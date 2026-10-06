class SourceControl {
    hidden [object]$Backend
    hidden [string]$WorkDir
    [string]$Channel
    [string]$Root
    [Env]$Env
    [Yaml]$Settings

    SourceControl([Env]$Env, [Yaml]$Settings, [string]$RemoteUrl, [GitHub]$GitHub, [GitLab]$GitLab) {
        if (-not $Env) { throw '[!] SourceControl requires Env' }
        if (-not $Settings) { throw '[!] SourceControl requires settings.cfg' }
        if (-not $GitHub) { throw '[!] SourceControl requires GitHub' }
        if (-not $GitLab) { throw '[!] SourceControl requires GitLab' }
        $this.Env = $Env
        $this.Settings = $Settings
        $this.Channel = switch ($Env.Name.ToLower()) {
            { $_ -in @('dev', 'development') } { 'test' }
            'live' { 'live' }
            'test' { 'test' }
            default { throw "[!] env must be live or test (got $($Env.Name))" }
        }

        if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { throw '[!] remote url required' }

        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) { throw '[!] not in a git repo' }
        $this.Root = (Resolve-Path $repoRoot).Path

        $localPath = $this.Root
        if ($this.UsesTempClone($RemoteUrl)) {
            $this.WorkDir = Join-Path ([IO.Path]::GetTempPath()) "iac-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $localPath = $this.WorkDir
        }

        $repo = $this.RepoPath($RemoteUrl)
        if ($this.Channel -eq 'live') {
            $GitHub.Remote = $RemoteUrl
            $GitHub.LocalPath = $localPath
            $GitHub.Repo = $repo
            $this.Backend = $GitHub
        }
        else {
            $GitLab.Remote = $RemoteUrl
            $GitLab.LocalPath = $localPath
            $GitLab.Repo = $repo
            $this.Backend = $GitLab
        }
    }

    hidden [string] RepoPath([string]$Url) {
        if ($Url -match '^ssh://git@([^:/]+):[0-9]+/(.+)$') { return $Matches[2] -replace '\.git$', '' }
        if ($Url -match '^git@([^:]+):(.+)$') { return $Matches[2] -replace '\.git$', '' }
        if ($Url -match '^https?://([^/]+)/(.+)$') { return $Matches[2] -replace '\.git$', '' }
        throw "[!] cannot parse git URL: $Url"
    }

    hidden [bool] UsesTempClone([string]$RemoteUrl) {
        $names = git -C $this.Root remote 2>$null
        if (-not $names) { return $true }
        foreach ($name in $names) {
            $url = (git -C $this.Root remote get-url $name 2>$null).Trim()
            if ($url -eq $RemoteUrl) { return $false }
        }
        return $true
    }

    [void] Cleanup() {
        if ($this.WorkDir -and (Test-Path $this.WorkDir)) {
            Remove-Item -Recurse -Force $this.WorkDir -ErrorAction SilentlyContinue
            $this.WorkDir = $null
        }
    }

    [void] Sync() { $this.Backend.Sync() }

    [void] WriteFile([string]$RelativePath, [string]$SourcePath) {
        $this.Backend.WriteFile($RelativePath, $SourcePath)
    }

    [void] WriteContent([string]$RelativePath, [string]$Content) {
        $this.Backend.WriteContent($RelativePath, $Content)
    }

    hidden [void] ConfigureGitsign([string]$RepoPath) {
        if (-not (Get-Command gitsign -ErrorAction SilentlyContinue)) {
            throw '[!] gitsign required (https://github.com/sigstore/gitsign)'
        }
        & git -C $RepoPath config gpg.x509.program gitsign
        & git -C $RepoPath config gpg.format x509
        & git -C $RepoPath config commit.gpgsign true
        $kind = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
        & git -C $RepoPath config gitsign.fulcio $this.Settings.Require("ONPREM.ENDPOINTS.FULCIO.$kind")
        & git -C $RepoPath config gitsign.rekor $this.Settings.Require("ONPREM.ENDPOINTS.REKOR.$kind")
        & git -C $RepoPath config gitsign.issuer $this.Settings.Require("ONPREM.ENDPOINTS.KEYCLOAK.$kind")
        & git -C $RepoPath config gitsign.clientID $this.Env.Require('OIDC_CLIENT_ID')
        & git -C $RepoPath config gitsign.redirectURL $this.Settings.Require('LOCAL.SIGSTORE.OIDC_REDIRECT_URL')
        & git -C $RepoPath config gitsign.autoclose false

        # Private Sigstore TUF — gitsign's embedded public root expired; use ONPREM.ENDPOINTS.TUF.
        $tufMirror = $this.Settings.Require("ONPREM.ENDPOINTS.TUF.$kind").TrimEnd('/')
        $homeDir = if (-not [string]::IsNullOrWhiteSpace($env:HOME)) { $env:HOME } else { $env:USERPROFILE }
        if ([string]::IsNullOrWhiteSpace($homeDir)) { throw '[!] HOME/USERPROFILE required for gitsign TUF cache' }
        $tufRootDir = Join-Path (Join-Path $homeDir '.sigstore') 'root'
        # Keep the initial root as a file (gitsign initialize may create dirs named after --root basenames).
        $tufRootFile = Join-Path $tufRootDir 'nottinfra-initial-root.json'
        if (-not (Test-Path -LiteralPath $tufRootDir)) {
            New-Item -ItemType Directory -Path $tufRootDir -Force | Out-Null
        }
        if (Test-Path -LiteralPath $tufRootFile) {
            if ((Get-Item -LiteralPath $tufRootFile).PSIsContainer) {
                Remove-Item -LiteralPath $tufRootFile -Recurse -Force
            }
        }
        try {
            Invoke-WebRequest -Uri "$tufMirror/root.json" -OutFile $tufRootFile -UseBasicParsing
        }
        catch {
            throw "[!] failed to fetch TUF root from $tufMirror/root.json ($($_.Exception.Message))"
        }
        & gitsign initialize --mirror $tufMirror --root $tufRootFile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "[!] gitsign initialize failed for mirror $tufMirror"
        }
        $env:TUF_MIRROR = $tufMirror
        $env:TUF_ROOT = $tufRootFile
        $env:TUF_ROOT_JSON = $tufRootFile

        $env:GITSIGN_LOG = Join-Path ([IO.Path]::GetTempPath()) 'gitsign.log'
        Write-Host "[+] gitsign configured (log=$env:GITSIGN_LOG tuf=$tufMirror)"
    }

    [string] PromptCommitMessage() {
        $types = @(
            @{ Name = 'feat';     Hint = 'new feature' }
            @{ Name = 'fix';      Hint = 'bug fix' }
            @{ Name = 'docs';     Hint = 'documentation only' }
            @{ Name = 'style';    Hint = 'formatting / whitespace (no logic change)' }
            @{ Name = 'refactor'; Hint = 'code change that is not feat or fix' }
            @{ Name = 'perf';     Hint = 'performance improvement' }
            @{ Name = 'test';     Hint = 'add or fix tests' }
            @{ Name = 'build';    Hint = 'build system or dependencies' }
            @{ Name = 'ci';       Hint = 'CI configuration' }
            @{ Name = 'chore';    Hint = 'maintenance / misc' }
            @{ Name = 'revert';   Hint = 'revert a previous commit' }
        )

        Write-Host ''
        Write-Host 'Conventional commit type:'
        for ($i = 0; $i -lt $types.Count; $i++) {
            Write-Host ("  {0}) {1,-9} {2}" -f ($i + 1), $types[$i].Name, $types[$i].Hint)
        }
        $choice = Read-Host "Choose [1-$($types.Count)]"
        if (-not $choice) { throw '[!] commit type required' }
        $idx = 0
        if (-not [int]::TryParse($choice, [ref]$idx)) { throw "[!] invalid choice: $choice" }
        $idx = $idx - 1
        if ($idx -lt 0 -or $idx -ge $types.Count) { throw "[!] choice out of range: $choice" }
        $type = [string]$types[$idx].Name

        $scope = (Read-Host 'Scope (optional)').Trim()
        $desc = (Read-Host 'Short description').Trim()
        if ([string]::IsNullOrWhiteSpace($desc)) { throw '[!] commit description required' }
        $desc = $desc.TrimEnd('.')

        $breaking = $false
        if ((Read-Host 'Breaking change? [y/N]') -match '^[yY]$') { $breaking = $true }

        $body = (Read-Host 'Body (optional)').Trim()
        $footer = ''
        if ($breaking) {
            $footer = (Read-Host 'BREAKING CHANGE description').Trim()
            if ([string]::IsNullOrWhiteSpace($footer)) { throw '[!] BREAKING CHANGE description required' }
        }

        $bang = if ($breaking) { '!' } else { '' }
        $scopePart = if ($scope) { "($scope)" } else { '' }
        $header = "${type}${scopePart}${bang}: $desc"

        $parts = [System.Collections.Generic.List[string]]::new()
        $parts.Add($header)
        if ($body) {
            $parts.Add('')
            $parts.Add($body)
        }
        if ($footer) {
            $parts.Add('')
            $parts.Add("BREAKING CHANGE: $footer")
        }
        $msg = ($parts -join "`n").Trim()
        Write-Host ''
        Write-Host "[+] commit message:"
        Write-Host $msg
        return $msg
    }

    [void] Commit([string]$Message) {
        $this.ConfigureGitsign($this.Root)
        if (git -C $this.Root status --porcelain) {
            & git -C $this.Root add -A
            & git -C $this.Root commit -S -m $Message
            if ($LASTEXITCODE -ne 0) { throw '[!] git commit failed' }
        }
        else {
            Write-Host '[i] Working tree clean — pushing existing commits only'
        }
    }

    [void] CommitAndPush([string]$Message) {
        $this.ConfigureGitsign($this.Backend.LocalPath)
        $this.Backend.CommitAndPush($Message)
    }

    [string] CreateBranch([string]$Name, [string]$RemoteName) {
        return $this.Backend.CreateBranch($Name, $RemoteName)
    }

    [void] PreparePullRequestBranch([string]$BranchName, [string]$RemoteName, [string]$TargetBranch) {
        $repo = $this.Backend.LocalPath
        & git -C $repo fetch $RemoteName $TargetBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git fetch failed: $RemoteName $TargetBranch" }

        $previous = (& git -C $repo branch --show-current 2>$null).Trim()
        & git -C $repo checkout $BranchName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git checkout failed: $BranchName" }

        $target = "$RemoteName/$TargetBranch"
        & git -C $repo merge-base HEAD $target 2>$null | Out-Null
        if ($LASTEXITCODE -eq 1) {
            Write-Host "[i] unrelated histories — merging $target into $BranchName"
            & git -C $repo merge $target --allow-unrelated-histories -m "Merge $TargetBranch into $BranchName" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                & git -C $repo merge --abort 2>$null | Out-Null
                if ($previous) {
                    & git -C $repo checkout $previous 2>&1 | Out-Null
                }
                throw "[!] git merge failed: $target into $BranchName"
            }
        }
        elseif ($LASTEXITCODE -ne 0) {
            throw "[!] git merge-base failed: HEAD $target"
        }

        if ($previous) {
            & git -C $repo checkout $previous 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "[!] git checkout failed: $previous" }
        }
    }

    [void] PushBranch([string]$RemoteName, [string]$BranchName) {
        $this.Backend.PushBranch($RemoteName, $BranchName)
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        return $this.Backend.CreatePullRequest($SourceBranch, $TargetBranch, $Title)
    }

    [void] SetCiVars([hashtable]$Vars) {
        if ($this.Channel -eq 'live') {
            foreach ($key in $Vars.Keys) {
                $val = [string]$Vars[$key]
                if ($key -match 'TOKEN|SECRET|^VAULT_') {
                    $this.Backend.SetSecret($this.Backend.Repo, $key, $val)
                }
                else {
                    $this.Backend.SetVariable($this.Backend.Repo, $key, $val)
                }
            }
            return
        }
        foreach ($key in $Vars.Keys) {
            $masked = $key -match 'TOKEN|SECRET'
            $this.Backend.SetVariable($key, [string]$Vars[$key], $masked, $false)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCANG0eZQ/PaZpAz
# YDGpQMqRvtmPZ3cyzx7eZaxPTLqBhqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
# R/b0C5YxX/PjyDAKBggqhkjOPQQDAjAgMR4wHAYDVQQDExVOb3R0SW5mcmEgSW50
# ZXJuYWwgQ0EwHhcNMjYwNzI3MjM0NDE1WhcNMjcwNzI3MjM0NDE1WjAlMSMwIQYD
# VQQDExpOT1RUSU5GUkEgTElNSVRFRCBTT0ZUV0FSRTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAKRICuzioM/pLsdWW/uV0Hl7Y5FHNBPTEl3X/oGK+BAi
# kC0es0CLXLykWpsJ/f9ldyyHlMzwUR1zEIhCZXEyo+uqQ8B1yWke7rQ4wkWE6/DU
# htCLSiySkf/KB389/ptcEM+jJ48DQGi0+8K6QQ02vEOAQKLfxA4Rrnl5BYY+nnNs
# Rpa+B6K40i/aFAsc60gbG3SGQePzuHHbPl6CE5AzQNY2WBpY77aonZ830RM5AsS4
# Xe7P8cDJ7Gahw6ZjLEriCaR3xBytPy63RiZdW8upuQ0AIFz4/8GVRYuOJ1wGeU53
# b0OZhj/6Z481Zry0VcBvGfHidIVkQKbWZQ2QWdkSBbSAIR92tKpSqSDy4VQYQ4RO
# l3NY/QHkJsAl6EGzQ514P+qUzkSyxgSNHZFCknqTu6gXtemaCUC7z/eLZDibw+mg
# yAuyLTZoeAlDPaHT4FOPfB8pn6UuGb/LwJwFlBHGAkaYlfAkx3BJYIsQpfPwKxfN
# Ufds8LMYArJlFZJnJ1EmJSE+qIu0cN7SyuFDAdGszrVjltYswzAfhE0NRQQm4HiG
# CWG9ZxDD1TxbhvEecgJCOMy/dZCcjEEzq4wZxSVPicn0QowKDWHy1GpgdR3pT+Ok
# zuIBpfEeXW5uW9e0yoOzwOnh1XCRp8hv+B4l4RvTEl3ccZ+PcmAcsLHODqvW4vmT
# AgMBAAGjQTA/MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
# MBaAFKF88Blhy5xs0hQfn4medNFL3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDwlWDa
# ojXZG8h5O2XzW/IG9h+GUKAmx8SCd7NuhB0SUAIgJkQlleqNoGkPuDyi08MuVI36
# ezJPirlP+IxtyaFnz10xggMHMIIDAwIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIF2YUutA
# CndORh+H5rab8OsgUfblhPBFs5WJ4zPCcCDLMAsGCSqGSIb3DQEBAQSCAgBJ2fCp
# 3nUU1gQc+wOew617eOpRHk0YN0Cxe/OpNMf65Hn0Jtkm1ID5UgsqUuLDPQn1URwX
# 1f/GauDbFI0ufoqGZD31zr3/ba4IpNs6sMdtAvTvGblNE12U51oSQkyJCJGUL3Jk
# E9GjAPMnkiqNJRz4arxcaHBTNYcxnjnUjXGc1H8Pm9g2Shpd7yrcILZO/Cvf+OHY
# v3woqlfOFQdEWpcC1Lbf0dwNPglJtB7Gnvd71bUBumhuem0WLtuAigpAO145R7jK
# WC2hBCQlQuF1Qf1ItFdD+68U2Z5GFsNg/cxmRbIpX5BhF9905048Lnk0Rp/+7K69
# 54QsRwgyfljlau2caF/8Q+XJlHHZc1bngL04Ke4pMF6OJBCO7Ig8aia7MLuW0kZR
# 9Rqv7gMtVLcQV5tHomj+iP3DhNLRaWYqvIyw+Sa/k3PPFd8ptwZZszW2k3fh4hOe
# TSs4FoMly53DMCRPXRYw+SeN9O+cTuaBDjlfbENvFIaqgJaiHn6Rn3W+sNwq+pEy
# 3WbA25GUMVWOz/X9s1hN5HCNan3EATwFciY7YAgPnWhFYAV0E36ZGKX88aPYY89C
# w7iwQdg1STO2rMA4fh45N9/ANVqwk+7AoK1FXvW0hYRqcDwJBSm/aehgURO5r0Ce
# nii/YAcs5E1UL4fwmfpzwYdFUa2zWVJXTBSA8aErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBF5wN6XfunYvjb
# 6v3QN3QZbisZ2CQeiTaEXZ/o3xDEe6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
# R/b0C5YxX/PjyDAKBggqhkjOPQQDAjAgMR4wHAYDVQQDExVOb3R0SW5mcmEgSW50
# ZXJuYWwgQ0EwHhcNMjYwNzI3MjM0NDE1WhcNMjcwNzI3MjM0NDE1WjAlMSMwIQYD
# VQQDExpOT1RUSU5GUkEgTElNSVRFRCBTT0ZUV0FSRTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAKRICuzioM/pLsdWW/uV0Hl7Y5FHNBPTEl3X/oGK+BAi
# kC0es0CLXLykWpsJ/f9ldyyHlMzwUR1zEIhCZXEyo+uqQ8B1yWke7rQ4wkWE6/DU
# htCLSiySkf/KB389/ptcEM+jJ48DQGi0+8K6QQ02vEOAQKLfxA4Rrnl5BYY+nnNs
# Rpa+B6K40i/aFAsc60gbG3SGQePzuHHbPl6CE5AzQNY2WBpY77aonZ830RM5AsS4
# Xe7P8cDJ7Gahw6ZjLEriCaR3xBytPy63RiZdW8upuQ0AIFz4/8GVRYuOJ1wGeU53
# b0OZhj/6Z481Zry0VcBvGfHidIVkQKbWZQ2QWdkSBbSAIR92tKpSqSDy4VQYQ4RO
# l3NY/QHkJsAl6EGzQ514P+qUzkSyxgSNHZFCknqTu6gXtemaCUC7z/eLZDibw+mg
# yAuyLTZoeAlDPaHT4FOPfB8pn6UuGb/LwJwFlBHGAkaYlfAkx3BJYIsQpfPwKxfN
# Ufds8LMYArJlFZJnJ1EmJSE+qIu0cN7SyuFDAdGszrVjltYswzAfhE0NRQQm4HiG
# CWG9ZxDD1TxbhvEecgJCOMy/dZCcjEEzq4wZxSVPicn0QowKDWHy1GpgdR3pT+Ok
# zuIBpfEeXW5uW9e0yoOzwOnh1XCRp8hv+B4l4RvTEl3ccZ+PcmAcsLHODqvW4vmT
# AgMBAAGjQTA/MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
# MBaAFKF88Blhy5xs0hQfn4medNFL3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDwlWDa
# ojXZG8h5O2XzW/IG9h+GUKAmx8SCd7NuhB0SUAIgJkQlleqNoGkPuDyi08MuVI36
# ezJPirlP+IxtyaFnz10xggLaMIIC1gIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIEjsRHb
# W9dOrnoGIX4H0B8pnsPBfUXaC7KI3Mk44pKzMAsGCSqGSIb3DQEBAQSCAgAoJJyZ
# 8wIe8UfLpAJQTuJxJ0tWPpE7vhhxAMjVtgMdmMxZNd1gpTU49OPgykm+5rWwXcA+
# 5jN3jcoNTOjyVo/jAq8a75UV94G14wZT8CCXDAX+RKSVequE6kDTxUxrfiOI6cUA
# qBZzU/6J4iDBo3U8S/myP2w/1Gx9ba8fafm6IjJRvnsII3n8iVPQgn9oLAX0yC99
# gWDG6jxYDANaLLVyInQ7OVfjGU6EwKRcGdaGCrFRuPvadKGbGUnLHqM0DxVVx1eq
# NTE4aEyRjsLPv6IrB8oP2gRcmZmTv1oFwoqHoOACmYT6TWGedmMZcT9mfSeJ1e+D
# KVCBi+mm174bDXoCtIcZ44VXUzPCr0iV1DbZuosUaKmgaRxSpDcHVmpl69oITVkS
# yya1tdxEdGHo5TfgNetOcT0sNaYnofCkIzC+n84zCvf6alfYAw7iL2Ei/GrA3Ry2
# pzFkv2JW6A2pFT1QuQRI3tCYca3WT0H7O61ql+Bb2goko50EQ5E18GSRsuC8Cr4x
# pqpu3hOP5MRgIw6G5ATFssOxvdOs1ExJnzo7HtfKd3E81DK3+i/8AG9B1nRGDRtJ
# xmZB0f2uglvTEPw14XEMjeNjHLH0cdOrGI/RPpJJTKX/gxr3G87axA9G/2qjNTCO
# XYMiI+horKNOWXAvg/vHERrQ0KJ8jrZK+O/hbw==
# SIG # End signature block

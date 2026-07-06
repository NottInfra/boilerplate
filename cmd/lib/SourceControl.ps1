class SourceControl {
    hidden [object]$Backend
    hidden [string]$WorkDir
    [string]$Env
    [string]$Root

    SourceControl([string]$RemoteUrl) {
        if (-not $env:ENV) { throw '[!] ENV required' }
        $this.Env = switch ($env:ENV.ToLower()) {
            { $_ -in @('dev', 'development') } { 'test' }
            'live' { 'live' }
            'test' { 'test' }
            default { throw "[!] env must be live or test (got $env:ENV)" }
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
        if ($this.Env -eq 'live') {
            $this.Backend = New-Object GitHub $RemoteUrl, $localPath
        }
        else {
            $this.Backend = New-Object GitLab $RemoteUrl, $localPath
        }
        $this.Backend.Repo = $repo
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

    [void] CommitAndPush([string]$Message) { $this.Backend.CommitAndPush($Message) }

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
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[i] unrelated histories — merging $target into $BranchName"
            & git -C $repo merge $target --allow-unrelated-histories -m "Merge $TargetBranch into $BranchName" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "[!] git merge failed: $target into $BranchName" }
        }

        if ($previous) {
            & git -C $repo checkout $previous 2>&1 | Out-Null
        }
    }

    [void] PushBranch([string]$RemoteName, [string]$BranchName) {
        $this.Backend.PushBranch($RemoteName, $BranchName)
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        return $this.Backend.CreatePullRequest($SourceBranch, $TargetBranch, $Title)
    }

    [void] SetCiVars([hashtable]$Vars) {
        if ($this.Env -eq 'live') {
            foreach ($key in $Vars.Keys) {
                $val = [string]$Vars[$key]
                if ($key -match 'TOKEN|SECRET') {
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

class GitLab {
    [string]$Remote
    [string]$LocalPath
    [string]$Repo
    [string]$WebUrl

    GitLab([string]$Remote, [string]$LocalPath) {
        $this.Remote = $Remote
        $this.LocalPath = $LocalPath
        if (-not $env:GITLAB_URL_PUBLIC) { throw '[!] GITLAB_URL_PUBLIC is required' }
        $this.WebUrl = $env:GITLAB_URL_PUBLIC.TrimEnd('/')
    }

    [void] Sync() {
        if (Test-Path (Join-Path $this.LocalPath '.git')) {
            & git -C $this.LocalPath fetch origin 2>&1 | Out-Null
            & git -C $this.LocalPath checkout main 2>$null
            if ($LASTEXITCODE -ne 0) { & git -C $this.LocalPath checkout master 2>$null }
            & git -C $this.LocalPath pull --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "[!] git pull failed in $($this.LocalPath)" }
            return
        }
        if (Test-Path $this.LocalPath) { Remove-Item -Recurse -Force $this.LocalPath }
        $parent = Split-Path $this.LocalPath -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        & git clone $this.Remote $this.LocalPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git clone failed: $($this.Remote)" }
    }

    [void] WriteFile([string]$RelativePath, [string]$SourcePath) {
        $dest = Join-Path $this.LocalPath $RelativePath
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -Path $SourcePath -Destination $dest -Force
    }

    [void] WriteContent([string]$RelativePath, [string]$Content) {
        $dest = Join-Path $this.LocalPath $RelativePath
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -Path $dest -Value $Content -NoNewline
    }

    [void] CommitAndPush([string]$Message) {
        & git -C $this.LocalPath add -A 2>&1 | Out-Null
        & git -C $this.LocalPath diff --cached --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host '[=] no IaC changes'
            return
        }
        & git -C $this.LocalPath commit -m $Message 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[!] git commit failed' }
        & git -C $this.LocalPath push origin HEAD 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[!] git push failed' }
        Write-Host "[+] IaC pushed: $Message"
    }

    [bool] LocalBranchExists([string]$Name) {
        & git -C $this.LocalPath show-ref --verify --quiet "refs/heads/$Name"
        return $LASTEXITCODE -eq 0
    }

    [bool] RemoteBranchExists([string]$RemoteName, [string]$BranchName) {
        $out = & git -C $this.LocalPath ls-remote --exit-code --heads $RemoteName $BranchName 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        if ($LASTEXITCODE -eq 2) { return $false }
        throw "[!] git ls-remote failed: $RemoteName/$BranchName ($out)"
    }

    [string] CreateBranch([string]$Name, [string]$RemoteName) {
        $branch = $Name
        if ($this.LocalBranchExists($branch) -or $this.RemoteBranchExists($RemoteName, $branch)) {
            $shortSha = (& git -C $this.LocalPath rev-parse --short HEAD).Trim()
            $branch = "$Name-$shortSha"
        }
        $suffix = 2
        while ($this.LocalBranchExists($branch) -or $this.RemoteBranchExists($RemoteName, $branch)) {
            $branch = "$Name-$suffix"
            $suffix++
        }
        & git -C $this.LocalPath branch $branch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git branch failed: $branch" }
        return $branch
    }

    [void] PushBranch([string]$RemoteName, [string]$BranchName) {
        $out = & git -C $this.LocalPath push $RemoteName "${BranchName}:${BranchName}" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "[!] git push failed: $BranchName ($out)" }
    }

    [void] SetVariable([string]$Key, [string]$Value) {
        $this.SetVariable($Key, $Value, $false, $false)
    }

    [void] SetVariable([string]$Key, [string]$Value, [bool]$Masked) {
        $this.SetVariable($Key, $Value, $Masked, $false)
    }

    [void] SetVariable([string]$Key, [string]$Value, [bool]$Masked, [bool]$Protected) {
        if (-not $env:GITLAB_TOKEN) { throw '[!] GITLAB_TOKEN is required' }
        $headers = @{ 'PRIVATE-TOKEN' = $env:GITLAB_TOKEN }
        $payload = @{
            key                 = $Key
            value               = $Value
            protected           = $Protected
            masked              = $Masked
            environment_scope   = '*'
            variable_type       = 'env_var'
        }
        $body = ($payload | ConvertTo-Json -Compress)
        $base = "$($this.WebUrl)/api/v4/projects/$([uri]::EscapeDataString($this.Repo))/variables"
        try {
            Invoke-RestMethod -Method Put -Uri "$base/$Key" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -ne 404) { throw "[!] GitLab variable update failed: $Key ($($_.Exception.Message))" }
            Invoke-RestMethod -Method Post -Uri $base -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        }
        $flags = if ($Protected) { 'protected' } else { 'unprotected' }
        if ($Masked) { $flags += ', masked' }
        Write-Host "[+] GitLab $($this.Repo): variable $Key ($flags)"
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        $query = @(
            "merge_request%5Bsource_branch%5D=$([uri]::EscapeDataString($SourceBranch))"
            "merge_request%5Btarget_branch%5D=$([uri]::EscapeDataString($TargetBranch))"
            "merge_request%5Btitle%5D=$([uri]::EscapeDataString($Title))"
        ) -join '&'
        $url = "$($this.WebUrl)/$($this.Repo)/-/merge_requests/new?$query"
        if (Get-Command open -ErrorAction SilentlyContinue) { & open $url }
        Write-Host "[+] GitLab MR: $url"
        return $url
    }
}

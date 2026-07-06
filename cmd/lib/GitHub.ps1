class GitHub {
    [string]$Remote
    [string]$LocalPath
    [string]$Repo
    hidden [string]$Gh

    GitHub([string]$Remote, [string]$LocalPath) {
        $this.Remote = $Remote
        $this.LocalPath = $LocalPath
        $this.Gh = [GitHub]::ResolveGh()
    }

    static [string] ResolveGh() {
        $cmd = Get-Command gh -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        $paths = [System.Collections.Generic.List[string]]::new()
        if ($env:HOMEBREW_PREFIX) { $paths.Add((Join-Path $env:HOMEBREW_PREFIX 'bin/gh')) }
        $paths.Add('/opt/homebrew/bin/gh')
        $paths.Add('/usr/local/bin/gh')
        foreach ($p in $paths) {
            if (Test-Path $p) { return $p }
        }
        throw '[!] gh CLI required (install: brew install gh)'
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

    [void] CreateRepo([string]$Owner, [string]$Name, [bool]$Private = $true) {
        $vis = if ($Private) { '--private' } else { '--public' }
        & $this.Gh repo create "$Owner/$Name" $vis --confirm 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh repo create failed: $Owner/$Name" }
        Write-Host "[+] GitHub repo created: $Owner/$Name"
    }

    [void] SetSecret([string]$Repo, [string]$Name, [string]$Value) {
        $Value | & $this.Gh secret set $Name --body - -R $Repo 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh secret set failed: $Name" }
        Write-Host "[+] GitHub ${Repo}: secret $Name"
    }

    [void] SetVariable([string]$Repo, [string]$Name, [string]$Value) {
        $Value | & $this.Gh variable set $Name --body - -R $Repo 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh variable set failed: $Name" }
        Write-Host "[+] GitHub ${Repo}: variable $Name"
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        $out = & $this.Gh pr create --repo $this.Repo --base $TargetBranch --head $SourceBranch --title $Title --body $Title 2>&1
        if ($LASTEXITCODE -ne 0) { throw "[!] gh pr create failed: $out" }
        $url = ($out | Select-Object -Last 1).ToString().Trim()
        Write-Host "[+] GitHub PR created: $url"
        return $url
    }
}

class GitHub : GitRemote {
    [bool]$HasGh

    GitHub([string]$Remote, [string]$LocalPath) : base($Remote, $LocalPath) {
        $this.HasGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
        if (-not $this.HasGh) { throw '[!] gh CLI required' }
    }

    [void] CreateRepo([string]$Owner, [string]$Name, [bool]$Private = $true) {
        if (-not $this.HasGh) { throw '[!] gh CLI required' }
        $vis = if ($Private) { '--private' } else { '--public' }
        & gh repo create "$Owner/$Name" $vis --confirm 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh repo create failed: $Owner/$Name" }
        Write-Host "[+] GitHub repo created: $Owner/$Name"
    }

    [void] SetSecret([string]$Repo, [string]$Name, [string]$Value) {
        if (-not $this.HasGh) { throw '[!] gh CLI required' }
        $Value | & gh secret set $Name --body - -R $Repo 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh secret set failed: $Name" }
        Write-Host "[+] GitHub ${Repo}: secret $Name"
    }

    [void] ScheduleCi([string]$Workflow = 'deploy-live.yml', [string]$Cron = '0 0 * * *') {
        if (-not $this.HasGh) { throw '[!] gh CLI required' }
        $this.Sync()
        $file = Join-Path $this.LocalPath ".github/workflows/$Workflow"
        if (-not (Test-Path $file)) { throw "[!] missing workflow: $Workflow" }
        $yaml = Get-Content $file -Raw
        if ($yaml -match '(?m)^\s+schedule:') {
            Write-Host "[+] GitHub schedule exists: $Workflow"
            return
        }
        $block = @"

  schedule:
    - cron: '$Cron'
"@
        if ($yaml -notmatch '(?m)^on:\s*$') { throw '[!] workflow missing on: block' }
        $updated = $yaml -replace '(?m)(^  workflow_dispatch:\s*\r?\n)', "`$1$block"
        if ($updated -eq $yaml) { throw '[!] could not inject schedule into workflow' }
        Set-Content -Path $file -Value $updated.TrimEnd() -NoNewline
        $this.CommitAndPush("ci: schedule $Workflow every 24h")
        Write-Host "[+] GitHub schedule added: $Workflow ($Cron)"
    }
}

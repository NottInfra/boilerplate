#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

if (-not (Test-Path 'compose.yml')) { throw '[!] Missing compose.yml' }

$project = [ProjectConfigParse]::new()
$content = (Get-Content 'compose.yml' -Raw) -replace '@PROJECT@', $project.Name

$git = [SourceControl]::new($project.Require('remotes.iac.url'))
try {
    $git.Sync()
    $iacPath = "docker/$($project.Name)/compose.yml"
    $git.WriteContent($iacPath, $content)
    $git.CommitAndPush("app-config: $($project.Name)")
    Write-Host "[+] Done — app compose → $iacPath ($($env:ENV))"
}
finally {
    $git.Cleanup()
}

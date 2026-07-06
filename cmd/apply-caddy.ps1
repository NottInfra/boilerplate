#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

if (-not (Test-Path 'Caddyfile')) { throw '[!] Missing Caddyfile' }

$project = [Config]::new('project.cfg')

$git = [SourceControl]::new($project.Require('remotes.iac.url'))
try {
    $git.Sync()
    $iacPath = "host/caddy/configs/$($project.Name).caddy"
    $git.WriteFile($iacPath, 'Caddyfile')
    $git.CommitAndPush("caddy: $($project.Name)")
    Write-Host "[+] Done — Caddy → $iacPath ($($env:ENV))"
}
finally {
    $git.Cleanup()
}

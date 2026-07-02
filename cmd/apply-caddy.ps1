#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/GitRemote.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$caddy = Join-Path $Root 'Caddyfile'
if (-not (Test-Path $caddy)) { throw '[!] Missing Caddyfile' }

$project = [ProjectConfigParse]::new((Join-Path $Root 'project.cfg'))

$iacGit = $project.Require('remotes.iac.url')
$workDir = Join-Path ([IO.Path]::GetTempPath()) "iac-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    $git = [GitRemote]::ForRemote($iacGit, $workDir)
    $git.Sync()
    $iacPath = "host/caddy/configs/$($project.Name).caddy"
    $git.WriteFile($iacPath, $caddy)
    $git.CommitAndPush("caddy: $($project.Name)")
    Write-Host "[+] Done — Caddy → $iacPath"
}
finally {
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

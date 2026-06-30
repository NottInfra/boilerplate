#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Project.ps1"
. "$PSScriptRoot/lib/Cfg.ps1"
. "$PSScriptRoot/lib/GitRemote.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$project = [Project]::new((Join-Path $Root 'project.yml'))
$json = ($project.BlackboxTargets() | ConvertTo-Json -Depth 10 -Compress)

$iacGit = [Cfg]::new((Join-Path $Root 'boilerplate.cfg')).Get('iac_git')
$workDir = Join-Path ([IO.Path]::GetTempPath()) "iac-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    $git = [GitRemote]::ForRemote($iacGit, $workDir)
    $git.Sync()
    $iacPath = $project.IaCPath('blackbox')
    $git.WriteContent($iacPath, $json)
    $git.CommitAndPush("blackbox: $($project.Name)")
    Write-Host "[+] Done — synth-mon → $iacPath"
}
finally {
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

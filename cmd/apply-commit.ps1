#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Project.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$projectFile = Join-Path $Root 'project.yml'
$project = [Project]::new($projectFile)

$env:ENV = 'production'
$live = [Project]::new($projectFile)
$env:ENV = 'test'
$test = [Project]::new($projectFile)

git remote get-url $live.RemoteName 2>$null
if ($LASTEXITCODE -eq 0) { git remote set-url $live.RemoteName $live.RemoteUrl }
else { git remote add $live.RemoteName $live.RemoteUrl }

git remote get-url $test.RemoteName 2>$null
if ($LASTEXITCODE -eq 0) { git remote set-url $test.RemoteName $test.RemoteUrl }
else { git remote add $test.RemoteName $test.RemoteUrl }

Write-Host ''
Write-Host 'Release channel:'
Write-Host "  1) live  → $($live.RemoteName) / $($live.Branch)"
Write-Host "  2) test  → $($test.RemoteName) / $($test.Branch)"
$choice = Read-Host 'Choose 1/2'
$channel = switch ($choice) { '1' { 'live' } '2' { 'test' } default { throw '[!] Invalid choice' } }
$target = if ($channel -eq 'live') { $live } else { $test }

$msg = Read-Host 'Commit message'
if ([string]::IsNullOrWhiteSpace($msg)) { throw '[!] Commit message required' }

[Gitleaks]::new().Scan()

if (git status --porcelain) { git add -A; git commit -m $msg }
else { Write-Host '[i] Working tree clean — pushing existing commits only' }

git push $target.RemoteName "HEAD:$($target.Branch)"
Write-Host "[+] Pushing $channel → $($target.RemoteName) $($target.Branch) ($($project.Name))"

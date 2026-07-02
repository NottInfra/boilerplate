#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"
. "$PSScriptRoot/lib/GitRemote.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$projectFile = Join-Path $Root 'project.cfg'
$project = [ProjectConfigParse]::new($projectFile)

$env:ENV = 'live'
$live = [ProjectConfigParse]::new($projectFile)
$env:ENV = 'test'
$test = [ProjectConfigParse]::new($projectFile)

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

if ((Read-Host 'Create pull request? [y/N]') -match '^[yY]$') {
    $slug = $msg.Trim() -replace '\s+', '-' -replace '[~^:?*\[\\]', '' -replace '\.+', '.'
    if ([string]::IsNullOrWhiteSpace($slug)) { throw '[!] Commit message cannot produce a valid branch name' }
    $branch = "pull-request/$slug"
    $git = [GitRemote]::ForRemote($target.RemoteUrl, $Root)
    $git.CreateBranch($branch)
    $git.PushBranch($target.RemoteName, $branch)
    $prUrl = $git.CreatePullRequest($branch, $target.Branch, $msg)
    Write-Host "[+] PR $branch → $($target.Branch) ($prUrl)"
}
else {
    git push $target.RemoteName "HEAD:$($target.Branch)"
    Write-Host "[+] Pushing $channel → $($target.RemoteName) $($target.Branch) ($($project.Name))"
}

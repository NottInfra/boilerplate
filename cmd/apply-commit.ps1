#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

$project = [ProjectConfigParse]::new()
$liveRemote = $project.Require('remotes.live.remote')
$liveUrl = $project.Require('remotes.live.url')
$liveBranch = $project.Require('remotes.live.branch')
$testRemote = $project.Require('remotes.test.remote')
$testUrl = $project.Require('remotes.test.url')
$testBranch = $project.Require('remotes.test.branch')

git remote get-url $liveRemote 2>$null
if ($LASTEXITCODE -eq 0) { git remote set-url $liveRemote $liveUrl }
else { git remote add $liveRemote $liveUrl }

git remote get-url $testRemote 2>$null
if ($LASTEXITCODE -eq 0) { git remote set-url $testRemote $testUrl }
else { git remote add $testRemote $testUrl }

Write-Host ''
Write-Host 'Release channel:'
Write-Host "  1) live  → $liveRemote / $liveBranch"
Write-Host "  2) test  → $testRemote / $testBranch"
$choice = Read-Host 'Choose 1/2'
$channel = switch ($choice) { '1' { 'live' } '2' { 'test' } default { throw '[!] Invalid choice' } }

if ($channel -eq 'live') {
    $targetRemote = $liveRemote
    $targetUrl = $liveUrl
    $targetBranch = $liveBranch
}
else {
    $targetRemote = $testRemote
    $targetUrl = $testUrl
    $targetBranch = $testBranch
}

$msg = Read-Host 'Commit message'
if ([string]::IsNullOrWhiteSpace($msg)) { throw '[!] Commit message required' }

[Gitleaks]::new().Scan()

if (git status --porcelain) { git add -A; git commit -m $msg }
else { Write-Host '[i] Working tree clean — pushing existing commits only' }

if ((Read-Host 'Create pull request? [y/N]') -match '^[yY]$') {
    $slug = $msg.Trim() -replace '\s+', '-' -replace '[~^:?*\[\\]', '' -replace '\.+', '.'
    if ([string]::IsNullOrWhiteSpace($slug)) { throw '[!] Commit message cannot produce a valid branch name' }
    $git = [SourceControl]::new($targetUrl)
    $branch = $git.CreateBranch("pull-request/$slug", $targetRemote)
    $git.PushBranch($targetRemote, $branch)
    $prUrl = $git.CreatePullRequest($branch, $targetBranch, $msg)
    Write-Host "[+] PR $branch → $targetBranch ($prUrl)"
}
else {
    git push $targetRemote "HEAD:$targetBranch"
    Write-Host "[+] Pushing $channel → $targetRemote $targetBranch ($($project.Name))"
}

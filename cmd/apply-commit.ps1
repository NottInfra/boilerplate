#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()
$project = [Config]::new('project.cfg')

$channel = switch ($env:ENV.ToLower()) {
    'live' { 'live' }
    { $_ -in @('test', 'development', 'dev') } { 'test' }
    default { throw "[!] apply-commit requires development, test, or live (got $env:ENV)" }
}

foreach ($name in @('live', 'test')) {
    $remote = $project.Require("remotes.$name.remote")
    $url = $project.Require("remotes.$name.url")
    git remote get-url $remote 2>$null
    if ($LASTEXITCODE -eq 0) { git remote set-url $remote $url }
    else { git remote add $remote $url }
}

$targetRemote = $project.Require("remotes.$channel.remote")
$targetUrl = $project.Require("remotes.$channel.url")
$targetBranch = $project.Require("remotes.$channel.branch")

Write-Host ''
Write-Host "[+] Push target: $channel → $targetRemote / $targetBranch (ENV=$env:ENV)"

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
    $git.PreparePullRequestBranch($branch, $targetRemote, $targetBranch)
    $git.PushBranch($targetRemote, $branch)
    $prUrl = $git.CreatePullRequest($branch, $targetBranch, $msg)
    Write-Host "[+] PR $branch → $targetBranch ($prUrl)"
}
else {
    git push $targetRemote "HEAD:$targetBranch"
    Write-Host "[+] Pushing $channel → $targetRemote $targetBranch ($($project.Name))"
}

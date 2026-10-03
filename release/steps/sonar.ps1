#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Sonar.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('sonar', 'started')

$gated = $env:RELEASE_PIPELINE -eq 'gated'
$baseBranch = [string]$project.Get("remotes.$staging.branch")
if ([string]::IsNullOrWhiteSpace($baseBranch)) { $baseBranch = 'develop' }

$sonar = [Sonar]::new($project.Name, $project.Root, $gated, $baseBranch)
$err = $null
try {
    $sonar.Scan()
}
catch {
    $err = $_
}
if ($sonar.FindingCount -gt 0) {
    $summary = if ($sonar.FindingSummary) { "sonar quality gate: $($sonar.FindingSummary)" } else { "sonar found $($sonar.FindingCount) finding(s)" }
    [AlertMgr]::new().Alert($summary)
}
if ($err) {
    $os.Step('sonar', 'failed', @{ error = $err.Exception.Message; finding_count = $sonar.FindingCount })
    throw $err
}
$os.Step('sonar', 'succeeded')

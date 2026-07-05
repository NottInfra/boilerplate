#!/usr/bin/env pwsh
# Gated pipeline — build, test, scan, sonar (PR mode). No push/deploy.
$ErrorActionPreference = 'Stop'

$Env = 'test'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('gitleaks', 'unit-test', 'semgrep', 'sonar', 'build', 'syft', 'grype', 'trivy')
$env:RELEASE_PIPELINE = 'gated'

$step = if ($args[0]) { $args[0] } else { 'all' }
if ($step -eq 'scan') { $step = 'trivy' }

$known = @('all', 'scan') + $All
if ($step -notin $known) {
    Write-Error "[!] unknown step: $step ($($known -join '|'))"
    exit 1
}

$steps = if ($step -eq 'all') { $All } else { @($step) }
foreach ($name in $steps) {
    & pwsh -NoProfile -File (Join-Path $Root "release/steps/$name.ps1") $Env
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

#!/usr/bin/env pwsh
# Live pipeline — build, test, scan, push. Deploy is Watchtower on the IaC host.
$ErrorActionPreference = 'Stop'

$Env = 'live'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('build', 'unit-test', 'gitleaks', 'semgrep', 'syft', 'grype', 'trivy', 'sonar', 'push')

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

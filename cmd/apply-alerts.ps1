#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/Kibana.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

foreach ($f in @('alerts/kibana.json', 'alerts/grafana.json')) {
    if (-not (Test-Path (Join-Path $Root $f))) { throw "[!] Missing $f" }
}

[void][Env]::new($Root)

$project = [ProjectConfigParse]::new((Join-Path $Root 'project.cfg'))

Write-Host "[+] Applying alerts (ENV=$($env:ENV))"
[Kibana]::new($project.Name).ApplyAlertingRules((Join-Path $Root 'alerts/kibana.json'))
[Grafana]::new($project.Name).ApplyAlertingRules((Join-Path $Root 'alerts/grafana.json'))
Write-Host '[+] Done — alerts'

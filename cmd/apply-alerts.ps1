#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Kibana.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"

[void][Env]::new()
$project = [Config]::new('project.cfg')

Write-Host "[+] Applying alerts (ENV=$($env:ENV))"
[Kibana]::new($project.Name).ApplyAlertingRules()
[Grafana]::new($project.Name).ApplyAlertingRules()
Write-Host '[+] Done — alerts'

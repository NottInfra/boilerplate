#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Project.ps1"
. "$PSScriptRoot/lib/Elastic.ps1"
. "$PSScriptRoot/lib/Kibana.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"
. "$PSScriptRoot/lib/PostHog.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$dirs = @(
    (Join-Path $Root 'dashboards/grafana')
    (Join-Path $Root 'dashboards/kibana')
    (Join-Path $Root 'dashboards/posthog')
)
$hasAny = $false
foreach ($d in $dirs) {
    if (Test-Path $d) {
        $hasAny = [bool](Get-ChildItem $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
        if ($hasAny) { break }
    }
}
if (-not $hasAny) { throw '[!] No dashboards found under dashboards/{grafana,kibana,posthog}/' }

[void][Env]::new($Root)

$project = [Project]::new((Join-Path $Root 'project.yml'))
$name = $project.Name

Write-Host "[+] Applying dashboards (ENV=$($env:ENV), project=$name)"

[Elastic]::new().CreateStream($name)

$kibanaDir = Join-Path $Root 'dashboards/kibana'
if ((Get-ChildItem $kibanaDir -Filter '*.ndjson' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    [Kibana]::new($name).ImportDir($kibanaDir)
}

$grafanaDir = Join-Path $Root 'dashboards/grafana'
if ((Get-ChildItem $grafanaDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    [Grafana]::new($name).ImportDir($grafanaDir)
}

$posthogDir = Join-Path $Root 'dashboards/posthog'
if ((Get-ChildItem $posthogDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    if ($env:POSTHOG_HOST -and $env:POSTHOG_API_KEY) {
        [PostHog]::new($name).ImportDir($posthogDir)
    }
    else {
        Write-Host '[i] PostHog dashboards present but POSTHOG_HOST / POSTHOG_API_KEY not set — skipping'
    }
}

Write-Host '[+] Done — dashboards'

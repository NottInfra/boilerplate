#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/Elastic.ps1"
. "$PSScriptRoot/lib/Kibana.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"
. "$PSScriptRoot/lib/PostHog.ps1"
. "$PSScriptRoot/lib/DefectDojo.ps1"

[void][Env]::new()

$dirs = @('dashboards/grafana', 'dashboards/kibana', 'dashboards/posthog')
$hasAny = $false
foreach ($d in $dirs) {
    if (Test-Path $d) {
        $hasAny = [bool](Get-ChildItem $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
        if ($hasAny) { break }
    }
}
if (-not $hasAny) { throw '[!] No dashboards found under dashboards/{grafana,kibana,posthog}/' }

$project = [ProjectConfigParse]::new()

Write-Host "[+] Applying dashboards (ENV=$($env:ENV), project=$($project.Name))"

[Elastic]::new($project.Name).CreateStream()

if ((Get-ChildItem 'dashboards/kibana' -Filter '*.ndjson' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    [Kibana]::new($project.Name).ImportDir('dashboards/kibana')
}

if ((Get-ChildItem 'dashboards/grafana' -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    [Grafana]::new($project.Name).ImportDir('dashboards/grafana')
}

$envHints = [System.Collections.Generic.List[string]]::new()
$posthog = $null

if ((Get-ChildItem 'dashboards/posthog' -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    if ($env:POSTHOG_URL -and $env:POSTHOG_API_KEY) {
        $posthog = [PostHog]::new($project.Name)
        $posthog.ImportDir('dashboards/posthog')
        if ($posthog.ResolvedProjectId) {
            $envHints.Add("POSTHOG_PROJECT_ID=$($posthog.ProjectId)")
        }
    }
    else {
        Write-Host '[i] PostHog dashboards present but POSTHOG_URL / POSTHOG_API_KEY not set — skipping'
    }
}

if ($env:DEFECT_DOJO_URL_PUBLIC -and $env:DEFECT_DOJO_API_TOKEN) {
    $dojo = [DefectDojo]::new($project.Name)
    $engId = $dojo.EnsureEngagement()
    if (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) {
        $envHints.Add("DEFECT_DOJO_ENGAGEMENT_ID=$engId")
    }
}
elseif (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) {
    Write-Host '[i] Defect Dojo not configured — set DEFECT_DOJO_URL_PUBLIC and DEFECT_DOJO_API_TOKEN, then re-run'
}

if ($envHints.Count -gt 0) {
    Write-Host ''
    Write-Host '[i] Add to .env:'
    foreach ($line in $envHints) {
        Write-Host "    $line"
    }
}

Write-Host '[+] Done — dashboards'

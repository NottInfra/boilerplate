#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Project.ps1"
. "$PSScriptRoot/lib/Spaceship.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

[void][Env]::new($Root)

$project = [Project]::new((Join-Path $Root 'project.yml'))
$plan = $project.DnsPlan()

if ($plan.Registry.ToUpper() -ne 'SPACESHIP') {
    throw "[!] public.dns.registry must be SPACESHIP (got $($plan.Registry))"
}

$items = foreach ($name in $plan.Names) {
    [ordered]@{
        type    = 'A'
        name    = $name
        address = $plan.Host
        ttl     = 3600
    }
}

Write-Host "[+] Applying DNS ($($plan.Domain), registry=$($plan.Registry))"
[Spaceship]::new().SaveRecords($plan.Domain, $items)
Write-Host '[+] Done — DNS'

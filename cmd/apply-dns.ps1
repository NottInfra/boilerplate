#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/Spaceship.ps1"

[void][Env]::new()

$project = [ProjectConfigParse]::new()
$registry = $project.Require('public.dns.registry')
$domain = $project.Require('public.domain')
$pubHost = $project.Require('public.host')
$names = @($project.Get('public.dns.A'))
if (-not $names -or $names.Count -eq 0) { throw '[!] public.dns.A required in project.cfg' }

if ($registry.ToUpper() -ne 'SPACESHIP') {
    throw "[!] public.dns.registry must be SPACESHIP (got $registry)"
}

$items = foreach ($name in $names) {
    [ordered]@{
        type    = 'A'
        name    = $name
        address = $pubHost
        ttl     = 3600
    }
}

Write-Host "[+] Applying DNS ($domain, registry=$registry)"
[Spaceship]::new().SaveRecords($domain, $items)
Write-Host '[+] Done — DNS'

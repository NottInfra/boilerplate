#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Project.ps1"
. "$PSScriptRoot/lib/Vault.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

[void][Env]::new($Root)

$project = [Project]::new((Join-Path $Root 'project.yml'))
$vault = [Vault]::new()
$vault.Health()

Write-Host ''
Write-Host "Vault @ $($vault.Addr)"
Write-Host "Project: $($project.Name)"

$stages = @(
    @{ Staging = 'live'; EnvFile = '.env.production' }
    @{ Staging = 'test'; EnvFile = '.env.test' }
)
Write-Host ''
Write-Host 'Staging:'
for ($i = 0; $i -lt $stages.Count; $i++) {
    $s = $stages[$i]
    $secret = "$($s.Staging)-$($project.Name)"
    Write-Host "  $($i + 1)) $($s.Staging)  ← $($s.EnvFile)  → secret/$secret"
}
Write-Host "  $($stages.Count + 1)) all"
$choice = Read-Host 'Choose'
$selected = if ([int]$choice -eq ($stages.Count + 1)) { $stages } else { @($stages[[int]$choice - 1]) }

foreach ($s in $selected) {
    $envf = Join-Path $Root $s.EnvFile
    $secret = "$($s.Staging)-$($project.Name)"
    if (-not (Test-Path $envf)) { throw "[!] missing $($s.EnvFile)" }

    $data = @{}
    foreach ($line in Get-Content $envf) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^([^=]+)=(.*)$') {
            $k = $Matches[1].Trim()
            $v = $Matches[2].Trim().Trim('"').Trim("'")
            $data[$k] = $v
        }
    }
    $vault.WriteSecret($secret, $data)
    Write-Host "[+] $($s.Staging) : secret/$secret updated"
}

Write-Host '[+] Done'

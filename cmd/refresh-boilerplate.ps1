#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Cfg.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$git = [Cfg]::new((Join-Path $Root 'boilerplate.cfg')).Get('boilerplate_git')
$stage = Join-Path ([IO.Path]::GetTempPath()) "boilerplate.$([guid]::NewGuid().ToString('N').Substring(0, 8))"
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    Write-Host "[+] Cloning $git"
    & git clone --depth 1 $git (Join-Path $stage 'repo')
    if ($LASTEXITCODE -ne 0) { throw '[!] git clone failed' }

    Write-Host '[+] Merging boilerplate (preserving src/, env, project config)'
    $excludes = @('.git', 'src', '.env', '.env.development', '.env.test', '.env.production', 'project.yml', 'boilerplate.cfg', 'Caddyfile', 'compose.yml', 'assets', 'alerts', 'dashboards')
    Get-ChildItem (Join-Path $stage 'repo') -Force | ForEach-Object {
        if ($excludes -contains $_.Name) { return }
        Copy-Item -Path $_.FullName -Destination (Join-Path $Root $_.Name) -Recurse -Force
    }
    Write-Host '[+] Done — boilerplate refreshed'
}
finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}

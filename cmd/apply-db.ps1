#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/PostgreSql.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$sql = Join-Path $Root 'assets/db.sql'
if (-not (Test-Path $sql)) { throw '[!] Missing assets/db.sql' }
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw '[!] psql required' }

[void][Env]::new($Root)

$pg = [PostgreSql]::new()
$pg.EnsureDatabase()
Write-Host '[+] Applying schema → assets/db.sql'
$pg.ExecFile($sql)
Write-Host '[+] Done — db schema'

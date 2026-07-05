#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/PostgreSql.ps1"

[void][Env]::new()

if (-not (Test-Path 'assets/db.sql')) { throw '[!] Missing assets/db.sql' }
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw '[!] psql required' }

$pg = [PostgreSql]::new()
$pg.EnsureDatabase()
Write-Host '[+] Applying schema → assets/db.sql'
$pg.ExecFile('assets/db.sql')
Write-Host '[+] Done — db schema'

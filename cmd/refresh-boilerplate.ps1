#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Config.ps1"

$preserve = @('.git', 'src', '.env.development', '.env.test', '.env.live', 'project.cfg', 'settings.cfg', 'Caddyfile', 'compose.yml', 'assets/db.sql')

$added = [System.Collections.Generic.List[string]]::new()
$updated = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$overwritten = [System.Collections.Generic.List[string]]::new()
$unchanged = 0
$preserved = 0

function Merge {
    param([string]$Source, [string]$Dest, [string]$Root)

    if (-not (Test-Path -LiteralPath $Source)) { return }

    if (Test-Path -LiteralPath $Source -PathType Container) {
        if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
        Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
            Merge $_.FullName (Join-Path $Dest $_.Name) $Root
        }
        return
    }

    $rel = ([IO.Path]::GetRelativePath($Root, $Dest)) -replace '\\', '/'
    if ($preserve -contains $rel) { $script:preserved++; return }

    if ((Test-Path -LiteralPath $Dest) -and (Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Dest).Hash) {
        $script:unchanged++
        return
    }

    if (-not (Test-Path -LiteralPath $Dest)) {
        $parent = Split-Path $Dest -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        $script:added.Add($rel)
        return
    }

    & git -C $Root rev-parse --verify "HEAD:$rel" 2>$null | Out-Null
    $matchesHead = $false
    if ($LASTEXITCODE -eq 0) {
        $headHash = (& git -C $Root rev-parse "HEAD:$rel").Trim()
        $localHash = (& git -C $Root hash-object $Dest).Trim()
        $matchesHead = $headHash -eq $localHash
    }

    if ($matchesHead) {
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        $script:updated.Add($rel)
        return
    }

    Write-Host "[!] drift: $rel — edited since last commit; source of truth unknown" -ForegroundColor Yellow
    if ((Read-Host '    Overwrite with boilerplate? [y/N]') -match '^[yY]$') {
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        $script:overwritten.Add($rel)
        return
    }

    Write-Host "    skipped $rel"
    $script:skipped.Add($rel)
}

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$git = [Config]::new('project.cfg').Require('remotes.boilerplate.url')
$stage = Join-Path ([IO.Path]::GetTempPath()) "boilerplate.$([guid]::NewGuid().ToString('N').Substring(0, 8))"
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    Write-Host "[+] Cloning $git"
    & git clone --depth 1 $git (Join-Path $stage 'repo')
    if ($LASTEXITCODE -ne 0) { throw '[!] git clone failed' }

    Write-Host '[+] Merging boilerplate'
    Get-ChildItem -LiteralPath (Join-Path $stage 'repo') -Force | ForEach-Object {
        if ($preserve -contains $_.Name) { return }
        Merge $_.FullName (Join-Path $Root $_.Name) $Root
    }

    Write-Host "[+] Done — added $($added.Count), updated $($updated.Count), unchanged $unchanged, overwritten $($overwritten.Count), skipped $($skipped.Count), preserved $preserved"
    if ($skipped.Count -gt 0) {
        Write-Host '[!] refresh incomplete — drifted files were skipped (re-run and choose Y to overwrite)' -ForegroundColor Yellow
        $skipped | ForEach-Object { Write-Host "    skipped $_" }
    }
    if ($added.Count -gt 0) {
        Write-Host '[+] added:'
        $added | ForEach-Object { Write-Host "    $_" }
    }
}
finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}

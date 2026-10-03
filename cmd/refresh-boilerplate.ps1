#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Config.ps1"

$preserve = @('.git', 'src', '.env.development', '.env.test', '.env.live', 'project.cfg', 'settings.cfg', 'Caddyfile', 'assets/db.sql')

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

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA+uZLMD3r9lhrh
# wjCSbsZ8yCxPMe8hJz/haeEnbVDWA6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
# R/b0C5YxX/PjyDAKBggqhkjOPQQDAjAgMR4wHAYDVQQDExVOb3R0SW5mcmEgSW50
# ZXJuYWwgQ0EwHhcNMjYwNzI3MjM0NDE1WhcNMjcwNzI3MjM0NDE1WjAlMSMwIQYD
# VQQDExpOT1RUSU5GUkEgTElNSVRFRCBTT0ZUV0FSRTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAKRICuzioM/pLsdWW/uV0Hl7Y5FHNBPTEl3X/oGK+BAi
# kC0es0CLXLykWpsJ/f9ldyyHlMzwUR1zEIhCZXEyo+uqQ8B1yWke7rQ4wkWE6/DU
# htCLSiySkf/KB389/ptcEM+jJ48DQGi0+8K6QQ02vEOAQKLfxA4Rrnl5BYY+nnNs
# Rpa+B6K40i/aFAsc60gbG3SGQePzuHHbPl6CE5AzQNY2WBpY77aonZ830RM5AsS4
# Xe7P8cDJ7Gahw6ZjLEriCaR3xBytPy63RiZdW8upuQ0AIFz4/8GVRYuOJ1wGeU53
# b0OZhj/6Z481Zry0VcBvGfHidIVkQKbWZQ2QWdkSBbSAIR92tKpSqSDy4VQYQ4RO
# l3NY/QHkJsAl6EGzQ514P+qUzkSyxgSNHZFCknqTu6gXtemaCUC7z/eLZDibw+mg
# yAuyLTZoeAlDPaHT4FOPfB8pn6UuGb/LwJwFlBHGAkaYlfAkx3BJYIsQpfPwKxfN
# Ufds8LMYArJlFZJnJ1EmJSE+qIu0cN7SyuFDAdGszrVjltYswzAfhE0NRQQm4HiG
# CWG9ZxDD1TxbhvEecgJCOMy/dZCcjEEzq4wZxSVPicn0QowKDWHy1GpgdR3pT+Ok
# zuIBpfEeXW5uW9e0yoOzwOnh1XCRp8hv+B4l4RvTEl3ccZ+PcmAcsLHODqvW4vmT
# AgMBAAGjQTA/MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
# MBaAFKF88Blhy5xs0hQfn4medNFL3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDwlWDa
# ojXZG8h5O2XzW/IG9h+GUKAmx8SCd7NuhB0SUAIgJkQlleqNoGkPuDyi08MuVI36
# ezJPirlP+IxtyaFnz10xggLaMIIC1gIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGJbmbrC
# p/gRi7zb8juTFo+DJJQhWvRM72pbWHL2fQPFMAsGCSqGSIb3DQEBAQSCAgAgCr03
# WsjxW7F7gFc1DAIHGmyiIMi8vqH5LmPhDH7OffEcZ8dIp8JUBMvQTqLnqxVLorID
# wVYgSHRX/3sYigRtNMMvYWAtIC4ylf2sByR/L0nIZHhXDL/k5R6Yh3K5h6WPrDCo
# GZWet0rrLusKeT0q7xPEnW21YYSh5V3U/XO97jgr0hsMEyRo+EaYkTeXV40lJT0D
# rjXLa1QeSDsoR+ixY9sKHrdAvmuoRqEmWaBewzKl9nSFHRZbQfhh/PDQ2YYIGLNA
# y3acWn7LxcdUen6imP8c8YNMczjWUBlGVnxLG/BR5BrCATlDcIOLAxefqXQ0wRFH
# 45bazVhHSp2SNuSiPjmgvZRWojaBvmHhZ5/3bso3UW7cWQ7gFBQ8YR/BbGoB/rC7
# 1Pze4jRWYyrwzmuCBHDD4rIJZ41I4DNCPapVO8A0pl9XPhaWRygzToFcwPioGB7G
# Iw47OKO+x5xRvaJM2vc9zR/Tn60ahAx3vIaIk5NbU2SbndHF8mEdMsb0nLRJipqm
# APHyDNQMtS/Jlx6EDZPUj9tSdJIDEcm6Y/rN5/j1PuQp8lFqgFxqHDge30nTtOzw
# rSGLAZeL5quLYg9BlG0z6vp5env30wkM+Z4R7cXWJSSVuR30CJNMDUTqy7hY40lk
# yiGC0GqewEIRU8ivObhStAAArKBY/HbOqMAh+A==
# SIG # End signature block

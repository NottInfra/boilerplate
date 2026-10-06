#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$os = [OpenSearch]::new($settings, $project, $staging)
$os.Step('unit-test', 'started')

try {
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        throw '[!] make is required for unit tests'
    }
    $kind = $project.Require('type').ToLower()
    $target = if ($kind -eq 'service') { 'test-docker' } elseif ($kind -eq 'package') { 'test' } else { throw '[!] project.cfg type must be service or package' }
    Write-Host "[+] unit-test via make $target"
    & make $target
    if ($LASTEXITCODE -ne 0) { throw '[!] unit tests failed' }
    $os.Step('unit-test', 'succeeded')
}
catch {
    $os.Step('unit-test', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDMV3Svg5E2nDgx
# L12KHqZ7oJ/Kpqwvll+rDLLkKXJ/XqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOmOPOif
# A+pGUpuFM5qfsUMLzUcOyxglC2ObXO11iaMSMAsGCSqGSIb3DQEBAQSCAgBRfAqv
# alOkZpO7lxHbh2tIvgQzPDxOz5HUkw5al8otE79KK7ZKFrzNHEYI3X4dr+7TCBo4
# BaUILLZ0Ch1dEVnQux5PHDxH9W/qSAZBb9HJlQbyAQGF+Y/O9qPjX8qQK1PMdATv
# bAVCpSAo0099nz0Ynt7ErSvwvveKf8qY0iU9IDwvXPsl1LmpzCJ7u+sWvatr8DVz
# 3ONToD8inmZi6UsogeaJaQziC52rovknzNZwkD/72ccz88IUTonfV1BVuAMbAO+e
# hEc7U0X06NElS6iNtjlUvjpmMl/svO2liPdwc0H20xdpAgFb+4qF3n4nIYlNnxBS
# 2C8n0b9mWoz1mbe4AkEO3m512K7rscO75LOy/A7Rn6CHfKHiVKN4oxcAAnLWEPm6
# a6W2FJRE/KMFfy+mLFwipEzqwqoEIBG0qaC0Wb6kuGSDKENqYRkrn9utFemquyCs
# M4LQu6MY9mRhQQoCDVsO5upTRsTvRV5iYmUUVw6iuH87lQIK5FsAYCGlJWCcJFSp
# bpQ8mpbt1+fWLfM9bBlaUxcaxqYsQH0NqVUZ/hERmBR1lnOxC9Vy0tmPOyOzmnWE
# jo54LO0h3+2aW/ZDaUyRe4CiLoMi2n9K6fL4nszNnay7FPpeOqOyJ+ih4/xIJGK2
# hZmnCyqwH8aELXACwmdlEsPBBCTFfnLvAnJ9+w==
# SIG # End signature block

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('build', 'started')

try {
    $artifactDir = if ($env:ARTIFACT_DIR) {
        (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
    }
    else {
        $project.Root
    }

    $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
    $releaseImage = $project.BuildImage()

    $registry = [Registry]::new($project.Root, $releaseImage)
    $registry.Build()
    $registry.Push()

    $artifact = [ordered]@{
        image = $releaseImage
        targetImage = $project.Image
        commit = $sha
        staging = $staging
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $artifact | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $artifactDir 'build-artifact.json') -Encoding utf8

    $os.Step('build', 'succeeded')
}
catch {
    $os.Step('build', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDqHvnpWtGbHGJy
# INfURemgZen+Y2A9Ih53n4GLCFHL/KCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBbBfX2H
# wqG8f9d0LVLl0RbPFImgK7PeM/TP5itzaMreMAsGCSqGSIb3DQEBAQSCAgApvWMV
# aFmgn3cG4Rh7PHy/7qbjo20+NvmfBck2xpasI00qD7Um90EgEmwEwLs6afsv2fnX
# sSGz0+AGC1yW2uvrs9zbAJNcJTokF/01J2PeWDtj/ysh+DurEp2YalfM7kgLOojJ
# qYCwSsRG920LGQbPqDnUSSDCgYbBRUQaB6XLoRne5gi8GHg/e1wp5i19IaozQuru
# uTS1IoVBzSfPKRS0PoiECF7kVzLs+39Pt+H5oLvRCp3RjQIdgulLj6PUjnFHnlF0
# ud8WOx1FDx2p5/nUnZ2Mv/a9JyaBajRVavmsFnGcq0JjhIT9SeHAuiHaQTt/kpaP
# QUDSHYUSrrjA6Z14j6C3LaKZ/ntx7tqqRPv/xr7xTIthFq+7nrLnGlhalIPjJ+o6
# 3SQrpeqwCYqcVkIkUs6cxF8Yh3zxo8ZFelA4zbaIfKQkpM4etOFexputw/nqvL6A
# qVKaLi9nBAYBi91UIQGqnfX0ylf6KMayja3dJcOiKIKMBZMF5rP1YLG8eKo7pUcM
# 6oN69XQcPDHubk9+fMxBQysWjgaFNjRR8ZPoMZpiHILk0GO00g28EtcuQ15fE8e/
# e/KN7XlS5lTQnZDvCeTvuVxvPMYYdxJAB790HMm8TXG76rkvxlIxKWptHbgkoCLw
# Jb0ap3yOw9NC12T6kkDwNc+vH9C0xblx53Tw2Q==
# SIG # End signature block

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$registry = [Registry]::new($settings, $project, $staging)
$os = [OpenSearch]::new($settings, $project, $staging)
$os.Step('build', 'started')

try {
    $artifactDir = if ($env:ARTIFACT_DIR) {
        (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
    }
    else {
        (Get-Location).Path
    }

    $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
    $kind = $project.Require('type').ToLower()
    if ($kind -eq 'service') {
        $registry.BuildContainer()
        $registry.PushContainer()
    }
    elseif ($kind -eq 'package') {
        $registry.BuildBinary()
        $registry.PublishBinary()
    }
    else {
        throw '[!] project.cfg type must be service or package'
    }

    $artifact = [ordered]@{
        type = $kind
        commit = $sha
        staging = $staging
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    if ($kind -eq 'service') {
        $artifact.image = $registry.Image
        $artifact.targetImage = $registry.TargetImage
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBGwkv2ptV5V73f
# 5yh/jHHN7uN/dAeenoIENiVNFvrOZaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPkmLrT1
# 2Nc9PaosRzjo/P/SCU6szcwos31bwmeYiq1NMAsGCSqGSIb3DQEBAQSCAgBqEO4W
# CVwYBzie00R3rHNP3Hi+bCinuLTAs67rYLLgSyAc+KiMaSkRqDAkdKEDAYyj9Cch
# Mu9ADH5wGK9k+LLPsu1d8n91ywt1uSEWGCIOtZnclgYGxLgK59rxXE+PdZRhdkkj
# IDLHwwtFmB4B63+Ww3txP9SDnX8mu/yq7V246fIBdp8oWwI2dYP56nImjcASBorV
# f6spjRtHzUlFrH1l75V6qblAw80faMmVTbqoajgvn7AtFKSs0FpJXHVLD2NuIDxe
# ZqVyhZThzYd7e9ZwcNV4uCE7S+LWLouI1eVnfAiHRZLHJRdDBNQ+eFQ9Mfssecc2
# D//KK7vm0pY0HnAUEAw0qsLxl8nKjRZ3hjDs9lci4TqvK++xqT/R1SxX6JAkDVQl
# o5iViI/TTTcNtMksc2zlPRPoqAKpdgBdaiLubGjI44MDagQWajUnV7abBhR+qqQL
# JdsPwGLNLdivN7iNjDcWnhNiEXDtvSscOX9MUDDpa6LCzzZ1FgwgLclpshCJvDr9
# 4N81LahztV4RmFzJaPVDa5eHhuEMkNXlZtzG3eyaTI9Rnv/n0wMG1LCSWdmE0ioV
# QMPzKV7sK7TfhTPpc5ku/PePRLhM9Yc/TvjSa7fbMZs0Ct6H9TkhIGkmoi5hGUL0
# cxBnDpLU4bbIwz/vr3Ler2ugeblMj0QnJIvVMg==
# SIG # End signature block

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Env = 'live'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('gitleaks', 'unit-test', 'semgrep', 'sonar', 'build', 'syft', 'grype', 'trivy', 'deploy')
$env:RELEASE_PIPELINE = 'production'

. (Join-Path $PSScriptRoot 'lib/Vault.ps1')
. (Join-Path $PSScriptRoot 'lib/Yaml.ps1')

$step = if ($args[0]) { $args[0] } else { 'all' }
if ($step -eq 'scan') { $step = 'trivy' }

$known = @('all', 'scan') + $All
if ($step -notin $known) {
    Write-Error "[!] unknown step: $step ($($known -join '|'))"
    exit 1
}

Set-Location $Root
$project = [Yaml]::new((Join-Path $Root 'project.cfg'))
$projectType = $project.Require('type').ToLower()
if ($projectType -notin @('service', 'package')) { throw '[!] project.cfg type must be service or package' }
$imageSteps = @('syft', 'grype', 'trivy')

if ($projectType -eq 'package' -and $step -in $imageSteps) {
    Write-Host "[+] skip $step (project type is package)"
    exit 0
}

$name = $project.Require('project')
[Vault]::new().LoadEnv($name)

$steps = if ($step -eq 'all') { $All } else { @($step) }
if ($projectType -eq 'package') {
    $steps = @($steps | Where-Object { $_ -notin $imageSteps })
}
foreach ($name in $steps) {
    & pwsh -NoProfile -File (Join-Path $Root "release/steps/$name.ps1") $Env
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCRQh0e0E+0VNga
# qhJjxjZdcXuRO10Kej1AM7KkBYbmraCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIO9PhGbp
# Zubb2dN+i0Uud0szCN83Lk6hfdY66I6lUZrpMAsGCSqGSIb3DQEBAQSCAgBSq0qr
# b49SV7UnkvutpFt8fT7FjadDLJE93AhASwtBHFc6LDf2P92ZEM+/Mf843n9m+GD3
# q5raIlZcZonCQawF/poU8STKFrTdPclkT0nyRd34fI5jvYbfl/jrC76zsIWjsWja
# TxiyDkHxsf5m2kCf7KbGpG5TzvU7MpuSxX7c4XYiXotWqNNZD4LFlGswhR6Njk6t
# TIO+Q+YPPae0DYyFLPCTAKFESusi43HxBlDZ+89km3k3ul2UZe6jlSpvj6V1wGkf
# u3ZaduNFnKmbf9d9eGmpXmTr6/y0PIm800AJO289ad0+sJOysE1ouCkJJyLKTeHM
# h06F35bqW3qkY5vIybWMRdiIHHZ5wucYpDHc20uIh1H9OvwNVFFFVcN9iN48S6iQ
# pQpdvsR9yUCAfuyF2il00oLq5eNe9QMgbKl2z9lfp2IEq1ES5B+7PvBQI4VHkIOx
# EZJywoMsHe0m+111xMiq4vH5jFJk4dxLtU1KxoARQ1icyVouWgvpxd1CB4VddjYy
# SEBSc6Z2PO9n8TXx7FCN9MnD2UHttZ+r4QNgcTwv/soo7K35R5mbCdMg1g59iNYf
# Mcib8kPsDussHDkU+b8eguJn0gXEzYiyE9Qe54cbwqOFKOFNnFZBaY7USspIpk0q
# YFRIm4I+zbAS6cUKRxpLO/6d1mpMksbtlCV6Cg==
# SIG # End signature block

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Env = 'test'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('gitleaks', 'unit-test', 'semgrep', 'sonar', 'build', 'syft', 'grype', 'trivy', 'deploy')
$env:RELEASE_PIPELINE = 'test'

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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDKXTNkl6jBi7nr
# Tha35GDATl5at3gQzv+wVpfqt//kZqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPeQ0TXJ
# ZNIb6UC4uZ8tfqN9qt+KjiiY1g61OsbSpb32MAsGCSqGSIb3DQEBAQSCAgB4LkHG
# 9kND9Hj/joegtszlL4HeXsnveex/W+E7+DYhZxY3G9oHB8qTUNxDWwLzWhtf4kOA
# GuhKPwLRAER5ynCB4X40qPv0Q6VJeibvIzVLBTarcILZSwxdxmzFalyxHl0SVpOB
# u2VO1q4lJrm3CUkLsbRM+luHtL3yxAGLfqFkfl3JCZDGA1aCBZHvek59Xn86SAxa
# l2tjrqJrv2CczRqIVtH+ltgu/O9Gj9/KEuZaH2Omai7mIQaxFuXzgavwCuf3thD2
# cfUjO9wi5XBTJMY3kzsaJLALRE2fCD4B3WqR8UvWxg1mou9E1xqeKs/IOQzXVTNx
# z1odD4ztjc6wNZfqhRrJcfLtb+O4PZZ0v4qYvfGorRkKgvMXz3uxwVOXSNZ37G7k
# xRxtpFZuUWtYZic4UR2wNyJyLpjBq7h6ms/ArJoqZS3xFLhfulkFnxaJ/L96sDyP
# uh5ibhuGJ3yJn9lhQAvK8zXsiu8Y46jIEG8MXjhYwQSJbjhYx88WoLLmuRrCxozw
# wdO8gkx99qY34O37bFTWEFAIvBn/0MocM08CRLoLB1eYHMPMtqv7wvO5Y6KpIajh
# VH8LTILR6luC41q0W+awlbh09Av3573CB9pEapwpuCgAJL77PCelOHYNDhGgXuHQ
# 8PhOwWi+zlxZatDkShY7YEe0wU6oe3oazX4zSw==
# SIG # End signature block

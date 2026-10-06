#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Syft.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertManager.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$release = [Registry]::new($settings, $project, $staging)
$os = [OpenSearch]::new($settings, $project, $staging)
$dojo = [DefectDojo]::new($settings, $project)
$scanner = [Syft]::new($settings, $release)

$os.Step('syft', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
    $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
    $os.Finding('syft', 'succeeded', $scanner.FindingCount, $report)
    if ($scanner.FindingCount -gt 0) {
        [AlertManager]::new($settings, $project).Alert("syft found $($scanner.FindingCount) finding(s)")
    }
    $os.Step('syft', 'succeeded')
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) {
        $report = $candidate
        $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
        $os.Finding('syft', 'failed', $scanner.FindingCount, $report)
        if ($scanner.FindingCount -gt 0) {
            [AlertManager]::new($settings, $project).Alert("syft found $($scanner.FindingCount) finding(s)")
        }
    }
    $os.Step('syft', 'failed', @{ error = $err.Exception.Message })
    throw $err
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC3MRnpmkIkms2g
# OumgAShXxl+iGD3/qfBpULIHOeFpf6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIG0WwjgL
# YIkf70h3+Z/Q3JabGwY5+BwPiiYRz1uIp4FEMAsGCSqGSIb3DQEBAQSCAgA1kmQn
# QuQaSnwXaQ2Mzz423MWptf8s9QPuN4jcFQR4tkYe+KrQ5E+6BP0f91pBH0qe5Nfj
# VrRLb8p5rOjspgZ6ZgrZCoPkbGmesQzIOcmjfQxBnBOhIMAPsMjyuXrQhmOT/qlI
# GD1IF3C7ITSC2CguAZ06nJ0BywHrugy0Cpw88WTUbhXyTipd4aD/GZl7LyU6Wh2Y
# emyxunty4ICOnVTyZIu6sYV/BSIrBoU0n7SIJg78H1yWd5GirFXA5boUDVEwZbTG
# 7dJ9XqWHPsJIhZt38PZCTh8qEnqLvvkir2ENDTEnyO3JtVZK2yfEDagl/yNm16fH
# INgbrxLp+pqobABeUq2SLq0Ww2jfQtUMzVxLVWKBaCbOMjXHxETjWz20BsHTN6K8
# YDjLDCzB31bmoO+QnTeF2JNIR4++pAEDSJ/4CejGtslHM1sRCi4sBcLH0XD6Nv+L
# +8UkqRuIycIWOn7b6lYz71Aj6hlI5dkYjYn6aMNO3K7PzfPofVSN/eM2t6WzVg++
# pAE9wteZHs8WMFOF7HEJDiBiChtUYvaAngwWbHF3SrKNszgA3y8DyRfuUAQnnKgi
# sgtLaUV6eH+nSMgQu07RE+ckziHS7rnnPSCohEVV6ZabKeb6Pfz32PwN3VWXjZCF
# 7kkK0jO04aj2QnjD5C4MAxmtG1BCcZ3Z/G3yLw==
# SIG # End signature block

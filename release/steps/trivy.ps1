#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Trivy.ps1"
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
$scanner = [Trivy]::new($settings, $release)

$os.Step('trivy', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Trivy Scan', $report, 'trivy')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $os.Finding('trivy', $status, $scanner.FindingCount, $report)
}
if ($scanner.FindingCount -gt 0) {
    [AlertManager]::new($settings, $project).Alert("trivy found $($scanner.FindingCount) high or critical finding(s)", 'critical')
}
if ($err) {
    $os.Step('trivy', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('trivy', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCb0ZO7NhSzIQXo
# Pa+SZONVrQ/dTeM5nxo6GC2Wpk2fA6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJVKUnse
# T7jMp/VxJTKwrIGm2AOa4ImGn09WEqewEkdpMAsGCSqGSIb3DQEBAQSCAgBeQm1U
# kKoigtlyEdPEToJiU83wsUMh6o6HrwqchKy+6xJJzwdo+tRh4L4f+rp/63pTVoRW
# i8cPE/jemL8eoe2Kf+M/JdJ8iZF16kxyYbNRtZAN0unSfWsLkAhgJbpjAoqQixOw
# eKkZZ1kCDviZu5nwUI8uMs1vULOWRBvHzDBPAKxWDoR/r+S9lgJ2qiNpm0EluBOO
# f4Th6tIm+Cbot6XqRyfnR6ZJZgavPmvKg3wg1l1kqq4Z6P2Hs+RQtxU39ki6OKDQ
# QtTZssGHBxSvZ5urT47fppR/LGkf6sklMt1+OwD1hXziYNyWi0/VFWssimOw/9LK
# H+rX1vvAcWA5SUZxdstk3omFieFFOxza5XLkdZd1kgeR+4oZGRT7EcSDzPd7pAQl
# O4WNKEmqcIQ7VFdMzBPwTlbMpTb/fwgMaLbYgiA/V5eEITJO5sxhjxZt1GpSkxSQ
# OjQkQBxf4mgoIJf5IufkE4vXv6KKQjlTeO146MpmgsQOiPaTSeb5z53hoSsrnFgW
# U4lCS1nCvNtEN9+0LmNliMA1UWZPj0gaPFv7UFE3/w/DeUfCI5FNwLPDYhDpzPPA
# 40bKDQS9nR9Tsbo+RsdaFKJobnTo0EILtGkGo7pTuWkpTBhnkW6zAsmPsH/XEEQq
# CVnAgcF88TpCXRWnNzu8AZV2V6y+qln2IFqy9A==
# SIG # End signature block

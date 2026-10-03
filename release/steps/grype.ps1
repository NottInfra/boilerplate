#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Grype.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Grype]::new()

$os.Step('grype', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.Scan()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Anchore Grype', $report, 'grype')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $os.Finding('grype', $status, $scanner.FindingCount, $report)
}
if ($scanner.FindingCount -gt 0) {
    $severity = 'warning'
    if ($report -and (Test-Path $report)) {
        $doc = Get-Content $report -Raw | ConvertFrom-Json
        foreach ($match in @($doc.matches)) {
            if ([string]$match.vulnerability.severity -match '^(?i)(critical|high)$') { $severity = 'critical'; break }
        }
    }
    [AlertMgr]::new().Alert("grype found $($scanner.FindingCount) finding(s)", $severity)
}
if ($err) {
    $os.Step('grype', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('grype', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCChh7SOOKV/cHc2
# Xu5kYa6knPdxEhNwZ7RkzrTVQkKKr6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINtCxSDg
# ggbu0NNLYQFshPBDxhGUxeYUinHLumj+4SlcMAsGCSqGSIb3DQEBAQSCAgChRQcB
# mVIKyr/jFe8kd7kJy1sB6mYfkiZ/WX32M7CaEwTwz5M7g3VMp1utRCVgPIaujBa9
# BQUjg05CyaPJHuSi9V7TtDuVMOYOepfy3ueKbgt0JVsoZzXXtge3CUjInfrhFd2U
# rgIeT0ZiyrkhxSviZNDtRW/PWDg0DTscwwl/j0wIqCwzq0xEDRER9wexifHUw+D7
# p/yX8aAhmP9RbsI1FpkXgb22FIdu/ch2mjJ/5UqMpuU8LMvUMInZhx3gp7a+KZSf
# RgY5LyrTTD16I/04qmgY8nKm2OsE3VremJXuiVQW76Zcp+qS8Kw4J05LZ2n71uAt
# VDC1JGpPSlUrSC2GFRlVdv/SQmPwqrTZrKGZfP5IzQsomnVK/LdfHq+aEFTgiJ7u
# 499oSr6z6I7Wpu03qVBiVD8DIqh4ofXcmbmu1pVI/AZURl20HwiRraDrjOC/H4zc
# I5V7SgiirqXHxwK6lLk8avQiOw6IahjPfebt7yodBB0i4eankPnjcRV8dxsEy1TG
# XhxrJuPCEm8IuK6wQX1voFsI+lI6xBEZFHgQCreBiUnmRWRqJmRRTemEw2g85cuk
# DiAsfCNvSEe4Sj0+qGVQzzQlMiFnZ87T1P9BHj5V2V7N2s/2wKsYFzhFflmBsB0s
# PxKuFEG0n8L0jaa1c9U5GrBHoe/yrCR5P1Fn6w==
# SIG # End signature block

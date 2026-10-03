#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Trivy.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Trivy]::new($project.ReleaseImage())

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
    [AlertMgr]::new().Alert("trivy found $($scanner.FindingCount) high or critical finding(s)", 'critical')
}
if ($err) {
    $os.Step('trivy', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('trivy', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB2biFmFvjClp77
# PmDOfbTP8baHWESWCWs5NDsETP2OHqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGX5Jiym
# N3Xjkm3SsthF51hCj/FyE6whvC56343uq7kUMAsGCSqGSIb3DQEBAQSCAgBERV/i
# g18IiMtnOQK+vwigNGay4IAmnmalRHSHtS9v5PReJtAnmxIh/PFLwtqkcAYps+Pl
# jDdzmjsDPJ6cuRhENKqP2tvR3rBbFwqGcTYzskTIQ/vEG1Ivzi0qCZMt4gKTQXU6
# d0RNblX8YCXmWRZzS9Ve6UGHENwmcqgBSew8B7M16AMtETmdOLQctv9jZdeckkCY
# ryc8WAPK+kgHnD0ylQWk9TDPyJ3UaK52ajQDAOl4aV4PSOroW95pBr4XgU86W129
# CcWkkmFVelr7/XIfHPLfGw+nH/MO0/yhlfVJRTLerFtmiwv7LcloTnacrorKzyoP
# Cz2ndRsBX0sQ41X+WWVakH/esnlJn6dRCKXswFy89QImzVTASckt5u6Qt6srIYog
# 8j706TxcsTatSKs3B8t+4W8zcAkhkrvlD/SsP5/U4gO/93ytoQdCHrtxGY701lwu
# yXcXorAhSXVNHhTWyXr4z8148a+rXU+Rkq0/Cd1/+mnWqpWL8Z+n6NK9hK8WImf4
# 5GDYu27vNCK59kN5lrsnTtUp8wekyqBe2MKsdoJ2eT8JWRozaOWTWRsVZdTzGjQb
# hNLAv/ySZYMC1oNfSejjrve8npLOq2COcdrSjX9AK+J77b9MskkKaOsEIJrLZXVs
# C5KJ3opmNX1VJgnhHJtQ+yUr15GfE2gt45mmlw==
# SIG # End signature block

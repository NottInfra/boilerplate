#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Semgrep.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Semgrep]::new()

$os.Step('semgrep', 'started')
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
    $dojo.ImportScan($staging, 'Semgrep JSON Report', $report, 'semgrep')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $os.Finding('semgrep', $status, $scanner.FindingCount, $report)
}
if ($scanner.FindingCount -gt 0) {
    [AlertMgr]::new().Alert("semgrep found $($scanner.FindingCount) finding(s)")
}
if ($err) {
    $os.Step('semgrep', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('semgrep', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKuDtt8g5e4SO2
# BT9WEjMUrilbjIXpj/VMnphyy0QC36CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEzn58Ub
# lTZnjW1JQ+eD8J0S49iv9QIr15yTyc5b8MT1MAsGCSqGSIb3DQEBAQSCAgAJmsyX
# 51UWlOn4dXOdo+ztrzwhVvOZT/vMRL4AQR+Xr/7dl+iXYbbMm10WgIAKNP6UDQpr
# q75WNxFdxYEP7MpzHXjLRw4u/1wTqSXClYfqAE9V0SaXYRIou9j+WlGFpQ0o6i1W
# /As7pRvqfWNd8lmuZMoY881M8TTlqNLxduzJC9QHhLJdtvhgHpkYzVtNZ9A6LAm7
# OdyyfzMDFmmAk+FgrbmvU7iQjpX9xMXPXfgRCpSALmHMG8Yk2ye8ElRNMXleoXvw
# G5V5I1eF/DNSbng7clwiorEeDDOlBaf5vQZi0Spcvq2OZGi/2Qo/AaL4lG192zLb
# hNSflXcpfbhBqXGG9m/gQJqJKMgriL/2WOH120eT8I2WTp8h001I7JlF/HtfUJdc
# wnC28Oe6z7D/Dbm2ozsqQvQCZsyWNXbpB9jLB7Zs1ltdWyvQUHP7U7q11pD42gKt
# WXRrmf0eDT+0ZXKlTLyflUwwEeBdGLxqamAJYVUcwPsALH2hP1usIj8x51AJlvRJ
# s8WyIZwMHQC63dE6EcAURC5WknfkwkuliEer0Z62wQjp9TxFrfc4IfqVoJCODKXF
# mD7VC6Qx3JaC09DzBzfKvORqh4dy7QUS+WEF7kuS8bLz+I/bdFLrTGyGPnkeaxUq
# L8xB3w+WWD6NT2IB0/3/wu9Qn521WTM6QdPyUA==
# SIG # End signature block

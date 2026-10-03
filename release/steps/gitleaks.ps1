#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Gitleaks.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Gitleaks]::new()

$os.Step('gitleaks', 'started')
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
    $dojo.ImportScan($staging, 'Gitleaks Scan', $report, 'gitleaks')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $os.Finding('gitleaks', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $os.Step('gitleaks', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('gitleaks', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCZ+QuUW8QzDNfZ
# WG3rHiVzrW9yfM7EPB9caCBOJJ5pW6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGTPscKX
# YC2hT8KGiYmhVW93+S3Ji/DZhVF8HwlmdRk3MAsGCSqGSIb3DQEBAQSCAgBQjEiJ
# hWATs1JEUnJ4N1VDqDayr4esk3kj5LFCGSjsjWdMSqLNALVUpasaP9wJM9QgrSRl
# mHqBPEbtKmAYsuRHvZ9PvH7+tvcRmdUCTMi3Cvq8FisNH5ZaDQBXV0GUOyYNcVVq
# fa9He/PaJdCKByrkJOatVYi/bO+zk+0FFV7kjzxezGJQpAsLY9e1LV6CEPbohjdW
# lWWmoehdEFcZkEUKZ2Wia90Qv9lsHBuzrMB3DL9BXrW996w2n8EunuKZ75RvYPZb
# ZlMrJWMQ8k7pOU6ybIqC6LllPonDyLbHgotCujkXt89qNsB/Gz/op2KEnyKKd6oX
# r2B+9TlyPs8KFBPnALg0nz5j73WqCV/5ir/h7LDNbuz40KSUB3YnFs5wpdlvXJQG
# 97YHdc7yy2Te2iuzvgfvNs9bsOwQwPozd+q5pSIPAgkqu2jO22ZQpf1jA5HRJiYO
# 8pSTsZV1mUOnSOqQ83pes/Z1GwiITwwh/RxOtJnHqFz79PY7a+kM38nQzocjwdLc
# W/jRyBdCK9BqiKl3Nd6Hwxf/Ka3SYKEPg3k0o4IXbSNw1j55BEPOj+W3S4+YNOzs
# Xss0KjUr6I+uJ3/HyAj2Kkjvr/zhBnqkIm4cllFGTynYPANuzPeaKFxrrSCWkHKb
# I7ciCfcZwaAJEonVu3sZN4tsJSRgq9RCRVUgKg==
# SIG # End signature block

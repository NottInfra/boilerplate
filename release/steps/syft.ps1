#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Syft.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Syft]::new($project.ReleaseImage())

$os.Step('syft', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
    $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
    $os.Finding('syft', 'succeeded', $scanner.FindingCount, $report)
    if ($scanner.FindingCount -gt 0) {
        [AlertMgr]::new().Alert("syft found $($scanner.FindingCount) finding(s)")
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
            [AlertMgr]::new().Alert("syft found $($scanner.FindingCount) finding(s)")
        }
    }
    $os.Step('syft', 'failed', @{ error = $err.Exception.Message })
    throw $err
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB81Y5p2kbMSpqn
# JR1zuFnBFIkTh7Tl//ZeinbViyCCFaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHi3SFCh
# mzptzpjfaD9ZZxdsXvHvVgSmyJcdfq7J6lNdMAsGCSqGSIb3DQEBAQSCAgCIbkgn
# TVlBTXD11HhXQIBo/Uaui/NaAQOXDHx2LbBCanhy+GJAKoY6C+1QUCY0gNBn13JY
# srcyyoxnb3OS46gEzDt5UrOYItMMg1iu2efpF8SNjL86IioW++2qWigeKGbmsdky
# PR/yO8THfINY+pT7QpfhT/H33kPInFW0rveOd5A9ljIWXk2m4svyw/1Amz8CRJIC
# assfNrPvhcJ1bk3U//rqOUXbz8I2eFOz/6wdliZlEkzRp8PJFFMMt0As/lIJAeVD
# Z9vZDh7xXLV0W+Oaqn7e/rr3Nv31jIe5SP7rEONo/9QloFnmbJHmjf5S/ud1ccNC
# CV6+sCfYv6phvYO0kZwl6l7DLrcgvkDO52Y+oFzLZNW4pXZ5aBexrXy+ZnWgHJMF
# DgZ22xgdP7UHaAE0TtmURrV1WJffA/+XyBgrBWj2wv7ChdFxfgNEHH1ncyJal2Dr
# c3xuMyzvAOlkN0YJ192lItW+usLtbwqm2sb576TZMP/UCEp8LXXDRipF1iYFoXRv
# EDc/KIJDqU5blUoBmo2r64cgcn2nPOzIn+P65aBAYqNw5YzGj4GpWHbVAouelB6U
# UWS+sOX/YyWn85mFZaytp+eUVLzFX9ybUZJVFP1EHZe/n/P2ydMQNTU2upme7KMr
# cI+yRtPM1HjSFnrJJH9ETJW8mPFm8W0YEME+5Q==
# SIG # End signature block

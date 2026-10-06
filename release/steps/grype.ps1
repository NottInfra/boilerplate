#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Grype.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertManager.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$os = [OpenSearch]::new($settings, $project, $staging)
$dojo = [DefectDojo]::new($settings, $project)
$scanner = [Grype]::new($settings)

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
    [AlertManager]::new($settings, $project).Alert("grype found $($scanner.FindingCount) finding(s)", $severity)
}
if ($err) {
    $os.Step('grype', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('grype', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAGmIOSbvQoRqoo
# dbQahXzaOFwZ+pF5I8fbnEfUgxao06CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIADHaC7D
# ZT4924NzevTUhg6Zq5DnLJ5GW0V4fgFC1yDTMAsGCSqGSIb3DQEBAQSCAgBF6wWW
# WatD5dyscGjs2Zn6d4S9EipHX5OFO4YN3/yOqw2tmsDY9TgFc1WR/2c+ALc/H+es
# RV4H1zZj2MqXmXJy+MXkRdai4SbPB/02Jcpja/rIxkOiS4T1HvqrLLfyZiOFyNcz
# 2kzczTIuxc/CQoaDdKDQIIYOCpBnT4bn/xL4VFBhcKETPekBCx14aMuOzeb1VdSS
# 9zo6+i0USBMYjNRGydwGDJCx1X5ntZp/ITk+1+Er4AwhQ3pzxNJLYm6zPJalVnpU
# jOalGTtXX3hwMG/gWsJ1Rt3nbfM47pVKdTvxX0yEiew5qj/W3+7hGkDbghZkZhfL
# iFp7bR9WZKVHzmL/95P5cO3o9h42j0ndmkq4b26EWVZZ40S0fYD4dRHNelbkRPkW
# ghXgTx8CNf1NwFotvmt9lbgvWcwu2PMqR5kwMk2krL34e+Z7Eej8bkAZVlJV1hm2
# Nkd61KVDFB5FqM7D1G+oR+Upo5aFGK1lE0BfeXxSk4yAvRf0slqQQSKqEBho5cfy
# I9C3vPoCRCQUTxU2rS0yIxIjzNrp+ZF/EblDEWcbArFaIvLYql2gbxOH8YuaNZmp
# krRcX8U2FFzxOK0LoakAxwejhcNGgnjDqQk1riwq/C7QrlXCD1+4puF4qkvLeuSF
# men6Od/RAoqAdyeEtrlYruToPdxxhVIQW0Z74w==
# SIG # End signature block

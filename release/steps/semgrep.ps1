#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Semgrep.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertManager.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$os = [OpenSearch]::new($settings, $project, $staging)
$dojo = [DefectDojo]::new($settings, $project)
$scanner = [Semgrep]::new($settings)

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
    [AlertManager]::new($settings, $project).Alert("semgrep found $($scanner.FindingCount) finding(s)")
}
if ($err) {
    $os.Step('semgrep', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('semgrep', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDxoDou/aKQnuok
# dCo2vAeVp023ySdKJugVqYxRcA4jzaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBE9Czke
# cEqdYfvfWCmabM/ktApiG7ZwFbth1MctQVKwMAsGCSqGSIb3DQEBAQSCAgAezlqT
# pA9ShxSfrVn4dXlihHKihTsJ6KdmJpHdm5pxnAYtO6cUI2j1PROg7tqmgEvbHhel
# s6yuhk9mkqA39XJ4QZwnigw71TLXOq0dslmqURXadrdItLHbwqBkYiJe9Ov9/2ZI
# xOgFxYFYHc7cPf9/C2dURkLXbKnKcjYOIDo+V7eLCxbHy/5yidLMfPjYk2gRCEJ2
# BbikNDNVhzMCC+LhvvOzBYeqm7eXSrFHKfOqwFqbRYz+nNG3okdlqIZ8EJTnINC+
# xI27wv9IOu0PdkQ6OYzF3h7V6K7nFWSBkSVlqLQ3/+Mn1JvCQazHhhfJAjzXDFU9
# Utnbnyp8dkhvaAJG40/aI4ONg06grUZzFSBOMS2JzGmSVPa64TmWP6Zka8kz15vz
# jw809dsCJ8QQ4lIZRiRjZnjctqE9UF8qs3KYO6HwL5sqi55s+9pEHN+DhFiqL9zd
# c5bHEb8R4e/M+gZDTS1AEpjNAs7QiE/Y7EyFUNebd/Csyclqr+2krisRu+Mlxzs5
# VmIYXWaqLaev3bCnkGWddYVCPWrW9bsMRzCQg6ysRKxUADRyMwd5CLLPi/9Z/42X
# D0qj8xyW88DuHbxX4MYRxqCdCuYzXtF1/gAMiW+kixaBLNjYopYSD3E6W+LJYHMe
# OIfH1YJKtLYUB/092LgUuRZeuxYYcUdpRVsL9g==
# SIG # End signature block

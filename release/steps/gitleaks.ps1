#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Gitleaks.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$os = [OpenSearch]::new($settings, $project, $staging)
$dojo = [DefectDojo]::new($settings, $project)
$scanner = [Gitleaks]::new($settings)

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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBHDPm44ILBPhsS
# szznsvFf76h8Q3r5dXtRAXuSAso4b6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDyHeAEJ
# hQejgWJib5mHwbjwfeJL69/dYOD+7eQw9AHtMAsGCSqGSIb3DQEBAQSCAgAomfE9
# YDSyHH4hz7XEBdNmxZaU5x6VCg4pOjXsqkk7f+LkxX8eRb7zuC7FyoxHmEE0dKnU
# Fuu+pGIocL1ziealcvxOI1Gsyt5UYN/iy2clFWB/bkhI12+Yti3Jtk7HyJkKXDfW
# zfioYsyCw33sPuuszuaLZsS6LHZ7WW0xs8z04YFZqH/vIutvJikQizUh04rPU7fO
# wHdPPIr6vPZFQwNjuV6cVn0/8TaUADaI8DEpspVTcZ7Fx/25QidD7Ct8w8T9rLDf
# jLPIJWnRoWNHCre+h0C8iFvlFKMj2K0xfD/FRhaoCcGrCC4Fq93TBbO6fCCLFxMw
# kdtVwcCAOx4yFolzeA+pE6p8CAmRqrlkJtmyadtmKjuHLVM7F0kBuIzQRbWtviWj
# omFSVbg/cNHzSG+XXX+0K0j+0LJOyuqLFCSwNg9JAOeI4zT1kp5TGOu/00ndrFni
# GVq0U/tT59Y+OmacTPHD9cUCd+RYCG2L3+BcXC9rk273jrAGdbGMorFNnCxKdLEp
# kqgfTRA7Iz4gsgdiQaL7QiogQyz3YucJS5jNDhRwy+GQc6Ba3OrBwHF/i8zuqSDP
# MZJljt6s3QyWZuLJBu2ZMCa/a6cPc5EOOldlUdJGiPh9+CaykwYOmESq+k+FCcal
# XZNeqn7kl2azSkcQV0oeu2k57RxjJDvjgWhgnw==
# SIG # End signature block

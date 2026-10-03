#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Sonar.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('sonar', 'started')

$gated = $env:RELEASE_PIPELINE -eq 'gated'
$baseBranch = [string]$project.Get("remotes.$staging.branch")
if ([string]::IsNullOrWhiteSpace($baseBranch)) { $baseBranch = 'develop' }

$sonar = [Sonar]::new($project.Name, $project.Root, $gated, $baseBranch)
$err = $null
try {
    $sonar.Scan()
}
catch {
    $err = $_
}
if ($sonar.FindingCount -gt 0) {
    $summary = if ($sonar.FindingSummary) { "sonar quality gate: $($sonar.FindingSummary)" } else { "sonar found $($sonar.FindingCount) finding(s)" }
    [AlertMgr]::new().Alert($summary)
}
if ($err) {
    $os.Step('sonar', 'failed', @{ error = $err.Exception.Message; finding_count = $sonar.FindingCount })
    throw $err
}
$os.Step('sonar', 'succeeded')

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA/Gf/P0P6JT9KL
# MqbnWj+XRtwd0DwXGNbskwRdVMjHGqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINsYyJHI
# BmdoJfn66ywB0ti2dhyd1xLk+DNxNWGnuC66MAsGCSqGSIb3DQEBAQSCAgAinh2o
# QKlvakxoUxO/c+pjze7Tq5QMC7bK5Vd/zbGpdpyPhep99Xop1Nj6ctH5y+eFTKR4
# QqEH1J342Ua0iNJ8IW1ZK2Mf5QYvD7H5hJ7Xm1rZD88Jms6hQ/Z0CAY/ywlt+8X4
# reVhpYBTBQrEmrGDwdXNnIckl0H8vSJyh/EP4ZikRVPSc9YYGswZCh/3X/844BDx
# Mnn7UyAjdyQlFQYaEdcgIoSivftVGLGuOFUJ4Nid8jraKttzTctoxqNnHKYkpjah
# A2dzvIBCXcI0C4pmzAdWV3fb3xaeESKcIoAvKAZHMMOVWmsDhGLLtB5Do1X+vgjl
# SYCRz+hsffqybYbBOLf8HCmJtcvPHsznZGByUOkBTdDxMvKUtQlgwtpzFi6v9b5G
# UZQ+1EiPteNR16CShFu9KZMrxZxevfiK9nnWfoyFQEpDzZZ3XSZsiponVR7+Vmf+
# 0Va3dlpRby7PgagRzBNcy2UEZ3YI6HkbOgLrDq0oozUh+lIqDfANOANmEJXUfyd9
# I/5WohsdZhPDyy4I13uEQKnhQtbWhKISHl7slVuDeg0KWR7k5TCDsOwoS8RgecYE
# +ROy6Pa5LOznXFrpABJQ2ZqunIP7on8YjzP6Gi0jveTBTdjjczq/1SInBRwz79xn
# tkNnw1CHhXQ9JemDZrr7xs0DPMTzhPmIniyMAQ==
# SIG # End signature block

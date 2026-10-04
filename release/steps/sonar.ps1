#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Sonar.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertManager.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$os = [OpenSearch]::new($settings, $project, $staging)
$os.Step('sonar', 'started')

$sonar = [Sonar]::new($settings, $project, $staging)
$err = $null
try {
    $sonar.Scan()
}
catch {
    $err = $_
}
if ($sonar.FindingCount -gt 0) {
    $summary = if ($sonar.FindingSummary) { "sonar quality gate: $($sonar.FindingSummary)" } else { "sonar found $($sonar.FindingCount) finding(s)" }
    [AlertManager]::new($settings, $project).Alert($summary)
}
if ($err) {
    $os.Step('sonar', 'failed', @{ error = $err.Exception.Message; finding_count = $sonar.FindingCount })
    throw $err
}
$os.Step('sonar', 'succeeded')

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCrbBDYezhFP6pw
# +gmeTQpS6dAJL+OXpjqw5CO4hRh26KCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHxl2OND
# dgtg+hTREISI2gxfJl1QC5LNntdLm5YGOyizMAsGCSqGSIb3DQEBAQSCAgAKSRWm
# LzDFxGLRnvXdxjJAzgQnbpKEDX7HNADE1KnKdvt+QnpNXNh0ZM9vwoC+9iYqi88l
# e/60TRmheDhfilxtfQV0+6K5bZEqxjhdyNrhZsrGK1wNGwQ2B02hSlTEmEev3nPI
# GyfERWeCOZLyavGRiOWshRgvuSQA/FVSobfuMCLUW0V4c4W4WC8VC7AIQ+uzEt8S
# CKEQm9z3mumJC19NgvVdkDu7YEebfpOG0k6cva+1v6L0NED57OIlzGsyyNTqtVRy
# iYVV5vGqxD75F1/oiPhUphy+HvuryklunTZau3qklJ4MwG7dIxTJ40qsZyp0xn1A
# ujiHGpxDal97uhbnnVPyw+wtRjHfqymM2vwrud1TUCrgnZll/xjUSs2wiBjIx3BB
# BwPSnDhK2QxaqEYfW4phEhakOtOFQji9N0AJexNWIE00zrfBrW97l7FLfEj35j24
# xrHc9R5gV3G9ouwMfq6xLCkg/NgRSuY6exg7frPD5nKZSTbNStD5qYFTV7d8HymT
# 39QYOt1Nz/C3F7AkTcS2Y5TedJySK4cBilWqlNXQf58FMAoZt4HqoCAE+PkVtiuL
# 3/nkjWwWuwzLR8vwP6tr9tYKH2mY8twhXX0308N2I2MDiLnt3z0YrC+1tZUwVneM
# 4tMtUmWtwYAKw8HFBdODO2nop3O4LAnpgFxh9g==
# SIG # End signature block

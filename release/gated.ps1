#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Env = 'test'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('gitleaks', 'unit-test', 'semgrep', 'sonar', 'build', 'syft', 'grype', 'trivy')
$env:RELEASE_PIPELINE = 'gated'

. (Join-Path $PSScriptRoot 'lib/Vault.ps1')
. (Join-Path $PSScriptRoot 'lib/Yaml.ps1')

$step = if ($args[0]) { $args[0] } else { 'all' }
if ($step -eq 'scan') { $step = 'trivy' }

$known = @('all', 'scan') + $All
if ($step -notin $known) {
    Write-Error "[!] unknown step: $step ($($known -join '|'))"
    exit 1
}

Set-Location $Root
$project = [Yaml]::new((Join-Path $Root 'project.cfg'))
$projectType = $project.Require('type').ToLower()
if ($projectType -notin @('service', 'package')) { throw '[!] project.cfg type must be service or package' }
$imageSteps = @('syft', 'grype', 'trivy')

if ($projectType -eq 'package' -and $step -in $imageSteps) {
    Write-Host "[+] skip $step (project type is package)"
    exit 0
}

$name = $project.Require('project')
[Vault]::new().LoadEnv($name)

$steps = if ($step -eq 'all') { $All } else { @($step) }
if ($projectType -eq 'package') {
    $steps = @($steps | Where-Object { $_ -notin $imageSteps })
}
foreach ($name in $steps) {
    & pwsh -NoProfile -File (Join-Path $Root "release/steps/$name.ps1") $Env
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB8TQxTma4BC9C5
# /wP8BNiwsFoyQk4ghzXZt4pcOs1W56CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEII4y1DQB
# VdipaFEbUrPcxp6HPJw4gK77EGq2nHfLJiszMAsGCSqGSIb3DQEBAQSCAgB6W1ad
# USxMVVv2wdZ901UWZvCSAxTCcVkz9JMpV29dlO6fBzWPlqDU8FVc5W+Cynm1vAUP
# eSXp8wTR2nl8ssIWmMwt+5vfGBacZxuney5XheiJLD2KQKaBxUufhybz3p6YGPad
# e8JV11elxs/X1yK38lOMws/lRwQyYN8yVlI29u91TtAJPt/oTJNH57w04AQZNlnn
# eJiIT4R/Ueo0TRMsODEp7FJs/LBle2uW82mOYRae8EMLEq9LLtVPyX3XZhkgcXH8
# EoDJWkdFJLbQe4MOQXoqmGPyyMsJ3SWmefyqJpWSfUYVyKvZ1Iq6tDAiRMwbvjHw
# lIUL5Q59Gwer2MMg3a/yyoynyqwyT1qef4gzhxTCks6Db6TV5ljqJipforFRCjDc
# rzCfeanzmLrbqj8Saz2RjA8mVB4rDAu5zkg4RiJoPWnkb4cef+ghZ23dXmUVJptt
# kyjM/kDUL5kKDIfLASkB5b29bSw4LNoz/B2HjSS/J0Zg5GTJL24ltKK739FhvjZp
# oRuhDE3dkIPzZuEHsu8ommPZJ+n9czkMrhA5HZACmOyZlqiWW7HssDY+ElhD+jqD
# +ZjzkL8uXZNpoq1Ls21V143SybBW64yO2rxWuUPBn+kbyOs6qSNlu9HIqC+0hMSZ
# dbpiFCtsJRTRR/vpd08qzIhWIqgKNLH3S2HGag==
# SIG # End signature block

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Yaml.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
$registry = [Registry]::new($settings, $project, $staging)
$os = [OpenSearch]::new($settings, $project, $staging)
$os.Step('deploy', 'started')

try {
    $kind = $project.Require('type').ToLower()
    if ($kind -eq 'service') { $registry.DeployContainer() }
    elseif ($kind -eq 'package') { $registry.DeployBinary() }
    else { throw '[!] project.cfg type must be service or package' }
    $os.Step('deploy', 'succeeded')
}
catch {
    $os.Step('deploy', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCpcP1THDjcaaTw
# QpwZ5faXxRwp48/2Hs9D14bzNP0jaaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIE08bmzK
# +bEO+JHyDYIlmvmxjNx84D49fAzgs/DgvWXUMAsGCSqGSIb3DQEBAQSCAgB/hO0o
# G5PlpKL9ikjq+LzYMkAeMEYIDxPJCngw5YXnSzydq/7S0oKEyW+aQVZBtSbKl+bb
# 7N1Y0fkm0uOgd7wSrrNFTD0KYNdD4L21p+PW+Cg1mtYoBAc+/Qb5jRRgIwadtx96
# zvbfeLgO/Zwf0/eHu9TaVg5HQL9kupooJS8pcefQwQQ9yjGM4H93Za/0vSFVCb9y
# tEUQWLt0+awhZFLgfTTxY35NUCgt0Hmo4FdRK5oFuaiGbL+JObGguD68XflWhR9k
# Oth8Rq1+t6Ar+Dwos2oWMjAr8OvNyZ7f92/Kx3/dk41ymibcRX+qrHpGy7JGXMS6
# 1AcKzw2Upv8iRkMnS1RbJCLMvpWu8cKwbyCGe1bpG6fFlLODYs4CYoRW92SQPAW7
# kQEB9ebhNkOwHn6k3UtJGXL3c/uqOBZp2+/DsRubYY7i1JFvGzSsQn3yQFF/ClGm
# FWbku8AXzhNFtZZqWMXqtJCWSbML1wOuBAZddiyz3hO4ZNxqCC2+j4uJ82lynD8y
# bDHnRUPaMtbSmWmwEQ/UYOlPzxolHs0prXzytsxu3zhOlvvpQA3M559NxXcvKuJ7
# 0gAyIqXjEtpt+fZtzzEJdn0NSCOqDEkWz4CI3C3X2604YeKOthRp8U6VggNqlRNb
# 7DoNTSDToPUa3r75hrhNjQ91CmklI5tAsi6SKw==
# SIG # End signature block

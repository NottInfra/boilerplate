#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('deploy', 'started')

try {
    $sourceImage = $project.ReleaseImage()
    if ($sourceImage -ne $project.Image) {
        $source = [Registry]::new($project.Root, $sourceImage)
        $source.Pull()
        $source.Tag($project.Image)
    }

    [Registry]::new($project.Root, $project.Image).Push()
    $os.Step('deploy', 'succeeded')
}
catch {
    $os.Step('deploy', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBzCdDNb4AiugUl
# YE/0IO1uco8OqEkPCbcOa/C7AJDR7KCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILpC1cnY
# 3lrQrVrX0RA1tpo6aPsfusf3fmgiVGSKh3k4MAsGCSqGSIb3DQEBAQSCAgBINMum
# XvL8Qng8AY1XKCIdPqp7TOYRqsALV7lnXde/OEsBOBiAYnYLv2k41KyeM977dx7R
# rQu4d8xLojZ2mNAb1pUyVrevb7CUqvep2EnDEOTczZiRU8ibPFSCsx2a0QJ2Arol
# bu7+WoZX2fQ3W367NRbmk4CFHP91jHZWeAovCach45WXWPu0t9gYU4vPTroZpj37
# c+EBXn6+x0Pb7V4izjvZSjWSDzpn/y817FHHXLGNfCVsNrL9CfVx5soEcTpIMAw7
# 2CBIo59LSkOOsxvCtamyAWp/4tWlvku1iiOr0roVfBq/6EqQOIFzaHP/WZ+4HUNn
# WbW6d5hs3EqJ8XkLdhX+NjjBljBKa3HRZhI2vb9keKVl0ZbmfCPv7+Hm73lb1TST
# DzSoimwbenH54fmIqe20lbU0Hnwf7jnbV1U85MyC6oAgLM1uvB1KK6mXxaHM48ow
# lbt0b3Oeez/jW20t8QSIKtEZyXiKIQUMm1rAST0ucgzjyuQDrbAaR1WKLkaPekpH
# tHvykOi+0IAXnbEVP4AN56mb+BLbUecmKMSNOpIW5wuSD656HBYlfpNBVsMsowOB
# K0MSMK2W9V/Ylz/QTQCJQENugLS6Zw3+HkRZAjj5V2wQpqII4JDeNXR2DzcDPWBC
# V8TPud1+1OKIeGNiKOdCLkG/BKSCgp/a+mmM2Q==
# SIG # End signature block

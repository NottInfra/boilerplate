#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('unit-test', 'started')

try {
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        throw '[!] make is required for unit tests'
    }
    Write-Host '[+] unit-test via make test-docker'
    & make test-docker
    if ($LASTEXITCODE -ne 0) { throw '[!] unit tests failed' }
    $os.Step('unit-test', 'succeeded')
}
catch {
    $os.Step('unit-test', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCn1NWCHKZZgEIV
# xIS/VItH4NofzLT/pnvCvG1enOx6/aCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDVwGdDp
# BbAZsg56f63Ubox27IpWFAiMnB+5yvlzRf6nMAsGCSqGSIb3DQEBAQSCAgBMGqdf
# meW5HWiexKCo2a9CZqxsWs20HKAwqpVWPAwoHd53wOtEZNX0yoaKxBmjHFzwlnp1
# ybP0y4VCpeLMbH2cBgJs+cKTllu0JT0N/AZEM8dyLmYTtxCWrWszgpP/4/EwjmHW
# Cvqin87j6hBfgKY1om1n7alN+SpfIHS8wBoYMDwHapqCHiwMlfDQvjqK4YwRxgNX
# gbI2da4N9Fku9yR4YaseEMwyEx6rIu+1V4tqxexocczMuL1TlIyOYnHuX0H1zG5c
# ZCgJWDd5d1OqqBjw/UvuYfMTHBzftYrIuUsQvAvfQMzWoMgMwHlzU7lKmNhlSIzj
# XtwKP8WYfSIV7KZBNm4QmDWXq74iotfAAvZQVK+MIBsaOmDzvu409BFHezNy5E48
# LHjI3ajS+TJUTscOT2vJS4Kt2EVTYj4+5VDvdOY8XbaIbC9bHYW4CA9FYJp7zEKD
# ouT+pd2aMnwCONBRpoNAemkMViE/1t9CuuaLEJzjTQfH0BW/e1WKL6he4zGaahFl
# r4UFRJUucZUoP/COVIeG45Ldjm68er0+/1GhabcTkGhUAhuET9Y2p+IjKkdMc+bf
# BqxOCaaLYrqcIe7xdXfBogYIGTm3xRn8JBjKmPZhhdg8Lg6R3zj+YWPEHilXq6a4
# h8qaZOyVOQFx+6I+It8pjAZ5T8WzoCg71sSnQQ==
# SIG # End signature block

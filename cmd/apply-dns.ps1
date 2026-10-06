#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Yaml.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Spaceship.ps1"

$Env = [Env]::new()
$Project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$os = $null
try {
    $Settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Require('project'))-cmd")
    $os.Step('apply-dns', 'started')
    [Spaceship]::new($Env, $Project).Apply()
    $os.Step('apply-dns', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Require('project'))-cmd") }
        if (-not $os.Url) { $os.Url = $os.PinnedPublicUrl.TrimEnd('/') }
        $os.Step('apply-dns', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-dns', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBy1vbZmAkuvns7
# x3GTQs3v25YEhopNrsfNcybrbvkdo6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# ezJPirlP+IxtyaFnz10xggMHMIIDAwIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMFUwitX
# AWLG9ox1rXe1CmCDAWFlTSoq7NJS6yXRPn12MAsGCSqGSIb3DQEBAQSCAgBWRIEc
# QFii81jkKXAFrnGWnIXPva+B53AT4UcjG04wIq/XzoSKny2WmcAPChcClKOGzuIW
# aDptahLub9S1prM6LKOeMobwJ1W05GtFJWoGTnhFKo/mef17Lu0mdNOKbD3d/3Yc
# UUikGmMtyZzaz0ZbTOv345sk3oTRiuptDiXVoQMZUhzPmj4ohnV/H/uQR41AFN90
# kCZuOdFqABETnZDwnPKoTdLfgLePR0+K9ah+FPnLcZcCD0kewK5RXGARbuQOBnC5
# G9jaWVzI9wBt1SsnO2wra9AdI5olVzqsAjX6Nh8JZtwOL8jZ+dQ8oMybkC/1WDrm
# riIFsbJDIGLq+fVHWrYVYLzTfC7oscddL+V19nHVME3bAU9AVK23x/Ziu7Doj/Qt
# tqjbCeInvCghnL0/6T/AyLoXFJH4hS3EWrlcXK5+BpeZWSeKxqbdtoH5ML17Y88I
# OhHgAdFMeJUwcMNdPC8NoyM+iKwnZvVslCxJcYm7Uq9Gg7Y+jTSIQkAxUfhR39ap
# hvkBye0AYioaB4xpTyjvBO0XKhzkXnE+HBQJ+ONS/ZIuaFdoywWzYMcNql0wEQuy
# 3CaeLwdyRaCicQJFH4VAE5Zkv+1c/TrRccxBpxALL4EQ/J8CSwn1YQNg1r+QU71h
# ELuiK+SDbSV5KAxVQkGtfXa8360OmF3l8E8LBKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB6OFkp25FTL3ov
# ncuMrLIVo4UihcZ0CbTkPVFy73dxlaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGhogC1w
# QAWK0HUnG2cBH1wn+aC+lM1OQp/OTYDrqhOqMAsGCSqGSIb3DQEBAQSCAgCZ5x7b
# SFBvEP4iWU41K8Pbo2MhEBfqYyXUFQ4CR7hcmJHZaWsEFXWTlIjzfsWYQCKfftoo
# klOfQKzJ8kKM5ycJ4uP5wZgO3ce076apx9iKDvkUIv91WsIQoEopGvDUHv2cGiQN
# dbyS606B9F1sYcSJcWvs3A12+YW1nokHIxIbGA+ohPxli0wvnQmGRdM7f7n/e0lW
# 3P15ByyEzdjDz6FM915WqgoKKlZksLD5Vbw24Axa+WKj8G9a/BMobsG8bbf5Nthw
# Z+C5dDi+usvWio6su9DQRI7eKuef6gSR/hQbWYdoQOKdch2m6jSc8Om6O/FypWdM
# HZx2C1VbvnVyV4hiNEV2jmIvLyQROyWcLjgBhPsSDua5rGYuJm6f5R9RIr1+3Y9n
# YQKtu9ZHSwDmGzoTm1HiyUBUGPjWhk1zO+8Xq+8lnwELrqyo/+XDJ7O+yKEgr04O
# ncROLDutlzRPpczjnFo1R1Bx40Y4C8oVbZ3P8orW75hfkaOVXqZ5Tk6HewW1CY+2
# gjBf6Ass/3r24kH86cjGI9WgIrAbpl8UhnozE7GkvhxVmZoU1HlYSshcUXFkl4hW
# zENyec/bXEmB6wQgt17dLkUSwRG4+0ow0ikMRmIP8uhmGeHewCI3Po2D+u32vrAR
# 77rDxDrK3P5Fq9Eyt+zTkBs5cHS03ZkKGxhVKw==
# SIG # End signature block

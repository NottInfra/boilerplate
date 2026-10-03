#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-alerts', 'started')
    Write-Host "[+] Applying alerts (ENV=$($Env.Name))"
    $os.ApplyAlertingMonitors()
    if (Test-Path 'alerts/grafana.json') {
        [Grafana]::new($Project, $Env).ApplyAlertingRules()
    }
    else {
        Write-Host '[i] alerts/grafana.json missing — skipping Grafana rules'
    }
    Write-Host '[+] Done — alerts'
    $os.Step('apply-alerts', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-alerts', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-alerts', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDwXRqW2rp8IgQt
# os42jINueoTzGTCdJxrOXBr1WtLKiKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIASp1O5i
# 9QUjiNhzBNvVUwZvZIp28YrNnLpOe+mnLdaFMAsGCSqGSIb3DQEBAQSCAgA324RE
# ChVA5mD0SfSIrMinMrgqnnwvC4OIrcWsI/y8f19dFYjIqTJv4qZCL2qDLyEq8Okv
# Ufn+uQp9OPMmDBAPqjl8DYekkyPztJ2mXbatbiRl4fy6qd18wIYYiwksU2nPB7sE
# xBGX5+rKnXGonaQuay6TxBhGpAOTE6DQBPAId4pJl5LtiG1f4F/FVY7YUmDTw93G
# XZ728QvUiGf+CatQS8yBwRcaKUlrkpehBh0YJXujVlb6VfOzbY1oDx1mHoiq15tQ
# 3FELRz54cyD84Pbm+pfelpJp/K3LDzkrKq4CRJHcaMIM1WQ4VzNL9MAhv7j+uJNB
# o9K/DspnhOQs4+2I00HX4GY1x+HARqo1fV51Hqqydog3uegYLvKuGmVY1fqUSBbq
# mvshL2rHrVYJ7pmG+A1OMvdjHfuj2uFQJr5eAddrUkLZ7kK5yKODpvUoQLn8wpoi
# 6bSIeR9MZ2fKXmKRrlL3aoy1Erk00j/nxJPuzAN7xEdPHHnX8EPwE32yZcw0YNaQ
# 22GCQt4I1bIhKDAE/zcvMawwH/yt/jUlBudHhK/9U3pOqZy1OIiYxVUmHGPNclP/
# nqVnPDlQfa4N1DncLExNWcZjJ1D6WvUtzUojGLxa8bHaVLFuHQY437pv1CWkjknO
# W+azyZnmeIT3ZBZWIRvKdAZoSmqy5x7Ogc4Jfg==
# SIG # End signature block

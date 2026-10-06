#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Yaml.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Spaceship.ps1"
. "$PSScriptRoot/lib/S3.ps1"
. "$PSScriptRoot/lib/Cloudflare.ps1"

$Env = [Env]::new()
$Project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$os = $null
try {
    $Settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Require('project'))-cmd")
    $os.Step('apply-cdn', 'started')

    $domains = @($Project.Get('public.domains')) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -notmatch '^\{' }
    if (-not $domains -or $domains.Count -eq 0) {
        throw '[!] public.domains required in project.cfg (real domain names, not placeholders)'
    }

    $s3 = [S3]::new($Env, $Settings, $Project)
    $hosts = @($domains | ForEach-Object { "cdn.$_" })

    Write-Host "[+] DNS before Cloudflare ($($hosts -join ', '))"
    & "$PSScriptRoot/apply-dns.ps1"

    $cf = [Cloudflare]::new($Env, $Settings, $Project)
    $kind = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
    $origin = $Settings.Require("ONPREM.ENDPOINTS.MINIO.$kind")
    foreach ($hostName in $hosts) {
        $cf.AttachOrigin($hostName, $origin)
    }

    $s3.EnsurePublic()
    Write-Host "[+] CDN linked to MinIO public bucket $($s3.Bucket)"

    Write-Host ''
    $answer = Read-Host "Publish assets/cdn to the project CDN ($($hosts -join ', '))? [y/N]"
    if ($answer -notmatch '^[yY]$') {
        Write-Host '[=] publish skipped'
        $os.Step('apply-cdn', 'succeeded', @{ publish = 'skipped' })
        return
    }

    if (-not (Test-Path -LiteralPath 'assets/cdn')) { throw '[!] missing assets/cdn' }
    $s3.Publish('assets/cdn')
    Write-Host '[+] Done — cdn'
    $os.Step('apply-cdn', 'succeeded', @{ publish = 'pushed'; bucket = $s3.Bucket })
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Require('project'))-cmd") }
        if (-not $os.Url) { $os.Url = $os.PinnedPublicUrl.TrimEnd('/') }
        $os.Step('apply-cdn', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-cdn', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDcPtES85Km3BTn
# R6+bw5pEvWLI0FG4W4D5WFla2/LmrqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIE0fV+hv
# tFR49+YCtk/rjxL5ChLtGb1iPGXdUjTp+IJFMAsGCSqGSIb3DQEBAQSCAgBxY64+
# 5XLB0JSYuJpbkA7FG91OpX5g4zJqYNZl6GoXb0bqkYfHfz0NBZcKRnv96eHmixPJ
# 6uXons/gJop40X3emhR97voRFjtuwS958B/G0Y9C7bwsJ3JTkeau/inGnf0cQLE3
# wysGiYM/llZedV4svujs+5OLqdE/SPhqyFoXhBJrwaKQZnam7Qb5u6oNzTPTCvBx
# c8WuyUChsAJYc4l2qR9yVDLah4UEhqsOiV8TJJSDXTgwX6geRNB0pWxbn5AEfo8l
# lDbPpBk2YseNEvKUu/ca9XLoAx5AAw1CUo6gDYdFZgu8+X3jDONQzJS7cn2bhKok
# 2tSaVts6dpys4Cs0NZX8eRmNzfDixIJIkLzadcBM6E90htc3+GZN2UM1+VU6UvXL
# u9yKaGQmVVaJ4pWo2Nt6BufZrxh1C8kLY2nXCb5QhedYWP6+pz7cCT0omNS5kI/P
# nKAYKwhDcGBojaSuzvTneEi6i3t/t4QiVA+/exToia8AAq8sBq/QxE/Kf8mivvKU
# rmQjxY2uRxpVC/Y+1dlZV8AzjRJqiK1OUcB8dTgsGnxAT5TR7w1Fy5+06RJpdYVu
# X5IdxcorWr1jqeYOnZcTNk/UUmR4M9u9pyGj8Sq2N6fTxCaN5vo/hPG2D0hj86+B
# wH5ABm7r83NoJm9Qgdc5L/8J8XDGyk/fP8jWN6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

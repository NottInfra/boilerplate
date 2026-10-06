#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Yaml.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

$Env = [Env]::new()
$Project = [Yaml]::new((Join-Path (Get-Location) 'project.cfg'))
$os = $null
try {
    $Settings = [Yaml]::new((Join-Path (Get-Location) 'settings.cfg'))
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Require('project'))-cmd")
    $os.Step('apply-synth-monitoring', 'started')

    $domains = @($Project.Get('public.domains')) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ -and $_ -notmatch '^\{' }
    if (-not $domains -or $domains.Count -eq 0) {
        throw '[!] public.domains required in project.cfg (real domain names, not placeholders)'
    }

    $dnsA = @($Project.Get('public.dns.A')) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ }
    if (-not $dnsA -or $dnsA.Count -eq 0) {
        $dnsA = @('@', 'www')
    }

    $hostLabel = ([string]$Project.Get('public.ingress.type')).Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($hostLabel)) { $hostLabel = 'external' }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($domain in $domains) {
        $domain = $domain.Trim().TrimEnd('.')
        if (-not $domain) { continue }
        foreach ($name in $dnsA) {
            $name = $name.Trim()
            if (-not $name) { continue }
            $vhost = switch ($name) {
                '@' { $domain }
                default { "$name.$domain" }
            }
            $rows.Add([ordered]@{
                    targets = @("https://$vhost")
                    labels  = [ordered]@{
                        service = $Project.Require('project')
                        host    = $hostLabel
                        vhost   = $vhost
                    }
                })
        }
    }
    if ($rows.Count -eq 0) { throw '[!] no blackbox HTTPS targets derived from public.domains / public.dns.A' }

    $payload = @($rows.ToArray())
    # file_sd expects [{targets,labels}, ...] — do not use -AsArray (double-wraps arrays → [[...]]).
    $json = ConvertTo-Json -InputObject $payload -Depth 10
    if ($payload.Count -eq 1 -and $json -notmatch '^\s*\[') { $json = "[`n$json`n]" }

    $root = $Project.Require('remotes.configs.root').TrimEnd('/', '.git')
    $remoteUrl = "$root/blackbox-targets.git"
    $relPath = "https/$($Project.Require('project')).json"

    Write-Host "[+] blackbox-targets (project=$($Project.Require('project')), domains=$($domains -join ', '), host=$hostLabel)"
    Write-Host "[+] remote=$remoteUrl path=$relPath"

    $git = [SourceControl]::new($Env, $Settings, $remoteUrl, [GitHub]::new(), [GitLab]::new($Env))
    try {
        $git.Sync()
        $git.WriteContent($relPath, ($json.TrimEnd() + "`n"))
        $git.CommitAndPush("chore(blackbox): $($Project.Require('project'))")
    }
    finally {
        $git.Cleanup()
    }

    Write-Host '[+] Done — blackbox-targets'
    $os.Step('apply-synth-monitoring', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Require('project'))-cmd") }
        if (-not $os.Url) { $os.Url = $os.PinnedPublicUrl.TrimEnd('/') }
        $os.Step('apply-synth-monitoring', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-synth-monitoring', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDuS0uBB7tB6feP
# c5lzlAEzSPGX6hi2P9fFxiHga6AZo6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKOBiovZ
# TqkSwKuAqccnBDyBF9Ch/+EI4JQc67BL5pV2MAsGCSqGSIb3DQEBAQSCAgAXtW0F
# H8fSaCmsAAffOFr26ylaaPKd8qeFlBuz5VWa+sXQaC+RfDxvdzYSnbCvhEyTKFKG
# qsi0vWkgkaP13MzSaczmMIbK5WHpcNyjUE5vamCXbzhETPVCCNcMX3Xc6Xdpp5Ov
# UpZdYVvKYFqBTshqy1NaVuprjEyBlMr8R0ujmF8NLwOQRVmHtIiAJrQI1xXlr4D4
# nB/qfBQ8CYc5CY0xuysWIp6j+hpe/q8Rt9N43UCsjumf7QLFefkWbqQbU/IOnbjx
# LpRgs1T2+HUzsjM0ZOwKDfA1Ipkj84G1vAYy/1xnnNcVUfDjWDJK/pbEfY35BWIx
# AV9ql52u0QWWzQmfkdlOX3ye9ZRzEtHJe63u9QN8yUJ5xyQzAyKQTjQbjIIi0gqC
# /H+VIFGWQ7LbSPPbLK10Zww9ARjLiiMJuC8oPEtggy5FA6IZTcyR9nY6f58ICODh
# G47P3fUvGnesQWymGkbdsa2HHkBDPqI48TeuB4SgwWH7+MJIWa02mS3H7EpmUcCW
# zvvgUWoPMZIG9MPX0x3r1lSQ3GhVwDz8iF5lOD8/6l0eq8s1kLbIy+iwrLeJXhGf
# pO2JQN6b90kx0WM7bTesO7F611OQ+O1KAJS88yvXjrzP7eSKMwDpbTSv1hGgCnhX
# TtM+5/QSgAPRrx4D8sZU+wF1FWZB8X/ikAkvEKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB0vzLi/VlGXTWl
# w7ERwfxhBFFHZ/7UrULwOqKyIDBft6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIN922+2U
# klr6/KeFpqbxGZeqNcWMFUlHWsfFvEpntDH1MAsGCSqGSIb3DQEBAQSCAgCEx7Rn
# d6yOo5cR6fqxD3KCEAdQJCrzn1JFUnHKB5EfYqf9oYJXBOJQcDhMP1sX5oZ1Gk9z
# IMCnrx8/S2AFC11Qx+Q9iIIjcn60rhMAji+yfNHGKf9Hi86CRr8Guh4tC3SopGe1
# ig7EwtRmShzsWF+8iILHOaL+u9CYKUafId3gNOeSMV7VdAt9emtGWi0gmr4b6xJV
# QojX8I1lO9UsMOvGtImLGDdkc3Mj12ztKP3hAGtfwuQq3eKPkpNOHVNqxPsJF7Cf
# xhYDxez8BXiy21V3LaoPEpsJPooJWIiTfSoI1YJsVBLFlZmjlXVqJBjR8Emb7Unt
# j9Uu93O9LHFCMAoQ9oPWiph/1hjZbiO+Al3B7MLjfLE+t9miGhJwLsAmiqCxvKsE
# UumJ6xCqXDA/mc76rOfGTMEI7WbwITcwM14tY+k7QPTXGdJ4LJ9Y6P+lJ/Za+DlJ
# 5MpRyTz9XaRP7/OmKMwGmhz4uOYqi0F2Er8TMxgAYrBHtf0f+CeWQo9hR9f30l1s
# tWRyoxKKXVWjeg0hbVs93/Olbh1YOEjM/mnr/vArBiXg5lEGSdVzGbNu3nONTr5+
# 1fscP9C5IsEqz9hRm1H4YeXzVzjoCUsGT9NJDwpAzay/wHe7brWPLtVUQjCKnVml
# Av/hGGBKheMMnbDcolqAnc/jUCb4i5AuNsIhBg==
# SIG # End signature block

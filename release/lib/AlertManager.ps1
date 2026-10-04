class AlertManager {
    hidden [string]$Url
    hidden [string]$ProjectName

    AlertManager([object]$Settings, [object]$Project) {
        $this.ProjectName = $Project.Require('project')
        $inCluster = "$env:NETWORK" -eq 'cluster' -or "$env:GITHUB_ACTIONS" -eq 'true'
        $which = if ($inCluster) { 'CLUSTER' } else { 'PUBLIC' }
        $this.Url = ([string]$Settings.Require("ENDPOINTS.ALERTMANAGER.$which")).TrimEnd('/')
    }

    [void] Alert([string]$Message) {
        $this.Alert($Message, 'warning')
    }

    [void] Alert([string]$Message, [string]$Severity) {
        if ([string]::IsNullOrWhiteSpace($Message)) { return }
        if ([string]::IsNullOrWhiteSpace($Severity)) { $Severity = 'warning' }
        $summary = "$($this.ProjectName): $Message"
        $alert = [ordered]@{
            labels      = [ordered]@{
                alertname = 'ReleaseAlert'
                severity  = $Severity
                project   = $this.ProjectName
            }
            annotations = [ordered]@{
                summary     = $summary
                description = $summary
            }
        }
        $body = '[' + ($alert | ConvertTo-Json -Depth 6 -Compress) + ']'
        Write-Host "[+] AlertManager $summary"
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/alerts" `
            -ContentType 'application/json' -Body $body -SkipCertificateCheck -TimeoutSec 30 | Out-Null
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCQo4dutW09V7L5
# ez/HaX1rgr5qoJxLMoClRj+2lK8RAaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINd31vHH
# +vaSoYsrtfjylU6UD+rnUDAE00bUO9wjgN+9MAsGCSqGSIb3DQEBAQSCAgBKG5Cs
# bVWGmWbKAfB+NIvvhid7VT+/grbRyC7EsvQnoSKkk1A39V6ZrhjdsN/I44YFHpR9
# kfjFRFKnOgY4eIQQUSt//lPumRFujv28tKq+CbjNuyuoEvfm3WnYKHgeazP0fG1D
# tI87H53uy9b7orL9U/31NeElisM9700GOmYSvAzIqfLTVkObuGBDU/Kh6eUu64TQ
# f2pY+ZrQ3zEMgHCaZ6Jeaz85yBL8DnAYBZSsE9ircv7Y2RCs/3qvfo/Ksw+oFVbI
# bPON8Hp1VwK/XwJydyLDrGL4pWf2FSnRVhlj/rt4l2xrsFewMJgCZeMHMx1s/odo
# 9YBmdt2mZUNnlZ7noW1D2u+gak01URbdSicWmtnFPn/b0akL9rYydGagZWZM9dF6
# p1EiSIH5+N/vQGrEB3WegQww+ZHhq7goEXeNGJGBKv+fZkgS4BqP7hmCV0mDnsu+
# NbV2AnwuczUSEpzmF3aeK1DkftXtTqpMWr4JUhOC0va4g8LW9NMrJzSpNCNWMldj
# ClcM51dy7iRxCWY7oK2lM08xuHDw96uHKKNdfuRiqoIy9FRgvJSBXXhL49LoYt0j
# o7ODU9UyuR10nOqc6mvWmanSC5YtsW85km2INjSPnK6cDu6hmaaQsMbDTKjLE34t
# Y3XIfWOa21MGX/GL1kwRPl3EunI98oU+7G4IZg==
# SIG # End signature block

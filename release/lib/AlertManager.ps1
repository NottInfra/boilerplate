class AlertManager {
    hidden [string]$Url
    hidden [string]$ProjectName

    AlertManager([object]$Settings, [object]$Project) {
        $this.ProjectName = $Project.Require('project')
        $inCluster = "$env:NETWORK" -eq 'cluster' -or "$env:GITHUB_ACTIONS" -eq 'true'
        $which = if ($inCluster) { 'CLUSTER' } else { 'PUBLIC' }
        $this.Url = ([string]$Settings.Require("ONPREM.ENDPOINTS.ALERTMANAGER.$which")).TrimEnd('/')
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
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDoSDk6mUICdJEP
# 45ni64Dzn0COHI74ZquTNvGuh4C9uqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFtkRDH/
# bXMsM5nIGwYJppdrqM/g5Ydk0S0oCOmB0TVrMAsGCSqGSIb3DQEBAQSCAgB2N/JO
# uFc7eRT+1WkOfpaj0rllXCLqHU/CuM916xXRJevotJRMZ07qZy4A0Qi4+E1iERuz
# NaN9QIp8/rnkCMOY+dn3KQ7d3zIsYLBoqO6qTzthNAvwS3AbOvskq/dos210fxqy
# iRg0UbeUKF3EydxPyWp8XJfSpR+j0U9G9STJtGVBHfDaPaL2VzghG/n+V3ORcvGT
# Rde40l22YZHsdr8xGQajKWqcdobWD+jLiKVUD3s0hhIDxkPj4qrNUh/HTAghp1OT
# qnjCnfri027Bzsph/lj2KLPeo4hVMMDw0L65sGG1C1GOhGvFzHrGRSsTKhevfeTf
# 6B+mrxdHQSXc0Z2FBiiL45e49PFT+G4M63nYdVEChgVPU7eB5CGZ+SmF4uMCK0is
# Z7rLMV4hWK0XW97PkIqNEowcruJhyVVFTKgJhgB97HkziIxlCmpQxHC/RR46EJgb
# GFSu81mFAdvLXqKGUFftPrzgTh7jSj3RiSOA5pGcBAToHGR+8jvlrSEBxRffo1JE
# pJTVhMCZdyixXWhFb6KtuHTF7q75QqsrbFf6JQkK/RpsLkrICA7AKNxJ6A5UXkeZ
# ed/m3+Oh3+h8OEBHjBzjBJym/1YFhKG9XoEB+a24xZoD4L/EclLEEGmrgpyiQVr3
# XJ5qmUBjcfpJXD3b2W6lhr77hjBAQkWPsvz+dqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

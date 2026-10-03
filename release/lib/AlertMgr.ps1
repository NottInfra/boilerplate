class AlertMgr {
    hidden [string]$Url

    AlertMgr() {
        if (-not $env:ALERTMANAGER_URL) { throw '[!] ALERTMANAGER_URL is required' }
        $this.Url = $env:ALERTMANAGER_URL.TrimEnd('/')
        try {
            $null = [System.Net.Dns]::GetHostAddresses('alertmanager.monitoring.svc.cluster.local')
            $this.Url = 'http://alertmanager.monitoring.svc.cluster.local:9093'
            Write-Host '[+] AlertMgr via cluster service'
        }
        catch { }
    }

    [void] Alert([string]$Message) {
        $this.Alert($Message, 'warning')
    }

    [void] Alert([string]$Message, [string]$Severity) {
        if ([string]::IsNullOrWhiteSpace($Message)) { return }
        if ([string]::IsNullOrWhiteSpace($Severity)) { $Severity = 'warning' }
        $alert = [ordered]@{
            labels      = [ordered]@{
                alertname = 'ReleaseAlert'
                severity  = $Severity
            }
            annotations = [ordered]@{
                summary     = $Message
                description = $Message
            }
        }
        $body = '[' + ($alert | ConvertTo-Json -Depth 6 -Compress) + ']'
        Write-Host "[+] AlertMgr $Message"
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/alerts" `
            -ContentType 'application/json' -Body $body -SkipCertificateCheck -TimeoutSec 30 | Out-Null
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBm+EKyo7tX0U2P
# rQWtJ15DcmhOY712JtAPS7QASrvMS6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIG1jW6sU
# hOp2wG3unuE3wUOtGczDRRd3k47b8rQNqPZnMAsGCSqGSIb3DQEBAQSCAgBvMUCD
# +t50z4r8m4UIpg/t4F5bKDb69E+d4uswi6YQ6IGSOhI5i2msg0hQsEby1cLBTvUy
# YvJ1DTFUtGrcFduNjWRIYGtymodifEKlNDTNJK5e8DguLSMO5gP/QDSXYVAcKb6v
# gm2GQnRhGi+WmWNoP0uv9v80SVBMSQHSs0q6dYKANU2KrZZSRi+6KLFTqIpR/JDV
# 7aCXbt65rFJrzSuktVazT/P20W82FGviWIDCvVajbZ55VP/rweauepxg6CsOycdm
# cY0Gt4Hr7KS9GUtaNiW3tlsqv50NSInGy5fburTzBgp9tOfR/DeS1lFSW3ztfc1H
# QS7l7naO35XSth3wxY+aFgFI+iBEuF9Jc06fg/VipwETdRhDvyEPl5hcAW/Gs/DH
# RkYvFYWpcvpV91XzAGY5FdNAa3nfwF0F2TlN0lmif9g8j3jg2ISyd5v8i+Nxx70H
# 0nZ6FtYjumQfcCC/IDHD6dYE1cKSG1HRGOM7K/I+1hE3nf8B90Wg8ui/SVJQqCum
# xmfBGJmBXL28nJL/83FWoMJOj2wqqVQ9TnYIkj5vydmhQK4LCNXBey0iVzj6gsxD
# Pk9TZCu7X9VqA3kuduEbfq1Sa9SaAXYWaj1nxGhvq0UsdDpMNy+nPETqIEcCjugU
# rO6t5n3o3mDMqWKdN74ITVxNw4OcjI5paJ4gMg==
# SIG # End signature block

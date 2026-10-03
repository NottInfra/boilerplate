class OpenSearch {
    hidden [string]$Url
    hidden [string]$UserPass
    hidden [string]$Env
    hidden [string]$Stream
    hidden [string]$Staging
    hidden [string]$ProjectName

    OpenSearch([string]$ProjectName, [string]$Env) {
        if (-not $env:OPENSEARCH_URL) { throw '[!] OPENSEARCH_URL is required' }
        if (-not $env:OPENSEARCH_USER) { throw '[!] OPENSEARCH_USER is required' }
        if (-not $env:OPENSEARCH_PASSWORD) { throw '[!] OPENSEARCH_PASSWORD is required' }
        $this.Url = $env:OPENSEARCH_URL.TrimEnd('/')
        try {
            $null = [System.Net.Dns]::GetHostAddresses('opensearch.opensearch.svc.cluster.local')
            $this.Url = 'http://opensearch.opensearch.svc.cluster.local:9200'
        }
        catch { }
        $this.Env = $Env
        $this.UserPass = "$($env:OPENSEARCH_USER):$($env:OPENSEARCH_PASSWORD)"
        $this.ProjectName = $ProjectName
        $this.Staging = $Env
        $this.Stream = "$ProjectName-pipeline"
    }

    [void] Step([string]$Step, [string]$Status) {
        $this.Step($Step, $Status, @{})
    }

    [void] Step([string]$Step, [string]$Status, [hashtable]$Extra) {
        if (-not $Extra) { $Extra = @{} }
        $fields = [ordered]@{
            event                    = 'pipeline_step'
            'deployment.environment' = $this.Env
            pipeline                 = @{
                staging = $this.Staging
                step    = $Step
                status  = $Status
            }
            project                  = $this.ProjectName
        }
        foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
        $this.WriteDoc($this.Stream, $fields)
    }

    [void] Finding([string]$Scanner, [string]$Status, [int]$Count, [string]$ReportFile) {
        $fields = [ordered]@{
            event                    = 'pipeline_finding'
            'deployment.environment' = $this.Env
            scanner                  = $Scanner
            status                   = $Status
            finding_count            = $Count
            report                   = $ReportFile
            project                  = $this.ProjectName
            pipeline                 = @{ staging = $this.Staging }
        }
        $this.WriteDoc("$($this.ProjectName)-findings", $fields)
    }

    hidden [void] WriteDoc([string]$DataStream, [hashtable]$Fields) {
        $doc = [ordered]@{ '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        foreach ($k in $Fields.Keys) { $doc[$k] = $Fields[$k] }
        $headers = @{ 'Content-Type' = 'application/json' }
        $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers['Authorization'] = "Basic $b64"
        $body = ($doc | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$DataStream/_doc" `
            -Headers $headers -Body $body -SkipCertificateCheck -TimeoutSec 30 | Out-Null
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCAjC3LH4kWOMGY
# tECd6VaxOcKv2uZb2qOMIcZOPcgEwaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKFrobfx
# kPPh06Zp19429GsfhfXrSqNMzki7JuqRqdetMAsGCSqGSIb3DQEBAQSCAgCL8dqr
# E/aIXS0HhjCihUebRM0ihHRqmFPUceY//a0BxvsM45ueuAc3DQw95OA6hosm8Se2
# V9sM1hh0ATJdwugx1mODYmfzqWdW6VnlULF5WYpwPPrQFKOLJySssYhr3zSrMB4L
# Da8Ozy+1H6DtnguNUUeh4KGqvNvvTRys3sVCQx72vvVEhqGlkTIUr3t/XNUeN9on
# 16pjZUaquVci8q3t1e6mUuNgRPq1RA2LkDLH8nx2/74I1Czqcb4dciwhLxRt63gf
# i307c5qgwiFvP19lH7p7W7aNrqOp3QT4ODbUUg9lIQkSzVRLFquxN74KnKfjw4fp
# FnMkovUM7BaIzSaX4brxKM7RTHneqNUB0uNnG2utqW5MITeBfGpS22NOb8u540HR
# BVMVQiUiZfZxfv6iT+5NH1dRjjAnvLunNzKPdjNTK3ESVXc8iz+FIDQRRtqg4G6S
# QFE/8PwZJo5ZaSbH02jhff2slzvR/OP13weDTJNCyc0iOP2oTauHRHM03cu+s7WG
# nwop/2qFYw/w6O+SguVx4HR+ooYb3CKKAXlgoHRr24tWy489L8BuXu06FcvMH+PP
# I2VnzB12qQtQkxRYieSy8TaIfdUi4m83H2f8kdSvRs8JFPhSkhiTtEY9f0phv5KD
# uPqMs7lq55bwkZekK6ZfXYFuQ2SwrJl9vnD60A==
# SIG # End signature block

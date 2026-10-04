class DefectDojo {
    hidden [string]$Url
    hidden [string]$Token
    hidden [int]$EngagementId
    hidden [string]$ProjectName

    DefectDojo([object]$Settings, [object]$Project) {
        if (-not $env:DEFECT_DOJO_API_TOKEN) { throw '[!] DEFECT_DOJO_API_TOKEN is required' }
        if (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) { throw '[!] DEFECT_DOJO_ENGAGEMENT_ID is required' }
        $inCluster = "$env:NETWORK" -eq 'cluster' -or "$env:GITHUB_ACTIONS" -eq 'true'
        $which = if ($inCluster) { 'CLUSTER' } else { 'PUBLIC' }
        $this.Url = ([string]$Settings.Require("ENDPOINTS.DEFECTDOJO.$which")).TrimEnd('/')
        $this.Token = $env:DEFECT_DOJO_API_TOKEN
        $this.EngagementId = [int]$env:DEFECT_DOJO_ENGAGEMENT_ID
        $this.ProjectName = $Project.Require('project')
    }

    [void] ImportScan([string]$Staging, [string]$ScanType, [string]$ReportFile, [string]$StepName) {
        if (-not (Test-Path $ReportFile)) { throw "[!] report missing: $ReportFile" }
        $title = "$($this.ProjectName)-$Staging-$StepName"
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $form = @{
            scan_type           = $ScanType
            test_title          = $title
            product_name        = $this.ProjectName
            engagement_name     = "$($this.ProjectName)-$Staging"
            engagement          = $this.EngagementId
            file                = Get-Item -LiteralPath $ReportFile
            active              = 'true'
            verified            = 'true'
            minimum_severity    = 'Info'
            auto_create_context = 'true'
            close_old_findings  = 'true'
        }
        Write-Host "[+] Defect Dojo import: $ScanType → $title"
        $r = $this.PostScan("$($this.Url)/api/v2/import-scan/", $headers, $form, $title)
        if (-not $r) {
            $r = $this.PostScan("$($this.Url)/api/v2/reimport-scan/", $headers, $form, $title)
        }
        if (-not $r) { throw '[!] Defect Dojo import failed' }
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }

    hidden [object] PostScan([string]$Uri, [hashtable]$Headers, [hashtable]$Form, [string]$Title) {
        for ($i = 1; $i -le 3; $i++) {
            try {
                return Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Form $Form `
                    -SkipCertificateCheck -TimeoutSec 300
            }
            catch {
                $code = 0
                if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
                $msg = $_.Exception.Message
                # uwsgi closes the socket after a long import even when the test was saved.
                if ($msg -match 'ResponseEnded|prematurely|502|Bad Gateway') {
                    if ($this.TestExists($Title)) {
                        Write-Host '[+] Defect Dojo import saved; HTTP body was truncated'
                        return @{ saved = $true }
                    }
                }
                if ($code -eq 400) { return $null }
                if ($i -lt 3 -and ($code -in 0, 502, 503, 504)) {
                    Write-Host "[i] Defect Dojo HTTP $code, retry $i/3"
                    Start-Sleep -Seconds (10 * $i)
                    continue
                }
                throw
            }
        }
        if ($this.TestExists($Title)) {
            Write-Host '[+] Defect Dojo import saved after retries'
            return @{ saved = $true }
        }
        return $null
    }

    hidden [bool] TestExists([string]$Title) {
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $uri = "$($this.Url)/api/v2/tests/?engagement=$($this.EngagementId)&limit=100"
        $r = Invoke-RestMethod -Uri $uri -Headers $headers -SkipCertificateCheck -TimeoutSec 60
        foreach ($t in @($r.results)) {
            if ($t.title -eq $Title) { return $true }
        }
        return $false
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB6ifL0Ngg+3Qdu
# Jw9vPFgEGnMRRuurhllItI3sqOsKUqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDbxW8E1
# 8f+pqEvhCE+UOBP/u/lutv4yb5tnK1SCW1UyMAsGCSqGSIb3DQEBAQSCAgA1NXmm
# TFhgPtO2JzqpBkqjS5FkjNODG++FjQmYRKsbXOQ+STsUFQrAEEPWvlGumP1FNL0J
# kS758LDxBhY0sZMYOuqz2iN77qSbQui8/7/+f8xFX+P4yhp0WIWSh/+hkbMbnrdT
# 6knkIRpxtZwbjvJm6JJqQHynQysQDjVXES/N4IroIowXPlxUd6eIjLbd7hupcTL1
# n5BFJH4yg74yvOyoql8TCY1mAmUHDup3wiz+HTtRejVBb3IFKm6Ba31M+iF53gJ7
# t8DoidQWJlGktYr89ZpErgE9CGD+JJNIAlcwgqd88PbtW+JPeKFF/1i6lnguvIM+
# JPlmrWYmJgZPAY8qrHCLm6m7xKJzv5UMJE22uCWagGR2WmefGKVUc5myYtbzc73g
# jfLc1oWjLaWLILuk1S2ofBug30TYdnAcFlaci0JVMfIGQnDku/DTsaFCU3HgYotE
# MviEUIWUwpEu8Rvu/YzxKaRD3BZCS7Z8siXtDsfhND1Bd7L0/n6cfyUBYUEChjXo
# p7eet+G1M1PMmguPziEAJOvDb/2/vKgYYdsdPl1zwCta/AFYacnGdDRXA6IJaONu
# XnxEKBslA/JSjdf1b2/oB+VqyJQnF47zghaOZx6ElnfzseaWuMqUgdXCI+z5aG0A
# MLNbHvV58q3a7kI6PmburIhJ+1tbpWW9mHsR3A==
# SIG # End signature block

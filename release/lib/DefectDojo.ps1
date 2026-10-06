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
        $this.Url = ([string]$Settings.Require("ONPREM.ENDPOINTS.DEFECTDOJO.$which")).TrimEnd('/')
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
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCf1Ds2HHHDTZe3
# IKiqtU1JRP6tPBCx44WyWVuTMVaPfqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDmLDLNi
# uD149mMzZCBiyO0LTsMbL0LEdUo4jXnxOSuzMAsGCSqGSIb3DQEBAQSCAgBw+2kq
# 2AD3jkp12eFkWDMLWHqkeanzvcPyRYMhjInAPn9ToxV6d22vMqwTbqwklnU6hSgR
# LZAP4sd/Dqy5wAiBy+TbJtNDg1nzB7sy8U9f/DOwlpfhtG6qRo1r4ZGeMbu8dRCs
# fmXBX/BB5KEF83FiNko3ZEfzs8ma/OsgudLCBRZjx0K3QLQHrDlWYMOEkf18ydpj
# JApzNGeiaE4c8AHoWL72TLEU3Xs/NjSu+MEj0YuplOUFr5vDIPmqAN16prO3Y+S/
# mPfHg9lFHSTdZ7m6w1RwtugWmpqVZfRLTakfNXjIEw77YFPkER6LSQwBNPTOATyK
# B+uvSlTHuotFTp612g7Ez3nJ1wTUz7YcvqMoOW5blaRdEcIpEiafwQWC0nnCa6mI
# kYFgGmqKgLo4hELwdLjc1FIyos8R3kybTuqTw1VOpgWix0J3EBoXz3KCD7FrS2dz
# KWKDkIK8XeGTadqsqrvI2/rnU+C2Ht8U3tWAvI9mmjTWuUljBdtwKfpgDgR1m0lU
# /dhB52ztlAhRGw6CCdYTEDKrOMG4tj8I+WyDAKTs9xyscXElGz0YPlhir9wYCVJF
# dE6XlZiXy0EQPY+jOGyLz0KcvAKtPVkougEv77GzfEoelkcV+b04rJejmum1f0Kh
# 9H2m1w+zmEXnCL980c9rcyrKX5mfrZxNjLw1MKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

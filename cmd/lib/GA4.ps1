class GA4 {
    [Yaml]$Project
    [string]$AccountId
    [Google]$Google

    GA4([Yaml]$Project, [Google]$Google) {
        if (-not $Project) { throw '[!] GA4 requires project.cfg' }
        if (-not $Google) { throw '[!] GA4 requires Google' }
        $this.Project = $Project
        $this.Google = $Google
        $this.AccountId = $this.FindOrProvisionAccount()
    }

    hidden [string] FindOrProvisionAccount() {
        $matches = $this.FindAccountIds()
        if ($matches.Count -gt 1) {
            Write-Host "[!] Found $($matches.Count) GA4 accounts named '$($this.Project.Require('project'))' — using $($matches[0]), delete the extras in Admin UI"
        }
        if ($matches.Count -ge 1) {
            Write-Host "[+] GA4 account: $($this.Project.Require('project')) (accounts/$($matches[0]))"
            return [string]$matches[0]
        }

        Write-Host "[+] GA4 account '$($this.Project.Require('project'))' not found — requesting provision ticket"
        $headers = $this.Google.AuthHeaders()
        $body = (@{
                account     = @{
                    displayName = $this.Project.Require('project')
                    regionCode  = 'GB'
                }
                redirectUri = 'https://analytics.google.com/'
            } | ConvertTo-Json -Compress -Depth 5)
        try {
            $ticket = Invoke-RestMethod -Method Post -Uri 'https://analyticsadmin.googleapis.com/v1beta/accounts:provisionAccountTicket' -Headers $headers -Body $body
        }
        catch {
            throw "[!] GA4 cannot create account '$($this.Project.Require('project'))': $($_.Exception.Message)"
        }

        $url = "https://analytics.google.com/analytics/web/?provisioningSignup=false#/termsofservice/$($ticket.accountTicketId)"
        Write-Host "[!] Accept GA4 ToS: $url"
        if (Get-Command open -ErrorAction SilentlyContinue) { & open $url }

        Write-Host "[+] Waiting for GA4 account '$($this.Project.Require('project'))' (poll every 5s, up to 15m)..."
        $deadline = (Get-Date).AddMinutes(15)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5
            $matches = $this.FindAccountIds()
            if ($matches.Count -ge 1) {
                Write-Host "[+] GA4 account: $($this.Project.Require('project')) (accounts/$($matches[0]))"
                return [string]$matches[0]
            }
            Write-Host "[=] waiting for account '$($this.Project.Require('project'))'..."
        }
        throw "[!] Timed out waiting for GA4 account '$($this.Project.Require('project'))' after ToS"
    }

    hidden [string[]] FindAccountIds() {
        $headers = $this.Google.AuthHeaders()
        $found = [System.Collections.Generic.List[string]]::new()
        $pageToken = $null
        do {
            $uri = 'https://analyticsadmin.googleapis.com/v1beta/accountSummaries'
            if ($pageToken) { $uri += "?pageToken=$([uri]::EscapeDataString($pageToken))" }
            $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $summaries = @()
            if ($null -ne $r.accountSummaries) { $summaries = @($r.accountSummaries) }
            foreach ($summary in $summaries) {
                if ($summary.displayName -eq $this.Project.Require('project') -and $summary.account) {
                    $id = ($summary.account -replace '^accounts/', '')
                    if ($id) { $found.Add($id) }
                }
            }
            $pageToken = $r.nextPageToken
        } while ($pageToken)
        return @($found | Sort-Object { [long]$_ })
    }

    [string] EnsureProperty([string]$Domain) {
        if ([string]::IsNullOrWhiteSpace($Domain)) { throw '[!] domain required' }
        $headers = $this.Google.AuthHeaders()
        $parent = "accounts/$($this.AccountId)"
        $filter = [uri]::EscapeDataString("parent:$parent")
        $pageToken = $null
        do {
            $uri = "https://analyticsadmin.googleapis.com/v1beta/properties?filter=$filter"
            if ($pageToken) { $uri += "&pageToken=$([uri]::EscapeDataString($pageToken))" }
            $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            foreach ($prop in @($r.properties)) {
                if ($prop.displayName -eq $Domain) {
                    Write-Host "[+] GA4 property: $Domain ($($prop.name))"
                    return $this.EnsureWebStream($prop.name, $Domain)
                }
            }
            $pageToken = $r.nextPageToken
        } while ($pageToken)

        $body = (@{
                parent           = $parent
                displayName      = $Domain
                timeZone         = 'Europe/London'
                currencyCode     = 'GBP'
                industryCategory = 'OTHER'
            } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri 'https://analyticsadmin.googleapis.com/v1beta/properties' -Headers $headers -Body $body
        Write-Host "[+] GA4 property created: $Domain ($($created.name))"
        return $this.EnsureWebStream($created.name, $Domain)
    }

    hidden [string] EnsureWebStream([string]$PropertyName, [string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        $pageToken = $null
        do {
            $uri = "https://analyticsadmin.googleapis.com/v1beta/$PropertyName/dataStreams"
            if ($pageToken) { $uri += "?pageToken=$([uri]::EscapeDataString($pageToken))" }
            $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            foreach ($stream in @($r.dataStreams)) {
                if ($stream.type -eq 'WEB_DATA_STREAM') {
                    $mid = [string]$stream.webStreamData.measurementId
                    if ($mid) {
                        Write-Host "[+] GA4 measurement ID: $Domain → $mid"
                        return $mid
                    }
                }
            }
            $pageToken = $r.nextPageToken
        } while ($pageToken)

        $body = (@{
                type          = 'WEB_DATA_STREAM'
                displayName   = $Domain
                webStreamData = @{
                    defaultUri = "https://$Domain"
                }
            } | ConvertTo-Json -Compress -Depth 5)
        $created = Invoke-RestMethod -Method Post -Uri "https://analyticsadmin.googleapis.com/v1beta/$PropertyName/dataStreams" -Headers $headers -Body $body
        $mid = [string]$created.webStreamData.measurementId
        if (-not $mid) { throw "[!] GA4 web stream created for $Domain but measurementId missing" }
        Write-Host "[+] GA4 measurement ID created: $Domain → $mid"
        return $mid
    }

    [hashtable] EnsureDomains([string[]]$Domains) {
        $out = [ordered]@{}
        foreach ($domain in $Domains) {
            $out[$domain] = $this.EnsureProperty([string]$domain)
        }
        return $out
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCIodeZzS0bukFQ
# X9Ql2FL0y8/gnIvUZMfNHhU/GMN5OaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMKPoIOA
# 6amMcd3iC64numoGZbOIaUjhOV8hkjOiAPWqMAsGCSqGSIb3DQEBAQSCAgBvvpYO
# NMBFPJCrGOsJCwVKtD5EzmixpsaAIKYiPVq4XrbOOIR8rJFsgET5+GDtVrTz6Hoq
# DvGFVryAjIkag8iyUG8WjhY3erPDYc18wZDgwnhSAck7xKgVwg6GCFFFEcOmOlT1
# BXKR7K04yIA03tGcJ2J2pKMCDRCvFPboGIJBMOsWX0D2+keJsvUtWsrY0OPk08Wg
# JxJLyQcVt8VzcSqwzfA6RX1/JKdsmTDlvyHKTvnM/nlvf3KSGmxGKmziaTcEF4kd
# htSmEOyQ3tNGwAdI4cHeMbjoEfM3vjVu/kTNUpNhDXEDqlyn1OzFC0IbPnf9em+2
# ChTE4IdFncz26FdYbdGsOdRpctv23O7I2O4jIOPsqvAJ7QMFuvmeoAmsqgF1PWNQ
# f5aXWEJNdkOEuVedrT88xuKdyh82L94tNsWUGaiS18ZLTNkZMmbNfq9N3jjwo2QF
# ukvUxcByoXiiZfkHmbP4G8+dR7HLOsRPanu3oZs6sjlSPq6Z/Lgu6waAJIvX5eNf
# 0nfiEM4fP8cO+Adpqr3ECe9L8E85hhCHHxQX/0nS/ShaJUTh7WQ9S+XT8281mmfU
# FRMmX7CDs3eBM1jdvp9YZaz08cwSSmiDLNLUqyYm5e1vL5YkcRzh19WsbC77Xf4x
# W73Ze0hwji3e3xFfVwUgxQ8xUaXsJ0uLqEpd+qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

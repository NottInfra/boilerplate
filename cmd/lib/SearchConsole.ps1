class SearchConsole {
    [Yaml]$Project
    [Google]$Google

    SearchConsole([Yaml]$Project, [Google]$Google) {
        if (-not $Project) { throw '[!] SearchConsole requires project.cfg' }
        if (-not $Google) { throw '[!] SearchConsole requires Google' }
        $this.Project = $Project
        $this.Google = $Google
    }

    [string] GetDnsTxtToken([string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        $body = (@{
                verificationMethod = 'DNS_TXT'
                site               = @{
                    type       = 'INET_DOMAIN'
                    identifier = $Domain
                }
            } | ConvertTo-Json -Compress -Depth 5)
        $r = Invoke-RestMethod -Method Post -Uri 'https://www.googleapis.com/siteVerification/v1/token' -Headers $headers -Body $body
        if (-not $r.token) { throw "[!] Search Console DNS token missing for $Domain" }
        return [string]$r.token
    }

    [hashtable] GetDnsTxtTokens([string[]]$Domains) {
        $out = @{}
        foreach ($domain in $Domains) {
            $out[[string]$domain] = $this.GetDnsTxtToken([string]$domain)
        }
        return $out
    }

    [bool] IsVerified([string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        try {
            $r = Invoke-RestMethod -Method Get -Uri 'https://www.googleapis.com/siteVerification/v1/webResource' -Headers $headers
            foreach ($item in @($r.items)) {
                if ($item.site.type -eq 'INET_DOMAIN' -and $item.site.identifier -eq $Domain) {
                    return $true
                }
            }
        }
        catch {
            return $false
        }
        return $false
    }

    [void] VerifyDomain([string]$Domain) {
        if ($this.IsVerified($Domain)) {
            Write-Host "[=] Search Console already verified: $Domain"
            return
        }
        $headers = $this.Google.AuthHeaders()
        $body = (@{
                site = @{
                    type       = 'INET_DOMAIN'
                    identifier = $Domain
                }
            } | ConvertTo-Json -Compress -Depth 5)
        Invoke-RestMethod -Method Post -Uri 'https://www.googleapis.com/siteVerification/v1/webResource?verificationMethod=DNS_TXT' -Headers $headers -Body $body | Out-Null
        Write-Host "[+] Search Console verified: $Domain"
    }

    [void] EnsureSite([string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        $siteUrl = "sc-domain:$Domain"
        $encoded = [uri]::EscapeDataString($siteUrl)
        try {
            Invoke-RestMethod -Method Get -Uri "https://www.googleapis.com/webmasters/v3/sites/$encoded" -Headers $headers | Out-Null
            Write-Host "[=] Search Console site exists: $siteUrl"
            return
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -ne 404) { throw "[!] Search Console site lookup failed for ${siteUrl}: $($_.Exception.Message)" }
        }
        Invoke-RestMethod -Method Put -Uri "https://www.googleapis.com/webmasters/v3/sites/$encoded" -Headers $headers | Out-Null
        Write-Host "[+] Search Console site added: $siteUrl"
    }

    [void] EnsureDomains([string[]]$Domains) {
        foreach ($domain in $Domains) {
            $this.VerifyDomain([string]$domain)
            $this.EnsureSite([string]$domain)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPE+mqsCWXGX6c
# vYiMoHmMKCOmjLEmA0HH9rBb9FA7caCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOqO0Qgh
# Db/1dEyqYxGObOrLB3CqSZUJXBuHLOpQD/UqMAsGCSqGSIb3DQEBAQSCAgBoa3Ri
# OhpSt9ETkcUPjldaSeGBuhgWQ2/In01a6SKNd3WSKojgXfpyozJJXXrouw8fcblS
# dg9gxpCCMKLIV5Hwcb4xTWNPUN1F/Zka4dlP1bE5ogkMQ4dQJVeGx2S5dGHKhbJU
# lpEmtga4DhfzUPgTxhgRo9WuYgN6RzcXEO0LNf87GexlBA0zpLdSa11sDmbMhylb
# 0U5wyUfwJiLUk2bawi6l7axRTYuZ3vPJQ2sfLrwNnAl7jGmuXcIKvuqi64eu8oJH
# ERpa8ZBiE5EZCLu0tSBQQ1ZjOq50R01A5d3RSDjtLnPSgCB3fSwBRsjhQLFndlys
# a3+HOzt9O+cO5mFmEjBIDWmglEGGDzWVT2MkEFGJZbT23hO7B2o0+YhoCqhxK6iZ
# 64Xja+U96VhEHy5HNfOuQHRY1UHT8SnqdycNaFQ5m/98mWsDQ4PaXampEr91IA5a
# hFrAyE+xjJNmcMUXBiSsFV+QLgEqBjK6ZDtRoSy+b+klJvRXrLIu7jiAvL94oGzO
# 6z1Ve+/c//C//suOzSll/XSi2DzDRTnvhGd9qaesBF6u5XcaNazl6mGCv55/tJxb
# V9iROtOTYz4N/+Ej5Xm2JNsDMTWIf9NOhD7RuFzeuh7qSybB3U717IOYMOBJGDVz
# EKsJ7JbW/TxXSxAPTacWfLIf8GGldA6z1USchKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

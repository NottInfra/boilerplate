class Cloudflare {
    [Env]$Env
    [Yaml]$Settings
    [Yaml]$Project
    [string]$Api
    [string]$AccountId
    [string]$Token

    Cloudflare([Env]$Env, [Yaml]$Settings, [Yaml]$Project) {
        if (-not $Env) { throw '[!] Cloudflare requires Env' }
        if (-not $Settings) { throw '[!] Cloudflare requires settings.cfg' }
        if (-not $Project) { throw '[!] Cloudflare requires project.cfg' }
        $this.Env = $Env
        $this.Settings = $Settings
        $this.Project = $Project
        $this.Api = $Settings.Require('MANAGED.CLOUDFLARE.API').TrimEnd('/')
        $this.AccountId = $Settings.Require('MANAGED.CLOUDFLARE.ACCOUNT_ID')
        $this.Token = $Env.Require('CLOUDFLARE_API_TOKEN')
    }

    [void] AttachOrigin([string]$Hostname, [string]$OriginUrl) {
        $zone = $this.Zone($Hostname)
        $origin = ([Uri]$OriginUrl).Host
        if ([string]::IsNullOrWhiteSpace($origin)) { throw "[!] invalid MinIO origin: $OriginUrl" }
        $zoneName = [string]$zone.Name
        if ($Hostname -eq $zoneName -or $Hostname.EndsWith(".$zoneName")) {
            $this.EnsureProxiedRecord([string]$zone.Id, $Hostname, $origin)
        }
        else {
            $this.EnsureCustomHostname([string]$zone.Id, $Hostname, $origin)
        }
        Write-Host "[+] Cloudflare $Hostname → MinIO $origin"
    }

    hidden [hashtable] Zone([string]$Hostname) {
        $parts = @($Hostname.Split('.') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($parts.Count -lt 2) { throw "[!] Cloudflare zone name required for $Hostname" }
        $apex = ''
        for ($i = 0; $i -le $parts.Count - 2; $i++) {
            $name = ($parts[$i..($parts.Count - 1)] -join '.')
            $apex = $name
            $found = $this.FindZone($name)
            if (-not [string]::IsNullOrWhiteSpace([string]$found.Id)) { return $found }
        }
        return $this.CreateZone($apex)
    }

    hidden [hashtable] FindZone([string]$Name) {
        $q = [Uri]::EscapeDataString($Name)
        $got = $this.Call('GET', "zones?name=$q&account.id=$($this.AccountId)", $null)
        if ($got.Ok -and @($got.Json.result).Count -gt 0) {
            $row = @($got.Json.result)[0]
            return @{ Id = [string]$row.id; Name = [string]$row.name }
        }
        return @{ Id = ''; Name = '' }
    }

    hidden [hashtable] CreateZone([string]$Name) {
        $made = $this.Call('POST', 'zones', @{
                name       = $Name
                account    = @{ id = $this.AccountId }
                type       = 'full'
                jump_start = $false
            })
        if (-not $made.Ok) { throw "[!] Cloudflare zone $Name ($($made.Status) $($made.Message))" }
        $id = [string]$made.Json.result.id
        if ([string]::IsNullOrWhiteSpace($id)) { throw "[!] Cloudflare zone $Name missing id" }
        Write-Host "[+] Cloudflare zone created: $Name"
        return @{ Id = $id; Name = $Name }
    }

    hidden [void] EnsureProxiedRecord([string]$ZoneId, [string]$Hostname, [string]$Origin) {
        $q = [Uri]::EscapeDataString($Hostname)
        $list = $this.Call('GET', "zones/$ZoneId/dns_records?name=$q", $null)
        $id = ''
        if ($list.Ok) {
            foreach ($row in @($list.Json.result)) {
                if ([string]$row.name -eq $Hostname) { $id = [string]$row.id }
            }
        }
        $body = @{ type = 'CNAME'; name = $Hostname; content = $Origin; proxied = $true; ttl = 1 }
        if ($id) {
            $upd = $this.Call('PATCH', "zones/$ZoneId/dns_records/$id", $body)
            if (-not $upd.Ok) { throw "[!] Cloudflare DNS $Hostname ($($upd.Status) $($upd.Message))" }
            return
        }
        $made = $this.Call('POST', "zones/$ZoneId/dns_records", $body)
        if (-not $made.Ok) { throw "[!] Cloudflare DNS $Hostname ($($made.Status) $($made.Message))" }
    }

    hidden [void] EnsureCustomHostname([string]$ZoneId, [string]$Hostname, [string]$Origin) {
        $q = [Uri]::EscapeDataString($Hostname)
        $list = $this.Call('GET', "zones/$ZoneId/custom_hostnames?hostname=$q", $null)
        $id = ''
        if ($list.Ok) {
            foreach ($row in @($list.Json.result)) {
                if ([string]$row.hostname -eq $Hostname) { $id = [string]$row.id }
            }
        }
        if ($id) {
            $upd = $this.Call('PATCH', "zones/$ZoneId/custom_hostnames/$id", @{ custom_origin_server = $Origin })
            if (-not $upd.Ok) { throw "[!] Cloudflare origin $Hostname ($($upd.Status) $($upd.Message))" }
            return
        }
        $made = $this.Call('POST', "zones/$ZoneId/custom_hostnames", @{
                hostname             = $Hostname
                custom_origin_server = $Origin
                ssl                  = @{ method = 'http'; type = 'dv' }
            })
        if (-not $made.Ok) { throw "[!] Cloudflare origin $Hostname ($($made.Status) $($made.Message))" }
    }

    hidden [hashtable] Call([string]$Method, [string]$Path, [object]$Body) {
        $uri = "$($this.Api)/$($Path.TrimStart('/'))"
        $headers = @{
            Authorization = "Bearer $($this.Token)"
            Accept        = 'application/json'
        }
        $params = @{
            Method             = $Method
            Uri                = $uri
            Headers            = $headers
            SkipHttpErrorCheck = $true
        }
        if ($null -ne $Body) {
            $params.ContentType = 'application/json'
            $params.Body = ($Body | ConvertTo-Json -Compress -Depth 6)
        }
        $resp = Invoke-WebRequest @params
        $json = $null
        if ($resp.Content) {
            try { $json = $resp.Content | ConvertFrom-Json } catch { $json = $null }
        }
        $ok = ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300)
        if ($json -and $null -ne $json.success) { $ok = [bool]$json.success }
        $msg = [string]$resp.Content
        if ($json -and $json.errors) {
            $msg = (($json.errors | ForEach-Object { [string]$_.message }) -join '; ')
        }
        return @{ Ok = $ok; Status = [int]$resp.StatusCode; Message = $msg; Json = $json }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCApVcEBO9cm4kTJ
# z9L49woQmEYhDJCsDISexLi//8a+d6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFuwoVpM
# j75COzPOoW0buBoqYxoHn4111DUKxWmwn/IxMAsGCSqGSIb3DQEBAQSCAgCfo6de
# ZWa0KFbdqE1f5wu8tT8slyxnuDZvrdog5avHhCP4JCpo8WqIslvUcQcbEnPPp+IS
# vzhxatD0lBK2NPRD/GugSYV1lV9QU4n3W8q/CE0SPXrI2v2aR6hvH12A6azkfQyt
# 3gSVJ62CNI6h+oFiYhcpuKWdQcx1kXP5s6qfqVyaLhNw8XM/Egexco54G9NoUCNJ
# ssoCPHTRaOAcX9oYiMk21BK3MJDBKUbF77BUk8gQyPocTtqXwav7Gpao36lamnBk
# a/yVjqnbSgpDU63iCFJ3rhNXoIvrXHJkeTeMCEiMrDIitC0TT8qEbPGIrFhmR2M5
# GjataMML/CTsjnLVHLCwiDBMt1Wh0HRkAUkA31z0jQCxER9+DfR4bCCmw5fgwG8u
# 4g8j3vUeDBe80sCk6GVOnE/0Zx528Bb1j9xgj+T55jSWCKKZw/QWan8DZXD6dpdb
# tRUEqNFFu9V0i/K7Ac28M5N+k5dAfaTkWDyef5i7Fbt7O/Qz9RyWyObCsUHEk1MY
# f0nEQ8JyIH42P1pZ0qapdlYX4tbAxW1AI24dcr81Zi/pzj0BPxUOpxOg67g4i0wd
# M+7ciQ4JUPxiFEtc/DqL0M08XDy7DkLO+KGIiEbwCqtOxdZ7u9ldURZVVI9MScgR
# 4wNnl9jIECeyPNWrzO2aApqIxLbuMFiiKgpqP6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

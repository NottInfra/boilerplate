class PostgreSql {
    [string]$DbUrl
    [Env]$Env

    PostgreSql([Env]$Env, [object]$Settings, [object]$Project) {
        if (-not $Env) { throw '[!] PostgreSql requires Env' }
        $this.Env = $Env
        $this.Apply($Settings, $Project)
        $this.DbUrl = $this.Env.Require('DB_URL')
    }

    [void] Apply([object]$Settings, [object]$Project) {
        if (-not $this.Env) { throw '[!] PostgreSql.Apply requires Env' }
        if (-not $Settings) { return }
        $kind = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
        $endpoint = $Settings.Require("ONPREM.ENDPOINTS.DB.$kind")
        $user = $this.Env.Get('DB_USER')
        $pass = $this.Env.Get('DB_PASSWORD')
        if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) { return }
        if (-not $Project) {
            throw '[!] PostgreSql requires project name for database'
        }
        if ([string]::IsNullOrWhiteSpace($this.Env.Name) -or $this.Env.Name -eq 'shared') {
            throw '[!] PostgreSql requires ENV (development, test, or live)'
        }
        $dbName = "$($Project.Require('project'))-$($this.Env.Name)"
        $env:DB_URL = $this.BuildUrl([string]$endpoint, $user, $pass, $dbName)
    }

    [string] BuildUrl([string]$Endpoint, [string]$User, [string]$Password, [string]$DbName) {
        if ($Endpoint -notmatch '^(postgresql://)([^/?]+)(.*)$') {
            throw "[!] invalid DB endpoint (expected postgresql://host[:port]): $Endpoint"
        }
        $scheme = $Matches[1]
        $hostPart = $Matches[2]
        $rest = $Matches[3]
        if ($rest -match '^/') {
            throw "[!] DB endpoint must be host-only (no database path): $Endpoint"
        }
        $u = [Uri]::EscapeDataString($User)
        $p = [Uri]::EscapeDataString($Password)
        $url = "${scheme}${u}:${p}@${hostPart}${rest}"
        if (-not [string]::IsNullOrWhiteSpace($DbName)) {
            $url = "$($url.TrimEnd('/'))/$DbName"
        }
        return $url
    }

    [void] EnsureDatabase() {
        $db = $this.DbNameFromUrl($this.DbUrl)
        $admin = $this.AdminUrl($this.DbUrl)
        if ($this.Exists($admin, $db)) {
            Write-Host "[=] database $db exists"
            return
        }
        Write-Host "[+] creating database $db"
        & psql $admin -v ON_ERROR_STOP=1 -c "CREATE DATABASE `"$db`";"
        if ($LASTEXITCODE -ne 0) { throw "[!] CREATE DATABASE failed: $db" }
    }

    [void] ExecFile([string]$SqlFile) {
        & psql $this.DbUrl -v ON_ERROR_STOP=1 -f $SqlFile
        if ($LASTEXITCODE -ne 0) { throw "[!] psql failed: $SqlFile" }
    }

    hidden [string] DbNameFromUrl([string]$Url) {
        if ($Url -match 'postgresql://[^/]+/([^?]+)') { return $Matches[1] }
        throw '[!] cannot parse database name from DB_URL'
    }

    hidden [string] AdminUrl([string]$Url) {
        $db = $this.DbNameFromUrl($Url)
        return $Url -replace "/$([regex]::Escape($db)).*$", '/postgres'
    }

    hidden [bool] Exists([string]$DbUrl, [string]$DbName) {
        $out = & psql $DbUrl -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>$null
        return ($out -match '1')
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD462KCFC3RDRrT
# DpSnbAIxJb27zDK8FI4NY2aCzuKCnaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICqPKk4P
# vBp+qnkpsmu1Hq937N7j/1SFbD6AY04jtjXuMAsGCSqGSIb3DQEBAQSCAgCNKMUu
# SquDNU88xjggYoL1385mp0kvItcvoFRZ1uf24Gbrx0NIeAx3sbG2DKoKJ7X3gq1R
# D+J0nbIzRCmk9qud0GrmwGXMXQflGKi3+AICSPRw6CyNdCnG8N7RgAgYkdr4NaUQ
# i6HV8+rcJ2j3WvBB8+B9MK0uS4UMAwhCM9/+3B3wX5xW2AWJ5H1yqmQ53zXXmD3X
# 8cP+CT1XuC1F4Ww1rrxEM0YmsoQMVlFjYVnZ79xxugQa65jX9ENO/7mjBpSFI9jC
# ib+GVTi1TYpzqJdg9ECvleso3N3r5lGAUJJ0JFYOH0Wk0L2ZgLAi2fxP5pb7BmnD
# zQOggROHxfMFCMAQDMub8A1btsN8rPuGxCRpftrC/+Sed1+tESZUJnABSuYc0fUM
# uNwt8y4KUas3l9k3/DxkRdDOHjXpfD4tNOZGYjiUfMQSWsTIloybyJL89GotGDgZ
# FcFSkB7BGizaDzWcb2/nemskHYnE0LOpETG5INH8QXpIuMQ44JP8QbA/XS6lOzIK
# 2P9UsbQLXhGaOETlXQlyItm+9KUcxTDLChVb+uE5x9J5nsVitGTeYtNvh7pHYI9D
# OHCLyEAlFv1k9Dw8y5zBBiJnXXwSzmG8CNU/QsxTJGNe8ocD/eU63NgXLlvyYfHC
# O1a2KVZUK36N1rZj1vt+zj7UUNQAyUzxb8qVQ6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

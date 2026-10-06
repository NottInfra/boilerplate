class OpenSearchDashboards {
    [string]$Url
    [Env]$Env
    [Yaml]$Project

    OpenSearchDashboards([Yaml]$Project, [Env]$Env) {
        if (-not $Project) { throw '[!] OpenSearchDashboards requires project.cfg' }
        if (-not $Env) { throw '[!] OpenSearchDashboards requires Env' }
        $this.Project = $Project
        $this.Env = $Env
        $this.Url = $this.Env.Require('OPENSEARCH_DASHBOARDS_URL').TrimEnd('/')
    }

    hidden [string] PrepareNdjson([string]$File, [string]$Slug) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $title = "$($this.Project.Require('project')) / $Slug"
        foreach ($line in Get-Content $File) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['title']) {
                $obj.attributes.title = $title
            }
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['description']) {
                $cur = [string]$obj.attributes.description
                if ($cur -notmatch [regex]::Escape($this.Project.Require('project'))) {
                    $obj.attributes.description = "$title — $cur".Trim(' —')
                }
            }
            $lines.Add(($obj | ConvertTo-Json -Depth 50 -Compress))
        }
        return ($lines -join "`n")
    }

    hidden [hashtable] Headers() {
        $headers = @{
            'osd-xsrf' = 'true'
            'kbn-xsrf' = 'true'
        }
        $user = $this.Env.Get('OPENSEARCH_USER')
        $pass = $this.Env.Get('OPENSEARCH_PASSWORD')
        if (-not [string]::IsNullOrWhiteSpace($user) -and -not [string]::IsNullOrWhiteSpace($pass)) {
            $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${pass}"))
            $headers.Authorization = "Basic $token"
        }
        return $headers
    }

    [void] ImportNdjson([string]$File, [string]$Slug) {
        Write-Host "== OpenSearch Dashboards import: $($this.Url) =="
        Write-Host "    $($this.Project.Require('project')) / $Slug ← $File"
        $body = $this.PrepareNdjson($File, $Slug)
        $tmp = [IO.Path]::GetTempFileName() + '.ndjson'
        try {
            Set-Content -Path $tmp -Value $body -NoNewline
            $form = @{ file = Get-Item $tmp }
            $r = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/saved_objects/_import?overwrite=true" `
                -Headers $this.Headers() -Form $form
            if (-not $r.success) {
                $r | ConvertTo-Json -Depth 10
                throw '[!] OpenSearch Dashboards import reported errors'
            }
            Write-Host "[+] OpenSearch Dashboards: $($this.Project.Require('project')) / $Slug"
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.ndjson' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] OpenSearch Dashboards: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $this.ImportNdjson($f.FullName, $slug)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAjkr3SMxC3ctOs
# fY8BzkQnvRmaJ61QHEpyOkqdCbSuOaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEYBeLBU
# 9SQgNCqpfdqREtnR1TpJ2Fl6UCiRs/kLS2oIMAsGCSqGSIb3DQEBAQSCAgBgp9U/
# k4/tyvq9PQyK3kyzT0JBlFCwZ5WYAcz8alc3Iiyewve/Nww6+8TtQ2PFiiYxRS7X
# L5RyPdEfZRNahPfteoqqm/0PpiOz7ach+A6KGpKGF+wzDOIG3UD3jOKNJbf4kpHK
# LzBUyuzCXt38JKJR5HcxCwAcJ/2HUElC6mIINJlTYDbP04u/V0syrgIwn7XD/Cb7
# cqVsP4AZ6xnGAmzdVkyEbyQTvq/PbZbnxDtmJ0qGELiKMBhsX63nortMYSxeFrh+
# G+yewrUYd40DqUl+SLFpNOHN5Pl/9n3jVSdItb/NHvR0WzhMB6UxsqlA2STKgLbQ
# b2JUM6agBmtdAbJ5QDBZoH7oXOVZP9WXJnOEfjJwBY63tovyGHrewkeUzx7tUR96
# YvVOx6qa7GbV3wsf1+3YgXy8jl4+24GGOeNSWi5PnLcnwP5w0eSXQewenS6A6Rl0
# twS1FzCH8OFRMhGAXfDK4OTkiEgyIHg8gnLeKvt0G1D1p8R4FYsRlAgSBujIlAPU
# QUstgk/fnLIro2kk2KhHi+WYRQOwJZEht/sMVozQCqx++prN4j7nOsHgMs79az5f
# nBI6+EfRZLigMoGRdRUP16N1KrNvvZe3klQtwbyH64f3wseSsJpTp7zbVpwl7ZMV
# mU19KNcFwkbIMUc22EgvuGuj6X9AKOtw/VKw0qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

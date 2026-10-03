class OpenSearchDashboards {
    [string]$Url
    [Env]$Env
    [Config]$Project

    OpenSearchDashboards([Config]$Project, [Env]$Env) {
        if (-not $Project -or -not $Project.Loaded) { throw '[!] OpenSearchDashboards requires project.cfg' }
        if (-not $Env) { throw '[!] OpenSearchDashboards requires Env' }
        $this.Project = $Project
        $this.Env = $Env
        $this.Url = $this.Env.Require('OPENSEARCH_DASHBOARDS_URL').TrimEnd('/')
    }

    hidden [string] PrepareNdjson([string]$File, [string]$Slug) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $title = "$($this.Project.Name) / $Slug"
        foreach ($line in Get-Content $File) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['title']) {
                $obj.attributes.title = $title
            }
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['description']) {
                $cur = [string]$obj.attributes.description
                if ($cur -notmatch [regex]::Escape($this.Project.Name)) {
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
        Write-Host "    $($this.Project.Name) / $Slug ← $File"
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
            Write-Host "[+] OpenSearch Dashboards: $($this.Project.Name) / $Slug"
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
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBrAcjwr8hz47RZ
# KPpYND5HkXsBBew8PimU1CxSwqfuFaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJmBkeqB
# VJWy7PIUAuYFSOskrQo88Glpz1MAFWh45B3vMAsGCSqGSIb3DQEBAQSCAgCiYCbp
# a63OViM17WjIiYiGipJkWz6BvTH9ky2crHeyjFOAi1uaq76Ky/i3cKh0TdIFgGb0
# bK7z6AtWTE52VrBfdk9wc/alWX+DeG+s7wKV+XwUhdbKBO2aIHXE/KvqYMCQp2hM
# GV/ix6rJWExf1p4Zi02F8/jnSECltEGqeWAZ3Hy3p9svQV7fGoLlNa94sQ6IOhhj
# hM3SFQUZHpkwHHi6+JDvm5ewD1uwqXkLuGwq3N5RzV01cY3vIMZW3hRzl3BEnAq8
# a+jJefYeqkwDqbbw2rQnW1GnnXHFxX9o0kn7+2VZdrZMAJR6yPHAmwhfr4zyQGqM
# xdRdHCPbRGhrz7sxBGd2rhrgjK6UZf/fYj0nGqft+gpvSbuX4rvss45K+kowY3R/
# RVOZ+4DAaFQ9Xqw/sFsixPKM69wmzmLEPDVAuGctWSamqN1Ch3cZnBkQwWO9u9xJ
# 8QCeck0I8uoeyTLRw9HwQDIfxCKEB+/Rz2pGg51g3qUMQgW/+qLcu20b/BZGT3Ut
# 5jpI7qHjBv6g0P4Dnx4AJ5BnUCFNtp8NpVfu9tvLTZfcvzqdfKcHnfhrJ7fI4AdU
# kwfaT6Yt+029DBcf7O6kG+skjXMURNne+rRSWIwfFGi7jXlNS0OmlmhOLzwUvxpJ
# 5mcVn0q8iT5Oti7ELOxKJFK6kT3vtSILt+sPyw==
# SIG # End signature block

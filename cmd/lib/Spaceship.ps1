class Spaceship {
    [string]$BaseUrl
    [string]$ApiKey
    [string]$ApiSecret
    [Env]$Env
    [Yaml]$Project

    Spaceship([Env]$Env, [Yaml]$Project) {
        if (-not $Env) { throw '[!] Spaceship requires Env' }
        if (-not $Project) { throw '[!] Spaceship requires project.cfg' }
        $this.Env = $Env
        $this.Project = $Project
        $this.ApiKey = $this.Env.Require('SPACESHIP_API_KEY')
        $this.ApiSecret = $this.Env.Require('SPACESHIP_API_SECRET')
        $this.BaseUrl = 'https://spaceship.dev/api/v1'
    }

    [object[]] GetRecords([string]$Domain) {
        Write-Host "== Spaceship DNS list: $Domain =="
        $r = Invoke-RestMethod -Method Get -Uri "$($this.BaseUrl)/dns/records/$Domain" -Headers @{
            'X-Api-Key'    = $this.ApiKey
            'X-Api-Secret' = $this.ApiSecret
            Accept         = 'application/json'
        }
        return @($r.items)
    }

    [void] SaveRecords([string]$Domain, [object[]]$Items) {
        Write-Host "== Spaceship DNS save: $Domain ($($Items.Count) record(s)) =="
        foreach ($item in $Items) {
            $n = if ($item.name) { $item.name } else { '@' }
            $addr = if ($item.address) { $item.address } elseif ($item.value) { $item.value } else { '' }
            Write-Host "   → $($item.type) $n → $addr (ttl=$($item.ttl))"
        }
        $body = (@{ force = $true; items = $Items } | ConvertTo-Json -Depth 10 -Compress)
        Invoke-RestMethod -Method Put -Uri "$($this.BaseUrl)/dns/records/$Domain" -Headers @{
            'X-Api-Key'    = $this.ApiKey
            'X-Api-Secret' = $this.ApiSecret
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        } -Body $body | Out-Null
        Write-Host '[+] Spaceship DNS records saved'
    }

    hidden [object[]] Entries([object]$Node) {
        $out = [System.Collections.Generic.List[object]]::new()
        if ($null -eq $Node) { return @() }
        if ($Node -is [System.Collections.IDictionary]) {
            foreach ($key in @($Node.Keys)) {
                [void]$out.Add([pscustomobject]@{ Name = [string]$key; Value = $Node[$key] })
            }
            return @($out)
        }
        foreach ($prop in $Node.PSObject.Properties) {
            [void]$out.Add([pscustomobject]@{ Name = [string]$prop.Name; Value = $prop.Value })
        }
        return @($out)
    }

    hidden [object] Child([object]$Node, [string]$Key) {
        if ($null -eq $Node -or [string]::IsNullOrWhiteSpace($Key)) { return $null }
        if ($Node -is [System.Collections.IDictionary]) {
            if (-not $Node.Contains($Key)) { return $null }
            return $Node[$Key]
        }
        $prop = $Node.PSObject.Properties[$Key]
        if ($null -eq $prop) { return $null }
        return $prop.Value
    }

    [void] Apply() {
        $this.Apply(@{})
    }

    # $SiteTxt: domain → TXT value for @ (e.g. Search Console tokens); merged with project.cfg sites.
    [void] Apply([System.Collections.IDictionary]$SiteTxt) {
        $registry = $this.Project.Require('public.dns.registry')
        $domains = @($this.Project.Get('public.domains'))
        $pubHost = $this.Project.Require('public.ingress.ip')
        $dnsCfg = $this.Project.Get('public.dns')
        if (-not $domains -or $domains.Count -eq 0) { throw '[!] public.domains required in project.cfg' }
        if (-not $dnsCfg) { throw '[!] public.dns required in project.cfg' }
        if ($registry.ToUpper() -ne 'SPACESHIP') {
            throw "[!] public.dns.registry must be SPACESHIP (got $registry)"
        }
        if (-not $SiteTxt) { $SiteTxt = @{} }

        foreach ($domain in $domains) {
            $domain = [string]$domain
            $items = [System.Collections.Generic.List[object]]::new()
            $specs = [System.Collections.Generic.List[object]]::new()

            $entries = $this.Entries($dnsCfg)
            foreach ($prop in $entries) {
                if ($prop.Name -in @('registry', 'sites')) { continue }
                $specs.Add([ordered]@{ Type = [string]$prop.Name; Spec = $prop.Value })
            }
            $sites = $this.Child($dnsCfg, 'sites')
            $siteNode = $this.Child($sites, $domain)
            if ($siteNode) {
                foreach ($prop in $this.Entries($siteNode)) {
                    $specs.Add([ordered]@{ Type = [string]$prop.Name; Spec = $prop.Value })
                }
            }

            foreach ($entry in $specs) {
                $type = [string]$entry.Type
                $spec = $entry.Spec
                if ($null -eq $spec) { continue }
                if ($spec -is [array] -or $spec -is [System.Collections.Generic.List[object]] -or ($spec -is [System.Collections.IList] -and $spec -isnot [System.Collections.IDictionary])) {
                    foreach ($name in @($spec)) {
                        $items.Add([ordered]@{
                                type    = $type
                                name    = [string]$name
                                address = $pubHost
                                ttl     = 3600
                            })
                    }
                    continue
                }
                foreach ($rec in $this.Entries($spec)) {
                    $row = [ordered]@{
                        type = $type
                        name = [string]$rec.Name
                        ttl  = 3600
                    }
                    if ($type -in @('A', 'AAAA')) { $row.address = [string]$rec.Value }
                    elseif ($type -eq 'CNAME') { $row.cname = [string]$rec.Value }
                    else { $row.value = [string]$rec.Value }
                    $items.Add($row)
                }
            }

            $extraTxt = [string]$SiteTxt[$domain]
            if (-not [string]::IsNullOrWhiteSpace($extraTxt)) {
                $dup = $false
                foreach ($existing in $items) {
                    if ([string]$existing.type -eq 'TXT' -and [string]$existing.name -eq '@' -and [string]$existing.value -eq $extraTxt) {
                        $dup = $true
                        break
                    }
                }
                if (-not $dup) {
                    $items.Add([ordered]@{
                            type  = 'TXT'
                            name  = '@'
                            value = $extraTxt
                            ttl   = 3600
                        })
                }
            }

            if ($items.Count -eq 0) { throw "[!] no DNS records to apply for $domain" }
            Write-Host "[+] Applying DNS ($domain, registry=$registry, ip=$pubHost, records=$($items.Count))"
            $this.SaveRecords($domain, @($items))
        }
        Write-Host '[+] Done — DNS'
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA0r12Yq2TjxgSO
# thELfHxC1Z40a2Xe/l/zNQSdATF5ZqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPzDj+Zn
# otu34agnhcm5WqmCSxaDH9YYa/LFB4WTUl4QMAsGCSqGSIb3DQEBAQSCAgAVGD2j
# aUyoReOjw/ePJH7MdrPBN6rp2lMq7bgP820Dy4DCvmmsWBISs7FDI9NNU1LzpMOE
# OEYQXJ++LvCV2jDiC4BR0ga/QVB2/FMPO0wpRrP5n0IHyrg8ClIFNptvuzfG1F4b
# gN6lxcddZ1E/g0rouXcwbE+SCQV9F2CGSrsVT9pxvuFlbSGnH+iePSMHuJOYN0Y7
# HzmVLhe6TIVZwGTjbz+7oBMm4Wdg4uYoGeTxAEvvbTahSuJsS94Bq1CinQCszq5e
# OUltec5x6++H74bCxtB27Sqm0RxTprxZ+HwEYgwHrPmfwsU9m8iBd0/AME1uSjda
# 2A0hjj1JBKGyma/Fhjty5kvO22ho4N6dDGEINmX+XPpkne2pBPFICUmJP6aPgUo+
# sTjaLH9BY2PHVzxKd4Bbk0HvQrXaCU/dUqTiilz8sKHiGlxFifC4f3f23jiCvwbp
# G613NYhwXagaUPlBHd7nnMr+pT47QGlxWJSPTWy6AfeCZ0g9h7zkmsaII9YEz3Jp
# 2abmtpqGrJFnAciXAjk9hOlUGlf3Qxwyl6t1aBXPuj6nUiDYgONggQkzpUwvMad8
# jvUVGNwSzjdr0kZJXYsTaLPBIVBqtGkrFACF3MX3bqeSR6oynavE2fA0EigCAmiu
# EhGFpB0aImFK83+8NxFFgdEG0H8vvATBLRwEwKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

class Grype {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$ScanDir
    hidden [string]$ToolImage

    Grype([object]$Settings) {
        $this.ToolImage = '{0}:{1}@{2}' -f $Settings.Require('CONTAINERS.GRYPE.NAME'), $Settings.Require('CONTAINERS.GRYPE.VERSION'), $Settings.Require('CONTAINERS.GRYPE.DIGEST')
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'grype.json'
    }

    [string] Scan() {
        $sbom = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
        if (-not (Test-Path $sbom)) { throw "[!] grype sbom missing: $sbom (run syft first)" }
        Write-Host "[+] grype sbom=$sbom"
        docker run --rm -v "$($this.ScanDir):$($this.ScanDir)" $this.ToolImage "sbom:$sbom" -o "json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] grype scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] grype report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        $report = $this.ReportFile
        return $report
    }

    hidden [int] CountFindings([string]$Report) {
        $matches = @(Get-Content $Report -Raw | ConvertFrom-Json | Select-Object -ExpandProperty matches -ErrorAction SilentlyContinue)
        if ($matches) { return $matches.Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD7/lGm68PRGS1H
# PxjYMpQ2dCsYZV3d1nn5n/NXlwS01aCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINtIUl//
# tCs45cD93HVOoV8w1AOzQ6ORk/OnZES10TxFMAsGCSqGSIb3DQEBAQSCAgBGB/kj
# enuRZCg9IHd5WW98eB/SNn44SjA60AS/xDQ4DvVGiqOugGev2UJrIvB1w2VeAVH3
# BcKCITIPNFLDiayPbMr0OKKkwRTcd+PRr+5+WhgP7X038rkj3SiZnkCrJg51rAmJ
# MOSeB3F1omUwIGA4zvp1xKQgd/lSVE3DSAxySOqo8k6HYm3MX9Uc0eBiSGATJO7a
# EcLqp7+dWc+E9nKh8lf4jKjWY/J9q2WVhpOxH8O1WAvWuP1EygFKdjts+XoxJu9K
# 8X1fqR6Y9XdVKXRrnXHuEy0YigUwlAVnwq0eBg4S7KsAJMVKTE8fzMQmDYESkauj
# +U+XXrlq6+KQLNzxgYHZLAUXiEESyP0J9g3NuhHg9l8fC3ehmwCj8R48n51zX5La
# dL86GmXMKclQjpX7MQB3q3lkfR/5lEElYeR78Eo1rwswpPSe/OQ+Wc4KP7CXRHAp
# O0zMtPq02mgxAB57T8BWONIWhsBRzMsB6DthdZk+i9IOlZxI7amEc2tdnxm2t2zm
# 4Lfmjzf6oIRODjyVN/lhXe/qMw81ZO2ukntuwebwpoyF7ZgwJZ5NXeUHKEK+0KJu
# 8YYGtUkpoGQt0Scwl1RYHGVQQwig+xqJhZQPpuHmn/Ca7LXogcgAqIMMFOFb3eya
# 3jTUoQow/DUII/H60wwK12FkxbPlRsgdOwEH8w==
# SIG # End signature block

class Grype {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$ScanDir

    Grype() {
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
        docker run --rm -v "$($this.ScanDir):$($this.ScanDir)" anchore/grype:v0.120.0 "sbom:$sbom" -o "json=$($this.ReportFile)"
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDSJEIdZxS4wNKA
# JEVgeNOZ65CNZoxpCpIKLUi48YgEQqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFAfmhY2
# pMunKbUgQka4FbIoktEfWlC3DBelpSdJtvHbMAsGCSqGSIb3DQEBAQSCAgCERq0u
# oY3yOtWAFCM/32zcPSEnLXSk6yhS5uxrPQDOf0Pw84MgVQg3KlDznhvcy0LHeMaC
# zQUT4Cy0IHunYB5VPYZypYDBYeDZ8cnXi3sDdMth1QorVunYkZmDHEqFPo1jIj6g
# x9DDj5Cx4KEPdG+J+bZP7Py6rQXTtrNSTlHRoMv1m/ph+cUjz8I0pLkEnOaPYSy2
# tX1MeRc+E7L3RVViw1vJ4iM+x/P043z4SNNmG0VyQ9hHk889K+6TKvOGkTO90dPV
# ZWryMotlS7oqgIInOAyHtzpd+ttgcpfWzC7vUulVMYQf83pYToenOvrV3u6DTfeu
# yNOcO2SHODNCAFC//svmowEMcieQe/pz5gQ6Mrs2ZnvypKA1jTz+rXv/uUe3kwS4
# D1qpc61dd5JTocNGlpkX1xL0yxR3Mij24Rhe7Lxx8Ax1L+iD3R5XJliBHPKWou5x
# +GeILHBlMfAI2VQ81VnpGd6x0COulA0i7jlLZ279qNR87z+q+JYPcAJXC/fxqUto
# OD7g0Zd5zktxFMT++iZgVnbbgGDsLhtPCsMuVJGVSdpWetvTvSmVlRmPvmYF9INE
# LHbAHsLzG2ECVQERMhJYQ/1EJtARDlB87TUyJrKtKEcKMYqS4HFAa4lzeCHgjxAU
# 6EoYLncZUsaMUG6sNwWBOI959hQgWeZ3z97rYA==
# SIG # End signature block

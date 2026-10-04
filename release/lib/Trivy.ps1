class Trivy {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ToolImage
    hidden [string]$ScanDir
    hidden [string]$CacheDir

    Trivy([object]$Settings, [object]$Release) {
        if ([string]::IsNullOrWhiteSpace([string]$Release.Image)) { throw '[!] release image is required' }
        $this.Image = [string]$Release.Image
        $this.ToolImage = '{0}:{1}@{2}' -f $Settings.Require('CONTAINERS.TRIVY.NAME'), $Settings.Require('CONTAINERS.TRIVY.VERSION'), $Settings.Require('CONTAINERS.TRIVY.DIGEST')
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        $this.CacheDir = Join-Path ([System.IO.Path]::GetTempPath()) 'trivy-cache'
        foreach ($dir in @($this.ScanDir, $this.CacheDir)) {
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
        $this.ReportFile = Join-Path $this.ScanDir 'trivy.json'
    }

    [string] ScanImage() {
        & docker run --rm `
            -v '/var/run/docker.sock:/var/run/docker.sock' `
            -v "$($this.CacheDir):/root/.cache/trivy" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            $this.ToolImage image `
            --scanners vuln `
            --severity HIGH,CRITICAL `
            --format json `
            --output $this.ReportFile `
            --exit-code 1 `
            $this.Image
        $exit = $LASTEXITCODE
        if (-not (Test-Path $this.ReportFile)) { throw "[!] trivy report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        if ($exit -ne 0) { throw "[!] trivy scan failed (findings=$($this.FindingCount))" }
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        $count = 0
        foreach ($r in @($data.Results)) {
            if ($r.Vulnerabilities) { $count += @($r.Vulnerabilities).Count }
        }
        return $count
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA80F2cHQ9NmA0Z
# ttpE4DRFM0vU9CrTh4lQ684mq+uchKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFemvpFC
# yTBOMvk3j2Wo3Gf+ArhsrKF9dGBRYYe5nHNLMAsGCSqGSIb3DQEBAQSCAgApUpkJ
# 1QOxt0A9tuWQSnHuHsRCOxKrNkil9IqsAxYpGtyttb3uGxQ8hRPtNqwZJVQM3vCW
# HK1zQQmLwMOIfOXFnONSV7yd+D8E+3B2ShyrtXCkxsUxw5QhRqgiyU/xdlWG8VH3
# Bks8VBJeRT6U5HaGmiip1KUW3Vgr0BHc/WGT/pJ1C8XQZZqzCK3dOgFlqSdxKRWK
# N9pBSYXGeJmMz003v7LpIoZFTTuS1geOhwh6XGUOUwDzSeKpmJEwDj0X8hH2rYnN
# XBjk4nL2nWSpIm43vFOrOCtqNm71j6eSmvsAvklSgntdGi9wkm4tqZGwFTY4TMNq
# u7YmbUHe5giuR1BCaYy1Aqu5gaqTHRZ1KxLjPeBxUVJ0T2Xvx5BChrzw296jRA68
# YmojxPwP9DucWL8gp1nzdXz8ZOZp90ARyvJSzWhQbdK78jbH5u7363w39GP21Sx7
# DWoisTSMGkVbB4irsmF20Cqa8P6V3oeacZNV/rmCsGhGIpbUzOKdbQoFjRfdGkhl
# ArZ5969AUyoQcsYJqYPk+95uyVxX3anRPVNdFwidSoG75XvtOd/p/6L4HWnLoqh7
# ISkdCUTJHboHF4m/Dnkj9fhZAPxQ4gY4qpEm7Cg3RPejxICJapU5tErhFX5iD7yD
# 5JmlBJ6J8JVTTMRx6hgebdQ9uQqhhsW/OgvKZQ==
# SIG # End signature block

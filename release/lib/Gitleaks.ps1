class Gitleaks {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir

    Gitleaks() {
        $this.WorkDir = (Get-Location).Path
        # Keep reports under the runner workdir so DinD can see the bind mount (not /tmp).
        $this.ScanDir = Join-Path $this.WorkDir 'artifacts/release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'gitleaks.json'
    }

    [string] Scan() {
        if (Test-Path $this.ReportFile) { Remove-Item $this.ReportFile -Force }
        $src = $this.WorkDir
        $report = $this.ReportFile
        # actions/checkout often puts gitdir one level above the workspace; mount the parent so git works in Docker.
        $mountRoot = Split-Path -Parent $src
        if (-not $mountRoot) { $mountRoot = $src }
        Write-Host "[+] gitleaks workdir=$src mount=$mountRoot report=$report"
        & docker run --rm `
            -e GIT_DISCOVERY_ACROSS_FILESYSTEM=1 `
            -v "${mountRoot}:${mountRoot}" `
            -w $src `
            zricethezav/gitleaks:v8.21.2 `
            detect --source=$src --report-path=$report --report-format=json --no-banner
        $exit = $LASTEXITCODE
        if (-not (Test-Path $this.ReportFile)) {
            '[]' | Set-Content -Path $this.ReportFile -NoNewline
        }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        if ($exit -ne 0) { throw "[!] gitleaks failed (findings=$($this.FindingCount))" }
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        if ($data -is [array]) { return $data.Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDJlYyQ/mN6olIz
# BVq9CIo8VvzHFf8mvNDOZaQtCT0GHKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINzBUBU9
# AumeiIA3JK5JUPeSWkrEbvvU42v+m2cLMvlwMAsGCSqGSIb3DQEBAQSCAgBiJwzB
# REKA1xnTihEnWLiiz8bCQ3wRS+/CibH+XY0J8d4St1SJ5Igr6HPEsMu/s1xdJJ2V
# d5oOXo557e+NC3q+qA+dQmbNEiFO29QIxIpg//XkbYRi1Nxpw1oHQDHrSr8KHbgR
# qOWNLw2XnEiv01pStBXHrqS6ZX9keerhjggqp2TfIIpp4kRrsa9l0iazuKv0IpIv
# uHMLLrpTPhH5XkutUfV93gY4F6DxEnV/vlKxVmAzy7gMGKPQ6KM3ZTEhBmz3C12v
# LtEhXI7RRjD6YlH1bVqpnMsFG5yXzXJAK/2l8S9k35blod0NUQ6QwfpgNYJa0eXX
# pzaM3w1RPHfJdeIsU7ZT5vtsy0qk4F4jWkxFcoGw2stUsHq4O9SeyOyQZhW7697P
# S4WafARSRWu/lb2ObVMfbE6Xvir2BB+uCrJUodpkKtO84CiX15f9rUsXBP+EyXsS
# YXT1PPafhOlRW+l9lf2epu6H0IvaI0BxB4Zmax0XxyGqx00fUBvQBaf5eXLdUTxM
# 6y8qDCzo1AKfGCwkUyQlAFmawtdReUydsbizE5Qr69kDgLxrk0GNzE9Zz56Dtk2K
# CfdKNbqteTBa7hOgbfv9SFlYGb3rXX5jpIhx5Z6Hsji1PqQ0DTL7U0EbORNwPQHY
# KvgB12KArz0Z5MeRJOxuXgve/MR0/v+mBNPPaw==
# SIG # End signature block

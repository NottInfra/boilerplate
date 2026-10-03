class Semgrep {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir

    Semgrep() {
        $this.WorkDir = (Get-Location).Path
        # Keep reports under the runner workdir so DinD can see the bind mount (not /tmp).
        $this.ScanDir = Join-Path $this.WorkDir 'artifacts/release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'semgrep.json'
    }

    [string] Scan() {
        if (Test-Path $this.ReportFile) { Remove-Item $this.ReportFile -Force }
        $mountRoot = Split-Path -Parent $this.WorkDir
        if (-not $mountRoot) { $mountRoot = $this.WorkDir }
        Write-Host "[+] semgrep workdir=$($this.WorkDir) report=$($this.ReportFile)"
        & docker run --rm `
            -e GIT_DISCOVERY_ACROSS_FILESYSTEM=1 `
            -v "${mountRoot}:${mountRoot}" `
            -w $this.WorkDir `
            semgrep/semgrep:1.96.0 `
            semgrep scan --config p/ci --json --output $this.ReportFile --metrics=off $this.WorkDir
        $exit = $LASTEXITCODE
        # Semgrep exits 1 when findings exist; still require a report.
        if (-not (Test-Path $this.ReportFile)) { throw "[!] semgrep report missing: $($this.ReportFile) (exit=$exit)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        if ($exit -gt 1) { throw "[!] semgrep scan failed (exit=$exit findings=$($this.FindingCount))" }
        if ($this.FindingCount -gt 0) { throw "[!] semgrep findings=$($this.FindingCount)" }
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        if ($data.results) { return @($data.results).Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAcsJEotrRM4hgq
# 8V7/Ke8zKlsKinWuurVtN4+Zs/NzeqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIClj8NGV
# 7smGcDXaH+HiCeQ36YPyejeg+cJCVw77JK/HMAsGCSqGSIb3DQEBAQSCAgBHHjNh
# QEDZhRal0Se7CgcUuSCmMtlxXBGHRSofby7PNS9Za5CwV+ofmDIg4tnAD7QnXJAt
# hqIxmzHDPJkGTgh06tbGfY/wnSo87A3z7IIckAjNSd627Zl3HxSoMx7XO3J+NK1r
# MYGkQwvhYGkhSAEWm4bYdQoRdc0igjGthPI3had0rls16GC4FnDPfEyWMug0e4Xw
# 4Y1iFCQVSvSoQhpE6Ia4mZ4/rmH/7+xonbhFS1Qmwus8C6bboZoAWIZKKWCQA12f
# oJ33jknnG7HDHwtRfXnB+OwOAD1uKKrPCVi5SIYoCJmYy4pF80Fx7uHxRAXZ6qnO
# 9o1lvFGGwQjKU2JCdI90Y1ebjxu9da0XElJDhR6yGmM8+wZKLjnJU6NEmDVpzAAS
# +gNtcIRp+XO9c7q+fbx+i/NRkDUwxYDr0YAmHl7LoPj6h/LBjPaCbaSYh+U5mZxJ
# f5zYfc+fpNjpPFaGBv2TiFXUzNFi1t6CG/wcR3BQmgEeo7BUDO2tuiftxLYlZnv4
# fqgOKr//BwoXt+7yO62AvBZpW64bNIsMTHJpUwOyKIK8V//JydW0MbEFUJakIh9B
# PzRm/b5HtdbByPrHimArUMhlliBnEM6fCLt5U0UHS/5NLrJmj+pzayWClqPzqJ+J
# pS7LhXusDX75PSTPlbZBuwbKD9z9JgbGUulBJQ==
# SIG # End signature block

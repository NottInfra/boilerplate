class Syft {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ScanDir

    Syft([string]$Image) {
        $this.Image = $Image
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
    }

    [string] ScanImage() {
        Write-Host "[+] syft image=$($this.Image)"
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$($this.ScanDir):$($this.ScanDir)" anchore/syft:v1.54.0 $this.Image -o "cyclonedx-json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] syft scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] syft report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        $report = $this.ReportFile
        return $report
    }

    hidden [int] CountFindings([string]$Report) {
        $doc = Get-Content $Report -Raw | ConvertFrom-Json
        if ($doc.vulnerabilities) { return @($doc.vulnerabilities).Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCASLfVwlHfURqBp
# bEjtjcqpQDuVDxOTXU/AQpxK//LbdaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJXeoxWE
# o4GHEtOm1zS9qsj0/1w8qejjX7iDW1cBx7orMAsGCSqGSIb3DQEBAQSCAgAJSxo+
# Boml0Qnsd9k9k9kPSzVU/uyv2IZlIPO5ADyBwQelCmWFUTQdDjtcMBls5Vma6gHL
# 7hg/BSRgGjHBq0aHngqMuDi2VYFHBjyjmjm2fccO6yGpVgk5CjS6TYGUNPqKUggj
# DT8Eh/BTbT5grNCPZx1m2yhz1LKmJLqJOmn8R2snd6ar8xDWa9uWbSJcEU7XRUCX
# pTsnzdbnWg/eDSg9pQ07Ol7Tb5Ene8mK8+0qn9yUJ+cFsJyoPevL4W/c+1tiXiES
# 2ZhIYPcxKGtRp036QS01SnKe2t+yTQYRqOfl+2KhRB3cWBpJimi8m24twv9O1OGZ
# IQ2cpLhc6jaTa/UWZPOUV4d5dIzYkBDUBSCNiNVsXlwrm9Y3l02Fx4RwNh4YVBu+
# Fg2MySev4TcmvZ2twnR5ZP5S7w8FIHvigjmMmJmCUe7SwsXBj4SOVdZOjhjvdUne
# SovzBZnUmUD468HbWZHgKNOhXdsSJtdmtZsDSNiT2bOzq4tIVtcZn2xNotweuw1m
# 375PgszQA1X8WHVm7NrF1fD+0tuSPK4rLQ2zgkSDtAdFhteN8ijwT0RLfXhBV5OH
# qxk2SRakkx88Eb6IYb+kPmjL1vhDSWO/1cDKELukkcVOR8KhnWZn8k8xLzBD9Qfn
# t0G50qf8zLYt11aasrojiJT5mzFyUgURh9Z/wA==
# SIG # End signature block

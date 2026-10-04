class Gitleaks {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir
    hidden [string]$ToolImage

    Gitleaks([object]$Settings) {
        $this.ToolImage = '{0}:{1}@{2}' -f $Settings.Require('CONTAINERS.GITLEAKS.NAME'), $Settings.Require('CONTAINERS.GITLEAKS.VERSION'), $Settings.Require('CONTAINERS.GITLEAKS.DIGEST')
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
            $this.ToolImage `
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDtZ+GDVXt5a4Ic
# k4ZbsxoVJa6jzl9Na4McZL45NKt776CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJfvem73
# DV7U/qoMvlt0sAyg1bamq/G5BpiR+tix2VbGMAsGCSqGSIb3DQEBAQSCAgCVfcwj
# 297bOc1gKIKPt2/ZBwEAd38uq/oLMALSDPrw578TBHtsXSJjhOzUCX7mIw5Hpkx5
# wBLRVNk1BTD7EdEoDdCsflNYgpWP/LwGfSg+4YSuYGtjkFKebBjQqL4ITHGMDs59
# cfy4RPOP+XbfUtfiBthy7UtmW98c/I/T28NPj3Ou7HdLcAa3e0b51ABgJqOfwLJL
# r5egPm/Ziwm+KxAH2SZ+QN+yH1LR/cvj9EELed0ircJ2+zXpYkwR3oAPPRkZilWB
# vQ0SzBjHcFAj3iDlaw8vtYgH2jKNn3Tdy2pnshvsQ4/euo5pd7LFOw0hdiYJTss0
# c5UR1laN0Gq8ZwLpQ9DsyakXqZjZ9SQVvyK13GD8dfLYMZAWJTitqlSMCKTzKpNV
# zePzCgSxJrei2ROgqweaL2HK3o3XPR/kdX0NM6mtHfbOHH/E5T6PSdZpNAr4RMgy
# VhvyR78hWecMthl8fDFmpi2yfi8IPk9TjlIYVHyn/IA6Sv+UIaDiWmxl2OvfAvYi
# r0uAM8I1z70f33JJ8UjV0eJwUMXBcJuWAKCKIG1LRepiOKz8q1IdtuddqxO+IByM
# yEvBaW/WXFrGlyydg8zGeVgBIYKBTPFKF0n6t/hKEb3RPdmwTqrSjvsEtCbFdega
# S1DF93l6++D4W0NRAErx/WEgCv6IByH3+sYqaA==
# SIG # End signature block

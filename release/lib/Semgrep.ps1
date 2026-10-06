class Semgrep {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir
    hidden [string]$ToolImage

    Semgrep([object]$Settings) {
        $this.ToolImage = '{0}:{1}@{2}' -f $Settings.Require('CONTAINERS.SEMGREP.NAME'), $Settings.Require('CONTAINERS.SEMGREP.VERSION'), $Settings.Require('CONTAINERS.SEMGREP.DIGEST')
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
            $this.ToolImage `
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCNREeXgABlOjLP
# F8J14voFd2qL2lcgt+49Dy/30oqZ4KCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINybQhRR
# WRioh1//oUF3cx3EBmeSDZWep9pJOEDjI3cHMAsGCSqGSIb3DQEBAQSCAgCet3ir
# z85tJXQgVlFnKLeTFxcisqx/SGTqbToQT90mbWCltQ872ZGQoIKZaefh12a6wgy/
# rXoPASOjqJA07OQdVghI9Y52ONSWsjoo4qCCu4Wpvq3JzBhtBq0t/wL5u9SnMs25
# EmUadAbAot2ja/pMIpFeuzm7v5T+FRGqj4b/zGxV9xBEk3DBvAL5smrUfRg5BsCi
# gwvFNpVZzqFrHZdoQDG8V0fQ29X1ItF6QtRNL5mXMwHIlLtWaXIcpkbS2WcuBsEs
# Dd4JqU7INMxUHIWSJGjulsLo3qGksd8hvJcozCDnf1lGRSPA74XQvGTlIMg2BRZi
# oN4Qjdl0Q5K8c5tx6vp7dPkYLycWxvP/e4TdravjcM+mk4FePkl6UGWJTg2NhA4V
# WRo4ZY9Nnto1B5GsF0tVNgHCBErN8aTWiZUAPGFcKNJTy/67jZ1jKPztPeVWphWu
# rEUUTa4aNvpSg8WVc64JGhvYr5FTFd136z6eBp9PudE+eIjLKTD5StmxLumyLZKQ
# 7icK+9VeMgZysflillwxmhtl44CwToN2Mm7vBmlpT6KqhCMgcbelbVYaFnQM6v9X
# 3iItpCs1pGb59+Pr4a0C0/SCoypAmYJkj9T0vz6AOFKfmHbRi5EmHJ7xJs6ssY9E
# 2tYaf3OVsCopTXMm976YL7g75sxbbCJB7XiJXQ==
# SIG # End signature block

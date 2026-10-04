class Syft {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ToolImage
    hidden [string]$ScanDir

    Syft([object]$Settings, [object]$Release) {
        if ([string]::IsNullOrWhiteSpace([string]$Release.Image)) { throw '[!] release image is required' }
        $this.Image = [string]$Release.Image
        $this.ToolImage = '{0}:{1}@{2}' -f $Settings.Require('CONTAINERS.SYFT.NAME'), $Settings.Require('CONTAINERS.SYFT.VERSION'), $Settings.Require('CONTAINERS.SYFT.DIGEST')
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
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$($this.ScanDir):$($this.ScanDir)" $this.ToolImage $this.Image -o "cyclonedx-json=$($this.ReportFile)"
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCDf4DCzdQV77OJ
# VP+1qYIOsw15llkWlWjdSJW9MOPBGqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMciXyD7
# Q2i5EBNBu+3mMun95sBPzrQaR0NrkP17Gk1OMAsGCSqGSIb3DQEBAQSCAgCAqzMD
# q2urpKngh1wP3FAk0aZcyKVrj2TUAKJ7kKvOFpTjBStiQbbaNwlqb94BF4pVtYV1
# lAd9e22VYPMVoKcjZXAbEmZI7CGW00pyeekr3erd6BwJGKjNzxuWCEHH0ByZvDOA
# Nj3V00g4TVl5OwPh3uVVxy+lPBGYxnW5hQWpkWDAhQvDsDb1y3motk4+WEnob1ze
# PsYd9zzGzkBvS7JXaZwHDwgWx0xXI3lpA5u3APxywFSKi1XppxY18Zu0jz4myDhx
# g7/aVW6SxrwUyu7C8xqVsKdmFs5xbCNILyywze+ZRuXpzhYr0AXSHbk9uvqnQnAC
# 6nv5pjK/HYHUGm7QFqONHfUjct2Urb++GmSk7LLlphYA0CBif8Mw3V0iscKq621x
# xH63QJ04r3oqdhVzwAEXpQXR67fUOM9EQkiVeP5lBGuV2PvOsh8p6Sr+3SsQ9SrM
# tbxggDcBPQkgsXYW0D8TeWIcsmyXZtEGhfyUJOzcvSAQhtZuGaY4dKHgx5d/EKP1
# J7uJpqqSilvHUhbBUnefU/VkOHMeB6KLyVHkdAJAQpYMTdU7Z744u2uirjQwjaQ0
# BU8HLlEDkwM+0EsGGhh0ngqCl1gqlua3EoFvpmxRpZFPaZ2Vq/rwTnFBhCv3ZwjT
# +rUitZF1yPP57h8UpSzo5/9x6ki39icsv5n+vA==
# SIG # End signature block

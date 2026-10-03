class Sonar {
    hidden [string]$Name
    hidden [string]$Root
    hidden [string]$Token
    hidden [string]$Url
    hidden [string]$WorkDir
    hidden [bool]$Gated
    hidden [string]$BaseBranch
    hidden [string]$Image = 'sonarsource/sonar-scanner-cli:latest'
    [int]$FindingCount
    [string]$FindingSummary

    Sonar([string]$Name, [string]$Root, [bool]$Gated, [string]$BaseBranch) {
        if (-not $env:SONAR_TOKEN) { throw '[!] SONAR_TOKEN is required' }
        if (-not $env:SONAR_URL) { throw '[!] SONAR_URL is required' }
        $this.Name = $Name
        $this.Root = $Root
        $this.Token = $env:SONAR_TOKEN
        $this.Url = $env:SONAR_URL
        try {
            $null = [System.Net.Dns]::GetHostAddresses('sonarqube.sonarqube.svc.cluster.local')
            $this.Url = 'http://sonarqube.sonarqube.svc.cluster.local:9000'
        }
        catch { }
        $this.WorkDir = (Resolve-Path $Root).Path
        $this.Gated = $Gated
        $this.BaseBranch = $BaseBranch
    }

    hidden [string[]] ScannerArgs() {
        $args = @("-Dsonar.projectKey=$($this.Name)")
        if (-not $this.Gated) { return $args }

        $branch = if ($env:CI_COMMIT_REF_NAME) { $env:CI_COMMIT_REF_NAME } else {
            & git -C $this.Root rev-parse --abbrev-ref HEAD 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { throw '[!] cannot resolve current branch for sonar pull request analysis' }
            (& git -C $this.Root rev-parse --abbrev-ref HEAD).Trim()
        }
        $key = if ($env:CI_MERGE_REQUEST_IID) { $env:CI_MERGE_REQUEST_IID } else { $branch }
        $base = if ($env:CI_MERGE_REQUEST_TARGET_BRANCH_NAME) { $env:CI_MERGE_REQUEST_TARGET_BRANCH_NAME } else { $this.BaseBranch }

        $args += "-Dsonar.pullrequest.key=$key"
        $args += "-Dsonar.pullrequest.branch=$branch"
        $args += "-Dsonar.pullrequest.base=$base"
        return $args
    }

    [void] Scan() {
        $props = Join-Path $this.Root 'sonar-project.properties'
        if (-not (Test-Path $props)) { throw "[!] sonar-project.properties missing in $($this.Root)" }

        $mode = if ($this.Gated) { 'pull-request' } else { 'branch' }
        Write-Host "[+] sonar-scanner workdir=$($this.WorkDir) mode=$mode"

        # --network host so the scanner container can reach the cluster Service (DinD shares the pod netns).
        & docker run --rm --network host `
            -e "SONAR_HOST_URL=$($this.Url)" `
            -e "SONAR_TOKEN=$($this.Token)" `
            -v "$($this.WorkDir):/usr/src" `
            -w /usr/src `
            $this.Image `
            @($this.ScannerArgs() + '-Dsonar.qualitygate.wait=true')

        $exit = $LASTEXITCODE
        try { $this.CollectFindings() }
        catch {
            if ($exit -ne 0) { throw '[!] sonar-scanner failed' }
            throw
        }
        if ($this.FindingCount -gt 0) {
            $detail = if ($this.FindingSummary) { $this.FindingSummary } else { '' }
            throw "[!] sonar findings=$($this.FindingCount) $detail"
        }
        if ($exit -ne 0) { throw '[!] sonar-scanner failed' }
    }

    hidden [void] CollectFindings() {
        $headers = @{ Authorization = "Bearer $($this.Token)" }
        $key = [uri]::EscapeDataString($this.Name)
        $issues = Invoke-RestMethod -SkipCertificateCheck -Headers $headers `
            -Uri "$($this.Url)/api/issues/search?componentKeys=$key&resolved=false&ps=1"
        $this.FindingCount = [int]$issues.total
        $gate = Invoke-RestMethod -SkipCertificateCheck -Headers $headers `
            -Uri "$($this.Url)/api/qualitygates/project_status?projectKey=$key"
        $status = [string]$gate.projectStatus.status
        if ($status -eq 'OK' -or $status -eq 'NONE' -or [string]::IsNullOrWhiteSpace($status)) {
            $this.FindingSummary = ''
            return
        }
        $bits = @()
        foreach ($c in @($gate.projectStatus.conditions)) {
            if ($c.status -eq 'ERROR') { $bits += "$($c.metricKey)=$($c.actualValue)" }
        }
        $this.FindingSummary = if ($bits) { $bits -join ', ' } else { $status }
        if ($this.FindingCount -eq 0) { $this.FindingCount = 1 }
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBbupc3pM9U9Gma
# X8waHuiRxma8vStEyICpR+8fgG2J4qCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIN2ElNTh
# Z1dr6/YVazsJcA218izkjtirOB5AY0QD8b+/MAsGCSqGSIb3DQEBAQSCAgChXqyR
# x6vudK1ZiDPFWadYAnQUiSHaG8frwV7anTQbjWAZkI3Nc47SP6Bqe68cHSYaPjV1
# C0gZPVdxSRgaaIUlXoeXSq7flea17Yny6Zh8Ek2rYQMfLZiyT4ZjhdSyKjHHATOI
# 8wMsmnMAiAiBJci3Opu47tXlAwZbOTwBVdrD2rJDeZAKRINg2rL8jEcy8VOUKUdP
# 1fGzPwW1Or4khGvpx93tJq0YDToqG/B6QpIwE4IKSTuB741inNzrNSywo+TyQAhb
# u7Q/db3WccuYZA1g7+MzgZ5/7wbcLWYeTh4k8AgRcW79GsLSH9KbtfXxbd/zrYPt
# F/GlxMnmxjFQgq97BsUUgGzW+fWfeVq7Q13zhL3O0txtk6697992f95k4MAfwaYZ
# Su/ehcB0kcWylZWoXKPTFaZtfAtdkgiGkLWDZgqUVClNu6364UvWFOqrlFYkeZ6X
# VViLyCmmTdGGprT1rRCVJVWeEyYPbQL9CbAoi9twuHFWARDtFfjB3eeQ1vyHTBMt
# 6iCvxIlTa9DbPPe8eeNlYWAy6LvsHc1otnKkTgRGuhlgsRyQGyQxcGv3mW2AQh4B
# hEkxhhm3dz8MkX86oK/DS1QeJ2EoJ2Syihaj/hi+1vvzVseW1EBye+M4KgzU6DSv
# tQ3mOM2kQgdL90mAQnws8hbt/mL1/5S4ZOvyfw==
# SIG # End signature block

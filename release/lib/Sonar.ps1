class Sonar {
    hidden [string]$Name
    hidden [string]$Root
    hidden [string]$Token
    hidden [string]$Url
    hidden [string]$WorkDir
    hidden [bool]$Gated
    hidden [string]$BaseBranch
    hidden [string]$Image
    [int]$FindingCount
    [string]$FindingSummary

    Sonar([object]$Settings, [object]$Project, [string]$Env) {
        if ($Env -notin @('live', 'test')) { throw '[!] env required: live|test' }
        if (-not $env:SONAR_TOKEN) { throw '[!] SONAR_TOKEN is required' }
        $this.Name = $Project.Require('project')
        $this.Root = (Get-Location).Path
        $this.Token = $env:SONAR_TOKEN
        $inCluster = "$env:NETWORK" -eq 'cluster' -or "$env:GITHUB_ACTIONS" -eq 'true'
        $which = if ($inCluster) { 'CLUSTER' } else { 'PUBLIC' }
        $this.Url = ([string]$Settings.Require("ONPREM.ENDPOINTS.SONAR.$which")).TrimEnd('/')
        $this.WorkDir = (Resolve-Path $this.Root).Path
        $this.Gated = $env:RELEASE_PIPELINE -eq 'gated'
        $branch = [string]$Project.Get("remotes.$Env.branch")
        if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'develop' }
        $this.BaseBranch = $branch
        $this.Image = '{0}:{1}@{2}' -f $Settings.Require('CONTAINERS.SONAR.NAME'), $Settings.Require('CONTAINERS.SONAR.VERSION'), $Settings.Require('CONTAINERS.SONAR.DIGEST')
    }

    hidden [string[]] ScannerArgs() {
        # Community Build rejects sonar.pullrequest.* (Developer Edition only).
        return @("-Dsonar.projectKey=$($this.Name)")
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
            $this.FindingCount = 0
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
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCASZmuo1rtGyVR0
# SF15u6tQjjFnf1lTBmCJsAe6PMYfIqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# ezJPirlP+IxtyaFnz10xggMHMIIDAwIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAr2zFIk
# +GELG2DJ7zhkTFO6ijpRsN9cS5GTATe8UXfNMAsGCSqGSIb3DQEBAQSCAgCQMAvF
# 0BFIpvIi7YQnNLhZdshdcv5jBRzphkHhNGQ8SyT7eI3vkpetjOX1zWw+Zg5W9KQx
# ZmzPssB51bboFIw06aTpp9nIiuD8ST0Erk5ZjPyFjfL/vYIky+p27/NPSbX7giF9
# OT83S8ocicVLFW6BGvRYu9RCkOfF1EDI+Xe2UjJDpfmu/yfNjJsFTNLdp+g/+5dz
# bFwws4oIzcu1o+mpAEJ8QsN9BKYRaieMOVdm2YApN5admjm4nhczAdhJm3p2GWi1
# OCtIVirSK6eI/LjgJKUSJtTLEM94HEDF9s4PByoC0AEvX5MpsGg141sQJmOpjJfS
# l0y4FdbhmRZ/G7vk7H6Yr5BLqnWAGplxGxoShRkulOy/riBynGGviEvyDkrqC7ot
# RGhJj89Ho8lbeDN1SsvTOGj0o9XunYntDCjamO9YIRVMk8kU1y99HApzXagYMAD9
# p4T96YutyZdeEveT9wVrlBt+f4L6nTEgJcML3rVj5e99pvRkR5oGEizujZhgEOOP
# pcZ7vRlU7qWezLaxBZEznCaBsf12rBwfYbiRKcHEhJWTQlJbqZqtslEcz6hOkjQV
# uf7JkGHT6usJX8TzqcRmoxCq/DFbfy/4jiHIWwE11b5kB/mDrTWw8j3ExsZi528j
# elurm+EgN7eXstLlbpMrtNi6s2JVGZhjgnHU36ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

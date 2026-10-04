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
        $this.Url = ([string]$Settings.Require("ENDPOINTS.SONAR.$which")).TrimEnd('/')
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
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDLC7BqfuzYeDyM
# VOW8/oGeNd2v785/VOJDOmlRiNiwpKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGiAv/Gt
# 3/Xi2B7mwatQ9pNGeAbPw2vMUR7iHAn9xSWIMAsGCSqGSIb3DQEBAQSCAgCiVP0J
# zTHT3wyTy7ChbBsPA6p+zoP+bxg4tRyGHYWH2Z9thSGWAwzhGAlsSkMcJmk7repZ
# q6CdIQmbNzFR7HggoRmnWLZb3vkK1r50Blefkb8WMBiwHSlKHAqnajyJiav9ULbF
# 7an2ny+JIDLbXRlR1otchSrxFoMIJRFp9uxS5h3r9Rve5jNO8OucyQTvtJ2qrmp0
# 5k6AxNpLvueFuI7blN5JbOHjTPlQBai8QFGwygKMXeOapdG+uQylQ2CFxk1hU27N
# VipkdQ/+oME/Mx83cvhKRSNFnISKnS1j33VfwFdZB6X6/MtKvVL91qNkMsK5IqQk
# PfnGAXyuKHW7sPVBplUd309V/ceuBIqC1X9HxReca+5wjnhHoZC1mykwzd6xkm69
# paQqT/tI1k0WO7W9rgHB4K8mh7MoEzdUUddQGOr5J8Fhd1NvUeaaYV0PCl5EGBeT
# uW622ROKF5bRxqBY1O47o/FpzrmHPcu8CphlFRq1dPxZse/ehth5qffTtw8XzCsw
# AzKgcl7RAaX0I4Hf/wK3+Q75VJaiaC42nSz8zAcEi2K8sun75ixAtqd4lfbNy6a+
# TuFqKnSffjmWVtbeevZ+EdirY8cXoC2bB3yr0EqqdcXIyZyqWcr9+OwBdd+5Gg6k
# 6hIbe81fbQeUPOH62BPKPrceRzAUC1aOJ5fyDg==
# SIG # End signature block

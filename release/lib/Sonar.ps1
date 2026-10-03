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

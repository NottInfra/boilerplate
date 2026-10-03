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

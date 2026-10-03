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

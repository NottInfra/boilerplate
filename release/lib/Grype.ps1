class Grype {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$ScanDir

    Grype() {
        $this.ScanDir = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'grype.json'
    }

    [string] Scan() {
        $sbom = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
        if (-not (Test-Path $sbom)) { throw "[!] grype sbom missing: $sbom (run syft first)" }
        Write-Host "[+] grype sbom=$sbom"
        & docker run --rm `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            anchore/grype:0.84.0 `
            "sbom:$sbom" -o "json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] grype scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] grype report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        if ($data.matches) { return @($data.matches).Count }
        return 0
    }
}

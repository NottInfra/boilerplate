class Syft {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ScanDir

    Syft([string]$Image) {
        $this.Image = $Image
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
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$($this.ScanDir):$($this.ScanDir)" anchore/syft:v1.54.0 $this.Image -o "cyclonedx-json=$($this.ReportFile)"
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

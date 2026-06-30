class Gitleaks {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir

    Gitleaks() {
        $this.ScanDir = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'gitleaks.json'
        $this.WorkDir = (Get-Location).Path
    }

    [string] Scan() {
        if (Test-Path $this.ReportFile) { Remove-Item $this.ReportFile -Force }
        Write-Host "[+] gitleaks workdir=$($this.WorkDir)"
        & docker run --rm `
            -v "$($this.WorkDir):$($this.WorkDir)" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            -w $this.WorkDir `
            zricethezav/gitleaks:8.21.2 `
            detect --source=$this.WorkDir --report-path=$this.ReportFile --report-format=json --no-banner
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

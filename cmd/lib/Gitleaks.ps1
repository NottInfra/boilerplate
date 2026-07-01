class Gitleaks {
    hidden [string]$WorkDir

    Gitleaks() {
        $this.WorkDir = (Get-Location).Path
    }

    [void] Scan() {
        Write-Host "[+] gitleaks workdir=$($this.WorkDir)"
        & docker run --rm `
            -v "$($this.WorkDir):$($this.WorkDir)" `
            -w $this.WorkDir `
            zricethezav/gitleaks:8.21.2 `
            detect --source=$this.WorkDir --no-banner
        if ($LASTEXITCODE -ne 0) { throw '[!] gitleaks failed' }
    }
}

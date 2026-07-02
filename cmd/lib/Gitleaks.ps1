class Gitleaks {
    hidden [string]$WorkDir

    Gitleaks() {
        $this.WorkDir = (Get-Location).Path
    }

    [void] Scan() {
        $src = $this.WorkDir
        Write-Host "[+] gitleaks workdir=$src"
        & docker run --rm `
            -v "${src}:${src}" `
            -w $src `
            zricethezav/gitleaks:v8.21.2 `
            detect --source=$src --no-banner
        if ($LASTEXITCODE -ne 0) { throw '[!] gitleaks failed' }
    }
}

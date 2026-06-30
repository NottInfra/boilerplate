class Sonar {
    hidden [string]$Name
    hidden [string]$Root
    hidden [string]$Token
    hidden [string]$Url
    hidden [string]$WorkDir

    Sonar([string]$Name, [string]$Root) {
        if (-not $env:SONAR_TOKEN) { throw '[!] SONAR_TOKEN is required' }
        if (-not $env:SONAR_HOST_URL) { throw '[!] SONAR_HOST_URL is required' }
        if (-not (Get-Command sonar-scanner -ErrorAction SilentlyContinue)) {
            throw '[!] sonar-scanner is required on the runner'
        }
        $this.Name = $Name
        $this.Root = $Root
        $this.Token = $env:SONAR_TOKEN
        $this.Url = $env:SONAR_HOST_URL
        $this.WorkDir = (Resolve-Path $Root).Path
    }

    [void] Scan() {
        $props = Join-Path $this.Root 'sonar-project.properties'
        if (-not (Test-Path $props)) { throw "[!] sonar-project.properties missing in $($this.Root)" }

        Write-Host "[+] sonar-scanner workdir=$($this.WorkDir)"
        $env:SONAR_HOST_URL = $this.Url
        $env:SONAR_TOKEN = $this.Token
        Push-Location $this.WorkDir
        try {
            & sonar-scanner "-Dsonar.projectKey=$($this.Name)"
            if ($LASTEXITCODE -ne 0) { throw '[!] sonar-scanner failed' }
        }
        finally {
            Pop-Location
        }
    }
}

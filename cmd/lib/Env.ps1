class Env {
    [string]$Root
    [string]$LoadedFile
    [string]$Name

    Env([string]$Root) {
        $this.Root = $Root
        if ($env:ENV_FILE) {
            $path = if ([IO.Path]::IsPathRooted($env:ENV_FILE)) { $env:ENV_FILE } else { Join-Path $Root $env:ENV_FILE }
            $this.Load($path)
        }
        elseif ($env:ENV) {
            $this.Load((Join-Path $Root $this.FileForName($env:ENV)))
        }
        else {
            $this.Pick()
        }
        if (-not $env:ENV) { throw '[!] ENV is required in env file' }
        $this.Name = $env:ENV
    }

    hidden [string] FileForName([string]$Name) {
        switch ($Name.ToLower()) {
            'development' { return '.env.development' }
            'test' { return '.env.test' }
            'production' { return '.env.production' }
            'live' { return '.env.production' }
        }
        throw "[!] unknown ENV: $Name (expected development, test, production)"
    }

    [void] Load([string]$File) {
        if (-not (Test-Path $File)) { throw "[!] missing env file: $File" }
        foreach ($line in Get-Content $File) {
            if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $Matches[1].Trim()
                $val = $Matches[2].Trim()
                if ($val -match '^"(.*)"$') { $val = $Matches[1] }
                elseif ($val -match "^'(.*)'$") { $val = $Matches[1] }
                Set-Item -Path "env:$key" -Value $val
            }
        }
        $this.LoadedFile = $File
        $env:ENV_FILE = $File
    }

    [void] Pick() {
        $candidates = @(
            @{ Label = 'development'; Path = Join-Path $this.Root '.env.development' }
            @{ Label = 'test'; Path = Join-Path $this.Root '.env.test' }
            @{ Label = 'production'; Path = Join-Path $this.Root '.env.production' }
        ) | Where-Object { Test-Path $_.Path }

        if (-not $candidates) { throw '[!] no env files found (.env.development, .env.test, .env.production)' }

        Write-Host ''
        Write-Host 'Env file:'
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            $rel = $candidates[$i].Path.Replace("$($this.Root)/", '').Replace("$($this.Root)\", '')
            Write-Host "  $($i + 1)) $($candidates[$i].Label)  ← $rel"
        }
        $choice = Read-Host "Choose [1-$($candidates.Count)]"
        if (-not $choice) { throw '[!] choice required' }
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $candidates.Count) { throw "[!] invalid choice: $choice" }
        $this.Load($candidates[$idx].Path)
    }
}

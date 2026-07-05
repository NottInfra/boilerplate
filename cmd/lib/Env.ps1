$script:CmdLibDir = $PSScriptRoot

class Env {
    [string]$LoadedFile
    [string]$Name

    Env() {
        $top = git rev-parse --show-toplevel 2>$null
        if ($top) { Set-Location (Resolve-Path $top).Path }
        else { Set-Location (Resolve-Path (Join-Path $script:CmdLibDir '../..')).Path }

        if ($env:ENV_FILE) {
            $path = if ([IO.Path]::IsPathRooted($env:ENV_FILE)) { $env:ENV_FILE } else { $env:ENV_FILE }
            $this.Load($path)
        }
        elseif ($env:ENV) {
            $this.Load($this.FileForName($env:ENV))
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
            'live' { return '.env.live' }
        }
        throw "[!] unknown ENV: $Name (expected development, test, live)"
    }

    [string] VaultStaging() {
        switch ($this.Name.ToLower()) {
            'live' { return 'live' }
            'test' { return 'test' }
        }
        throw "[!] apply-env only pushes test/live env files (selected ENV=$($this.Name))"
    }

    [hashtable] ParseFile([string]$File) {
        if (-not (Test-Path $File)) { throw "[!] missing env file: $File" }
        $data = @{}
        foreach ($line in Get-Content $File) {
            if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $Matches[1].Trim()
                $val = $Matches[2].Trim()
                if ($val -match '^"(.*)"$') { $val = $Matches[1] }
                elseif ($val -match "^'(.*)'$") { $val = $Matches[1] }
                $data[$key] = $val
            }
        }
        return $data
    }

    [void] Load([string]$File) {
        $data = $this.ParseFile($File)
        foreach ($key in $data.Keys) {
            Set-Item -Path "env:$key" -Value $data[$key]
        }
        $this.LoadedFile = $File
        $env:ENV_FILE = $File
    }

    [void] Pick() {
        $candidates = @(
            @{ Label = 'development'; Path = '.env.development' }
            @{ Label = 'test'; Path = '.env.test' }
            @{ Label = 'live'; Path = '.env.live' }
        ) | Where-Object { Test-Path $_.Path }

        if (-not $candidates) { throw '[!] no env files found (.env.development, .env.test, .env.live)' }

        Write-Host ''
        Write-Host 'Env file:'
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "  $($i + 1)) $($candidates[$i].Label)  ← $($candidates[$i].Path)"
        }
        $choice = Read-Host "Choose [1-$($candidates.Count)]"
        if (-not $choice) { throw '[!] choice required' }
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $candidates.Count) { throw "[!] invalid choice: $choice" }
        $this.Load($candidates[$idx].Path)
    }
}

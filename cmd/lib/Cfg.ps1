class Cfg {
    [string]$File

    Cfg([string]$FilePath) {
        if (-not (Test-Path $FilePath)) { throw "[!] missing $FilePath" }
        $this.File = $FilePath
    }

    [string] Get([string]$Key) {
        foreach ($line in Get-Content $this.File) {
            if ($line -match "^$([regex]::Escape($Key)):\s*(.+)$") {
                $val = $Matches[1].Trim()
                if ($val) { return $val }
            }
        }
        throw "[!] $Key not set in $($this.File)"
    }
}

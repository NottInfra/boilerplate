class PostgreSql {
    [string]$DbUrl

    PostgreSql() {
        if (-not $env:DB_URL_PUBLIC) { throw '[!] DB_URL_PUBLIC is required' }
        $this.DbUrl = $env:DB_URL_PUBLIC
    }

    hidden [string] DbNameFromUrl([string]$Url) {
        if ($Url -match 'postgresql://[^/]+/([^?]+)') { return $Matches[1] }
        throw '[!] cannot parse database name from DB_URL_PUBLIC'
    }

    hidden [string] AdminUrl([string]$Url) {
        $db = $this.DbNameFromUrl($Url)
        return $Url -replace "/$([regex]::Escape($db)).*$", '/postgres'
    }

    hidden [bool] Exists([string]$DbUrl, [string]$DbName) {
        $out = & psql $DbUrl -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>$null
        return ($out -match '1')
    }

    [void] EnsureDatabase() {
        $db = $this.DbNameFromUrl($this.DbUrl)
        $admin = $this.AdminUrl($this.DbUrl)
        if ($this.Exists($admin, $db)) {
            Write-Host "[=] database $db exists"
            return
        }
        Write-Host "[+] creating database $db"
        & psql $admin -v ON_ERROR_STOP=1 -c "CREATE DATABASE `"$db`";"
        if ($LASTEXITCODE -ne 0) { throw "[!] CREATE DATABASE failed: $db" }
    }

    [void] ExecFile([string]$SqlFile) {
        & psql $this.DbUrl -v ON_ERROR_STOP=1 -f $SqlFile
        if ($LASTEXITCODE -ne 0) { throw "[!] psql failed: $SqlFile" }
    }
}

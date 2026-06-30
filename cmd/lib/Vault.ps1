class Vault {
    [string]$Addr
    [string]$Token
    [string]$ReadToken

    Vault() {
        if (-not $env:VAULT_ADDR) { throw '[!] VAULT_ADDR is required' }
        if (-not $env:VAULT_TOKEN) { throw '[!] VAULT_TOKEN is required' }
        $this.Addr = $env:VAULT_ADDR.TrimEnd('/')
        $this.Token = $env:VAULT_TOKEN
        $this.ReadToken = if ($env:VAULT_READ_TOKEN) { $env:VAULT_READ_TOKEN } else { $env:VAULT_TOKEN }
    }

    [hashtable] ReadSecret([string]$Path) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        try {
            $r = Invoke-RestMethod -Uri $uri -Headers @{ 'X-Vault-Token' = $this.ReadToken }
            return $r.data.data
        }
        catch { return @{} }
    }

    [void] Load([string]$Path) {
        $secret = $this.ReadSecret($Path)
        foreach ($k in $secret.Keys) {
            Set-Item -Path "env:$k" -Value $secret[$k]
        }
        $env:VAULT_SECRET_PATH = $Path
    }

    [void] Health() {
        $uri = "$($this.Addr)/v1/sys/health?standbyok=true&sealedcode=503&uninitcode=503"
        Invoke-RestMethod -Uri $uri -ErrorAction Stop | Out-Null
    }

    [void] WriteSecret([string]$Path, [hashtable]$Data) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        $body = (@{ data = $Data } | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token } -ContentType 'application/json' -Body $body | Out-Null
    }
}

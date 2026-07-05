class Vault {
    [string]$Addr
    [string]$Token

    Vault() {
        if (-not $env:VAULT_URL_PUBLIC) { throw '[!] VAULT_URL_PUBLIC is required' }
        if (-not $env:VAULT_TOKEN) { throw '[!] VAULT_TOKEN is required' }
        $this.Addr = $env:VAULT_URL_PUBLIC.TrimEnd('/')
        $this.Token = $env:VAULT_TOKEN
    }

    [hashtable] ReadSecret([string]$Path) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        try {
            $r = Invoke-RestMethod -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token }
            $data = $r.data.data
            if ($null -eq $data) { return @{} }
            if ($data -is [hashtable]) { return $data }
            $h = @{}
            foreach ($p in $data.PSObject.Properties) {
                $h[$p.Name] = $p.Value
            }
            return $h
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 404) { return @{} }
            throw "[!] Vault read failed: $uri ($($_.Exception.Message))"
        }
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
        try {
            Invoke-RestMethod -Uri $uri -ErrorAction Stop | Out-Null
        }
        catch {
            throw "[!] Vault health check failed: $uri ($($_.Exception.Message))"
        }
    }

    [hashtable] Compare([string]$Path, [hashtable]$Data) {
        $existing = $this.ReadSecret($Path)
        $added = 0
        $changed = 0
        $unchanged = 0
        foreach ($key in $Data.Keys) {
            if (-not $existing.ContainsKey($key)) {
                $added++
            }
            elseif ([string]$existing[$key] -ne [string]$Data[$key]) {
                $changed++
            }
            else {
                $unchanged++
            }
        }
        $removed = 0
        foreach ($key in $existing.Keys) {
            if (-not $Data.ContainsKey($key)) { $removed++ }
        }
        return @{ Added = $added; Changed = $changed; Unchanged = $unchanged; Removed = $removed }
    }

    [void] WriteSecret([string]$Path, [hashtable]$Data) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        $body = (@{ data = $Data } | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token } -ContentType 'application/json' -Body $body | Out-Null
    }
}

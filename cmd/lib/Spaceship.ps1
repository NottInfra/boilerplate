class Spaceship {
    [string]$BaseUrl
    [string]$ApiKey
    [string]$ApiSecret

    Spaceship() {
        if (-not $env:SPACESHIP_API_KEY) { throw '[!] SPACESHIP_API_KEY is required' }
        if (-not $env:SPACESHIP_API_SECRET) { throw '[!] SPACESHIP_API_SECRET is required' }
        $this.ApiKey = $env:SPACESHIP_API_KEY
        $this.ApiSecret = $env:SPACESHIP_API_SECRET
        $this.BaseUrl = 'https://spaceship.dev/api/v1'
    }

    [object[]] GetRecords([string]$Domain) {
        Write-Host "== Spaceship DNS list: $Domain =="
        $r = Invoke-RestMethod -Method Get -Uri "$($this.BaseUrl)/dns/records/$Domain" -Headers @{
            'X-Api-Key'    = $this.ApiKey
            'X-Api-Secret' = $this.ApiSecret
            Accept         = 'application/json'
        }
        return @($r.items)
    }

    [void] SaveRecords([string]$Domain, [object[]]$Items) {
        Write-Host "== Spaceship DNS save: $Domain ($($Items.Count) record(s)) =="
        foreach ($item in $Items) {
            $n = if ($item.name) { $item.name } else { '@' }
            $addr = if ($item.address) { $item.address } elseif ($item.value) { $item.value } else { '' }
            Write-Host "   → $($item.type) $n → $addr (ttl=$($item.ttl))"
        }
        $body = (@{ force = $true; items = $Items } | ConvertTo-Json -Depth 10 -Compress)
        Invoke-RestMethod -Method Put -Uri "$($this.BaseUrl)/dns/records/$Domain" -Headers @{
            'X-Api-Key'    = $this.ApiKey
            'X-Api-Secret' = $this.ApiSecret
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        } -Body $body | Out-Null
        Write-Host '[+] Spaceship DNS records saved'
    }
}

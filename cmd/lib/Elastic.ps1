class Elastic {
    [string]$Url
    [string]$UserPass
    [string]$Env

    Elastic() {
        if (-not $env:ES_URL) { throw '[!] ES_URL is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        if (-not $env:ELASTIC_USER) { throw '[!] ELASTIC_USER is required' }
        if (-not $env:ELASTIC_PASSWORD) { throw '[!] ELASTIC_PASSWORD is required' }
        $this.Url = $env:ES_URL
        $this.Env = $env:ENV
        $this.UserPass = "$($env:ELASTIC_USER):$($env:ELASTIC_PASSWORD)"
    }

    [void] CreateStream([string]$ProjectName) {
        $dataStream = "$ProjectName-logging"
        $template = @{
            index_patterns = @("${dataStream}*")
            data_stream    = @{}
            priority       = 10000
            template       = @{ mappings = @{ dynamic = $true } }
        } | ConvertTo-Json -Depth 10 -Compress

        $headers = @{}
        if ($this.UserPass) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
            $headers['Authorization'] = "Basic $b64"
        }

        Write-Host "== Elasticsearch: $($this.Url) =="
        Write-Host "== index template ($dataStream) =="
        Invoke-RestMethod -Method Put -Uri "$($this.Url)/_index_template/$dataStream" -Headers $headers -ContentType 'application/json' -Body $template | Out-Null

        Write-Host "== bootstrap document → $dataStream =="
        $doc = (@{
                '@timestamp'             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                event                    = 'import_bootstrap'
                'deployment.environment' = $this.Env
            } | ConvertTo-Json -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$dataStream/_doc?refresh=wait_for" -Headers $headers -ContentType 'application/json' -Body $doc | Out-Null

        Write-Host '== data stream =='
        Invoke-RestMethod -Method Get -Uri "$($this.Url)/_data_stream/$dataStream" -Headers $headers | Out-Null
        Write-Host '== field caps =='
        Invoke-RestMethod -Method Get -Uri "$($this.Url)/$dataStream/_field_caps?fields=event,@timestamp" -Headers $headers | Out-Null
    }

    [void] WriteDoc([string]$DataStream, [hashtable]$Fields) {
        $doc = [ordered]@{ '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        foreach ($k in $Fields.Keys) { $doc[$k] = $Fields[$k] }
        $headers = @{ 'Content-Type' = 'application/json' }
        if ($this.UserPass) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
            $headers['Authorization'] = "Basic $b64"
        }
        $body = ($doc | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$DataStream/_doc" -Headers $headers -Body $body | Out-Null
    }
}

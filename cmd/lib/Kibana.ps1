class Kibana {
    [string]$Url
    [string]$Env
    [string]$ProjectName

    Kibana([string]$ProjectName) {
        if (-not $env:KIBANA_URL_PUBLIC) { throw '[!] KIBANA_URL_PUBLIC is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        $this.Url = $env:KIBANA_URL_PUBLIC
        $this.Env = $env:ENV
        $this.ProjectName = $ProjectName
    }

    hidden [string] PrepareNdjson([string]$File, [string]$Slug) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $title = "$($this.ProjectName) / $Slug"
        foreach ($line in Get-Content $File) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['title']) {
                $obj.attributes.title = $title
            }
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['description']) {
                $cur = [string]$obj.attributes.description
                if ($cur -notmatch [regex]::Escape($this.ProjectName)) {
                    $obj.attributes.description = "$title — $cur".Trim(' —')
                }
            }
            $lines.Add(($obj | ConvertTo-Json -Depth 50 -Compress))
        }
        return ($lines -join "`n")
    }

    hidden [hashtable] Headers() {
        $h = @{ 'kbn-xsrf' = 'true' }
        if ($env:KIBANA_USER) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($env:KIBANA_USER):$($env:KIBANA_PASSWORD)"))
            $h.Authorization = "Basic $b64"
        }
        return $h
    }

    [void] ImportNdjson([string]$File, [string]$Slug) {
        Write-Host "== Kibana import: $($this.Url) =="
        Write-Host "    $($this.ProjectName) / $Slug ← $File"
        $body = $this.PrepareNdjson($File, $Slug)
        $tmp = [IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $tmp -Value $body -NoNewline
            $form = @{ file = Get-Item $tmp }
            $r = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/saved_objects/_import?overwrite=true" `
                -Headers $this.Headers() -Form $form
            if (-not $r.success) {
                $r | ConvertTo-Json -Depth 10
                throw '[!] Kibana import reported errors'
            }
            Write-Host "[+] Kibana dashboard: $($this.ProjectName) / $Slug"
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.ndjson' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] Kibana: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $this.ImportNdjson($f.FullName, $slug)
        }
    }

    [void] ApplyAlertingRules([string]$RulesFile) {
        Write-Host "== Kibana alerting rules: $($this.Url) (ENV=$($this.Env)) =="
        $rules = Get-Content $RulesFile -Raw | ConvertFrom-Json
        foreach ($rule in $rules) {
            $id = $rule.id
            Write-Host "   → $id"
            $create = $rule | Select-Object * -ExcludeProperty id
            if ($create.params.esQuery -and $create.params.esQuery -match '__ENV__') {
                $create.params.esQuery = $create.params.esQuery -replace '__ENV__', $this.Env
            }
            $update = $create | Select-Object * -ExcludeProperty rule_type_id, consumer, enabled
            $uri = "$($this.Url)/api/alerting/rule/$id"
            $headers = $this.Headers()
            $headers['Content-Type'] = 'application/json'
            try {
                Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop | Out-Null
                $body = $update | ConvertTo-Json -Depth 30 -Compress
                Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body | Out-Null
            }
            catch {
                $body = $create | ConvertTo-Json -Depth 30 -Compress
                Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body | Out-Null
            }
            Write-Host "[+] Kibana rule OK: $id"
        }
    }
}

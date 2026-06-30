class Grafana {
    [string]$Url
    [string]$UserPass
    [string]$Env
    [string]$ProjectName

    Grafana([string]$ProjectName) {
        if (-not $env:GRAFANA_URL) { throw '[!] GRAFANA_URL is required' }
        if (-not $env:GRAFANA_ADMIN_USER) { throw '[!] GRAFANA_ADMIN_USER is required' }
        if (-not $env:GRAFANA_ADMIN_PASSWORD) { throw '[!] GRAFANA_ADMIN_PASSWORD is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        $this.Url = $env:GRAFANA_URL
        $this.UserPass = "$($env:GRAFANA_ADMIN_USER):$($env:GRAFANA_ADMIN_PASSWORD)"
        $this.Env = $env:ENV
        $this.ProjectName = $ProjectName
    }

    [void] EnsureFolder([string]$FolderUid, [string]$Title) {
        $uid = "$($this.ProjectName)-$FolderUid"
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $code = 200
        try {
            Invoke-RestMethod -Method Get -Uri "$($this.Url)/api/folders/$uid" -Headers $headers -ErrorAction Stop | Out-Null
        }
        catch {
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode.value__ }
            else { throw }
        }
        if ($code -eq 200) { Write-Host "[+] Grafana folder exists: $uid"; return }
        if ($code -ne 404) { throw "[!] Grafana folder GET HTTP $code" }
        $body = (@{ uid = $uid; title = "$($this.ProjectName) / $Title" } | ConvertTo-Json -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/folders" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        Write-Host "[+] Grafana folder created: $uid"
    }

    [string] PrepareDashboard([string]$File, [string]$Slug) {
        $dash = Get-Content $File -Raw | ConvertFrom-Json
        $dash.title = "$($this.ProjectName) / $Slug ($($this.Env))"
        $dash.uid = "$($this.ProjectName)-$Slug-$($this.Env)"
        if (-not $dash.tags) { $dash.tags = @() }
        if ($dash.tags -notcontains $this.ProjectName) { $dash.tags += $this.ProjectName }
        if ($dash.tags -notcontains $this.Env) { $dash.tags += $this.Env }
        if ($dash.templating -and $dash.templating.list) {
            foreach ($item in $dash.templating.list) {
                if ($item.name -eq 'environment') {
                    $item.current = @{ selected = $true; text = $this.Env; value = $this.Env }
                    $item.options = @(@{ selected = $true; text = $this.Env; value = $this.Env })
                }
            }
        }
        return ($dash | ConvertTo-Json -Depth 50 -Compress)
    }

    [void] ImportDashboard([string]$DashboardJson, [string]$FolderUid) {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $dash = $DashboardJson | ConvertFrom-Json
        $payload = (@{
            dashboard = $dash
            folderUid = $FolderUid
            overwrite = $true
            message   = 'apply-dashboards'
        } | ConvertTo-Json -Depth 50 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/dashboards/db" -Headers $headers -ContentType 'application/json' -Body $payload | Out-Null
        Write-Host "[+] Grafana dashboard: $($dash.title) → folder/$FolderUid"
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.json' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] Grafana: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $folderUid = "$($this.ProjectName)-$slug"
            $this.EnsureFolder($slug, $slug)
            $dash = $this.PrepareDashboard($f.FullName, $slug)
            $this.ImportDashboard($dash, $folderUid)
        }
    }

    [void] ApplyAlertingRules([string]$RulesFile) {
        Write-Host "== Grafana alerting rules: $($this.Url) (ENV=$($this.Env)) =="
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $doc = Get-Content $RulesFile -Raw | ConvertFrom-Json
        $this.EnsureFolder($doc.folder.uid, $doc.folder.title)
        $folderUid = "$($this.ProjectName)-$($doc.folder.uid)"
        foreach ($rule in $doc.rules) {
            $json = ($rule | ConvertTo-Json -Depth 50 -Compress) -replace '__ENV__', $this.Env
            $parsed = $json | ConvertFrom-Json
            $parsed.folderUid = $folderUid
            $json = $parsed | ConvertTo-Json -Depth 50 -Compress
            $uid = $parsed.uid
            Write-Host "   → $uid"
            $uri = "$($this.Url)/api/v1/provisioning/alert-rules/$uid"
            $ruleHeaders = $headers.Clone()
            $ruleHeaders['X-Disable-Provenance'] = 'true'
            $code = 200
            try {
                Invoke-RestMethod -Method Put -Uri $uri -Headers $ruleHeaders -ContentType 'application/json' -Body $json -ErrorAction Stop | Out-Null
            }
            catch {
                if ($_.Exception.Response) {
                    $code = [int]$_.Exception.Response.StatusCode.value__
                    if ($code -eq 404) {
                        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v1/provisioning/alert-rules" -Headers $ruleHeaders -ContentType 'application/json' -Body $json | Out-Null
                        $code = 200
                    }
                    else { throw }
                }
                else { throw }
            }
            if ($code -lt 200 -or $code -ge 300) { throw "[!] Grafana rule $uid HTTP $code" }
            Write-Host "[+] Grafana rule OK: $uid"
        }
    }
}

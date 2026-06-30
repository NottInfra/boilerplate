class PostHog {
    [string]$BaseUrl
    [string]$Token
    [string]$ProjectId
    [string]$Env
    [string]$ProjectName
    [bool]$ResolvedProjectId

    PostHog([string]$ProjectName) {
        if (-not $env:POSTHOG_URL) { throw '[!] POSTHOG_URL is required' }
        if (-not $env:POSTHOG_API_KEY) { throw '[!] POSTHOG_API_KEY is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        $this.BaseUrl = $env:POSTHOG_URL.TrimEnd('/')
        $this.Token = $env:POSTHOG_API_KEY
        $this.Env = $env:ENV
        $this.ProjectName = $ProjectName
        $this.ResolvedProjectId = $false
        if ($env:POSTHOG_PROJECT_ID) {
            $this.ProjectId = $env:POSTHOG_PROJECT_ID
        }
        else {
            $this.ProjectId = $this.FindOrCreateProject()
            $this.ResolvedProjectId = $true
        }
    }

    hidden [string] FindOrCreateProject() {
        $headers = @{ Authorization = "Bearer $($this.Token)"; 'Content-Type' = 'application/json' }
        $r = Invoke-RestMethod -Uri "$($this.BaseUrl)/api/projects/" -Headers $headers
        foreach ($p in $r.results) {
            if ($p.name -eq $this.ProjectName) {
                Write-Host "[+] PostHog project: $($this.ProjectName) (id=$($p.id))"
                return [string]$p.id
            }
        }
        $body = (@{ name = $this.ProjectName } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri "$($this.BaseUrl)/api/projects/" -Headers $headers -Body $body
        Write-Host "[+] PostHog project created: $($this.ProjectName) (id=$($created.id))"
        return [string]$created.id
    }

    hidden [object] FindDashboard([string]$Name) {
        $headers = @{ Authorization = "Bearer $($this.Token)"; 'Content-Type' = 'application/json' }
        $uri = "$($this.BaseUrl)/api/projects/$($this.ProjectId)/dashboards/?search=$([uri]::EscapeDataString($Name))"
        $r = Invoke-RestMethod -Uri $uri -Headers $headers
        foreach ($d in $r.results) {
            if ($d.name -eq $Name) { return $d }
        }
        return $null
    }

    [void] ImportDashboard([string]$File, [string]$Slug) {
        $name = "$($this.ProjectName) / $Slug"
        Write-Host "== PostHog import: $($this.BaseUrl) =="
        Write-Host "    $name ← $File"
        $template = Get-Content $File -Raw | ConvertFrom-Json
        if ($template.name) { $template.name = $name }
        else { $template | Add-Member -NotePropertyName name -NotePropertyValue $name -Force }
        $headers = @{ Authorization = "Bearer $($this.Token)"; 'Content-Type' = 'application/json' }
        $existing = $this.FindDashboard($name)
        if ($existing) {
            $uri = "$($this.BaseUrl)/api/projects/$($this.ProjectId)/dashboards/$($existing.id)/"
            Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -Body ($template | ConvertTo-Json -Depth 50 -Compress) | Out-Null
            Write-Host "[+] PostHog dashboard updated: $name"
            return
        }
        $uri = "$($this.BaseUrl)/api/projects/$($this.ProjectId)/dashboards/create_from_template_json/"
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body ($template | ConvertTo-Json -Depth 50 -Compress) | Out-Null
        Write-Host "[+] PostHog dashboard created: $name"
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.json' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] PostHog: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $this.ImportDashboard($f.FullName, $slug)
        }
    }
}

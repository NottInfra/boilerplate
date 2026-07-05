class DefectDojo {
    [string]$Url
    [string]$Token
    [string]$ProjectName
    [int]$EngagementId

    DefectDojo([string]$ProjectName) {
        if (-not $env:DEFECT_DOJO_URL_PUBLIC) { throw '[!] DEFECT_DOJO_URL_PUBLIC is required' }
        if (-not $env:DEFECT_DOJO_API_TOKEN) { throw '[!] DEFECT_DOJO_API_TOKEN is required' }
        $this.Url = $env:DEFECT_DOJO_URL_PUBLIC.TrimEnd('/')
        $this.Token = $env:DEFECT_DOJO_API_TOKEN
        $this.ProjectName = $ProjectName
        if ($env:DEFECT_DOJO_ENGAGEMENT_ID) {
            $this.EngagementId = [int]$env:DEFECT_DOJO_ENGAGEMENT_ID
        }
    }

    [int] EnsureEngagement() {
        if ($this.EngagementId) { return $this.EngagementId }
        $staging = $this.StagingFromEnv()
        $engagementName = "$($this.ProjectName)-$staging"
        $productId = $this.EnsureProduct()
        $existing = $this.FindEngagement($productId, $engagementName)
        if ($existing) {
            $this.EngagementId = [int]$existing.id
            Write-Host "[+] Defect Dojo engagement: $engagementName (id=$($this.EngagementId))"
            return $this.EngagementId
        }
        $created = $this.CreateEngagement($productId, $engagementName)
        $this.EngagementId = [int]$created.id
        Write-Host "[+] Defect Dojo engagement created: $engagementName (id=$($this.EngagementId))"
        return $this.EngagementId
    }

    [void] ImportScan([string]$Staging, [string]$ScanType, [string]$ReportFile, [string]$StepName) {
        if (-not $this.EngagementId) { throw '[!] DEFECT_DOJO_ENGAGEMENT_ID is required' }
        if (-not (Test-Path $ReportFile)) { throw "[!] report missing: $ReportFile" }
        $title = "$($this.ProjectName)-$Staging-$StepName"
        $form = @{
            scan_type        = $ScanType
            test_title       = $title
            engagement       = $this.EngagementId
            file             = Get-Item -LiteralPath $ReportFile
            active           = 'true'
            verified         = 'true'
            minimum_severity = 'Info'
        }
        $uri = "$($this.Url)/api/v2/reimport-scan/"
        Write-Host "[+] Defect Dojo import: $ScanType → $title"
        $r = Invoke-RestMethod -Method Post -Uri $uri -Headers $this.Headers() -Form $form
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }

    hidden [hashtable] Headers() {
        return @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
    }

    hidden [string] StagingFromEnv() {
        switch ($env:ENV.ToLower()) {
            'live' { return 'live' }
            { $_ -in @('test', 'development') } { return 'test' }
            default { throw "[!] ENV must be development, test, or live (got $env:ENV)" }
        }
    }

    hidden [int] EnsureProduct() {
        $uri = "$($this.Url)/api/v2/products/?name=$([uri]::EscapeDataString($this.ProjectName))"
        $r = Invoke-RestMethod -Uri $uri -Headers $this.Headers()
        foreach ($p in $r.results) {
            if ($p.name -eq $this.ProjectName) {
                Write-Host "[+] Defect Dojo product: $($this.ProjectName) (id=$($p.id))"
                return [int]$p.id
            }
        }
        $body = (@{ name = $this.ProjectName; description = $this.ProjectName } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/products/" `
            -Headers ($this.Headers() + @{ 'Content-Type' = 'application/json' }) -Body $body
        Write-Host "[+] Defect Dojo product created: $($this.ProjectName) (id=$($created.id))"
        return [int]$created.id
    }

    hidden [object] FindEngagement([int]$ProductId, [string]$Name) {
        $uri = "$($this.Url)/api/v2/engagements/?product=$ProductId&name=$([uri]::EscapeDataString($Name))"
        $r = Invoke-RestMethod -Uri $uri -Headers $this.Headers()
        foreach ($e in $r.results) {
            if ($e.name -eq $Name) { return $e }
        }
        return $null
    }

    hidden [object] CreateEngagement([int]$ProductId, [string]$Name) {
        $start = (Get-Date).ToString('yyyy-MM-dd')
        $end = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
        $body = (@{
            product      = $ProductId
            name         = $Name
            target_start = $start
            target_end   = $end
            status       = 'In Progress'
        } | ConvertTo-Json -Compress)
        return Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/engagements/" `
            -Headers ($this.Headers() + @{ 'Content-Type' = 'application/json' }) -Body $body
    }
}

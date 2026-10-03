class DefectDojo {
    hidden [string]$Url
    hidden [string]$Token
    hidden [int]$EngagementId
    hidden [string]$ProjectName

    DefectDojo([string]$ProjectName) {
        $dojoUrl = $env:DEFECTDOJO_URL
        if (-not $dojoUrl) { $dojoUrl = $env:DEFECT_DOJO_URL }
        if (-not $dojoUrl) { throw '[!] DEFECTDOJO_URL is required' }
        if (-not $env:DEFECT_DOJO_API_TOKEN) { throw '[!] DEFECT_DOJO_API_TOKEN is required' }
        if (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) { throw '[!] DEFECT_DOJO_ENGAGEMENT_ID is required' }
        $this.Url = $dojoUrl.TrimEnd('/')
        # Public gateway cuts scan imports (~75s) with 502. Runners can hit the Service directly.
        try {
            $null = [System.Net.Dns]::GetHostAddresses('defectdojo.defectdojo.svc.cluster.local')
            $this.Url = 'http://defectdojo.defectdojo.svc.cluster.local:8080'
            Write-Host '[+] Defect Dojo via cluster service'
        }
        catch { }
        $this.Token = $env:DEFECT_DOJO_API_TOKEN
        $this.EngagementId = [int]$env:DEFECT_DOJO_ENGAGEMENT_ID
        $this.ProjectName = $ProjectName
    }

    [void] ImportScan([string]$Staging, [string]$ScanType, [string]$ReportFile, [string]$StepName) {
        if (-not (Test-Path $ReportFile)) { throw "[!] report missing: $ReportFile" }
        $title = "$($this.ProjectName)-$Staging-$StepName"
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $form = @{
            scan_type           = $ScanType
            test_title          = $title
            product_name        = $this.ProjectName
            engagement_name     = "$($this.ProjectName)-$Staging"
            engagement          = $this.EngagementId
            file                = Get-Item -LiteralPath $ReportFile
            active              = 'true'
            verified            = 'true'
            minimum_severity    = 'Info'
            auto_create_context = 'true'
            close_old_findings  = 'true'
        }
        Write-Host "[+] Defect Dojo import: $ScanType → $title"
        $r = $this.PostScan("$($this.Url)/api/v2/import-scan/", $headers, $form, $title)
        if (-not $r) {
            $r = $this.PostScan("$($this.Url)/api/v2/reimport-scan/", $headers, $form, $title)
        }
        if (-not $r) { throw '[!] Defect Dojo import failed' }
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }

    hidden [object] PostScan([string]$Uri, [hashtable]$Headers, [hashtable]$Form, [string]$Title) {
        for ($i = 1; $i -le 3; $i++) {
            try {
                return Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Form $Form `
                    -SkipCertificateCheck -TimeoutSec 300
            }
            catch {
                $code = 0
                if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
                $msg = $_.Exception.Message
                # uwsgi closes the socket after a long import even when the test was saved.
                if ($msg -match 'ResponseEnded|prematurely|502|Bad Gateway') {
                    if ($this.TestExists($Title)) {
                        Write-Host '[+] Defect Dojo import saved; HTTP body was truncated'
                        return @{ saved = $true }
                    }
                }
                if ($code -eq 400) { return $null }
                if ($i -lt 3 -and ($code -in 0, 502, 503, 504)) {
                    Write-Host "[i] Defect Dojo HTTP $code, retry $i/3"
                    Start-Sleep -Seconds (10 * $i)
                    continue
                }
                throw
            }
        }
        if ($this.TestExists($Title)) {
            Write-Host '[+] Defect Dojo import saved after retries'
            return @{ saved = $true }
        }
        return $null
    }

    hidden [bool] TestExists([string]$Title) {
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $uri = "$($this.Url)/api/v2/tests/?engagement=$($this.EngagementId)&limit=100"
        $r = Invoke-RestMethod -Uri $uri -Headers $headers -SkipCertificateCheck -TimeoutSec 60
        foreach ($t in @($r.results)) {
            if ($t.title -eq $Title) { return $true }
        }
        return $false
    }
}

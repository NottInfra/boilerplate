class AlertMgr {
    hidden [string]$Url

    AlertMgr() {
        if (-not $env:ALERTMANAGER_URL) { throw '[!] ALERTMANAGER_URL is required' }
        $this.Url = $env:ALERTMANAGER_URL.TrimEnd('/')
        try {
            $null = [System.Net.Dns]::GetHostAddresses('alertmanager.monitoring.svc.cluster.local')
            $this.Url = 'http://alertmanager.monitoring.svc.cluster.local:9093'
            Write-Host '[+] AlertMgr via cluster service'
        }
        catch { }
    }

    [void] Alert([string]$Message) {
        $this.Alert($Message, 'warning')
    }

    [void] Alert([string]$Message, [string]$Severity) {
        if ([string]::IsNullOrWhiteSpace($Message)) { return }
        if ([string]::IsNullOrWhiteSpace($Severity)) { $Severity = 'warning' }
        $alert = [ordered]@{
            labels      = [ordered]@{
                alertname = 'ReleaseAlert'
                severity  = $Severity
            }
            annotations = [ordered]@{
                summary     = $Message
                description = $Message
            }
        }
        $body = '[' + ($alert | ConvertTo-Json -Depth 6 -Compress) + ']'
        Write-Host "[+] AlertMgr $Message"
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/alerts" `
            -ContentType 'application/json' -Body $body -SkipCertificateCheck -TimeoutSec 30 | Out-Null
    }
}

class OpenSearch {
    hidden [string]$Url
    hidden [string]$UserPass
    hidden [string]$Env
    hidden [string]$Stream
    hidden [string]$Staging
    hidden [string]$ProjectName

    OpenSearch([string]$ProjectName, [string]$Env) {
        if (-not $env:OPENSEARCH_URL) { throw '[!] OPENSEARCH_URL is required' }
        if (-not $env:OPENSEARCH_USER) { throw '[!] OPENSEARCH_USER is required' }
        if (-not $env:OPENSEARCH_PASSWORD) { throw '[!] OPENSEARCH_PASSWORD is required' }
        $this.Url = $env:OPENSEARCH_URL.TrimEnd('/')
        try {
            $null = [System.Net.Dns]::GetHostAddresses('opensearch.opensearch.svc.cluster.local')
            $this.Url = 'http://opensearch.opensearch.svc.cluster.local:9200'
        }
        catch { }
        $this.Env = $Env
        $this.UserPass = "$($env:OPENSEARCH_USER):$($env:OPENSEARCH_PASSWORD)"
        $this.ProjectName = $ProjectName
        $this.Staging = $Env
        $this.Stream = "$ProjectName-pipeline"
    }

    [void] Step([string]$Step, [string]$Status) {
        $this.Step($Step, $Status, @{})
    }

    [void] Step([string]$Step, [string]$Status, [hashtable]$Extra) {
        if (-not $Extra) { $Extra = @{} }
        $fields = [ordered]@{
            event                    = 'pipeline_step'
            'deployment.environment' = $this.Env
            pipeline                 = @{
                staging = $this.Staging
                step    = $Step
                status  = $Status
            }
            project                  = $this.ProjectName
        }
        foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
        $this.WriteDoc($this.Stream, $fields)
    }

    [void] Finding([string]$Scanner, [string]$Status, [int]$Count, [string]$ReportFile) {
        $fields = [ordered]@{
            event                    = 'pipeline_finding'
            'deployment.environment' = $this.Env
            scanner                  = $Scanner
            status                   = $Status
            finding_count            = $Count
            report                   = $ReportFile
            project                  = $this.ProjectName
            pipeline                 = @{ staging = $this.Staging }
        }
        $this.WriteDoc("$($this.ProjectName)-findings", $fields)
    }

    hidden [void] WriteDoc([string]$DataStream, [hashtable]$Fields) {
        $doc = [ordered]@{ '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        foreach ($k in $Fields.Keys) { $doc[$k] = $Fields[$k] }
        $headers = @{ 'Content-Type' = 'application/json' }
        $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers['Authorization'] = "Basic $b64"
        $body = ($doc | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$DataStream/_doc" `
            -Headers $headers -Body $body -SkipCertificateCheck -TimeoutSec 30 | Out-Null
    }
}

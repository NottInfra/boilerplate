class GitLab : GitRemote {
    [string]$ApiUrl
    [string]$Token

    GitLab([string]$Remote, [string]$LocalPath) : base($Remote, $LocalPath) {
        if (-not $env:GITLAB_URL) { throw '[!] GITLAB_URL is required' }
        if (-not $env:GITLAB_TOKEN) { throw '[!] GITLAB_TOKEN is required' }
        $this.ApiUrl = $env:GITLAB_URL.TrimEnd('/')
        $this.Token = $env:GITLAB_TOKEN
    }

    [object] Api([string]$Path, [string]$Method = 'Get', [object]$Body = $null) {
        $uri = "$($this.ApiUrl)/api/v4$Path"
        $headers = @{ 'PRIVATE-TOKEN' = $this.Token }
        $params = @{ Uri = $uri; Method = $Method; Headers = $headers; ErrorAction = 'Stop' }
        if ($null -ne $Body) {
            $params.ContentType = 'application/json'
            $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        }
        return Invoke-RestMethod @params
    }

    [void] CreateRepo([string]$Name, [string]$NamespaceId = '', [bool]$Private = $true) {
        $body = @{
            name                   = $Name
            path                   = $Name
            visibility             = if ($Private) { 'private' } else { 'public' }
            initialize_with_readme = $false
        }
        if ($NamespaceId) { $body.namespace_id = $NamespaceId }
        [void]$this.Api('/projects', 'Post', $body)
        Write-Host "[+] GitLab project created: $Name"
    }

    [void] ScheduleCi([string]$Ref, [string]$Description = 'Daily CI', [string]$Cron = '0 0 * * *') {
        $projectPath = [uri]::EscapeDataString([GitRemote]::ParseUrl($this.Remote).Path)
        $project = $this.Api("/projects/$projectPath")
        $schedules = @($this.Api("/projects/$($project.id)/pipeline_schedules"))
        $existing = $schedules | Where-Object { $_.ref -eq $Ref -and $_.cron -eq $Cron } | Select-Object -First 1
        $body = @{
            description   = $Description
            ref           = $Ref
            cron          = $Cron
            cron_timezone = 'UTC'
            active        = $true
        }
        if ($existing) {
            [void]$this.Api("/projects/$($project.id)/pipeline_schedules/$($existing.id)", 'Put', $body)
            Write-Host "[+] GitLab pipeline schedule updated: $Cron on $Ref"
            return
        }
        [void]$this.Api("/projects/$($project.id)/pipeline_schedules", 'Post', $body)
        Write-Host "[+] GitLab pipeline schedule created: $Cron on $Ref"
    }
}

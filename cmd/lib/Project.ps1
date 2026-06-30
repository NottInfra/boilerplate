class Project {
    [string]$File
    [string]$Name
    [string]$Staging
    [string]$Domain
    [string]$Host
    [string]$Endpoint
    [string]$Server
    [string]$HostPort
    [string]$ContainerPort
    [string]$RemoteName
    [string]$RemoteUrl
    [string]$Branch
    [string]$Release

    Project([string]$FilePath) {
        $this.File = $FilePath
        if (-not (Test-Path $this.File)) { throw "[!] missing $($this.File)" }
        $this.Name = $this.Top('project')
        if ([string]::IsNullOrWhiteSpace($this.Name)) { throw '[!] project name required in project.yml' }

        if (-not $env:ENV) { return }

        $this.Staging = switch ($env:ENV.ToLower()) {
            'production' { 'live' }
            'live' { 'live' }
            'prod' { 'live' }
            'test' { 'test' }
            'development' { 'test' }
            default { throw "[!] ENV must be development, test, or production (got $env:ENV)" }
        }

        $this.Domain = $this.PublicKey('domain')
        $this.Host = $this.PublicKey('host')
        $this.Endpoint = $this.AppKey('endpoint')
        $this.Server = $this.AppKey('server')
        $this.HostPort = $this.AppPort('host')
        $this.ContainerPort = $this.AppPort('container')
        $this.RemoteName = $this.RemoteKey('remote')
        $this.RemoteUrl = $this.RemoteKey('url')
        $this.Branch = $this.RemoteKey('branch')
        $this.Release = $this.RemoteKey('release')
    }

    [string] ServerName() {
        if ($this.Server) { return $this.Server }
        foreach ($st in @('live', 'test')) {
            $s = $this.AppKeyFor($st, 'server')
            if ($s) { return $s }
        }
        throw '[!] public.app.*.server required in project.yml'
    }

    [string] IaCPath([string]$Kind) {
        $srv = $this.ServerName()
        if ($Kind -eq 'caddy') { return "servers/$srv/host/caddy/configs/$($this.Name).caddy" }
        if ($Kind -eq 'blackbox') { return "servers/$srv/docker/blackbox/configs/https/$($this.Name).json" }
        if ($Kind -eq 'app-compose') { return "servers/$srv/docker/$($this.Name)/compose.yml" }
        throw "[!] unknown IaC path kind: $Kind"
    }

    [object[]] BlackboxTargets() {
        $pubDomain = $this.PublicKey('domain')
        $rows = [System.Collections.Generic.List[object]]::new()
        foreach ($stage in @('live', 'test')) {
            $url = $this.AppKeyFor($stage, 'endpoint')
            if ([string]::IsNullOrWhiteSpace($url)) { continue }
            $srv = $this.AppKeyFor($stage, 'server')
            if ([string]::IsNullOrWhiteSpace($srv)) { throw "[!] public.app.$stage.server required in project.yml" }
            $vhost = ($url -replace '^https?://', '').Split('/')[0]
            $rows.Add([ordered]@{
                targets = @($url)
                labels  = @{ service = $this.Name; host = $srv; vhost = $vhost }
            })
            if ($stage -eq 'live' -and $pubDomain) {
                $rows.Add([ordered]@{
                    targets = @("https://www.$pubDomain")
                    labels  = @{ service = $this.Name; host = $srv; vhost = "www.$pubDomain" }
                })
            }
        }
        return $rows
    }

    [hashtable] DnsPlan() {
        $registry = $this.DnsKey('registry')
        $pubDomain = $this.PublicKey('domain')
        $pubHost = $this.PublicKey('host')
        if ([string]::IsNullOrWhiteSpace($pubDomain)) { throw '[!] public.domain required in project.yml' }
        if ([string]::IsNullOrWhiteSpace($pubHost)) { throw '[!] public.host required in project.yml' }
        if ([string]::IsNullOrWhiteSpace($registry)) { throw '[!] public.dns.registry required in project.yml' }
        $names = $this.DnsList('A')
        if (-not $names -or $names.Count -eq 0) { throw '[!] public.dns.A required in project.yml' }
        return @{
            Registry = $registry
            Domain   = $pubDomain
            Host     = $pubHost
            Names    = $names
        }
    }

    hidden [string] DnsKey([string]$Key) {
        $inPublic = $inDns = $false
        foreach ($line in Get-Content $this.File) {
            if ($line -eq 'public:') { $inPublic = $true; continue }
            if ($inPublic -and $line -match '^[^ #]' -and $line -notmatch '^  ') { break }
            if ($inPublic -and $line -eq '  dns:') { $inDns = $true; continue }
            if ($inDns -and $line -match '^  [^ ]' -and $line -ne '  dns:') { break }
            if ($inDns -and $line -match "^    $([regex]::Escape($Key)):\s*(.*)$") { return $Matches[1].Trim() }
        }
        return ''
    }

    hidden [string[]] DnsList([string]$Type) {
        $inPublic = $inDns = $inList = $false
        $items = [System.Collections.Generic.List[string]]::new()
        foreach ($line in Get-Content $this.File) {
            if ($line -eq 'public:') { $inPublic = $true; continue }
            if ($inPublic -and $line -match '^[^ #]' -and $line -notmatch '^  ') { break }
            if ($inPublic -and $line -eq '  dns:') { $inDns = $true; continue }
            if ($inDns -and $line -match '^  [^ ]' -and $line -ne '  dns:') { $inDns = $false; $inList = $false }
            if ($inDns -and $line -eq "    ${Type}:") { $inList = $true; continue }
            if ($inList -and $line -match '^    \S+:' -and $line -ne "    ${Type}:") { $inList = $false }
            if ($inList -and $line -match '^\s+-\s+(.*)$') {
                $items.Add($Matches[1].Trim().Trim('"').Trim("'"))
            }
        }
        return $items.ToArray()
    }

    hidden [string] Top([string]$Key) {
        foreach ($line in Get-Content $this.File) {
            if ($line -match "^$([regex]::Escape($Key)):\s*(.*)$") { return $Matches[1].Trim() }
        }
        return ''
    }

    hidden [string] PublicKey([string]$Key) {
        $in = $false
        foreach ($line in Get-Content $this.File) {
            if ($line -eq 'public:') { $in = $true; continue }
            if ($in -and $line -match '^[^ #]' -and $line -notmatch '^  ') { break }
            if ($in -and $line -match "^  $([regex]::Escape($Key)):\s*(.*)$") { return $Matches[1].Trim() }
        }
        return ''
    }

    hidden [string] AppKey([string]$Key) {
        return $this.AppKeyFor($this.Staging, $Key)
    }

    hidden [string] AppKeyFor([string]$Staging, [string]$Key) {
        $inPublic = $inApp = $inStage = $false
        foreach ($line in Get-Content $this.File) {
            if ($line -eq 'public:') { $inPublic = $true; continue }
            if ($inPublic -and $line -match '^[^ #]' -and $line -notmatch '^  ') { break }
            if ($inPublic -and $line -eq '  app:') { $inApp = $true; continue }
            if ($inApp -and $line -eq "    ${Staging}:") { $inStage = $true; continue }
            if ($inStage -and $line -match '^    [^ ]' -and $line -ne "    ${Staging}:") { $inStage = $false }
            if ($inStage -and $line -match "^      $([regex]::Escape($Key)):\s*(.*)$") { return $Matches[1].Trim() }
        }
        return ''
    }

    hidden [string] AppPort([string]$Key) {
        $st = $this.Staging
        $inPublic = $inApp = $inStage = $inPorts = $false
        foreach ($line in Get-Content $this.File) {
            if ($line -eq 'public:') { $inPublic = $true; continue }
            if ($inPublic -and $line -match '^[^ #]' -and $line -notmatch '^  ') { break }
            if ($inPublic -and $line -eq '  app:') { $inApp = $true; continue }
            if ($inApp -and $line -eq "    ${st}:") { $inStage = $true; continue }
            if ($inStage -and $line -match '^    [^ ]' -and $line -ne "    ${st}:") { $inStage = $false; $inPorts = $false }
            if ($inStage -and $line -eq '      ports:') { $inPorts = $true; continue }
            if ($inStage -and $inPorts -and $line -match '^      [^ ]' -and $line -ne '      ports:') { $inPorts = $false }
            if ($inStage -and $inPorts -and $line -match "^        $([regex]::Escape($Key)):\s*(\S+)") { return $Matches[1] }
        }
        return ''
    }

    hidden [string] RemoteKey([string]$Key) {
        $st = $this.Staging
        $in = $inStage = $false
        foreach ($line in Get-Content $this.File) {
            if ($line -eq 'remotes:') { $in = $true; continue }
            if ($in -and $line -match '^[^ #]' -and $line -notmatch '^  ') { break }
            if ($in -and $line -eq "  ${st}:") { $inStage = $true; continue }
            if ($inStage -and $line -match '^  [^ ]' -and $line -ne "  ${st}:") { $inStage = $false }
            if ($inStage -and $line -match "^    $([regex]::Escape($Key)):\s*(.*)$") { return $Matches[1].Trim() }
        }
        return ''
    }
}

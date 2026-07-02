class ProjectConfigParse {
    hidden [string]$File
    hidden [hashtable]$Tree
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

    ProjectConfigParse([string]$FilePath) {
        $this.File = $FilePath
        if (-not (Test-Path $this.File)) { throw "[!] missing $($this.File)" }
        $this.Tree = $this.ReadYaml()
        $this.Name = [string]$this.Get('project')
        if ([string]::IsNullOrWhiteSpace($this.Name)) { throw '[!] project name required in project.cfg' }

        if (-not $env:ENV) { return }

        $norm = $env:ENV.ToLower()
        $accepted = @('live', 'test', 'dev', 'development')
        if ($accepted -notcontains $norm) { throw "[!] ENV must be live, test, dev, or development (got $env:ENV)" }
        $this.Staging = $norm

        $st = $this.Staging
        $this.Domain = [string]$this.Get("public.domain")
        $this.Host = [string]$this.Get("public.host")
        $this.Endpoint = [string]$this.Get("public.app.$st.endpoint")
        $this.Server = [string]$this.Get("public.app.$st.server")
        $this.HostPort = [string]$this.Get("public.app.$st.ports.host")
        $this.ContainerPort = [string]$this.Get("public.app.$st.ports.container")
        $this.RemoteName = [string]$this.Get("remotes.$st.remote")
        $this.RemoteUrl = [string]$this.Get("remotes.$st.url")
        $this.Branch = [string]$this.Get("remotes.$st.branch")
        $this.Release = [string]$this.Get("remotes.$st.release")
    }

    [object] Get([string]$Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) { return $this.ToObject($this.Tree) }
        $node = $this.Tree
        foreach ($part in $Path.Split('.')) {
            if ($null -eq $node) { return $null }
            if ($node -is [System.Collections.IDictionary] -and $node.Contains($part)) {
                $node = $node[$part]
            }
            else { return $null }
        }
        return $this.ToObject($node)
    }

    [string] Require([string]$Path) {
        $val = $this.Get($Path)
        if ($null -eq $val -or ($val -is [string] -and [string]::IsNullOrWhiteSpace($val))) {
            throw "[!] $Path not set in $($this.File)"
        }
        return [string]$val
    }

    hidden [hashtable] ReadYaml() {
        $doc = [ordered]@{}
        $stack = [System.Collections.Generic.List[object]]::new()
        $stack.Add([ordered]@{ Map = $doc; Indent = -1 })
        $lines = Get-Content $this.File

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*(#|$)') { continue }

            if ($line -match '^(\s*)-\s+(.*)$') {
                $indent = $Matches[1].Length
                $value = $this.Unquote($Matches[2].Trim())
                $this.TrimStack($stack, $indent)
                $map = $stack[$stack.Count - 1].Map
                $listKey = $null
                foreach ($k in $map.Keys) {
                    if ($map[$k] -is [System.Collections.Generic.List[object]]) { $listKey = $k }
                }
                if (-not $listKey) { throw "[!] invalid list in $($this.File): $line" }
                [void]$map[$listKey].Add($value)
                continue
            }

            if ($line -notmatch '^(\s*)([^:]+?):\s*(.*)$') { continue }
            $indent = $Matches[1].Length
            $key = $Matches[2].Trim()
            $value = $Matches[3].Trim()
            $this.TrimStack($stack, $indent)
            $frame = $stack[$stack.Count - 1]

            if ($value -eq '') {
                $next = $this.NextContentLine($lines, $i)
                if ($next -match ('^' + (' ' * $indent) + '-\s+')) {
                    $frame.Map[$key] = [System.Collections.Generic.List[object]]::new()
                    continue
                }
                $child = [ordered]@{}
                $frame.Map[$key] = $child
                $stack.Add([ordered]@{ Map = $child; Indent = $indent })
                continue
            }

            $frame.Map[$key] = $this.Unquote($value)
        }

        return $doc
    }

    hidden [string] NextContentLine([string[]]$Lines, [int]$Index) {
        for ($j = $Index + 1; $j -lt $Lines.Count; $j++) {
            if ($Lines[$j] -notmatch '^\s*(#|$)') { return $Lines[$j] }
        }
        return ''
    }

    hidden [void] TrimStack([System.Collections.Generic.List[object]]$Stack, [int]$Indent) {
        while ($Stack.Count -gt 1 -and $Stack[$Stack.Count - 1].Indent -ge $Indent) {
            $Stack.RemoveAt($Stack.Count - 1)
        }
    }

    hidden [string] Unquote([string]$Value) {
        if ($Value.StartsWith('"') -and $Value.EndsWith('"')) { return $Value.Substring(1, $Value.Length - 2) }
        if ($Value.StartsWith("'") -and $Value.EndsWith("'")) { return $Value.Substring(1, $Value.Length - 2) }
        return $Value
    }

    hidden [object] ToObject([object]$Node) {
        if ($Node -is [System.Collections.IDictionary]) {
            $o = [PSCustomObject]@{}
            foreach ($k in $Node.Keys) {
                $o | Add-Member -NotePropertyName $k -NotePropertyValue ($this.ToObject($Node[$k]))
            }
            return $o
        }
        if ($Node -is [System.Collections.Generic.List[object]]) {
            return @($Node | ForEach-Object { $this.ToObject($_) })
        }
        if ($Node -is [array]) {
            return @($Node | ForEach-Object { $this.ToObject($_) })
        }
        return $Node
    }
}

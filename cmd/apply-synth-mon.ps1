#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

$project = [ProjectConfigParse]::new()

$pubDomain = [string]$project.Get('public.domain')
$rows = [System.Collections.Generic.List[object]]::new()
foreach ($stage in @('live', 'test')) {
    $url = [string]$project.Get("public.app.$stage.endpoint")
    if ([string]::IsNullOrWhiteSpace($url)) { continue }
    $srv = [string]$project.Get("public.app.$stage.server")
    if ([string]::IsNullOrWhiteSpace($srv)) { throw "[!] public.app.$stage.server required in project.cfg" }
    $vhost = ($url -replace '^https?://', '').Split('/')[0]
    $rows.Add([ordered]@{
        targets = @($url)
        labels  = @{ service = $project.Name; host = $srv; vhost = $vhost }
    })
    if ($stage -eq 'live' -and $pubDomain) {
        $rows.Add([ordered]@{
            targets = @("https://www.$pubDomain")
            labels  = @{ service = $project.Name; host = $srv; vhost = "www.$pubDomain" }
        })
    }
}
$json = ($rows | ConvertTo-Json -Depth 10 -Compress)

$git = [SourceControl]::new($project.Require('remotes.iac.url'))
try {
    $git.Sync()
    $iacPath = "docker/blackbox/configs/https/$($project.Name).json"
    $git.WriteContent($iacPath, $json)
    $git.CommitAndPush("blackbox: $($project.Name)")
    Write-Host "[+] Done — synth-mon → $iacPath ($($env:ENV))"
}
finally {
    $git.Cleanup()
}

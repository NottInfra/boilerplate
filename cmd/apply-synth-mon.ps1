#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/lib/GitRemote.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$project = [ProjectConfigParse]::new((Join-Path $Root 'project.cfg'))

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

$iacGit = $project.Require('remotes.iac.url')
$workDir = Join-Path ([IO.Path]::GetTempPath()) "iac-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    $git = [GitRemote]::ForRemote($iacGit, $workDir)
    $git.Sync()
    $iacPath = "docker/blackbox/configs/https/$($project.Name).json"
    $git.WriteContent($iacPath, $json)
    $git.CommitAndPush("blackbox: $($project.Name)")
    Write-Host "[+] Done — synth-mon → $iacPath"
}
finally {
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

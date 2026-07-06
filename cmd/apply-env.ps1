#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Vault.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

$envLoader = [Env]::new()
$project = [Config]::new('project.cfg')
$vault = [Vault]::new()
$vault.Health()

$staging = $envLoader.VaultStaging()
$secret = "$staging-$($project.Name)"
$data = $envLoader.ParseFile($envLoader.LoadedFile)
$diff = $vault.Compare($secret, $data)

$settingsPath = 'settings.cfg'
$settingsData = @{}
$settingsDiff = @{ Added = 0; Changed = 0; Unchanged = 0; Removed = 0 }
if (Test-Path $settingsPath) {
    $settingsData = [Config]::new($settingsPath).VaultFlat()
    $settingsDiff = $vault.Compare('config', $settingsData)
}

$ciVars = @{
    VAULT_URL           = $data['VAULT_URL']
    VAULT_TOKEN         = $data['VAULT_TOKEN']
    VAULT_SECRET_PREFIX = $staging
}
if (-not $ciVars.VAULT_URL) { throw '[!] VAULT_URL missing in env file' }
if (-not $ciVars.VAULT_TOKEN) { throw '[!] VAULT_TOKEN missing in env file' }

$remoteUrl = $project.Require("remotes.$staging.url")
$ciLabel = if ($env:ENV -eq 'live') { "GitHub $remoteUrl" } else { "GitLab $remoteUrl" }

Write-Host ''
Write-Host "Vault @ $($vault.Addr)"
Write-Host "Project: $($project.Name)"
Write-Host "[i] $staging : secret/$secret"
Write-Host "    source: $($envLoader.LoadedFile)"
Write-Host "    added=$($diff.Added) changed=$($diff.Changed) unchanged=$($diff.Unchanged) removed=$($diff.Removed)"
if (Test-Path $settingsPath) {
    Write-Host '[i] config : secret/config'
    Write-Host "    source: $settingsPath"
    Write-Host "    keys=$($settingsData.Count) added=$($settingsDiff.Added) changed=$($settingsDiff.Changed) unchanged=$($settingsDiff.Unchanged) removed=$($settingsDiff.Removed)"
}
else {
    Write-Host '[i] config : skipped (no settings.cfg)'
}
Write-Host "[i] CI → $ciLabel"
foreach ($key in $ciVars.Keys) {
    Write-Host "    $key=$($ciVars[$key])"
}

if ((Read-Host 'Apply? [y/N]') -notmatch '^[yY]$') {
    Write-Host '[=] skipped'
    exit 0
}

$vault.WriteSecret($secret, $data)
Write-Host "[+] secret/$secret updated"

if ($settingsData.Count -gt 0) {
    $vault.WriteSecret('config', $settingsData)
    Write-Host "[+] secret/config updated ($($settingsData.Count) keys)"
}

$ci = [SourceControl]::new($remoteUrl)
$ci.SetCiVars($ciVars)

Write-Host '[+] Done'

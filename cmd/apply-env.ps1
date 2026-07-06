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
$configSecret = "$staging-$($project.Name)-config"
$data = $envLoader.ParseFile($envLoader.LoadedFile)
$diffSecret = $vault.Compare($secret, $data)

$config = [Config]::new('settings.cfg')
$diffConfig = $vault.Compare($configSecret, $config.Data)

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
Write-Host "    added=$($diffSecret.Added) changed=$($diffSecret.Changed) unchanged=$($diffSecret.Unchanged) removed=$($diffSecret.Removed)"
if ($config.Loaded) {
    Write-Host "[i] config : secret/$configSecret"
    Write-Host '    source: settings.cfg'
    Write-Host "    keys=$($config.Data.Count) added=$($diffConfig.Added) changed=$($diffConfig.Changed) unchanged=$($diffConfig.Unchanged) removed=$($diffConfig.Removed)"
}
else {
    Write-Host "[i] config : skipped (no settings.cfg)"
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

if ($config.Loaded) {
    $vault.WriteSecret($configSecret, $config.Data)
    Write-Host "[+] secret/$configSecret updated ($($config.Data.Count) keys)"
}

$ci = [SourceControl]::new($remoteUrl)
$ci.SetCiVars($ciVars)

Write-Host '[+] Done'

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('build', 'started')

try {
    $registry = [Registry]::new($project.Root, $project.Image)
    $registry.Build()
    if ($staging -eq 'test') {
        $registry.Push()
    }
    $elastic.Step('build', 'succeeded')
}
catch {
    $elastic.Step('build', 'failed', @{ error = $_.Exception.Message })
    throw
}

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Project.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Project]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('push', 'started')

try {
    [Registry]::new($project.Root, $project.Image).Push()
    $elastic.Step('push', 'succeeded')
}
catch {
    $elastic.Step('push', 'failed', @{ error = $_.Exception.Message })
    throw
}

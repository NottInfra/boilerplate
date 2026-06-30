#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/Project.ps1"
. "$PSScriptRoot/../lib/Sonar.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [Project]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('sonar', 'started')

try {
    [Sonar]::new($project.Name, $project.Root).Scan()
    $elastic.Step('sonar', 'succeeded')
}
catch {
    $elastic.Step('sonar', 'failed', @{ error = $_.Exception.Message })
    throw
}

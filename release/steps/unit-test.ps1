#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('unit-test', 'started')

try {
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        throw '[!] make is required for unit tests'
    }
    Write-Host '[+] unit-test via make test-docker'
    & make test-docker
    if ($LASTEXITCODE -ne 0) { throw '[!] unit tests failed' }
    $os.Step('unit-test', 'succeeded')
}
catch {
    $os.Step('unit-test', 'failed', @{ error = $_.Exception.Message })
    throw
}

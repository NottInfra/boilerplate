#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$os.Step('deploy', 'started')

try {
    $sourceImage = $project.ReleaseImage()
    if ($sourceImage -ne $project.Image) {
        $source = [Registry]::new($project.Root, $sourceImage)
        $source.Pull()
        $source.Tag($project.Image)
    }

    [Registry]::new($project.Root, $project.Image).Push()
    $os.Step('deploy', 'succeeded')
}
catch {
    $os.Step('deploy', 'failed', @{ error = $_.Exception.Message })
    throw
}

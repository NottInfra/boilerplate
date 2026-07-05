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
    $artifactDir = if ($env:ARTIFACT_DIR) {
        (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
    }
    else {
        $project.Root
    }

    $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
    $releaseImage = if ($env:RELEASE_IMAGE) {
        $env:RELEASE_IMAGE
    }
    elseif ($sha) {
        "$($env:REGISTRY_URL)/$($project.Name):ci-$sha"
    }
    else {
        $project.Image
    }

    $registry = [Registry]::new($project.Root, $releaseImage)
    $registry.Build()
    if ($sha -or $staging -eq 'test') {
        $registry.Push()
    }

    $artifact = [ordered]@{
        image = $releaseImage
        targetImage = $project.Image
        commit = $sha
        staging = $staging
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $artifact | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $artifactDir 'build-artifact.json') -Encoding utf8

    $elastic.Step('build', 'succeeded')
}
catch {
    $elastic.Step('build', 'failed', @{ error = $_.Exception.Message })
    throw
}

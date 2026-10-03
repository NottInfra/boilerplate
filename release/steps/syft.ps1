#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Syft.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Syft]::new($project.ReleaseImage())

$os.Step('syft', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
    $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
    $os.Finding('syft', 'succeeded', $scanner.FindingCount, $report)
    if ($scanner.FindingCount -gt 0) {
        [AlertMgr]::new().Alert("syft found $($scanner.FindingCount) finding(s)")
    }
    $os.Step('syft', 'succeeded')
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) {
        $report = $candidate
        $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
        $os.Finding('syft', 'failed', $scanner.FindingCount, $report)
        if ($scanner.FindingCount -gt 0) {
            [AlertMgr]::new().Alert("syft found $($scanner.FindingCount) finding(s)")
        }
    }
    $os.Step('syft', 'failed', @{ error = $err.Exception.Message })
    throw $err
}

#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Grype.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/OpenSearch.ps1"
. "$PSScriptRoot/../lib/AlertMgr.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$os = [OpenSearch]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Grype]::new()

$os.Step('grype', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.Scan()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Anchore Grype', $report, 'grype')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $os.Finding('grype', $status, $scanner.FindingCount, $report)
}
if ($scanner.FindingCount -gt 0) {
    $severity = 'warning'
    if ($report -and (Test-Path $report)) {
        $doc = Get-Content $report -Raw | ConvertFrom-Json
        foreach ($match in @($doc.matches)) {
            if ([string]$match.vulnerability.severity -match '^(?i)(critical|high)$') { $severity = 'critical'; break }
        }
    }
    [AlertMgr]::new().Alert("grype found $($scanner.FindingCount) finding(s)", $severity)
}
if ($err) {
    $os.Step('grype', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$os.Step('grype', 'succeeded', @{ finding_count = $scanner.FindingCount })

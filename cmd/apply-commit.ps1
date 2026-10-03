#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-commit', 'started')

    $channel = switch ($Env.Name.ToLower()) {
        'live' { 'live' }
        { $_ -in @('test', 'development', 'dev') } { 'test' }
        default { throw "[!] apply-commit requires development, test, or live (got $($Env.Name))" }
    }

    foreach ($name in @('live', 'test')) {
        $remote = $Project.Require("remotes.$name.remote")
        $url = $Project.Require("remotes.$name.url")
        git remote get-url $remote 2>$null
        if ($LASTEXITCODE -eq 0) { git remote set-url $remote $url }
        else { git remote add $remote $url }
    }

    $targetRemote = $Project.Require("remotes.$channel.remote")
    $targetUrl = $Project.Require("remotes.$channel.url")
    $targetBranch = $Project.Require("remotes.$channel.branch")

    Write-Host ''
    Write-Host "[+] Push target: $channel → $targetRemote / $targetBranch (ENV=$($Env.Name))"

    [Gitleaks]::new().Scan()

    $git = [SourceControl]::new($Env, $Settings, $targetUrl, [GitHub]::new(), [GitLab]::new($Env))
    $msg = $git.PromptCommitMessage()
    $git.Commit($msg)
    # PR title / branch slug = conventional header only (type[(scope)][!]: description)
    $prTitle = (($msg -replace "`r", '') -split "`n")[0].Trim()
    if ([string]::IsNullOrWhiteSpace($prTitle)) { $prTitle = $msg.Trim() }

    if ((Read-Host 'Create pull request? [y/N]') -match '^[yY]$') {
        $slug = $prTitle -replace '\s+', '-' -replace '[~^:?*\[\\]', '' -replace '\.+', '.'
        if ([string]::IsNullOrWhiteSpace($slug)) { throw '[!] Commit message cannot produce a valid branch name' }
        $branch = $git.CreateBranch("pull-request/$slug", $targetRemote)
        $git.PreparePullRequestBranch($branch, $targetRemote, $targetBranch)
        $git.PushBranch($targetRemote, $branch)
        $prUrl = $git.CreatePullRequest($branch, $targetBranch, $prTitle)
        Write-Host "[+] PR $branch → $targetBranch ($prUrl)"
    }
    else {
        git push $targetRemote "HEAD:$targetBranch"
        Write-Host "[+] Pushing $channel → $targetRemote $targetBranch ($($Project.Name))"
    }
    $os.Step('apply-commit', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-commit', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-commit', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCnpfTwJ7VEvDIN
# DvdcGpr1B8rxAE8FaiYzbxWaUQF7mKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
# R/b0C5YxX/PjyDAKBggqhkjOPQQDAjAgMR4wHAYDVQQDExVOb3R0SW5mcmEgSW50
# ZXJuYWwgQ0EwHhcNMjYwNzI3MjM0NDE1WhcNMjcwNzI3MjM0NDE1WjAlMSMwIQYD
# VQQDExpOT1RUSU5GUkEgTElNSVRFRCBTT0ZUV0FSRTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAKRICuzioM/pLsdWW/uV0Hl7Y5FHNBPTEl3X/oGK+BAi
# kC0es0CLXLykWpsJ/f9ldyyHlMzwUR1zEIhCZXEyo+uqQ8B1yWke7rQ4wkWE6/DU
# htCLSiySkf/KB389/ptcEM+jJ48DQGi0+8K6QQ02vEOAQKLfxA4Rrnl5BYY+nnNs
# Rpa+B6K40i/aFAsc60gbG3SGQePzuHHbPl6CE5AzQNY2WBpY77aonZ830RM5AsS4
# Xe7P8cDJ7Gahw6ZjLEriCaR3xBytPy63RiZdW8upuQ0AIFz4/8GVRYuOJ1wGeU53
# b0OZhj/6Z481Zry0VcBvGfHidIVkQKbWZQ2QWdkSBbSAIR92tKpSqSDy4VQYQ4RO
# l3NY/QHkJsAl6EGzQ514P+qUzkSyxgSNHZFCknqTu6gXtemaCUC7z/eLZDibw+mg
# yAuyLTZoeAlDPaHT4FOPfB8pn6UuGb/LwJwFlBHGAkaYlfAkx3BJYIsQpfPwKxfN
# Ufds8LMYArJlFZJnJ1EmJSE+qIu0cN7SyuFDAdGszrVjltYswzAfhE0NRQQm4HiG
# CWG9ZxDD1TxbhvEecgJCOMy/dZCcjEEzq4wZxSVPicn0QowKDWHy1GpgdR3pT+Ok
# zuIBpfEeXW5uW9e0yoOzwOnh1XCRp8hv+B4l4RvTEl3ccZ+PcmAcsLHODqvW4vmT
# AgMBAAGjQTA/MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
# MBaAFKF88Blhy5xs0hQfn4medNFL3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDwlWDa
# ojXZG8h5O2XzW/IG9h+GUKAmx8SCd7NuhB0SUAIgJkQlleqNoGkPuDyi08MuVI36
# ezJPirlP+IxtyaFnz10xggLaMIIC1gIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINRXB1TJ
# o4BIJzx/TAFWwV97pPBdMTK5MGVnSPfbzN1OMAsGCSqGSIb3DQEBAQSCAgBIiyXc
# kJWnM5/x2DT7jMes1iTT3kQG3qaPMQskWiEvfoJOnBpjy15AknyKMrOw01hsufF9
# TQp4yaniyoNz9fkhzh9QOqmnjoEeWkniCJqv9uq9nTvMekTRVmZPbIFDi+z5NOr8
# z471Kq62L3O/ozj32R7qNYFCMg2YKpmb8aKDhiY5hdgjOrIGEv/zCEdUR15PGyFG
# LwIs/4SBkaZka+Sl7w/JIKHxUENAq8eQ3GvCovZSi2eqTDE+WzjhArhfesES5llx
# Yx32pfHw7ZDIbsDzJiLoLjMUBHnVzZxo6UmQGqCQNCUKH+0PshQ3B1cHWj6Qp8Es
# 14fgRexBTbhRK5M4Re4CbkhNlnQlgbErqz5oRyB4rid+pzpUsFWU5vk18bR8txgh
# 9T83HfR6rMHfd+JYmej4zCHuOd9/O+5+5KVhxWNHmIH1JyF+hxTywuVKN9A65IMD
# DJPliltdLkWWO10XH7qpIyvXBpQI2XmkIgAVa/YY2XjsYPJD1LsLC9DV0i6ziNUx
# kcjbEZp75rd8NJxEgMjGJDlaTMy1ralGoGqd5U1EcSm3XB25gI4Joz1t4x0OMLwg
# 09kgf1Yw2A8fb3u2XE3Pp2KvbHZUbk+7YE0L2YYR0a5RKMWBsFqDNaJA0cy/mqXL
# ypxMqtcK5+U3uRZMetVAYldPvK+UEdggDAppCw==
# SIG # End signature block

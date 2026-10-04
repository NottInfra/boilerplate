class OpenSearch {
    hidden [string]$Url
    hidden [string]$UserPass
    hidden [string]$Env
    hidden [string]$Stream
    hidden [string]$Staging
    hidden [string]$ProjectName

    OpenSearch([object]$Settings, [object]$Project, [string]$Env) {
        if ($Env -notin @('live', 'test')) { throw '[!] env required: live|test' }
        if (-not $env:OPENSEARCH_USER) { throw '[!] OPENSEARCH_USER is required' }
        if (-not $env:OPENSEARCH_PASSWORD) { throw '[!] OPENSEARCH_PASSWORD is required' }
        $which = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
        $this.Url = ([string]$Settings.Require("ENDPOINTS.OPENSEARCH.$which")).TrimEnd('/')
        $name = $Project.Require('project')
        $this.Env = $Env
        $this.UserPass = "$($env:OPENSEARCH_USER):$($env:OPENSEARCH_PASSWORD)"
        $this.ProjectName = $name
        $this.Staging = $Env
        $this.Stream = ("$name-pipeline").ToLower()
    }

    [void] Step([string]$Step, [string]$Status) {
        $this.Step($Step, $Status, @{})
    }

    [void] Step([string]$Step, [string]$Status, [hashtable]$Extra) {
        if (-not $Extra) { $Extra = @{} }
        $fields = [ordered]@{
            event                    = 'pipeline_step'
            'deployment.environment' = $this.Env
            pipeline                 = @{
                staging = $this.Staging
                step    = $Step
                status  = $Status
            }
            project                  = $this.ProjectName
        }
        foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
        $this.WriteDoc($this.Stream, $fields)
    }

    [void] Finding([string]$Scanner, [string]$Status, [int]$Count, [string]$ReportFile) {
        $fields = [ordered]@{
            event                    = 'pipeline_finding'
            'deployment.environment' = $this.Env
            scanner                  = $Scanner
            status                   = $Status
            finding_count            = $Count
            report                   = $ReportFile
            project                  = $this.ProjectName
            pipeline                 = @{ staging = $this.Staging }
        }
        $this.WriteDoc(("$($this.ProjectName)-findings").ToLower(), $fields)
    }

    hidden [void] WriteDoc([string]$DataStream, [hashtable]$Fields) {
        $doc = [ordered]@{ '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        foreach ($k in $Fields.Keys) { $doc[$k] = $Fields[$k] }
        $headers = @{ 'Content-Type' = 'application/json' }
        $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers['Authorization'] = "Basic $b64"
        $body = ($doc | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$DataStream/_doc" `
            -Headers $headers -Body $body -SkipCertificateCheck -TimeoutSec 30 | Out-Null
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBSFMNjedaNpluH
# QmoIk7U0nQcnLw2CznBBfYkj5rbjpKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPi3uAqV
# PNB7eeDadd3wo5mFYhSUCMaFPcaIAKStfG+uMAsGCSqGSIb3DQEBAQSCAgB/5x1E
# rWAos2QXi+58+yrpNTSNHAO3wp8F8QGLx3AOix+EJKxHYm37q1kKEAwouTh7yANm
# rvDSxj+TSYX9ebk02CT58RauGPRVyTBAas8WWUDYcH6lkZd/HZYN6tvmu5n0+S9c
# bOscedM8KiXk+HFnYxhYPhdfmHTQJa4a7rzvFBJItOgIyMhtJx2y5VsggXPujb7L
# UZNT+EcOeTdLhP9dVXl0phnwd/3oFxE9GU+PUGGojRrzqVAcgTl0SlvC5Pyhk/xM
# t9zIeuBIbCQfO/1ZgrX+iwNjTPZbYlllPlj93HuqEZrHQFnKLyuah3C0Cndbbrlp
# dMyoL+HQOEE8DMWo0+ZTjnxKcW+Cy0eA1Amz+SgeAVbj1RsVQrTiCK0ruK0EGx/n
# M4rsGM8d1FZt48sXi75Eg7GuBDXMJDXvoPUu32ZBwLdQWphRhzlQMsU4+Edh+9vS
# CH1l+A7nJ0HsSkVL1qOcQJzsaHqokXsZME6eJCGRI0248oOYDem5+IwJkWHmw8/k
# V8wdx8A9gfi905QQK3829zr2i/uDeHD1jpu2L0nsitlRY7illYwaEpqb3s3CvjVG
# JEzsz+JrdUKFoh6oIygxc+68K3UdqHVEkGh0ONJUNeM/+rFQrOXSE0aK1CPI3re0
# hWlzYBdamNVqX2QlIAi9KoYIoeh7GRmYW7RZVg==
# SIG # End signature block

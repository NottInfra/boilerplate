class Registry {
    hidden [object]$Settings
    hidden [object]$Project
    hidden [string]$Env
    hidden [string]$Root
    [string]$Type
    [string]$Image
    [string]$TargetImage

    Registry([object]$Settings, [object]$Project, [string]$Env) {
        if ($Env -notin @('live', 'test')) { throw '[!] env required: live|test' }
        $kind = $Project.Require('type').ToLower()
        if ($kind -notin @('service', 'package')) { throw '[!] project.cfg type must be service or package' }
        $this.Settings = $Settings
        $this.Project = $Project
        $this.Env = $Env
        $this.Type = $kind
        $this.Root = (Get-Location).Path
        if ($kind -ne 'service') { return }
        $hostName = $this.RegistryHost()
        $name = $Project.Require('project')
        $tag = if ($Env -eq 'live') { 'prod' } else { 'test' }
        $this.TargetImage = "$hostName/${name}:$tag"
        $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
        if ($env:RELEASE_IMAGE) { $this.Image = $env:RELEASE_IMAGE }
        elseif ($sha) { $this.Image = "$hostName/${name}:ci-$sha" }
        else { $this.Image = $this.TargetImage }
    }

    hidden [string] RegistryHost() {
        $which = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
        $hostName = [string]$this.Settings.Require("ENDPOINTS.REGISTRY.$which")
        $hostName = $hostName -replace '^[a-z][a-z0-9+.-]*://', ''
        return ($hostName.TrimEnd('/') -split '/')[0]
    }

    [void] BuildContainer() {
        if ($this.Type -ne 'service') { throw '[!] docker build requires project type service' }
        & docker build -t $this.Image $this.Root
        if ($LASTEXITCODE -ne 0) { throw '[!] docker build failed' }
    }

    [void] PushContainer() {
        if ($this.Type -ne 'service') { throw '[!] docker push requires project type service' }
        $this.Login()
        & docker push $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker push failed: $($this.Image)" }
    }

    [void] DeployContainer() {
        if ($this.Type -ne 'service') { throw '[!] docker deploy requires project type service' }
        if ($this.Image -ne $this.TargetImage) {
            $this.Pull()
            $this.Tag($this.TargetImage)
            $built = $this.Image
            $this.Image = $this.TargetImage
            try { $this.PushContainer() }
            finally { $this.Image = $built }
        }
        else {
            $this.PushContainer()
        }
    }

    [void] BuildBinary() {
        if ($this.Type -ne 'package') { throw '[!] binary build requires project type package' }
        $this.Make('build')
    }

    [void] PublishBinary() {
        if ($this.Type -ne 'package') { throw '[!] binary publish requires project type package' }
        $this.PutPackage($this.PackageTag(), $this.Pack())
    }

    [void] DeployBinary() {
        if ($this.Type -ne 'package') { throw '[!] binary deploy requires project type package' }
        $dest = if ($this.Env -eq 'live') { 'prod' } else { 'test' }
        $built = $this.PackageTag()
        if ($built -eq $dest) { $this.PutPackage($dest, $this.Pack()) }
        else { $this.CopyPackage($built, $dest) }
    }

    hidden [void] Make([string]$Target) {
        if (-not (Get-Command make -ErrorAction SilentlyContinue)) { throw '[!] make is required' }
        Write-Host "[+] make $Target"
        & make -C $this.Root $Target
        if ($LASTEXITCODE -ne 0) { throw "[!] make $Target failed" }
    }

    hidden [string] PackageTag() {
        $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
        if ($sha) { return "ci-$sha" }
        if ($this.Env -eq 'live') { return 'prod' }
        return 'test'
    }

    hidden [string] RegistryUrl() {
        $which = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
        return ([string]$this.Settings.Require("ENDPOINTS.REGISTRY.$which")).TrimEnd('/')
    }

    hidden [string] Pack() {
        $dist = Join-Path $this.Root 'dist'
        if (-not (Test-Path -LiteralPath $dist)) { throw '[!] package build did not produce dist' }
        $name = $this.Project.Require('project')
        $file = Join-Path ([System.IO.Path]::GetTempPath()) "$name.tgz"
        & tar -czf $file -C $this.Root dist
        if ($LASTEXITCODE -ne 0) { throw '[!] package archive failed' }
        return $file
    }

    hidden [hashtable] RegistryHeaders() {
        $user = $env:REGISTRY_USER
        $pass = $env:REGISTRY_PASSWORD
        if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
            throw '[!] REGISTRY_USER and REGISTRY_PASSWORD are required'
        }
        $pair = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${user}:${pass}"))
        return @{ Authorization = "Basic $pair" }
    }

    hidden [string] PackageUrl([string]$Tag) {
        $name = $this.Project.Require('project')
        return "$($this.RegistryUrl())/repository/raw-hosted/$name/$Tag/$name.tgz"
    }

    hidden [void] PutPackage([string]$Tag, [string]$File) {
        Write-Host "[+] registry put $Tag"
        Invoke-WebRequest -Method Put -Uri $this.PackageUrl($Tag) -InFile $File -Headers $this.RegistryHeaders() -SkipCertificateCheck | Out-Null
    }

    hidden [void] CopyPackage([string]$Source, [string]$Dest) {
        $file = Join-Path ([System.IO.Path]::GetTempPath()) "$Dest.tgz"
        Write-Host "[+] registry copy $Source -> $Dest"
        Invoke-WebRequest -Method Get -Uri $this.PackageUrl($Source) -OutFile $file -Headers $this.RegistryHeaders() -SkipCertificateCheck | Out-Null
        $this.PutPackage($Dest, $file)
    }

    [void] Pull() {
        $this.Login()
        & docker pull $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker pull failed: $($this.Image)" }
    }

    hidden [void] Login() {
        $user = $env:REGISTRY_USER
        $pass = $env:REGISTRY_PASSWORD
        if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
            throw '[!] REGISTRY_USER and REGISTRY_PASSWORD are required'
        }
        $registry = ($this.Image -split '/')[0]
        $pass | & docker login $registry --username $user --password-stdin
        if ($LASTEXITCODE -ne 0) { throw "[!] docker login failed: $registry" }
    }

    [void] Tag([string]$TargetImage) {
        & docker tag $this.Image $TargetImage
        if ($LASTEXITCODE -ne 0) { throw "[!] docker tag failed: $($this.Image) -> $TargetImage" }
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB7rtOwK7MMjnKw
# TQDGfn7eTh8AXpie7c1BxGMUBkobb6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHtI0E1q
# Xfg0ylWGNTLfDySmOeEP/4PD7s3dQsQ7D/dpMAsGCSqGSIb3DQEBAQSCAgAky3H8
# Q8zNPR5ezANszfGeaAvjTMK7N/R/+nLOzpxF6pFW17i95GWFiMixGhFy/TP/9V6a
# NNkdkY1v1Ii6gkQ8zbiDG/tLIfqIBkWW5wR+aU9hofvF4HQEA7x/fpz1lIfOxKNb
# QVnCRP3OvAcc5EuMeQTa2pxkxdh7RGXw+elrY4dRCkY5oAfgBDjwR0dWgmhuX8WK
# erAgZjQj1diddFgsbrbpDdszRaB/xnrbymc+8ufQ79bdmev/PhogIrFvaC43dr0r
# PoO7nG9CKiyyuOh7+tAS2TC7xH0ny3duhT+i/UMCeY1rXlIsklLQZM6s6i10dIJn
# /YLe5NQceNoF2AFLfG132WZ/9O6ithtz79BWgWRwt2cansk2hfDY7mD0WoouIUhI
# c8J4+gJ47E1PeB0JQhuICbQmjmzFeVOnf3pF68zJQ2BI3ElxP10Wl4TyUf7N5yL5
# PF+HSQWLcx+4Mjqkfbbd3FMESN8O5pYbPOQ4aTr8OSyb3UvayjurFh3+BStpUeCv
# pDOmw2EO14tNg7WiK5/TUVM3vCOyR43KCwNGyTB7FmEmDDYB7xlaU/fFkUf51bRM
# OEW7cmKUNBBozc8XGf9k8kR4mFKVoJEhU1gdf9Jd7dOlHzKTQDqJ6ZXt7Et/MvVv
# K3zB70HXpnFeIkvCLkkmGGOA2nWCdN3MCteQEw==
# SIG # End signature block

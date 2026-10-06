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
        $hostName = [string]$this.Settings.Require("ONPREM.ENDPOINTS.REGISTRY.$which")
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
        return ([string]$this.Settings.Require("ONPREM.ENDPOINTS.REGISTRY.$which")).TrimEnd('/')
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
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDkYL+k3JN1bnoJ
# qaMoL8cX56539WD8GCrRM6SeTskhR6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# ezJPirlP+IxtyaFnz10xggMHMIIDAwIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHGRtPM2
# 1JfHAFeUYmbosLwuGVvM2x7r7Y8my4n7EwMQMAsGCSqGSIb3DQEBAQSCAgBQC1rf
# npbfQOWl+5vyW+uqj/XQ2oFAzDgg8fJZTPU19j3DRhlZA/QZZKtwzkfkMx7N8KGv
# GhAc8E2zQk0N5R1vJlmyRzJsoPU9lxTc81+NXCbu08APO/+pZsIqAudoK7Mc84of
# L4IO0/7WpzPQEfHtnlMA3hF/ZtTki3dOXAWaxqEMu2Znqp+VjiTCeoTAyUCGDLHt
# YwBHPWSxKuahhJD2gnjYMl6spE868EdFLyR+fMCu6DyuA0Kee0ouUPXUkani+E9J
# 9K7YgU1Ar4R/UBtrMXLdKGSmnuM4YXtKbsyBB9/9NLByKtK4hA1jnDR7HRt+qHnW
# a+5PRQQljI2v6UMiDMQ5lJiJU1CD6t1lPQnYB3CvawOoGKaCZJZYoZ2V2z9x326Z
# 625TVZLoJbTBkJWCmmGInS8w8rTevwzR8F0gy/J+PsmC6AMXOiBbNvMWtEjGa406
# 9rSImKfNK195Nv+bcHtcCAMytbaoJdaB0mQkLLanhdHjVGtGoIIeU8AMW55YnXAE
# Uj9IJcHqpiriZY5QF4ujF2pYVvBhms/PKqtgppI8zhYfFpAiSM/Geoq7PmwRzw8B
# NAO1rGGJXoxFl58spNsXtUICSZJ4Uf5oCsI8YdX9GCw62Ty/3oUNDhnNC75wBcPg
# 79otD1u5xPpc0Wu6A06m+SVCeMIlJqXmScnWFKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

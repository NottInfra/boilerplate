class Registry {
    hidden [string]$Root
    hidden [string]$Image

    Registry([string]$Root, [string]$Image) {
        $this.Root = $Root
        $this.Image = $Image
    }

    # Misleading ik
    [void] Build() {
        & docker build -t $this.Image $this.Root
        if ($LASTEXITCODE -ne 0) { throw '[!] docker build failed' }
    }

    [void] Pull() {
        $this.Login()
        & docker pull $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker pull failed: $($this.Image)" }
    }

    [void] Push() {
        $this.Login()
        & docker push $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker push failed: $($this.Image)" }
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDMFuYKL1HkL3/a
# BTmC67Hvwj3/RlGmPVm+sElJCzsKdaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOp7YBho
# GZcoOjR/1gKbYIHwBVLjPLRL+fnC5lhhYT4GMAsGCSqGSIb3DQEBAQSCAgA+gbZt
# RmQDUPJU7BtGteZTaEgMzN+N9BRcys0U9YSbTAKvXywanFaheGJk0o9Y50izx9O3
# DzfLfEuiWMeOLjkhWanG8OSjORrJ1F1zUmamgtxzBD0aHhqvGEwCemHZo2eqkAUw
# gpGH1B5GeiATEiTW44oHhb3S8exR36hZsRv4xB9UW3mYefiCUGV1Pb91f0yX0/ax
# 33BHfQ5II+OEDHMupY62JdeblSJvNyPBScTfE2tKVCKRYF1X1rIapJbWEqLTCS7P
# d4k5SaJPquC3LeX1ypGLIqJf2/Dnx0fT2jEipR5JA4NkF+mKpx1DypVCDPE34Qhf
# 7rS2Pfa26kqJTlkDjOMB8AZo+Td7YozHJisFPhqda6TOCQlBE3+aGstg6dg2OkqT
# +RSb3CEsU0BsVMyVIbitESQPOceTmlicUzhzQ1Rc6GPMKPWGaYF840nGv/ien1Cx
# J9gShiSZYYJI6Gv69LNJNIrQy3JTS5XA9PgpAhxmbL+0tzeE/7eDlaMQSazNzGst
# 7FXnnJmI5UwCLRVZqWHaFjPiAusVPcQo4oKQcaq2jG2N5PmSGj1ZzRtQBpT17NfD
# Bqx87jBJYIjVn2tcs4gWuTCHyQj+i3rqaI4VpLiHJxnlGmNog4wOLvp+q2tQZcOE
# OjkTHiCPM2f7YBKHH+4zSnMG3YVJnXE7uT0J5w==
# SIG # End signature block

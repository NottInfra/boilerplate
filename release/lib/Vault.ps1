class Vault {
    [string]$Addr
    [string]$Token
    [string]$Prefix

    Vault() {
        if (-not $env:VAULT_URL) { throw '[!] VAULT_URL is required' }
        if (-not $env:VAULT_TOKEN) { throw '[!] VAULT_TOKEN is required' }
        if (-not $env:VAULT_SECRET_PREFIX) { throw '[!] VAULT_SECRET_PREFIX is required' }
        $this.Addr = $env:VAULT_URL.TrimEnd('/')
        $this.Token = $env:VAULT_TOKEN
        $this.Prefix = $env:VAULT_SECRET_PREFIX
    }

    [hashtable] ReadSecret([string]$Path) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        try {
            $r = Invoke-RestMethod -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token } -SkipCertificateCheck
            $data = $r.data.data
            if ($null -eq $data) { return @{} }
            if ($data -is [hashtable]) { return $data }
            $h = @{}
            foreach ($p in $data.PSObject.Properties) {
                $h[$p.Name] = $p.Value
            }
            return $h
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 404) { throw "[!] Vault secret missing: $Path" }
            throw "[!] Vault read failed: $uri ($($_.Exception.Message))"
        }
    }

    [void] LoadEnv([string]$ProjectName) {
        $path = "$($this.Prefix)-$ProjectName"
        $secret = $this.ReadSecret($path)
        foreach ($key in $secret.Keys) {
            Set-Item -Path "env:$key" -Value $secret[$key]
        }
        $env:VAULT_SECRET_PATH = $path
        Write-Host "[+] Vault secret/$path loaded ($($secret.Count) keys)"
    }
}

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAM7y7fs05SsWLT
# 9moZ9BgfQgDI4aQPYGBq7mG5Fec4D6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOhe3+J1
# UPA49aXf6PGCvdJpbwT+O+MXmPB9DjJ9ttGQMAsGCSqGSIb3DQEBAQSCAgA7T3nl
# DMI9iV0OVtxieFE3Y/OEOO/w8H97N5ufZhhIGGK0CWwgJImXhK1ItX2NvZOImCYn
# uwbRRZaFV3hjv03kEGl7lJHfABSev95lBBGeR5aF0Zf0TrAb9jC12GfyaQLEbJ7n
# jXgTQprctkHYcOteNmF/sMJlqH5Z8fjVDgcZjVvdKK3hn2bUIMsF2/0t5LOWDT8E
# ne+OWpXgRaE9zVSF4+RKVRL7EPDLw+edibsw8GKjlZ3eljRNd5yZ9vzZBI4lt4eQ
# ET5c3ZFJLNLy97RTU68++eQCzER/1UKUe2ll+v+Q50oDZUb6reHnMTlZF0B9gr0D
# 59Hc6VxLR7ql0pRkPivh9rad5lpBAI9yrEjEeAOCa3J4YJbVS+lriF63wmh4JuPj
# N1XXWOY56xD/IVKvUL8F2lGrThWSHJwndY1dIURuX1iQXKzv3/NhyD0sMG+mPTCV
# Xs1KjhtvpIjqnk7WQ5Z90RnkPu+3o5hf26RSKTCwwsMdZosR/R3FpeuSk3FHVcWo
# QbqMs5NGWIMzwYZUq9MNitwz+MYKq7be1uxf5ReeL3bLXC9imuQuZk7IAhymmszP
# lcmh8V2S0H0BiQbHsgiV6yE+WX6FbhcNnO3Dd+pHM7dP93UDGjKxn4vQJHtkRBQ5
# SR+fk+XwqWHzFTaY0y0NAJIiHuMRKf3gOPiJxQ==
# SIG # End signature block

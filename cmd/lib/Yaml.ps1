class Yaml {
    hidden [object]$Document
    [string]$Path

    Yaml([string]$File) {
        if ([string]::IsNullOrWhiteSpace($File)) { throw '[!] config path required' }
        if (-not (Test-Path -LiteralPath $File)) { throw "[!] missing $File" }
        $this.Path = (Resolve-Path -LiteralPath $File).Path
        if ([IO.Path]::GetFileName($this.Path) -eq 'settings.cfg') { $this.CheckSignature() }
        $ErrorActionPreference = 'Stop'
        Import-Module powershell-yaml -ErrorAction Stop
        $this.Document = ConvertFrom-Yaml (Get-Content -LiteralPath $this.Path -Raw)
        if ($null -eq $this.Document) { throw "[!] failed to parse $($this.Path)" }
    }

    hidden [void] CheckSignature() {
        $tufPath = Join-Path (Split-Path -Parent $this.Path) 'cmd/lib/Tuf.ps1'
        if (-not (Test-Path -LiteralPath $tufPath)) { throw "[!] missing $tufPath" }
        if (-not ('Tuf' -as [type])) { . $tufPath }
        $tuf = New-Object -TypeName Tuf
        $tuf.TargetsKeyId = '4b7b9ec52e91431e7310abf27edf4d3b0abb39308801b038aad8dac35f0f8907'
        $tuf.TargetsPublicKeyHex = '5fb64cdf03bbce4a54d27cf1981614075066732297f1539a5d39160f6de7dc13'
        try {
            $tuf.CheckSigned($this.Path, ($this.Path + '.sig'), 'nottinfra.crt')
        }
        catch {
            throw ('[!] UNSIGNED_SETTINGS_CFG: ' + $_.Exception.Message)
        }
    }

    [object] Get([string]$Key) {
        $node = $this.Document
        if ([string]::IsNullOrWhiteSpace($Key)) { return $node }
        foreach ($part in $Key.Split('.')) {
            if ($null -eq $node) { return $null }
            if ($node -is [System.Collections.IDictionary]) {
                if (-not $node.Contains($part)) { return $null }
                $node = $node[$part]
                continue
            }
            $prop = $node.PSObject.Properties[$part]
            if ($null -eq $prop) { return $null }
            $node = $prop.Value
        }
        return $node
    }

    [string] Require([string]$Key) {
        $val = $this.Get($Key)
        if ($null -eq $val -or ($val -is [string] -and [string]::IsNullOrWhiteSpace($val))) {
            throw "[!] $Key not set in $($this.Path)"
        }
        if ($val -is [System.Collections.IDictionary] -or $val -is [System.Collections.IList]) {
            throw "[!] $Key is not a value in $($this.Path)"
        }
        return [string]$val
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC+97bbaURHVl5d
# eL9J4hqPK6u8lYBDnoZKxKswQhh4ZKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAwsxCkW
# CoEj9RdJKeUAIlsJXUbePqMtlE1JJ6+XNLsjMAsGCSqGSIb3DQEBAQSCAgCCTw9a
# g6j9i+oKn08KgfAaMlQ1lLjRR5x94GoogGAMl9d+JbXLwtuFhnXqd4GP79cLJjVC
# CC6Is3DsLXIffhsfBIGRw99yfKp+y/0ttHfmefgLObDaW5FHejZfrer3lUu9fAhZ
# 0v+J8/Pyeoxz4od1yZ9sv6fOOVAP6UMg+3/XNxF145MoKnlsyLVUy9931X0jxxRV
# uK/edYxFiNeuexV08IAWUWl7zY1mp0dyE09lrXnnDohWe8BkaU3sd41cAuZ2+VVN
# 2FbsbeypphWNATPQDbdN6v30n48H4j40a7voC7Vc+ApN4j9OSZS1zyn9R6uR1W+f
# NlvIrWsxpyWmLIktpwfK7mpz11P20lC85sMtj9XxeDxh3H1jwaGs1CsMurIUYLb0
# 5dpoElLjmXIP3a+fDXaXbYv/oADyG/cvlKpdl3szd/cyruRh/gu8UwVVOZjFcrIz
# iXXgQXe/QIA/DNazMegycKsLVtPy2TIzxC+X49PDkVgK04nkteyamL6CmBf6jEiI
# HQU1R2/oEbstSrGQsZagyWc9hV85CCtAkM84QsZKBRaQJtxwvFPWU2rXzQYqROm5
# D+JmS7EF+uA5H7ApX2r30colR7E4/sybH2izlByI9CdEqmOUReeF0AQAYOiHMg3f
# zMJGOJKCyOD8w3xH2rUCjxup9EOgx3iRoD/9gqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

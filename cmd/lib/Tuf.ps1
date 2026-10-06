class Tuf {
    # Hardcoded — Tuf must not read settings.cfg (chicken/egg).
    [string]$Url = 'https://tuf.nottinfra.co.uk'

    # Set by caller (e.g. Yaml) before GetTarget / CheckSigned.
    [string]$TargetsPublicKeyHex
    [string]$TargetsKeyId

    hidden [object]$Targets
    hidden [string]$OpenSslPath

    Tuf() {}

    [void] CheckSigned([string]$File, [string]$SigFile, [string]$CaTarget) {
        if ([string]::IsNullOrWhiteSpace($File)) { throw 'file path required' }
        if ([string]::IsNullOrWhiteSpace($SigFile)) { throw 'sig file path required' }
        if ([string]::IsNullOrWhiteSpace($CaTarget)) { throw 'CA target name required' }
        if (-not (Test-Path -LiteralPath $File)) { throw "missing $File" }
        if (-not (Test-Path -LiteralPath $SigFile)) { throw "missing $SigFile" }

        $sig = $null
        try {
            $sig = Get-Content -LiteralPath $SigFile -Raw -Encoding utf8 | ConvertFrom-Json
        }
        catch {
            throw ("cannot parse $SigFile ($($_.Exception.Message))")
        }

        if ([string]$sig.format -ne 'cms-detached') {
            throw "$SigFile format must be cms-detached"
        }
        if ([string]::IsNullOrWhiteSpace([string]$sig.cms_pem)) {
            throw "$SigFile missing cms_pem"
        }
        if ([string]::IsNullOrWhiteSpace([string]$sig.digest)) {
            throw "$SigFile missing digest"
        }

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $digest = ''
        try {
            $fileBytes = [System.IO.File]::ReadAllBytes($File)
            $hex = ([BitConverter]::ToString($sha.ComputeHash($fileBytes)) -replace '-', '').ToLowerInvariant()
            $digest = 'sha256:' + $hex
        }
        finally {
            $sha.Dispose()
        }
        if ($digest -ne [string]$sig.digest) {
            throw "digest $digest does not match $SigFile digest $($sig.digest)"
        }

        $caPem = ''
        try {
            $caPem = $this.GetTargetText($CaTarget)
        }
        catch {
            throw ("TUF CA $CaTarget unavailable ($($_.Exception.Message))")
        }

        $dir = Join-Path ([IO.Path]::GetTempPath()) ('tuf-cms-' + [guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        try {
            $caPath = Join-Path $dir 'ca.crt'
            $cmsPath = Join-Path $dir 'signed.cms'
            $outPath = Join-Path $dir 'out.bin'
            [IO.File]::WriteAllText($caPath, $caPem)
            [IO.File]::WriteAllText($cmsPath, [string]$sig.cms_pem)
            $openssl = $this.ResolveOpenSsl()
            $cmsOut = & $openssl cms -verify -inform PEM -in $cmsPath -content $File -CAfile $caPath -binary -out $outPath -purpose any 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "CMS verification failed ($cmsOut)"
            }
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    [string] ResolveOpenSsl() {
        if (-not [string]::IsNullOrWhiteSpace($this.OpenSslPath)) { return $this.OpenSslPath }
        $candidates = [System.Collections.Generic.List[string]]::new()
        foreach ($c in @(
                '/opt/homebrew/bin/openssl',
                '/usr/local/bin/openssl',
                (Get-Command openssl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
                '/usr/bin/openssl'
            )) {
            if ([string]::IsNullOrWhiteSpace($c)) { continue }
            if (-not (Test-Path -LiteralPath $c)) { continue }
            if ($candidates -contains $c) { continue }
            $candidates.Add($c)
        }
        foreach ($candidate in $candidates) {
            # Prefer OpenSSL 3+ (ed25519 pkeyutl); LibreSSL can still verify CMS.
            $algs = & $candidate list -public-key-algorithms 2>$null
            if ($LASTEXITCODE -eq 0 -and ("$algs" -match 'ED25519')) {
                $this.OpenSslPath = $candidate
                return $this.OpenSslPath
            }
        }
        if ($candidates.Count -gt 0) {
            $this.OpenSslPath = $candidates[0]
            return $this.OpenSslPath
        }
        throw '[!] openssl not found (required for TUF / settings verification)'
    }

    [byte[]] GetTarget([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) { throw '[!] TUF target name required' }
        $meta = $this.TargetMeta($Name)
        $hash = [string]$meta.hashes.sha512
        if ([string]::IsNullOrWhiteSpace($hash)) { throw "[!] TUF target $Name missing sha512" }
        $expectedLen = [int]$meta.length
        $uri = "$($this.Url.TrimEnd('/'))/targets/$hash.$Name"
        $bytes = $null
        try {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $handler.ServerCertificateCustomValidationCallback = [System.Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
            $client = [System.Net.Http.HttpClient]::new($handler)
            $client.Timeout = [TimeSpan]::FromSeconds(60)
            try {
                $bytes = $client.GetByteArrayAsync($uri).GetAwaiter().GetResult()
            }
            finally {
                $client.Dispose()
            }
        }
        catch {
            throw "[!] TUF download failed for $Name ($uri): $($_.Exception.Message)"
        }
        if ($bytes.Length -ne $expectedLen) {
            throw "[!] TUF target $Name length $($bytes.Length) != $expectedLen"
        }
        $sha = [System.Security.Cryptography.SHA512]::Create()
        $digestHex = ''
        try {
            $digestHex = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
        }
        finally {
            $sha.Dispose()
        }
        if ($digestHex -ne $hash.ToLowerInvariant()) {
            throw "[!] TUF target $Name sha512 mismatch"
        }
        return [byte[]]$bytes
    }

    [string] GetTargetText([string]$Name) {
        return [Text.Encoding]::UTF8.GetString($this.GetTarget($Name))
    }

    hidden [object] TargetMeta([string]$Name) {
        $doc = $this.EnsureTargets()
        $map = $doc.signed.targets
        $prop = $map.PSObject.Properties[$Name]
        if (-not $prop) { throw "[!] TUF target not found: $Name" }
        return $prop.Value
    }

    hidden [object] EnsureTargets() {
        if ($null -ne $this.Targets) { return $this.Targets }
        $uri = "$($this.Url.TrimEnd('/'))/targets.json"
        $raw = $null
        try {
            $raw = (Invoke-WebRequest -Uri $uri -UseBasicParsing -SkipCertificateCheck -TimeoutSec 60).Content
        }
        catch {
            throw "[!] TUF targets.json fetch failed ($uri): $($_.Exception.Message)"
        }
        if ($raw -is [byte[]]) { $raw = [Text.Encoding]::UTF8.GetString($raw) }

        $this.VerifyTargetsSignatureRaw([string]$raw)

        $doc = $null
        try {
            $doc = $raw | ConvertFrom-Json
        }
        catch {
            throw "[!] TUF targets.json parse failed: $($_.Exception.Message)"
        }
        if ([string]$doc.signed._type -ne 'targets') {
            throw '[!] TUF metadata is not targets'
        }
        $expiresRaw = $doc.signed.expires
        if ($expiresRaw -is [datetime]) {
            $expires = ([datetime]$expiresRaw).ToUniversalTime()
        }
        else {
            $expires = [datetime]::Parse(
                [string]$expiresRaw,
                [Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
            )
        }
        if ($expires -le [datetime]::UtcNow) {
            throw "[!] TUF targets metadata expired at $expires"
        }
        $this.Targets = $doc
        return $this.Targets
    }

    # Verify using System.Text.Json so ISO8601 date strings are not coerced to DateTime.
    hidden [void] VerifyTargetsSignatureRaw([string]$Raw) {
        $jdoc = [System.Text.Json.JsonDocument]::Parse($Raw)
        try {
            $root = $jdoc.RootElement
            $sigEntry = $null
            foreach ($s in $root.GetProperty('signatures').EnumerateArray()) {
                if ($s.GetProperty('keyid').GetString() -eq $this.TargetsKeyId) {
                    $sigEntry = $s
                    break
                }
            }
            if ($null -eq $sigEntry) {
                throw "[!] TUF targets.json missing signature for key $($this.TargetsKeyId)"
            }

            $msg = [Text.Encoding]::UTF8.GetBytes($this.CanonicalJsonElement($root.GetProperty('signed')))
            $sig = $this.HexToBytes($sigEntry.GetProperty('sig').GetString())
            $pub = $this.HexToBytes($this.TargetsPublicKeyHex)

            $dir = Join-Path ([IO.Path]::GetTempPath()) ('tuf-' + [guid]::NewGuid().ToString('n'))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                $msgPath = Join-Path $dir 'signed.bin'
                $sigPath = Join-Path $dir 'sig.bin'
                $pubPath = Join-Path $dir 'targets.pub.pem'
                [IO.File]::WriteAllBytes($msgPath, $msg)
                [IO.File]::WriteAllBytes($sigPath, $sig)
                [IO.File]::WriteAllText($pubPath, $this.Ed25519PublicKeyPem($pub))

                $openssl = $this.ResolveOpenSsl()
                $out = & $openssl pkeyutl -verify -pubin -inkey $pubPath -rawin -in $msgPath -sigfile $sigPath 2>&1
                if ($LASTEXITCODE -ne 0 -and "$out" -match 'unknown option|operation not supported') {
                    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
                        throw "[!] TUF targets.json signature invalid ($openssl): $out"
                    }
                    & bash -c "tar -C '$dir' -cf - signed.bin sig.bin targets.pub.pem | docker run --rm -i alpine:3.21 sh -c 'apk add --no-cache openssl >/dev/null && tar -xf - -C /tmp && openssl pkeyutl -verify -pubin -inkey /tmp/targets.pub.pem -rawin -in /tmp/signed.bin -sigfile /tmp/sig.bin'"
                    if ($LASTEXITCODE -ne 0) {
                        throw "[!] TUF targets.json signature invalid (docker openssl): exit $LASTEXITCODE"
                    }
                }
                elseif ($LASTEXITCODE -ne 0) {
                    throw "[!] TUF targets.json signature invalid ($openssl): $out"
                }
            }
            finally {
                Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        finally {
            $jdoc.Dispose()
        }
    }

    hidden [string] Ed25519PublicKeyPem([byte[]]$RawPublicKey) {
        if ($RawPublicKey.Length -ne 32) { throw '[!] ed25519 public key must be 32 bytes' }
        # SubjectPublicKeyInfo for id-Ed25519
        $prefix = [byte[]](0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00)
        $spki = New-Object byte[] ($prefix.Length + $RawPublicKey.Length)
        [Array]::Copy($prefix, 0, $spki, 0, $prefix.Length)
        [Array]::Copy($RawPublicKey, 0, $spki, $prefix.Length, $RawPublicKey.Length)
        $b64 = [Convert]::ToBase64String($spki)
        $lines = for ($i = 0; $i -lt $b64.Length; $i += 64) {
            $b64.Substring($i, [Math]::Min(64, $b64.Length - $i))
        }
        return "-----BEGIN PUBLIC KEY-----`n$($lines -join "`n")`n-----END PUBLIC KEY-----`n"
    }

    hidden [byte[]] HexToBytes([string]$Hex) {
        $h = ($Hex -replace '\s', '').ToLowerInvariant()
        if ($h.Length % 2 -ne 0) { throw '[!] invalid hex length' }
        $bytes = New-Object byte[] ($h.Length / 2)
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            $bytes[$i] = [Convert]::ToByte($h.Substring($i * 2, 2), 16)
        }
        return $bytes
    }

    # OLPC / TUF canonical JSON encoding.
    hidden [string] CanonicalJsonElement([System.Text.Json.JsonElement]$Node) {
        switch ($Node.ValueKind) {
            'Null' { return 'null' }
            'True' { return 'true' }
            'False' { return 'false' }
            'String' { return ($Node.GetString() | ConvertTo-Json -Compress) }
            'Number' { return $Node.GetRawText() }
            'Array' {
                $parts = [System.Collections.Generic.List[string]]::new()
                foreach ($item in $Node.EnumerateArray()) {
                    $parts.Add($this.CanonicalJsonElement($item))
                }
                return '[' + ($parts -join ',') + ']'
            }
            'Object' {
                $props = [System.Collections.Generic.List[System.Text.Json.JsonProperty]]::new()
                foreach ($p in $Node.EnumerateObject()) { $props.Add($p) }
                $sorted = @($props | Sort-Object { $_.Name })
                $parts = [System.Collections.Generic.List[string]]::new()
                foreach ($p in $sorted) {
                    $k = ($p.Name | ConvertTo-Json -Compress)
                    $parts.Add($k + ':' + $this.CanonicalJsonElement($p.Value))
                }
                return '{' + ($parts -join ',') + '}'
            }
            default { throw "[!] unsupported JSON value kind: $($Node.ValueKind)" }
        }
        throw '[!] unreachable'
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDNzhJ7oUF2CfwA
# PQk2Ah7YpPfa0OEC5A33DeUgWs8nyKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDbHGZpJ
# Dm7GrXoTF84cS2tAW4CnkZO/+hp6QODQa7gBMAsGCSqGSIb3DQEBAQSCAgAfVIzy
# oei+vUTa1RTFx30KC9YRYrsjKvwkZF/MkFm9P01dM0Csgr3NnvfPXR6z10K3K8vL
# GrHm+QhcBAV/pxVt7AKQXaD1f2fQFAWnO6MV65CaOKsfGsQGQ9H/Awq5Ks/Y6aI7
# 3eVi0JKR6tmI5cxCiGUMs2UjwjFibHoFRiu+rcZBdPVRUena5RGgU4jWH/mLAIjz
# tc065ELOnq90bAKchnVGDgAkhAfdFgQIMhhie9eCd22FMqqaEUHdU7JZI8L1UX8p
# U/uRsiQDqIRVnjjzhgOrxXRKcfZ2R5uzEvRKGdd2fHmGSjZmaWivJ4ex2zNY6Axc
# qmHDynxgRFLx8WK6vDx1BhB4/Fo25IEwJQYCSllRdEDMHcdltzwMVOOcjLfUcBnV
# vnyGoZ5alYwHu8v5K5W2KyHMlCqaHr54v8NQQxnBDT+l5AqgdOaxp3oMRuC4cYRO
# WH12+sdruqG3zC+m7z6VnO5YhAPIQSY3oQ0siwRfkEl75e/xjBDBvFKNCZIuKwrS
# M+h6J+TCZhx3JpVXn6yTal+Mek5YY4fbs+OBsMVFt6LD0PhAaHgSzBVUU7TfE493
# 8ziGqq0AGdIj4+bLkb7Ojj3fU9jmD0TUojt6licTGhjm0ICRelIr3jZESwwGOHnh
# JIfzyta/25sx0tXkZU1IXPq/3DloNR769JwMXaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

# SIG # Begin signature block
# MIIG2AYJKoZIhvcNAQcCoIIGyTCCBsUCAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCbGPT2kx3+pyiE
# cCAIME9TxRIjY9yArjTRtGL8Twi55qCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEsKVuMX
# myJey7X7f4nWQy6BY5Gn2VymhiU1/J24yUWeMAsGCSqGSIb3DQEBAQSCAgB/dq3L
# pToTkxLI8Bf5me5LfzlRl7/CRFNmkYS183KIVU3V1nw7ZcHTiDXxHLIT98QzoiqO
# JCu+nzcTXm+pw1E8T11ZDMVZ+6V+gq91TIBGrB5m+YHJp2clfelU9vBfI3L64PLK
# 8tGf5adJlcSEYpiKH4D943lKEpaUzpkCw7yqZ82weznsS+bmCXVhqnnJBx4lItH2
# cj4TIJQZA6ghTgeqbbhIP+NV75U3NIOqn+v4Fp8eJIU6DTPHuH91gk6sT1/doChu
# zaf/u/wX7Lj2jcAYsB94opnCht7Q4GJIzWQ7KLHSVdzXBKS+y5iNWrvzCVZGgo9x
# F62bB9l4yQAeGthVRpkwpd22et3wxWot5msoY93Ryx6ZYSLrpCE19mvxJI+xkQRz
# Ozxs32sfzRHzQyqAe/BO7b2UsrpgoEq3rspQrjlpDovBMUfhgSb/pdNzVPeZp+xI
# atOj7hfVfC8pb3BqS9D7ljq5zyu40qZv9FNitdwym93wUImTR9QuYIi6mYkzb1nF
# uktkpQq2SF5VwMYL35KQQQDaSjGslyaHtDEMGFQZhsXZETHwt1vMQZCEhDLRb3XU
# Ebkjwa6u8v4jfVdn0iDhgL3/T7gfvJroFtW7mzhBhPfZxEwiUCM2V84x25KFj2I5
# 9ORaXsKDt54a6ZvdT7bL4JJklVZR5lGdylWJ+Q==
# SIG # End signature block

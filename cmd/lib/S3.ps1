class S3 {
    [Env]$Env
    [Yaml]$Settings
    [Yaml]$Project
    [string]$HostName
    [string]$Scheme
    [string]$Region
    [string]$AccessKey
    [string]$SecretKey
    [string]$Bucket

    S3([Env]$Env, [Yaml]$Settings, [Yaml]$Project) {
        if (-not $Env) { throw '[!] S3 requires Env' }
        if (-not $Settings) { throw '[!] S3 requires settings.cfg' }
        if (-not $Project) { throw '[!] S3 requires project.cfg' }
        $this.Env = $Env
        $this.Settings = $Settings
        $this.Project = $Project
        $name = ([regex]::Replace($Project.Require('project').ToLower(), '[^a-z0-9-]', '-')).Trim('-')
        if ([string]::IsNullOrWhiteSpace($name)) { throw '[!] project name is not a valid bucket name' }
        $this.Bucket = "$name-cdn"
        $this.BindMinio()
    }

    hidden [void] BindMinio() {
        $kind = if ("$env:NETWORK" -eq 'cluster') { 'CLUSTER' } else { 'PUBLIC' }
        $this.Bind(
            $this.Settings.Require("ONPREM.ENDPOINTS.MINIO.$kind"),
            'us-east-1',
            $this.Env.Require('MINIO_ACCESS_KEY'),
            $this.Env.Require('MINIO_SECRET_KEY')
        )
    }

    hidden [void] Bind([string]$Endpoint, [string]$Region, [string]$AccessKey, [string]$SecretKey) {
        $uri = [Uri]$Endpoint
        if ([string]::IsNullOrWhiteSpace($uri.Host)) { throw "[!] invalid S3 endpoint: $Endpoint" }
        $this.HostName = $uri.Host
        $this.Scheme = $uri.Scheme
        $this.Region = $Region
        $this.AccessKey = $AccessKey
        $this.SecretKey = $SecretKey
    }

    [void] EnsurePublic() {
        $this.BindMinio()
        $this.EnsureBucket($this.Bucket)
        $this.SetPublic($this.Bucket)
        Write-Host "[+] MinIO public bucket $($this.Bucket) ($($this.HostName))"
    }

    [void] Publish([string]$Root) {
        $this.BindMinio()
        Write-Host "[+] Publishing $Root → MinIO $($this.Bucket)"
        $this.PublishTree($this.Bucket, $Root)
    }

    [void] EnsureBucket([string]$Bucket) {
        $head = $this.Send('HEAD', "/$Bucket", $null, '', '')
        if ($head.Status -ge 200 -and $head.Status -lt 300) { return }
        $made = $this.Send('PUT', "/$Bucket", $null, '', '')
        if ($made.Status -ge 200 -and $made.Status -lt 300) { return }
        if ($made.Body -match 'BucketAlready') { return }
        throw "[!] S3 bucket $Bucket ($($made.Status) $($made.Body))"
    }

    [void] SetPublic([string]$Bucket) {
        $policy = @{
            Version   = '2012-10-17'
            Statement = @(
                @{
                    Effect    = 'Allow'
                    Principal = @{ AWS = @('*') }
                    Action    = @('s3:GetObject')
                    Resource  = @("arn:aws:s3:::$Bucket/*")
                }
            )
        } | ConvertTo-Json -Compress -Depth 6
        $bytes = [Text.Encoding]::UTF8.GetBytes($policy)
        $put = $this.Send('PUT', "/$Bucket", $bytes, 'application/json', 'policy=')
        if ($put.Status -ge 200 -and $put.Status -lt 300) { return }
        throw "[!] S3 public policy $Bucket ($($put.Status) $($put.Body))"
    }

    [void] PublishTree([string]$Bucket, [string]$Root) {
        if (-not (Test-Path -LiteralPath $Root)) { throw "[!] missing $Root" }
        $base = (Resolve-Path -LiteralPath $Root).Path
        $files = @(Get-ChildItem -LiteralPath $base -Recurse -File)
        if ($files.Count -eq 0) {
            Write-Host "[=] $Root is empty"
            return
        }
        foreach ($file in $files) {
            $rel = $file.FullName.Substring($base.Length).TrimStart('\', '/') -replace '\\', '/'
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            $type = $this.ContentType($file.Name)
            $put = $this.Send('PUT', "/$Bucket/$rel", $bytes, $type, '')
            if ($put.Status -lt 200 -or $put.Status -ge 300) {
                throw "[!] S3 put $rel ($($put.Status) $($put.Body))"
            }
            Write-Host "[+] $Bucket/$rel"
        }
    }

    hidden [hashtable] Send([string]$Method, [string]$Resource, [byte[]]$Body, [string]$ContentType, [string]$Query) {
        if ($null -eq $Body) { $Body = [byte[]]::new(0) }
        $payloadHash = $this.Sha256Hex($Body)
        $amzDate = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
        $day = $amzDate.Substring(0, 8)
        $canonicalUri = $this.CanonicalUri($Resource)
        $names = [System.Collections.Generic.List[string]]::new()
        $map = @{}
        $map['host'] = $this.HostName
        $map['x-amz-content-sha256'] = $payloadHash
        $map['x-amz-date'] = $amzDate
        if (-not [string]::IsNullOrWhiteSpace($ContentType)) { $map['content-type'] = $ContentType }
        foreach ($key in $map.Keys) { $names.Add([string]$key) }
        $names.Sort([StringComparer]::Ordinal)

        $canonHeaders = ''
        foreach ($name in $names) { $canonHeaders += "$name`:$($map[$name].Trim())`n" }
        $signed = $names -join ';'
        $canonical = "$Method`n$canonicalUri`n$Query`n$canonHeaders`n$signed`n$payloadHash"
        $scope = "$day/$($this.Region)/s3/aws4_request"
        $toSign = "AWS4-HMAC-SHA256`n$amzDate`n$scope`n$($this.Sha256Hex([Text.Encoding]::UTF8.GetBytes($canonical)))"
        $signing = $this.SigningKey($day)
        $signature = $this.Hex($this.Hmac($signing, $toSign))
        $auth = "AWS4-HMAC-SHA256 Credential=$($this.AccessKey)/$scope, SignedHeaders=$signed, Signature=$signature"

        $uri = "$($this.Scheme)://$($this.HostName)$canonicalUri"
        if (-not [string]::IsNullOrWhiteSpace($Query)) { $uri = "$uri`?$Query" }
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromMinutes(5)
        try {
            $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $uri)
            [void]$req.Headers.TryAddWithoutValidation('x-amz-content-sha256', $payloadHash)
            [void]$req.Headers.TryAddWithoutValidation('x-amz-date', $amzDate)
            [void]$req.Headers.TryAddWithoutValidation('Authorization', $auth)
            if ($Method -ne 'HEAD' -and $Method -ne 'GET') {
                $req.Content = [System.Net.Http.ByteArrayContent]::new($Body)
                if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
                    [void]$req.Content.Headers.TryAddWithoutValidation('Content-Type', $ContentType)
                }
            }
            $resp = $client.Send($req)
            try {
                $text = ''
                if ($resp.Content) { $text = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
                return @{ Status = [int]$resp.StatusCode; Body = $text }
            }
            finally { $resp.Dispose() }
        }
        finally { $client.Dispose() }
    }

    hidden [string] CanonicalUri([string]$Resource) {
        $path = if ([string]::IsNullOrWhiteSpace($Resource)) { '/' } else { $Resource }
        if (-not $path.StartsWith('/')) { $path = "/$path" }
        $encoded = @()
        foreach ($part in $path.Split('/')) {
            if ($part -eq '') { $encoded += ''; continue }
            $encoded += [Uri]::EscapeDataString($part)
        }
        return ($encoded -join '/')
    }

    hidden [byte[]] SigningKey([string]$Day) {
        $kDate = $this.Hmac([Text.Encoding]::UTF8.GetBytes("AWS4$($this.SecretKey)"), $Day)
        $kRegion = $this.Hmac($kDate, $this.Region)
        $kService = $this.Hmac($kRegion, 's3')
        return $this.Hmac($kService, 'aws4_request')
    }

    hidden [byte[]] Hmac([byte[]]$Key, [string]$Data) {
        $h = [System.Security.Cryptography.HMACSHA256]::new($Key)
        try { return $h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Data)) }
        finally { $h.Dispose() }
    }

    hidden [string] Sha256Hex([byte[]]$Bytes) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return $this.Hex($sha.ComputeHash($Bytes)) }
        finally { $sha.Dispose() }
    }

    hidden [string] Hex([byte[]]$Bytes) {
        return ([BitConverter]::ToString($Bytes) -replace '-', '').ToLowerInvariant()
    }

    hidden [string] ContentType([string]$Name) {
        $type = 'application/octet-stream'
        switch ([IO.Path]::GetExtension($Name).ToLowerInvariant()) {
            '.png' { $type = 'image/png' }
            '.jpg' { $type = 'image/jpeg' }
            '.jpeg' { $type = 'image/jpeg' }
            '.gif' { $type = 'image/gif' }
            '.webp' { $type = 'image/webp' }
            '.svg' { $type = 'image/svg+xml' }
            '.avif' { $type = 'image/avif' }
            '.ico' { $type = 'image/x-icon' }
            '.css' { $type = 'text/css' }
            '.js' { $type = 'text/javascript' }
            '.json' { $type = 'application/json' }
            '.txt' { $type = 'text/plain' }
            '.woff' { $type = 'font/woff' }
            '.woff2' { $type = 'font/woff2' }
        }
        return $type
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBnkbGk698vkSQx
# bxB1NYlFYEQFHsuv9VdXGVO9GxgBDKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOHGNUHT
# lcTKSYwIS/fK+iC1nXFUgmK+0ah1+vxw1EwdMAsGCSqGSIb3DQEBAQSCAgA8YzLW
# qF6RHHlYcnBURLoKkzgOYtN+KWQTw1K9MaWJQ2C6qi8MfNiQPSsaNHcSRlqeIn8T
# UciCW554FmLE4nKp5XEU8KANBkWArQFFydiw+fYZslgBqW4jVdOZTngq3a4KsIFl
# FNpVx3jSFen3FbsKooLUk1I2BDBMk6u+txaI/IQWxnm6AJr5KW44pjak8XKS098h
# jelQkdiX3tgYaaiQ1RoTDVxsnQutfhjGq+OYwmMpRN6SRVLPn6HdeoiupuKRz/re
# laI2dL8DS5RQ5jQI1i6hn/soUzETZTSm8/vSJM4nSTFA2T6qYjMbgjsZRlds3J9S
# aiwnpvINBQfD6CwbCEIFDAnjOXXpFoFvTi2F3MA42npeCk9I7WURNtw9F0PdyZpM
# ce+JQgnhvfCb5D/CHkRCJ0jxGw5IdsCxJaFMZEV8v8fKL4yly3GX93A2tWm74I4n
# BubyWdv5JJmrFpDVHEWIHyEvOBfIbzWb/bNAWRn0JDm/ns59oUrP7IG2V5B7YOgN
# PDTnYah8ZhWhsLLMF3jug0HenpeyjiXE6COX6El1/d4xx897D0gftNSVCkktHcB1
# tPsHWxGZg4Ps7AaA44Dt6bmDeSVa74h1NfaO9olfCnwwQTwzU+q44LfeBfvP6USb
# Esa2FmttBNoPVHfp9bgOHT6pBD1ZU092VqsG4qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

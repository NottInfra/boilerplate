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

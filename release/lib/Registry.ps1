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

    [void] Push() {
        & docker push $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker push failed: $($this.Image)" }
    }
}

# Vendored PowerShell modules

`powershell-yaml` is vendored for CI/self-hosted runners that do not have
PSGallery modules preinstalled. Release scripts import it via `PSModulePath`
(see `.github/workflows/deploy-live.yml` and `.gitlab-ci.yml`).

Source: https://www.powershellgallery.com/packages/powershell-yaml/0.4.12
License: see `powershell-yaml/0.4.12/LICENSE`

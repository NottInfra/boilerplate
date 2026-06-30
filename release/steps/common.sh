#!/usr/bin/env bash
set -euo pipefail

STAGING="${1:-}"
[[ -n "$STAGING" ]] || { echo "[!] staging required: live|test" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if command -v pwsh >/dev/null 2>&1; then
  eval "$(pwsh -NoProfile -Command "
    \$env:ENV = if ('${STAGING}' -eq 'live') { 'production' } else { 'test' }
    . '${ROOT}/cmd/lib/Project.ps1'
    \$p = [Project]::new('${ROOT}/project.yml')
    \$project = \$p.Name
    if (-not \$env:REGISTRY) { throw '[!] REGISTRY is required' }
    if (-not \$env:REGISTRY_HOST) { throw '[!] REGISTRY_HOST is required' }
    \$tag = if ('${STAGING}' -eq 'live') { 'prod' } else { 'test' }
    \$vaultProject = '${STAGING}-' + \$project
    Write-Output \"export STAGING='${STAGING}'\"
    Write-Output \"export PROJECT_NAME='\$project'\"
    Write-Output \"export IMAGE='\$env:REGISTRY/\${project}:\$tag'\"
    Write-Output \"export IMAGE_HOST='\$env:REGISTRY_HOST/\${project}:\$tag'\"
    Write-Output \"export CONTAINER_NAME='\${project}-${STAGING}'\"
    Write-Output \"export VAULT_PROJECT='\$vaultProject'\"
    Write-Output \"export ENV_FILE='/root/\${vaultProject}.env'\"
    Write-Output \"export HOST_PORT='\$p.HostPort'\"
    Write-Output \"export CONTAINER_PORT='\$p.ContainerPort'\"
    Write-Output \"export EXPECTED_BRANCH='\$p.Branch'\"
    Write-Output \"export RELEASE_FILE='\$p.Release'\"
    Write-Output \"export REMOTE_NAME='\$p.RemoteName'\"
    Write-Output \"export REMOTE_URL='\$p.RemoteUrl'\"
    Write-Output \"export SONAR_KEY='\$(if (\$env:SONAR_PROJECT_KEY) { \$env:SONAR_PROJECT_KEY } else { \$project })'\"
    Write-Output \"export MONO_HOST='\$p.Host'\"
  ")"
else
  echo "[!] pwsh required for project staging (cmd/lib)" >&2
  exit 1
fi

branch_gate() {
  local ref="${GITHUB_REF_NAME:-${CI_COMMIT_BRANCH:-}}"
  if [[ -n "$ref" && "$ref" != "$EXPECTED_BRANCH" ]]; then
    echo "Skip: ${ref} != ${EXPECTED_BRANCH}"
    exit 0
  fi
}

mono_network() {
  printf '%s' "${MONO_NETWORK:-mono}"
}

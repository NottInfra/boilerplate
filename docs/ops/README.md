# Operations

`/cmd` and `/release` are separate — each dotsources only its own `lib/*.ps1` (no cross-imports).

Env template: [`.env.example`](../../.env.example) → copy to `.env.development`, `.env.test`, or `.env.production`.

## Apply scripts (`/cmd`)

| Script | Purpose |
|--------|---------|
| `apply-alerts.ps1` | Kibana + Grafana alert rules |
| `apply-dashboards.ps1` | ES template + Kibana + Grafana dashboards |
| `apply-db.ps1` | `assets/db.sql` (creates DB if missing) |
| `apply-env.ps1` | Push env files → Vault |
| `apply-commit.ps1` | Commit + push to live/test remotes |
| `apply-caddy.ps1` | Push `Caddyfile` → IaC repo |
| `apply-synth-mon.ps1` | Push blackbox targets → IaC repo |
| `apply-app-config.ps1` | Push root `compose.yml` → IaC repo |
| `apply-dns.ps1` | Apply `public.dns.*` A records via Spaceship API |
| `refresh-boilerplate.ps1` | Soft-pull boilerplate updates |

## Release pipeline (`/release`)

`build` → `unit-test` → `gitleaks` → `semgrep` → `syft` → `grype` → `trivy` → `sonar` → `push` (live only). Deploy is Watchtower on the IaC host via `compose.yml`.

Finding-producing steps import reports to Defect Dojo and emit summaries to Elasticsearch (`{project}-findings`).

| Lib | Purpose |
|-----|---------|
| `Project.ps1` | `project.yml` parser, `Get('remotes.live')`, pipeline context |
| `Elastic.ps1` | Pipeline step + finding telemetry |
| `DefectDojo.ps1` | Scan import (CI) |
| `Registry.ps1` | Docker build / tag / push |
| `Gitleaks.ps1` | Secrets scan |
| `Semgrep.ps1` | SAST |
| `Syft.ps1` | SBOM (CycloneDX) |
| `Grype.ps1` | SBOM vulnerability scan (after syft) |
| `Trivy.ps1` | Container image scan |
| `Sonar.ps1` | SonarQube |

Scanner images are pinned in each lib class. Scan reports go to `$TMP/release-scan`. Sonar runs via `sonar-scanner` on the runner. Bootstrap Defect Dojo / PostHog IDs via `./cmd/apply-dashboards.ps1`.

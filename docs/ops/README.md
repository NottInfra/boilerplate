# Operations

`/cmd` is PowerShell. Apply scripts dot-source only the `cmd/lib/*.ps1` files they need.

## Scripts

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

## Lib classes (`cmd/lib/`)

| Class | Init | Role |
|-------|------|------|
| `Env` | `$Root` | Load/pick env file; sets `ENV` |
| `Cfg` | `$FilePath` | Parse `boilerplate.cfg` (or any cfg file) |
| `Project` | `$FilePath` | Parse `project.yml` for current `ENV` |
| `Vault` | reads `VAULT_*` from env | Vault API |
| `GitRemote` | `$Remote, $LocalPath` | Clone/pull to explicit path, write, push |
| `GitHub` / `GitLab` | `$Remote, $LocalPath` | + `CreateRepo`, platform APIs |
| `Elastic`, `Kibana`, `Grafana`, `PostHog`, `PostgreSql`, `Spaceship` | reads service vars from env | Service APIs |

IaC scripts clone to `/tmp/iac-*`, push, then delete — never touch the project repo.

## Usage

```powershell
pwsh ./cmd/apply-caddy.ps1
$env:ENV_FILE = '.env.development'; pwsh ./cmd/apply-dashboards.ps1
```

Release CI (`release/steps/common.sh`) dot-sources `Project.ps1` inline via `pwsh`.

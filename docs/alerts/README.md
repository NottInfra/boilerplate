# Alerting

Source files in `alerts/` (when present):

- `grafana.json` — Grafana alerting rules
- `kibana.json` — Kibana alerting rules

Applied via `./cmd/apply-alerts.sh`.

## Synthetic monitoring

Uptime / reachability checks are **not** applied here — they use the blackbox exporter via `./cmd/apply-synth-mon.ps1`, which pushes targets to the IaC repo under `servers/{server}/docker/blackbox/configs/https/` (server from `public.app.*.server` in `project.yml`).

Set `ENV` (`development` | `test` | `production`) in your env file before running apply scripts.

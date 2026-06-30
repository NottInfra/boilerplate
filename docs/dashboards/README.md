# Dashboards

Source files under `dashboards/` — one file per dashboard, grouped by platform:

```
dashboards/
  grafana/
    metrics.json
    synthetic-monitoring.json
  kibana/
    logging.ndjson
  posthog/
    analytics.json
```

Applied via `./cmd/apply-dashboards.ps1`.

Each dashboard is scoped to the project from `project.yml`:

| Platform | Naming |
|----------|--------|
| Grafana | folder `{project}/{slug}`, dashboard `{project} / {slug} ({ENV})` |
| Kibana | title `{project} / {slug}` |
| PostHog | name `{project} / {slug}` (requires `POSTHOG_HOST`, `POSTHOG_API_KEY`) |

Empty placeholder files are skipped. PostHog is optional if env vars are not set.

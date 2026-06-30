# Alerting

Source files in `alerts/` (when present):

- `grafana.json` — Grafana alerting rules
- `kibana.json` — Kibana alerting rules

Applied via `./cmd/apply-alerts.ps1`.

## Pipeline failures

CI steps emit documents to `{project}-pipeline` in Elasticsearch when `ES_URL` is set (`event: pipeline_step`, `pipeline.status: failed`). Finding steps also write to `{project}-findings` (`event: pipeline_finding`).

Add a Kibana rule that queries e.g.:

```json
"esQuery": "event:pipeline_step AND pipeline.status:failed AND deployment.environment:\"__ENV__\""
```

`__ENV__` is substituted at apply time (same as other Kibana rules).

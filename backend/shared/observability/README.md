# Observability Profile

The backend should standardize on OpenTelemetry instrumentation in each service,
then export:

- traces/logs through an OpenTelemetry Collector,
- metrics to Prometheus,
- dashboards through Grafana,
- centralized logs to Loki.

The optional `observability` Docker Compose profile wires these config files into
local containers:

- `otel-collector.yaml`
- `prometheus.yml`
- `grafana/provisioning/datasources/datasources.yml`
- `loki-config.yaml`

Run it through the deployment wrapper so the same env profile is used:

```sh
cd backend
scripts/deploy/compose.sh development --profile observability up -d
```

Use staging/production env files with real secrets before enabling Grafana in a
shared environment.

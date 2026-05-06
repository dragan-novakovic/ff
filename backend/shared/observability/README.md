# Observability Placeholders

The backend should standardize on OpenTelemetry instrumentation in each service,
then export:

- traces/logs through an OpenTelemetry Collector,
- metrics to Prometheus,
- dashboards through Grafana,
- centralized logs to Loki.

No observability containers are wired into `docker-compose.yml` yet. The config
files here are starter placeholders for a future compose profile or deployment
overlay:

- `otel-collector.yaml`
- `prometheus.yml`
- `grafana/provisioning/datasources/datasources.yml`
- `loki-config.yaml`

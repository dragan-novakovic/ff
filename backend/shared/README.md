# Shared Backend Assets

Shared files for backend services live here:

- `contracts/` documents versioned gRPC/protobuf and event-contract conventions.
- `docker/` contains local infrastructure init/config mounted by
  `backend/docker-compose.yml`.
- `observability/` contains starter OpenTelemetry, Prometheus, Grafana, and
  Loki configuration placeholders.

Service source code should live under `backend/services/` when those projects
are created.

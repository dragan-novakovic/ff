# FF Backend

This directory contains the split-first backend scaffold. It currently starts
local infrastructure only; application service images are intentionally not
assumed yet.

## Local infrastructure

```sh
cd backend
cp .env.example .env # optional; docker compose also has safe local defaults
docker compose up -d
docker compose ps
docker compose down
```

To remove local data volumes:

```sh
docker compose down -v
```

Default local endpoints:

| Service | Endpoint |
|---|---|
| PostgreSQL | `localhost:5432` |
| Redis | `localhost:6379` |
| NATS | `nats://localhost:4222` |
| NATS monitoring | `http://localhost:8222` |

Contracts live in `shared/contracts`, local container config in
`shared/docker`, and observability placeholders in `shared/observability`.

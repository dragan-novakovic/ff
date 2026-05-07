# FF Backend

This directory contains the split-first backend services, local infrastructure,
and deployment profile scripts for development, staging, and production.

## Local infrastructure

```sh
cd backend
cp .env.example .env # optional; docker compose also has safe local defaults
docker compose up -d
docker compose ps
docker compose down
```

The profile-aware wrapper uses explicit env files and validates unsafe defaults:

```sh
cd backend
cp env/development.env.example env/development.env
scripts/deploy/compose.sh development up -d --build
scripts/deploy/healthcheck.sh development
scripts/deploy/smoke-test.sh development
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
`shared/docker`, and observability config in `shared/observability`.

## Deployment profiles

Profile templates live in `env/`:

| Profile | Template | Purpose |
|---|---|---|
| `development` | `env/development.env.example` | Local development with build-from-source enabled and safe local defaults. |
| `staging` | `env/staging.env.example` | Shared test deploy with production-like settings and no seed account. |
| `production` | `env/production.env.example` | Production deploy template with placeholders for real secrets and immutable images. |

For staging or production, copy the template and replace every `CHANGE_ME` value:

```sh
cp env/staging.env.example env/staging.env
scripts/deploy/check-env.sh staging
scripts/deploy/compose.sh staging pull
scripts/deploy/apply-schema.sh staging
scripts/deploy/smoke-test.sh staging
```

The scripts intentionally reject development secrets, unresolved placeholders,
`Include Error Detail=true`, seed accounts, and local image builds outside the
development profile. Real env files such as `env/staging.env`,
`env/production.env`, and `.env` are ignored by git.

`apply-schema.sh` makes the current schema step explicit by starting backing
infrastructure and then one instance of each service so the services' existing
idempotent startup schema initialization runs. Replace this script with a
dedicated migrator when formal migrations are introduced.

Optional observability containers are available through the compose profile:

```sh
scripts/deploy/compose.sh development --profile observability up -d
```

This starts the OpenTelemetry Collector, Prometheus, Loki, and Grafana using the
configuration under `shared/observability`.

## Gateway anti-abuse rules

The gateway persists every sensitive-action decision in PostgreSQL under the
`gateway` schema. Blocked decisions also create
`gateway.suspicious_action_events` for the admin review queue. Clients can read
the active rules from `GET /anti-abuse/rules`; admins can review suspicious
events through `GET /admin/anti-abuse/review-queue` and
`POST /admin/anti-abuse/review-queue/{eventId}/review`.

Current enforcement rules:

| Action | Idempotency-Key required | Limit |
|---|---:|---|
| `player_work` | No | 6 per 5 minutes |
| `player_train` | No | 10 per 5 minutes |
| `hospital_recover` | Yes | 6 per 10 minutes |
| `inventory_item_use` | Yes | 20 per 5 minutes |
| `weapon_equip` | Yes | 10 per 10 minutes |
| `weapon_repair` | Yes | 10 per 10 minutes |
| `market_buy` | Yes | 30 per 5 minutes |
| `market_sell` | Yes | 40 per hour |
| `market_cancel` | Yes | 30 per 10 minutes |
| `trade_create` | Yes | 60 per hour |
| `trade_accept` | Yes | 30 per 10 minutes |
| `trade_cancel` | Yes | 30 per 10 minutes |
| `combat_fight` | Yes | 20 per 5 minutes |

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

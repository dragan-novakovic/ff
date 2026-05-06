# Combat Service

Initial Rust scaffold for deterministic combat simulation in the eRepublik-like backend.

## Purpose

The service owns small, repeatable combat calculations that can later be called by the rest of the backend. It currently exposes:

- `GET /health` for service health.
- `POST /simulate/fight` for deterministic fight simulation between an attacker and defender.

## Commands

```bash
cd backend/services/combat-service
cargo fmt
cargo test
cargo run
```

The HTTP server listens on `0.0.0.0:8080` by default. Override with `COMBAT_SERVICE_ADDR`, for example:

```bash
COMBAT_SERVICE_ADDR=127.0.0.1:8081 cargo run
```

## Example request

```bash
curl -X POST http://127.0.0.1:8080/simulate/fight \
  -H 'content-type: application/json' \
  -d '{
    "attacker": { "strength": 80, "energy": 100, "weapon_power": 3 },
    "defender": { "strength": 60, "energy": 100, "weapon_power": 1 },
    "rounds": 3
  }'
```

`weapon_power` must be between `1` and `5`, energy must be between `0` and `100`, and each round consumes `10` energy per fighter.

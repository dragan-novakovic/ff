# Copilot instructions for this repository

This repository is a Flutter frontend with a split-first backend for an
eRepublik-style multiplayer strategy game. Future agents should use this file as
stable handoff context, then verify current code before changing behavior.

## Project shape

- `frontend/` contains the Flutter app. It talks to the backend through the
  gateway/BFF and uses domain models, blocs, pages, and tests.
- `backend/` contains the .NET solution (`Ff.Backend.sln`) with ASP.NET Core
  APIs/workers plus a Rust combat service under `services/combat-service/`.
- Docker Compose in `backend/docker-compose.yml` runs PostgreSQL, Redis, NATS,
  all backend services, the Rust combat service, and an optional observability
  profile.
- Deployment profile templates live in `backend/env/`; helper scripts live in
  `backend/scripts/deploy/`.

## Product expectations

- Do not use Firebase or Firestore for future backend architecture.
- Do not implement mock-only gameplay features. User-visible features should be
  backed by real persisted state and wired through the owning backend service.
- Preserve the eRepublik-style direction: countries, citizens, economy,
  companies, market, production, politics, battles, campaigns, notifications,
  research, social/news, and admin/moderation surfaces.

## Service ownership

- `gateway-service`: public REST/BFF, auth checks, orchestration, response
  shaping, anti-abuse/rate-limit decisions. It should not own durable gameplay
  domain state.
- `identity-service`: accounts, sessions, token issuance, auth-to-player mapping.
- `player-service`: player progression, energy, strength, missions/objectives,
  achievements, onboarding, and player combat result application.
- `economy-service`: wallet, ledger, inventory, equipment, reservations, grants,
  and item durability.
- `production-service`: companies, factories, production jobs, workforce,
  upgrades, formulas, and resource logistics owned by companies.
- `market-service`: order book/listings, purchases, cancellations, releases,
  trade contracts/history, and market fees.
- `world-service`: countries, regions, citizenship, battles, combat reports,
  campaigns, military units, territory, politics/laws, diplomacy, treasury, and
  world resources.
- `social-chat-service`: chat, contacts, conversations, newspapers/articles,
  comments, votes, subscriptions, and moderation metadata.
- `notification-service`: activity feed, push subscriptions, push delivery, and
  notification dispatch state.
- `research-service`: technologies, research projects, research points, and
  active technology bonuses.
- `scheduler-service`: simulation ticks and recurring jobs.
- `admin-service`: protected operations, review queues, audit/support surfaces.
- `combat-service`: Rust combat simulation and combat mission data.

## Engineering rules

- Inspect the current working tree before edits and do not revert user changes.
- Make complete vertical slices: owner service persistence, gateway route,
  frontend model/API/bloc/UI, tests, and docs where relevant.
- Use idempotency keys for retryable or sensitive mutations, especially money,
  inventory, market, production, combat, notification, and account flows.
- Prefer service-owned APIs/events over cross-service table writes.
- Avoid broad catches, silent fallbacks, unnecessary casts, and unrelated
  rewrites.
- Never commit secrets, real `.env` files, production credentials, or private
  tokens. Only commit templates with safe placeholders.
- If asked only for suggestions, list options and wait for explicit approval
  before implementing.

## Validation commands

Use existing tools only. Typical validation commands:

```sh
dotnet build backend/Ff.Backend.sln --nologo
cd backend && docker compose config --quiet
cargo test --manifest-path backend/services/combat-service/Cargo.toml --quiet
cd frontend && flutter test --no-pub
cd frontend && flutter build web --release --no-pub
```

Deployment profile checks:

```sh
cd backend
scripts/deploy/check-env.sh development
scripts/deploy/compose.sh development config --quiet
scripts/deploy/healthcheck.sh development
scripts/deploy/smoke-test.sh development
```

## Commit convention

When creating commits from Copilot work, include:

```text
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

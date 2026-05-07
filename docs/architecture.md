# Architecture handoff

This document captures the current project architecture as verified from the repository structure and service files. Keep it short, factual, and updated when service ownership or deployment topology changes.

## Verified shape

- **Frontend:** Flutter app in `frontend/` (`frontend/pubspec.yaml`) that calls the backend through the gateway/BFF.
- **Backend:** .NET solution in `backend/Ff.Backend.sln` with ASP.NET Core APIs and worker services under `backend/services/`.
- **Combat:** Rust service in `backend/services/combat-service/` (`Cargo.toml`, Axum HTTP routes) for combat mission lookup and fight simulation.
- **Gateway/BFF:** `gateway-service` is the public API surface for Flutter. It validates client requests, orchestrates calls to backend services, and shapes client-friendly responses.
- **Infrastructure:** `backend/docker-compose.yml` runs PostgreSQL, Redis, and NATS alongside the services. PostgreSQL is the default durable store for service-owned game state; Redis is for short-lived coordination/cache/rate-limit/presence use; NATS is the event-broker direction for cross-service events.
- **Deployment:** Profile templates are in `backend/env/` (`development`, `staging`, `production`). Deployment helpers live in `backend/scripts/deploy/` for compose orchestration, env validation, schema startup, health checks, and smoke tests.

## Service ownership boundaries

Each service should own its durable state and schema/table set. Other services should call its API or consume its events rather than writing across the boundary.

| Service | Owner boundary |
|---|---|
| `identity-service` | Authentication/account state, player ID mappings, sessions, account status, password reset and email verification flows. It does not own game progression. |
| `player-service` | Player profile, level/XP, energy, strength, daily objectives, achievements, onboarding, hospital recovery, and combat result progression. |
| `economy-service` | Wallet balances, transaction ledger, inventory, equipment, reservations, grants/spends, and economic audit trail. |
| `production-service` | Factories, companies, company membership/assets, production jobs, upgrades, formulas, and resource production workflows. |
| `market-service` | Listings/order book, listing lifecycle, purchases, cancellations, releases/settlement, trade history, and market fees. |
| `world-service` | Countries, regions, citizenship, battles, military units, politics, elections, laws, diplomacy, treasury, resources, campaigns, and global world configuration/time. |
| `gateway-service` | Public REST/BFF routing, auth checks, request validation, response shaping, orchestration, anti-abuse/rate-limit decisions, and client-facing API compatibility. It must not become the durable owner of gameplay domain state. |
| `social-chat-service` | Contacts, conversations, channels, messages, newspapers/articles/comments/votes/subscriptions, unread counts, and moderation metadata. |
| `notification-service` | Persisted activity feed, notification read state, push subscriptions, push delivery state/outbox, and notification dispatch. |
| `research-service` | Technology catalogs, country/company research projects, research points, completion state, and active technology bonuses. |
| `scheduler-service` | Background tick orchestration for simulation ticks, daily resets, energy regeneration, production completion, battle expiration, and market cleanup. Durable job/run state should be added before jobs become business-critical. |
| `admin-service` | Protected operations API, moderation/support workflows, audit views, player/economy inspection, anti-abuse review, and administrative actions. |
| `combat-service` | Rust-owned combat mission data and deterministic fight simulation. Persisted battle/action records should live behind a stable combat/world boundary rather than in the gateway. |

## Cross-service reliability notes

- Treat **idempotency keys** as mandatory for money, inventory, market, combat, notification, and other retryable/sensitive mutations. Gateway anti-abuse rules already distinguish actions that require `Idempotency-Key`; downstream services should also enforce idempotency where they own the mutation.
- The **gateway orchestrates flows**, but ownership remains in the domain services. Gateway may coordinate calls and keep operational/security state, but it should not own durable gameplay state or become the source of truth for wallets, inventory, production, market, world, chat, research, combat, or progression.
- Prefer synchronous calls only where a user action needs an immediate authoritative answer, such as auth, balance checks, reservations, purchases, combat simulation, or command acceptance.
- Prefer events for side effects and projections: notifications, feeds, achievements, admin/audit projections, analytics, daily summaries, and fan-out.
- Highest-priority hardening work: transactional outbox, sagas/process managers for multi-service workflows, formal database migrations instead of startup schema initialization, and contract-first APIs/events (OpenAPI/protobuf/event schemas) before expanding clients or integrations.
- Do not rely on mock-only behavior for product features. User-visible gameplay features should be real, backed by persisted state where appropriate, and wired through the owning service boundary.

## Contributor rules of thumb

1. Add new durable state to the owning service, not to the gateway.
2. If a change touches money, items, market listings, combat results, production output, or account/session state, design for retries and duplicate requests first.
3. Keep service APIs stable and explicit; update contracts/docs when changing request or response shapes.
4. Avoid secrets in docs and examples. Use `backend/env/*.env.example` placeholders and deployment scripts for environment-specific configuration.

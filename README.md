## T0 - D0

- Global Time
- Updating Player resourses
- Company 2 types food and wep (Detail Screen)
- Training Grounds
- Armory (Gear?)
- Battle Regions ( Rewards Gold and Special Resurse, useses wep and energy, strength requirements)
- Market

## - Channels

-BBM style
-DM, and group
-Profile page Info

## Using:

- RxDart
- Get_it
- Bloc

https://www.facebook.com/charuwaka/videos/2807396325978185

## Repository layout

- `frontend/` contains the Flutter app. Run Flutter commands such as `flutter pub get`, `flutter test`, and `flutter run` from this directory.
- `backend/` contains the split-first backend scaffold and local infrastructure.

## Backend microservices design

The backend should be designed around domain ownership, not UI screens. For an eRepublik-like game, the core domains are identity, player state, economy, production, market, combat, social, and scheduled world simulation.

The target backend should not use Firebase Auth or Firestore. Use a backend-owned identity flow, issue normal OIDC/JWT tokens to the Flutter app, and keep an internal `playerId` separate from the auth provider's subject/account ID.

### Recommended microservice map

| Service | Owns | Main responsibilities |
|---|---|---|
| API Gateway / BFF | Client-facing API surface | Auth verification, request routing, Flutter-friendly response shaping, rate limiting, API versioning |
| Identity Service | Auth account linkage | Owns login/account identity or integrates with a self-hosted OIDC provider; maps auth subjects to internal player IDs, handles bans/session metadata |
| Player Service | Player profile and progression | Player profile, level, XP, energy, strength, avatar, daily status, tutorial/progression state |
| Inventory Service | Player-owned items/resources | Food, weapons, raw materials, storage capacity, item balances, inventory reservations |
| Wallet / Economy Service | Money and ledgers | Gold/currency balances, transaction ledger, deposits/withdrawals, anti-negative-balance guarantees |
| Production Service | Companies/factories/jobs | Factory ownership, upgrades, production cycles, resource consumption, output generation |
| Market Service | Trading | Buy/sell orders, product listings, pricing, order matching, market taxes/fees |
| Combat Service | Battles and military actions | Battle regions, attacks, damage calculation, weapon/energy consumption, rewards |
| World Service | Game world state | Countries/regions, ownership, laws/modifiers, global day/time, world configuration |
| Scheduler / Tick Service | Time-based simulation | Daily reset, production ticks, battle expiration, energy regeneration, market cleanup |
| Social Service | Contacts/groups/guilds | Friends/contacts, guilds/parties/companies as social groups, membership and roles |
| Chat Service | Messaging | DMs, group chat, global channels, unread counts, moderation hooks |
| Notification Service | User notifications | Push/email/in-app notifications for battles, market sales, messages, daily events |
| News / Media Service | Player-generated content | Articles, comments, likes, moderation, country/global feeds |
| Politics Service | Elections and governance | Parties, candidacies, voting, country leadership, law proposals |
| Admin / Moderation Service | Operations tooling | User lookup, economy inspection, bans, compensation, audit views |
| Analytics / Telemetry Service | Product/game analytics | Event ingestion, funnels, balance metrics, suspicious behavior signals |

### MVP backend split

Start with independently deployable services from the beginning. Keep the first split pragmatic: separate services where ownership and scaling differ, but keep wallet and inventory together in `economy-service` because market and combat need atomic money/item reservations.

1. Gateway/BFF
2. Identity Service
3. Player Service
4. Economy Service: wallet ledger, currencies, inventory balances, reservations
5. Production Service
6. Market Service
7. Combat Service
8. World Service
9. Social Chat Service
10. Scheduler Service
11. Notification Service
12. Admin Service

Politics, news, and analytics can come later once the core game loop works.

### Core game loop ownership

The essential loop is:

1. Player logs in.
2. Player receives/uses energy.
3. Player works or produces resources.
4. Production creates goods.
5. Goods go into inventory.
6. Goods are sold or consumed.
7. Player fights battles using energy/weapons.
8. Rewards update wallet, XP, country/region state.
9. Scheduler advances the game day and resets timed limits.

Ownership should look like this:

```text
Flutter App
   |
API Gateway / BFF
   |
   +-- Identity / Player
   +-- Inventory
   +-- Wallet / Economy
   +-- Production
   +-- Market
   +-- Combat
   +-- World
   +-- Chat / Social
   +-- Notification
   +-- Scheduler
```

### Data ownership rules

Each service should own its own database tables/collections. Other services should not write directly into another service's data.

| Data | Owning service |
|---|---|
| Player profile, level, XP, energy | Player Service |
| Auth user mapping | Identity Service |
| Gold/currency balances | Wallet Service |
| Food, weapons, resources | Inventory Service |
| Factories, production jobs | Production Service |
| Market listings/orders | Market Service |
| Battles, damage, battle rewards | Combat Service |
| Countries, regions, modifiers | World Service |
| Messages/channels | Chat Service |
| Notifications | Notification Service |

For example, Combat should not directly subtract weapons from inventory and add rewards to wallet. It should request/emit operations through Inventory and Wallet so those services preserve their own invariants.

### Important cross-service events

Use events for things that happen after a command succeeds.

| Event | Producer | Consumers |
|---|---|---|
| `PlayerRegistered` | Identity/Player | Inventory, Wallet, Notification |
| `DailyTickStarted` | Scheduler | Player, Production, Market, Combat |
| `EnergyRegenerated` | Player | Notification, Analytics |
| `ProductionCompleted` | Production | Inventory, Notification |
| `InventoryItemReserved` | Inventory | Market, Combat |
| `MarketOrderFilled` | Market | Wallet, Inventory, Notification |
| `BattleJoined` | Combat | Inventory, Player, Analytics |
| `BattleResolved` | Combat | Wallet, Player, World, Notification |
| `RegionCaptured` | World/Combat | Notification, News, Analytics |
| `MessageSent` | Chat | Notification |

### Service details

#### API Gateway / BFF

The Flutter app should call this instead of directly calling every backend service.

Responsibilities:

- Verify OIDC/JWT access tokens issued by the Identity Service.
- Convert external user identity into internal `playerId`.
- Expose mobile-friendly endpoints.
- Hide internal service topology.
- Apply rate limits, especially for combat, market, chat, and login-heavy endpoints.

Example endpoints:

```http
GET /me
GET /dashboard
GET /inventory
POST /production/jobs
GET /market/orders
POST /market/orders
POST /combat/battles/{battleId}/fight
GET /chat/inbox
POST /chat/messages
```

#### Identity Service

Use a backend-owned identity system rather than Firebase. The Flutter app should authenticate with an OIDC/OAuth2 flow, preferably Authorization Code + PKCE for mobile/web clients, then send bearer tokens to the API Gateway.

Owns:

- `identitySubject`
- `playerId`
- account state
- ban/suspension state
- login metadata

Avoid putting game state directly in identity tables. Identity should answer "who is this account?", while Player owns game progression.

#### Player Service

Owns the player's core state:

- username
- profile
- level
- XP
- energy
- strength
- country/citizenship
- daily action counters
- tutorial state

This service should expose commands like:

```http
GET /players/{playerId}
POST /players/{playerId}/energy/consume
POST /players/{playerId}/xp/add
POST /players/{playerId}/daily-reset
```

Energy consumption should be atomic and reject if insufficient.

#### Wallet / Economy Service

This should be ledger-based, not just "balance fields".

Owns:

- currencies
- gold
- transaction ledger
- reserved funds
- economic audit trail

Use double-entry or at least append-only ledger entries for important transactions.

Example transaction types:

- `market_purchase`
- `market_sale`
- `combat_reward`
- `daily_bonus`
- `admin_grant`
- `production_cost`
- `tax`

Never let other services directly mutate balances.

#### Inventory Service

Owns item balances and reservations.

Items:

- food
- weapons
- raw resources
- produced goods
- possibly storage upgrades

Important operations:

```http
POST /inventory/{playerId}/reserve
POST /inventory/{playerId}/commit-reservation
POST /inventory/{playerId}/release-reservation
POST /inventory/{playerId}/grant
POST /inventory/{playerId}/consume
```

Reservations matter because Market and Combat both need to prevent double-spending items.

#### Production Service

Owns:

- factories
- company ownership
- production jobs
- upgrades
- worker assignment if jobs are added later
- production formulas

Production should request resource consumption from Inventory and output completed goods back to Inventory.

Example flow:

```text
Player starts food production
Production asks Inventory to reserve raw materials
Production creates production job
Scheduler completes job later
Production asks Inventory to grant food output
Production emits ProductionCompleted
```

#### Market Service

Owns:

- sell orders
- buy orders
- order book
- trade history
- market fees
- country/region market scope if needed

Market should interact with:

- Inventory to reserve listed goods.
- Wallet to reserve buyer funds.
- Wallet to transfer money.
- Inventory to transfer items.

For MVP, use simple fixed-price listings before building a full matching engine.

#### Combat Service

Owns:

- battles
- battle sides
- attacks/fights
- damage calculations
- combat logs
- rewards
- cooldowns
- battle expiration

Combat should not own player energy or weapons. It should request those from Player/Inventory.

Example fight flow:

```text
POST /combat/battles/{id}/fight

Combat:
1. Validates battle is active.
2. Requests Player Service to consume energy.
3. Requests Inventory Service to consume weapon/food if applicable.
4. Calculates damage.
5. Records combat action.
6. Emits BattleJoined or DamageDealt.
7. If battle ends, emits BattleResolved.
```

#### World Service

Owns the persistent world state:

- countries
- regions
- region ownership
- active wars
- country modifiers
- taxes
- world configuration

Combat may determine battle results, but World should apply region ownership changes.

#### Scheduler / Tick Service

This service drives the simulation.

Responsibilities:

- daily reset
- energy regeneration
- production completion
- battle expiration
- market listing expiration
- election lifecycle later
- periodic notifications

It should emit events like `DailyTickStarted` and call specific services through commands where strict completion is required.

#### Chat / Social Service

Current frontend already has chat concepts: contacts, inbox, group/global channels.

Split options:

- MVP: one SocialChat Service
- Later: separate Social Service and Chat Service

Owns:

- contacts
- direct conversations
- group channels
- global/country/guild channels
- unread counts
- moderation metadata

For real-time Flutter updates, use WebSockets or a dedicated realtime gateway backed by Redis/NATS fan-out.

#### Notification Service

Consumes events and creates:

- in-app notifications
- push notifications
- email notifications later

Examples:

- market order sold
- production completed
- battle ended
- new DM
- daily reward available

### Suggested database approach

For MVP:

| Service | Good default |
|---|---|
| Gateway/BFF | No owned game database; Redis for rate limits, short-lived cache, and request coordination |
| Identity | PostgreSQL |
| Player | PostgreSQL |
| Economy | PostgreSQL, because wallet ledger, inventory balances, and reservations need atomic transactions |
| Production | PostgreSQL |
| Market | PostgreSQL |
| Combat | PostgreSQL for battle/action records; Rust engine can keep no durable state or own its own PostgreSQL schema |
| World | PostgreSQL |
| Social Chat | PostgreSQL for message history + Redis/NATS for realtime fan-out |
| Scheduler | PostgreSQL for job state/run IDs if using Quartz/Hangfire |
| Notifications | PostgreSQL + push provider |
| Admin | PostgreSQL read models or service-owned audit tables |
| Analytics | Event stream/log store |

Use PostgreSQL as the default database for core game state because wallet, inventory, market, production, and combat all need strong transactional guarantees. In a split-first architecture, give each service its own database or schema and do not allow direct cross-service writes. Add Redis for caching, rate limits, short-lived locks, presence, and websocket fan-out. Add NATS JetStream for cross-service events instead of using database writes across service boundaries.

### Recommended technologies and frameworks

Use .NET as the default backend stack for APIs, transactional domain services, realtime, and workers. Use Rust selectively where deterministic performance, memory safety, and CPU efficiency matter most: combat calculations, market matching, simulation engines, anti-cheat analysis, and high-volume event processors.

| Layer | Recommended technology | Fit for this game |
|---|---|---|
| Main backend framework | .NET 9/10 ASP.NET Core | High performance, strong typing, excellent REST/gRPC/OpenAPI support, mature hosting, and a strong fit for domain-heavy game services |
| Performance-critical services | Rust with Axum for HTTP and Tonic for gRPC | Best fit for combat simulation, market matching, deterministic world simulation, anti-cheat scoring, and hot event processors |
| Identity | OpenIddict + ASP.NET Core Identity + PostgreSQL, or Keycloak + PostgreSQL | OpenIddict keeps auth in the .NET stack; Keycloak is a good off-the-shelf OIDC server if admin UI and built-in identity features matter more |
| Primary database | PostgreSQL | Best default for transactional game state, ledgers, inventories, orders, battles, and admin reporting |
| .NET data access | EF Core + Dapper | EF Core is productive for normal domain data; Dapper/raw SQL is better for ledger, inventory reservation, and market locking hot paths |
| Rust data access | SQLx | Compile-time checked SQL, async PostgreSQL support, and good fit for Rust services that own performance-sensitive tables |
| Cache/rate limit/presence | Redis | Rate limits, sessions/refresh-token metadata, websocket presence, temporary locks, and hot dashboard data |
| Event broker | NATS JetStream | Lightweight durable events for `ProductionCompleted`, `MarketOrderFilled`, `BattleResolved`, and scheduler ticks; simpler than Kafka for MVP |
| Internal service calls | gRPC for commands; NATS JetStream for events | gRPC works well between .NET and Rust services; NATS carries durable cross-service events without database coupling |
| Public API | ASP.NET Core REST + OpenAPI | Easy Flutter integration, clear contracts, and strong tooling through Swashbuckle/Scalar |
| Realtime | SignalR + Redis backplane | Strong fit for chat, battle updates, notifications, presence, and live market updates in a Flutter client |
| Scheduler/workflows | .NET Worker Services + Quartz.NET or Hangfire; Temporal later | Good fit for daily ticks and recurring jobs; Temporal is better later for durable multi-service workflows |
| Observability | OpenTelemetry + Prometheus + Grafana + Loki | Distributed traces, metrics, dashboards, and logs across microservices |
| Local/dev deployment | Docker Compose | Easy local stack for PostgreSQL, Redis, NATS, Keycloak, and services |
| Production deployment | Kubernetes or Docker Swarm behind Traefik/Nginx | Start simple; use Kubernetes when autoscaling, service discovery, and rolling deploys are needed |
| .NET testing | xUnit, NUnit, FluentAssertions, WebApplicationFactory, Testcontainers | Unit/API tests plus real PostgreSQL/Redis/NATS integration tests |
| Rust testing | Cargo test, Tokio test, Testcontainers, Criterion | Async integration tests and benchmarks for combat, market matching, and simulation logic |

Recommended service fit:

| Service | Best-fit implementation |
|---|---|
| API Gateway / BFF | ASP.NET Core, JWT/OIDC guards, OpenAPI, Redis rate limiting, Traefik/Nginx at the edge |
| Identity Service | OpenIddict + ASP.NET Core Identity + PostgreSQL; Keycloak remains a valid external alternative |
| Player Service | ASP.NET Core + PostgreSQL + EF Core, with Redis caching for dashboard reads |
| Economy Service | .NET + PostgreSQL ledger tables, inventory balances, reservation tables, strict transactions, idempotency keys, Dapper/raw SQL for hot paths, outbox events |
| Production Service | .NET + PostgreSQL, NATS events, Worker Services/Quartz/Hangfire for production completion |
| Market Service | .NET for fixed-price listings and normal APIs; Rust matching engine later if order matching becomes high-volume |
| Combat Service | Rust combat engine exposed through gRPC, with a thin .NET API/orchestrator if needed for auth, rate limits, and integration |
| World Service | .NET + PostgreSQL, Redis cache for countries, regions, taxes, and modifiers; move simulation-heavy calculations to Rust if needed |
| Scheduler / Tick Service | .NET Worker Service with Quartz.NET or Hangfire for MVP daily ticks; Rust workers only for heavy simulation batches |
| Social Service | .NET + PostgreSQL for contacts, guilds, memberships, roles |
| Chat Service | ASP.NET Core SignalR, PostgreSQL message history, Redis/NATS fan-out |
| Notification Service | .NET worker consuming NATS events; mobile push provider plus in-app notification table |
| News / Media Service | .NET + PostgreSQL, object storage such as S3-compatible MinIO for uploaded media |
| Politics Service | .NET + PostgreSQL, event-driven election/law lifecycle through Scheduler |
| Admin / Moderation Service | ASP.NET Core admin API + PostgreSQL read models, protected by identity roles |
| Analytics / Telemetry Service | Rust or .NET NATS event consumer first; Kafka/ClickHouse later if analytics volume grows |

Use Rust behind stable service boundaries rather than throughout the whole MVP. `combat-service` should be Rust from day one; market matching, simulation batches, anti-cheat scoring, and high-volume event processors can move to Rust when their contracts are stable. Keep CRUD-heavy, admin-heavy, and integration-heavy services in .NET for faster iteration.

### Communication style

Use both sync APIs and async events.

| Use synchronous calls for | Use events for |
|---|---|
| Validating balance/energy | Notifications |
| Reserving money/items | Analytics |
| Consuming inventory | Daily summaries |
| Joining battles | Feed updates |
| Completing purchases | Achievement/progression side effects |

Critical economic operations should be synchronous and transactional. Non-critical side effects should be event-driven.

### MVP service boundaries

The first backend should already be split into independently deployable services:

```text
backend/
  services/
    gateway-service/          # .NET, public REST API for Flutter
    identity-service/         # .NET, OpenIddict/ASP.NET Core Identity
    player-service/           # .NET
    economy-service/          # .NET, wallet + inventory
    production-service/       # .NET
    market-service/           # .NET API; Rust matcher later if needed
    combat-service/           # Rust, gRPC combat engine/API
    world-service/            # .NET
    social-chat-service/      # .NET + SignalR
    scheduler-service/        # .NET Worker
    notification-service/     # .NET Worker
    admin-service/            # .NET
  shared/
    contracts/                # protobuf, OpenAPI, event contracts
    docker/
    observability/
```

### Highest-risk areas to design carefully

| Area | Risk | Recommendation |
|---|---|---|
| Wallet | duplicated money, negative balances | ledger + transactions |
| Inventory | duplicated items | reservations + atomic commits |
| Market | race conditions on purchases | order locking / transactional order fills |
| Combat | cheating/spam | server-side damage calculation, rate limits |
| Scheduler | partial daily resets | idempotent jobs with run IDs |
| Chat | abuse/spam | rate limits and moderation hooks |
| Identity coupling | auth/game-state coupling | keep internal `playerId` separate from identity provider subjects |

### Recommended first implementation order

1. Identity Service + Player Service: map OIDC identity subject/account ID to player profile.
2. Gateway/BFF dashboard endpoint: aggregate player, economy, inventory, and basic world state.
3. Economy Service: implement wallet balances, ledger entries, item grants, item consumption, and reservations.
4. Production: create factories and production jobs.
5. Scheduler: complete production and regenerate energy.
6. Market: simple sell/buy listings.
7. Combat: active battles and fight action.
8. Social Chat Service: contacts, DMs, global channels.
9. Notifications: production done, battle result, message received.
10. Politics/News: elections, articles, parties, governance.

This gives you a backend that supports the core eRepublik-style loop before expanding into politics, media, countries, and advanced multiplayer systems.

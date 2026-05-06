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

For the first backend version, don't start with every service as a separate deployment. Start with these bounded services or modules:

1. Gateway/BFF
2. Identity + Player
3. Inventory + Wallet
4. Production
5. Market
6. Combat
7. Chat/Social
8. Scheduler

Politics, news, advanced admin, and analytics can come later once the core game loop works.

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
| Identity/Player | PostgreSQL |
| Inventory/Wallet | PostgreSQL, because transactions matter |
| Market | PostgreSQL |
| Production | PostgreSQL |
| Combat | PostgreSQL for battle/action records |
| Chat | PostgreSQL for message history + Redis/NATS for realtime fan-out |
| Notifications | PostgreSQL + push provider |
| Analytics | Event stream/log store |

Use PostgreSQL as the default database for core game state because wallet, inventory, market, production, and combat all need strong transactional guarantees. Add Redis for caching, rate limits, short-lived locks, presence, and websocket fan-out. Add an event broker for cross-service events instead of using database writes across service boundaries.

### Recommended technologies and frameworks

Use one boring, consistent stack for most MVP services, then specialize only where load proves it is needed.

| Layer | Recommended technology | Fit for this game |
|---|---|---|
| Main backend framework | TypeScript + NestJS with the Fastify adapter | Strong module boundaries, dependency injection, guards, validation, OpenAPI generation, WebSocket support, and good fit for many domain services |
| High-throughput services | Go with gRPC/Gin/Fiber, only if needed | Good fit later for combat simulation, market matching, or scheduler workers if TypeScript becomes a bottleneck |
| Identity | Keycloak + PostgreSQL | Self-hosted OIDC/OAuth2, Authorization Code + PKCE, roles, admin UI, MFA, account management, and no Firebase dependency |
| Custom auth fallback | NestJS + Passport + Argon2 + rotating refresh tokens | Use this only if Keycloak feels too heavy and the game needs fully custom account UX |
| Primary database | PostgreSQL | Best default for transactional game state, ledgers, inventories, orders, battles, and admin reporting |
| ORM/migrations | Prisma + Prisma Migrate | Productive TypeScript data access; use raw SQL for ledger/order hot paths that need precise locking |
| Cache/rate limit/presence | Redis | Rate limits, sessions/refresh-token metadata, websocket presence, temporary locks, and hot dashboard data |
| Event broker | NATS JetStream | Lightweight durable events for `ProductionCompleted`, `MarketOrderFilled`, `BattleResolved`, and scheduler ticks; simpler than Kafka for MVP |
| Internal service calls | gRPC or NATS request/reply | Typed, efficient service-to-service commands for balance checks, reservations, and combat actions |
| Public API | REST + OpenAPI | Easy Flutter integration and clear contracts; add GraphQL later only if dashboard aggregation becomes painful |
| Realtime | NestJS WebSocket Gateway or Socket.IO + Redis/NATS adapter | Good fit for chat, battle updates, notifications, and live market updates |
| Scheduler/workflows | BullMQ + Redis for MVP; Temporal later | BullMQ is simple for recurring jobs; Temporal is better later for durable multi-step workflows and retries |
| Observability | OpenTelemetry + Prometheus + Grafana + Loki | Distributed traces, metrics, dashboards, and logs across microservices |
| Local/dev deployment | Docker Compose | Easy local stack for PostgreSQL, Redis, NATS, Keycloak, and services |
| Production deployment | Kubernetes or Docker Swarm behind Traefik/Nginx | Start simple; use Kubernetes when autoscaling, service discovery, and rolling deploys are needed |
| Testing | Jest, Supertest, Testcontainers | Unit/API tests plus real PostgreSQL/Redis/NATS integration tests |

Recommended service fit:

| Service | Best-fit implementation |
|---|---|
| API Gateway / BFF | NestJS + Fastify, JWT/OIDC guards, OpenAPI, Redis rate limiting, Traefik/Nginx at the edge |
| Identity Service | Keycloak + PostgreSQL; store only the `identitySubject` to `playerId` mapping in game services |
| Player Service | NestJS + PostgreSQL + Prisma, with Redis caching for dashboard reads |
| Inventory Service | NestJS + PostgreSQL transactions, reservation tables, row locking, outbox events |
| Wallet / Economy Service | NestJS + PostgreSQL ledger tables, strict transactions, idempotency keys, outbox events |
| Production Service | NestJS + PostgreSQL, NATS events, BullMQ/Temporal workers for production completion |
| Market Service | NestJS + PostgreSQL for MVP fixed-price listings; Go later if order matching becomes high-volume |
| Combat Service | NestJS initially; Go/gRPC later if battle calculations or fight traffic become CPU-heavy |
| World Service | NestJS + PostgreSQL, Redis cache for countries, regions, taxes, and modifiers |
| Scheduler / Tick Service | BullMQ worker for MVP daily ticks; Temporal worker when workflows span multiple services |
| Social Service | NestJS + PostgreSQL for contacts, guilds, memberships, roles |
| Chat Service | NestJS WebSocket Gateway or Socket.IO, PostgreSQL message history, Redis/NATS fan-out |
| Notification Service | NestJS worker consuming NATS events; mobile push provider plus in-app notification table |
| News / Media Service | NestJS + PostgreSQL, object storage such as S3-compatible MinIO for uploaded media |
| Politics Service | NestJS + PostgreSQL, event-driven election/law lifecycle through Scheduler |
| Admin / Moderation Service | NestJS admin API + PostgreSQL read models, protected by Keycloak roles |
| Analytics / Telemetry Service | NATS event consumer first; Kafka/ClickHouse later if analytics volume grows |

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

A practical first backend could be:

```text
backend/
  gateway/
  identity-player-service/
  economy-service/        # wallet + inventory
  production-service/
  market-service/
  combat-service/
  social-chat-service/
  scheduler-service/
```

Then split later:

```text
economy-service -> wallet-service + inventory-service
social-chat-service -> social-service + chat-service
identity-player-service -> identity-service + player-service
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

1. Identity + Player: map OIDC identity subject/account ID to player profile.
2. Dashboard API: return player, wallet, inventory, and basic world state.
3. Wallet + Inventory: implement balances, item grants, item consumption.
4. Production: create factories and production jobs.
5. Scheduler: complete production and regenerate energy.
6. Market: simple sell/buy listings.
7. Combat: active battles and fight action.
8. Chat/Social: contacts, DMs, global channels.
9. Notifications: production done, battle result, message received.
10. Politics/News: elections, articles, parties, governance.

This gives you a backend that supports the core eRepublik-style loop before expanding into politics, media, countries, and advanced multiplayer systems.

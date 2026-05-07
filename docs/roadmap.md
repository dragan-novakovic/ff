# FF Roadmap and Handoff

This project is moving toward an eRepublik-style multiplayer strategy game with a
Flutter frontend and split-first backend services. The notes below describe the
current direction and the most useful next steps without claiming production
readiness for every surface.

## Current completed capabilities

The repository currently includes implemented or scaffolded surfaces for:

- Auth/account backend via gateway and identity service, including account flows
  and security-oriented frontend tests.
- Player progression: profiles, levels/XP, energy, strength, daily actions, and
  dashboard/profile surfaces.
- Economy, inventory, and market loops: balances, item/resource holdings,
  market orders, trades, treasury-style surfaces, and anti-abuse checks.
- Companies, production, and workforce: company/factory management, upgrades,
  production cycles, jobs, workforce pages, and related gateway routes.
- World simulation areas: countries, territory, diplomacy, laws/congress,
  military units, battles, and campaigns.
- Combat reports and battle participation surfaces across backend, gateway, and
  frontend game areas.
- Resource logistics for moving or planning resource flows around production and
  game-economy needs.
- Achievements, missions/objectives, rankings, and activity feed style progress
  feedback.
- Push notifications and notification worker plumbing for game events.
- Research service and frontend research page/tests.
- Newspapers, politics, social chat, and admin/moderation surfaces.
- Deployment profiles for development, staging, and production templates, plus
  local infrastructure and optional observability compose profile.

## Recommended next gameplay features

If the user asks for suggestions only, provide options and wait for explicit
approval before implementing code. Keep feature work focused on one vertical
slice at a time.

- **National war goals:** let countries set limited campaign objectives with
  clear costs, timers, rewards, and public progress.
- **Military unit coordination:** add unit orders, member contribution goals,
  shared buffs, and after-action summaries.
- **Political season loop:** schedule elections, candidacy windows, party
  activity, law proposals, and citizen voting rewards.
- **Supply-chain depth:** add quality tiers, region resource bonuses, company
  input shortages, and logistics constraints that affect production.
- **New-player retention loop:** refine tutorial missions, daily objectives,
  catch-up rewards, and notifications that pull players into work/train/fight.

## Architecture/platform priorities

- **Transactional outbox and sagas:** protect cross-service game actions such as
  market buys, production completion, battle rewards, and logistics transfers
  from partial failure.
- **Formal migrations:** replace startup schema initialization with versioned,
  reviewable migrations and a dedicated migrator per deploy profile.
- **Contract-first APIs:** maintain protobuf/OpenAPI/event contracts before
  implementation; require idempotency keys and correlation metadata on commands.
- **Read models:** build query-optimized projections for dashboard, country,
  market, battle, and admin screens instead of coupling UI reads to write models.
- **Observability:** standardize OpenTelemetry traces, metrics, structured logs,
  dashboards, and alert-friendly health checks for each service.
- **Frontend modularization:** keep Flutter features organized by domain with
  models, blocs/services, pages, and tests that can evolve independently.

## Workflow rules for future feature work

- Do not implement suggestions unless the user explicitly asks for code changes.
- Prefer small, complete vertical slices: contract, backend owner, persistence,
  gateway/BFF route, frontend state/UI, and tests.
- Respect service data ownership; other services should call commands or consume
  events instead of writing another service's tables.
- Add or update migrations/contracts/tests in the same change when behavior or
  storage changes.
- Include observability and admin/moderation considerations for gameplay systems
  that affect economy, combat, chat, politics, or account state.
- Avoid committing secrets, real environment files, or production credentials.
- Keep the backlog lightweight: document the next few decisions, not every
  possible feature.

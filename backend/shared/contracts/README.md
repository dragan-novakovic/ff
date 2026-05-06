# Backend Contract Conventions

Contracts are versioned separately from service implementations so .NET and
Rust services can evolve behind stable boundaries.

## Synchronous commands

- Prefer gRPC/protobuf for internal service commands that must complete before
  the caller continues.
- Command names should be imperative, for example `ReserveInventory`,
  `CompletePurchase`, or `JoinBattle`.
- Every command should carry metadata with a unique `command_id`,
  `idempotency_key`, `correlation_id`, `causation_id`, and `requested_at`.
- The service that owns the data validates invariants and commits its own
  transaction. Other services must not write directly into its tables.

## Asynchronous events

- Use NATS JetStream for facts that happened after a command succeeds.
- Event names are past tense PascalCase, for example `ProductionCompleted`.
- Subjects use `ff.<context>.events.v<major>.<event_name_snake_case>`.
- Each event has an envelope with `event_id`, `event_type`, `schema_version`,
  `producer`, `occurred_at`, `correlation_id`, `causation_id`, and `trace_id`.
- Consumers must be idempotent by `event_id` and tolerate out-of-order delivery
  unless a stream explicitly documents stronger ordering.

## Compatibility

- Use additive field changes within a major version.
- Do not reuse protobuf field numbers or change event meaning in place.
- Breaking changes require a new major subject/protobuf package version.
- Prefer UTC timestamps and opaque UUID/string identifiers at boundaries.

See `events/catalog.v1.yaml` for the initial cross-service event catalog and
`proto/ff/contracts/v1` for protobuf placeholders.

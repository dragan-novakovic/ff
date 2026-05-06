# Event Catalog

Initial durable events are published through NATS JetStream. Subjects use the
shape `ff.<context>.events.v1.<event_name_snake_case>`.

| Event | Producer | Consumers | Subject |
|---|---|---|---|
| `PlayerRegistered` | Player | Economy, Notification | `ff.player.events.v1.player_registered` |
| `DailyTickStarted` | Scheduler | Player, Production, Market, Combat | `ff.scheduler.events.v1.daily_tick_started` |
| `ProductionCompleted` | Production | Economy, Notification | `ff.production.events.v1.production_completed` |
| `MarketOrderFilled` | Market | Economy, Notification | `ff.market.events.v1.market_order_filled` |
| `BattleResolved` | Combat | Economy, Player, World, Notification | `ff.combat.events.v1.battle_resolved` |
| `MessageSent` | SocialChat | Notification | `ff.social_chat.events.v1.message_sent` |

Each event should include the common event metadata described in
`../README.md`, plus a payload owned by the producing service.

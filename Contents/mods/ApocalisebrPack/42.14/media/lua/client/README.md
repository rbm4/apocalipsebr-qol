# Zombie kill notifications

Kill notification is entirely server-side. There is no client command, file
export, player-position report, skill/XP export or online-player heartbeat.

`../server/ZKC_ServerHandler.lua` receives server `OnZombieDead`, verifies a real
connected player attacker and buffers counts for the trusted character life.
`../shared/ZKC_Config.lua` sets a 30-second wall-clock flush/retry interval and a
512-entry bound. Only nonempty batches are published; new kills remain separate
from a frozen batch awaiting acknowledgement.

`../server/ApocBR/BackendMessages.lua` maps `ApocBR.BackendMessage` to
`mod_data.backend_message` and exposes server-only
`BackendMessages.publish(type, playerContext, payload, callback)`. The only
current event is `ZombieKillsRecorded.v1` with `{count=N}`. A publication handle
retains its private UUID and payload for idempotent `handle:retry(callback)`.
Character context is captured by Java from the relational binding. Clients cannot
supply character IDs or invoke database operations through this feature.

`../server/ApocBR/Entities.lua` is the shared repository facade, now owned by this
pack. BeyondTen Build 42 requires mod ID `APOCALISEBR_PACK` and imports this module
through `require "ApocBR/Entities"`.

Backend migration V36 creates the immutable inbox, error history and failed-event
view. Failure six is quarantined. The backend worker/business handlers and future
game-engine consumers are not part of this change. The game buffer is bounded and
memory-only; crashes/outages may lose uncommitted kills. OnSave requests a flush
but does not synchronously await a commit. Pending file exports from earlier
versions require an explicit backend cutover/checkpoint.

Full producer/migration contract:
`Z:/git/Github/apocalipsebr-zomboid-patches/42.22.1/docs/features/2026-11-04-backend-messages.md`.
Backend contract:
`Z:/git/Github/apocalipsebr-manager/manager/docs/backend-messages.md`.

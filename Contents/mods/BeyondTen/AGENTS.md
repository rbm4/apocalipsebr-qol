# BeyondTen server Lua entity persistence

## Direction and current scope

BeyondTen is the first mod adopting the ApocBR server patch's Lua entity pathway
for mod-specific PostgreSQL persistence. The goal is to store this data directly
through server repositories instead of native global/player ModData.

Implemented 2026-10-29: gameplay in `42/media/lua/server/BeyondTen/Server.lua`
keeps its existing XP calculations, GlobalModData cache and player mirrors.
PostgreSQL wins at initialization when character rows exist. Otherwise, an atomic
load-or-create operation imports sanitized server GlobalModData, seeding real
zero-valued perk rows as initialization evidence. Player ModData never seeds the
database. Changed XP fields are patched to PostgreSQL at five-second intervals
and requested on save. This is an incremental dual-storage flow, not removal of
GlobalModData, and queued mod writes are not durable journal entries.

## Controlling files and bridge

- `42/media/lua/server/BeyondTen/Persistence/MasteryEntity.lua`: mastery mapping and
  log-only startup validation.
- `42/media/lua/server/BeyondTen/ServerMasteryService.lua`: asynchronous initialization,
  dirty generations, bounded pending XP, retries and database batch saves.
- `42/media/lua/server/BeyondTen/ServerController.lua`: authenticated vanilla
  `OnClientCommand` entry point. Accept only `RequestSync`; ignore all client
  payload fields and rate-limit requests. The player argument is supplied by vanilla.
- `42/media/lua/client/BeyondTen/ClientController.lua` and `ClientMasteryService.lua`:
  empty-payload sync requests, retry until full sync, and local-player mirror updates.
  Clients do not receive a database API, session token or character UUID in commands.
- `42/media/lua/server/ApocBR/Entities.lua`: reusable server Lua repository/entity
  facade. Require it as `ApocBR/Entities`.
- `Z:/git/Github/apocalipsebr-zomboid-patches/42.22.0/src/zombie/savefile/ApocBRModEntities.java`:
  current Java bridge, mapping rules, asynchronous execution and schema checks.
- The patched `zombie/network/GameServer.java` installs `ApocBRModEntities` before
  server Lua loads. Verify the active patch version when changing this contract.
- `ApocBRPlayerRelationalMutations.entityContext`: obtains the real character UUID
  and session from the live relational binding. No ID is derived from client data.

Keep this pathway under server Lua with an `isServer()` guard. Lua submits detached
scalar values through `ApocBRModEntities`; Java owns SQL, JDBC connections, worker
execution and transactions. Do not expose raw SQL, credentials or JDBC to Lua or
clients. The schema is always `mod_data`; Lua supplies only the unqualified table.

## Mastery mapping contract

Entity name: `BeyondTen.Mastery`. Table: `mod_data.beyondten_mastery`.

| Lua field | Mapping type | PostgreSQL reference | ID |
| --- | --- | --- | --- |
| `character_id` | `uuid` | `uuid` | yes |
| `perk_id` | `string` | `varchar` or `text` (JDBC VARCHAR/LONGVARCHAR) | yes |
| `xp` | `number` | `double precision` (JDBC DOUBLE) | no |

The database primary key must contain exactly `character_id` and `perk_id`.
An additional `revision bigint` column is managed by the bridge, not declared as
a Lua field. New objects start at revision `"0"`; committed rows use positive
revisions. Keep revisions as decimal strings to avoid Lua numeric precision loss.

Other supported mapping types are `integer` (JDBC BIGINT, Lua-exact integer range)
and `boolean` (JDBC BOOLEAN/BIT). Fields are non-null at the API boundary and IDs
are immutable. Table/field identifiers must match `[a-z][a-z0-9_]{0,47}`;
`revision` is reserved. Java currently permits 1–4 ID fields, at most 32 fields
and 16 models. Re-defining a name with a different mapping is rejected.

## Startup validation

Use `Events.OnServerStarted`, which the vanilla and patched server fire after
`IsoWorld.instance.init()` and server startup. `OnInitWorld` occurs earlier during
world initialization. Register the mapping and call `repository:validate(callback)`
once from this startup hook; do not block the server thread waiting for completion.

`Entities.lua` drains bridge completions on `OnTickEvenPaused`, on the server Lua
thread. Keep this independent of simulation ticks: with `PauseEmpty=true`, an
empty server stops firing `OnTick`, leaving completed requests undelivered.
`IngameState.updateInternal()` fires `OnTickEvenPaused` before its pause check.
An accepted request is not a
successful validation: only callback status `OK` confirms the database check.
Admission failures (`BUSY`, `UNAVAILABLE`) invoke the callback immediately. Missing
bridges and synchronous definition/submission errors must also be logged without
raising a startup error. Look for `[BeyondTen/Persistence] BeyondTen.Mastery ->
mod_data.beyondten_mastery:` followed by `validation requested`, then `validation OK`
or `validation FAILED`. A request log alone does not establish success.

The Java validator performs a zero-row SELECT to check mapped columns and JDBC
types, including `revision`, then checks the exact primary-key field set. It
does not validate nullability, defaults, foreign keys, check constraints, or extra
columns. It performs no automatic DDL. Provision/change tables through the server
database migration workflow; do not create or repair schema from mod startup.
`SCHEMA_ERROR` is a coarse result; the current callback does not identify which
column or key failed. Database failures can report `DATABASE_ERROR`, and runtime
validation failures can report `INVALID_DATA`. Startup continues on all failures.

## Active gameplay and identity contract

- `ApocBREntities.resolveCharacter(player, callback)` is server-only and delivers
  the bound UUID/session on the next completion tick. A binding may precede the
  initial character commit: the scoped worker must verify the persisted active life.
- Use `loadOrCreateForCharacter(player, context, seeds, callback)` for initialization
  and `repository:characterSnapshot(result.rows)` to retain the committed baseline.
  Call `snapshot:patch(player, context, rows, callback)` with full current row values
  for gameplay. Each row is
  `{ values = { perk_id = ..., xp = ... }, revision = "..." }`. Java injects the
  character key; supplying it in a row is rejected. Loads return all character rows.
  Patch snapshots obtain revisions from their own acknowledged baseline; supplied
  row revisions do not override it. Composite keys and changed fields are generic,
  not perk-specific. Only changed rows/columns cross the worker boundary, and patch
  results contain only changed rows and their new revisions (not the full collection).
- `entity:patch(callback)` provides the same dirty comparison for ordinary entities;
  new entities insert all fields through save. Full `save`/`saveAllForCharacter` remain
  explicit compatibility operations, but should not be used for routine mastery sync.
- Previous snapshots advance only on committed `OK`; failures/uncertain outcomes
  retain them. Capture submitted values separately from live changes so edits
  or reverts during a patch remain dirty for the next call. Unchanged calls return
  `OK, unchanged=true` immediately without SQL or revision increments. A mutation
  followed by a revert before submission also does no SQL. Omitted rows are not deleted.
- Keep presentation mirror dirtiness separate from database dirtiness. Only actual
  mastery mutations or initialization normalization schedule a snapshot comparison;
  RequestSync, scans and periodic mirror repair must not schedule database writes.
- Admission and worker execution check the session. The worker locks the actual
  `player_rel.player_slot`, verifies its active character, and atomically seeds or
  writes the collection using per-row revisions. Completion rechecks the live
  session before handing results to the service. Workers never access live players.
- Bounds: 256 collection rows, 512 service entries, 4096 pending initialization
  changes per player. New catalog zero rows fill only remaining collection capacity.
- Existing database rows replace the local cache in place, preserving alias table
  references. Mark GlobalModData records with their character UUID so another life
  cannot seed old progress. Death invalidates callbacks and clears all local aliases.
- Retain zero rows after clears; deleting all rows would permit a legacy re-import.
  Empty DB results are initialized once in one transaction; existing collections
  are never partially merged with legacy data. No migration marker table is needed
  for this zero-row-preserving policy. Do not add hard deletes without revisiting it.
- While loading, mastery bonuses and client sync are gated. Native mastery XP events,
  explicit setters, clears and recovered-XP calls are deferred and replayed in order
  over the database result. Deferred legacy synchronous APIs cannot report their final
  result immediately; the recovered-XP handler returns zero applied until replay.
- Use `repository:find(keys, callback)`, `repository:new(values)`, entity `get/set`,
  `save(callback)` and `delete(callback)`. `new` and `set` only change local objects.
- Treat callback `OK` on save/delete as committed. Handle `NOT_FOUND`, `CONFLICT`,
  `BUSY`, `UNAVAILABLE`, `DATABASE_ERROR`, `SCHEMA_ERROR`, `INVALID_DATA`, and
  `OUTCOME_UNKNOWN` explicitly. Reload/reconcile conflicts or uncertain commits;
  do not blindly retry non-idempotent changes.
- Preserve dirty tracking: one save/patch/delete may be in flight per entity; mutations
  made during a save remain dirty after that save completes.
- Retry temporary `BUSY`, `UNAVAILABLE`, `IDENTITY_PENDING`, database and bridge
  failures after five seconds. Conflicts, uncertain commits, stale sessions, schema
  and invalid-data errors stop automatic writes and retain local state for diagnosis;
  reconnect/restart reloads the database. A stale session also revokes readiness.
- This has no durable mod journal, atomic world-save barrier or distributed server
  ownership lease. Revision checks and active-life validation do not establish
  exclusive ownership across servers. Transfers need an acknowledged flush and
  ownership design before claiming durability. Do not blindly replay uncertain writes.
- The V32 mastery table currently has no foreign key; old-life rows can remain after
  relational replacement deletes old characters. They are not loaded for new lives.
  A future backend migration may add cleanup/FK policy; startup must never run DDL.

## Verification when developing

Check the Java bridge and local decompiled lifecycle before changing event timing
or interop signatures. Validate Lua syntax and exercise success, schema mismatch,
missing bridge, admission rejection and synchronous exception paths. Live server
verification must confirm both the request and terminal callback logs against the
actual PostgreSQL schema; a mocked callback cannot prove schema compatibility.
Update this file as the entity contract and migration progress change.

Regression fixtures live in `Z:/git/Github/apocalipsebr-zomboid-patches/tools/`:
`test_mod_entities.py --version 42.22.0`, `test_character_mod_entities.py`, and
`test_beyondten_persistence.py`, plus `test_entity_patches.py` for generic snapshot
semantics. They exercise production bridge/Lua code with
JDBC/game doubles; they do not replace live dedicated-server/PostgreSQL testing.

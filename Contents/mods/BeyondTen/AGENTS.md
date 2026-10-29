# BeyondTen server Lua entity persistence

## Direction and current scope

BeyondTen is the first mod adopting the ApocBR server patch's Lua entity pathway
for mod-specific PostgreSQL persistence. The goal is to store this data directly
through server repositories instead of native global/player ModData.

This migration is incremental. Gameplay in `42/media/lua/server/BeyondTen/Server.lua`
still uses its existing ModData store and player mirrors. The entity scaffold only
registers and validates the mastery mapping at server startup. It does not import,
find, save, or delete mastery rows automatically. Do not treat the migration as
complete or switch the source of truth without an explicit migration design.

## Controlling files and bridge

- `42/media/lua/server/BeyondTen/Persistence/MasteryEntity.lua`: mastery mapping and
  log-only startup validation.
- `42/media/lua/server/ApocBR/Entities.lua`: reusable server Lua repository/entity
  facade. Require it as `ApocBR/Entities`.
- `Z:/git/Github/apocalipsebr-zomboid-patches/42.22.0/src/zombie/savefile/ApocBRModEntities.java`:
  current Java bridge, mapping rules, asynchronous execution and schema checks.
- The patched `zombie/network/GameServer.java` installs `ApocBRModEntities` before
  server Lua loads. Verify the active patch version when changing this contract.

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

## Future gameplay integration

- Obtain `character_id` from trusted server reconstruction, not client input,
  usernames alone, or an assumed player/descriptor ID. Verify the supported bridge
  for this identity before implementing gameplay persistence.
- Check that the player incarnation and transfer ownership are still current when
  an asynchronous request completes. Do not mutate stale/disconnected player state.
- Use `repository:find(keys, callback)`, `repository:new(values)`, entity `get/set`,
  `save(callback)` and `delete(callback)`. `new` and `set` only change local objects.
- Treat callback `OK` on save/delete as committed. Handle `NOT_FOUND`, `CONFLICT`,
  `BUSY`, `UNAVAILABLE`, `DATABASE_ERROR`, `SCHEMA_ERROR`, `INVALID_DATA`, and
  `OUTCOME_UNKNOWN` explicitly. Reload/reconcile conflicts or uncertain commits;
  do not blindly retry non-idempotent changes.
- Preserve dirty tracking: one save/delete may be in flight per entity; mutations
  made during a save remain dirty after that save completes.
- Plan legacy import, identity transitions, durability and any client mirrors
  separately before replacing existing mastery storage. Keep clients unable to
  submit arbitrary entity names, keys, values or database operations.

## Verification when developing

Check the Java bridge and local decompiled lifecycle before changing event timing
or interop signatures. Validate Lua syntax and exercise success, schema mismatch,
missing bridge, admission rejection and synchronous exception paths. Live server
verification must confirm both the request and terminal callback logs against the
actual PostgreSQL schema; a mocked callback cannot prove schema compatibility.
Update this file as the entity contract and migration progress change.

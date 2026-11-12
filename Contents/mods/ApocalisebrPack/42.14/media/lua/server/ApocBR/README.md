# Server entity repositories

## Scoped record mutations (2026-11-12)

`Entities.document(id)` wraps the updated server bridge's `documentLoad` and
`documentMutate`. Its `load(callback)` returns scoped canonical records and a
revision; `mutate(revision, mutationId, operations, callback)` atomically commits
only named collection/key upserts or deletions. `Entities.newMutationId()` creates
a fresh UUID for a logical batch; retries must reuse the identical token/body and
expected revision. Engine server/world scope is captured by Java. Admission and
completions share the existing bounded queue and OnTickEvenPaused poll.

Runtime batches are capped at 256 records; initial revision-zero imports permit
100,000 with the existing aggregate JSON bound. The manager's V54 migration owns
the schema/function and converts existing wallet snapshots once. The wallet's
normal saves no longer replace a full document or run full projection sweeps.
Deploy migration, 42.22.2 patches, this facade and wallet together with both game
instances stopped; archived v1 wallet writes are rejected after V54.

The wallet fixture using this actual facade passed 35 checks in Fengari and
the installed game's Kahlua runtime. The Java fixture passed 348 checks;
7 isolated PostgreSQL tests cover transactions, migration and concurrent CAS.
Existing generic entity repositories below retain their API and behavior.

Wallet persistence uses `require "ApocBR/Entities"` as a hard mod dependency.
`ApocBREntities.serverScope()` returns engine-owned `server_id` and `world` without
a live player. `encode(table)` / `decode(text)` provide bounded data-only JSON:
no userdata/cycles, depth 64, 100,000 values per collection and 32 MiB characters.
The `text` field type supports bounded large state/native-item payloads; ordinary
`string` fields keep their 4096-character bound. These methods require the updated
42.22.2 entity bridge. Lua still supplies no SQL, JDBC object or datasource.

`require "ApocBR/Entities"` loads the shared server-only entity facade. The engine bridge executes prepared SQL against `mod_data` asynchronously, with completions delivered by `OnTickEvenPaused`.

Repositories now support `repo:listForServer(callback)`. The mapping must include integer `server_id` and string `world` ID fields. Java captures the engine server ID and save-world name; Lua supplies neither. Successful results contain `entities` (getters, revision strings and normal entity lifecycle) and detached `rows`. The read is ordered by primary key and limited to 256 rows per server/world; overflow yields `LIMIT_EXCEEDED` without partial rows. Admission rejection returns false and invokes the callback with BUSY/UNAVAILABLE; accepted work completes asynchronously. This requires the updated 42.22.2 `ApocBRModEntities` patch.

ExtractionMapUtils uses this method for backend-managed fixed-electricity areas. Its documentation owns policy, retry and startup application; the entity facade owns transport only. No SQL or arbitrary client query interface is exposed.

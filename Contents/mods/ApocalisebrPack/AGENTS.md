# ApocalisebrPack: implementation and persistence rules

These instructions apply to this pack and its descendants. Preserve the existing
`common`, versioned and legacy folder layout; inspect the active `mod.info` and
load paths before choosing where a change belongs.

## State machine and performance model

The server runs a high-frequency state machine. An update is an opportunity to
advance eligible work, **not a reason to persist state**. Persistence and its
preparation must follow meaningful business mutations, not tick frequency,
elapsed save intervals or repeated observation of an unchanged state.

Optimize both engine computation and PostgreSQL work. Moving unnecessary work
onto an asynchronous worker or into a database trigger does not eliminate its
cost. Throttling a whole-state snapshot does not make it a mutation design.

## Required mutation pattern

- Use the existing server-only `ApocBR/Entities` facade and the appropriate
  mutation/patch API. Inspect the implementation and its
  [API notes](42.14/media/lua/server/ApocBR/README.md) before extending it.
- Identify the authoritative owner and the specific transition that changes
  durable state. Record the affected entity keys and fields at that point.
  Submit only the rows/fields required by that transition, including explicit
  keyed deletes. An unchanged transition must produce no database write.
- Keep dirty tracking explicit and bounded. Do not rediscover mutations by
  repeatedly walking, copying, encoding, hashing or comparing the entire state
  tree, all players, all entities or accumulated history. Avoid serialization
  even for equality checking when the update has no relevant changes.
- Apply field patches where the existing mapping supports them. Scoped document
  mutations currently replace only the named record values; they are **not** an
  arbitrary JSON field-patch API. Do not invent unsupported calls or describe a
  full record replacement as a field delta. For large records containing blobs
  or history, consider separating independently changing data or extending the
  transactional mutation contract so a small change stays small end to end.
- Coalesce compatible duplicate work and unchanged values before submission.
  Do not coalesce across required custody, payment or ownership commit barriers.
  Retain pending changes until their database acknowledgment; clear only the
  exact acknowledged generation/batch so newer changes cannot be lost.

## Prohibited recurring work

Do not introduce periodic whole-state snapshots into update or persistence flows.
In particular, avoid:

- Serializing a root/global table or full collection whenever one member changes.
- Replacing a whole JSON document to change one entity or field.
- Full collection upserts, delete-and-reinsert persistence, or projection triggers
  that scan unrelated records/history on every small commit.
- Whole-state diffing, hashing or snapshot comparison as a substitute for explicit
  mutation tracking.
- Database reads/writes on every update to check whether anything changed, or
  repeated schema/primary-key discovery for an already established mapping.
- Persisting polling timestamps, tick counters, retry/admission timers, in-flight
  request handles or other session bookkeeping unless crash recovery actually
  requires them. Repeated admission failures must not rewrite an unchanged intent.

Full reconstruction or conversion can be appropriate for bounded startup loads,
explicit recovery, one-time migration or operator-requested backups. Keep these
outside recurring updates, bound their work and document their purpose. They
must not silently become the normal persistence path.

## Database and consistency boundaries

- Keep SQL/JDBC, schema DDL and credentials out of gameplay Lua. Reuse the engine
  bridge, existing worker, bounded queues and authoritative server/world scope.
  Do not open another connection or create a worker per entity/update.
- Use indexed keyed operations. Inspect triggers, projections, foreign keys and
  other downstream work: a small Lua request must not trigger a full-state scan.
- Commit coupled business mutations atomically. Preserve optimistic revision
  checks, stable idempotency keys and safe reconciliation of ambiguous commits.
  Retry the same logical batch without rebuilding unrelated state.
- Preserve acknowledgment barriers before irreversible inventory/payment effects.
  Never remove a required durable write merely to reduce CPU. Native world files,
  HTTP services and SQL do not share a transaction; document recovery boundaries.
- Keep derived indexes and caches in memory when they can be reconstructed safely
  from canonical records. Bound queues, retries and retained data. An unavailable
  database must not create a busy retry loop or an unbounded backlog.
- Missing mutation support must fail explicitly. Do not silently fall back to
  recurring snapshots, native-file persistence or unacknowledged success.

The scoped document API uses `Entities.document(id):load(callback)` and
`:mutate(revision, mutationId, operations, callback)`, with
`Entities.newMutationId()` for a new logical batch. Verify current bounds and
deployment prerequisites in the facade/bridge; do not bypass them. Existing
entity `patch` and character mutation APIs retain their own contracts.

## Verification and documentation

For persistence changes, add or adapt focused regression tests that verify:

- Unchanged/idle updates and repeated unchanged admission retries issue zero SQL
  writes and do not serialize or traverse unrelated state.
- Changing one record touches only its intended rows/fields. Adding thousands of
  unrelated historical records does not increase that mutation's preparation or
  database work in proportion to total history.
- Coupled changes commit/roll back together; deletions, concurrent revisions,
  lost acknowledgments, stale callbacks and restart recovery remain correct.
- Batching, queue capacity, backoff and failure paths stay bounded, including
  empty paused servers where `OnTickEvenPaused` still runs.

Exercise production Lua through the actual Kahlua runtime when its semantics
matter. Validate SQL changes against a disposable local database and compile
bridge changes against the exact target game JAR. Ordinary tests must not mutate
production databases or deploy/restart live servers.

Document the canonical records, mutation owner, dirty fields, transaction and
acknowledgment boundaries, work bounds, migration/deployment order and measured
validation. Distinguish mocked checks from live CPU measurements. Preserve
unrelated working-tree changes and keep optimizations scoped to the requested work.

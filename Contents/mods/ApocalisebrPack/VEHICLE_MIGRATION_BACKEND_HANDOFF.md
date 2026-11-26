# Vehicle migration backend handoff

The game mod now consumes PostgreSQL jobs from an authenticated `servercommand` notification or a scoped startup recovery query. Update the manager in `apocalipsebr-manager` to publish those jobs through its existing game-runtime datasource. The vehicle migration no longer reads or rewrites `VehicleMigration.txt`.

## Runtime database contract

Create the table through the manager's game-runtime Flyway migrations. The Lua entity bridge requires the exact primary key below and a positive bigint revision. Grant the configured game runtime role read access and permission to update the result fields and revision. Inspect the runtime migration directory's instructions for ownership and grants.

```sql
CREATE TABLE mod_data.vehicle_migration_job (
    server_id bigint NOT NULL,
    world text NOT NULL,
    job_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    payload text NOT NULL,
    detail text NOT NULL DEFAULT '',
    vehicle_id bigint NOT NULL DEFAULT -1,
    cargo_restored boolean NOT NULL DEFAULT false,
    revision bigint NOT NULL DEFAULT 1,
    PRIMARY KEY (server_id, world, job_id),
    CHECK (status IN ('pending', 'applying', 'delivered', 'review_required')),
    CHECK (octet_length(payload) BETWEEN 1 AND 131072),
    CHECK (char_length(detail) <= 512),
    CHECK (vehicle_id >= -1),
    CHECK (revision > 0)
);
```

Resolve `server_id` and `world` to the destination's engine scope, as reported by `ApocBREntities.serverScope()`. The manager's routing key selects the RCON endpoint. The Lua consumer derives the database scope from the engine. Keep the payload immutable after publication. Use a stable UUID for each logical delivery and retain an idempotency record after removing the queue row so a repeated request cannot create a replacement job.

Limit the queue to 32 rows per destination, including unresolved and unarchived jobs. The game admits at most 32 jobs in memory and processes one at a time. Its startup query uses `listForServer`, which fetches all mapped rows for the scope and rejects results above 256. Store long-term history outside the queue.

## Publish and notify

1. Adapt `VehicleMigrationService.deliver` to publish the existing `VehicleSpawn` JSON as one row. Keep item counts grouped by container and item type. Preserve the current coordinate convention and default container assignment.
2. Commit the runtime row before using the manager's targeted RCON service to notify the destination. The app and runtime datasources use separate transactions. Persist and reconcile the publication using a stable operation ID so a failed request or backend restart can resume without inserting a second job.
3. Send the following command with the job's UUID. The Lua module subscribes directly to the Byte Buddy event. The public RCON extension mod is optional for this workflow.

```text
servercommand vehicle-migration 01a20e22-1947-7882-9c14-eb9d3ba185b2
```

The payload is JSON text. Use the existing fields `scriptName`, `x`, `y`, and `items`. The coordinates must be finite and in the range 0–1,000,000. Lua uses the destination ground-level tile. An optional `createKey` boolean defaults to true. `items` may be omitted or contain up to 2,048 dense entries with a `fullType`, vehicle part ID in `container`, and optional positive integer `count` defaulting to 1.

```json
{
  "scriptName": "Base.SportsCar",
  "x": 7073.5,
  "y": 7677.37,
  "createKey": true,
  "items": [
    {"fullType": "Base.WaterBottle", "container": "TruckBed", "count": 8}
  ]
}
```

Use the database job state for the backend's result. The RCON reply `Server command dispatched.` acknowledges dispatch to the event. Retry notification for bounded batches of `pending` jobs with backoff if a server was offline, a notification was missed, or a cell never became available. Reuse the original job UUID.

## Consume and archive results

| State | Meaning and backend action |
| --- | --- |
| `pending` | Eligible to notify. The Lua module also recovers it on startup. A cell timeout before spawning can return a claimed job to this state. |
| `applying` | The Lua module committed a revision-checked claim before calling the spawn API. If it remains in this state after a restart, surface it for reconciliation. Requeue only after an operator verifies that spawning never occurred or resolves the spawned vehicle. |
| `delivered` | The game registered a vehicle and verified insertion of the expected cargo and requested key, subject to the server's cargo sandbox setting. Read `vehicle_id`, `cargo_restored`, and `detail` into the delivery receipt. A false `cargo_restored` here means the setting disabled a nonempty cargo list. |
| `review_required` | Validation failed or an incomplete spawn may exist. Retain the original payload and surface `detail` and `vehicle_id`. A value of `-1` means Lua did not obtain a vehicle ID and is insufficient evidence that nothing spawned. |

Archive and remove a delivered queue row in one runtime transaction. Use a conditional delete by scope, job ID, revision, and `status = 'delivered'`, and retain the payload, result, and stable operation ID in the receipt. Update the app candidate state from that receipt idempotently. Review the current self-service policy that completes all of a user's preserved candidates after one handoff. The delivery receipt only proves the specific job it identifies.

The Lua result confirms the vehicle and cargo in the running game. The native engine queues vehicle persistence separately and the Lua bridge has no native save acknowledgment. Keep the receipt and payload for reconciliation after a host crash. An `applying` row is never replayed automatically. If the backend needs to promise persistence across an immediate process crash, it needs confirmation from the native vehicle persistence path before making that stronger claim.

## Cutover and acceptance

- Verify each destination has the server-side Java agent exposing `OnApocBRServerCommand`, `ApocBRModEntities`, and `ApocBRLobbyStreaming.keepCellLoaded`.
- Apply Flyway before enabling the updated mod. Drain or manually reconcile old JSONL entries before retiring the SSH producer. Existing lines carry no job UUID and should be imported only after confirming they were never applied.
- Test duplicate notifications, restart with a pending job, an unloaded destination with zero players, missing cargo or key, interrupted claims, and archive retries. Verify that the migration tick callback detaches when the queue drains and attaches again for new work. The shared entity bridge still delivers database completions.

The Lua smoke test ran the production migration and entity facade in the installed game's Kahlua runtime with simulated database and vehicle APIs. It covered startup recovery, scoped notifications, duplicate suppression, claim conflicts, cell timeout, cargo failure, and idle behavior. Live PostgreSQL, RCON, cell streaming, and native vehicle save acceptance remain to be tested after the backend contract is installed.

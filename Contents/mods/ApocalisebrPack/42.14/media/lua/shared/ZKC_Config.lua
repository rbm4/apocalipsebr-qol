-- Server-only kill batching. No client commands, files or player-stat export.
ZKC_Config = {
    enabled = true,
    flushIntervalMs = 30000,
    retryIntervalMs = 30000,
    maxEntries = 512,
}
return ZKC_Config

# Zombie Kill Counter & Player Tracker (Server File-Based Export)

## Overview
This mod tracks zombie kills and player data, exporting it to a **server-side file** for consumption by an external API. Clients send data to the server via commands, and the server writes it to a newline-delimited JSON file that your external API can read and clear periodically.

## Architecture

### Files
- **ZKC_Config.lua** (shared): Configuration settings for storage filename, batching, and debug options
- **ZKC_API.lua** (client): Sends player data to server via `sendClientCommand()`
- **ZKC_Main.lua** (client): Core logic for tracking kills and managing batching
- **ZKC_Events.lua** (client): Event handlers that hook into game events
- **ZKC_ServerHandler.lua** (server): Receives client commands and writes to server file

### How It Works

1. **Kill Detection**: The `OnZombieDead` event triggers when a zombie dies (client-side)
2. **Kill Attribution**: The mod checks if the local player killed the zombie (client-side)
3. **Batching** (optional): Kills are batched to reduce server commands (client-side)
4. **Server Command**: Client sends `sendClientCommand("ZKC", "StoreKillData", {...})` to server
5. **File Export**: Server receives command and appends data to JSONL file
6. **API Consumption**: Your external API reads the server file, processes data, and clears it

### Configuration

Edit `ZKC_Config.lua` to configure:
```lua
ZKC_Config.Storage.filename = "ZKC_PlayerData.jsonl"
ZKC_Config.Storage.debug = true
ZKC_Config.Batch.enabled = true
ZKC_Config.Batch.maxBatchSize = 100
```

### Data File Format

The server writes to `ZKC_PlayerData.jsonl` in the **server's Zomboid directory** in newline-delimited JSON format (JSONL). Each line is a complete JSON object:

```json
{"playerName":"PlayerUsername","playerId":"123456","timestamp":1705536000,"serverName":"MyServer","updateNumber":1,"killsSinceLastUpdate":5,"totalSessionKills":42,"x":10500,"y":9800,"z":0,"health":100,"infected":false,"isDead":false,"inVehicle":false,"profession":"Unemployed","hoursSurvived":48,"updateReason":"timer"}
{"playerName":"PlayerUsername","playerId":"123456","timestamp":1705536060,"serverName":"MyServer","updateNumber":2,"killsSinceLastUpdate":3,"totalSessionKills":45,"x":10520,"y":9810,"z":0,"health":95,"infected":false,"isDead":false,"inVehicle":false,"profession":"Unemployed","hoursSurvived":48,"updateReason":"kill_threshold"}
```

### External API Integration

Your external API should:
1. **Periodically read** the `ZKC_PlayerData.jsonl` file from the **server's directory** (e.g., every 10-30 seconds)
2. **Parse each line** as a separate JSON object
3. **Process the data** (store in database, update statistics, etc.)
4. **Clear the file** after successful processing (delete or truncate it)

**Important**: The file is located on the **server machine**, not client machines. Your API needs access to the server's filesystem.

Example Python API reader:
```python
import json
import os

DATA_FILE = "ZKC_PlayerData.jsonl"

def read_and_process_kills():
    if not os.path.exists(DATA_FILE):
        return []
    
    with open(DATA_FILE, 'r') as f:
        lines = f.readlines()
    
    # Parse each line as JSON
    data = [json.loads(line) for line in lines if line.strip()]
    
    # Process data here...
    for entry in data:
        print(f"Player {entry['playerName']} killed {entry['killsSinceLastUpdate']} zombies")
    
    # Clear the file after processing
    open(DATA_FILE, 'w').close()
    
    return data
```

##Client-to-server commands are lightweight (just JSON string)
- Server file writes are synchronous but very fast (no network latency)
- Batching reduces command frequency (configurable batch size and timeout)
- Only the server performs file I/O operations
- File writes are synchronous but very fast (no network latency)
- Batching reduces file write frequency (configurable batch size and timeout)
- No file I/O on the server - all data goes directly to your API
- Minimal game tick overhead

## Future Enhancements

- Support for batch endpoint (send multiple kills in one request)
- Retry logic for failed API calls
- Queue persistence (save pending kills if API is unavailable)
- Additional kill statistics (weapon used, zombie type, etc.)
- Admin commands for testing and statistics

## Testing

To test the API connection, you can use the debug command in-game or modify `ZKC_Events.lua` to call:
```lua
ZKC_API.testConnection()
```

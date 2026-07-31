# RaccoonCityB42 Difference Report

Compared on 2026-07-30.

Local copy:

`C:\Users\ricar\Zomboid\Workshop\apocbr\Contents\mods\RaccoonCityB42`

Workshop copy:

`Z:\SteamLibrary\steamapps\workshop\content\108600\3388468313\mods\RaccoonCityB42`

## Executive Summary

- Local has 325 files; Workshop has 306 files.
- After normalizing the top-level `42\` vs `common\` layout, 272 files are byte-identical but stored under different version folders.
- 31 normalized files have different content.
- 19 normalized files exist only in the local copy.
- No normalized files exist only in the Workshop copy.
- The most important behavioral differences are:
  - Local uses `tiledef=shisantiles 9527`; Workshop uses `tiledef=shisantiles 2527`.
  - Local moves most content into `42\media`; Workshop stores most content in `common\media`.
  - Local adds PTBR translations.
  - Local changes vehicle spawning to avoid several modded vehicles spawning naturally.
  - Local adds multiplayer/server fixes for the Biochemical PickupTruck doors and armor protection.
  - Local changes Biochemical PickupTruck vehicle script values.
  - Local has changed binary `.lotheader` map data for 9 cells.

## Packaging Layout

Local puts the main mod payload under:

`42\media\...`

Workshop puts the same payload under:

`common\media\...`

Most assets, models, sounds, textures, maps, scripts, and Lua files are identical after stripping the leading `42\` or `common\` prefix. This is a packaging/versioning difference more than a content difference for the 272 matching files.

Both copies also contain `42\mod.info`, `42\poster.png`, `common\mod.info`, and `common\poster.png`.

## Mod Info Difference

Both `42\mod.info` files are identical except for `tiledef`:

Local:

```ini
tiledef=shisantiles 9527
```

Workshop:

```ini
tiledef=shisantiles 2527
```

The same difference exists in `common\mod.info`.

Impact: this can affect custom tile ID assignment/collision behavior. It is one of the highest-risk differences if saves or other mods depend on the tile range.

## Local-Only Files

These files exist only in the local copy after normalizing `42\` vs `common\`:

```text
media\lua\server\Vehicles\Biochemical_Armor_Server.lua
media\lua\shared\Translate\PTBR\ContextMenu.json
media\lua\shared\Translate\PTBR\Fluids.json
media\lua\shared\Translate\PTBR\IG_UI.json
media\lua\shared\Translate\PTBR\ItemName.json
media\lua\shared\Translate\PTBR\language.txt
media\lua\shared\Translate\PTBR\Recipes.json
media\lua\shared\Translate\PTBR\Sandbox.json
media\lua\shared\Translate\PTBR\Tooltip.json
media\maps\RaccoonCity\38_38.lotheader.bak
media\maps\RaccoonCity\38_39.lotheader.bak
media\maps\RaccoonCity\38_40.lotheader.bak
media\maps\RaccoonCity\39_38.lotheader.bak
media\maps\RaccoonCity\39_39.lotheader.bak
media\maps\RaccoonCity\39_40.lotheader.bak
media\maps\RaccoonCity\40_38.lotheader.bak
media\maps\RaccoonCity\40_39.lotheader.bak
media\maps\RaccoonCity\40_40.lotheader.bak
media\maps\RaccoonCity\worldmap-annotations.lua
```

Notes:

- `Biochemical_Armor_Server.lua` is a real gameplay/server fix, not packaging noise.
- PTBR translation files are local additions.
- The `.lotheader.bak` files look like backup artifacts and may not need to be shipped unless intentionally used.
- `worldmap-annotations.lua` adds local-only world map annotation data.

## Gameplay Lua Differences

### Biochemical PickupTruck door fix

Local changes:

- `media\lua\client\Vehicles\Biochemical_PickupTruck.lua`
- `media\lua\server\RaccoonCityServerCommand.lua`

Local adds an `Events.OnEnterVehicle` handler for `Base.Biochemical_PickupTruck`. In multiplayer clients, it sends:

```lua
sendClientCommand(player, "RaccoonCityCommand", "closeBiochemicalDoor", {})
```

The local server command handler receives `closeBiochemicalDoor`, checks that the player is inside `Base.Biochemical_PickupTruck`, then force-closes open door parts and transmits the door state.

Workshop does not have this fix.

### Biochemical armor logic

Local changes:

- `media\lua\shared\Biochemical_Armor.lua`
- `media\lua\server\Vehicles\Biochemical_Armor_Server.lua`
- `media\scripts\vehicles\template_Biochemical_Bumper.txt`

Workshop keeps the armor protection logic in shared Lua using `Events.OnEnterVehicle` and `Events.OnPlayerUpdate`, including client-side condition changes and `sendClientCommand("vehicle", "setPartCondition", ...)` for TruckBed.

Local replaces shared armor logic with a namespace stub and moves authoritative behavior into `Biochemical_Armor_Server.lua`. The local bumper template also adds:

```txt
lua
{
    create = Biochemical_Armor.Create,
    update = Biochemical_Armor.Update,
}
```

Impact: local is adapted for B42 server-authoritative vehicle part condition handling. This is likely intended to fix multiplayer sync/authority problems.

### Vehicle spawning

Local changes:

- `media\lua\server\BasementPoliceCarSpawns.lua`
- `media\lua\shared\RaccoonCitySpawns.lua`

Local adds a `BlockedPrefixes` list to prevent several modded vehicle prefixes from appearing in basement police car spawns, including ATA vehicles, Humvee/trailer entries, Biochemical pickup, Bronco, and Unimog entries.

Local also changes vehicle zone distributions:

- `biochemical`: local uses vanilla `Base.SUV` and `Base.PickUpTruck`; Workshop uses `Base.Biochemical_PickupTruck` with very high spawn chance.
- `modplain`: local uses vanilla civilian vehicles; Workshop uses several modded vehicle ids.
- `modspecial`: local uses vanilla police/ranger/luxury vehicles; Workshop uses ATA special vehicles.

Impact: local appears tuned to stop dependency/mod-store vehicles from spawning naturally and use vanilla fallbacks instead.

## Vehicle Script Differences

Changed file:

`media\scripts\vehicles\Biochemical_PickupTruck.txt`

Local values:

```txt
maxSpeed = 110f
engineLoudness = 160
frontEndDurability = 150
rearEndDurability = 150
GloveBox capacity = 25
```

Workshop values:

```txt
maxSpeed = 100
engineLoudness = 40
frontEndHealth = 150
rearEndHealth = 150
GloveBox capacity = 7
```

Impact:

- Local truck is faster and much louder.
- Local glovebox capacity is much larger.
- Local uses `frontEndDurability`/`rearEndDurability`; Workshop uses `frontEndHealth`/`rearEndHealth`. This may matter for B42 script compatibility depending on which field names the current parser accepts.

## Map Differences

Changed text map metadata:

`media\maps\RaccoonCity\map.info`

Local description:

```text
Epicentro da infeccao Knox, antigo centro de operacoes da Umbrella, utilizado hoje em dia como laboratorio a ceu aberto do Virus Knox
```

Workshop description:

```text
Located to the west of muldraugh, with a map size of 2x2, in cells 33,33
```

Changed binary map headers:

```text
38_38.lotheader  local 25744 bytes  workshop 25523 bytes
38_39.lotheader  local 49745 bytes  workshop 46100 bytes
38_40.lotheader  local 30073 bytes  workshop 27958 bytes
39_38.lotheader  local 50580 bytes  workshop 47250 bytes
39_39.lotheader  local 110348 bytes workshop 106764 bytes
39_40.lotheader  local 84654 bytes  workshop 82183 bytes
40_38.lotheader  local 24500 bytes  workshop 23645 bytes
40_39.lotheader  local 118374 bytes workshop 114896 bytes
40_40.lotheader  local 87043 bytes  workshop 85517 bytes
```

Other map files such as `.lotpack`, `chunkdata_*.bin`, `worldmap.xml`, `worldmap.xml.bin`, `worldmap-forest.xml`, and `worldmap-forest.xml.bin` are byte-identical after folder normalization.

## Translation Differences

Local adds a complete PTBR translation folder.

Several existing CN/EN JSON files differ. The most meaningful observed difference is in `ItemName.json`:

- Local uses keys like `ItemName_Base.AdapterClip`.
- Workshop uses keys like `Base.AdapterClip`.

Other translation JSON diffs are largely formatting/whitespace or key-category style changes.

Impact: local appears adjusted toward B42-style translation keys for item names and adds Brazilian Portuguese support.

## File Count By Extension

Local:

```text
.bak 10
.bin 14
.fbx 21
.info 3
.json 20
.lotheader 12
.lotpack 12
.lua 32
.ogg 69
.pack 3
.png 95
.tiles 1
.txt 27
.xml 6
```

Workshop:

```text
.bak 1
.bin 14
.fbx 21
.info 3
.json 13
.lotheader 12
.lotpack 12
.lua 30
.ogg 69
.pack 3
.png 95
.tiles 1
.txt 26
.xml 6
```

## Practical Recommendation

Treat the local copy as a patched/forked version of the Workshop copy, not just a repack.

If the goal is to publish or deploy the local copy, review these before shipping:

- Confirm `tiledef=shisantiles 9527` is intentional and does not conflict with other tile packs.
- Keep `Biochemical_Armor_Server.lua` and the bumper `lua { create/update }` hook together; they are linked.
- Decide whether local `.lotheader.bak` files should be removed from the distributable package.
- Confirm whether the local vehicle script should use `frontEndDurability`/`rearEndDurability` or the Workshop `frontEndHealth`/`rearEndHealth` names for the exact B42 target.
- Confirm the spawn-pool changes are intentional, because local intentionally removes many modded vehicles from natural spawns.

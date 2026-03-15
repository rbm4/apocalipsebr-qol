# Simple Suppressor B42

Adds one new standalone `WeaponPart` item: `SimpleSuppressorB42.Suppressor`.

Compatibility target:
- `42.14.1`
- `42.15.0`
- `42.15.1`
- Singleplayer, multiplayer host, and dedicated server

Implementation:
- `42/media/scripts/suppressor.txt`: defines the suppressor item, `Canon` part slot, supported `MountOn` weapons, and the dedicated ground model.
- `42/media/scripts/suppressor_models.txt`: defines the equipped suppressor model and the separate dropped-world model.
- `42/media/scripts/vanilla_weapon_overrides.txt`: adds native `ModelWeaponPart` mappings for the suppressor on the supported vanilla firearms.
- `42/media/scripts/vanilla_weapon_model_overrides.txt`: adds native `attachment Canon` placement on the supported vanilla firearm models.
- `42/media/scripts/sounds_simple_suppressor_b42.txt`: defines the custom suppressed firing sound plus attach and detach sounds.
- `42/media/lua/shared/SimpleSuppressorB42/SimpleSuppressorB42_Sound.lua`: sound-only Lua. It updates `SwingSound`, `SoundRadius`, and `SoundVolume` after native attach, detach, equip, and load events. It does not touch held-weapon visuals.
- `42/media/lua/server/SimpleSuppressorB42/SimpleSuppressorB42_Loot.lua`: injects the suppressor into procedural loot tables only, once.
- `42/media/lua/shared/Translate/EN/Tooltip_EN.txt`: adds the suppressor tooltip text.
- `42/media/models_X/WorldItems/suppressor.fbx`: dropped-world mesh.
- `42/media/models_X/weapons/parts/suppressor/SimpleSuppressorB42_Suppressor.fbx`: equipped suppressor mesh.
- `42/media/textures/item_Suppressor.png`: inventory icon.
- `42/media/textures/weapons/parts/suppressor/SimpleSuppressorB42_Suppressor.png`: suppressor texture.

Targeted vanilla weapons:
- `Base.Pistol`
- `Base.Pistol2`
- `Base.Pistol3`
- `Base.AssaultRifle`
- `Base.AssaultRifle2`
- `Base.HuntingRifle`
- `Base.VarmintRifle`

Suppressor stats:
- Weight `0.4`
- Part slot `Canon`
- Small range penalty (`MinRangeModifier = -1`, `MaxRangeModifier = -1`)
- Small aim handling penalty (`HitChanceModifier = -2`, `AimingTimeModifier = 2`)

Assumptions:
- `Base.Rifle` was not present in the local Build 42.14.1 vanilla firearm scripts, so it was not included.
- The suppressor uses the native `Canon` attachment point on the supported vanilla weapon models.
- Build 42.14.1 does not expose a native `WeaponPart` script property that changes firearm `SwingSound`, `SoundRadius`, or `SoundVolume`, so a minimal shared sound script updates those fields after native attach, detach, equip, and load events.
- The current 42-series runtime inspected locally still loads translation entries from `42/media/lua/shared/Translate/EN/Tooltip_EN.txt`, so no separate 42.15-only translation fork was required for this mod.

Visual behavior:
- Held-weapon visuals use the native Build 42 pipeline only: `WeaponPart` + `ModelWeaponPart` + weapon model `attachment Canon`.
- No sprite swapping, no forced hand-model refresh, no custom client/server commands, and no held-weapon visual dirty workaround code remain in the mod.
- Because the suppressor is attached as a real weapon part, the equipped suppressor state should persist naturally through relog, inventory moves, drops, and multiplayer replication.

Sound behavior:
- The custom suppressed firing sound is active on the supported weapons while the suppressor is attached.
- The existing toggle sound asset is used for both suppressor attach and suppressor detach.
- The sound Lua only touches the live weapon audio profile; it is not part of the visual attachment pipeline.

Known limitations:
- The visual pipeline is fully native, but the suppressed sound profile is still Lua-driven because Build 42.14.1 does not offer a native per-`WeaponPart` firearm sound override.
- The suppressor still uses one shared attachment model across the supported pistol and rifle set.
- The mod is adapted to the 42.14.1 / 42.15.0 / 42.15.1 runtime surface without changing weapon behavior between those builds; it was not live-validated here on a real dedicated server session, only adapted against the current 42-series scripts/runtime present in the workspace.

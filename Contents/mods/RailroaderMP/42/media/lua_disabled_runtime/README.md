RailroaderMP runtime disabled for save compatibility.

The active Lua loader path (`media/lua`) intentionally keeps only:
- `shared/Railroader/RR_Profession.lua`
- `shared/Definitions/animal/*.lua`
- translation JSON files

This keeps the `rr:railroader` profession/trait and saved Railroader animal
types registered, while preventing the client/server train simulation, HUD,
network commands, and tick handlers from loading on multiplayer servers.

Move these files back under `media/lua` to re-enable the train runtime.

#!/bin/bash
# filepath: patchSyncClothing.sh
# Patches SyncClothingPacket.java to fix the "naked player" clothing desync bug.
#
# Root cause: SyncClothingPacket.processServer() echoes the packet back to the
# SENDING client (passes null to sendToClients instead of excluding the sender).
# Every other packet (EquipPacket, GameCharacterAttachedItemPacket, etc.) correctly
# excludes the sender. This self-echo carries stale clothing state which overwrites
# any items added between the original send and the echo receipt.
#
# The bug manifests during any action that rapidly triggers clothing syncs:
#   - Bandaging wounds (addBandageModel → setWornItem → SyncClothing)
#   - Climbing fences/windows (visual state transitions → SyncClothing)
#   - Combat with multiple zombies (addHole/addBlood each → SyncClothing)
#
# Fixes applied:
#   1. processServer(): exclude sender from relay (server-side, primary fix)
#   2. processClient(): skip destructive process() for local player (client-side defense)
#   3. Null-safety: guard ItemBodyLocation lookups in parse/process/isItemsContains
 
set -e
 
JAR_FILE="/opt/pzserver/java/projectzomboid.jar"
JAVAC="/usr/lib/jvm/java-25-openjdk-amd64/bin/javac"
JAR_CMD="/usr/lib/jvm/java-25-openjdk-amd64/bin/jar"
WORK_DIR="/tmp/pzpatch_syncclothing"
 
echo "=== PZ SyncClothingPacket Patch (Self-Echo + Null-Safety) ==="
 
# Verify tools exist
if [ ! -f "$JAVAC" ]; then
    echo "ERROR: javac not found at $JAVAC"
    exit 1
fi
 
if [ ! -f "$JAR_FILE" ]; then
    echo "ERROR: JAR not found at $JAR_FILE"
    exit 1
fi
 
# Clean and create working directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/src/zombie/network/packets"
mkdir -p "$WORK_DIR/build"
 
echo "[1/5] Creating backup..."
cp -n "$JAR_FILE" "${JAR_FILE}.bak" 2>/dev/null || echo "  Backup already exists, skipping."
 
echo "[2/5] Writing patched SyncClothingPacket.java..."
cat > "$WORK_DIR/src/zombie/network/packets/SyncClothingPacket.java" << 'JAVAEOF'
package zombie.network.packets;
 
import java.util.ArrayList;
import zombie.Lua.LuaEventManager;
import zombie.characterTextures.BloodBodyPartType;
import zombie.characters.Capability;
import zombie.characters.IsoPlayer;
import zombie.characters.WornItems.WornItem;
import zombie.characters.animals.IsoAnimal;
import zombie.core.ImmutableColor;
import zombie.core.network.ByteBufferReader;
import zombie.core.network.ByteBufferWriter;
import zombie.core.raknet.UdpConnection;
import zombie.core.skinnedmodel.visual.ItemVisual;
import zombie.debug.DebugLog;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.types.Clothing;
import zombie.network.GameClient;
import zombie.network.IConnection;
import zombie.network.JSONField;
import zombie.network.PacketSetting;
import zombie.network.PacketTypes;
import zombie.network.ServerGUI;
import zombie.network.fields.character.PlayerID;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.scripting.objects.ResourceLocation;
import zombie.util.Type;
 
@PacketSetting(ordering = 0, priority = 1, reliability = 2, requiredCapability = Capability.LoginOnServer, handlingType = 3)
public class SyncClothingPacket implements INetworkPacket {
    @JSONField
    private final PlayerID playerId = new PlayerID();
    @JSONField
    private final ArrayList<SyncClothingPacket.ItemDescription> items = new ArrayList<>();
 
    @Override
    public void setData(Object... values) {
        if (values.length == 1 && values[0] instanceof IsoPlayer) {
            this.set((IsoPlayer)values[0]);
        } else {
            DebugLog.Multiplayer.warn(this.getClass().getSimpleName() + ".set get invalid arguments");
        }
    }
 
    public void set(IsoPlayer player) {
        if (player instanceof IsoAnimal) {
            DebugLog.General.printStackTrace("SyncClothingPacket.set receives IsoAnimal");
        }
 
        this.playerId.set(player);
        this.items.clear();
        this.playerId.getPlayer().getWornItems().forEach(item -> {
            // PATCH: skip items with null location to prevent NPE in write()
            if (item != null && item.getItem() != null && item.getLocation() != null) {
                this.items.add(new SyncClothingPacket.ItemDescription(item));
            }
        });
    }
 
    void parseClothing(ByteBufferReader b, int itemId) {
        IsoPlayer player = this.playerId.getPlayer();
        if (player != null) {
            Clothing clothing = Type.tryCastTo(player.getInventory().getItemWithID(itemId), Clothing.class);
            if (clothing != null) {
                clothing.removeAllPatches();
            }
 
            byte patchesNum = b.getByte();
 
            for (byte j = 0; j < patchesNum; j++) {
                byte bloodBodyPartTypeIdx = b.getByte();
                byte tailorLvl = b.getByte();
                byte fabricType = b.getByte();
                boolean hasHole = b.getBoolean();
                if (clothing != null) {
                    ItemVisual bloodBodyPartType = clothing.getVisual();
                    if (bloodBodyPartType instanceof ItemVisual) {
                        bloodBodyPartType.removeHole(bloodBodyPartTypeIdx);
                        BloodBodyPartType bloodBodyPartTypex = BloodBodyPartType.FromIndex(bloodBodyPartTypeIdx);
                        switch (Clothing.ClothingPatchFabricType.fromIndex(fabricType)) {
                            case null:
                                break;
                            case Cotton:
                                bloodBodyPartType.setBasicPatch(bloodBodyPartTypex);
                                break;
                            case Denim:
                                bloodBodyPartType.setDenimPatch(bloodBodyPartTypex);
                                break;
                            case Leather:
                                bloodBodyPartType.setLeatherPatch(bloodBodyPartTypex);
                                break;
                            default:
                                throw new MatchException(null, null);
                        }
                    }
 
                    clothing.addPatchForSync(bloodBodyPartTypeIdx, tailorLvl, fabricType, hasHole);
                }
            }
        }
    }
 
    void writeClothing(ByteBufferWriter b, int itemId) {
        IsoPlayer player = this.playerId.getPlayer();
        if (player == null) {
            b.putByte(0);
        } else {
            Clothing clothing = Type.tryCastTo(player.getInventory().getItemWithID(itemId), Clothing.class);
            if (clothing == null) {
                b.putByte(0);
            } else {
                b.putByte(clothing.getPatchesNumber());
 
                for (int i = 0; i < BloodBodyPartType.MAX.index(); i++) {
                    Clothing.ClothingPatch patch = clothing.getPatchType(BloodBodyPartType.FromIndex(i));
                    if (patch != null) {
                        b.putByte(i);
                        b.putByte(patch.tailorLvl);
                        b.putByte(patch.fabricType);
                        b.putBoolean(patch.hasHole);
                    }
                }
            }
        }
    }
 
    @Override
    public void parse(ByteBufferReader b, IConnection connection) {
        this.playerId.parse(b, connection);
        IsoPlayer player = this.playerId.getPlayer();
        if (player != null) {
            this.items.clear();
            byte size = b.getByte();
 
            for (int i = 0; i < size; i++) {
                SyncClothingPacket.ItemDescription item = new SyncClothingPacket.ItemDescription();
                item.parse(b, connection);
                this.items.add(item);
                this.parseClothing(b, item.itemId);
            }
        }
    }
 
    @Override
    public void write(ByteBufferWriter b) {
        this.playerId.write(b);
        b.putByte(this.items.size());
 
        for (SyncClothingPacket.ItemDescription item : this.items) {
            item.write(b);
            this.writeClothing(b, item.itemId);
        }
    }
 
    @Override
    public boolean isConsistent(IConnection connection) {
        return this.playerId.getPlayer() != null;
    }
 
    // PATCH: null-guard on item.location before .equals()
    private boolean isItemsContains(int itemId, ItemBodyLocation location) {
        if (location == null) {
            return false;
        }
        for (SyncClothingPacket.ItemDescription item : this.items) {
            if (item.itemId == itemId && item.location != null && item.location.equals(location)) {
                return true;
            }
        }
 
        return false;
    }
 
    private void process() {
        if (this.playerId.getPlayer().remote) {
            this.playerId.getPlayer().getItemVisuals().clear();
        }
 
        ArrayList<InventoryItem> itemsForDelete = new ArrayList<>();
        this.playerId.getPlayer().getWornItems().forEach(itemx -> {
            if (!this.isItemsContains(itemx.getItem().getID(), itemx.getLocation())) {
                itemsForDelete.add(itemx.getItem());
            }
        });
 
        for (InventoryItem item : itemsForDelete) {
            this.playerId.getPlayer().getWornItems().remove(item);
        }
 
        for (SyncClothingPacket.ItemDescription item : this.items) {
            // PATCH: skip items with null location (unresolved body location from registry)
            if (item.location == null) {
                continue;
            }
            Clothing wornItem = Type.tryCastTo(this.playerId.getPlayer().getWornItems().getItem(item.location), Clothing.class);
            int wornItemId = wornItem == null ? -1 : wornItem.getID();
            if (wornItemId != item.itemId) {
                InventoryItem itemForAdd = this.playerId.getPlayer().getInventory().getItemWithID(item.itemId);
                if (itemForAdd == null) {
                    itemForAdd = InventoryItemFactory.CreateItem(item.itemType);
                }
 
                if (itemForAdd != null) {
                    this.playerId.getPlayer().getWornItems().setItem(item.location, itemForAdd);
                    if (this.playerId.getPlayer().remote) {
                        itemForAdd.getVisual().setTint(item.tint);
                        itemForAdd.getVisual().setBaseTexture(item.baseTexture);
                        itemForAdd.getVisual().setTextureChoice(item.textureChoice);
                        this.playerId.getPlayer().getItemVisuals().add(itemForAdd.getVisual());
                    }
                }
            }
        }
    }
 
    @Override
    public void processClient(UdpConnection connection) {
        if (GameClient.client) {
            // PATCH: only apply the destructive delete-then-add process() on remote players.
            // The local player's worn items are authoritative — an echoed packet from the
            // server carries stale state and would delete items added since the original send.
            if (this.playerId.getPlayer().remote) {
                this.process();
            }
            this.playerId.getPlayer().onWornItemsChanged();
        }
 
        this.playerId.getPlayer().resetModelNextFrame();
        LuaEventManager.triggerEvent("OnClothingUpdated", this.playerId.getPlayer());
    }
 
    @Override
    public void processServer(PacketTypes.PacketType packetType, UdpConnection connection) {
        this.process();
        if (ServerGUI.isCreated()) {
            this.playerId.getPlayer().resetModelNextFrame();
        }
 
        // PATCH: exclude sender from relay. Original code passed null which echoed the
        // packet back to the sending client, causing stale state to overwrite newer items.
        // Every other packet (EquipPacket, GameCharacterAttachedItemPacket) correctly
        // passes the connection to exclude the sender.
        this.sendToClients(PacketTypes.PacketType.SyncClothing, connection);
    }
 
    static class ItemDescription implements INetworkPacket {
        @JSONField
        int itemId;
        @JSONField
        String itemType;
        @JSONField
        ItemBodyLocation location;
        @JSONField
        ImmutableColor tint;
        @JSONField
        int textureChoice;
        @JSONField
        int baseTexture;
 
        public ItemDescription() {
        }
 
        public ItemDescription(WornItem item) {
            this.itemId = item.getItem().getID();
            this.itemType = item.getItem().getFullType();
            this.location = item.getLocation();
            this.baseTexture = item.getItem().getVisual() == null ? -1 : item.getItem().getVisual().getBaseTexture();
            this.textureChoice = item.getItem().getVisual() == null ? -1 : item.getItem().getVisual().getTextureChoice();
            this.tint = item.getItem().getVisual().getTint();
        }
 
        @Override
        public void write(ByteBufferWriter b) {
            b.putInt(this.itemId);
            b.putUTF(this.itemType);
            b.putUTF(this.location.toString());
            b.putInt(this.textureChoice);
            b.putInt(this.baseTexture);
            b.putFloat(this.tint.r);
            b.putFloat(this.tint.g);
            b.putFloat(this.tint.b);
            b.putFloat(this.tint.a);
        }
 
        @Override
        public void parse(ByteBufferReader b, IConnection connection) {
            this.itemId = b.getInt();
            this.itemType = b.getUTF();
            // PATCH: ItemBodyLocation.get() returns null if the location string is not
            // registered in the registry. Store null and let process() skip it.
            String locationStr = b.getUTF();
            this.location = ItemBodyLocation.get(ResourceLocation.of(locationStr));
            this.textureChoice = b.getInt();
            this.baseTexture = b.getInt();
            this.tint = new ImmutableColor(b.getFloat(), b.getFloat(), b.getFloat(), b.getFloat());
        }
    }
}
JAVAEOF
 
echo "[3/5] Compiling patched class..."
"$JAVAC" -cp "$JAR_FILE" \
  "$WORK_DIR/src/zombie/network/packets/SyncClothingPacket.java" \
  -d "$WORK_DIR/build"
 
echo "[4/5] Injecting patched classes into JAR..."
cd "$WORK_DIR/build"
# SyncClothingPacket compiles to multiple .class files (inner classes)
"$JAR_CMD" -uf "$JAR_FILE" \
  zombie/network/packets/SyncClothingPacket.class \
  zombie/network/packets/SyncClothingPacket\$ItemDescription.class
 
echo "[5/5] Verifying..."
unzip -l "$JAR_FILE" | grep -E "SyncClothingPacket"
 
echo ""
echo "=== SyncClothingPacket Patch applied successfully! ==="
echo "Patched methods:"
echo "  - processServer(): excludes sender from relay (was sending stale echo to sender)"
echo "  - processClient(): skips destructive process() for local player (defense-in-depth)"
echo "  - isItemsContains(): null-guard on ItemBodyLocation"
echo "  - process(): skips items with null location"
echo "  - set(): skips worn items with null location"
echo "  - ItemDescription.parse(): tolerates unresolved body locations"
echo ""
echo "Restart the server to apply changes."
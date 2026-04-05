#!/bin/bash
# filepath: patchNullSafety.sh
# Patches BodyLocationGroup.java, WornItems.java, and SyncClothingPacket.java
# with null-safety guards and clothing desync fixes via classpath override.
#
# Null-Safety (BodyLocationGroup + WornItems):
#   getLocation() can return null for modded/unregistered clothing slots.
#   In the zombie death chain (Kill → DoZombieInventory → setFromItemVisuals),
#   an NPE prevents isOnKillDone/isOnDeathDone from being set, causing the server
#   to retry die() every tick in an infinite error loop.
#
# Clothing Desync (SyncClothingPacket):
#   processServer() echoes the packet back to the SENDING client (passes null to
#   sendToClients instead of excluding the sender). This self-echo carries stale
#   clothing state which overwrites items added between the original send and the
#   echo receipt, causing the "naked player" bug during bandaging/climbing/combat.
#
# Strategy: Instead of patching projectzomboid.jar directly, we leverage the
# classpath order defined in the server's JSON config:
#   "classpath": ["java/.", "java/projectzomboid.jar"]
# Since "java/." comes first, .class files placed under /opt/pzserver/java/
# with the correct package folder structure will be loaded BEFORE those in the JAR.
# This leaves the original JAR untouched and makes patches easy to add/remove.

set -e

PZ_DIR="/opt/pzserver"
JAR_FILE="$PZ_DIR/java/projectzomboid.jar"
CLASSPATH_DIR="$PZ_DIR/java"
JAVAC="/usr/lib/jvm/java-25-openjdk-amd64/bin/javac"
WORK_DIR="/tmp/pzpatch_nullsafety"
PATCH_WORN="$CLASSPATH_DIR/zombie/characters/WornItems"
PATCH_NET="$CLASSPATH_DIR/zombie/network/packets"

echo "=== PZ Classpath Override Patch ==="
echo "=== BodyLocationGroup + WornItems + SyncClothingPacket ==="

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
mkdir -p "$WORK_DIR/src/zombie/characters/WornItems"
mkdir -p "$WORK_DIR/src/zombie/network/packets"
mkdir -p "$WORK_DIR/build"

echo "[1/7] Writing patched BodyLocationGroup.java..."
cat > "$WORK_DIR/src/zombie/characters/WornItems/BodyLocationGroup.java" << 'JAVAEOF'
package zombie.characters.WornItems;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import zombie.UsedFromLua;
import zombie.scripting.objects.ItemBodyLocation;

@UsedFromLua
public class BodyLocationGroup {
    private final String id;
    private final List<BodyLocation> locations = new ArrayList<>();

    public BodyLocationGroup(String id) {
        if (id == null) {
            throw new NullPointerException("id is null");
        } else if (id.isEmpty()) {
            throw new IllegalArgumentException("id is empty");
        } else {
            this.id = id;
        }
    }

    public String getId() {
        return this.id;
    }

    public BodyLocation getLocation(ItemBodyLocation itemBodyLocation) {
        for (int i = 0; i < this.locations.size(); i++) {
            BodyLocation location = this.locations.get(i);
            if (location.isId(itemBodyLocation)) {
                return location;
            }
        }

        return null;
    }

    public BodyLocation getOrCreateLocation(ItemBodyLocation itemBodyLocation) {
        BodyLocation bodyLocation = this.getLocation(itemBodyLocation);
        if (bodyLocation == null) {
            bodyLocation = new BodyLocation(this, itemBodyLocation);
            this.locations.add(bodyLocation);
        }

        return bodyLocation;
    }

    public BodyLocation getLocationByIndex(int index) {
        return index >= 0 && index < this.size() ? this.locations.get(index) : null;
    }

    public void moveLocationToIndex(ItemBodyLocation itemBodyLocation, int index) {
        if (index >= 0 && index < this.size()) {
            for (int i = 0; i < this.locations.size(); i++) {
                BodyLocation location = this.locations.get(i);
                if (location.isId(itemBodyLocation)) {
                    this.locations.add(index, this.locations.remove(i));
                }
            }
        }
    }

    public int size() {
        return this.locations.size();
    }

    // PATCH: null-guard — both locations must resolve before setting exclusive
    public void setExclusive(ItemBodyLocation firstId, ItemBodyLocation secondId) {
        BodyLocation first = this.getLocation(firstId);
        BodyLocation second = this.getLocation(secondId);
        if (first == null || second == null) {
            return;
        }
        first.setExclusive(secondId);
        second.setExclusive(firstId);
    }

    // PATCH: null-guard — return false if location not found
    public boolean isExclusive(ItemBodyLocation firstId, ItemBodyLocation secondId) {
        BodyLocation first = this.getLocation(firstId);
        if (first == null) {
            return false;
        }
        return first.isExclusive(secondId);
    }

    // PATCH: null-guard — return early if location not found
    public void setHideModel(ItemBodyLocation firstId, ItemBodyLocation secondId) {
        BodyLocation first = this.getLocation(firstId);
        if (first == null) {
            return;
        }
        first.setHideModel(secondId);
    }

    // PATCH: null-guard — return false if location not found
    public boolean isHideModel(ItemBodyLocation firstId, ItemBodyLocation secondId) {
        BodyLocation first = this.getLocation(firstId);
        if (first == null) {
            return false;
        }
        return first.isHideModel(secondId);
    }

    // PATCH: null-guard — return early if location not found
    public void setAltModel(ItemBodyLocation firstId, ItemBodyLocation secondId) {
        BodyLocation first = this.getLocation(firstId);
        if (first == null) {
            return;
        }
        first.setAltModel(secondId);
    }

    // PATCH: null-guard — return false if location not found
    public boolean isAltModel(ItemBodyLocation firstId, ItemBodyLocation secondId) {
        BodyLocation first = this.getLocation(firstId);
        if (first == null) {
            return false;
        }
        return first.isAltModel(secondId);
    }

    public int indexOf(ItemBodyLocation locationId) {
        for (int i = 0; i < this.locations.size(); i++) {
            BodyLocation location = this.locations.get(i);
            if (location.isId(locationId)) {
                return i;
            }
        }

        return -1;
    }

    // PATCH: null-guard — return early if location not found
    public void setMultiItem(ItemBodyLocation locationId, boolean bMultiItem) {
        BodyLocation location = this.getLocation(locationId);
        if (location == null) {
            return;
        }
        location.setMultiItem(bMultiItem);
    }

    // PATCH: null-guard — return false if location not found (was line 119 NPE)
    public boolean isMultiItem(ItemBodyLocation locationId) {
        BodyLocation location = this.getLocation(locationId);
        if (location == null) {
            return false;
        }
        return location.isMultiItem();
    }

    public List<BodyLocation> getAllLocations() {
        return Collections.unmodifiableList(this.locations);
    }
}
JAVAEOF

echo "[2/7] Writing patched WornItems.java..."
cat > "$WORK_DIR/src/zombie/characters/WornItems/WornItems.java" << 'JAVAEOF'
package zombie.characters.WornItems;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import zombie.GameWindow;
import zombie.UsedFromLua;
import zombie.core.Color;
import zombie.core.ImmutableColor;
import zombie.core.skinnedmodel.visual.ItemVisual;
import zombie.core.skinnedmodel.visual.ItemVisuals;
import zombie.core.textures.Texture;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Clothing;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.scripting.objects.ResourceLocation;

@UsedFromLua
public final class WornItems {
    private final BodyLocationGroup group;
    private final List<WornItem> items = new ArrayList<>();

    public WornItems(BodyLocationGroup group) {
        this.group = group;
    }

    public WornItems(WornItems other) {
        this.group = other.group;
        this.copyFrom(other);
    }

    public void copyFrom(WornItems other) {
        if (this.group != other.group) {
            throw new RuntimeException("group=" + this.group.getId() + " other.group=" + other.group.getId());
        } else {
            this.items.clear();
            this.items.addAll(other.items);
        }
    }

    public BodyLocationGroup getBodyLocationGroup() {
        return this.group;
    }

    public WornItem get(int index) {
        return this.items.get(index);
    }

    public void setItem(ItemBodyLocation location, InventoryItem item) {
        // PATCH: null-guard on location parameter
        if (location == null) {
            return;
        }

        if (!this.group.isMultiItem(location)) {
            int index = this.indexOf(location);
            if (index != -1) {
                this.items.remove(index);
            }
        }

        for (int i = 0; i < this.items.size(); i++) {
            WornItem wornItem = this.items.get(i);
            // PATCH: null-guard on wornItem.getLocation() before exclusive check
            if (wornItem.getLocation() != null && this.group.isExclusive(location, wornItem.getLocation())) {
                this.items.remove(i--);
            }
        }

        if (item != null) {
            this.remove(item);
            int insertAt = this.items.size();

            for (int ix = 0; ix < this.items.size(); ix++) {
                WornItem wornItem1 = this.items.get(ix);
                // PATCH: null-guard on wornItem.getLocation() before indexOf comparison
                if (wornItem1.getLocation() != null && this.group.indexOf(wornItem1.getLocation()) > this.group.indexOf(location)) {
                    insertAt = ix;
                    break;
                }
            }

            WornItem wornItem = new WornItem(location, item);
            this.items.add(insertAt, wornItem);
        }
    }

    public InventoryItem getItem(ItemBodyLocation location) {
        int index = this.indexOf(location);
        return index == -1 ? null : this.items.get(index).getItem();
    }

    public InventoryItem getItemByIndex(int index) {
        return index >= 0 && index < this.items.size() ? this.items.get(index).getItem() : null;
    }

    public void remove(InventoryItem item) {
        int index = this.indexOf(item);
        if (index != -1) {
            this.items.remove(index);
        }
    }

    public void clear() {
        this.items.clear();
    }

    public ItemBodyLocation getLocation(InventoryItem item) {
        int index = this.indexOf(item);
        return index == -1 ? null : this.items.get(index).getLocation();
    }

    public boolean contains(InventoryItem item) {
        return this.indexOf(item) != -1;
    }

    public int size() {
        return this.items.size();
    }

    public boolean isEmpty() {
        return this.items.isEmpty();
    }

    public void forEach(Consumer<WornItem> c) {
        for (int i = 0; i < this.items.size(); i++) {
            c.accept(this.items.get(i));
        }
    }

    public void setFromItemVisuals(ItemVisuals itemVisuals) {
        this.clear();

        for (int i = 0; i < itemVisuals.size(); i++) {
            ItemVisual itemVisual = itemVisuals.get(i);
            String itemType = itemVisual.getItemType();
            InventoryItem item = InventoryItemFactory.CreateItem(itemType);
            if (item != null) {
                if (item.getVisual() != null) {
                    item.getVisual().copyFrom(itemVisual);
                    item.synchWithVisual();
                }

                // PATCH: resolve body location first and null-check before calling setItem
                ItemBodyLocation bodyLoc;
                if (item instanceof Clothing) {
                    bodyLoc = item.getBodyLocation();
                } else {
                    bodyLoc = item.canBeEquipped();
                }

                if (bodyLoc != null) {
                    this.setItem(bodyLoc, item);
                }
            }
        }
    }

    public void getItemVisuals(ItemVisuals itemVisuals) {
        itemVisuals.clear();

        for (int i = 0; i < this.items.size(); i++) {
            InventoryItem item = this.items.get(i).getItem();
            ItemVisual itemVisual = item.getVisual();
            if (itemVisual != null) {
                itemVisual.setInventoryItem(item);
                itemVisuals.add(itemVisual);
            }
        }
    }

    public void addItemsToItemContainer(ItemContainer container) {
        for (int i = 0; i < this.items.size(); i++) {
            InventoryItem item = this.items.get(i).getItem();
            int totalHoles = item.getVisual().getHolesNumber();
            item.setConditionNoSound(item.getConditionMax() - totalHoles * 3);
            container.AddItem(item);
        }
    }

    private int indexOf(ItemBodyLocation location) {
        // PATCH: null-guard on location parameter
        if (location == null) {
            return -1;
        }

        for (int i = 0; i < this.items.size(); i++) {
            WornItem item = this.items.get(i);
            // PATCH: null-guard on item.getLocation() before .equals()
            if (item.getLocation() != null && item.getLocation().equals(location)) {
                return i;
            }
        }

        return -1;
    }

    private int indexOf(InventoryItem item) {
        for (int i = 0; i < this.items.size(); i++) {
            WornItem wornItem = this.items.get(i);
            if (wornItem.getItem() == item) {
                return i;
            }
        }

        return -1;
    }

    public void save(ByteBuffer output) throws IOException {
        // PATCH: count only items with non-null location for the size header
        short validCount = 0;
        for (int i = 0; i < this.items.size(); i++) {
            if (this.items.get(i).getLocation() != null) {
                validCount++;
            }
        }
        output.putShort(validCount);

        for (int i = 0; i < this.items.size(); i++) {
            WornItem wornItem = this.items.get(i);
            // PATCH: skip items with null location during save
            if (wornItem.getLocation() == null) {
                continue;
            }
            GameWindow.WriteString(output, wornItem.getLocation().toString());
            GameWindow.WriteString(output, wornItem.getItem().getType());
            GameWindow.WriteString(output, wornItem.getItem().getTex().getName());
            wornItem.getItem().col.save(output);
            output.putInt(wornItem.getItem().getVisual().getBaseTexture());
            output.putInt(wornItem.getItem().getVisual().getTextureChoice());
            ImmutableColor colorTint = wornItem.getItem().getVisual().getTint();
            output.putFloat(colorTint.r);
            output.putFloat(colorTint.g);
            output.putFloat(colorTint.b);
            output.putFloat(colorTint.a);
        }
    }

    public void load(ByteBuffer input, int worldVersion) throws IOException {
        short size = input.getShort();
        this.items.clear();

        for (int i = 0; i < size; i++) {
            String location = GameWindow.ReadString(input);
            String type = GameWindow.ReadString(input);
            String tex = GameWindow.ReadString(input);
            Color color = new Color();
            color.load(input, worldVersion);
            int baseTexture = input.getInt();
            int textureChoice = input.getInt();
            ImmutableColor colorTint = new ImmutableColor(input.getFloat(), input.getFloat(), input.getFloat(), input.getFloat());
            InventoryItem item = InventoryItemFactory.CreateItem(type);
            if (item != null) {
                item.setTexture(Texture.trygetTexture(tex));
                if (item.getTex() == null) {
                    item.setTexture(Texture.getSharedTexture("media/inventory/Question_On.png"));
                }

                String worldTexture = tex.replace("Item_", "media/inventory/world/WItem_");
                worldTexture = worldTexture + ".png";
                item.setWorldTexture(worldTexture);
                item.setColor(color);
                item.getVisual().tint = new ImmutableColor(color);
                item.getVisual().setBaseTexture(baseTexture);
                item.getVisual().setTextureChoice(textureChoice);
                item.getVisual().setTint(colorTint);
                // PATCH: null-guard on resolved body location before adding
                ItemBodyLocation bodyLoc = ItemBodyLocation.get(ResourceLocation.of(location));
                if (bodyLoc != null) {
                    this.items.add(new WornItem(bodyLoc, item));
                }
            }
        }
    }
}
JAVAEOF

echo "[3/7] Writing patched SyncClothingPacket.java..."
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

echo "[4/7] Compiling patched classes..."
"$JAVAC" -cp "$JAR_FILE" \
  "$WORK_DIR/src/zombie/characters/WornItems/BodyLocationGroup.java" \
  "$WORK_DIR/src/zombie/characters/WornItems/WornItems.java" \
  "$WORK_DIR/src/zombie/network/packets/SyncClothingPacket.java" \
  -d "$WORK_DIR/build"

echo "[5/7] Deploying classes to classpath override directory..."
mkdir -p "$PATCH_WORN"
mkdir -p "$PATCH_NET"
cp "$WORK_DIR/build/zombie/characters/WornItems/BodyLocationGroup.class" "$PATCH_WORN/"
cp "$WORK_DIR/build/zombie/characters/WornItems/WornItems.class" "$PATCH_WORN/"
# SyncClothingPacket compiles to multiple .class files (inner class ItemDescription)
cp "$WORK_DIR/build/zombie/network/packets/SyncClothingPacket.class" "$PATCH_NET/"
cp "$WORK_DIR/build/zombie/network/packets/SyncClothingPacket\$ItemDescription.class" "$PATCH_NET/"

echo "[6/7] Verifying deployment..."
echo "  Checking classpath override files:"
ls -la "$PATCH_WORN/BodyLocationGroup.class"
ls -la "$PATCH_WORN/WornItems.class"
ls -la "$PATCH_NET/SyncClothingPacket.class"
ls -la "$PATCH_NET/SyncClothingPacket\$ItemDescription.class"

echo ""
echo "  Checking classpath config has 'java/.' before JAR:"
grep -A5 '"classpath"' "$PZ_DIR/ProjectZomboid64.json" 2>/dev/null || \
grep -A5 '"classpath"' "$PZ_DIR/ProjectZomboidServer.json" 2>/dev/null || \
echo "  WARNING: Could not find server JSON config to verify classpath order."

echo ""
echo "[7/7] Cleanup..."
rm -rf "$WORK_DIR"

echo ""
echo "=== Classpath Override Patch deployed successfully ==="
echo ""
echo "How it works:"
echo "  The server config classpath is: [\"java/.\", \"java/projectzomboid.jar\"]"
echo "  Since 'java/.' is listed first, the JVM loads .class files from the"
echo "  filesystem before looking inside the JAR. The original JAR is untouched."
echo ""
echo "Patched classes deployed to:"
echo "  $PATCH_WORN/"
echo "    - BodyLocationGroup.class (isMultiItem, isExclusive, setExclusive, isHideModel, setHideModel, isAltModel, setAltModel, setMultiItem)"
echo "    - WornItems.class (setItem, indexOf, setFromItemVisuals, save, load)"
echo "  $PATCH_NET/"
echo "    - SyncClothingPacket.class (processServer: exclude sender, processClient: skip local, null-safety guards)"
echo "    - SyncClothingPacket\$ItemDescription.class (parse: tolerate unresolved locations)"
echo ""
echo "To remove all patches:"
echo "  rm -rf $CLASSPATH_DIR/zombie/"
echo ""
echo "Restart the server to apply changes."

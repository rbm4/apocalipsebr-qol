#!/bin/bash
# filepath: patchNullSafety.sh
# Patches BodyLocationGroup.java and WornItems.java with null-safety guards
# to prevent NPE infinite loop when zombies die with unregistered body locations.
#
# Root cause: getLocation() can return null for modded/unregistered clothing slots.
# In the zombie death chain (Kill → DoZombieInventory → setFromItemVisuals),
# an NPE prevents isOnKillDone/isOnDeathDone from being set, causing the server
# to retry die() every tick in an infinite error loop.

set -e

JAR_FILE="/opt/pzserver/java/projectzomboid.jar"
JAVAC="/usr/lib/jvm/java-25-openjdk-amd64/bin/javac"
JAR_CMD="/usr/lib/jvm/java-25-openjdk-amd64/bin/jar"
WORK_DIR="/tmp/pzpatch_nullsafety"

echo "=== PZ Null-Safety Patch (BodyLocationGroup + WornItems) ==="

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
mkdir -p "$WORK_DIR/build"

echo "[1/6] Creating backup..."
cp -n "$JAR_FILE" "${JAR_FILE}.bak" 2>/dev/null || echo "  Backup already exists, skipping."

echo "[2/6] Writing patched BodyLocationGroup.java..."
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

echo "[3/6] Writing patched WornItems.java..."
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

echo "[4/6] Compiling patched classes..."
"$JAVAC" -cp "$JAR_FILE" \
  "$WORK_DIR/src/zombie/characters/WornItems/BodyLocationGroup.java" \
  "$WORK_DIR/src/zombie/characters/WornItems/WornItems.java" \
  -d "$WORK_DIR/build"

echo "[5/6] Injecting patched classes into JAR..."
cd "$WORK_DIR/build"
"$JAR_CMD" -uf "$JAR_FILE" \
  zombie/characters/WornItems/BodyLocationGroup.class \
  zombie/characters/WornItems/WornItems.class

echo "[6/6] Verifying..."
unzip -l "$JAR_FILE" | grep -E "(BodyLocationGroup|WornItems)\.class"

echo ""
echo "=== Null-Safety Patch applied successfully! ==="
echo "Patched classes:"
echo "  - BodyLocationGroup.java (isMultiItem, isExclusive, setExclusive, isHideModel, setHideModel, isAltModel, setAltModel, setMultiItem)"
echo "  - WornItems.java (setItem, indexOf, setFromItemVisuals, save, load)"
echo ""
echo "Restart the server to apply changes."
echo "Make sure the patched .jar file has the correct execution permissions."

package com.apocalipsebr.tools.mapconverter;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;

import com.apocalipsebr.tools.mapconverter.ConvertMap.LotHeaderData;
import com.apocalipsebr.tools.mapconverter.ConvertMap.LotPackData;
import com.apocalipsebr.tools.mapconverter.ConvertMap.MetaObject;
import com.apocalipsebr.tools.mapconverter.ConvertMap.RoomDef;
import com.apocalipsebr.tools.mapconverter.ConvertMap.RoomRect;

/**
 * Decompiles a single PZ map cell (.lotheader + .lotpack) back into a TileZed/WorldEd
 * TMX map: tile layers per (level × role) + RoomDefs object groups.
 *
 * Output TMX uses orientation=LevelIsometric, tilewidth=64, tileheight=32, which
 * matches what WorldEd ships as the PZ template.
 */
public class LotToTMX {

    /** How many native FloorOverlay slots we allow before dropping. Vanilla B42 reaches FloorOverlay14. */
    private static final int MAX_OVERLAY_SLOTS = 16;

    /** Tile sprite native size in tileset (1x): 64×128 — PZ convention. */
    private static final int SPRITE_W = 64;
    private static final int SPRITE_H = 128;

    /** How to encode room/building objects for the next consumer. */
    public enum RoomObjectMode {
        /** Native B42 WorldEd/GenerateLots RoomDefs use pixel rectangles and TBX-like type paths. */
        GENERATE_LOTS,
        /** Alias for native B42 editor-visible RoomDefs. */
        EDITOR
    }

    /** Reference into a tileset for emitting <tileset> elements. */
    private static class TilesetSlot {
        final TilesetIndex.TilesetMeta meta;
        final int firstGid;
        TilesetSlot(TilesetIndex.TilesetMeta meta, int firstGid) {
            this.meta = meta;
            this.firstGid = firstGid;
        }
    }

    /** One key per (level, role, slotIdx). Stored gids in row-major width×height grid. */
    private static class LayerKey {
        final int    level;
        final String role;
        final int    slot; // For FloorOverlay: 0 = base, 1 = "1", 2 = "2", ...

        LayerKey(int level, String role, int slot) {
            this.level = level; this.role = role; this.slot = slot;
        }
        String name() {
            return role + (slot == 0 ? "" : String.valueOf(slot));
        }
        @Override public boolean equals(Object o) {
            if (!(o instanceof LayerKey)) return false;
            LayerKey k = (LayerKey) o;
            return level == k.level && slot == k.slot && role.equals(k.role);
        }
        @Override public int hashCode() {
            return Objects.hash(level, role, slot);
        }
    }

    /**
     * Decompile a single cell to a TMX file.
     *
     * @param hdr     parsed lotheader (from ConvertMap.loadLotHeader)
     * @param pack    parsed lotpack   (from ConvertMap.loadLotPack)
     * @param idx     tileset index (from TilesetIndex.load)
     * @param outFile destination .tmx file
     * @param tilePathPrefix relative path prefix for <image source=...> e.g. "../../Tiles/"
     * @return diagnostic summary
     */
    public static String decompileCell(LotHeaderData hdr, LotPackData pack,
                                       TilesetIndex idx, File outFile,
                                       String tilePathPrefix) throws IOException {
        return decompileCell(hdr, pack, idx, outFile, tilePathPrefix, RoomObjectMode.GENERATE_LOTS);
    }

    public static String decompileCell(LotHeaderData hdr, LotPackData pack,
                                       TilesetIndex idx, File outFile,
                                       String tilePathPrefix,
                                       RoomObjectMode roomObjectMode) throws IOException {
        final int cellDim = hdr.cellDim;
        final int minZ = hdr.minLevelNotEmpty;
        final int maxZ = hdr.maxLevelNotEmpty;

        // tilesetName -> slot (firstGid assigned in encounter order)
        Map<String, TilesetSlot> tilesetSlots = new LinkedHashMap<>();
        int nextFirstGid = 1;

        // layerKey -> int[cellDim*cellDim] of gids
        Map<LayerKey, int[]> layerGrids = new LinkedHashMap<>();

        // Track unknown sprite names for diagnostics
        Set<String> unknown = new TreeSet<>();
        long totalTiles = 0, placedTiles = 0, droppedTiles = 0;

        for (int z = minZ; z <= maxZ; z++) {
            for (int y = 0; y < cellDim; y++) {
                for (int x = 0; x < cellDim; x++) {
                    int wx = hdr.getMinSquareX() + x;
                    int wy = hdr.getMinSquareY() + y;
                    String[] tiles = pack.getSquareData(wx, wy, z);
                    if (tiles == null) continue;

                    for (String spriteName : tiles) {
                        if (spriteName == null || spriteName.isEmpty()) continue;
                        totalTiles++;

                        TilesetIndex.TileRef ref = idx.lookup(spriteName);
                        if (ref == null) {
                            unknown.add(spriteName);
                            droppedTiles++;
                            continue;
                        }

                        TilesetSlot ts = tilesetSlots.get(ref.tileset);
                        if (ts == null) {
                            TilesetIndex.TilesetMeta meta = idx.meta(ref.tileset);
                            if (meta == null) { droppedTiles++; continue; }
                            ts = new TilesetSlot(meta, nextFirstGid);
                            tilesetSlots.put(ref.tileset, ts);
                            nextFirstGid += meta.tileCount();
                        }
                        int gid = ts.firstGid + ref.localId;

                        // Native B42 WorldEd uses only Floor, Vegetation, and FloorOverlay* layers.
                        LayerRouter.Role role = LayerRouter.routeOf(spriteName);
                        boolean placed = false;
                        if (role == LayerRouter.Role.FLOOR) {
                            placed = tryPlace(layerGrids, new LayerKey(z, "Floor", 0), cellDim, x, y, gid);
                        } else if (role == LayerRouter.Role.VEGETATION) {
                            placed = tryPlace(layerGrids, new LayerKey(z, "Vegetation", 0), cellDim, x, y, gid);
                        }
                        if (!placed) {
                            placed = tryPlaceOverlay(layerGrids, z, cellDim, x, y, gid);
                        }
                        if (placed) {
                            placedTiles++;
                        }
                        if (!placed) droppedTiles++;
                    }
                }
            }
        }

        // ============== Emit TMX ==============
        try (Writer w = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(outFile), StandardCharsets.UTF_8))) {

            w.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
            w.write("<map version=\"2.0\" orientation=\"levelisometric\" width=\"" + cellDim +
                    "\" height=\"" + cellDim +
                    "\" tilewidth=\"64\" tileheight=\"32\">\n");

            // Tilesets in encounter order
            for (TilesetSlot ts : tilesetSlots.values()) {
                int imgW = ts.meta.cols * SPRITE_W;
                int imgH = ts.meta.rows * SPRITE_H;
                w.write(" <tileset firstgid=\"" + ts.firstGid + "\" name=\"" + xmlAttr(ts.meta.name) +
                        "\" tilewidth=\"" + SPRITE_W + "\" tileheight=\"" + SPRITE_H + "\">\n");
                w.write("  <image source=\"" + xmlAttr(tilePathPrefix + ts.meta.name + ".png") +
                        "\" width=\"" + imgW + "\" height=\"" + imgH + "\"/>\n");
                w.write(" </tileset>\n");
            }

            // Tile layers (skip empty)
            for (Map.Entry<LayerKey, int[]> e : layerGrids.entrySet()) {
                int[] grid = e.getValue();
                if (allZero(grid)) continue;
                LayerKey k = e.getKey();
                w.write(" <layer name=\"" + k.name() + "\" level=\"" + k.level + "\" width=\"" + cellDim +
                        "\" height=\"" + cellDim + "\">\n");
                w.write("  <data encoding=\"csv\">\n");
                writeCsvLayerData(w, grid, cellDim);
                w.write("\n  </data>\n");
                w.write(" </layer>\n");
            }

            // RoomDefs object groups per level
            for (int z = minZ; z <= maxZ; z++) {
                List<RoomDef> roomsAtLevel = new ArrayList<>();
                for (RoomDef rd : hdr.roomList) {
                    if (rd.level == z) roomsAtLevel.add(rd);
                }
                if (roomsAtLevel.isEmpty()) continue;

                w.write(" <objectgroup name=\"RoomDefs\" level=\"" + z +
                        "\" width=\"" + cellDim + "\" height=\"" + cellDim + "\">\n");
                for (RoomDef rd : roomsAtLevel) {
                    for (int ri = 0; ri < rd.rects.size(); ri++) {
                        RoomRect rect = rd.rects.get(ri);
                        // Rects in loadLotHeader are stored as absolute world coords; convert to cell-relative
                        int relX = rect.x - hdr.getMinSquareX();
                        int relY = rect.y - hdr.getMinSquareY();
                        int clipX1 = Math.max(0, relX);
                        int clipY1 = Math.max(0, relY);
                        int clipX2 = Math.min(cellDim, relX + rect.w);
                        int clipY2 = Math.min(cellDim, relY + rect.h);
                        if (clipX1 >= clipX2 || clipY1 >= clipY2) continue;
                        int[] objRect = toObjectRect(clipX1, clipY1, clipX2 - clipX1, clipY2 - clipY1, roomObjectMode);
                        String typePath = roomTypePath(hdr, z, rd.name, clipX1, clipY1, ri);
                        w.write("  <object name=\"" + xmlAttr(rd.name) +
                                "\" type=\"" + xmlAttr(typePath) + "\" x=\"" + objRect[0] + "\" y=\"" + objRect[1] +
                                "\" width=\"" + objRect[2] + "\" height=\"" + objRect[3] + "\"/>\n");
                    }
                }
                w.write(" </objectgroup>\n");
            }

            w.write("</map>\n");
        }

        StringBuilder summary = new StringBuilder();
        summary.append("cell ").append(hdr.cellX).append("_").append(hdr.cellY)
               .append(": tiles=").append(totalTiles)
               .append(" placed=").append(placedTiles)
               .append(" dropped=").append(droppedTiles)
               .append(" rooms=").append(hdr.roomList.size())
               .append(" buildings=").append(hdr.buildings.size())
               .append(" tilesets=").append(tilesetSlots.size())
               .append(" roomMode=").append(roomObjectMode)
               .append(" zRange=").append(minZ).append("..").append(maxZ);
        if (!unknown.isEmpty()) {
            summary.append("\n  unknown sprite samples: ");
            int n = 0;
            for (String s : unknown) {
                if (n++ >= 5) { summary.append("…(+" + (unknown.size() - 5) + ")"); break; }
                summary.append(s).append(' ');
            }
        }
        return summary.toString();
    }

    // ============ helpers ============

    private static boolean tryPlaceOverlay(Map<LayerKey, int[]> layerGrids, int level,
                                           int cellDim, int x, int y, int gid) {
        for (int slot = 0; slot < MAX_OVERLAY_SLOTS; slot++) {
            if (tryPlace(layerGrids, new LayerKey(level, "FloorOverlay", slot), cellDim, x, y, gid)) {
                return true;
            }
        }
        return false;
    }

    private static boolean tryPlace(Map<LayerKey, int[]> layerGrids, LayerKey key,
                                    int cellDim, int x, int y, int gid) {
        int[] grid = layerGrids.get(key);
        if (grid == null) {
            grid = new int[cellDim * cellDim];
            layerGrids.put(key, grid);
        }
        int idxFlat = y * cellDim + x;
        if (grid[idxFlat] != 0) return false;
        grid[idxFlat] = gid;
        return true;
    }

    private static boolean allZero(int[] g) {
        for (int v : g) if (v != 0) return false;
        return true;
    }

    /** Write editor-native CSV layer data in row-major order. */
    private static void writeCsvLayerData(Writer w, int[] grid, int width) throws IOException {
        for (int i = 0; i < grid.length; i++) {
            if (i > 0) w.write(',');
            w.write(Integer.toString(grid[i]));
            if ((i + 1) % width == 0) w.write('\n');
        }
    }

    private static int[] toObjectRect(int x, int y, int w, int h, RoomObjectMode mode) {
        return new int[] { x * 64, y * 32, w * 64, h * 32 };
    }

    private static String roomTypePath(LotHeaderData hdr, int level, String roomName, int tileX, int tileY, int index) {
        return ".\\tbx\\" + hdr.cellX + "_" + hdr.cellY + "\\" +
                hdr.cellX + "_" + hdr.cellY + "_" + level + "_" +
                safePathPart(roomName) + "_" + tileX + "_" + tileY + "_" + index + ".tbx";
    }

    private static String safePathPart(String s) {
        if (s == null || s.isEmpty()) return "room";
        String out = s.replaceAll("[^A-Za-z0-9_-]+", "_");
        return out.isEmpty() ? "room" : out;
    }

    private static String xmlAttr(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;");
    }
}

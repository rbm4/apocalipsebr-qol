package com.apocalipsebr.tools.mapconverter;

import java.io.BufferedWriter;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;
import java.util.zip.Deflater;

import com.apocalipsebr.tools.mapconverter.ConvertMap.BuildingDef;
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

    /** How many overlay slots per role we allow before dropping (e.g. FloorOverlay4). */
    private static final int MAX_OVERLAY_SLOTS = 4;

    /** Tile sprite native size in tileset (1x): 64×128 — PZ convention. */
    private static final int SPRITE_W = 64;
    private static final int SPRITE_H = 128;

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
        final int    slot; // 0 = base, 1 = "2", 2 = "3", ...

        LayerKey(int level, String role, int slot) {
            this.level = level; this.role = role; this.slot = slot;
        }
        String name() {
            return level + "_" + role + (slot == 0 ? "" : String.valueOf(slot + 1));
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

                        // Route to a layer; if base slot is taken, climb to slot 2..N
                        LayerRouter.Role role = LayerRouter.routeOf(spriteName);
                        String roleStr = role.suffix;
                        boolean placed = false;
                        for (int slot = 0; slot < MAX_OVERLAY_SLOTS; slot++) {
                            LayerKey key = new LayerKey(z, roleStr, slot);
                            int[] grid = layerGrids.get(key);
                            if (grid == null) {
                                grid = new int[cellDim * cellDim];
                                layerGrids.put(key, grid);
                            }
                            int idxFlat = y * cellDim + x;
                            if (grid[idxFlat] == 0) {
                                grid[idxFlat] = gid;
                                placed = true;
                                placedTiles++;
                                break;
                            }
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
            w.write("<map version=\"1.0\" orientation=\"levelisometric\" width=\"" + cellDim +
                    "\" height=\"" + cellDim +
                    "\" tilewidth=\"64\" tileheight=\"32\">\n");

            // Map-level properties: zombie density bytes
            w.write(" <properties>\n");
            for (int cy = 0; cy < hdr.chunksPerCell; cy++) {
                for (int cx = 0; cx < hdr.chunksPerCell; cx++) {
                    int v = hdr.zombieDensity[cx + cy * hdr.chunksPerCell] & 0xFF;
                    if (v != 0) {
                        w.write("  <property name=\"ZombieDensity_" + cx + "_" + cy +
                                "\" value=\"" + v + "\"/>\n");
                    }
                }
            }
            w.write("  <property name=\"CellX\" value=\"" + hdr.cellX + "\"/>\n");
            w.write("  <property name=\"CellY\" value=\"" + hdr.cellY + "\"/>\n");
            w.write(" </properties>\n");

            // Tilesets in encounter order
            for (TilesetSlot ts : tilesetSlots.values()) {
                int imgW = ts.meta.cols * SPRITE_W;
                int imgH = ts.meta.rows * SPRITE_H;
                w.write(" <tileset firstgid=\"" + ts.firstGid + "\" name=\"" + ts.meta.name +
                        "\" tilewidth=\"" + SPRITE_W + "\" tileheight=\"" + SPRITE_H +
                        "\" tilecount=\"" + ts.meta.tileCount() +
                        "\" columns=\"" + ts.meta.cols + "\">\n");
                w.write("  <image source=\"" + xmlAttr(tilePathPrefix + ts.meta.name + ".png") +
                        "\" width=\"" + imgW + "\" height=\"" + imgH + "\"/>\n");
                w.write(" </tileset>\n");
            }

            // Tile layers (skip empty)
            for (Map.Entry<LayerKey, int[]> e : layerGrids.entrySet()) {
                int[] grid = e.getValue();
                if (allZero(grid)) continue;
                LayerKey k = e.getKey();
                w.write(" <layer name=\"" + k.name() + "\" width=\"" + cellDim +
                        "\" height=\"" + cellDim + "\">\n");
                w.write("  <data encoding=\"base64\" compression=\"zlib\">\n   ");
                w.write(encodeLayerData(grid));
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

                w.write(" <objectgroup name=\"" + z + "_RoomDefs\" color=\"#aa0000\">\n");
                for (RoomDef rd : roomsAtLevel) {
                    for (int ri = 0; ri < rd.rects.size(); ri++) {
                        RoomRect rect = rd.rects.get(ri);
                        // Rects in loadLotHeader are stored as absolute world coords; convert to cell-relative
                        int relX = rect.x - hdr.getMinSquareX();
                        int relY = rect.y - hdr.getMinSquareY();
                        w.write("  <object name=\"" + xmlAttr(rd.name) +
                                "\" type=\"room\" x=\"" + relX + "\" y=\"" + relY +
                                "\" width=\"" + rect.w + "\" height=\"" + rect.h + "\">\n");
                        w.write("   <properties>\n");
                        w.write("    <property name=\"RoomID\" value=\"" + rd.id + "\"/>\n");
                        w.write("    <property name=\"RoomName\" value=\"" + xmlAttr(rd.name) + "\"/>\n");
                        w.write("    <property name=\"RoomLevel\" value=\"" + rd.level + "\"/>\n");
                        if (ri == 0 && !rd.objects.isEmpty()) {
                            w.write("    <property name=\"MetaObjectCount\" value=\"" + rd.objects.size() + "\"/>\n");
                            int oi = 0;
                            for (MetaObject mo : rd.objects) {
                                w.write("    <property name=\"MetaObject_" + oi + "\" value=\"" +
                                        mo.type + "," + mo.x + "," + mo.y + "\"/>\n");
                                oi++;
                            }
                        }
                        w.write("   </properties>\n");
                        w.write("  </object>\n");
                    }
                }
                w.write(" </objectgroup>\n");
            }

            // Buildings object group (level 0 holds the building summary)
            if (!hdr.buildings.isEmpty()) {
                w.write(" <objectgroup name=\"0_Buildings\" color=\"#ffaa00\" visible=\"0\">\n");
                int bi = 0;
                for (BuildingDef bd : hdr.buildings) {
                    int relX = bd.x  - hdr.getMinSquareX();
                    int relY = bd.y  - hdr.getMinSquareY();
                    int relW = bd.x2 - bd.x;
                    int relH = bd.y2 - bd.y;
                    w.write("  <object name=\"building_" + bi + "\" type=\"building\" x=\"" + relX +
                            "\" y=\"" + relY + "\" width=\"" + relW + "\" height=\"" + relH + "\">\n");
                    w.write("   <properties>\n");
                    w.write("    <property name=\"BuildingID\" value=\"" + bd.id + "\"/>\n");
                    w.write("    <property name=\"RoomCount\" value=\"" + bd.rooms.size() + "\"/>\n");
                    w.write("   </properties>\n");
                    w.write("  </object>\n");
                    bi++;
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

    private static boolean allZero(int[] g) {
        for (int v : g) if (v != 0) return false;
        return true;
    }

    /** Encode an int[] grid (gids) as little-endian, zlib-compress, then base64. */
    private static String encodeLayerData(int[] grid) throws IOException {
        ByteBuffer bb = ByteBuffer.allocate(grid.length * 4).order(ByteOrder.LITTLE_ENDIAN);
        for (int v : grid) bb.putInt(v);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Deflater def = new Deflater(Deflater.BEST_COMPRESSION);
        def.setInput(bb.array());
        def.finish();
        byte[] buf = new byte[8192];
        while (!def.finished()) {
            int n = def.deflate(buf);
            baos.write(buf, 0, n);
        }
        def.end();
        return Base64.getEncoder().encodeToString(baos.toByteArray());
    }

    private static String xmlAttr(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;");
    }
}

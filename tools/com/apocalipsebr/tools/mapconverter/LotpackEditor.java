package com.apocalipsebr.tools.mapconverter;

import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * LotpackEditor — Inspect and edit individual tile objects in B42 .lotpack files.
 *
 * B42 cell layout:
 *   32×32 chunks, each chunk 8×8 tiles = 256×256 tiles per cell.
 *   .lotheader: string table of tile sprite names + rooms/buildings/zombieDensity.
 *   .lotpack: per-square tile indices referencing the lotheader string table.
 *
 * Commands:
 *   --inspect    &lt;mapDir&gt; &lt;cellX_cellY&gt; [chunkX,chunkY]
 *   --inspect-at &lt;mapDir&gt; &lt;worldX&gt; &lt;worldY&gt; &lt;z&gt;
 *   --search     &lt;mapDir&gt; &lt;cellX_cellY&gt; &lt;tileName&gt;
 *   --remove     &lt;mapDir&gt; &lt;worldX&gt; &lt;worldY&gt; &lt;z&gt; &lt;tileName&gt;
 *   --set        &lt;mapDir&gt; &lt;worldX&gt; &lt;worldY&gt; &lt;z&gt; &lt;oldTile&gt; &lt;newTile&gt;
 *   --add        &lt;mapDir&gt; &lt;worldX&gt; &lt;worldY&gt; &lt;z&gt; &lt;tileName&gt;
 *   --patch      <mapDir> <patchFile.csv> [worldmap.xml]
 *
 * Patch CSV actions: add, remove, set, removeAllRange, addAllRange, removeAllBut
 *   removeAllRange: x1, y1, z1, x2, y2, z2 — clears ALL objects in the 3D box.
 *   addAllRange:    x1, y1, z1, x2, y2, z2, tileName — adds a tile to every square in the 3D box.
 *   removeAllBut:   x, y, z, tileName — removes all objects EXCEPT the named tile.
 *
 * Patch CSV directives: legacy @ directives are now ignored.
 *
 * Worldmap sync (when worldmap.xml path is provided):
 *   Road polygons: any 'add' at z=0 of tile 'blends_street_01_85' emits a
 *   tertiary highway polygon in worldmap.xml.
 *   Polygon clipping: when removeAllRange clears tile objects, any overlapping
 * polygon features (forest, vegetation, buildings, etc.) in worldmap.xml are
 * automatically clipped via Sutherland-Hodgman algorithm so tile graphics render.
 *
 * World coordinates are absolute tile positions (use -debug tile inspector in-game).
 * Cell is auto-derived: cellX = worldX / 256, cellY = worldY / 256.
 */
public class LotpackEditor {

    static final int CHUNK_DIM = 8;
    static final int CHUNKS_PER_CELL = 32;
    static final int CELL_DIM = 256; // CHUNK_DIM * CHUNKS_PER_CELL
    static final int XML_CELL_DIM = 300; // worldmap.xml uses 300-unit cells

    /** Tile name that triggers road polygon injection in worldmap.xml */
    static final String ROAD_TILE = "blends_street_01_85";
    /** Highway type emitted for road polygons */
    static final String ROAD_HIGHWAY = "tertiary";

    static final byte[] LOTH_MAGIC = { 'L', 'O', 'T', 'H' };
    static final byte[] LOTP_MAGIC = { 'L', 'O', 'T', 'P' };

    /** Files backed up during the current patch run (for undo). */
    static final Set<File> backedUpFiles = new LinkedHashSet<>();

    // ========================== Cell Data ==========================

    /**
     * In-memory representation of a cell: lotheader string table + lotpack tile data.
     *
     * Tile data is stored per-square in a HashMap keyed by squareIdx:
     *   squareIdx = relX + relY * CELL_DIM + (z - minLevel) * CELL_DIM * CELL_DIM
     * where relX/relY are cell-relative (0..255).
     */
    static class CellData {
        int cellX, cellY;
        int minLevel, maxLevel;
        int headerVersion;

        // Tile string table (from .lotheader)
        List<String> tilesUsed = new ArrayList<>();
        Map<String, Integer> tileIndex = new LinkedHashMap<>();

        // Per-square tile data (from .lotpack)
        Map<Integer, List<Integer>> tiles = new HashMap<>();  // squareIdx → tile name indices
        Map<Integer, Integer> rooms = new HashMap<>();         // squareIdx → roomID

        // File references
        File lotheaderFile, lotpackFile;
        byte[] lotheaderBytes;    // original bytes for round-trip
        int tilesEndOffset;       // byte offset where tile-name section ends
        boolean lotheaderDirty;   // set when new tile names are added

        int getMinSquareX() { return cellX * CELL_DIM; }
        int getMinSquareY() { return cellY * CELL_DIM; }

        int squareIdx(int relX, int relY, int z) {
            return relX + relY * CELL_DIM + (z - minLevel) * CELL_DIM * CELL_DIM;
        }

        /** Ensure a tile name exists in the string table; returns its index. */
        int ensureTile(String name) {
            Integer idx = tileIndex.get(name);
            if (idx != null) return idx;
            idx = tilesUsed.size();
            tilesUsed.add(name);
            tileIndex.put(name, idx);
            lotheaderDirty = true;
            return idx;
        }

        String tileName(int idx) {
            return (idx >= 0 && idx < tilesUsed.size()) ? tilesUsed.get(idx) : "?INVALID_" + idx;
        }
    }

    // ========================== Cell Derivation ==========================

    /** Derive cell coordinates from absolute world tile position. */
    static int[] cellFromWorld(int worldX, int worldY) {
        return new int[]{ worldX / CELL_DIM, worldY / CELL_DIM };
    }

    // ========================== Load ==========================

    static CellData loadCell(File mapDir, int cellX, int cellY) throws IOException {
        String base = cellX + "_" + cellY;
        CellData cell = new CellData();
        cell.cellX = cellX;
        cell.cellY = cellY;
        cell.lotheaderFile = new File(mapDir, base + ".lotheader");
        cell.lotpackFile = new File(mapDir, "world_" + base + ".lotpack");

        if (!cell.lotheaderFile.exists())
            throw new FileNotFoundException("Missing: " + cell.lotheaderFile);
        if (!cell.lotpackFile.exists())
            throw new FileNotFoundException("Missing: " + cell.lotpackFile);

        loadLotheader(cell);
        loadLotpack(cell);
        return cell;
    }

    /**
     * Parse .lotheader: tile name string table + minLevel/maxLevel.
     * Stores original bytes for round-trip (rooms, buildings, zombie density are preserved).
     */
    static void loadLotheader(CellData cell) throws IOException {
        byte[] b = readAllBytes(cell.lotheaderFile);
        cell.lotheaderBytes = b;
        int pos = 0;

        boolean hasMagic = b.length >= 4
                && b[0] == 'L' && b[1] == 'O' && b[2] == 'T' && b[3] == 'H';
        if (hasMagic) pos = 4;

        cell.headerVersion = readIntLE(b, pos); pos += 4;
        int tileCount = readIntLE(b, pos); pos += 4;

        for (int i = 0; i < tileCount; i++) {
            int start = pos;
            while (pos < b.length && b[pos] != '\n') pos++;
            String name = new String(b, start, pos - start, StandardCharsets.UTF_8).trim();
            cell.tilesUsed.add(name);
            cell.tileIndex.put(name, i);
            pos++; // skip \n
        }
        cell.tilesEndOffset = pos;

        // Read width, height, levels
        if (cell.headerVersion == 0) pos++; // skip 1 padding byte
        pos += 8; // skip width + height

        if (cell.headerVersion == 0) {
            cell.minLevel = 0;
            cell.maxLevel = readIntLE(b, pos);
        } else {
            cell.minLevel = readIntLE(b, pos);
            cell.maxLevel = readIntLE(b, pos + 4);
        }
    }

    /**
     * Parse .lotpack file.
     *
     * File layout (version 1):
     *   [0..3]  "LOTP" magic
     *   [4..7]  version (int32 LE) = 1
     *   [8..11] chunkDim (int32 LE) = 8
     *   [12..]  chunk index table: 1024 entries × 8 bytes
     *           (first 4 bytes = file offset to chunk data, next 4 unused)
     *
     * Chunk data (per z → x → y):
     *   int32 count:
     *     count == -1 → next int32 is skipCount (RLE for empty squares)
     *     count ==  0 → empty square
     *     count  >  1 → int32 roomID, then (count-1) × int32 tileNameIndex
     */
    static void loadLotpack(CellData cell) throws IOException {
        try (RandomAccessFile raf = new RandomAccessFile(cell.lotpackFile, "r")) {
            byte[] magic = new byte[4];
            raf.read(magic, 0, 4);
            boolean hasMagic = Arrays.equals(magic, LOTP_MAGIC);
            int version;
            if (hasMagic) {
                version = readIntLE(raf);
                if (version < 0 || version > 1)
                    throw new IOException("Unsupported lotpack version: " + version);
            } else {
                raf.seek(0);
                version = 0;
            }

            int headerOffset = version >= 1 ? 8 : 0;
            int minZ = Math.max(cell.minLevel, -32);
            int maxZ = Math.min(cell.maxLevel, 31);
            if (version == 0) maxZ--;

            for (int cx = 0; cx < CHUNKS_PER_CELL; cx++) {
                for (int cy = 0; cy < CHUNKS_PER_CELL; cy++) {
                    int index = cx * CHUNKS_PER_CELL + cy;
                    raf.seek(headerOffset + 4 + (long) index * 8);
                    int pos = readIntLE(raf);
                    raf.seek(pos);

                    int skip = 0;
                    for (int z = minZ; z <= maxZ; z++) {
                        for (int x = 0; x < CHUNK_DIM; x++) {
                            for (int y = 0; y < CHUNK_DIM; y++) {
                                if (skip > 0) { skip--; continue; }

                                int count = readIntLE(raf);
                                if (count == -1) {
                                    skip = readIntLE(raf);
                                    if (skip > 0) { skip--; continue; }
                                }
                                if (count > 1) {
                                    int relX = cx * CHUNK_DIM + x;
                                    int relY = cy * CHUNK_DIM + y;
                                    int sqIdx = cell.squareIdx(relX, relY, z);

                                    int roomID = readIntLE(raf);
                                    cell.rooms.put(sqIdx, roomID);

                                    List<Integer> tileList = new ArrayList<>(count - 1);
                                    for (int n = 1; n < count; n++) {
                                        tileList.add(readIntLE(raf));
                                    }
                                    cell.tiles.put(sqIdx, tileList);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================== Save ==========================

    /**
     * Write .lotpack in B42 version 1 format.
     * Preserves room IDs read during load.
     */
    static void saveLotpack(CellData cell) throws IOException {
        int numChunks = CHUNKS_PER_CELL * CHUNKS_PER_CELL;
        ByteBuffer bb = ByteBuffer.allocate(20 * 1024 * 1024);
        bb.order(ByteOrder.LITTLE_ENDIAN);

        // Header
        bb.put(LOTP_MAGIC);
        bb.putInt(1);            // version
        bb.putInt(CHUNK_DIM);    // chunkDim

        int chunkTableStart = bb.position(); // = 12
        bb.position(chunkTableStart + numChunks * 8); // skip index table space

        int minZ = Math.max(cell.minLevel, -32);
        int maxZ = Math.min(cell.maxLevel, 31);

        for (int cx = 0; cx < CHUNKS_PER_CELL; cx++) {
            for (int cy = 0; cy < CHUNKS_PER_CELL; cy++) {
                // Record this chunk's data offset in the index table
                int tableEntry = chunkTableStart + (cx * CHUNKS_PER_CELL + cy) * 8;
                bb.putInt(tableEntry, bb.position());

                int emptyRun = 0;

                for (int z = minZ; z <= maxZ; z++) {
                    for (int x = 0; x < CHUNK_DIM; x++) {
                        for (int y = 0; y < CHUNK_DIM; y++) {
                            int relX = cx * CHUNK_DIM + x;
                            int relY = cy * CHUNK_DIM + y;
                            int sqIdx = cell.squareIdx(relX, relY, z);

                            List<Integer> tileList = cell.tiles.get(sqIdx);

                            if (tileList == null || tileList.isEmpty()) {
                                emptyRun++;
                            } else {
                                // Flush empty run
                                if (emptyRun > 0) {
                                    bb.putInt(-1);
                                    bb.putInt(emptyRun);
                                    emptyRun = 0;
                                }
                                int numTiles = tileList.size();
                                bb.putInt(numTiles + 1); // count includes room
                                bb.putInt(cell.rooms.getOrDefault(sqIdx, -1));
                                for (int tileIdx : tileList) {
                                    bb.putInt(tileIdx);
                                }
                            }
                        }
                    }
                }

                // Flush trailing empties for this chunk
                if (emptyRun > 0) {
                    bb.putInt(-1);
                    bb.putInt(emptyRun);
                }
            }
        }

        // Backup
        backup(cell.lotpackFile);

        // Write
        bb.flip();
        byte[] data = new byte[bb.remaining()];
        bb.get(data);
        try (FileOutputStream fos = new FileOutputStream(cell.lotpackFile)) {
            fos.write(data);
        }
        System.out.println("  Lotpack written: " + cell.lotpackFile.getName()
                + " (" + data.length + " bytes)");
    }

    /**
     * Rewrite .lotheader with updated tile name table.
     * Everything after the original tile-name section is preserved byte-for-byte.
     */
    static void saveLotheader(CellData cell) throws IOException {
        if (!cell.lotheaderDirty) return;

        byte[] original = cell.lotheaderBytes;
        int suffixStart = cell.tilesEndOffset;
        byte[] suffix = Arrays.copyOfRange(original, suffixStart, original.length);

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        boolean hasMagic = original.length >= 4
                && original[0] == 'L' && original[1] == 'O'
                && original[2] == 'T' && original[3] == 'H';
        if (hasMagic) out.write(LOTH_MAGIC);

        writeIntLE(out, cell.headerVersion);
        writeIntLE(out, cell.tilesUsed.size());
        for (String name : cell.tilesUsed) {
            out.write(name.getBytes(StandardCharsets.UTF_8));
            out.write('\n');
        }
        out.write(suffix);

        backup(cell.lotheaderFile);

        try (FileOutputStream fos = new FileOutputStream(cell.lotheaderFile)) {
            fos.write(out.toByteArray());
        }
        cell.lotheaderDirty = false;
        System.out.println("  Lotheader updated: " + cell.tilesUsed.size() + " tile names.");
    }

    // ========================== Commands ==========================

    static void doInspect(File mapDir, int cellX, int cellY, int[] chunkFilter) throws IOException {
        CellData cell = loadCell(mapDir, cellX, cellY);
        int minZ = Math.max(cell.minLevel, -32);
        int maxZ = Math.min(cell.maxLevel, 31);

        System.out.printf("Cell %d_%d  |  %d tile names  |  %d non-empty squares  |  z=[%d..%d]%n",
                cellX, cellY, cell.tilesUsed.size(), cell.tiles.size(), cell.minLevel, cell.maxLevel);
        System.out.println("=".repeat(70));

        if (chunkFilter != null) {
            // Detailed view for one chunk
            int fcx = chunkFilter[0], fcy = chunkFilter[1];
            System.out.printf("Chunk [%d, %d]%n", fcx, fcy);

            int count = 0;
            for (int z = minZ; z <= maxZ; z++) {
                for (int x = 0; x < CHUNK_DIM; x++) {
                    for (int y = 0; y < CHUNK_DIM; y++) {
                        int relX = fcx * CHUNK_DIM + x;
                        int relY = fcy * CHUNK_DIM + y;
                        int sqIdx = cell.squareIdx(relX, relY, z);
                        List<Integer> tl = cell.tiles.get(sqIdx);
                        if (tl != null) {
                            int wx = cell.getMinSquareX() + relX;
                            int wy = cell.getMinSquareY() + relY;
                            System.out.printf("  (%d,%d,%d) world=(%d,%d,%d):%n", relX, relY, z, wx, wy, z);
                            for (int ti : tl) {
                                System.out.printf("    [%3d] %s%n", ti, cell.tileName(ti));
                            }
                            count += tl.size();
                        }
                    }
                }
            }
            System.out.printf("%nTotal: %d tile objects%n", count);
        } else {
            // Summary per chunk
            for (int cx = 0; cx < CHUNKS_PER_CELL; cx++) {
                for (int cy = 0; cy < CHUNKS_PER_CELL; cy++) {
                    int objCount = 0;
                    int sqCount = 0;
                    for (int z = minZ; z <= maxZ; z++) {
                        for (int x = 0; x < CHUNK_DIM; x++) {
                            for (int y = 0; y < CHUNK_DIM; y++) {
                                int relX = cx * CHUNK_DIM + x;
                                int relY = cy * CHUNK_DIM + y;
                                List<Integer> tl = cell.tiles.get(cell.squareIdx(relX, relY, z));
                                if (tl != null) {
                                    sqCount++;
                                    objCount += tl.size();
                                }
                            }
                        }
                    }
                    if (objCount > 0) {
                        System.out.printf("  Chunk [%2d,%2d]: %5d objects in %4d squares%n",
                                cx, cy, objCount, sqCount);
                    }
                }
            }
        }
    }

    static void doInspectAt(File mapDir, int worldX, int worldY, int z) throws IOException {
        int[] cc = cellFromWorld(worldX, worldY);
        CellData cell = loadCell(mapDir, cc[0], cc[1]);
        int relX = worldX - cell.getMinSquareX();
        int relY = worldY - cell.getMinSquareY();

        System.out.printf("Cell %d_%d  |  World (%d,%d,%d)  |  Rel (%d,%d,%d)  |  Chunk [%d,%d]%n",
                cc[0], cc[1], worldX, worldY, z, relX, relY, z, relX / CHUNK_DIM, relY / CHUNK_DIM);
        System.out.println("-".repeat(60));

        int sqIdx = cell.squareIdx(relX, relY, z);
        List<Integer> tl = cell.tiles.get(sqIdx);
        if (tl == null || tl.isEmpty()) {
            System.out.println("  (empty — no objects)");
        } else {
            int room = cell.rooms.getOrDefault(sqIdx, -1);
            System.out.printf("  Room ID: %d  |  Objects: %d%n", room, tl.size());
            for (int ti : tl) {
                System.out.printf("    [%3d] %s%n", ti, cell.tileName(ti));
            }
        }
    }

    static void doSearch(File mapDir, int[] cc, String tileName) throws IOException {
        CellData cell = loadCell(mapDir, cc[0], cc[1]);
        Integer idx = cell.tileIndex.get(tileName);
        if (idx == null) {
            System.out.printf("Tile '%s' not found in cell %d_%d string table.%n", tileName, cc[0], cc[1]);
            return;
        }

        System.out.printf("Searching for '%s' (index %d) in cell %d_%d...%n", tileName, idx, cc[0], cc[1]);
        int hits = 0;

        int minZ = Math.max(cell.minLevel, -32);
        int maxZ = Math.min(cell.maxLevel, 31);

        for (int z = minZ; z <= maxZ; z++) {
            for (int relY = 0; relY < CELL_DIM; relY++) {
                for (int relX = 0; relX < CELL_DIM; relX++) {
                    int sqIdx = cell.squareIdx(relX, relY, z);
                    List<Integer> tl = cell.tiles.get(sqIdx);
                    if (tl != null && tl.contains(idx)) {
                        int wx = cell.getMinSquareX() + relX;
                        int wy = cell.getMinSquareY() + relY;
                        System.out.printf("  (%d,%d,%d) world=(%d,%d,%d)  tiles: %s%n",
                                relX, relY, z, wx, wy, z, tileListStr(cell, tl));
                        hits++;
                    }
                }
            }
        }

        System.out.printf("%nFound %d squares containing '%s'.%n", hits, tileName);
    }

    static void doRemove(File mapDir, int worldX, int worldY, int z,
                          String tileName) throws IOException {
        int[] cc = cellFromWorld(worldX, worldY);
        CellData cell = loadCell(mapDir, cc[0], cc[1]);
        int relX = worldX - cell.getMinSquareX();
        int relY = worldY - cell.getMinSquareY();

        Integer idx = cell.tileIndex.get(tileName);
        if (idx == null) {
            System.err.printf("Tile '%s' not in string table.%n", tileName);
            System.exit(1);
        }

        int sqIdx = cell.squareIdx(relX, relY, z);
        List<Integer> tl = cell.tiles.get(sqIdx);
        if (tl == null || !tl.contains(idx)) {
            System.err.printf("No '%s' at world (%d,%d,%d).%n", tileName, worldX, worldY, z);
            System.exit(1);
        }

        tl.remove(idx); // removes first occurrence of Integer value
        if (tl.isEmpty()) {
            cell.tiles.remove(sqIdx);
            cell.rooms.remove(sqIdx);
        }

        System.out.printf("Removed: '%s' at world (%d,%d,%d)%n", tileName, worldX, worldY, z);
        saveLotpack(cell);
    }

    static void doSet(File mapDir, int worldX, int worldY, int z,
                       String oldTile, String newTile) throws IOException {
        int[] cc = cellFromWorld(worldX, worldY);
        CellData cell = loadCell(mapDir, cc[0], cc[1]);
        int relX = worldX - cell.getMinSquareX();
        int relY = worldY - cell.getMinSquareY();

        Integer oldIdx = cell.tileIndex.get(oldTile);
        if (oldIdx == null) {
            System.err.printf("Old tile '%s' not in string table.%n", oldTile);
            System.exit(1);
        }

        int sqIdx = cell.squareIdx(relX, relY, z);
        List<Integer> tl = cell.tiles.get(sqIdx);
        if (tl == null) {
            System.err.printf("No objects at world (%d,%d,%d).%n", worldX, worldY, z);
            System.exit(1);
        }

        int pos = tl.indexOf(oldIdx);
        if (pos < 0) {
            System.err.printf("Tile '%s' not at world (%d,%d,%d).%n", oldTile, worldX, worldY, z);
            System.exit(1);
        }

        int newIdx = cell.ensureTile(newTile);
        tl.set(pos, newIdx);

        System.out.printf("Set: '%s' -> '%s' at world (%d,%d,%d)%n", oldTile, newTile, worldX, worldY, z);
        saveLotheader(cell);
        saveLotpack(cell);
    }

    static void doAdd(File mapDir, int worldX, int worldY, int z,
                       String tileName) throws IOException {
        int[] cc = cellFromWorld(worldX, worldY);
        CellData cell = loadCell(mapDir, cc[0], cc[1]);
        int relX = worldX - cell.getMinSquareX();
        int relY = worldY - cell.getMinSquareY();

        int tileIdx = cell.ensureTile(tileName);

        int sqIdx = cell.squareIdx(relX, relY, z);
        List<Integer> tl = cell.tiles.get(sqIdx);
        if (tl == null) {
            tl = new ArrayList<>();
            cell.tiles.put(sqIdx, tl);
        }
        tl.add(tileIdx);

        System.out.printf("Added: '%s' at world (%d,%d,%d)%n", tileName, worldX, worldY, z);
        saveLotheader(cell);
        saveLotpack(cell);
    }

    static void doPatch(File mapDir, File patchFile, File worldmapFile) throws IOException {
        if (!patchFile.isFile()) {
            System.err.println("Patch file not found: " + patchFile);
            System.exit(1);
        }

        List<String[]> operations = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(new FileInputStream(patchFile), StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                operations.add(line.split(",\\s*"));
            }
        }
        System.out.printf("Loaded %d lines from %s%n", operations.size(), patchFile.getName());

        // ── Filter out legacy @ directives (now ignored) ──
        List<String[]> normalOps = new ArrayList<>();
        for (String[] op : operations) {
            String act0 = op[0].trim();
            if (act0.startsWith("@")) {
                System.out.printf("  Ignoring legacy directive: %s%n", act0);
            } else {
                normalOps.add(op);
            }
        }
        operations = normalOps;

        // ── Pre-expand range operations ──
        List<int[]> clearAreas = new ArrayList<>();
        List<String[]> expanded = new ArrayList<>();
        for (String[] op : operations) {
            String action = op[0].trim().toLowerCase();
            if (action.equals("removeallrange")) {
                if (op.length < 7) {
                    System.err.printf("WARN: removeAllRange needs 7 fields (action,x1,y1,z1,x2,y2,z2): %s%n",
                            String.join(",", op));
                    continue;
                }
                int x1 = Integer.parseInt(op[1].trim()), y1 = Integer.parseInt(op[2].trim()), z1 = Integer.parseInt(op[3].trim());
                int x2 = Integer.parseInt(op[4].trim()), y2 = Integer.parseInt(op[5].trim()), z2 = Integer.parseInt(op[6].trim());
                int minX = Math.min(x1, x2), maxX = Math.max(x1, x2);
                int minY = Math.min(y1, y2), maxY = Math.max(y1, y2);
                int minZ = Math.min(z1, z2), maxZ = Math.max(z1, z2);
                clearAreas.add(new int[]{minX, minY, minZ, maxX, maxY, maxZ});
                int count = (maxX - minX + 1) * (maxY - minY + 1) * (maxZ - minZ + 1);
                System.out.printf("  Expanding removeAllRange (%d,%d,%d)->(%d,%d,%d) = %d squares%n",
                        minX, minY, minZ, maxX, maxY, maxZ, count);
                for (int z = minZ; z <= maxZ; z++)
                    for (int y = minY; y <= maxY; y++)
                        for (int x = minX; x <= maxX; x++)
                            expanded.add(new String[]{"_removeall", String.valueOf(x), String.valueOf(y), String.valueOf(z)});
            } else if (action.equals("addallrange")) {
                if (op.length < 8) {
                    System.err.printf("WARN: addAllRange needs 8 fields (action,x1,y1,z1,x2,y2,z2,tileName): %s%n",
                            String.join(",", op));
                    continue;
                }
                int x1 = Integer.parseInt(op[1].trim()), y1 = Integer.parseInt(op[2].trim()), z1 = Integer.parseInt(op[3].trim());
                int x2 = Integer.parseInt(op[4].trim()), y2 = Integer.parseInt(op[5].trim()), z2 = Integer.parseInt(op[6].trim());
                String tile = op[7].trim();
                int minX = Math.min(x1, x2), maxX = Math.max(x1, x2);
                int minY = Math.min(y1, y2), maxY = Math.max(y1, y2);
                int minZ = Math.min(z1, z2), maxZ = Math.max(z1, z2);
                int count = (maxX - minX + 1) * (maxY - minY + 1) * (maxZ - minZ + 1);
                System.out.printf("  Expanding addAllRange (%d,%d,%d)->(%d,%d,%d) '%s' = %d squares%n",
                        minX, minY, minZ, maxX, maxY, maxZ, tile, count);
                for (int z = minZ; z <= maxZ; z++)
                    for (int y = minY; y <= maxY; y++)
                        for (int x = minX; x <= maxX; x++)
                            expanded.add(new String[]{"add", String.valueOf(x), String.valueOf(y), String.valueOf(z), tile});
            } else {
                expanded.add(op);
            }
        }
        operations = expanded;
        System.out.printf("Total operations after expansion: %d%n%n", operations.size());

        // Group by auto-derived cell
        Map<String, List<String[]>> byCell = new LinkedHashMap<>();
        for (String[] op : operations) {
            String act = op[0].trim().toLowerCase();
            int minFields = act.equals("_removeall") ? 4 : 5;
            if (op.length < minFields) {
                System.err.printf("WARN: malformed line (need >=%d fields): %s%n", minFields, String.join(",", op));
                continue;
            }
            int wx = Integer.parseInt(op[1].trim());
            int wy = Integer.parseInt(op[2].trim());
            String cellKey = (wx / CELL_DIM) + "_" + (wy / CELL_DIM);
            byCell.computeIfAbsent(cellKey, k -> new ArrayList<>()).add(op);
        }

        int totalOps = 0;
        Map<String, Set<Long>> roadTilesByHighway = new LinkedHashMap<>();

        for (Map.Entry<String, List<String[]>> entry : byCell.entrySet()) {
            int[] cc = parseCellCoords(entry.getKey());
            CellData cell = loadCell(mapDir, cc[0], cc[1]);
            boolean dirty = false;

            for (String[] op : entry.getValue()) {
                String action = op[0].trim().toLowerCase();
                int worldX = Integer.parseInt(op[1].trim());
                int worldY = Integer.parseInt(op[2].trim());
                int z = Integer.parseInt(op[3].trim());
                String tileName = op.length > 4 ? op[4].trim() : null;

                int relX = worldX - cell.getMinSquareX();
                int relY = worldY - cell.getMinSquareY();
                int sqIdx = cell.squareIdx(relX, relY, z);

                switch (action) {
                    case "_removeall": {
                        List<Integer> tl = cell.tiles.remove(sqIdx);
                        if (tl != null && !tl.isEmpty()) {
                            cell.rooms.remove(sqIdx);
                            dirty = true;
                            totalOps++;
                            System.out.printf("  CLEAR  %d objects at (%d,%d,%d) [cell %d_%d]%n",
                                    tl.size(), worldX, worldY, z, cc[0], cc[1]);
                        }
                        break;
                    }
                    case "add": {
                        int idx = cell.ensureTile(tileName);
                        List<Integer> tl = cell.tiles.computeIfAbsent(sqIdx, k -> new ArrayList<>());
                        tl.add(idx);
                        dirty = true;
                        totalOps++;
                        System.out.printf("  ADD    '%s' at (%d,%d,%d) [cell %d_%d]%n",
                                tileName, worldX, worldY, z, cc[0], cc[1]);
                        // Track road tiles for worldmap sync (hardcoded: blends_street_01_85 → tertiary)
                        if (z == 0 && ROAD_TILE.equals(tileName)) {
                            roadTilesByHighway.computeIfAbsent(
                                    ROAD_HIGHWAY, k -> new HashSet<>())
                                    .add(posKey(worldX, worldY));
                        }
                        break;
                    }
                    case "remove": {
                        Integer idx = cell.tileIndex.get(tileName);
                        if (idx == null) {
                            System.err.printf("  WARN: '%s' not in string table, skip remove%n", tileName);
                            continue;
                        }
                        List<Integer> tl = cell.tiles.get(sqIdx);
                        if (tl != null && tl.remove(idx)) {
                            if (tl.isEmpty()) { cell.tiles.remove(sqIdx); cell.rooms.remove(sqIdx); }
                            dirty = true;
                            totalOps++;
                            System.out.printf("  REMOVE '%s' at (%d,%d,%d) [cell %d_%d]%n",
                                    tileName, worldX, worldY, z, cc[0], cc[1]);
                        } else {
                            System.err.printf("  WARN: '%s' not at (%d,%d,%d)%n",
                                    tileName, worldX, worldY, z);
                        }
                        break;
                    }
                    case "set": {
                        if (op.length < 6) {
                            System.err.println("  WARN: 'set' needs 6 fields (action,x,y,z,old,new)");
                            continue;
                        }
                        String newTile = op[5].trim();
                        Integer oldIdx = cell.tileIndex.get(tileName);
                        if (oldIdx == null) {
                            System.err.printf("  WARN: old tile '%s' not in table%n", tileName);
                            continue;
                        }
                        List<Integer> tl = cell.tiles.get(sqIdx);
                        if (tl == null) {
                            System.err.printf("  WARN: no objects at (%d,%d,%d)%n", worldX, worldY, z);
                            continue;
                        }
                        int pos = tl.indexOf(oldIdx);
                        if (pos < 0) {
                            System.err.printf("  WARN: '%s' not at (%d,%d,%d)%n",
                                    tileName, worldX, worldY, z);
                            continue;
                        }
                        int newIdx = cell.ensureTile(newTile);
                        tl.set(pos, newIdx);
                        dirty = true;
                        totalOps++;
                        System.out.printf("  SET    '%s' -> '%s' at (%d,%d,%d) [cell %d_%d]%n",
                                tileName, newTile, worldX, worldY, z, cc[0], cc[1]);
                        break;
                    }
                    case "removeallbut": {
                        Integer keepIdx = cell.tileIndex.get(tileName);
                        List<Integer> tl = cell.tiles.get(sqIdx);
                        if (tl == null || tl.isEmpty()) break;
                        int before = tl.size();
                        if (keepIdx != null) {
                            tl.removeIf(idx -> !idx.equals(keepIdx));
                        } else {
                            tl.clear();
                        }
                        int removed = before - tl.size();
                        if (removed > 0) {
                            if (tl.isEmpty()) { cell.tiles.remove(sqIdx); cell.rooms.remove(sqIdx); }
                            dirty = true;
                            totalOps++;
                            System.out.printf("  KEEPONLY '%s' at (%d,%d,%d) — removed %d of %d [cell %d_%d]%n",
                                    tileName, worldX, worldY, z, removed, before, cc[0], cc[1]);
                        }
                        break;
                    }
                    default:
                        System.err.printf("  WARN: unknown action '%s'%n", action);
                }
            }

            if (dirty) {
                saveLotheader(cell);
                saveLotpack(cell);
            }
        }
        System.out.printf("%nDone. %d operations applied.%n", totalOps);

        // ── Worldmap sync ──
        if (worldmapFile != null && worldmapFile.isFile()
                && (!roadTilesByHighway.isEmpty() || !clearAreas.isEmpty())) {
            syncWorldmap(worldmapFile, roadTilesByHighway, clearAreas, mapDir);
        }

        // ── Undo prompt ──
        if (!backedUpFiles.isEmpty()) {
            System.out.printf("%nUndo patch? This will restore %d backed-up file(s) to their original state.%n", backedUpFiles.size());
            System.out.print("Type 'yes' to undo, or press Enter to keep changes [N]: ");
            System.out.flush();
            String answer = new BufferedReader(new InputStreamReader(System.in)).readLine();
            if (answer != null && answer.trim().equalsIgnoreCase("yes")) {
                int restored = 0;
                for (File original : backedUpFiles) {
                    File bak = new File(original.getPath() + ".bak");
                    if (bak.exists()) {
                        if (original.exists()) original.delete();
                        if (bak.renameTo(original)) {
                            restored++;
                            System.out.println("  Restored: " + original.getName());
                        } else {
                            System.err.println("  WARN: Could not restore " + original.getName());
                        }
                    }
                }
                // Also remove regenerated worldmap.xml.bin if worldmap.xml was restored
                if (worldmapFile != null && backedUpFiles.contains(worldmapFile)) {
                    File binFile = new File(worldmapFile.getPath() + ".bin");
                    File binBak = new File(binFile.getPath() + ".bak");
                    if (binBak.exists()) {
                        if (binFile.exists()) binFile.delete();
                        if (binBak.renameTo(binFile)) {
                            restored++;
                            System.out.println("  Restored: " + binFile.getName());
                        }
                    }
                }
                System.out.printf("Undo complete: %d file(s) restored.%n", restored);
            } else {
                System.out.println("Changes kept. .bak files preserved for manual rollback.");
            }
            backedUpFiles.clear();
        }
    }

    // ========================== Worldmap Sync ==========================

    static long posKey(int x, int y) { return ((long) x << 32) | (y & 0xFFFFFFFFL); }
    static int posX(long key) { return (int) (key >> 32); }
    static int posY(long key) { return (int) (key & 0xFFFFFFFFL); }

    /** Group tile positions into 4-connected components via flood fill. */
    static List<Set<Long>> groupConnectedTiles(Set<Long> tiles) {
        Set<Long> remaining = new HashSet<>(tiles);
        List<Set<Long>> groups = new ArrayList<>();
        while (!remaining.isEmpty()) {
            long seed = remaining.iterator().next();
            Set<Long> group = new HashSet<>();
            Deque<Long> queue = new ArrayDeque<>();
            queue.add(seed);
            remaining.remove(seed);
            while (!queue.isEmpty()) {
                long pos = queue.poll();
                group.add(pos);
                int x = posX(pos), y = posY(pos);
                for (long nb : new long[]{posKey(x - 1, y), posKey(x + 1, y),
                                          posKey(x, y - 1), posKey(x, y + 1)}) {
                    if (remaining.remove(nb)) queue.add(nb);
                }
            }
            groups.add(group);
        }
        return groups;
    }

    /**
     * Trace the boundary outline of a connected set of grid cells.
     * Each cell at (x,y) occupies the unit square [(x,y), (x+1,y+1)].
     * Returns vertex coordinates forming a closed polygon (CW in screen coords).
     * Collinear vertices are removed for compactness.
     */
    static List<int[]> traceOutline(Set<Long> cells) {
        // Build directed boundary edges: startVertex → endVertex (CW winding)
        Map<Long, Long> edgeMap = new LinkedHashMap<>();
        for (long pos : cells) {
            int x = posX(pos), y = posY(pos);
            if (!cells.contains(posKey(x, y - 1)))   // no neighbor above
                edgeMap.put(posKey(x, y),     posKey(x + 1, y));
            if (!cells.contains(posKey(x + 1, y)))   // no neighbor to right
                edgeMap.put(posKey(x + 1, y), posKey(x + 1, y + 1));
            if (!cells.contains(posKey(x, y + 1)))   // no neighbor below
                edgeMap.put(posKey(x + 1, y + 1), posKey(x, y + 1));
            if (!cells.contains(posKey(x - 1, y)))   // no neighbor to left
                edgeMap.put(posKey(x, y + 1), posKey(x, y));
        }
        if (edgeMap.isEmpty()) return Collections.emptyList();

        // Trace the outer boundary loop
        long start = edgeMap.keySet().iterator().next();
        long cur = start;
        List<int[]> outline = new ArrayList<>();
        do {
            outline.add(new int[]{ posX(cur), posY(cur) });
            Long next = edgeMap.get(cur);
            if (next == null) break; // safety
            cur = next;
        } while (cur != start);

        // Remove collinear vertices (mid-points on straight H/V segments)
        List<int[]> simplified = new ArrayList<>();
        int n = outline.size();
        for (int i = 0; i < n; i++) {
            int[] prev = outline.get((i + n - 1) % n);
            int[] curr = outline.get(i);
            int[] next = outline.get((i + 1) % n);
            boolean collinear = (curr[0] - prev[0] == next[0] - curr[0])
                             && (curr[1] - prev[1] == next[1] - curr[1]);
            if (!collinear) simplified.add(curr);
        }
        return simplified.isEmpty() ? outline : simplified;
    }

    /** Extract an XML attribute value from a tag string, e.g. extractAttr(tag, "x"). */
    static String extractAttr(String tag, String attr) {
        String prefix = attr + "=\"";
        int start = tag.indexOf(prefix);
        if (start < 0) return null;
        start += prefix.length();
        int end = tag.indexOf('"', start);
        return tag.substring(start, end);
    }

    // ========================== Polygon Clipping ==========================

    /**
     * Sutherland-Hodgman half-plane clip.
     * Clips {@code poly} to one side of an axis-aligned line.
     * @param poly     input polygon (list of [x,y])
     * @param axis     0 = x-axis, 1 = y-axis
     * @param value    the coordinate value of the clipping edge
     * @param keepLess true = keep the side where coord &lt; value
     * @return clipped polygon (may be empty)
     */
    static List<double[]> clipToHalfPlane(List<double[]> poly, int axis, double value, boolean keepLess) {
        List<double[]> out = new ArrayList<>();
        int n = poly.size();
        if (n == 0) return out;
        for (int i = 0; i < n; i++) {
            double[] cur = poly.get(i);
            double[] nxt = poly.get((i + 1) % n);
            boolean curIn = keepLess ? cur[axis] < value : cur[axis] > value;
            boolean nxtIn = keepLess ? nxt[axis] < value : nxt[axis] > value;
            if (curIn) {
                out.add(cur);
                if (!nxtIn) out.add(edgeIntersect(cur, nxt, axis, value));
            } else if (nxtIn) {
                out.add(edgeIntersect(cur, nxt, axis, value));
            }
        }
        return out;
    }

    /** Compute intersection of segment a→b with axis-aligned line axis=value. */
    static double[] edgeIntersect(double[] a, double[] b, int axis, double value) {
        double t = (value - a[axis]) / (b[axis] - a[axis]);
        return new double[]{
                a[0] + t * (b[0] - a[0]),
                a[1] + t * (b[1] - a[1])
        };
    }

    /**
     * Subtract one axis-aligned rectangle from a polygon.
     * Returns up to 4 pieces: left, right, top-center, bottom-center.
     */
    static List<List<double[]>> subtractRect(List<double[]> poly, double x1, double y1, double x2, double y2) {
        List<List<double[]>> pieces = new ArrayList<>();
        // Left piece: x < x1
        List<double[]> left = clipToHalfPlane(poly, 0, x1, true);
        if (left.size() >= 3) pieces.add(left);
        // Right piece: x > x2
        List<double[]> right = clipToHalfPlane(poly, 0, x2, false);
        if (right.size() >= 3) pieces.add(right);
        // Center strip: x1 <= x <= x2
        List<double[]> center = clipToHalfPlane(clipToHalfPlane(poly, 0, x1, false), 0, x2, true);
        // Top-center: y < y1
        List<double[]> top = clipToHalfPlane(center, 1, y1, true);
        if (top.size() >= 3) pieces.add(top);
        // Bottom-center: y > y2
        List<double[]> bottom = clipToHalfPlane(center, 1, y2, false);
        if (bottom.size() >= 3) pieces.add(bottom);
        return pieces;
    }

    /**
     * Subtract multiple rectangles from a polygon, producing remaining pieces.
     * Each rectangle is subtracted from every piece produced so far.
     */
    static List<List<double[]>> subtractAllRects(List<double[]> poly, List<double[]> rects) {
        List<List<double[]>> pieces = new ArrayList<>();
        pieces.add(poly);
        for (double[] r : rects) {
            List<List<double[]>> next = new ArrayList<>();
            for (List<double[]> piece : pieces) {
                next.addAll(subtractRect(piece, r[0], r[1], r[2], r[3]));
            }
            pieces = next;
            if (pieces.isEmpty()) break;
        }
        return pieces;
    }

    /** Write a polygon feature element to the output list. */
    static void writeFeatureXml(List<String> output, List<double[]> poly, List<String> propLines) {
        output.add("  <feature>");
        output.add("   <geometry type=\"Polygon\">");
        output.add("    <coordinates>");
        for (double[] pt : poly) {
            // Round to 1 decimal to keep XML tidy
            String xs = (pt[0] == Math.floor(pt[0])) ? String.valueOf((int) pt[0])
                    : String.format("%.1f", pt[0]);
            String ys = (pt[1] == Math.floor(pt[1])) ? String.valueOf((int) pt[1])
                    : String.format("%.1f", pt[1]);
            output.add("     <point x=\"" + xs + "\" y=\"" + ys + "\"/>");
        }
        output.add("    </coordinates>");
        output.add("   </geometry>");
        if (!propLines.isEmpty()) {
            output.add("   <properties>");
            for (String pl : propLines) {
                output.add("    " + pl);
            }
            output.add("   </properties>");
        }
        output.add("  </feature>");
    }

    /**
     * Sync worldmap.xml: inject road polygon features and clip existing features
     * against cleared areas so underlying tile graphics render on the minimap.
     *
     * <p>World tile coordinates are mapped to 300-cell XML coordinates:
     *   xmlCellID = worldCoord / 300
     *   xmlLocal  = worldCoord - xmlCellID * 300
     *
     * <p>After modifying the XML, worldmap.xml.bin is auto-regenerated via ConvertMap.
     */
    static void syncWorldmap(File worldmapFile,
                              Map<String, Set<Long>> roadTilesByHighway,
                              List<int[]> clearAreas,
                              File mapDir) throws IOException {
        System.out.println("\n=== Worldmap Sync ===");

        // ── Step 1: Prepare road features grouped by cell ──
        // cellKey → list of {List<int[]> outline, highway}
        Map<String, List<Object[]>> roadFeaturesByCell = new LinkedHashMap<>();
        for (Map.Entry<String, Set<Long>> entry : roadTilesByHighway.entrySet()) {
            String highway = entry.getKey();
            // Group positions by XML cell (300-unit grid)
            Map<String, Set<Long>> byCell = new LinkedHashMap<>();
            for (long pos : entry.getValue()) {
                int wx = posX(pos), wy = posY(pos);
                String cellKey = (wx / XML_CELL_DIM) + "_" + (wy / XML_CELL_DIM);
                byCell.computeIfAbsent(cellKey, k -> new HashSet<>()).add(pos);
            }
            // Flood-fill connected components → trace exact boundary outlines
            for (Map.Entry<String, Set<Long>> cellEntry : byCell.entrySet()) {
                List<Set<Long>> components = groupConnectedTiles(cellEntry.getValue());
                for (Set<Long> comp : components) {
                    List<int[]> outline = traceOutline(comp);
                    if (!outline.isEmpty()) {
                        roadFeaturesByCell.computeIfAbsent(cellEntry.getKey(), k -> new ArrayList<>())
                                .add(new Object[]{outline, highway});
                    }
                }
            }
        }
        int totalPolygons = 0;
        for (List<Object[]> v : roadFeaturesByCell.values()) totalPolygons += v.size();
        System.out.printf("  Road features to inject: %d polygons in %d cells%n",
                totalPolygons, roadFeaturesByCell.size());

        // ── Step 2: Prepare clear-area bboxes in 300-cell coords for feature clipping ──
        // cellKey → list of [xmlX1, xmlY1, xmlX2, xmlY2]
        Map<String, List<double[]>> clearByCell = new LinkedHashMap<>();
        for (int[] area : clearAreas) {
            int minZ = Math.min(area[2], area[5]);
            if (minZ > 0) continue; // only z≤0 affects worldmap
            int cellX1 = area[0] / XML_CELL_DIM, cellX2 = area[3] / XML_CELL_DIM;
            int cellY1 = area[1] / XML_CELL_DIM, cellY2 = area[4] / XML_CELL_DIM;
            for (int cx = cellX1; cx <= cellX2; cx++) {
                for (int cy = cellY1; cy <= cellY2; cy++) {
                    String cellKey = cx + "_" + cy;
                    double x1 = Math.max(area[0], cx * XML_CELL_DIM) - cx * XML_CELL_DIM;
                    double y1 = Math.max(area[1], cy * XML_CELL_DIM) - cy * XML_CELL_DIM;
                    double x2 = Math.min(area[3] + 1, (cx + 1) * XML_CELL_DIM) - cx * XML_CELL_DIM;
                    double y2 = Math.min(area[4] + 1, (cy + 1) * XML_CELL_DIM) - cy * XML_CELL_DIM;
                    clearByCell.computeIfAbsent(cellKey, k -> new ArrayList<>())
                            .add(new double[]{x1, y1, x2, y2});
                }
            }
        }
        int totalClearAreas = 0;
        for (List<double[]> v : clearByCell.values()) totalClearAreas += v.size();
        System.out.printf("  Clear areas for feature clipping: %d areas in %d cells%n",
                totalClearAreas, clearByCell.size());

        // ── Step 3: Process XML line by line ──
        backup(worldmapFile);

        List<String> lines = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(new FileInputStream(worldmapFile), StandardCharsets.UTF_8))) {
            String ln;
            while ((ln = br.readLine()) != null) lines.add(ln);
        }

        List<String> output = new ArrayList<>();
        String currentCellKey = null;
        boolean inFeature = false;
        List<String> featureLines = new ArrayList<>();
        int injectedRoads = 0;
        int removedFeatures = 0;
        int clippedFeatures = 0;

        for (String ln : lines) {
            String trimmed = ln.trim();

            // Track current cell
            if (trimmed.startsWith("<cell ")) {
                String cx = extractAttr(trimmed, "x");
                String cy = extractAttr(trimmed, "y");
                if (cx != null && cy != null) currentCellKey = cx + "_" + cy;
                output.add(ln);
                continue;
            }

            // Inject road features before </cell>
            if (trimmed.equals("</cell>")) {
                if (currentCellKey != null && roadFeaturesByCell.containsKey(currentCellKey)) {
                    int[] cc = parseCellCoords(currentCellKey);
                    int cellBaseX = cc[0] * XML_CELL_DIM, cellBaseY = cc[1] * XML_CELL_DIM;
                    for (Object[] rf : roadFeaturesByCell.get(currentCellKey)) {
                        @SuppressWarnings("unchecked")
                        List<int[]> outline = (List<int[]>) rf[0];
                        String highway = (String) rf[1];
                        output.add("  <feature>");
                        output.add("   <geometry type=\"Polygon\">");
                        output.add("    <coordinates>");
                        for (int[] v : outline) {
                            int px = v[0] - cellBaseX;
                            int py = v[1] - cellBaseY;
                            output.add("     <point x=\"" + px + "\" y=\"" + py + "\"/>");
                        }
                        output.add("    </coordinates>");
                        output.add("   </geometry>");
                        output.add("   <properties>");
                        output.add("    <property name=\"highway\" value=\"" + highway + "\"/>");
                        output.add("   </properties>");
                        output.add("  </feature>");
                        injectedRoads++;
                    }
                }
                currentCellKey = null;
                output.add(ln);
                continue;
            }

            // Feature-level processing: clip polygons against clear areas
            if (!clearByCell.isEmpty() && trimmed.equals("<feature>")) {
                inFeature = true;
                featureLines.clear();
                featureLines.add(ln);
                continue;
            }

            if (inFeature) {
                featureLines.add(ln);
                if (trimmed.equals("</feature>")) {
                    inFeature = false;
                    List<double[]> cellClears = (currentCellKey != null)
                            ? clearByCell.get(currentCellKey) : null;
                    if (cellClears == null || cellClears.isEmpty()) {
                        // No clear areas in this cell - keep feature as-is
                        output.addAll(featureLines);
                    } else {
                        // Extract polygon points and property lines
                        List<double[]> poly = new ArrayList<>();
                        List<String> propLines = new ArrayList<>();
                        boolean inProps = false;
                        double bMinX = Double.MAX_VALUE, bMinY = Double.MAX_VALUE;
                        double bMaxX = -Double.MAX_VALUE, bMaxY = -Double.MAX_VALUE;
                        for (String fl : featureLines) {
                            String ft = fl.trim();
                            if (ft.startsWith("<point ")) {
                                String px = extractAttr(ft, "x");
                                String py = extractAttr(ft, "y");
                                if (px != null && py != null) {
                                    double xv = Double.parseDouble(px);
                                    double yv = Double.parseDouble(py);
                                    poly.add(new double[]{xv, yv});
                                    bMinX = Math.min(bMinX, xv);
                                    bMinY = Math.min(bMinY, yv);
                                    bMaxX = Math.max(bMaxX, xv);
                                    bMaxY = Math.max(bMaxY, yv);
                                }
                            }
                            if (ft.startsWith("<property ")) {
                                propLines.add(ft);
                            }
                        }
                        // Quick bbox check: does any clear rect overlap this feature?
                        boolean anyOverlap = false;
                        for (double[] ca : cellClears) {
                            if (bMaxX > ca[0] && bMinX < ca[2]
                                    && bMaxY > ca[1] && bMinY < ca[3]) {
                                anyOverlap = true;
                                break;
                            }
                        }
                        if (!anyOverlap || poly.size() < 3) {
                            output.addAll(featureLines);
                        } else {
                            // Subtract all clear rects from this polygon
                            List<List<double[]>> pieces = subtractAllRects(poly, cellClears);
                            if (pieces.isEmpty()) {
                                removedFeatures++;
                            } else if (pieces.size() == 1 && pieces.get(0).size() == poly.size()) {
                                // Unchanged - check if points actually match
                                boolean same = true;
                                List<double[]> p0 = pieces.get(0);
                                for (int pi = 0; pi < poly.size(); pi++) {
                                    if (Math.abs(p0.get(pi)[0] - poly.get(pi)[0]) > 0.001
                                            || Math.abs(p0.get(pi)[1] - poly.get(pi)[1]) > 0.001) {
                                        same = false;
                                        break;
                                    }
                                }
                                if (same) {
                                    output.addAll(featureLines);
                                } else {
                                    clippedFeatures++;
                                    for (List<double[]> piece : pieces) {
                                        writeFeatureXml(output, piece, propLines);
                                    }
                                }
                            } else {
                                clippedFeatures++;
                                for (List<double[]> piece : pieces) {
                                    writeFeatureXml(output, piece, propLines);
                                }
                            }
                        }
                    }
                }
                continue;
            }

            output.add(ln);
        }

        // Write modified XML
        try (BufferedWriter bw = new BufferedWriter(
                new OutputStreamWriter(new FileOutputStream(worldmapFile), StandardCharsets.UTF_8))) {
            for (int i = 0; i < output.size(); i++) {
                bw.write(output.get(i));
                if (i < output.size() - 1) bw.newLine();
            }
        }
        System.out.printf("  Worldmap updated: %d roads injected, %d features removed, %d features clipped.%n",
                injectedRoads, removedFeatures, clippedFeatures);

        // ── Step 4: Regenerate worldmap.xml.bin ──
        System.out.println("  Regenerating worldmap.xml.bin...");
        try {
            String cp = System.getProperty("java.class.path");
            ProcessBuilder pb = new ProcessBuilder(
                    "java", "-cp", cp,
                    "com.apocalipsebr.tools.mapconverter.ConvertMap",
                    "--gen-bin", mapDir.getAbsolutePath());
            pb.inheritIO();
            int exitCode = pb.start().waitFor();
            if (exitCode == 0) {
                System.out.println("  worldmap.xml.bin regenerated OK.");
            } else {
                System.err.println("  WARN: ConvertMap --gen-bin exited with code " + exitCode);
            }
        } catch (Exception e) {
            System.err.println("  WARN: Could not regenerate worldmap.xml.bin: " + e.getMessage());
            System.err.println("  Run option [4] in MapTools to regenerate manually.");
        }
    }

    // ========================== Main ==========================

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            printUsage();
            System.exit(1);
        }

        String mode = args[0];
        File mapDir = new File(args[1]);
        if (!mapDir.isDirectory()) {
            System.err.println("Not a directory: " + mapDir);
            System.exit(1);
        }

        switch (mode) {
            case "--inspect": {
                if (args.length < 3) { printUsage(); System.exit(1); }
                int[] cc = parseCellCoords(args[2]);
                int[] chunkFilter = (args.length >= 4) ? parseChunkCoords(args[3]) : null;
                doInspect(mapDir, cc[0], cc[1], chunkFilter);
                break;
            }
            case "--inspect-at": {
                if (args.length < 5) { printUsage(); System.exit(1); }
                doInspectAt(mapDir,
                        Integer.parseInt(args[2]), Integer.parseInt(args[3]),
                        Integer.parseInt(args[4]));
                break;
            }
            case "--search": {
                if (args.length < 4) { printUsage(); System.exit(1); }
                doSearch(mapDir, parseCellCoords(args[2]), args[3]);
                break;
            }
            case "--remove": {
                if (args.length < 6) { printUsage(); System.exit(1); }
                doRemove(mapDir,
                        Integer.parseInt(args[2]), Integer.parseInt(args[3]),
                        Integer.parseInt(args[4]), args[5]);
                break;
            }
            case "--set": {
                if (args.length < 7) { printUsage(); System.exit(1); }
                doSet(mapDir,
                        Integer.parseInt(args[2]), Integer.parseInt(args[3]),
                        Integer.parseInt(args[4]), args[5], args[6]);
                break;
            }
            case "--add": {
                if (args.length < 6) { printUsage(); System.exit(1); }
                doAdd(mapDir,
                        Integer.parseInt(args[2]), Integer.parseInt(args[3]),
                        Integer.parseInt(args[4]), args[5]);
                break;
            }
            case "--patch": {
                if (args.length < 3) { printUsage(); System.exit(1); }
                File worldmapFile = (args.length >= 4) ? new File(args[3]) : null;
                doPatch(mapDir, new File(args[2]), worldmapFile);
                break;
            }
            default:
                System.err.println("Unknown mode: " + mode);
                printUsage();
                System.exit(1);
        }
    }

    static void printUsage() {
        System.out.println("LotpackEditor — Inspect and edit B42 .lotpack tile objects");
        System.out.println();
        System.out.println("Usage:");
        System.out.println("  --inspect    <mapDir> <cellX_cellY> [chunkX,chunkY]");
        System.out.println("               Show all objects (summary, or detailed for one chunk).");
        System.out.println();
        System.out.println("  --inspect-at <mapDir> <worldX> <worldY> <z>");
        System.out.println("               Show all objects stacked at a specific world coordinate.");
        System.out.println("               Cell is auto-derived from coords.");
        System.out.println();
        System.out.println("  --search     <mapDir> <cellX_cellY> <tileName>");
        System.out.println("               Find all squares containing a specific tile name.");
        System.out.println();
        System.out.println("  --remove     <mapDir> <worldX> <worldY> <z> <tileName>");
        System.out.println("               Remove a tile object at a world coordinate.");
        System.out.println();
        System.out.println("  --set        <mapDir> <worldX> <worldY> <z> <oldTile> <newTile>");
        System.out.println("               Change a tile to a different one at a coordinate.");
        System.out.println();
        System.out.println("  --add        <mapDir> <worldX> <worldY> <z> <tileName>");
        System.out.println("               Add a new tile object at a coordinate.");
        System.out.println();
        System.out.println("  --patch      <mapDir> <patchFile.csv> [worldmap.xml]");
        System.out.println("               Batch operations from CSV. Format per line:");
        System.out.println("               action, worldX, worldY, z, tileName[, newTile]");
        System.out.println("               or: removeAllRange, x1, y1, z1, x2, y2, z2");
        System.out.println("               or: addAllRange, x1, y1, z1, x2, y2, z2, tileName");
        System.out.println("               or: removeAllBut, x, y, z, tileName");
        System.out.println("               Actions: add, remove, set, removeAllRange, addAllRange, removeAllBut");
        System.out.println();
        System.out.println("               Worldmap sync (optional - requires worldmap.xml path):");
        System.out.println("               Road polygons: 'add' at z=0 of 'blends_street_01_85' emits");
        System.out.println("                 tertiary highway polygons in worldmap.xml.");
        System.out.println("               Polygon clipping: removeAllRange clear areas automatically clip");
        System.out.println("                 overlapping worldmap features (forest, vegetation, buildings, etc.).");
        System.out.println("               worldmap.xml.bin is auto-regenerated after sync.");
        System.out.println();
        System.out.println("World coordinates are absolute tile positions (use -debug in-game).");
        System.out.println("Cell is auto-derived: cellX = worldX / 256, cellY = worldY / 256.");
        System.out.println("Backups (.bak) are created before any write.");
    }

    // ========================== Helpers ==========================

    static int[] parseCellCoords(String s) {
        String[] p = s.split("_");
        if (p.length != 2) throw new IllegalArgumentException("Expected cellX_cellY, got: " + s);
        return new int[]{ Integer.parseInt(p[0]), Integer.parseInt(p[1]) };
    }

    static int[] parseChunkCoords(String s) {
        String[] p = s.split(",");
        if (p.length != 2) throw new IllegalArgumentException("Expected chunkX,chunkY, got: " + s);
        return new int[]{ Integer.parseInt(p[0]), Integer.parseInt(p[1]) };
    }

    static String tileListStr(CellData cell, List<Integer> tl) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < tl.size(); i++) {
            if (i > 0) sb.append(", ");
            sb.append(cell.tileName(tl.get(i)));
        }
        return sb.toString();
    }

    static void backup(File file) throws IOException {
        File bak = new File(file.getPath() + ".bak");
        if (!bak.exists()) {
            copyFile(file, bak);
            backedUpFiles.add(file);
            System.out.println("  Backed up: " + bak.getName());
        }
    }

    // ========================== Binary I/O ==========================

    static int readIntLE(RandomAccessFile raf) throws IOException {
        int b0 = raf.read(), b1 = raf.read(), b2 = raf.read(), b3 = raf.read();
        if ((b0 | b1 | b2 | b3) < 0) throw new EOFException();
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
    }

    static int readIntLE(byte[] data, int offset) {
        return (data[offset] & 0xFF)
             | ((data[offset + 1] & 0xFF) << 8)
             | ((data[offset + 2] & 0xFF) << 16)
             | ((data[offset + 3] & 0xFF) << 24);
    }

    static String readString(RandomAccessFile raf) throws IOException {
        StringBuilder sb = new StringBuilder();
        int c;
        while ((c = raf.read()) != -1 && c != '\n') {
            if (c != '\r') sb.append((char) c);
        }
        return sb.toString();
    }

    static void writeIntLE(OutputStream out, int v) throws IOException {
        out.write(v & 0xFF);
        out.write((v >> 8) & 0xFF);
        out.write((v >> 16) & 0xFF);
        out.write((v >> 24) & 0xFF);
    }

    static byte[] readAllBytes(File file) throws IOException {
        byte[] data = new byte[(int) file.length()];
        try (FileInputStream fis = new FileInputStream(file)) {
            int off = 0;
            while (off < data.length) {
                int n = fis.read(data, off, data.length - off);
                if (n < 0) break;
                off += n;
            }
        }
        return data;
    }

    static void copyFile(File src, File dst) throws IOException {
        try (FileInputStream fis = new FileInputStream(src);
             FileOutputStream fos = new FileOutputStream(dst)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = fis.read(buf)) > 0) fos.write(buf, 0, n);
        }
    }
}

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
 *   --patch      &lt;mapDir&gt; &lt;patchFile.csv&gt;
 *
 * Patch CSV actions: add, remove, set, removeAllRange, addAllRange, removeAllBut
 *   removeAllRange: x1, y1, z1, x2, y2, z2 — clears ALL objects in the 3D box.
 *   addAllRange:    x1, y1, z1, x2, y2, z2, tileName — adds a tile to every square in the 3D box.
 *   removeAllBut:   x, y, z, tileName — removes all objects EXCEPT the named tile.
 *
 * World coordinates are absolute tile positions (use -debug tile inspector in-game).
 * Cell is auto-derived: cellX = worldX / 256, cellY = worldY / 256.
 */
public class LotpackEditor {

    static final int CHUNK_DIM = 8;
    static final int CHUNKS_PER_CELL = 32;
    static final int CELL_DIM = 256; // CHUNK_DIM * CHUNKS_PER_CELL

    static final byte[] LOTH_MAGIC = { 'L', 'O', 'T', 'H' };
    static final byte[] LOTP_MAGIC = { 'L', 'O', 'T', 'P' };

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

    static void doPatch(File mapDir, File patchFile) throws IOException {
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
        System.out.printf("Loaded %d operations from %s%n", operations.size(), patchFile.getName());

        // Pre-expand removeAllRange into individual _removeall ops
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
                doPatch(mapDir, new File(args[2]));
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
        System.out.println("  --patch      <mapDir> <patchFile.csv>");
        System.out.println("               Batch operations from CSV. Format per line:");
        System.out.println("               action, worldX, worldY, z, tileName[, newTile]");
        System.out.println("               or: removeAllRange, x1, y1, z1, x2, y2, z2");
        System.out.println("               or: addAllRange, x1, y1, z1, x2, y2, z2, tileName");
        System.out.println("               or: removeAllBut, x, y, z, tileName");
        System.out.println("               Actions: add, remove, set, removeAllRange, addAllRange, removeAllBut");
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

package com.apocalipsebr.tools.mapconverter;

import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;

/**
 * Standalone Project Zomboid B41→B42 map converter.
 * Converts map files from 300-cell (10×10 chunks, 30×30 grid) to 256-cell (8×8 chunks, 32×32 grid).
 *
 * Ported from the game's zombie.pot.POT converter logic (decompiled source).
 *
 * Binary formats handled:
 * - .lotheader (LOTH magic, version 0/1)
 * - .lotpack (LOTP magic, version 0/1)
 * - chunkdata_X_Y.bin
 *
 * Text formats handled:
 * - objects.lua (zone coordinates — copied as-is, uses absolute world coords)
 * - spawnpoints.lua (copied as-is — uses 300-unit cell coordinate system)
 * - worldmap.xml (copied as-is — uses 300-unit cell coordinate system)
 *
 * NOTE: worldmap.xml and spawnpoints.lua always use the 300-unit cell grid
 * for positioning (absolute = cellX * 300 + point). The game resolves these
 * with a fixed 300 multiplier regardless of binary lot cell size (256 in B42).
 */
public class ConvertMap {

    // Old B41 constants
    static final int CHUNK_DIM_OLD = 10;
    static final int CHUNKS_PER_CELL_OLD = 30;
    static final int CELL_DIM_OLD = 300;

    // New B42 constants
    static final int CHUNK_DIM_NEW = 8;
    static final int CHUNKS_PER_CELL_NEW = 32;
    static final int CELL_DIM_NEW = 256;

    static final int LEVELS = 64; // -32 to 31

    // Magic bytes
    static final byte[] LOTH_MAGIC = { 'L', 'O', 'T', 'H' };
    static final byte[] LOTP_MAGIC = { 'L', 'O', 'T', 'P' };

    // ========================== Data classes ==========================

    static class RoomRect {
        int x, y, w, h;
        RoomRect(int x, int y, int w, int h) { this.x = x; this.y = y; this.w = w; this.h = h; }
        int getX2() { return x + w; }
        int getY2() { return y + h; }
    }

    static class MetaObject {
        int type, x, y;
        MetaObject(int type, int x, int y) { this.type = type; this.x = x; this.y = y; }
    }

    static class RoomDef {
        long id;
        String name;
        int level;
        final List<RoomRect> rects = new ArrayList<>();
        final List<MetaObject> objects = new ArrayList<>();
        int x = 10000000, y = 10000000, x2 = -1000000, y2 = -1000000;
        int area;

        RoomDef(long id, String name) { this.id = id; this.name = name; }

        void calculateBounds() {
            x = 10000000; y = 10000000; x2 = -1000000; y2 = -1000000; area = 0;
            for (RoomRect r : rects) {
                if (r.x < x) x = r.x;
                if (r.y < y) y = r.y;
                if (r.x + r.w > x2) x2 = r.x + r.w;
                if (r.y + r.h > y2) y2 = r.y + r.h;
                area += r.w * r.h;
            }
        }
    }

    static class BuildingDef {
        long id;
        final List<RoomDef> rooms = new ArrayList<>();
        int x = Integer.MAX_VALUE, y = Integer.MAX_VALUE;
        int x2 = Integer.MIN_VALUE, y2 = Integer.MIN_VALUE;

        void calculateBounds() {
            x = Integer.MAX_VALUE; y = Integer.MAX_VALUE;
            x2 = Integer.MIN_VALUE; y2 = Integer.MIN_VALUE;
            for (RoomDef r : rooms) {
                for (RoomRect rect : r.rects) {
                    if (rect.x < x) x = rect.x;
                    if (rect.y < y) y = rect.y;
                    if (rect.x + rect.w > x2) x2 = rect.x + rect.w;
                    if (rect.y + rect.h > y2) y2 = rect.y + rect.h;
                }
            }
        }
    }

    // ========================== LotHeader ==========================

    static class LotHeaderData {
        final boolean pot;
        final int chunkDim, chunksPerCell, cellDim;
        final int cellX, cellY;
        int width, height;
        int minLevel = -32, maxLevel = 31;
        int minLevelNotEmpty = 1000, maxLevelNotEmpty = -1000;
        int version;
        final Map<Long, RoomDef> roomMap = new HashMap<>();
        final List<RoomDef> roomList = new ArrayList<>();
        final List<BuildingDef> buildings = new ArrayList<>();
        final List<String> tilesUsed = new ArrayList<>();
        final Map<String, Integer> tileIndex = new HashMap<>();
        final byte[] zombieDensity;

        LotHeaderData(int cellX, int cellY, boolean pot) {
            this.pot = pot;
            this.cellX = cellX;
            this.cellY = cellY;
            this.chunkDim = pot ? CHUNK_DIM_NEW : CHUNK_DIM_OLD;
            this.chunksPerCell = pot ? CHUNKS_PER_CELL_NEW : CHUNKS_PER_CELL_OLD;
            this.cellDim = pot ? CELL_DIM_NEW : CELL_DIM_OLD;
            this.width = chunkDim;
            this.height = chunkDim;
            this.zombieDensity = new byte[chunksPerCell * chunksPerCell];
        }

        int getMinSquareX() { return cellX * cellDim; }
        int getMinSquareY() { return cellY * cellDim; }
        int getMaxSquareX() { return (cellX + 1) * cellDim - 1; }
        int getMaxSquareY() { return (cellY + 1) * cellDim - 1; }

        boolean containsSquare(int sx, int sy) {
            return sx >= getMinSquareX() && sx <= getMaxSquareX()
                && sy >= getMinSquareY() && sy <= getMaxSquareY();
        }

        byte getZombieDensityForSquare(int squareX, int squareY) {
            if (!containsSquare(squareX, squareY)) return 0;
            int lx = squareX - getMinSquareX();
            int ly = squareY - getMinSquareY();
            return zombieDensity[lx / chunkDim + ly / chunkDim * chunksPerCell];
        }

        void setZombieDensityFromSquares(byte[] perSquare) {
            for (int cy = 0; cy < chunksPerCell; cy++) {
                for (int cx = 0; cx < chunksPerCell; cx++) {
                    int density = 0;
                    for (int n = 0; n < chunkDim * chunkDim; n++) {
                        int idx = cx * chunkDim + cy * chunkDim * cellDim
                                + n % chunkDim + n / chunkDim * cellDim;
                        density += (perSquare[idx] & 0xFF);
                    }
                    zombieDensity[cx + cy * chunksPerCell] = (byte)(density / (chunkDim * chunkDim));
                }
            }
        }

        int getTileIndex(String tileName) {
            Integer idx = tileIndex.get(tileName);
            if (idx == null) {
                idx = tilesUsed.size();
                tileIndex.put(tileName, idx);
                tilesUsed.add(tileName);
            }
            return idx;
        }

        void addBuilding(BuildingDef src) {
            BuildingDef bnew = new BuildingDef();
            int buildingIndex = buildings.size();
            bnew.id = makeBuildingID(cellX, cellY, buildingIndex);
            for (RoomDef rd : src.rooms) {
                int roomIndex = roomList.size();
                RoomDef rn = new RoomDef(makeRoomID(cellX, cellY, roomIndex), rd.name);
                rn.level = rd.level;
                rn.rects.addAll(rd.rects);
                rn.objects.addAll(rd.objects);
                rn.calculateBounds();
                bnew.rooms.add(rn);
                roomMap.put(rn.id, rn);
                roomList.add(rn);
            }
            bnew.calculateBounds();
            buildings.add(bnew);
        }
    }

    // ========================== Binary I/O Helpers ==========================

    /** Read a little-endian 32-bit int from RandomAccessFile */
    static int readIntLE(RandomAccessFile raf) throws IOException {
        int b0 = raf.read(); int b1 = raf.read(); int b2 = raf.read(); int b3 = raf.read();
        if ((b0 | b1 | b2 | b3) < 0) throw new EOFException();
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
    }

    /** Read a newline-terminated string */
    static String readString(RandomAccessFile raf) throws IOException {
        StringBuilder sb = new StringBuilder();
        int c;
        while ((c = raf.read()) != -1 && c != '\n') {
            if (c != '\r') sb.append((char) c);
        }
        return sb.toString();
    }

    /** Write little-endian int to ByteBuffer */
    static void putIntLE(ByteBuffer bb, int v) { bb.putInt(v); }

    /** Write newline-terminated string */
    static void putString(ByteBuffer bb, String s) {
        bb.put(s.getBytes(StandardCharsets.UTF_8));
        bb.put((byte) '\n');
    }

    // ========================== LotHeader Load/Save ==========================

    static LotHeaderData loadLotHeader(File file, int cellX, int cellY) throws IOException {
        LotHeaderData hdr = new LotHeaderData(cellX, cellY, false);
        try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
            byte[] magic = new byte[4];
            raf.read(magic, 0, 4);
            boolean hasMagic = Arrays.equals(magic, LOTH_MAGIC);
            if (!hasMagic) raf.seek(0);

            hdr.version = readIntLE(raf);
            if (hdr.version < 0 || hdr.version > 1)
                throw new IOException("Unsupported lotheader version " + hdr.version + " in " + file);

            int tileCount = readIntLE(raf);
            for (int i = 0; i < tileCount; i++) {
                String s = readString(raf).trim();
                hdr.tilesUsed.add(s);
                hdr.tileIndex.put(s, i);
            }

            if (hdr.version == 0) raf.read(); // skip 1 byte

            hdr.width = readIntLE(raf);
            hdr.height = readIntLE(raf);

            if (hdr.version == 0) {
                hdr.minLevel = 0;
                hdr.maxLevel = readIntLE(raf);
            } else {
                hdr.minLevel = readIntLE(raf);
                hdr.maxLevel = readIntLE(raf);
            }
            hdr.minLevelNotEmpty = hdr.minLevel;
            hdr.maxLevelNotEmpty = hdr.maxLevel;

            // Rooms
            int numRooms = readIntLE(raf);
            for (int i = 0; i < numRooms; i++) {
                String name = readString(raf);
                long roomID = makeRoomID(cellX, cellY, i);
                RoomDef rd = new RoomDef(roomID, name);
                rd.level = readIntLE(raf);
                int numRects = readIntLE(raf);
                for (int r = 0; r < numRects; r++) {
                    int rx = readIntLE(raf);
                    int ry = readIntLE(raf);
                    int rw = readIntLE(raf);
                    int rh = readIntLE(raf);
                    rd.rects.add(new RoomRect(rx + cellX * hdr.cellDim, ry + cellY * hdr.cellDim, rw, rh));
                }
                rd.calculateBounds();
                hdr.roomMap.put(rd.id, rd);
                hdr.roomList.add(rd);

                int numObjects = readIntLE(raf);
                for (int m = 0; m < numObjects; m++) {
                    int e = readIntLE(raf);
                    int ox = readIntLE(raf);
                    int oy = readIntLE(raf);
                    rd.objects.add(new MetaObject(e,
                        ox + cellX * hdr.cellDim - rd.x,
                        oy + cellY * hdr.cellDim - rd.y));
                }
            }

            // Buildings
            int numBuildings = readIntLE(raf);
            for (int i = 0; i < numBuildings; i++) {
                BuildingDef bd = new BuildingDef();
                bd.id = makeBuildingID(cellX, cellY, i);
                int nRooms = readIntLE(raf);
                for (int r = 0; r < nRooms; r++) {
                    int roomIdx = readIntLE(raf);
                    long roomID = makeRoomID(cellX, cellY, roomIdx);
                    RoomDef rd = hdr.roomMap.get(roomID);
                    bd.rooms.add(rd);
                }
                bd.calculateBounds();
                hdr.buildings.add(bd);
            }

            // Zombie density
            for (int x = 0; x < hdr.chunksPerCell; x++) {
                for (int y = 0; y < hdr.chunksPerCell; y++) {
                    hdr.zombieDensity[x + y * hdr.chunksPerCell] = (byte) raf.read();
                }
            }
        }
        return hdr;
    }

    static void saveLotHeader(LotHeaderData hdr, String fileName) throws IOException {
        ByteBuffer bb = ByteBuffer.allocate(10 * 1024 * 1024);
        bb.order(ByteOrder.LITTLE_ENDIAN);

        bb.put(LOTH_MAGIC);
        bb.putInt(1); // version

        bb.putInt(hdr.tilesUsed.size());
        for (String tile : hdr.tilesUsed) putString(bb, tile);

        bb.putInt(hdr.width);
        bb.putInt(hdr.height);
        bb.putInt(hdr.minLevelNotEmpty);
        bb.putInt(hdr.maxLevelNotEmpty);

        // Rooms
        bb.putInt(hdr.roomList.size());
        for (RoomDef rd : hdr.roomList) {
            putString(bb, rd.name);
            bb.putInt(rd.level);
            bb.putInt(rd.rects.size());
            for (RoomRect rr : rd.rects) {
                bb.putInt(rr.x - hdr.getMinSquareX());
                bb.putInt(rr.y - hdr.getMinSquareY());
                bb.putInt(rr.w);
                bb.putInt(rr.h);
            }
            bb.putInt(rd.objects.size());
            for (MetaObject mo : rd.objects) {
                bb.putInt(mo.type);
                bb.putInt(mo.x);
                bb.putInt(mo.y);
            }
        }

        // Buildings
        bb.putInt(hdr.buildings.size());
        for (BuildingDef bd : hdr.buildings) {
            bb.putInt(bd.rooms.size());
            for (RoomDef rd : bd.rooms) {
                bb.putInt(hdr.roomList.indexOf(rd));
            }
        }

        // Zombie density
        for (int x = 0; x < hdr.chunksPerCell; x++) {
            for (int y = 0; y < hdr.chunksPerCell; y++) {
                bb.put(hdr.zombieDensity[x + y * hdr.chunksPerCell]);
            }
        }

        writeBuffer(bb, fileName);
    }

    // ========================== LotPack ==========================

    static class LotPackData {
        final LotHeaderData header;
        final boolean pot;
        final int chunkDim, chunksPerCell, cellDim;
        final int cellX, cellY;
        int version;
        final int[] offsetInData;
        final List<Integer> data = new ArrayList<>();

        LotPackData(LotHeaderData hdr) {
            this.header = hdr;
            this.pot = hdr.pot;
            this.cellX = hdr.cellX;
            this.cellY = hdr.cellY;
            this.chunkDim = hdr.chunkDim;
            this.chunksPerCell = hdr.chunksPerCell;
            this.cellDim = hdr.cellDim;
            int levels = hdr.maxLevel - hdr.minLevel + 1;
            this.offsetInData = new int[cellDim * cellDim * levels];
            Arrays.fill(offsetInData, -1);
        }

        String[] getSquareData(int squareX, int squareY, int z) {
            int lx = squareX - header.getMinSquareX();
            int ly = squareY - header.getMinSquareY();
            int idx = lx + ly * cellDim + (z - header.minLevel) * cellDim * cellDim;
            int offset = offsetInData[idx];
            if (offset == -1) return null;
            int count = data.get(offset);
            String[] result = new String[count];
            for (int i = 0; i < count; i++) {
                result[i] = header.tilesUsed.get(data.get(offset + 1 + i));
            }
            return result;
        }

        void setSquareData(int squareX, int squareY, int z, String[] tiles) {
            if (z < header.minLevel || z > header.maxLevel) return;
            int lx = squareX - header.getMinSquareX();
            int ly = squareY - header.getMinSquareY();
            int idx = lx + ly * cellDim + (z - header.minLevel) * cellDim * cellDim;
            if (tiles == null || tiles.length == 0) {
                offsetInData[idx] = -1;
                return;
            }
            offsetInData[idx] = data.size();
            data.add(tiles.length);
            for (String tile : tiles) {
                data.add(header.getTileIndex(tile));
            }
            header.minLevelNotEmpty = Math.min(header.minLevelNotEmpty, z);
            header.maxLevelNotEmpty = Math.max(header.maxLevelNotEmpty, z);
        }
    }

    static LotPackData loadLotPack(File file, LotHeaderData hdr) throws IOException {
        LotPackData pack = new LotPackData(hdr);
        try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
            byte[] magic = new byte[4];
            raf.read(magic, 0, 4);
            boolean hasMagic = Arrays.equals(magic, LOTP_MAGIC);
            if (hasMagic) {
                pack.version = readIntLE(raf);
                if (pack.version < 0 || pack.version > 1)
                    throw new IOException("Unsupported lotpack version " + pack.version);
            } else {
                raf.seek(0);
                pack.version = 0;
            }

            int headerOffset = pack.version >= 1 ? 8 : 0;

            for (int cx = 0; cx < hdr.chunksPerCell; cx++) {
                for (int cy = 0; cy < hdr.chunksPerCell; cy++) {
                    int index = cx * hdr.chunksPerCell + cy;
                    raf.seek(headerOffset + 4 + (long) index * 8);
                    int pos = readIntLE(raf);
                    raf.seek(pos);

                    int minZ = Math.max(hdr.minLevel, -32);
                    int maxZ = Math.min(hdr.maxLevel, 31);
                    if (pack.version == 0) maxZ--;

                    int skip = 0;
                    for (int z = minZ; z <= maxZ; z++) {
                        for (int x = 0; x < hdr.chunkDim; x++) {
                            for (int y = 0; y < hdr.chunkDim; y++) {
                                int squareIdx = x + y * hdr.cellDim
                                    + cx * hdr.chunkDim
                                    + cy * hdr.chunkDim * hdr.cellDim
                                    + (z - hdr.minLevel) * hdr.cellDim * hdr.cellDim;
                                pack.offsetInData[squareIdx] = -1;

                                if (skip > 0) { skip--; continue; }

                                int count = readIntLE(raf);
                                if (count == -1) {
                                    skip = readIntLE(raf);
                                    if (skip > 0) { skip--; continue; }
                                }
                                if (count > 1) {
                                    pack.offsetInData[squareIdx] = pack.data.size();
                                    pack.data.add(count - 1);
                                    int roomID = readIntLE(raf); // skip room ID
                                    for (int n = 1; n < count; n++) {
                                        pack.data.add(readIntLE(raf));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return pack;
    }

    static void saveLotPack(LotPackData pack, String fileName) throws IOException {
        int numChunks = pack.chunksPerCell * pack.chunksPerCell;
        ByteBuffer bb = ByteBuffer.allocate(10 * 1024 * 1024);
        bb.order(ByteOrder.LITTLE_ENDIAN);

        bb.put(LOTP_MAGIC);
        bb.putInt(1); // version
        bb.putInt(pack.chunkDim);

        int chunkTableStart = bb.position();
        bb.position(chunkTableStart + numChunks * 8);

        for (int cx = 0; cx < pack.chunksPerCell; cx++) {
            for (int cy = 0; cy < pack.chunksPerCell; cy++) {
                // Write the offset for this chunk in the table (4-byte int, 8-byte stride)
                int tableIdx = chunkTableStart + (cx * pack.chunksPerCell + cy) * 8;
                bb.putInt(tableIdx, bb.position());

                int notdonecount = 0;
                for (int z = pack.header.minLevelNotEmpty; z <= pack.header.maxLevelNotEmpty; z++) {
                    for (int x = 0; x < pack.chunkDim; x++) {
                        for (int y = 0; y < pack.chunkDim; y++) {
                            int squareIdx = x + y * pack.cellDim
                                + (z - pack.header.minLevel) * pack.cellDim * pack.cellDim
                                + cx * pack.chunkDim
                                + cy * pack.chunkDim * pack.cellDim;
                            int offset = pack.offsetInData[squareIdx];
                            if (offset == -1) {
                                notdonecount++;
                            } else {
                                if (notdonecount > 0) {
                                    bb.putInt(-1);
                                    bb.putInt(notdonecount);
                                    notdonecount = 0;
                                }
                                int numTiles = pack.data.get(offset);
                                bb.putInt(numTiles + 1);
                                bb.putInt(-1); // roomID
                                for (int i = 0; i < numTiles; i++) {
                                    bb.putInt(pack.data.get(offset + 1 + i));
                                }
                            }
                        }
                    }
                }
                if (notdonecount > 0) {
                    bb.putInt(-1);
                    bb.putInt(notdonecount);
                }
            }
        }

        writeBuffer(bb, fileName);
    }

    // ========================== ChunkData ==========================

    static final int BIT_SOLID = 1, BIT_WALLN = 2, BIT_WALLW = 4, BIT_WATER = 8, BIT_ROOM = 16;
    static final int EMPTY_CHUNK = 0, SOLID_CHUNK = 1, REGULAR_CHUNK = 2, WATER_CHUNK = 3, ROOM_CHUNK = 4;

    static class ChunkDataCell {
        final boolean pot;
        final int chunkDim, chunksPerCell, cellDim;
        final int cellX, cellY;
        final byte[][] chunkBits; // per chunk: null means uniform, byte[chunkDim²] otherwise
        final int[][] chunkCounts; // per chunk: counts[5]

        ChunkDataCell(int cellX, int cellY, boolean pot) {
            this.pot = pot;
            this.cellX = cellX;
            this.cellY = cellY;
            this.chunkDim = pot ? CHUNK_DIM_NEW : CHUNK_DIM_OLD;
            this.chunksPerCell = pot ? CHUNKS_PER_CELL_NEW : CHUNKS_PER_CELL_OLD;
            this.cellDim = pot ? CELL_DIM_NEW : CELL_DIM_OLD;
            int n = chunksPerCell * chunksPerCell;
            chunkBits = new byte[n][];
            chunkCounts = new int[n][5];
            for (int i = 0; i < n; i++) chunkCounts[i][0] = chunkDim * chunkDim;
        }

        int getMinSquareX() { return cellX * cellDim; }
        int getMinSquareY() { return cellY * cellDim; }
        int getMaxSquareX() { return (cellX + 1) * cellDim - 1; }
        int getMaxSquareY() { return (cellY + 1) * cellDim - 1; }

        boolean containsSquare(int sx, int sy) {
            return sx >= getMinSquareX() && sx <= getMaxSquareX()
                && sy >= getMinSquareY() && sy <= getMaxSquareY();
        }

        int typeOf(byte bits) {
            if (bits == 0) return 0;
            if (bits == 1) return 1;
            if (bits == 8) return 3;
            if (bits == 16) return 4;
            return 2;
        }

        int chunkType(int ci) {
            int nSqrs = chunkDim * chunkDim;
            if (chunkCounts[ci][0] == nSqrs) return EMPTY_CHUNK;
            if (chunkCounts[ci][1] == nSqrs) return SOLID_CHUNK;
            if (chunkCounts[ci][3] == nSqrs) return WATER_CHUNK;
            if (chunkCounts[ci][4] == nSqrs) return ROOM_CHUNK;
            return REGULAR_CHUNK;
        }

        byte getBits(int squareX, int squareY) {
            if (!containsSquare(squareX, squareY)) return 0;
            int cx = (squareX - getMinSquareX()) / chunkDim;
            int cy = (squareY - getMinSquareY()) / chunkDim;
            int ci = cx + cy * chunksPerCell;
            int nSqrs = chunkDim * chunkDim;
            if (chunkCounts[ci][0] == nSqrs) return 0;
            if (chunkCounts[ci][1] == nSqrs) return 1;
            if (chunkCounts[ci][3] == nSqrs) return 8;
            if (chunkCounts[ci][4] == nSqrs) return 16;
            int lx = (squareX - getMinSquareX()) % chunkDim;
            int ly = (squareY - getMinSquareY()) % chunkDim;
            return chunkBits[ci][lx + ly * chunkDim];
        }

        void setBits(int squareX, int squareY, byte bits) {
            int cx = (squareX - getMinSquareX()) / chunkDim;
            int cy = (squareY - getMinSquareY()) / chunkDim;
            int ci = cx + cy * chunksPerCell;
            int nSqrs = chunkDim * chunkDim;

            byte oldBits = getBits(squareX, squareY);
            int typeOld = typeOf(oldBits);
            int typeNew = typeOf(bits);

            if (typeOld == typeNew && typeOld != 2) return;

            chunkCounts[ci][typeOld]--;
            chunkCounts[ci][typeNew]++;

            if (chunkType(ci) == REGULAR_CHUNK) {
                if (chunkBits[ci] == null) {
                    chunkBits[ci] = new byte[nSqrs];
                    Arrays.fill(chunkBits[ci], oldBits);
                }
                int lx = (squareX - getMinSquareX()) % chunkDim;
                int ly = (squareY - getMinSquareY()) % chunkDim;
                chunkBits[ci][lx + ly * chunkDim] = bits;
            } else {
                chunkBits[ci] = null;
            }
        }
    }

    static ChunkDataCell loadChunkData(File file, int cellX, int cellY) throws IOException {
        ChunkDataCell cd = new ChunkDataCell(cellX, cellY, false);
        try (DataInputStream dis = new DataInputStream(new FileInputStream(file))) {
            int version = dis.readShort();
            for (int y = 0; y < cd.chunksPerCell; y++) {
                for (int x = 0; x < cd.chunksPerCell; x++) {
                    int ci = x + y * cd.chunksPerCell;
                    int nSqrs = cd.chunkDim * cd.chunkDim;
                    Arrays.fill(cd.chunkCounts[ci], 0);
                    int type = dis.readByte();
                    if (type == REGULAR_CHUNK) {
                        cd.chunkBits[ci] = new byte[nSqrs];
                        for (int i = 0; i < nSqrs; i++) {
                            cd.chunkBits[ci][i] = dis.readByte();
                            cd.chunkCounts[ci][cd.typeOf(cd.chunkBits[ci][i])]++;
                        }
                    } else {
                        cd.chunkCounts[ci][type] = nSqrs;
                    }
                }
            }
        }
        return cd;
    }

    static void saveChunkData(ChunkDataCell cd, String fileName) throws IOException {
        try (DataOutputStream dos = new DataOutputStream(new FileOutputStream(fileName))) {
            dos.writeShort(1); // version
            for (int y = 0; y < cd.chunksPerCell; y++) {
                for (int x = 0; x < cd.chunksPerCell; x++) {
                    int ci = x + y * cd.chunksPerCell;
                    int type = cd.chunkType(ci);
                    dos.writeByte(type);
                    if (type == REGULAR_CHUNK) {
                        dos.write(cd.chunkBits[ci]);
                    }
                }
            }
        }
    }

    // ========================== ID helpers ==========================

    static long makeRoomID(int cellX, int cellY, int index) {
        return ((long) cellX << 40) | ((long) cellY << 20) | index;
    }

    static long makeBuildingID(int cellX, int cellY, int index) {
        return ((long) cellX << 40) | ((long) cellY << 20) | index;
    }

    // ========================== File helper ==========================

    static void writeBuffer(ByteBuffer bb, String fileName) throws IOException {
        try (FileOutputStream fos = new FileOutputStream(fileName)) {
            fos.write(bb.array(), 0, bb.position());
        }
    }

    // ========================== Conversion Logic ==========================

    String inputDir, outputDir;
    int minX = Integer.MAX_VALUE, minY = Integer.MAX_VALUE;
    int maxX = Integer.MIN_VALUE, maxY = Integer.MIN_VALUE;
    final Map<Integer, File> lotHeaderFiles = new HashMap<>();
    final Map<Integer, File> lotPackFiles = new HashMap<>();
    final Map<Integer, File> chunkDataFiles = new HashMap<>();
    final Map<Integer, LotHeaderData> oldLotHeaders = new HashMap<>();
    final Map<Integer, LotPackData> oldLotPacks = new HashMap<>();
    final Map<Integer, ChunkDataCell> oldChunkDatas = new HashMap<>();
    final Map<Integer, LotHeaderData> newLotHeaders = new HashMap<>();
    final byte[] zombieDensityPerSquare = new byte[CELL_DIM_NEW * CELL_DIM_NEW];

    void readFileNames() {
        File dir = new File(inputDir);
        File[] files = dir.listFiles();
        if (files == null) return;

        for (File f : files) {
            String name = f.getName();
            int dotIdx = name.lastIndexOf('.');
            if (dotIdx < 0) continue;
            String suffix = name.substring(dotIdx);
            String base = name.substring(0, dotIdx);

            if (".lotheader".equals(suffix)) {
                String[] parts = base.split("_");
                int x = Integer.parseInt(parts[0]);
                int y = Integer.parseInt(parts[1]);
                minX = Math.min(minX, x); minY = Math.min(minY, y);
                maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
                lotHeaderFiles.put(x + y * 1000, f);
            } else if (".lotpack".equals(suffix)) {
                String stripped = base.replace("world_", "");
                String[] parts = stripped.split("_");
                int x = Integer.parseInt(parts[0]);
                int y = Integer.parseInt(parts[1]);
                lotPackFiles.put(x + y * 1000, f);
            } else if (base.startsWith("chunkdata_") && ".bin".equals(suffix)) {
                String stripped = base.replace("chunkdata_", "");
                String[] parts = stripped.split("_");
                int x = Integer.parseInt(parts[0]);
                int y = Integer.parseInt(parts[1]);
                chunkDataFiles.put(x + y * 1000, f);
            }
        }

        System.out.println("Found cells: X[" + minX + ".." + maxX + "] Y[" + minY + ".." + maxY + "]");
        System.out.println("  " + lotHeaderFiles.size() + " .lotheader files");
        System.out.println("  " + lotPackFiles.size() + " .lotpack files");
        System.out.println("  " + chunkDataFiles.size() + " chunkdata files");
    }

    LotHeaderData getOldLotHeader(int cellX, int cellY) throws IOException {
        int key = cellX + cellY * 1000;
        File f = lotHeaderFiles.get(key);
        if (f == null) return null;
        LotHeaderData hdr = oldLotHeaders.get(key);
        if (hdr == null) {
            hdr = loadLotHeader(f, cellX, cellY);
            oldLotHeaders.put(key, hdr);
        }
        return hdr;
    }

    LotPackData getOldLotPack(LotHeaderData hdr) throws IOException {
        int key = hdr.cellX + hdr.cellY * 1000;
        LotPackData pack = oldLotPacks.get(key);
        if (pack == null) {
            File f = lotPackFiles.get(key);
            pack = loadLotPack(f, hdr);
            oldLotPacks.put(key, pack);
        }
        return pack;
    }

    ChunkDataCell getOldChunkData(int cellX, int cellY) throws IOException {
        int key = cellX + cellY * 1000;
        File f = chunkDataFiles.get(key);
        if (f == null) return null;
        ChunkDataCell cd = oldChunkDatas.get(key);
        if (cd == null) {
            cd = loadChunkData(f, cellX, cellY);
            oldChunkDatas.put(key, cd);
        }
        return cd;
    }

    LotHeaderData getNewLotHeader(int newCellX, int newCellY) {
        int key = newCellX + newCellY * 1000;
        LotHeaderData hdr = newLotHeaders.get(key);
        if (hdr == null) {
            hdr = new LotHeaderData(newCellX, newCellY, true);
            newLotHeaders.put(key, hdr);
        }
        return hdr;
    }

    String[] getOldSquareData(int squareX, int squareY, int z) throws IOException {
        LotHeaderData hdr = getOldLotHeader(squareX / CELL_DIM_OLD, squareY / CELL_DIM_OLD);
        if (hdr == null || !hdr.containsSquare(squareX, squareY)) return null;
        if (z < hdr.minLevel || z > hdr.maxLevel) return null;
        LotPackData pack = getOldLotPack(hdr);
        return pack.getSquareData(squareX, squareY, z);
    }

    byte getOldChunkBits(int squareX, int squareY) throws IOException {
        ChunkDataCell cd = getOldChunkData(squareX / CELL_DIM_OLD, squareY / CELL_DIM_OLD);
        if (cd == null || !cd.containsSquare(squareX, squareY)) return 0;
        return cd.getBits(squareX, squareY);
    }

    // -- Main conversion pipeline --

    void convertLotHeaders() throws IOException {
        System.out.println("Converting lot headers...");
        for (int y = minY * CELL_DIM_OLD; y < (maxY + 1) * CELL_DIM_OLD; y += CELL_DIM_NEW) {
            for (int x = minX * CELL_DIM_OLD; x <= (maxX + 1) * CELL_DIM_OLD; x += CELL_DIM_NEW) {
                convertLotHeader(x / CELL_DIM_NEW, y / CELL_DIM_NEW);
            }
        }
    }

    void convertLotHeader(int newCellX, int newCellY) throws IOException {
        LotHeaderData newHdr = new LotHeaderData(newCellX, newCellY, true);
        int oldCellMinX = newCellX * CELL_DIM_NEW / CELL_DIM_OLD;
        int oldCellMinY = newCellY * CELL_DIM_NEW / CELL_DIM_OLD;
        int oldCellMaxX = ((newCellX + 1) * CELL_DIM_NEW - 1) / CELL_DIM_OLD;
        int oldCellMaxY = ((newCellY + 1) * CELL_DIM_NEW - 1) / CELL_DIM_OLD;

        Arrays.fill(zombieDensityPerSquare, (byte) 0);

        for (int oldCellY = oldCellMinY; oldCellY <= oldCellMaxY; oldCellY++) {
            for (int oldCellX = oldCellMinX; oldCellX <= oldCellMaxX; oldCellX++) {
                LotHeaderData oldHdr = getOldLotHeader(oldCellX, oldCellY);
                if (oldHdr == null) continue;

                for (BuildingDef bd : oldHdr.buildings) {
                    if (newHdr.containsSquare(bd.x, bd.y)) {
                        newHdr.addBuilding(bd);
                    }
                }

                for (int ly = 0; ly < CELL_DIM_NEW; ly++) {
                    for (int lx = 0; lx < CELL_DIM_NEW; lx++) {
                        int absX = newCellX * CELL_DIM_NEW + lx;
                        int absY = newCellY * CELL_DIM_NEW + ly;
                        zombieDensityPerSquare[lx + ly * CELL_DIM_NEW] =
                            oldHdr.getZombieDensityForSquare(absX, absY);
                    }
                }
            }
        }

        newHdr.setZombieDensityFromSquares(zombieDensityPerSquare);
        newLotHeaders.put(newCellX + newCellY * 1000, newHdr);
    }

    void convertLotPacks() throws IOException {
        System.out.println("Converting lot packs...");
        for (int y = minY * CELL_DIM_OLD; y < (maxY + 1) * CELL_DIM_OLD; y += CELL_DIM_NEW) {
            for (int x = minX * CELL_DIM_OLD; x < (maxX + 1) * CELL_DIM_OLD; x += CELL_DIM_NEW) {
                int newCellX = x / CELL_DIM_NEW;
                int newCellY = y / CELL_DIM_NEW;
                convertLotPack(newCellX, newCellY);

                // Free old cells no longer needed
                int oldCellX = x / CELL_DIM_OLD - 1;
                for (int y2 = minY; y2 <= maxY; y2++) {
                    for (int x2 = minX; x2 <= maxX; x2++) {
                        if (x2 == oldCellX && y2 == y / CELL_DIM_OLD) continue;
                        int key = x2 + y2 * 1000;
                        oldLotPacks.remove(key);
                        oldLotHeaders.remove(key);
                    }
                }
            }
        }
    }

    void convertLotPack(int newCellX, int newCellY) throws IOException {
        LotHeaderData newHdr = getNewLotHeader(newCellX, newCellY);
        newHdr.minLevelNotEmpty = 1000;
        newHdr.maxLevelNotEmpty = -1000;
        LotPackData newPack = new LotPackData(newHdr);

        int total = CELL_DIM_NEW * CELL_DIM_NEW * LEVELS;
        int done = 0;
        int lastPct = -1;

        for (int z = -32; z <= 31; z++) {
            for (int sy = newHdr.getMinSquareY(); sy <= newHdr.getMaxSquareY(); sy++) {
                for (int sx = newHdr.getMinSquareX(); sx <= newHdr.getMaxSquareX(); sx++) {
                    newPack.setSquareData(sx, sy, z, getOldSquareData(sx, sy, z));
                    done++;
                }
            }
            int pct = done * 100 / total;
            if (pct != lastPct && pct % 10 == 0) {
                System.out.println("  Cell " + newCellX + "_" + newCellY + ": " + pct + "%");
                lastPct = pct;
            }
        }

        String outHdr = String.format("%s%s%d_%d.lotheader", outputDir, File.separator, newCellX, newCellY);
        String outPack = String.format("%s%sworld_%d_%d.lotpack", outputDir, File.separator, newCellX, newCellY);
        saveLotHeader(newHdr, outHdr);
        saveLotPack(newPack, outPack);

        newLotHeaders.remove(newCellX + newCellY * 1000);
    }

    void convertChunkDatas() throws IOException {
        System.out.println("Converting chunk data...");
        for (int y = minY * CELL_DIM_OLD; y < (maxY + 1) * CELL_DIM_OLD; y += CELL_DIM_NEW) {
            for (int x = minX * CELL_DIM_OLD; x < (maxX + 1) * CELL_DIM_OLD; x += CELL_DIM_NEW) {
                int newCellX = x / CELL_DIM_NEW;
                int newCellY = y / CELL_DIM_NEW;
                convertChunkData(newCellX, newCellY);
            }
        }
    }

    void convertChunkData(int newCellX, int newCellY) throws IOException {
        ChunkDataCell newCd = new ChunkDataCell(newCellX, newCellY, true);
        for (int sy = newCd.getMinSquareY(); sy <= newCd.getMaxSquareY(); sy++) {
            for (int sx = newCd.getMinSquareX(); sx <= newCd.getMaxSquareX(); sx++) {
                newCd.setBits(sx, sy, getOldChunkBits(sx, sy));
            }
        }
        saveChunkData(newCd, String.format("%s%schunkdata_%d_%d.bin", outputDir, File.separator, newCellX, newCellY));
    }

    // ========================== Text file converters ==========================

    /**
     * objects.lua: coordinates are absolute world coordinates.
     * The x,y values stay the same since they are world-absolute.
     * No conversion needed for objects.lua in this map format -
     * the world coordinates remain the same regardless of cell size.
     */
    void convertObjectsLua() throws IOException {
        File src = new File(inputDir, "objects.lua");
        if (!src.exists()) return;
        System.out.println("Copying objects.lua (world-absolute coordinates, no remapping needed)...");
        Files.copy(src.toPath(), new File(outputDir, "objects.lua").toPath(), StandardCopyOption.REPLACE_EXISTING);
    }

    /**
     * spawnpoints.lua: worldX/worldY are cell coordinates, posX/posY are cell-relative.
     * The game resolves spawn positions using: absolute = worldX * 300 + posX.
     * The 300-unit cell multiplier is used by the game for spawnpoints.lua regardless of
     * whether the binary lot data uses B41 (300) or B42 (256) cell sizes.
     * Therefore, no conversion is needed — the file is copied as-is.
     * (Confirmed by comparing with Maplewood which has B42 binary lots at cells 31-33
     * but spawnpoints.lua still uses 300-based cell 27,28.)
     */
    void convertSpawnPointsLua() throws IOException {
        File src = new File(inputDir, "spawnpoints.lua");
        if (!src.exists()) return;
        System.out.println("Copying spawnpoints.lua (300-unit cell coordinates, no remapping needed)...");
        Files.copy(src.toPath(), new File(outputDir, "spawnpoints.lua").toPath(), StandardCopyOption.REPLACE_EXISTING);
    }

    /**
     * worldmap.xml: cell x/y and point x/y use the 300-unit cell coordinate system.
     * The game resolves feature positions using: absolute = cellX * 300 + pointX.
     * This multiplier is always 300, regardless of whether binary lot data uses
     * B41 (300) or B42 (256) cell sizes.
     * Therefore, no conversion is needed — the file is copied as-is.
     * (Confirmed by comparing with Maplewood: B42 binary lots at cells 31-33,
     * but worldmap.xml uses cell 27,28 with points 0-300, and
     * setBoundsInSquares starts at 27*300=8100.)
     */
    void convertWorldMapXml() throws IOException {
        File src = new File(inputDir, "worldmap.xml");
        if (!src.exists()) return;
        System.out.println("Copying worldmap.xml (300-unit cell coordinates, no remapping needed)...");
        Files.copy(src.toPath(), new File(outputDir, "worldmap.xml").toPath(), StandardCopyOption.REPLACE_EXISTING);
    }

    /**
     * Copy non-binary files that don't need coordinate remapping.
     */
    void copyOtherFiles() throws IOException {
        for (String name : new String[]{"map.info", "Description.txt"}) {
            File src = new File(inputDir, name);
            if (src.exists()) {
                System.out.println("Copying " + name + "...");
                Files.copy(src.toPath(), new File(outputDir, name).toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }

    // ========================== Main Pipeline ==========================

    public void convert(String inputDir, String outputDir) throws Exception {
        this.inputDir = inputDir;
        this.outputDir = outputDir;

        Files.createDirectories(Paths.get(outputDir));

        long startTime = System.currentTimeMillis();
        System.out.println("=== B41→B42 Map Converter ===");
        System.out.println("Input:  " + inputDir);
        System.out.println("Output: " + outputDir);
        System.out.println();

        readFileNames();

        if (lotHeaderFiles.isEmpty()) {
            System.out.println("No .lotheader files found! Aborting.");
            return;
        }

        convertLotHeaders();
        convertLotPacks();
        convertChunkDatas();
        convertObjectsLua();
        convertSpawnPointsLua();
        convertWorldMapXml();
        copyOtherFiles();

        long elapsed = System.currentTimeMillis() - startTime;
        System.out.println();
        System.out.println("=== Conversion complete in " + elapsed + "ms ===");
    }

    // ========================== Entry Point ==========================

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.out.println("Usage: java ConvertMap <inputDir> <outputDir>");
            System.out.println();
            System.out.println("Converts a Project Zomboid B41 map (300-cell, 10x10 chunks)");
            System.out.println("to B42 format (256-cell, 8x8 chunks).");
            System.exit(1);
        }

        new ConvertMap().convert(args[0], args[1]);
    }
}

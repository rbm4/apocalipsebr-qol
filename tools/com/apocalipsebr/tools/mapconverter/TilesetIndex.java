package com.apocalipsebr.tools.mapconverter;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import com.apocalipsebr.tools.mapconverter.TilesetIndex.TileRef;
import com.apocalipsebr.tools.mapconverter.TilesetIndex.TilesetMeta;

/**
 * Parses TileD's Tilesets.txt and builds a lookup table:
 *   spriteName ("walls_exterior_house_01_27") -> (tilesetName, localId).
 *
 * Tilesets.txt format (line-based, brace blocks):
 *   tileset {
 *       file = walls_exterior_house_01
 *       size = 8,12
 *   }
 *
 * Sprites in a tileset are numbered 0..(cols*rows-1) row-major.
 * Sprite name convention: "<tilesetFile>_<id>".
 */
public class TilesetIndex {

    /** Per-sprite reference into the tileset table. */
    public static class TileRef {
        public final String tileset;
        public final int    localId;
        TileRef(String tileset, int localId) {
            this.tileset = tileset;
            this.localId = localId;
        }
    }

    /** Per-tileset metadata. */
    public static class TilesetMeta {
        public final String name;
        public final int    cols;
        public final int    rows;
        public TilesetMeta(String name, int cols, int rows) {
            this.name = name;
            this.cols = cols;
            this.rows = rows;
        }
        public int tileCount() { return cols * rows; }
    }

    public final Map<String, TileRef>     sprites  = new HashMap<>();
    public final Map<String, TilesetMeta> tilesets = new LinkedHashMap<>();

    /** Parse a Tilesets.txt file and populate the index. */
    public static TilesetIndex load(File file) throws IOException {
        TilesetIndex idx = new TilesetIndex();
        String curFile = null;
        int    curCols = 0, curRows = 0;
        boolean inBlock = false;

        try (BufferedReader br = new BufferedReader(new FileReader(file))) {
            String line;
            while ((line = br.readLine()) != null) {
                String t = line.trim();
                if (t.isEmpty() || t.startsWith("//")) continue;

                if (t.equals("tileset")) {
                    curFile = null; curCols = curRows = 0; inBlock = false;
                    continue;
                }
                if (t.equals("{")) { inBlock = true; continue; }
                if (t.equals("}")) {
                    if (curFile != null && curCols > 0 && curRows > 0) {
                        idx.addTileset(curFile, curCols, curRows);
                    }
                    inBlock = false;
                    continue;
                }
                if (!inBlock) continue;

                if (t.startsWith("file")) {
                    int eq = t.indexOf('=');
                    if (eq > 0) curFile = t.substring(eq + 1).trim();
                } else if (t.startsWith("size")) {
                    int eq = t.indexOf('=');
                    if (eq > 0) {
                        String[] parts = t.substring(eq + 1).trim().split(",");
                        if (parts.length == 2) {
                            try {
                                curCols = Integer.parseInt(parts[0].trim());
                                curRows = Integer.parseInt(parts[1].trim());
                            } catch (NumberFormatException ignore) { }
                        }
                    }
                }
            }
        }
        return idx;
    }

    private void addTileset(String name, int cols, int rows) {
        tilesets.put(name, new TilesetMeta(name, cols, rows));
        int total = cols * rows;
        for (int i = 0; i < total; i++) {
            sprites.put(name + "_" + i, new TileRef(name, i));
        }
    }

    /** Lookup a sprite. Returns null if not in the index. */
    public TileRef lookup(String spriteName) {
        return sprites.get(spriteName);
    }

    /** Lookup tileset metadata by name. Returns null if missing. */
    public TilesetMeta meta(String tilesetName) {
        return tilesets.get(tilesetName);
    }
}

package com.apocalipsebr.tools.mapconverter;

import java.awt.Color;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.apocalipsebr.tools.mapconverter.ConvertMap.LotHeaderData;
import com.apocalipsebr.tools.mapconverter.ConvertMap.LotPackData;

/**
 * Driver: decompile a B41/B42 PZ map directory into a WorldEd-openable project.
 *
 * Usage:
 *   java com.apocalipsebr.tools.mapconverter.MapDecompiler \
 *       <inputMapDir> <outputDir> [tileDPath] [pzwTemplate]
 *
 * Steps:
 *   1. Discover cell coords from CX_CY.lotheader files.
 *   2. Load TilesetIndex from TileD/Tilesets.txt.
 *   3. For each cell: parse lotheader+lotpack, emit cells/CX_CY.tmx.
 *   4. Emit world .pzw referencing all cells.
 *   5. Emit blank BMP placeholders.
 *   6. Copy ancillary files (objects.lua, spawnpoints.lua, worldmap.xml, etc.).
 */
public class MapDecompiler {

    private static final Pattern CELL_NAME = Pattern.compile("(\\d+)_(\\d+)\\.lotheader");

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.out.println("Usage: MapDecompiler <inputMapDir> <outputDir> [tileDPath] [pzwTemplate]");
            System.exit(1);
        }
        File inputDir   = new File(args[0]);
        File outputDir  = new File(args[1]);
        File tileDPath  = new File(args.length >= 3 ? args[2]
                                        : "z:\\pzmaps\\B42.Mapping.Tools\\TileD");
        // Default to the EMPTY teste.pzw, not untitled.pzw — the latter is a saved
        // Recife project whose <bmp>/<cell> entries would otherwise leak through.
        File pzwTemplate = (args.length >= 4) ? new File(args[3]) : new File("z:\\pzmaps\\teste.pzw");

        decompile(inputDir, outputDir, tileDPath, pzwTemplate);
    }

    public static void decompile(File inputDir, File outputDir, File tileDPath, File pzwTemplate) throws IOException {
        if (!inputDir.isDirectory()) throw new IOException("Input not a directory: " + inputDir);
        outputDir.mkdirs();
        File cellsDir = new File(outputDir, "cells");
        cellsDir.mkdirs();
        File tilesetsTxt = new File(tileDPath, "Tilesets.txt");
        if (!tilesetsTxt.isFile()) throw new IOException("Tilesets.txt not found: " + tilesetsTxt);

        System.out.println("[1/5] Loading tileset index from " + tilesetsTxt);
        TilesetIndex idx = TilesetIndex.load(tilesetsTxt);
        System.out.println("      " + idx.tilesets.size() + " tilesets, " + idx.sprites.size() + " sprite refs");

        System.out.println("[2/5] Discovering cells in " + inputDir);
        List<int[]> cells = new ArrayList<>();
        int minCX = Integer.MAX_VALUE, maxCX = Integer.MIN_VALUE;
        int minCY = Integer.MAX_VALUE, maxCY = Integer.MIN_VALUE;
        for (File f : Objects.requireNonNull(inputDir.listFiles())) {
            Matcher m = CELL_NAME.matcher(f.getName());
            if (m.matches()) {
                int cx = Integer.parseInt(m.group(1));
                int cy = Integer.parseInt(m.group(2));
                cells.add(new int[]{cx, cy});
                minCX = Math.min(minCX, cx); maxCX = Math.max(maxCX, cx);
                minCY = Math.min(minCY, cy); maxCY = Math.max(maxCY, cy);
            }
        }
        if (cells.isEmpty()) throw new IOException("No CX_CY.lotheader files found in " + inputDir);
        int worldW = maxCX - minCX + 1;
        int worldH = maxCY - minCY + 1;
        System.out.println("      " + cells.size() + " cells; world bounds X=" + minCX + ".." + maxCX
                + " Y=" + minCY + ".." + maxCY + " (size " + worldW + "x" + worldH + ")");

        System.out.println("[3/5] Emitting per-cell TMX files");
        // Per-cell TMX should reference tiles at "../../<TileDPath>/Tiles/2x/X.png"
        // We use an absolute path so the editor finds it regardless of project location.
        String tilePathPrefix = tileDPath.toPath().resolve("Tiles").resolve("2x").toString().replace('\\', '/') + "/";

        int ok = 0, fail = 0;
        StringBuilder report = new StringBuilder();
        List<MapToPZW.CellRef> cellRefs = new ArrayList<>();
        for (int[] c : cells) {
            int cx = c[0], cy = c[1];
            File headerFile = new File(inputDir, cx + "_" + cy + ".lotheader");
            File packFile   = new File(inputDir, "world_" + cx + "_" + cy + ".lotpack");
            File tmxFile    = new File(cellsDir, cx + "_" + cy + ".tmx");
            try {
                LotHeaderData hdr = ConvertMap.loadLotHeader(headerFile, cx, cy);
                if (!packFile.isFile()) {
                    System.out.println("      [skip " + cx + "_" + cy + "] no lotpack");
                    fail++;
                    continue;
                }
                LotPackData pack = ConvertMap.loadLotPack(packFile, hdr);
                String summary = LotToTMX.decompileCell(hdr, pack, idx, tmxFile, tilePathPrefix);
                ok++;
                report.append(summary).append('\n');
                cellRefs.add(new MapToPZW.CellRef(cx - minCX, cy - minCY, "cells/" + cx + "_" + cy + ".tmx"));
            } catch (Exception e) {
                System.out.println("      [fail " + cx + "_" + cy + "] " + e.getClass().getSimpleName() + ": " + e.getMessage());
                fail++;
            }
        }
        System.out.println("      " + ok + " ok, " + fail + " failed");

        System.out.println("[4/5] Writing world .pzw");
        String mapName = inputDir.getName().replaceAll("[^A-Za-z0-9_-]", "_");
        File pzwOut = new File(outputDir, mapName + ".pzw");
        MapToPZW.write(pzwTemplate, pzwOut, worldW, worldH, cellRefs);
        System.out.println("      " + pzwOut);

        System.out.println("[5/5] Copying ancillary files and emitting placeholders");
        copyIfExists(inputDir, outputDir, "objects.lua");
        copyIfExists(inputDir, outputDir, "spawnpoints.lua");
        copyIfExists(inputDir, outputDir, "spawnregions.lua");
        copyIfExists(inputDir, outputDir, "worldmap.xml");
        copyIfExists(inputDir, outputDir, "worldmap.xml.bin");
        copyIfExists(inputDir, outputDir, "worldmap-forest.xml");
        copyIfExists(inputDir, outputDir, "worldmap-annotations.lua");
        copyIfExists(inputDir, outputDir, "streets.xml");
        copyIfExists(inputDir, outputDir, "map.info");
        copyIfExists(inputDir, outputDir, "thumb.png");

        // Optional blank placeholders (256 px per cell)
        try {
            int pxW = worldW * 256;
            int pxH = worldH * 256;
            BuildBlankBMP.writeBlankBmp(new File(outputDir, mapName + ".bmp"), pxW, pxH, Color.WHITE);
            BuildBlankBMP.writeBlankBmp(new File(outputDir, mapName + "_veg.bmp"), pxW, pxH, Color.WHITE);
            System.out.println("      blank BMPs " + pxW + "x" + pxH);
        } catch (Exception e) {
            System.out.println("      BMP placeholder generation failed: " + e.getMessage());
        }

        // Write a per-cell decompilation report
        File rep = new File(outputDir, "_decompile_report.txt");
        Files.write(rep.toPath(), report.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));

        System.out.println();
        System.out.println("=== Done. Open in WorldEd: " + pzwOut.getAbsolutePath() + " ===");
    }

    private static void copyIfExists(File srcDir, File dstDir, String name) {
        File src = new File(srcDir, name);
        if (!src.isFile()) return;
        try {
            Files.copy(src.toPath(), new File(dstDir, name).toPath(),
                    StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            System.out.println("      [warn] copy " + name + " failed: " + e.getMessage());
        }
    }
}

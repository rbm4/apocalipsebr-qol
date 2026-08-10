package com.apocalipsebr.tools.mapconverter;

import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;

/**
 * Scans or patches the baked zombie-density bytes stored in .lotheader files.
 *
 * This preserves the original lotheader format and only rewrites the density block.
 */
public class ZombieDensityTool {
    private static final byte[] LOTH_MAGIC = new byte[] { 'L', 'O', 'T', 'H' };

    private static class DensityBlock {
        boolean pot;
        int chunksPerCell;
        long offset;
        int count;
        int min = 255;
        int max = 0;
        long sum = 0;
        int nonZero = 0;
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            usage();
            return;
        }

        String mode = args[0];
        File mapDir = new File(args[1]);
        if (!mapDir.isDirectory()) throw new IOException("Map dir not found: " + mapDir);

        if ("--scan".equals(mode)) {
            if (args.length == 2) {
                scan(mapDir);
            } else {
                File target = patchFromScanArgs(mapDir, args);
                System.out.println();
                scan(target);
            }
        } else if ("--zero".equals(mode)) {
            patch(mapDir, args.length >= 3 ? new File(args[2]) : null, "zero", 0);
        } else if ("--cap".equals(mode)) {
            if (args.length < 3) throw new IllegalArgumentException("--cap requires max byte 0..255");
            int cap = clamp(Integer.parseInt(args[2]));
            patch(mapDir, args.length >= 4 ? new File(args[3]) : null, "cap", cap);
        } else if ("--scale".equals(mode)) {
            if (args.length < 3) throw new IllegalArgumentException("--scale requires factor, e.g. 0.25");
            double factor = Double.parseDouble(args[2]);
            patch(mapDir, args.length >= 4 ? new File(args[3]) : null, "scale", factor);
        } else {
            usage();
        }
    }

    private static void usage() {
        System.out.println("Usage:");
        System.out.println("  ZombieDensityTool --scan <mapDir>");
        System.out.println("  ZombieDensityTool --scan <mapDir> --zero [outDir]");
        System.out.println("  ZombieDensityTool --scan <mapDir> --cap <maxByte> [outDir]");
        System.out.println("  ZombieDensityTool --scan <mapDir> --scale <factor> [outDir]");
        System.out.println("  ZombieDensityTool --zero <mapDir> [outDir]");
        System.out.println("  ZombieDensityTool --cap <mapDir> <maxByte> [outDir]");
        System.out.println("  ZombieDensityTool --scale <mapDir> <factor> [outDir]");
        System.out.println();
        System.out.println("If outDir is omitted, files are patched in-place after .bak backup creation.");
    }

    private static File patchFromScanArgs(File mapDir, String[] args) throws IOException {
        String action = args[2];
        if ("--zero".equals(action)) {
            File outDir = args.length >= 4 ? new File(args[3]) : null;
            patch(mapDir, outDir, "zero", 0);
            return outDir != null ? outDir : mapDir;
        } else if ("--cap".equals(action)) {
            if (args.length < 4) throw new IllegalArgumentException("--scan <mapDir> --cap requires max byte 0..255");
            int cap = clamp(Integer.parseInt(args[3]));
            File outDir = args.length >= 5 ? new File(args[4]) : null;
            patch(mapDir, outDir, "cap", cap);
            return outDir != null ? outDir : mapDir;
        } else if ("--scale".equals(action)) {
            if (args.length < 4) throw new IllegalArgumentException("--scan <mapDir> --scale requires factor, e.g. 0.30");
            double factor = Double.parseDouble(args[3]);
            File outDir = args.length >= 5 ? new File(args[4]) : null;
            patch(mapDir, outDir, "scale", factor);
            return outDir != null ? outDir : mapDir;
        } else {
            throw new IllegalArgumentException("Unknown --scan patch action: " + action);
        }
    }

    private static void scan(File mapDir) throws IOException {
        File[] files = lotheaders(mapDir);
        int totalFiles = 0, totalNonZero = 0, globalMin = 255, globalMax = 0;
        long totalBytes = 0, totalSum = 0;

        for (File file : files) {
            DensityBlock block = locate(file);
            readStats(file, block);
            totalFiles++;
            totalNonZero += block.nonZero;
            totalBytes += block.count;
            totalSum += block.sum;
            globalMin = Math.min(globalMin, block.min);
            globalMax = Math.max(globalMax, block.max);
            System.out.printf("%s format=%s bytes=%d nonZero=%d min=%d max=%d avg=%.2f%n",
                    file.getName(), block.pot ? "B42/POT" : "B41", block.count,
                    block.nonZero, block.min, block.max, block.sum / (double) block.count);
        }

        if (totalFiles == 0) {
            System.out.println("No .lotheader files found in " + mapDir);
        } else {
            System.out.printf("TOTAL files=%d bytes=%d nonZero=%d min=%d max=%d avg=%.2f%n",
                    totalFiles, totalBytes, totalNonZero, globalMin, globalMax,
                    totalSum / (double) totalBytes);
        }
    }

    private static void patch(File mapDir, File outDir, String mode, Object value) throws IOException {
        File[] files = lotheaders(mapDir);
        if (outDir != null) {
            copyMapDir(mapDir, outDir);
            mapDir = outDir;
            files = lotheaders(mapDir);
        }

        int changedFiles = 0;
        for (File file : files) {
            DensityBlock block = locate(file);
            if (outDir == null) backup(file);
            int changedBytes = patchFile(file, block, mode, value);
            if (changedBytes > 0) changedFiles++;
            System.out.printf("%s changedBytes=%d%n", file.getName(), changedBytes);
        }
        System.out.printf("Patched files=%d mode=%s target=%s%n", changedFiles, mode, mapDir);
    }

    private static int patchFile(File file, DensityBlock block, String mode, Object value) throws IOException {
        int changed = 0;
        try (RandomAccessFile raf = new RandomAccessFile(file, "rw")) {
            raf.seek(block.offset);
            byte[] bytes = new byte[block.count];
            raf.readFully(bytes);
            for (int i = 0; i < bytes.length; i++) {
                int old = bytes[i] & 0xFF;
                int next;
                if ("zero".equals(mode)) {
                    next = 0;
                } else if ("cap".equals(mode)) {
                    next = Math.min(old, (Integer) value);
                } else {
                    next = clamp((int) Math.round(old * (Double) value));
                }
                if (next != old) changed++;
                bytes[i] = (byte) next;
            }
            raf.seek(block.offset);
            raf.write(bytes);
        }
        return changed;
    }

    private static DensityBlock locate(File file) throws IOException {
        try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
            byte[] magic = new byte[4];
            raf.readFully(magic);
            boolean hasMagic = Arrays.equals(magic, LOTH_MAGIC);
            if (!hasMagic) raf.seek(0);

            int version = ConvertMap.readIntLE(raf);
            if (version < 0 || version > 1) {
                throw new IOException("Unsupported lotheader version " + version + " in " + file);
            }

            int tileCount = ConvertMap.readIntLE(raf);
            for (int i = 0; i < tileCount; i++) ConvertMap.readString(raf);
            if (version == 0) raf.read();
            ConvertMap.readIntLE(raf);
            ConvertMap.readIntLE(raf);
            if (version == 0) {
                ConvertMap.readIntLE(raf);
            } else {
                ConvertMap.readIntLE(raf);
                ConvertMap.readIntLE(raf);
            }

            int numRooms = ConvertMap.readIntLE(raf);
            for (int i = 0; i < numRooms; i++) {
                ConvertMap.readString(raf);
                ConvertMap.readIntLE(raf);
                int numRects = ConvertMap.readIntLE(raf);
                for (int r = 0; r < numRects; r++) {
                    ConvertMap.readIntLE(raf);
                    ConvertMap.readIntLE(raf);
                    ConvertMap.readIntLE(raf);
                    ConvertMap.readIntLE(raf);
                }
                int numObjects = ConvertMap.readIntLE(raf);
                for (int m = 0; m < numObjects; m++) {
                    ConvertMap.readIntLE(raf);
                    ConvertMap.readIntLE(raf);
                    ConvertMap.readIntLE(raf);
                }
            }

            int numBuildings = ConvertMap.readIntLE(raf);
            for (int i = 0; i < numBuildings; i++) {
                int buildingRoomCount = ConvertMap.readIntLE(raf);
                for (int r = 0; r < buildingRoomCount; r++) ConvertMap.readIntLE(raf);
            }

            DensityBlock block = new DensityBlock();
            block.pot = hasMagic;
            block.chunksPerCell = hasMagic ? 32 : 30;
            block.count = block.chunksPerCell * block.chunksPerCell;
            block.offset = raf.getFilePointer();
            if (block.offset + block.count > raf.length()) {
                throw new IOException("Density block exceeds file size in " + file);
            }
            return block;
        }
    }

    private static void readStats(File file, DensityBlock block) throws IOException {
        try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
            raf.seek(block.offset);
            for (int i = 0; i < block.count; i++) {
                int v = raf.read() & 0xFF;
                block.min = Math.min(block.min, v);
                block.max = Math.max(block.max, v);
                block.sum += v;
                if (v != 0) block.nonZero++;
            }
        }
    }

    private static File[] lotheaders(File mapDir) {
        File[] files = mapDir.listFiles((dir, name) -> name.endsWith(".lotheader"));
        if (files == null) return new File[0];
        Arrays.sort(files);
        return files;
    }

    private static void backup(File file) throws IOException {
        File backup = new File(file.getAbsolutePath() + ".bak");
        if (!backup.exists()) {
            Files.copy(file.toPath(), backup.toPath());
        }
    }

    private static void copyMapDir(File src, File dst) throws IOException {
        if (!dst.exists()) Files.createDirectories(dst.toPath());
        File[] files = src.listFiles();
        if (files == null) return;
        for (File file : files) {
            File target = new File(dst, file.getName());
            if (file.isDirectory()) {
                copyMapDir(file, target);
            } else {
                Files.copy(file.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }

    private static int clamp(int value) {
        return Math.max(0, Math.min(255, value));
    }
}

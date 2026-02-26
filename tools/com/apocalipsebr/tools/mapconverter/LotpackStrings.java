package com.apocalipsebr.tools.mapconverter;

import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Tool to dump and replace tile name strings in B42 .lotheader files.
 *
 * Tile names are stored in the lotheader's string table; the .lotpack only stores
 * integer indices into that table. Replacing a string in the lotheader is enough —
 * lotpack indices remain valid.
 *
 * Usage:
 *   --dump <mapDir>                    List all unique tile names across all .lotheader files
 *   --replace <mapDir> <csvFile>       Replace broken tile names using a CSV mapping file
 *
 * CSV format (tile_replacements.csv):
 *   # Lines starting with # are comments
 *   broken_tile_name,correct_tile_name
 *   vegetation_groudcover_01_18,d_generic_1_87
 */
public class LotpackStrings {

    static final String CSV_DEFAULT = "tile_replacements.csv";

    // ========================== Main ==========================

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.out.println("Usage:");
            System.out.println("  --dump <mapDir>                    Dump all unique tile names from .lotheader files");
            System.out.println("  --replace <mapDir> [csvFile]       Replace tile names using CSV mapping file");
            System.out.println();
            System.out.println("  CSV format: broken_name,correct_name  (# comments allowed)");
            System.out.println("  Default CSV: " + CSV_DEFAULT + " (next to this .class / in CWD)");
            return;
        }

        String mode = args[0];
        File mapDir = new File(args[1]);
        if (!mapDir.isDirectory()) {
            System.err.println("Not a directory: " + mapDir);
            return;
        }

        File[] lotHeaders = mapDir.listFiles((dir, name) -> name.endsWith(".lotheader"));
        if (lotHeaders == null || lotHeaders.length == 0) {
            System.err.println("No .lotheader files found in " + mapDir);
            return;
        }
        Arrays.sort(lotHeaders);

        switch (mode) {
            case "--dump":
                dumpMode(lotHeaders);
                break;
            case "--replace":
                File csvFile;
                if (args.length >= 3) {
                    csvFile = new File(args[2]);
                } else {
                    // Look for CSV next to the .class file (source folder)
                    csvFile = new File(getSourceDir(), CSV_DEFAULT);
                    if (!csvFile.isFile()) {
                        // Fallback to current working directory
                        csvFile = new File(CSV_DEFAULT);
                    }
                }
                replaceMode(lotHeaders, csvFile);
                break;
            default:
                System.err.println("Unknown mode: " + mode);
        }
    }

    // ========================== Dump Mode ==========================

    static void dumpMode(File[] lotHeaders) throws IOException {
        Set<String> allNames = new TreeSet<>();
        int totalFiles = 0;

        for (File f : lotHeaders) {
            List<String> names = readTileNames(f);
            allNames.addAll(names);
            totalFiles++;
            System.out.printf("  %s: %d tile names%n", f.getName(), names.size());
        }

        System.out.println();
        System.out.printf("Scanned %d .lotheader files, %d unique tile names%n", totalFiles, allNames.size());
        System.out.println("=".repeat(60));

        for (String name : allNames) {
            System.out.println(name);
        }
    }

    // ========================== Replace Mode ==========================

    static void replaceMode(File[] lotHeaders, File csvFile) throws IOException {
        if (!csvFile.isFile()) {
            System.err.println("CSV file not found: " + csvFile.getAbsolutePath());
            System.err.println("Create it with lines like:  broken_name,correct_name");
            return;
        }

        // Load mapping from CSV
        Map<String, String> mapping = loadCsv(csvFile);
        if (mapping.isEmpty()) {
            System.out.println("No valid mappings found in " + csvFile.getName());
            return;
        }
        System.out.printf("Loaded %d replacement mappings from %s%n", mapping.size(), csvFile.getName());

        int totalReplacements = 0;
        int filesModified = 0;

        for (File f : lotHeaders) {
            int count = replaceInLotheader(f, mapping);
            if (count > 0) {
                System.out.printf("  %s: %d replacements%n", f.getName(), count);
                totalReplacements += count;
                filesModified++;
            }
        }

        System.out.printf("%nDone. Modified %d files, %d total replacements%n",
                filesModified, totalReplacements);
    }

    // ========================== CSV Loading ==========================

    /**
     * Load tile name mappings from a CSV file.
     * Format: broken_name,correct_name
     * Lines starting with # are comments. Empty lines are skipped.
     */
    static Map<String, String> loadCsv(File csvFile) throws IOException {
        Map<String, String> mapping = new LinkedHashMap<>();
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(new FileInputStream(csvFile), StandardCharsets.UTF_8))) {
            String line;
            int lineNum = 0;
            while ((line = br.readLine()) != null) {
                lineNum++;
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                int comma = line.indexOf(',');
                if (comma <= 0 || comma == line.length() - 1) {
                    System.err.printf("  WARNING: line %d invalid (expected broken,correct): %s%n", lineNum, line);
                    continue;
                }
                String broken = line.substring(0, comma).trim();
                String correct = line.substring(comma + 1).trim();
                if (!broken.isEmpty() && !correct.isEmpty()) {
                    mapping.put(broken, correct);
                }
            }
        }
        return mapping;
    }

    // ========================== Lotheader I/O ==========================

    /**
     * Read just the tile name string table from a .lotheader file.
     */
    static List<String> readTileNames(File file) throws IOException {
        List<String> names = new ArrayList<>();
        try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
            byte[] magic = new byte[4];
            raf.read(magic, 0, 4);
            boolean hasMagic = magic[0] == 'L' && magic[1] == 'O'
                            && magic[2] == 'T' && magic[3] == 'H';
            if (!hasMagic) raf.seek(0);

            int version = readIntLE(raf);
            int tileCount = readIntLE(raf);
            for (int i = 0; i < tileCount; i++) {
                names.add(readString(raf).trim());
            }
        }
        return names;
    }

    /**
     * Replace tile name strings in a .lotheader file.
     * 
     * Strategy: read the entire file as raw bytes, locate each tile name string
     * in the header section, and replace if it matches a known broken name.
     * Then rewrite the entire file (structure is preserved since we only change
     * the content of newline-terminated strings).
     *
     * Since strings are newline-terminated (variable length), we rebuild the
     * entire file byte by byte to handle length changes correctly.
     */
    static int replaceInLotheader(File file, Map<String, String> mapping) throws IOException {
        byte[] original = readAllBytes(file);
        int pos = 0;

        // Check for LOTH magic
        boolean hasMagic = original.length >= 4
                        && original[0] == 'L' && original[1] == 'O'
                        && original[2] == 'T' && original[3] == 'H';
        if (hasMagic) pos = 4;

        // Read version (LE int32)
        int version = readIntLE(original, pos);
        pos += 4;

        // Read tile count (LE int32)
        int tileCount = readIntLE(original, pos);
        pos += 4;

        // Parse each tile name and check for replacements
        int replacements = 0;
        List<String> originalNames = new ArrayList<>();
        List<String> newNames = new ArrayList<>();
        int tilesSectionStart = pos;

        for (int i = 0; i < tileCount; i++) {
            int stringStart = pos;
            // Find the newline
            while (pos < original.length && original[pos] != '\n') pos++;
            String name = new String(original, stringStart, pos - stringStart, StandardCharsets.UTF_8).trim();
            if (pos < original.length) pos++; // skip \n

            originalNames.add(name);
            if (mapping.containsKey(name)) {
                newNames.add(mapping.get(name));
                replacements++;
            } else {
                newNames.add(name);
            }
        }

        if (replacements == 0) return 0;

        // Rebuild the file: header bytes before tile section + new tile strings + remainder
        int tilesSectionEnd = pos;
        byte[] remainder = new byte[original.length - tilesSectionEnd];
        System.arraycopy(original, tilesSectionEnd, remainder, 0, remainder.length);

        ByteArrayOutputStream out = new ByteArrayOutputStream(original.length + 1024);

        // Write everything before the tiles section
        out.write(original, 0, tilesSectionStart);

        // Write the new tile strings (same count, newline-terminated)
        for (String name : newNames) {
            out.write(name.getBytes(StandardCharsets.UTF_8));
            out.write('\n');
        }

        // Write the remainder of the file (rooms, buildings, zombie density, etc.)
        out.write(remainder);

        // Overwrite the original file
        try (FileOutputStream fos = new FileOutputStream(file)) {
            fos.write(out.toByteArray());
        }

        return replacements;
    }

    // ========================== Path Helpers ==========================

    /**
     * Get the directory where the LotpackStrings.class file lives.
     * This resolves to the source/package folder regardless of CWD.
     */
    static File getSourceDir() {
        try {
            java.net.URL url = LotpackStrings.class.getProtectionDomain().getCodeSource().getLocation();
            File classRoot = new File(url.toURI());
            // classRoot is the -cp root (e.g. tools/). Append the package path.
            return new File(classRoot, "com/apocalipsebr/tools/mapconverter");
        } catch (Exception e) {
            // Fallback: CWD
            return new File(".");
        }
    }

    // ========================== Binary Helpers ==========================

    static int readIntLE(RandomAccessFile raf) throws IOException {
        int b0 = raf.read(); int b1 = raf.read(); int b2 = raf.read(); int b3 = raf.read();
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

    static byte[] readAllBytes(File file) throws IOException {
        byte[] data = new byte[(int) file.length()];
        try (FileInputStream fis = new FileInputStream(file)) {
            int read = 0;
            while (read < data.length) {
                int n = fis.read(data, read, data.length - read);
                if (n == -1) break;
                read += n;
            }
        }
        return data;
    }
}

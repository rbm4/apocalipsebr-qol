package com.apocalipsebr.tools.mapconverter;

import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Verify a worldmap.xml.bin by reading it with the exact same logic as
 * zombie.worldMap.WorldMapBinary, printing diagnostics.
 */
public class VerifyBin {

    static int readByte(InputStream in) throws IOException {
        return in.read();
    }

    static int readInt(InputStream in) throws IOException {
        int ch1 = in.read();
        int ch2 = in.read();
        int ch3 = in.read();
        int ch4 = in.read();
        if ((ch1 | ch2 | ch3 | ch4) < 0) throw new EOFException();
        return (ch1) + (ch2 << 8) + (ch3 << 16) + (ch4 << 24);
    }

    static short readShort(InputStream in) throws IOException {
        int ch1 = in.read();
        int ch2 = in.read();
        if ((ch1 | ch2) < 0) throw new EOFException();
        return (short)((ch1) + (ch2 << 8));
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.out.println("Usage: VerifyBin <worldmap.xml.bin>");
            return;
        }
        File file = new File(args[0]);
        System.out.println("Verifying: " + file.getAbsolutePath());
        System.out.println("File size: " + file.length() + " bytes");

        try (BufferedInputStream bis = new BufferedInputStream(new FileInputStream(file))) {
            // Magic
            int b1 = bis.read(), b2 = bis.read(), b3 = bis.read(), b4 = bis.read();
            String magic = "" + (char)b1 + (char)b2 + (char)b3 + (char)b4;
            System.out.println("Magic: " + magic + (magic.equals("IGMB") ? " OK" : " FAIL"));

            int version = readInt(bis);
            System.out.println("Version: " + version + (version == 2 ? " OK" : " FAIL"));

            int cellSize = readInt(bis);
            System.out.println("CellSize: " + cellSize + (cellSize == 256 ? " OK" : " FAIL"));

            int width = readInt(bis);
            int height = readInt(bis);
            System.out.println("Grid: " + width + "x" + height + " (" + (width*height) + " slots)");

            // String table
            int numStrings = readInt(bis);
            System.out.println("String table: " + numStrings + " entries");
            String[] strings = new String[numStrings];
            for (int i = 0; i < numStrings; i++) {
                int len = readShort(bis) & 0xFFFF;
                byte[] utf = new byte[len];
                int read = 0;
                while (read < len) {
                    int r = bis.read(utf, read, len - read);
                    if (r < 0) throw new EOFException("reading string " + i);
                    read += r;
                }
                strings[i] = new String(utf, StandardCharsets.UTF_8);
                System.out.println("  [" + i + "] \"" + strings[i] + "\" (" + len + " bytes)");
            }

            // Cells
            int cellCount = 0;
            int totalFeatures = 0;
            int emptySlots = 0;
            int minCX = Integer.MAX_VALUE, maxCX = Integer.MIN_VALUE;
            int minCY = Integer.MAX_VALUE, maxCY = Integer.MIN_VALUE;

            for (int gy = 0; gy < height; gy++) {
                for (int gx = 0; gx < width; gx++) {
                    int x = readInt(bis);
                    if (x == -1) {
                        emptySlots++;
                        continue;
                    }
                    int y = readInt(bis);
                    int numFeatures = readInt(bis);
                    cellCount++;
                    totalFeatures += numFeatures;
                    minCX = Math.min(minCX, x); maxCX = Math.max(maxCX, x);
                    minCY = Math.min(minCY, y); maxCY = Math.max(maxCY, y);

                    int negCoords = 0, overCoords = 0;
                    for (int fi = 0; fi < numFeatures; fi++) {
                        // geometry type
                        short typeIdx = readShort(bis);
                        if (typeIdx < 0 || typeIdx >= numStrings) {
                            System.err.println("INVALID type index " + typeIdx + " at cell " + x + "," + y + " feature " + fi);
                            return;
                        }
                        String gtype = strings[typeIdx];

                        // coordinate blocks
                        int numBlocks = readByte(bis);
                        for (int bi = 0; bi < numBlocks; bi++) {
                            int numPts = readShort(bis) & 0xFFFF;
                            for (int pi = 0; pi < numPts; pi++) {
                                short px = readShort(bis);
                                short py = readShort(bis);
                                if (px < 0 || py < 0) negCoords++;
                                if (px > 256 || py > 256) overCoords++;
                            }
                        }
                        // properties
                        int numProps = readByte(bis);
                        for (int pi = 0; pi < numProps; pi++) {
                            short ki = readShort(bis);
                            short vi = readShort(bis);
                            if (ki < 0 || ki >= numStrings) {
                                System.err.println("INVALID prop key index " + ki);
                                return;
                            }
                            if (vi < 0 || vi >= numStrings) {
                                System.err.println("INVALID prop value index " + vi);
                                return;
                            }
                        }
                    }
                    if (gx < 3 && gy < 3) {
                        System.out.println("  Cell(" + x + "," + y + ") slot[" + gx + "," + gy + "]: " +
                            numFeatures + " features" +
                            (negCoords > 0 ? ", " + negCoords + " neg-coords" : "") +
                            (overCoords > 0 ? ", " + overCoords + " over-256" : ""));
                    }
                }
            }
            // Check position
            int remaining = bis.available();

            System.out.println("\nSummary:");
            System.out.println("  Cells: " + cellCount + " populated, " + emptySlots + " empty");
            System.out.println("  Cell range: [" + minCX + "," + minCY + "] to [" + maxCX + "," + maxCY + "]");
            System.out.println("  Total features: " + totalFeatures);
            System.out.println("  Remaining bytes: " + remaining + (remaining == 0 ? " OK" : " FAIL (should be 0)"));
        }
    }
}

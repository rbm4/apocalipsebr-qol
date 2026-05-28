package com.apocalipsebr.tools.mapconverter;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.*;
import javax.imageio.ImageIO;

/**
 * Generates blank placeholder BMP/PNG images for a decompiled map. WorldEd's BMPToTMX
 * dialog expects mapName.bmp and mapName_veg.bmp at one pixel per square (256 per cell).
 *
 * For a decompiled map we don't have the source heightmaps, so we emit solid-white
 * placeholders just so the project opens — they can be replaced later.
 */
public class BuildBlankBMP {

    /** Generate a solid-color image of the given size and save as BMP. */
    public static void writeBlankBmp(File outFile, int widthPx, int heightPx, Color fill) throws IOException {
        BufferedImage img = new BufferedImage(widthPx, heightPx, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        try {
            g.setColor(fill);
            g.fillRect(0, 0, widthPx, heightPx);
        } finally { g.dispose(); }
        File parent = outFile.getParentFile();
        if (parent != null) parent.mkdirs();
        if (!ImageIO.write(img, "bmp", outFile)) {
            throw new IOException("ImageIO has no BMP writer");
        }
    }
}

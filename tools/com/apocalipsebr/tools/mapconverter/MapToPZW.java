package com.apocalipsebr.tools.mapconverter;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/**
 * Writes a WorldEd .pzw world file referencing the cell TMX files produced by LotToTMX.
 *
 * Uses a known-good template (teste.pzw / untitled.pzw) as the boilerplate header and
 * appends &lt;cell x=... y=... map="cells/CX_CY.tmx"/&gt; entries before &lt;/world&gt;.
 */
public class MapToPZW {

    /** Describes one cell to reference. world-local coords (0..W-1), and a relative TMX path. */
    public static class CellRef {
        public final int worldX, worldY;
        public final String tmxRelPath;
        public CellRef(int wx, int wy, String tmxRelPath) {
            this.worldX = wx; this.worldY = wy; this.tmxRelPath = tmxRelPath;
        }
    }

    public static void write(File templatePzw, File outFile, int worldW, int worldH,
                             List<CellRef> cells) throws IOException {
        String tpl;
        if (templatePzw != null && templatePzw.isFile()) {
            tpl = new String(Files.readAllBytes(templatePzw.toPath()), StandardCharsets.UTF_8);
        } else {
            tpl = BUILTIN_TEMPLATE;
        }

        // Replace the <world ... width="X" height="Y"> tag
        tpl = tpl.replaceFirst(
            "<world[^>]*>",
            "<world version=\"1.0\" width=\"" + worldW + "\" height=\"" + worldH + "\">");

        // Strip any leftovers that would leak the template's previous project:
        //   - <cell .../> entries (we inject our own)
        //   - <bmp .../>  entries (BMPToTMX source slices from prior project)
        //   - <road .../> entries
        tpl = tpl.replaceAll("(?m)^\\s*<cell\\b[^>]*/>\\s*\\r?\\n", "");
        tpl = tpl.replaceAll("(?m)^\\s*<bmp\\b[^>]*/>\\s*\\r?\\n", "");
        tpl = tpl.replaceAll("(?m)^\\s*<road\\b[^>]*/>\\s*\\r?\\n", "");
        // Blank out path-style attributes that point to the template's source project
        tpl = tpl.replaceAll("(<tmxexportdir\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<rulesfile\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<blendsfile\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<mapbasefile\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<exportdir\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<ZombieSpawnMap\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<TileDefFolder\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<spawnPointsFile\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<worldObjectsFile\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<roomTonesFile\\s+path=)\"[^\"]*\"", "$1\"\"");
        tpl = tpl.replaceAll("(<buildingsImage\\s+path=)\"[^\"]*\"", "$1\"\"");
        // Reset assign-maps-to-world to false (template might have it true)
        tpl = tpl.replaceAll("<assign-maps-to-world\\s+checked=\"[^\"]*\"/>",
                             "<assign-maps-to-world checked=\"false\"/>");

        // Inject cell entries just before </world>
        StringBuilder cellsXml = new StringBuilder();
        for (CellRef cr : cells) {
            cellsXml.append(" <cell x=\"").append(cr.worldX)
                    .append("\" y=\"").append(cr.worldY)
                    .append("\" map=\"").append(xmlAttr(cr.tmxRelPath))
                    .append("\"/>\n");
        }
        int closing = tpl.lastIndexOf("</world>");
        if (closing < 0) throw new IOException("Template missing </world>");
        String output = tpl.substring(0, closing) + cellsXml + tpl.substring(closing);

        try (Writer w = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(outFile), StandardCharsets.UTF_8))) {
            w.write(output);
        }
    }

    private static String xmlAttr(String s) {
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&apos;");
    }

    /** Minimal fallback template if no template file is supplied. */
    private static final String BUILTIN_TEMPLATE =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
        "<world version=\"1.0\" width=\"1\" height=\"1\">\n" +
        " <BMPToTMX>\n" +
        "  <tmxexportdir path=\"\"/>\n" +
        "  <rulesfile path=\"\"/>\n" +
        "  <blendsfile path=\"\"/>\n" +
        "  <mapbasefile path=\"\"/>\n" +
        "  <assign-maps-to-world checked=\"false\"/>\n" +
        "  <warn-unknown-colors checked=\"true\"/>\n" +
        "  <compress checked=\"true\"/>\n" +
        "  <copy-pixels checked=\"true\"/>\n" +
        "  <update-existing checked=\"false\"/>\n" +
        " </BMPToTMX>\n" +
        " <TMXToBMP>\n" +
        "  <mainImage generate=\"true\"/>\n" +
        "  <vegetationImage generate=\"true\"/>\n" +
        "  <buildingsImage path=\"\" generate=\"false\"/>\n" +
        " </TMXToBMP>\n" +
        " <GenerateLots>\n" +
        "  <exportdir path=\"\"/>\n" +
        "  <ZombieSpawnMap path=\"\"/>\n" +
        "  <TileDefFolder path=\"\"/>\n" +
        "  <worldOrigin origin=\"0,0\"/>\n" +
        "  <numberOfThreads count=\"1\"/>\n" +
        " </GenerateLots>\n" +
        " <LuaSettings>\n" +
        "  <spawnPointsFile path=\"\"/>\n" +
        "  <worldObjectsFile path=\"\"/>\n" +
        "  <roomTonesFile path=\"\"/>\n" +
        " </LuaSettings>\n" +
        "</world>\n";
}

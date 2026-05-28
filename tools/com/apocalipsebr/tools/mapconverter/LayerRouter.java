package com.apocalipsebr.tools.mapconverter;

/**
 * Routes a PZ sprite name to a logical TMX layer role for the editor.
 *
 * Project Zomboid map cells store an unordered stack of sprite names per square.
 * TileZed/WorldEd, however, expect tiles to be separated across named layers:
 *   "<z>_Floor", "<z>_FloorOverlay", "<z>_Walls", "<z>_Furniture",
 *   "<z>_Vegetation", "<z>_RoofTop", "<z>_WallOverlay".
 *
 * Vanilla sprites follow a stable naming convention which we use here. Unknown
 * sprites fall back to FURNITURE so cells still open in the editor.
 */
public class LayerRouter {

    public enum Role {
        FLOOR("Floor"),
        FLOOR_OVERLAY("FloorOverlay"),
        WALLS("Walls"),
        WALL_OVERLAY("WallOverlay"),
        FURNITURE("Furniture"),
        VEGETATION("Vegetation"),
        ROOFTOP("RoofTop"),
        UNKNOWN("Unknown");

        public final String suffix;
        Role(String s) { this.suffix = s; }
    }

    /** Route a sprite name to a layer role. */
    public static Role routeOf(String spriteName) {
        if (spriteName == null) return Role.UNKNOWN;
        String n = spriteName.toLowerCase();

        // Floor tiles (ground-level base sprites)
        if (n.startsWith("floors_exterior_")
         || n.startsWith("floors_interior_")
         || n.startsWith("floors_burnt_")
         || n.startsWith("floors_rugs_")
         || n.startsWith("blends_natural_")
         || n.startsWith("blends_grass")
         || n.startsWith("e_newgrass")
         || n.startsWith("e_newsnow")
         || n.startsWith("e_exterior_")
         || n.startsWith("blends_street_")) {
            return Role.FLOOR;
        }

        // Floor overlays (decals on top of floor)
        if (n.startsWith("floors_overlay_")
         || n.startsWith("blends_streetoverlays_")
         || n.startsWith("street_trafficlines")
         || n.startsWith("street_curbs_")
         || n.startsWith("street_decoration_")
         || n.startsWith("overlay_blood_floor_")
         || n.startsWith("overlay_grime_floor_")
         || n.startsWith("d_floorleaves_")
         || n.startsWith("d_streetcracks_")
         || n.startsWith("d_trash_")
         || n.startsWith("floor_carpet_motif")
         || n.startsWith("blood_floor_")) {
            return Role.FLOOR_OVERLAY;
        }

        // Walls
        if (n.startsWith("walls_")
         || n.startsWith("wall_")
         || n.startsWith("fixtures_doors_")
         || n.startsWith("fixtures_windows_")
         || n.startsWith("fixtures_railings_")
         || n.startsWith("fixtures_escalators_")
         || n.startsWith("fixtures_stairs_")
         || n.startsWith("fencing_")
         || n.startsWith("trash_walls_")
         || n.startsWith("invisible_01")) {
            return Role.WALLS;
        }

        // Wall overlays
        if (n.startsWith("walls_decoration_")
         || n.startsWith("walls_detailing_")
         || n.startsWith("walls_interior_detailing_")
         || n.startsWith("walls_interior_cutaways_")
         || n.startsWith("overlay_blood_wall_")
         || n.startsWith("overlay_grime_wall_")
         || n.startsWith("overlay_graffiti_wall_")
         || n.startsWith("overlay_messages_wall_")
         || n.startsWith("d_wallcracks_")
         || n.startsWith("d_plants_")
         || n.startsWith("f_wallvines_")
         || n.startsWith("papernotices_")
         || n.startsWith("signs_")
         || n.startsWith("advertising_")) {
            return Role.WALL_OVERLAY;
        }

        // Roofs
        if (n.startsWith("roofs_")
         || n.startsWith("rooftop_")
         || n.startsWith("walls_exterior_roofs_")
         || n.startsWith("walls_burnt_roofs_")
         || n.startsWith("e_roof_")) {
            return Role.ROOFTOP;
        }

        // Vegetation
        if (n.startsWith("vegetation_")
         || n.startsWith("trees_")
         || n.startsWith("bushes_")
         || n.startsWith("jumbo_tree_")
         || n.startsWith("f_bushes_")
         || n.startsWith("f_flowerbed_")
         || n.startsWith("e_americanholly_")
         || n.startsWith("e_americanlinden_")
         || n.startsWith("e_canadianhemlock_")
         || n.startsWith("e_carolinasilverbell_")
         || n.startsWith("e_cockspurhawthorn_")
         || n.startsWith("e_dogwood")
         || n.startsWith("e_easternredbud_")
         || n.startsWith("e_redmaple")
         || n.startsWith("e_riverbirch")
         || n.startsWith("e_virginiapine_")
         || n.startsWith("e_yellowwood_")) {
            return Role.VEGETATION;
        }

        // Everything else (furniture, appliances, objects, fixtures, etc.)
        return Role.FURNITURE;
    }
}

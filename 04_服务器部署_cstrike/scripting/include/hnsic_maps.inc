/* ============================================
 * HNSIC Maps API Header
 * Version: 3.10.0
 * HNSIC CS 1.6 AMX Mod X System
 * ============================================ */

#if defined _hnsic_maps_included
    #endinput
#endif
#define _hnsic_maps_included

/* ---- Constants ---- */
#define HNSIC_MAPS_MAX_MAPS     64
#define HNSIC_MAPS_MAX_NAME     64
#define HNSIC_MAPS_MAX_NOMS     128
#define HNSIC_MAPS_MAX_PLAYERS  33

#define HNSIC_SECTION_KNIFE     0
#define HNSIC_SECTION_SKILL     1
#define HNSIC_SECTION_BOOST     2
#define HNSIC_SECTION_COUNT     3

/* ---- Natives ---- */

/**
 * Initialize the maps system (load config, parse sections).
 * Returns 1 on success, 0 on failure.
 */
native hnsic_maps_init();

/**
 * Check if the current map is a knife map.
 * Returns 1 if knife, 0 otherwise.
 */
native hnsic_maps_is_knife();

/**
 * Check if the current map is a boost map.
 * Returns 1 if boost, 0 otherwise.
 */
native hnsic_maps_is_boost();

/**
 * Check if the current map is a skill map.
 * Returns 1 if skill, 0 otherwise.
 */
native hnsic_maps_is_skill();

/**
 * Load and apply settings for the current map.
 * Sets roundtime, freezetime, flash, smoke, and hnsic_boost CVAR.
 * Returns 1 on success, 0 if map not found in any section.
 */
native hnsic_maps_load_settings();

/**
 * Get a random map name from the specified section.
 *
 * @param section   - Section name string: "knife", "skill", "boost"
 * @param dest      - Output buffer for the map name
 * @param len       - Maximum buffer length
 *
 * Returns 1 if a map was found, 0 if section is empty or invalid.
 */
native hnsic_maps_get_random_map(const section[], dest[], len);

/**
 * Get the number of maps in a given section.
 *
 * @param section   - Section name string: "knife", "skill", "boost"
 *
 * Returns map count, or -1 if section is invalid.
 */
native hnsic_maps_get_count(const section[]);

/* ---- Forwards ---- */

/**
 * Called after maps have been successfully loaded from config.
 */
forward hnsic_maps_loaded();

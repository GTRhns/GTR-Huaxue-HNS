#if defined _plugins_core_included
  #endinput
#endif
#define _plugins_core_included

#define PLUGINS_CORE_VERSION_MAJOR 1
#define PLUGINS_CORE_VERSION_MINOR 3

const FFADE_IN       = 0x0000; // Just here so we don't pass 0 into the function
const FFADE_OUT      = 0x0001; // Fade out (not in)
const FFADE_MODULATE = 0x0002; // Modulate (don't blend)
const FFADE_STAYOUT  = 0x0004; // ignores the duration, stays faded out until new ScreenFade message received

enum _: sound_file_type
{
  SFT_UNKNOWN,
  SFT_WAV,
  SFT_MP3
}

enum _:say_type
{
  ST_SAY      = 0,
  ST_SAY_TEAM = 1
}

enum _: exists_status
{
  ES_ORPHEU,
  ES_REAPI,
  ES_SIZE
}

enum (<<=1)
{
  NEED_UPDATE = 1,
  CREATE_IF_NOT_EXIST
}

enum (<<=1)
{
  STOP_IF_NOT_EXIST = 1
}

enum (<<= 1)
{
  GP_None = 0,           // No filter (Default)
  GP_ExcludeDead = 1,    // Do not include dead clients
  GP_ExcludeAlive,       // Do not include alive clients
  GP_ExcludeBots,        // Do not include bots
  GP_ExcludeHuman,       // Do not include human clients
  GP_ExcludeTTteam,      // Do not include TERRORIST Team
  GP_ExcludeCTteam,      // Do not include CT Team
  GP_ExcludeSTteam,      // Do not include SPECTATOR Team
  GP_ExcludeUTteam,      // Do not include UNASSIGNED team
  GP_MatchNameSubstring, // Match with part of name
  GP_CaseInsensitive,    // Match case insensitive
  GP_ExcludeHLTV,        // Do not include HLTV proxies
  GP_SkipTeamCounting,   // Do not count players num in each team
  GP_Randomize           // Randomize players list
}

enum{
  GPS_NONE,
  GPS_ONE,
  GPS_MULTIPLE,
  GPS_ALL
}

enum
{
  AMXX_LOGS,
  AMXX_CONFIGSDIR,
  AMXX_DATADIR
}

native pc_get_str(key, buffer[]);
native pc_get_amxmodx_version();
native pc_debug_log(dbg_lvl, const fmt[], any:...);
native pc_init_debug(const cvar_name[], version_int);
native pc_precache_sound_safe(const sound[], &sound_type = SFT_UNKNOWN, target_sound_type = SFT_UNKNOWN);
native pc_precache_player_model(const model[]);
native pc_precache_model_safe(const model[], ignore_exists = 0);
native pc_find_public(const func_name[], &plugin_id);
native pc_is_plugin_loaded(const filename[], const name[], const author[]);
native pc_is_user_steam(id);
native pc_stop_sound(id, type = SFT_WAV);
native pc_play_sound(id, const sound[], type = SFT_WAV, bool: loop = false);
native pc_screen_fade(id, const color[] = {0, 0, 0}, Float: fx_time = -1.0, Float: hold_time = 0.0, alpha = 0, flags = FFADE_IN, bool: reliable = false, bool: external = false);
native pc_screenshake(id, const Float: center[3], Float: amplitude, Float: frequency, Float: duration, Float: radius);
native pc_is_has_access(id, const access_flags[]);
native pc_nvault_prune(nvault_handle, start_timestamp, end_timestamp);
native pc_check_exists(es_index);
native pc_multi_mkdir(const path[]);
native pc_get_log_filename(log_filename[256] = "", const log_subfolder[] = "");
native pc_init_user_msgid(user_msgids_storage[]);
native pc_exec_cfg_file(Array: handle, const filename[], flags = CREATE_IF_NOT_EXIST);
native pc_str_to_color(const color_str[], &r = 0, &g = 0, &b = 0);
native pc_str_to_coord(const string[], any: origin[]);
native pc_str_to_hud(const string[], any: value[]);
native pc_str_to_flags(const value[], access_flags[], min_value = ADMIN_ALL, max_value = cellmax);
native pc_parse_text_file(const full_filename[], const callback_name[]);
native pc_get_players(players[32], &pl_num, flags, const compare[], pl_nums_by_team[4] = {0, ...});
native pc_get_players_by_arg_str(const string[], players[32], &pl_num);
native pc_show_progress_bar(id, duration, start_percent = 0, &see_progress_bar = 0);
native pc_hide_progress_bar(id, &see_progress_bar);
native pc_set_score(id, frags, deaths, bool:scoreboard = true);
native pc_replace_template(id, dest_str[], dest_str_size, const src_str[], const reason_str[] = "", const ban_time_str[] = "");
native is_equal_classname(entity, const target_classname[], c = 0);

native pc_settings_menu_item_insert(position, const item_name[], const access_flags[], const handler[], const behaviour[]);
native pc_settings_menu_display(id);

native pc_exists_in_chat_white_list(text[]);

#if AMXX_VERSION_NUM < 183
  native set_dhudmessage(red = 200, green = 100, blue = 0, Float:x = -1.0, Float:y = 0.35, effects = 0, Float:fxtime = 6.0, Float:holdtime = 12.0, Float:fadeintime = 0.1, Float:fadeouttime = 0.2);
  native show_dhudmessage(index, const fmt[], any:...);
  native read_argv_int(arg_index);
  native Float:read_argv_float(arg_index);
  
  native bool:get_pdata_bool(_index, _offset, _linuxdiff = 20, _macdiff = 20);
  native set_pdata_bool(_index, _offset, bool:_value, _linuxdiff = 20, _macdiff = 20);
  native get_pdata_short(_index, _offset, _linuxdiff = 20, _macdiff = 20);
  native set_pdata_short(_index, _offset, _value, _linuxdiff = 20, _macdiff = 20);
  native get_pdata_vector(_index, _offset, Float:_output[3], _linuxdiff = 20, _macdiff = 20);
  native set_pdata_vector(_index, _offset, Float:_origin[3], _linuxdiff = 20, _macdiff = 20);
#endif

/*
* This is the callback from the Plugins Core plugin that gives major/minor versions for verifying compatibility for Plugins Core versions.
* If an AMXX plugin gets a failure, then you do need to upgrade to the latest version of the Plugins Core plugin or update the files included for AMXX plugins.
* Do not modify this!
*/
public __plugins_core_version_check(const majorVersion, const minorVersion)
{
  //server_print("__plugins_core_version_check: %d - %d, %d - %d)", majorVersion, PLUGINS_CORE_VERSION_MAJOR, minorVersion, PLUGINS_CORE_VERSION_MINOR);

  if (majorVersion != PLUGINS_CORE_VERSION_MAJOR) {
    new temp[128];
    formatex(temp, charsmax(temp), "[Plugins Core]: Api major version mismatch; expected %d, real %d", PLUGINS_CORE_VERSION_MAJOR, majorVersion);
    set_fail_state(temp);
    return;
  }

  if (minorVersion < PLUGINS_CORE_VERSION_MINOR) {
    new temp[128];
    formatex(temp, charsmax(temp), "[Plugins Core]: Api minor version mismatch; expected at least %d, real %d", PLUGINS_CORE_VERSION_MINOR, minorVersion);
    set_fail_state(temp);
    return;
  }
}
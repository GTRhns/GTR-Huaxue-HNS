#if defined _hnsic_stats_included
    #endinput
#endif
#define _hnsic_stats_included

/**
 * Stats Native Functions for HNSIC
 * These natives allow other plugins to read player statistics tracked by HnsicStats
 */

/**
 * Get player's kills (round or all)
 * @param type 0 = round, 1 = all
 * @param id   Player ID
 * @return     Kill count
 */
native hnsic_get_kills(type, id);

/**
 * Get player's deaths (round or all)
 */
native hnsic_get_deaths(type, id);

/**
 * Get player's assists (round or all)
 */
native hnsic_get_assists(type, id);

/**
 * Get player's stabs (round or all)
 */
native hnsic_get_stabs(type, id);

/**
 * Get player's CT damage (round or all)
 */
native hnsic_get_dmg_ct(type, id);

/**
 * Get player's TT damage (round or all)
 */
native hnsic_get_dmg_tt(type, id);

/**
 * Get player's run distance (Float)
 */
native Float:hnsic_get_runned(type, id);

/**
 * Get player's run time (Float)
 */
native Float:hnsic_get_runned_time(type, id);

/**
 * Get player's average speed (Float)
 */
native Float:hnsic_get_avg_speed(type, id);

/**
 * Get player's flash time (Float)
 */
native Float:hnsic_get_flashtime(type, id);

/**
 * Get player's hide time (Float)
 */
native Float:hnsic_get_hidetime(type, id);

/**
 * Get player's play time (Float)
 */
native Float:hnsic_get_playtime(type, id);

/**
 * Get player's survival time (Float)
 */
native Float:hnsic_get_surv(type, id);

/**
 * Get player's ownage count (round or all)
 */
native hnsic_get_ownages(type, id);

/**
 * Get player's bhop count (round or all)
 */
native hnsic_get_bhop_count(type, id);

/**
 * Get player's bhop percent (Float)
 */
native Float:hnsic_get_bhop_percent(type, id);

/**
 * Get player's sgs count (round or all)
 */
native hnsic_get_sgs_count(type, id);

/**
 * Get player's sgs percent (Float)
 */
native Float:hnsic_get_sgs_percent(type, id);

/**
 * Get player's ddrun count (round or all)
 */
native hnsic_get_ddrun_count(type, id);

/**
 * Get player's ddrun percent (Float)
 */
native Float:hnsic_get_ddrun_percent(type, id);

/**
 * Stats type constants
 */
#define STATS_ROUND 0
#define STATS_ALL   1

/**
 * Forward: Called when stats are applied (round end or match end)
 * @param isEndMatch 1 if match ended, 0 if just round ended
 */
forward hnsic_apply_stats(isEndMatch);

/**
 * Forward: Called when a player leaves during match
 * @param id    Player ID
 * @param team  Team they were on
 */
forward hnsic_save_leave_stats(id, team);

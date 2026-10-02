// ============================================
// HnsMatchAccount Include File
// ============================================

#if defined _hns_account_included
    #endinput
#endif
#define _hns_account_included

#include <amxmodx>

// Natives
native bool:hns_is_logged_in(id);
native hns_get_player_id(id, szOutput[], iLen);
native hns_get_player_stats(id, stats[3]);  // stats[0]=matches, stats[1]=wins, stats[2]=kills
native hns_get_ui_color(id);

// Forwards
forward hns_player_logged_in(id);
forward hns_player_logged_out(id);
forward hns_player_registered(id, const szUsername[], const szRandomID[]);

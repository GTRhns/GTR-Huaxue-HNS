#if defined _mode_extra_included
  #endinput
#endif

#define _mode_extra_included

new g_iDesertCount[MAX_PLAYERS + 1];

// ============================================================
// 补充模块 (stubs): 为 mode_mix.inl 提供其依赖但未定义的符号
// duel / ascension / vampire / deserter 模块尚未实现, 这里给出
// 空实现, 保证编译通过且不改变现有行为。
// ============================================================

// ---- 参赛玩家管理 ----
stock markPlayingPlayersForMatch() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		new TeamName:iTeam = getUserTeam(id);
		if (iTeam == TEAM_TERRORIST || iTeam == TEAM_CT) {
			g_ePlayerInfo[id][PLAYER_MATCH] = true;
			copy(g_ePlayerInfo[id][PLAYER_TEAM], charsmax(g_ePlayerInfo[][PLAYER_TEAM]), iTeam == TEAM_TERRORIST ? "TERRORIST" : "CT");
		} else {
			g_ePlayerInfo[id][PLAYER_MATCH] = false;
		}
	}
}

stock forceUnmatchedToSpec() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (!g_ePlayerInfo[id][PLAYER_MATCH])
			transferUserToSpec(id);
	}
}

// ---- 弃赛惩罚 (deserter) ----
stock deserter_match_start() {
	// 记录本场比赛开始, 用于弃赛惩罚统计 (暂无实现)
}

stock bool:deserter_is_banned(id) {
	return false;
}

stock deserter_get_ban_remaining(id) {
	return 0;
}

stock deserter_apply_penalty(id) {
}

stock deserter_save(id) {
}


// ---- 决斗模式 (duel) ----
stock duel_start() {}
stock duel_freezeend() {}
stock duel_restartround() {}
stock duel_pause() {}
stock duel_swap() {}
stock duel_roundstart() {}
stock duel_roundend(bool:win_ct = false) {}
stock duel_killed(victim, killer) {}
stock duel_falldamage(id, Float:damage) {}
stock duel_reverttimer() {}

// ---- 点位积分模式 (ascension / pointscap) ----
stock ascension_start() {}
stock ascension_stop() {}

// ---- 吸血鬼模式 (vampire) ----
stock vamp_start() {}
stock vamp_stop() {}

stock deserter_clear_on_match_end() {}
stock matchControl_reset() {}

stock cvar_update_wintime(Float:fTime) {
	set_cvar_float("hns_wintime", fTime);
}
stock save_reset_data() {}
stock getRoundsScore(&iCT, &iTT) {
	iCT = g_iRoundsScore[HNS_TEAM_B];
	iTT = g_iRoundsScore[HNS_TEAM_A];
}

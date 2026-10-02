#if defined _natives_included
  #endinput
#endif

#define _natives_included

register_hns_natives() {
	register_native("hns_get_prefix", "native_get_prefix");
	register_native("hns_get_flag_watcher", "native_flag_watcher");
	register_native("hns_get_flag_fullwatcher", "native_flag_fullwatcher");
	register_native("hns_get_flag_admin", "native_get_flag_admin");

	register_native("hns_get_mode", "native_get_mode");
	register_native("hns_set_mode", "native_set_mode");

	register_native("hns_get_status", "native_get_status");
	register_native("hns_get_state", "native_get_state");

	register_native("hns_get_rules", "native_get_rules");

	register_native("hns_isboost", "native_hns_isboost");

	register_native("hns_get_score_a", "native_get_score_a");
	register_native("hns_get_score_b", "native_get_score_b");

	register_native("hns_get_is_team_tt", "native_get_is_team_tt");

	register_native("hns_get_point_distance", "native_get_point_distance");
	register_native("hns_get_players_distance", "native_get_players_distance");

	register_native("hns_deserter_is_banned", "native_deserter_is_banned");
	register_native("hns_deserter_get_remaining", "native_deserter_get_remaining");
	register_native("hns_deserter_get_count", "native_deserter_get_count");

	// ★ 独立报名插件调用的原生: 直接开始比赛 (走 "比赛即将开始" 缓冲期)
	register_native("hns_begin_external_match", "native_hns_begin_external_match");
	register_native("hns_external_set_sponsor", "native_hns_external_set_sponsor");
	register_native("hns_external_set_match_mode", "native_hns_external_set_match_mode");
	register_native("hns_external_set_match_time", "native_hns_external_set_match_time");
	register_native("hns_external_set_match_score", "native_hns_external_set_match_score");

	// ★ v5.6.0 公开只读接口: 比赛/玩家/规则状态查询
	register_native("hns_get_current_gameplay", "native_hns_get_current_gameplay");
	register_native("hns_is_knife_map", "native_hns_is_knife_map");
	register_native("hns_get_team_size", "native_hns_get_team_size");
	register_native("hns_get_team_size_tt", "native_hns_get_team_size_tt");
	register_native("hns_get_wintime", "native_hns_get_wintime");
	register_native("hns_is_sponsor_match", "native_hns_is_sponsor_match");
	register_native("hns_is_persistent_sponsor", "native_hns_is_persistent_sponsor");
	register_native("hns_get_match_starter", "native_hns_get_match_starter");
	register_native("hns_is_player_in_match", "native_hns_is_player_in_match");
	register_native("hns_get_player_hns_team", "native_hns_get_player_hns_team");
	register_native("hns_is_player_tt", "native_hns_is_player_tt");
	register_native("hns_get_players_count", "native_hns_get_players_count");
	register_native("hns_get_round_time", "native_hns_get_round_time");
	register_native("hns_get_rounds_max", "native_hns_get_rounds_max");
	register_native("hns_get_rounds_win", "native_hns_get_rounds_win");
	register_native("hns_get_rounds_score_t", "native_hns_get_rounds_score_t");
	register_native("hns_get_rounds_score_ct", "native_hns_get_rounds_score_ct");
	register_native("hns_is_rounds_mode", "native_hns_is_rounds_mode");
	register_native("hns_is_duel_mode", "native_hns_is_duel_mode");

	// ★ v5.6.0 公开控制接口: 外部插件统一中止/暂停/恢复/改人数
	register_native("hns_external_end_match", "native_hns_external_end_match");
	register_native("hns_external_pause_match", "native_hns_external_pause_match");
	register_native("hns_external_unpause_match", "native_hns_external_unpause_match");
	register_native("hns_external_set_team_size", "native_hns_external_set_team_size");

	// 旧版 HD 菜单兼容 native
	register_native("mix_start", "native_mix_start");
	register_native("mix_stop", "native_mix_stop");
	register_native("mix_pause", "native_mix_pause");
	register_native("mix_unpause", "native_mix_unpause");
	register_native("mix_restartround", "native_mix_restartround");
	register_native("mix_roundstart", "native_mix_roundstart");
	register_native("mix_roundend", "native_mix_roundend");
	register_native("mix_freezeend", "native_mix_freezeend");
	register_native("mix_swap", "native_mix_swap");
	register_native("mix_killed", "native_mix_killed");
	register_native("mix_falldamage", "native_mix_falldamage");

	set_native_filter("match_system_additons");
}

public native_get_prefix(amxx, params) {
	enum { argPrefix = 1, argLen };
	new szPrefix[24];
	format(szPrefix, charsmax(szPrefix), "[^3%s^1]", g_szPrefix);
	set_string(argPrefix, szPrefix, get_param(argLen));
}

public native_flag_watcher(amxx, params) {
	return read_flags(g_szWatcherFlag);
}

public native_flag_fullwatcher(amxx, params) {
	return read_flags(g_szFullWatcherFlag);
}

public native_get_flag_admin(amxx, params) {
	return read_flags(g_szAdminFlag);
}

public native_get_mode(amxx, params) {
	return g_iCurrentMode;
}

public native_set_mode(amxx, params) {
	enum { iSetMode = 1 };
	switch (get_param(iSetMode)) {
		case MODE_TRAINING: {
			training_start();
		}
		case MODE_KNIFE: {
			kniferound_start();
		}
		case MODE_PUB: {
			pub_start();
		}
		case MODE_DM: {
			dm_start();
		}
		case MODE_ZM: {
			zm_start();
		}
		case MODE_MIX: {
			mix_start();
		}
		case MODE_ASCENSION: {
			ascension_start();
		}
		case MODE_VAMP: {
			vamp_start();
		}
	}
}

public Float:native_get_score_a() {
	return Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A];
}

public Float:native_get_score_b() {
	return Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B];
}

public HNS_TEAM:native_get_is_team_tt() {
	return g_isTeamTT;
}

public native_get_point_distance() {
	return g_iPointsDistance;
}

public native_get_players_distance() {
	return g_iPlayerDistance;
}

public bool:native_deserter_is_banned(amxx, params) {
	enum { arg_id = 1 };
	return deserter_is_banned(get_param(arg_id));
}

public native_deserter_get_remaining(amxx, params) {
	enum { arg_id = 1 };
	return deserter_get_ban_remaining(get_param(arg_id));
}

public native_deserter_get_count(amxx, params) {
	enum { arg_id = 1 };
	new id = get_param(arg_id);
	return g_iDesertCount[id];
}

public native_hns_isboost() {
	return g_iSettings[HNSBOOST];
}

// ============================================
// 旧版 HD 菜单兼容 native - 转发到模式函数
// ============================================
public native_mix_start() { mix_start(); }
public native_mix_stop() { mix_stop(); }
public native_mix_pause() { mix_pause(); }
public native_mix_unpause() { mix_unpause(); }
public native_mix_restartround() { mix_restartround(); }
public native_mix_roundstart() { mix_roundstart(); }
public native_mix_freezeend() { mix_freezeend(); }
public native_mix_swap() { mix_swap(); }
public native_mix_roundend(amxx, params) {
	enum { argWin = 1 };
	mix_roundend(bool:get_param(argWin));
}
public native_mix_killed(amxx, params) {
	enum { argVictim = 1, argKiller = 2 };
	mix_killed(get_param(argVictim), get_param(argKiller));
}
public native_mix_falldamage(amxx, params) {
	enum { argId = 1, argDmg = 2 };
	mix_falldamage(get_param(argId), Float:get_param_f(argDmg));
}

// ============================================
// ★ v5.6.0 公开只读接口实现
// ============================================
public native_hns_get_current_gameplay() {
	return g_iCurrentGameplay;
}

public bool:native_hns_is_knife_map() {
	return hns_is_knife_map();
}

public native_hns_get_team_size() {
	return g_eMatchInfo[e_mTeamSize];
}

public native_hns_get_team_size_tt() {
	return g_eMatchInfo[e_mTeamSizeTT];
}

public Float:native_hns_get_wintime() {
	return g_eMatchInfo[e_mWintime];
}

public bool:native_hns_is_sponsor_match() {
	return g_bSponsorMatch;
}

public bool:native_hns_is_persistent_sponsor() {
	return g_bPersistentSponsor;
}

public native_hns_get_match_starter() {
	return g_iMatchStarter;
}

public bool:native_hns_is_player_in_match(amxx, params) {
	enum { arg_id = 1 };
	return bool:g_ePlayerInfo[get_param(arg_id)][PLAYER_MATCH];
}

// 返回玩家所属 HNS 队伍: 1=HNS_TEAM_A, 0=HNS_TEAM_B, -1=未分配
public HNS_TEAM:native_hns_get_player_hns_team(amxx, params) {
	enum { arg_id = 1 };
	new id = get_param(arg_id);
	if (id < 1 || id > MAX_PLAYERS) return HNS_TEAM:-1;
	if (!is_user_connected(id)) return HNS_TEAM:-1;

	switch (g_ePlayerInfo[id][PLAYER_ROLE]) {
		case ROLE_TEAM_A: return HNS_TEAM_A;
		case ROLE_TEAM_B: return HNS_TEAM_B;
	}
	return HNS_TEAM:-1;
}

// 玩家是否处于 TT(当前躲藏方) HNS 队伍
public bool:native_hns_is_player_tt(amxx, params) {
	enum { arg_id = 1 };
	new id = get_param(arg_id);
	if (id < 1 || id > MAX_PLAYERS) return false;

	switch (g_ePlayerInfo[id][PLAYER_ROLE]) {
		case ROLE_TEAM_A: return (g_isTeamTT == HNS_TEAM_A);
		case ROLE_TEAM_B: return (g_isTeamTT == HNS_TEAM_B);
	}
	return false;
}

// 返回指定 HNS 队伍(A或B)已分配玩家数
public native_hns_get_players_count(amxx, params) {
	enum { arg_team = 1 };
	new iTeam = get_param(arg_team);
	new iCount, iPlayers[MAX_PLAYERS], iNum;

	if (iTeam == HNS_TEAM_A) {
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			if (g_ePlayerInfo[iPlayers[i]][PLAYER_ROLE] == ROLE_TEAM_A) iCount++;
		}
	} else if (iTeam == HNS_TEAM_B) {
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			if (g_ePlayerInfo[iPlayers[i]][PLAYER_ROLE] == ROLE_TEAM_B) iCount++;
		}
	}
	return iCount;
}

public Float:native_hns_get_round_time() {
	return g_flRoundTime;
}

public native_hns_get_rounds_max() {
	return g_iRoundsMaxRounds;
}

public native_hns_get_rounds_win() {
	return g_iRoundsWinRounds;
}

public native_hns_get_rounds_score_t() {
	return g_iRoundsScoreT;
}

public native_hns_get_rounds_score_ct() {
	return g_iRoundsScoreCT;
}

public bool:native_hns_is_rounds_mode() {
	return (g_iCurrentMode == MODE_ROUNDS);
}

public bool:native_hns_is_duel_mode() {
	return (g_iCurrentRules == RULES_DUEL);
}

// ============================================
// ★ v5.6.0 公开控制接口实现
// ============================================
// 外部中止/结束当前比赛 (等价于观察员 "停止比赛")
public native_hns_external_end_match(amxx, params) {
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_END]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_END], _);
		return 1;
	}
	return 0;
}

// 外部暂停当前比赛
public native_hns_external_pause_match(amxx, params) {
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE], _);
		return 1;
	}
	return 0;
}

// 外部恢复当前比赛
public native_hns_external_unpause_match(amxx, params) {
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE], _);
		return 1;
	}
	return 0;
}

// 开赛前/比赛中设置双方人数 (size=总人数, sizeTT=TT方人数)
public native_hns_external_set_team_size(amxx, params) {
	enum { argSize = 1, argSizeTT = 2 };
	new iSize = get_param(argSize);
	new iSizeTT = get_param(argSizeTT);
	if (iSize < 1) iSize = 5;
	if (iSizeTT < 1) iSizeTT = iSize;

	g_eMatchInfo[e_mTeamSize] = iSize;
	g_eMatchInfo[e_mTeamSizeTT] = iSizeTT;
	return 1;
}
// ============================================================
//  比赛前公共模式 (MODE_LOBBY)
// ------------------------------------------------------------
//  这是一个"隐藏"模式: 任何指令 / 菜单 / hns_set_mode 函数
//  都无法切换到它。它只属于比赛流程本身 —— 由 AI 报名系统
//  在开启报名时通过 native hns_ai_enter_lobby() 激活。
//
//  行为上复用训练模式玩法 (GAMEPLAY_TRAINING), 玩家在大厅里
//  可以正常游玩, 直到收团开赛切换到比赛模式 (MODE_MIX)。
// ============================================================

public lobby_init() {
	g_ModFuncs[MODE_LOBBY][MODEFUNC_START]		= CreateOneForward(g_PluginId, "lobby_start");
	g_ModFuncs[MODE_LOBBY][MODEFUNC_PLAYER_JOIN]	= CreateOneForward(g_PluginId, "lobby_player_join", FP_CELL);
}

public lobby_start() {
	g_iCurrentMode = MODE_LOBBY;
	g_iMatchStatus = MATCH_NONE;
	g_eMatchState = STATE_DISABLED;

	update_hostname_prefix("");
	ChangeGameplay(GAMEPLAY_TRAINING);
	set_cvars_mode(MODE_LOBBY);
	hns_restart_round(1.0);
}

// 大厅里玩家入场直接复活, 不做任何玩家名单/比赛校验
public lobby_player_join(id) {
	if (g_eMatchState == STATE_DISABLED)
		rg_round_respawn(id);
}

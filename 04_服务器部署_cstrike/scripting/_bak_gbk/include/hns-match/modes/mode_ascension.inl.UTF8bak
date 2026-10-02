// ============================================
// HnsMatchSystem - Ascension Mode (PointScap)
// 点位积分制 - T进入区域直接得分
// 完全重写版 - 简洁可靠，不依赖freezeend事件链
// ============================================

public ascension_init() {
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_START]		= CreateOneForward(g_PluginId, "ascension_start");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_END]		= CreateOneForward(g_PluginId, "ascension_stop");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_PAUSE]		= CreateOneForward(g_PluginId, "ascension_pause");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_UNPAUSE]	= CreateOneForward(g_PluginId, "ascension_unpause");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_ROUNDSTART]	= CreateOneForward(g_PluginId, "ascension_roundstart");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_ROUNDEND]	= CreateOneForward(g_PluginId, "ascension_roundend", FP_CELL);
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_FREEZEEND]	= CreateOneForward(g_PluginId, "ascension_freezeend");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_RESTARTROUND]= CreateOneForward(g_PluginId, "ascension_restartround");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_SWAP]		= CreateOneForward(g_PluginId, "ascension_swap");
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_PLAYER_JOIN]= CreateOneForward(g_PluginId, "ascension_player_join", FP_CELL);
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_PLAYER_LEAVE]= CreateOneForward(g_PluginId, "ascension_player_leave", FP_CELL);
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_KILL]		= CreateOneForward(g_PluginId, "ascension_killed", FP_CELL, FP_CELL);
	g_ModFuncs[MODE_ASCENSION][MODEFUNC_FALLDAMAGE]	= CreateOneForward(g_PluginId, "ascension_falldamage", FP_CELL, FP_FLOAT);
	
	// ★ 点位分数设置已移到主菜单
}

// ============================================
// 模式开始
// ============================================
public ascension_start() {
	// ★ 不调用 match_reset_data()，由 mix_start() 已调用
	ChangeGameplay(GAMEPLAY_HNS);
	
	g_iCurrentMode = MODE_ASCENSION;
	update_hostname_prefix("ASCENSION");
	g_iCurrentRules = RULES_POINTSCAP;
	g_iMatchStatus = MATCH_STARTED;
	g_eMatchState = STATE_PREPARE;
	g_isTeamTT = HNS_TEAM_A;
	
	g_flScoreA = 0.0;
	g_flScoreB = 0.0;
	g_iPointScapRound = 0;
	g_iZoneCount = 0;
	
	pointscap_load_zones();
	
	server_print("[Ascension] Zones loaded: %d", g_iZoneCount);
	
	set_cvars_mode(MODE_ASCENSION);
	loadMapCFG();
	
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", "TERRORIST");
	g_eMatchInfo[e_mTeamSizeTT] = iNum;
	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
	
	hns_restart_round(2.0);
	// ★ 不调用 MATCH_START forward，由 mix_start() 统一调用
}

// ============================================
// 模式停止
// ============================================
public ascension_stop() {
	remove_all_tasks();
	ExecuteForward(g_hForwards[MATCH_CANCEL], _);
	match_reset_data();
	training_start();
}

// ============================================
// 回合开始 ★ 核心：直接启动检测，不依赖任何事件链
// ============================================
public ascension_roundstart() {
	remove_all_tasks();
	
	// ★ 如果已暂停，不覆盖状态
	if (g_eMatchState == STATE_PAUSED) {
		server_print("[Ascension] roundstart skipped: game is paused");
		return;
	}
	
	g_eMatchState = STATE_ENABLED;
	// ★ 不重新加载点位，只在 ascension_start 加载一次
	// 原点位数据不变，仅重置回合状态
	
	server_print("[Ascension] roundstart: using %d preloaded zones", g_iZoneCount);
	
	// ★ 调试：打印每个zone的状态
	for (new z = 0; z < g_iZoneCount; z++) {
		server_print("[Ascension] RoundStart Zone %d: label=%c type=%d enabled=%d mins=(%.0f,%.0f,%.0f) maxs=(%.0f,%.0f,%.0f)",
			z, 'A' + g_eZones[z][ZONE_LABEL], g_eZones[z][ZONE_TYPE], g_eZones[z][ZONE_ENABLED],
			g_eZones[z][ZONE_MINS][0], g_eZones[z][ZONE_MINS][1], g_eZones[z][ZONE_MINS][2],
			g_eZones[z][ZONE_MAXS][0], g_eZones[z][ZONE_MAXS][1], g_eZones[z][ZONE_MAXS][2]);
	}
	
	g_bPointScapDetectFirstRun = true; // ★ 重置首次运行标记
	
	g_iPointScapRound++;
	g_flRoundTime = 0.0;
	
	// 重置区域状态
	for (new i = 0; i < g_iZoneCount; i++) {
		g_eZones[i][ZONE_STATUS] = 0;
		g_eZones[i][ZONE_CAPTURED] = 0;
		g_eZones[i][ZONE_CAPTURE_TIME] = 0.0;
		g_eZones[i][ZONE_CAPTURED_TYPE] = 0;
		g_eZones[i][ZONE_PLAYER_COUNT] = 0;
	}
	
	// 标记比赛玩家
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (!is_user_connected(id)) continue;
		if (getUserTeam(id) == TEAM_TERRORIST || getUserTeam(id) == TEAM_CT) {
			g_ePlayerInfo[id][PLAYER_MATCH] = true;
			copy(g_ePlayerInfo[id][PLAYER_TEAM], charsmax(g_ePlayerInfo[][PLAYER_TEAM]), 
				fmt("%s", getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT"));
		} else {
			g_ePlayerInfo[id][PLAYER_MATCH] = false;
		}
	}
	
	// 初始化检测时间窗口
	g_flPointScapDetectTime = float(g_iPointScapDetectTime);
	if (g_flPointScapDetectTime < 10.0) g_flPointScapDetectTime = 10.0;
	
	// ★ 直接启动检测任务（每1.0秒，等冻结期过后开始计分）
	set_task(1.0, "taskAscensionDetect", TASK_POINTSCAP_DETECT, .flags = "b");
	
	// 启动HUD
	if (!task_exists(TASK_POINTSCAP_HUD))
		set_task(1.0, "taskAscensionHud", TASK_POINTSCAP_HUD, .flags = "b");
	
	// 刀杀计时
	g_flPointScapKnifeTime = float(g_iPointScapKnifeTime);
	set_task(3.0, "taskAscensionKnife", TASK_POINTSCAP_KNIFE, .flags = "b");
	
	server_print("[Ascension] Round %d started: zones=%d, detectTime=%.0f", 
		g_iPointScapRound, g_iZoneCount, g_flPointScapDetectTime);
	// ★ Restore scores from pre-round save (if this is a restart, not first round)
	if (g_flScorePreRound[0] > 0.0 || g_flScorePreRound[1] > 0.0) {
		g_flScoreA = g_flScorePreRound[0];
		g_flScoreB = g_flScorePreRound[1];
	}
	// ★ 保存回合开始时的分数（暂停恢复用）
	g_flScorePreRound[0] = g_flScoreA;
	g_flScorePreRound[1] = g_flScoreB;
	// ★ 用 HUD 中心消息，不会被 ChatManager 拦截
	set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 6.0, 5.0);
	show_hudmessage(0, "[Ascension] 回合 %d 已启动!^n点位=%d 检测时间=%.0f秒^n3秒后开始计分",
		g_iPointScapRound, g_iZoneCount, g_flPointScapDetectTime);
	
	ExecuteForward(g_hForwards[HNS_ROUND_START], _);
}

// ============================================
// 冻结结束 - 仅作为兼容保留，实际检测已在roundstart启动
// ============================================
public ascension_freezeend() {
	if (g_eMatchState != STATE_ENABLED)
		return PLUGIN_HANDLED;
	
	// 如果检测还没启动（极端情况），现在启动
	if (!task_exists(TASK_POINTSCAP_DETECT)) {
		set_task(1.0, "taskAscensionDetect", TASK_POINTSCAP_DETECT, .flags = "b");
	}
	if (!task_exists(TASK_POINTSCAP_KNIFE)) {
		g_flPointScapKnifeTime = float(g_iPointScapKnifeTime);
		set_task(1.0, "taskAscensionKnife", TASK_POINTSCAP_KNIFE, .flags = "b");
	}
	
	set_task(5.0, "taskCheckAfk");
	
	if (g_bHnsBannedInit) {
		if (checkUserBan()) return PLUGIN_HANDLED;
	}
	
	ExecuteForward(g_hForwards[HNS_ROUND_FREEZEEND], _);
	return PLUGIN_HANDLED;
}

// ============================================
// ★ 核心：点位检测任务（每1.0秒）
// 使用包围盒判定，并接入停留时间
// ============================================
public taskAscensionDetect() {
	if (g_eMatchState != STATE_ENABLED) {
		if (task_exists(TASK_POINTSCAP_DETECT)) remove_task(TASK_POINTSCAP_DETECT);
		g_bPointScapDetectFirstRun = true;
		return;
	}
	
	g_flPointScapDetectTime -= 1.0;
	
	if (g_flPointScapDetectTime <= 0.0) {
		server_print("[Ascension] 检测时间结束! A=%.1f B=%.1f", g_flScoreA, g_flScoreB);
		if (task_exists(TASK_POINTSCAP_DETECT)) remove_task(TASK_POINTSCAP_DETECT);
		g_bPointScapDetectFirstRun = true;
		return;
	}
	
	// 获取所有存活T
	new iTPlayers[MAX_PLAYERS], iTNum;
	get_players(iTPlayers, iTNum, "ae", "TERRORIST");
	
	if (g_bPointScapDetectFirstRun) {
		g_bPointScapDetectFirstRun = false;
		server_print("[Ascension] 检测启动: zones=%d T=%d time=%.0f", g_iZoneCount, iTNum, g_flPointScapDetectTime);
		// ★ 打印每个zone的详细信息
		for (new z = 0; z < g_iZoneCount; z++) {
			server_print("[Ascension] Zone %d: label=%c type=%d enabled=%d captured=%d mins=(%.0f,%.0f,%.0f) maxs=(%.0f,%.0f,%.0f)",
				z, 'A' + g_eZones[z][ZONE_LABEL], g_eZones[z][ZONE_TYPE], g_eZones[z][ZONE_ENABLED], g_eZones[z][ZONE_CAPTURED],
				g_eZones[z][ZONE_MINS][0], g_eZones[z][ZONE_MINS][1], g_eZones[z][ZONE_MINS][2],
				g_eZones[z][ZONE_MAXS][0], g_eZones[z][ZONE_MAXS][1], g_eZones[z][ZONE_MAXS][2]);
		}
	}
	
	if (iTNum == 0) return;

	// ★ 每个 zone 独立检测：有人进入并停留足够时间才判定成功
	for (new zoneId = 0; zoneId < g_iZoneCount; zoneId++) {
		if (!g_eZones[zoneId][ZONE_ENABLED]) continue;
		if (g_eZones[zoneId][ZONE_CAPTURED]) continue; // 已占领，跳过

		new iCount = 0;
		for (new i = 0; i < iTNum; i++) {
			new id = iTPlayers[i];
			if (!is_user_alive(id)) continue;
			if (is_player_in_box(id, g_eZones[zoneId][ZONE_MINS], g_eZones[zoneId][ZONE_MAXS])) {
				iCount++;
			}
		}

		if (iCount >= 1) {
			g_eZones[zoneId][ZONE_STATUS] = 1;
			g_eZones[zoneId][ZONE_PLAYER_COUNT] = iCount;
			g_eZones[zoneId][ZONE_CAPTURE_TIME] += 1.0;

			if (g_eZones[zoneId][ZONE_CAPTURE_TIME] + 0.001 < g_flPointScapStayTime) {
				continue;
			}

			new Float:pointScore = pointscap_get_zone_score(zoneId);
			new iZoneType = g_eZones[zoneId][ZONE_TYPE];

			new iTeam = g_isTeamTT;
			if (iTeam == HNS_TEAM_A)
				g_flScoreA += pointScore;
			else
				g_flScoreB += pointScore;

			g_eZones[zoneId][ZONE_CAPTURED] = 1;
			g_eZones[zoneId][ZONE_STATUS] = 2;
			g_eZones[zoneId][ZONE_CAPTURE_TIME] = g_flPointScapStayTime;
			g_eZones[zoneId][ZONE_CAPTURED_TYPE] = iZoneType;
			g_eZones[zoneId][ZONE_PLAYER_COUNT] = iCount;

			if (g_iPointScapSoundCapture) {
				client_cmd(0, "spk buttons/blip2.wav");
			}

			new szTeamName[8];
			copy(szTeamName, charsmax(szTeamName), (iTeam == HNS_TEAM_A) ? "Team A" : "Team B");
			client_print(0, print_chat, "[Ascension] %s 占领了点位 %c (%d人点)! 得分 +%.1f | A %.1f - B %.1f",
				szTeamName, 'A' + g_eZones[zoneId][ZONE_LABEL], iZoneType, pointScore, g_flScoreA, g_flScoreB);

			server_print("[Asc-SCORE] Zone%c: 占领! %dT +%.1f -> A=%.1f B=%.1f",
				'A' + g_eZones[zoneId][ZONE_LABEL], iCount, pointScore, g_flScoreA, g_flScoreB);
		} else {
			g_eZones[zoneId][ZONE_STATUS] = 0;
			g_eZones[zoneId][ZONE_CAPTURE_TIME] = 0.0;
			g_eZones[zoneId][ZONE_CAPTURED_TYPE] = 0;
			g_eZones[zoneId][ZONE_PLAYER_COUNT] = 0;
		}
	}
	
	if (g_flScoreA >= float(g_iPointScapTargetScore)) {
		remove_all_tasks();
		ascensionFinished(1);
	} else if (g_flScoreB >= float(g_iPointScapTargetScore)) {
		remove_all_tasks();
		ascensionFinished(2);
	}
}

// ============================================
// 刀杀计时
// ============================================
public taskAscensionKnife() {
	if (g_eMatchState != STATE_ENABLED) {
		if (task_exists(TASK_POINTSCAP_KNIFE)) remove_task(TASK_POINTSCAP_KNIFE);
		return;
	}
	
	g_flPointScapKnifeTime -= 1.0;
	
	if (g_flPointScapKnifeTime <= 0.0) {
		if (task_exists(TASK_POINTSCAP_KNIFE)) remove_task(TASK_POINTSCAP_KNIFE);
	}
}

// ============================================
// HUD显示（每1秒）
// ============================================
public taskAscensionHud() {
	if (g_eMatchState != STATE_ENABLED) {
		if (task_exists(TASK_POINTSCAP_HUD)) remove_task(TASK_POINTSCAP_HUD);
		return;
	}
	
	draw_zone_boxes();
	
	// 构建区域状态
	new szZones[192] = "";
	new iZoneCount_show = g_iZoneCount;
	if (iZoneCount_show > 5) iZoneCount_show = 5;
	
	for (new i = 0; i < iZoneCount_show; i++) {
		new szZone[32];
		new cLabel = 'A' + g_eZones[i][ZONE_LABEL];
		
		if (g_eZones[i][ZONE_CAPTURED]) {
			// ★ 已占领，显示 ✓
			format(szZone, charsmax(szZone), "%c:✓", cLabel);
		} else if (g_eZones[i][ZONE_STATUS] >= 1) {
			new iType = g_eZones[i][ZONE_TYPE];
			new Float:fScore = (iType >= 5) ? g_flPointScapScore5 :
				((iType == 4) ? g_flPointScapScore4 : g_flPointScapScore3);
			format(szZone, charsmax(szZone), "%c:+%.1f", cLabel, fScore);
		} else {
			format(szZone, charsmax(szZone), "%c:--", cLabel);
		}
		
		if (i > 0) add(szZones, charsmax(szZones), "  ");
		add(szZones, charsmax(szZones), szZone);
	}
	
	// 分数显示
	new szScore[64];
	format(szScore, charsmax(szScore), "A: %.1f  |  B: %.1f  |  目标: %d", 
		g_flScoreA, g_flScoreB, g_iPointScapTargetScore);
	
	// 合并显示
	new szFullHUD[256];
	if (g_iZoneCount == 0) {
		format(szFullHUD, charsmax(szFullHUD), "%s^n^n[!] 无点位! 用 /creatzone 创建", szScore);
	} else {
		format(szFullHUD, charsmax(szFullHUD), "%s^n%s^n剩余: %.0f秒", 
			szScore, szZones, g_flPointScapDetectTime);
	}
	
	set_hudmessage(0, 200, 220, -1.0, 0.06, 0, 0.0, 1.5, 0.1, 0.0, -1);
	show_hudmessage(0, szFullHUD);
}

// ============================================
// 回合结束
// ============================================
public ascension_roundend(bool:win_ct) {
	if (g_eMatchState != STATE_ENABLED) return;
	
	g_eMatchState = STATE_PREPARE;
	remove_all_tasks();
	
	// 检查目标分
	if (g_flScoreA >= float(g_iPointScapTargetScore)) {
		ascensionFinished(1);
		return;
	} else if (g_flScoreB >= float(g_iPointScapTargetScore)) {
		ascensionFinished(2);
		return;
	}
	
	hns_swap_teams();
	ExecuteForward(g_hForwards[HNS_ROUND_END], _);
}

// ============================================
// 暂停/恢复
// ============================================
public ascension_pause() {
	if (g_eMatchState == STATE_PAUSED) return;
	remove_all_tasks();
	g_eMatchState = STATE_PAUSED;
	ChangeGameplay(GAMEPLAY_TRAINING);
	set_pause_settings();
}

public ascension_unpause() {
	if (g_eMatchState != STATE_PAUSED) return;
	
	// ★ 恢复回合开始时的分数
	g_flScoreA = g_flScorePreRound[0];
	g_flScoreB = g_flScorePreRound[1];
	
	g_eMatchState = STATE_PREPARE;
	hns_restart_round(1.0);
	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
	ChangeGameplay(GAMEPLAY_HNS);
	set_unpause_settings();
}

// ============================================
// 换边
// ============================================
public ascension_swap() {
	g_isTeamTT = HNS_TEAM:!g_isTeamTT;
	
	// ★ 交换双方分数（换边后分数跟队伍走，不跟角色走）
	new Float:flTmp = g_flScoreA;
	g_flScoreA = g_flScoreB;
	g_flScoreB = flTmp;
	
	for (new i = 0; i < g_iZoneCount; i++) {
		g_eZones[i][ZONE_STATUS] = 0;
		g_eZones[i][ZONE_CAPTURE_TIME] = 0.0;
		g_eZones[i][ZONE_CAPTURED_TYPE] = 0;
		g_eZones[i][ZONE_PLAYER_COUNT] = 0;
	}
	ResetAfkData();
}

public ascension_restartround() {
	remove_all_tasks();
	if (g_eMatchState == STATE_ENABLED)
		g_eMatchState = STATE_PREPARE;
	
	// ★ Save current scores before restart so they persist
	g_flScorePreRound[0] = g_flScoreA;
	g_flScorePreRound[1] = g_flScoreB;
}

// ============================================
// 击杀事件
// ============================================
public ascension_killed(victim, killer) {
	if (g_eMatchState != STATE_ENABLED) return;
	if (getUserTeam(victim) != TEAM_TERRORIST) return;
	if (getUserTeam(killer) != TEAM_CT) return;
	
	new iTPlayers[MAX_PLAYERS], iTNum;
	get_players(iTPlayers, iTNum, "ae", "TERRORIST");
	
	if (iTNum == 0) {
		client_cmd(0, "spk ambience/thunder_clap.wav");
		ExecuteForward(g_hForwards[MATCH_RESET_ROUND], _);
	}
}

public ascension_falldamage(id, Float:flDmg) {
	return;
}

// ============================================
// 玩家进出
// ============================================
public ascension_player_join(id) {
	if (g_eMatchInfo[e_tLeaveData] != Invalid_Trie) {
		TrieGetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);
	}
	
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iNum = get_num_players_in_match(id);
		new bool:bReplaced = iNum >= g_eMatchInfo[e_mTeamSize] ? true : false;
		
		ExecuteForward(g_hForwards[MATCH_JOIN_PLAYER], _, id, bReplaced);
		
		if (bReplaced) {
			transferUserToSpec(id);
			return;
		}
		
		new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];
		if (iMatchRounds == g_ePlayerInfo[id][LEAVE_IN_ROUND])
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_TERRORIST : TEAM_CT);
		else
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_CT : TEAM_TERRORIST);
		
		if (g_eMatchState == STATE_PAUSED)
			rg_round_respawn(id);
	} else {
		transferUserToSpec(id);
	}
}

public ascension_player_leave(id) {
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];
		g_ePlayerInfo[id][LEAVE_IN_ROUND] = iMatchRounds;
	}
	ExecuteForward(g_hForwards[MATCH_LEAVE_PLAYER], _, id);
	TrieSetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);
	arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}

// ============================================
// 比赛结束
// ============================================
stock ascensionFinished(iWinTeam) {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);
	
	new szWinner[16];
	format(szWinner, charsmax(szWinner), iWinTeam == 1 ? "Team A" : "Team B");
	
	setTaskHud(0, 0.5, 1, 255, 255, 255, 5.0, "[Ascension] %s 获胜! A: %.1f | B: %.1f", 
		szWinner, g_flScoreA, g_flScoreB);
	
	match_reset_data();
	training_start();
	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);
}

// ============================================
// 绘制区域框
// ============================================
stock draw_zone_boxes() {
	server_print("[Ascension] draw_zone_boxes: count=%d iBeam=%d g_sprBeam=%d", g_iZoneCount, iBeam, g_sprBeam);
	for (new i = 0; i < g_iZoneCount; i++) {
		if (!g_eZones[i][ZONE_ENABLED]) continue;
		
		new Float:fMins[3], Float:fMaxs[3];
		for (new k = 0; k < 3; k++) {
			fMins[k] = g_eZones[i][ZONE_MINS][k];
			fMaxs[k] = g_eZones[i][ZONE_MAXS][k];
		}
		
		new r, g, b;
		if (g_eZones[i][ZONE_CAPTURED]) {
			r = 255; g = 215; b = 0;   // ★ 金色 = 已占领
		} else if (g_eZones[i][ZONE_STATUS] >= 1) {
			r = 0; g = 255; b = 0;     // 绿色 = 有人在
		} else {
			r = 255; g = 50; b = 50;   // 红色 = 空
		}
		
		// 底面
		draw_beam_line(fMins[0], fMins[1], fMins[2], fMaxs[0], fMins[1], fMins[2], r, g, b);
		draw_beam_line(fMaxs[0], fMins[1], fMins[2], fMaxs[0], fMaxs[1], fMins[2], r, g, b);
		draw_beam_line(fMaxs[0], fMaxs[1], fMins[2], fMins[0], fMaxs[1], fMins[2], r, g, b);
		draw_beam_line(fMins[0], fMaxs[1], fMins[2], fMins[0], fMins[1], fMins[2], r, g, b);
		// 顶面
		draw_beam_line(fMins[0], fMins[1], fMaxs[2], fMaxs[0], fMins[1], fMaxs[2], r, g, b);
		draw_beam_line(fMaxs[0], fMins[1], fMaxs[2], fMaxs[0], fMaxs[1], fMaxs[2], r, g, b);
		draw_beam_line(fMaxs[0], fMaxs[1], fMaxs[2], fMins[0], fMaxs[1], fMaxs[2], r, g, b);
		draw_beam_line(fMins[0], fMaxs[1], fMaxs[2], fMins[0], fMins[1], fMaxs[2], r, g, b);
		// 竖直
		draw_beam_line(fMins[0], fMins[1], fMins[2], fMins[0], fMins[1], fMaxs[2], r, g, b);
		draw_beam_line(fMaxs[0], fMins[1], fMins[2], fMaxs[0], fMins[1], fMaxs[2], r, g, b);
		draw_beam_line(fMaxs[0], fMaxs[1], fMins[2], fMaxs[0], fMaxs[1], fMaxs[2], r, g, b);
		draw_beam_line(fMins[0], fMaxs[1], fMins[2], fMins[0], fMaxs[1], fMaxs[2], r, g, b);
	}
}

stock draw_beam_line(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, r, g, b) {
	new iSprite = (iBeam > 0) ? iBeam : g_sprBeam;
	if (iSprite <= 0) {
		server_print("[Ascension] Cannot draw zone line: no beam sprite available");
		return;
	}

	message_begin(MSG_ALL, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	write_coord(floatround(x1));
	write_coord(floatround(y1));
	write_coord(floatround(z1));
	write_coord(floatround(x2));
	write_coord(floatround(y2));
	write_coord(floatround(z2));
	write_short(iSprite);
	write_byte(1);    // framestart
	write_byte(10);   // framerate
	write_byte(30);   // ★ life in 0.1s = 3.0秒（不闪烁）
	write_byte(5);    // width
	write_byte(0);    // noise
	write_byte(r);    // r
	write_byte(g);    // g
	write_byte(b);    // b
	write_byte(255);  // brightness
	write_byte(0);    // speed
	message_end();
}

// ============================================
// 清理所有任务
// ============================================
stock remove_all_tasks() {
	if (task_exists(TASK_POINTSCAP_DETECT)) remove_task(TASK_POINTSCAP_DETECT);
	if (task_exists(TASK_POINTSCAP_KNIFE)) remove_task(TASK_POINTSCAP_KNIFE);
	if (task_exists(TASK_POINTSCAP_HUD)) remove_task(TASK_POINTSCAP_HUD);
	if (task_exists(TASK_POINTSCAP_FALLBACK)) remove_task(TASK_POINTSCAP_FALLBACK);
	if (task_exists(TASK_POINTSCAP_FORCE)) remove_task(TASK_POINTSCAP_FORCE);
	if (task_exists(TASK_POINTSCAP_ROUNDTIMER)) remove_task(TASK_POINTSCAP_ROUNDTIMER);
}

// ============================================
// ★ 点位分数设置已移到主菜单 → 比赛设置 → 点位分数配置
// ============================================

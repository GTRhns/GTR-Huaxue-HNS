public mix_init() {
	g_ModFuncs[MODE_MIX][MODEFUNC_START]		= CreateOneForward(g_PluginId, "mix_start");
	g_ModFuncs[MODE_MIX][MODEFUNC_END]			= CreateOneForward(g_PluginId, "mix_stop");
	g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE]		= CreateOneForward(g_PluginId, "mix_pause");
	g_ModFuncs[MODE_MIX][MODEFUNC_UNPAUSE]		= CreateOneForward(g_PluginId, "mix_unpause");
	g_ModFuncs[MODE_MIX][MODEFUNC_ROUNDSTART]	= CreateOneForward(g_PluginId, "mix_roundstart");
	g_ModFuncs[MODE_MIX][MODEFUNC_ROUNDEND]		= CreateOneForward(g_PluginId, "mix_roundend", FP_CELL);
	g_ModFuncs[MODE_MIX][MODEFUNC_FREEZEEND]	= CreateOneForward(g_PluginId, "mix_freezeend");
	g_ModFuncs[MODE_MIX][MODEFUNC_RESTARTROUND]	= CreateOneForward(g_PluginId, "mix_restartround");
	g_ModFuncs[MODE_MIX][MODEFUNC_SWAP]			= CreateOneForward(g_PluginId, "mix_swap");
	g_ModFuncs[MODE_MIX][MODEFUNC_PLAYER_JOIN]	= CreateOneForward(g_PluginId, "mix_player_join", FP_CELL);
	g_ModFuncs[MODE_MIX][MODEFUNC_PLAYER_LEAVE]	= CreateOneForward(g_PluginId, "mix_player_leave", FP_CELL);
	g_ModFuncs[MODE_MIX][MODEFUNC_KILL]			= CreateOneForward(g_PluginId, "mix_killed", FP_CELL, FP_CELL);
	g_ModFuncs[MODE_MIX][MODEFUNC_FALLDAMAGE]	= CreateOneForward(g_PluginId, "mix_falldamage", FP_CELL, FP_FLOAT);
}

public mix_start() {
	new bool:bKeepExternalSize = g_bExternalTeamSize;
	new iKeepTeamSize = g_eMatchInfo[e_mTeamSize];
	new iKeepTeamSizeTT = g_eMatchInfo[e_mTeamSizeTT];
	new NATCH_RULES:iKeepRules = g_iCurrentRules;

	match_reset_data();
	g_iCurrentRules = iKeepRules;

	if (bKeepExternalSize) {
		g_bExternalTeamSize = true;
		g_eMatchInfo[e_mTeamSize] = iKeepTeamSize;
		g_eMatchInfo[e_mTeamSizeTT] = iKeepTeamSizeTT;
	}

	ChangeGameplay(GAMEPLAY_HNS);

	// ★ 强制清除残留无敌: 确保训练/缓冲期遗留的 godmode 不会带入比赛
	//   (hns_enable_rules 只清活着玩家, 这里对所有在线玩家再清一遍)
	new iAllPlayers[MAX_PLAYERS], iAllNum;
	get_players(iAllPlayers, iAllNum, "ch");
	for (new i; i < iAllNum; i++) {
		setUserGodmode(iAllPlayers[i], false);
	}

	// 手动开赛 / AI 开赛: 先把当前 T/CT 标成参赛者,
	// 再把未参赛的人转入观战, 避免全员被踢到 spec
	markPlayingPlayersForMatch();
	forceUnmatchedToSpec();

	g_iCurrentMode = MODE_MIX;
	update_hostname_prefix("MIX");
	g_iMatchStatus = MATCH_STARTED;
	g_eMatchState = STATE_PREPARE;

	// Record match start for deserter penalty
	deserter_match_start();

	g_isTeamTT = HNS_TEAM_A;

	g_eSurrenderData[e_sFlDelay] = get_gametime() + g_iSettings[SURTIMEDELAY];

	set_cvars_mode(MODE_MIX);

	// Force spectator settings during match
	set_cvar_num("mp_forcecamera", 2);  // Lock to first person
	set_cvar_num("mp_limitteams", 0);    // No team balance

	loadMapCFG();

	if (g_iCurrentRules == RULES_DUEL) {
		duel_start();
		hns_restart_round(2.0);
		play_match_start_sound();
		setTaskHud(0, 0.0, 1, 255, 255, 255, 3.0, "比赛即将开始!");
		setTaskHud(0, 3.1, 1, 255, 255, 255, 3.0, "比赛开始!^n祝你好运, 玩得开心!");
	}
	else if (g_iCurrentRules == RULES_POINTSCAP) {
		ascension_start(); // ascension_start 内部已调用 hns_restart_round
		play_match_start_sound();
		setTaskHud(0, 0.0, 1, 255, 255, 255, 3.0, "比赛即将开始!");
		setTaskHud(0, 3.1, 1, 255, 255, 255, 3.0, "比赛开始!^n祝你好运, 玩得开心!");
	}
	else if (g_iCurrentRules == RULES_VAMP) {
		vamp_start();
		hns_restart_round(2.0);
		play_match_start_sound();
		setTaskHud(0, 0.0, 1, 255, 255, 255, 3.0, "比赛即将开始!");
		setTaskHud(0, 3.1, 1, 255, 255, 255, 3.0, "比赛开始!^n祝你好运, 玩得开心!");
	}
	else {
		// ★ 普通比赛: 进入开场加载流程
		//   C4进度条7秒 → 音效+类型HUD → 刷新4次(每5秒) → 缓冲15秒倒计时 → 激活
		begin_match_loading();
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", "TERRORIST");
	if (g_bExternalTeamSize) {
		if (g_eMatchInfo[e_mTeamSize] < 1)
			g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
		if (g_eMatchInfo[e_mTeamSizeTT] < 1)
			g_eMatchInfo[e_mTeamSizeTT] = iNum;
	} else {
		g_eMatchInfo[e_mTeamSizeTT] = iNum;
		g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
	}

	ExecuteForward(g_hForwards[MATCH_START], _);
}

// ============================================================
//  比赛开场加载流程
// ============================================================
//  C4进度条7秒 → 比赛类型音效+HUD → 刷新4次(每5秒) → 缓冲15秒倒计时 → 激活
//  进度条期间不重启回合, 否则 BarTime 会被清掉
//  开场 HUD 全部走 show_match_stage_hud, 同一通道排队, 不叠字
stock begin_match_loading() {
	remove_task(TASK_LOADING_BAR);
	remove_task(TASK_LOADING_DONE);
	remove_task(TASK_REFRESH_WAVE);
	remove_task(TASK_MATCH_ACTIVATE);
	remove_task(TASK_MATCH_HUD);

	g_bMatchLoading = true;
	g_bMatchBufferDone = false;
	g_iLoadingStep = 0;
	g_iRefreshWave = 0;
	g_iMatchCountdown = 0;

	// 聊天框提示: 当前比赛 XX局 XX模式 (局=绿色, 模式=队伍色)
	new szMatchType[16], szRules[16];
	switch (g_eMatchType) {
		case MATCH_TYPE_SPONSOR:	copy(szMatchType, charsmax(szMatchType), "赞助");
		case MATCH_TYPE_CASUAL:		copy(szMatchType, charsmax(szMatchType), "娱乐");
		case MATCH_TYPE_RANKED:		copy(szMatchType, charsmax(szMatchType), "个人");
		default:					copy(szMatchType, charsmax(szMatchType), "未知");
	}
	switch (g_iCurrentRules) {
		case RULES_MR:		copy(szRules, charsmax(szRules), "MR");
		case RULES_TIMER:	copy(szRules, charsmax(szRules), "Wintime");
		case RULES_DUEL:	copy(szRules, charsmax(szRules), "Duel");
		case RULES_ROUNDS:	copy(szRules, charsmax(szRules), "回合制");
		default:			copy(szRules, charsmax(szRules), "回合制");
	}
	chat_print(0, "当前比赛: ^3%s局^1 ^2%s^1", szMatchType, szRules);

	// C4下包进度条: 底部引擎 BarTime, 走满后再刷新回合
	show_engine_loading_bar(floatround(LOADING_BAR_TIME));

	// 进度条逐格推进 (上方 DHUD 文字 + 百分比)
	draw_match_loading_bar(0, LOADING_STEPS);
	set_task(0.1, "taskLoadingBar", TASK_LOADING_BAR, .flags = "b");
	set_task(LOADING_BAR_TIME, "taskLoadingDone", TASK_LOADING_DONE);
}

public taskLoadingBar() {
	g_iLoadingStep++;
	if (g_iLoadingStep >= LOADING_STEPS) {
		remove_task(TASK_LOADING_BAR);
		return;
	}
	draw_match_loading_bar(g_iLoadingStep, LOADING_STEPS);
}

public taskLoadingDone() {
	show_engine_loading_bar(0);
	play_match_start_sound();
	show_match_type_hud();

	// 类型 HUD 先显示完, 再开始刷新回合, 避免叠字
	g_iRefreshWave = 0;
	set_task(4.5, "taskStartRefreshWaves", TASK_REFRESH_WAVE);
}

public taskStartRefreshWaves() {
	taskRefreshWave();
	set_task(REFRESH_WAVE_INTERVAL, "taskRefreshWave", TASK_REFRESH_WAVE, .flags = "b");
}

stock show_match_stage_hud(Red, Green, Blue, Float:HoldTime, const Text[], any:...) {
	new szMessage[128];
	vformat(szMessage, charsmax(szMessage), Text, 6);
	set_dhudmessage(Red, Green, Blue, -1.0, 0.16, 0, 0.0, HoldTime, 0.0, 0.1);
	show_dhudmessage(0, szMessage);
}

stock show_match_type_hud() {
	switch (g_eMatchType) {
		case MATCH_TYPE_SPONSOR: {
			show_match_stage_hud(255, 200, 0, 4.0,
				"赞助局 比赛即将开始!^n赞助者: %s | GBIC: %d",
				g_szSponsorName[0] ? g_szSponsorName : "未填写", g_iSponsorGC);
		}
		case MATCH_TYPE_CASUAL: {
			show_match_stage_hud(255, 40, 40, 4.0, "娱乐局 比赛即将开始!");
		}
		case MATCH_TYPE_RANKED: {
			show_match_stage_hud(40, 255, 40, 4.0, "个人局 比赛即将开始!");
		}
		default: {
			show_match_stage_hud(255, 255, 255, 4.0, "比赛即将开始!");
		}
	}
}

public taskRefreshWave() {
	do_refresh_wave();

	if (g_iRefreshWave >= REFRESH_WAVES) {
		remove_task(TASK_REFRESH_WAVE);
		g_iMatchCountdown = floatround(MATCH_ACTIVATE_DELAY);
		set_task(2.5, "taskMatchCountdown", TASK_MATCH_HUD);
		set_task(2.5 + MATCH_ACTIVATE_DELAY, "taskMatchActivate", TASK_MATCH_ACTIVATE);
	}
}

stock do_refresh_wave() {
	g_iRefreshWave++;
	hns_restart_round(2.0);
	setTaskHud(0, 0.3, 1, 255, 200, 0, 2.0, "刷新回合 %d / %d", g_iRefreshWave, REFRESH_WAVES);
}

public taskMatchCountdown() {
	if (!g_bMatchLoading)
		return;

	if (g_iMatchCountdown > 0) {
		show_match_stage_hud(0, 255, 0, 1.05, "比赛将在 %d 秒后开始!", g_iMatchCountdown);
		g_iMatchCountdown--;
		set_task(1.0, "taskMatchCountdown", TASK_MATCH_HUD);
	}
}

public taskMatchActivate() {
	remove_task(TASK_MATCH_HUD);
	g_bMatchLoading = false;
	g_bMatchBufferDone = true;
	g_eMatchState = STATE_ENABLED;

	hns_restart_round(2.0);
	client_cmd(0, "spk absolutely");
	setTaskHud(0, 0.3, 1, 0, 255, 0, 4.0, "比赛开始!^n祝你好运, 玩得开心!");
}


public mix_freezeend() {
	if (g_eMatchState != STATE_ENABLED) {
		return PLUGIN_HANDLED;
	}

	if (g_bHnsBannedInit) {
		if (checkUserBan()) {
			return PLUGIN_HANDLED;
		}
	}

	if (g_iCurrentRules == RULES_DUEL) {
		duel_freezeend();
	} else {
		set_task(0.25, "taskRoundEvent", .id = TASK_TIMER, .flags = "b");
	}

	if(g_eMatchInfo[e_mLeaved]) {
		set_task(1.0, "mix_pause");
	}

	return PLUGIN_HANDLED;
}

public mix_restartround() {
	if (g_eMatchState == STATE_ENABLED) {
		mix_reverttimer();
		g_eMatchState = STATE_PREPARE;
	}

	if (g_iCurrentRules == RULES_DUEL) {
		duel_restartround();
	}

	ResetAfkData();
}


public mix_pause() {
	if (g_eMatchState == STATE_PAUSED) {
		return;
	}

	mix_reverttimer();

	g_eMatchState = STATE_PAUSED;

	if (g_iCurrentRules == RULES_DUEL) {
		duel_pause();
	}

	ChangeGameplay(GAMEPLAY_TRAINING);

	set_pause_settings();
}

public mix_unpause() {
	if (g_eMatchState != STATE_PAUSED) {
		return;
	}

	g_eMatchState = STATE_PREPARE;

	hns_restart_round(1.0);

	if (!g_bExternalTeamSize)
		g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();

	ChangeGameplay(GAMEPLAY_HNS);

	set_unpause_settings();
}


public mix_swap() {
	g_isTeamTT = HNS_TEAM:!g_isTeamTT;

	if (g_iCurrentRules == RULES_DUEL) {
		duel_swap();
	}

	ResetAfkData();
}


public mix_stop() {
	ExecuteForward(g_hForwards[MATCH_CANCEL], _);

	if (g_iCurrentRules == RULES_POINTSCAP) {
		ascension_stop();
	}
	else if (g_iCurrentRules == RULES_VAMP) {
		vamp_stop();
	}

	// 停止开场加载流程
	cancel_match_loading();

	// Restore spectator settings
	set_cvar_num("mp_forcecamera", 0);

	match_reset_data();

	// ★ 比赛结束: 仅清除临时赞助标记, 保留持久化标记 (赞助局下一把仍生效)
	g_bSponsorMatch = g_bPersistentSponsor;
	g_iSponsorPlayer = 0;

	update_hostname_prefix("");
	training_start(); // 管理员关闭比赛: 一次回到练习模式, 不再先经过大厅
}

// 取消开场加载流程 (进度条/回合刷新/缓冲期全部停止)
stock cancel_match_loading() {
	g_bMatchLoading = false;
	g_bMatchBufferDone = false;
	g_iMatchCountdown = 0;

	remove_task(TASK_LOADING_BAR);
	remove_task(TASK_LOADING_DONE);
	remove_task(TASK_REFRESH_WAVE);
	remove_task(TASK_MATCH_ACTIVATE);
	remove_task(TASK_MATCH_HUD);
}


public mix_roundstart() {
	if (g_bMatchLoading) {
		// 开场加载流程中的回合刷新: 只做基础重置, 不激活比赛逻辑
		ResetAfkData();
		return;
	}

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	if (g_eMatchState == STATE_PREPARE) {
		g_eMatchState = STATE_ENABLED;
	}

	if (g_iCurrentRules == RULES_DUEL) {
		duel_roundstart();
		return;
	}

	g_flRoundTime = 0.0;

	cmdShowTimers(0);

	ResetAfkData();

	if (g_bHnsBannedInit) {
		checkUserBan();
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (!is_user_connected(id)) {
			continue;
		}

		if (getUserTeam(id) == TEAM_TERRORIST || getUserTeam(id) == TEAM_CT) {
			if (!g_ePlayerInfo[id][PLAYER_MATCH]) {
				transferUserToSpec(id);
				continue;
			}
			copy(g_ePlayerInfo[id][PLAYER_TEAM], charsmax(g_ePlayerInfo[][PLAYER_TEAM]), getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT");
		} else {
			g_ePlayerInfo[id][PLAYER_MATCH] = false;
		}
	}

	taskCheckLeave();

	if (!g_bExternalTeamSize) {
		get_players(iPlayers, iNum, "che", "TERRORIST");
		g_eMatchInfo[e_mTeamSizeTT] = iNum;
	}

	set_task(0.3, "taskSaveAfk");

}

public taskCheckLeave() {
	if (g_iCurrentMode != MODE_MIX) {
		return;
	}

	new iNum = get_num_players_in_match();

	if (iNum < g_eMatchInfo[e_mTeamSize]) {
		// Pause Need Players
		g_eMatchInfo[e_mLeaved] = true;
		chat_print(0, "比赛已暂停，还需要 ^3%d^1 名玩家。", g_eMatchInfo[e_mTeamSize] - iNum)
	} else {
		iNum = iNum - g_eMatchInfo[e_mTeamSize];
		if (iNum >= 2 && !g_bExternalTeamSize) {
			g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
		}

		if (g_eMatchInfo[e_tLeaveData] != Invalid_Trie) {
			new iPlayers[MAX_PLAYERS], iCount;
			get_players(iPlayers, iCount, "ch");
			for (new i; i < iCount; i++) {
				TrieDeleteKey(g_eMatchInfo[e_tLeaveData], getUserKey(iPlayers[i]));
			}
		}

		g_eMatchInfo[e_mLeaved] = false;
	}
}

public MixFinishedMR(iWinTeam) {
	award_match_gbic(iWinTeam);
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);

	// Clear deserter active flags (match ended normally)
	deserter_clear_on_match_end();
	matchControl_reset();

	new Float:TimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	new szTime[24];
	fnConvertTime(TimeDiff, szTime, charsmax(szTime));
	chat_print(0, "%s 赢得了比赛! (^3%s^1 差距)", iWinTeam == 1 ? "TT" : "CT", szTime);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "比赛结束");
	
	match_reset_data();
	
	update_hostname_prefix("");
	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);
}

public MixFinishedWT() {
	award_match_gbic(1);
	ExecuteForward(g_hForwards[MATCH_FINISH], _, 1);

	// Clear deserter active flags (match ended normally)
	deserter_clear_on_match_end();
	matchControl_reset();

	new Float:TimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	
	new szTime[24];
	fnConvertTime(TimeDiff, szTime, charsmax(szTime), false);
	
	chat_print(0, "TT 赢得了比赛! (^3%s^1 差距)", szTime);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "比赛结束");

	match_reset_data(true);

	update_hostname_prefix("");
	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, 1);
}

public MixFinishedRounds(iWinTeam) {
	award_match_gbic(iWinTeam);
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);

	deserter_clear_on_match_end();
	matchControl_reset();

	new iA = g_iRoundsScore[HNS_TEAM_A];
	new iB = g_iRoundsScore[HNS_TEAM_B];
	new iCtScore, iTtScore;
	getRoundsScore(iCtScore, iTtScore);

	chat_print(0, "%s 赢得回合制比赛! 最终比分 A队 ^3%d^1 - ^3%d^1 B队 | 当前[CT] ^3%d^1 : [TT] ^3%d^1",
		iWinTeam == 1 ? "A队" : "B队", iA, iB, iCtScore, iTtScore);
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "回合制比赛结束^n%s 获胜", iWinTeam == 1 ? "A队" : "B队");

	match_reset_data(true);

	update_hostname_prefix("");
	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);
}

public mix_roundend(bool:win_ct) {
	if (g_eMatchState != STATE_ENABLED) {
		return;
	}
	if (g_iCurrentRules == RULES_DUEL) {
		duel_roundend();
		return;
	}

	g_eMatchState = STATE_PREPARE;

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	if (g_iCurrentRules == RULES_MR) {
		if (win_ct) {
			g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT]++;
		} else {
			g_eMatchInfo[e_iSidesRounds][g_isTeamTT]++;
		}

		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ache", "CT");

		if (!iNum) {
			new Float:roundtime = get_round_time() * 60.0;
			g_eMatchInfo[e_flSidesTime][g_isTeamTT] += roundtime - g_flRoundTime;
		}

		if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= g_iSettings[MAXROUNDS] * 2) {
			new HNS_TEAM:win_team = HNS_TEAM:-1;
			if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]) {
				win_team = g_isTeamTT;
			} else if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] < g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]) {
				win_team = HNS_TEAM:!g_isTeamTT;
			}

			if (win_team != HNS_TEAM:-1)
				MixFinishedMR(win_team == g_isTeamTT ? 1 : 2);
			else {
				hns_swap_teams();
				chat_print(0, "双方时间相同! 加时赛! 再打 +2 回合。");
				g_iSettings[MAXROUNDS] += 2;
			}
		} else {
			hns_swap_teams();
			if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= (g_iSettings[MAXROUNDS] * 2) - 1) {
				new sTime[24];
				if (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - (get_round_time() * 60.0) > g_eMatchInfo[e_flSidesTime][g_isTeamTT]) {
					// variant kogda tt josko proebivaut (bolwe 4em roundtime)
					fnConvertTime(g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - g_eMatchInfo[e_flSidesTime][g_isTeamTT], sTime, charsmax(sTime));
					setTaskHud(0, 3.0, 1, 255, 255, 255, 5.0, "CT 获胜! ^n TT 没有足够 %s 的时间获胜! ^n(超过回合时间)", sTime);
				} else if (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] > g_eMatchInfo[e_flSidesTime][g_isTeamTT]) {
					// samii default variant
					fnConvertTime(g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - g_eMatchInfo[e_flSidesTime][g_isTeamTT], sTime, charsmax(sTime));
					new szHud[128];
					formatex(szHud, charsmax(szHud), "最后一回合!^n TT 还需要 %s 时间才能获胜!", sTime);
					setTaskHud(0, 3.0, 1, 255, 255, 255, 5.0, szHud);
				} else {
					setTaskHud(0, 3.0, 1, 255, 255, 255, 5.0, "TT 获胜! ^n TT 的时间比对手更短!");
				}
			}
		}
	} else if (g_iCurrentRules == RULES_TIMER) {
		g_eMatchInfo[e_iSidesRounds][g_isTeamTT]++

		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ache", "CT");

		if (!iNum) {
			new Float:roundtime = get_round_time() * 60.0;
			g_eMatchInfo[e_flSidesTime][g_isTeamTT] += roundtime - g_flRoundTime;

			if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] <= 0.0) {
				g_eMatchInfo[e_flSidesTime][g_isTeamTT] = 0.0;
			}
		}

		if (win_ct) {
			hns_swap_teams();
		}
	} else if (g_iCurrentRules == RULES_ROUNDS) {
		new HNS_TEAM:winTeam;
		if (win_ct) {
			winTeam = HNS_TEAM:!g_isTeamTT;
		} else {
			winTeam = g_isTeamTT;
		}

		g_iRoundsScore[winTeam]++;
		g_iRoundsPlayed++;

		new szWinnerName[16];
		copy(szWinnerName, charsmax(szWinnerName), winTeam == HNS_TEAM_A ? "A队" : "B队");

		// CT 赢换边, T 赢不换边
		if (win_ct) {
			hns_swap_teams();
		}

		if (g_iRoundsScore[winTeam] >= g_iSettings[MAXROUNDS]) {
			MixFinishedRounds(winTeam == HNS_TEAM_A ? 1 : 2);
			return;
		}

		new iCtScore, iTtScore;
		getRoundsScore(iCtScore, iTtScore);
		chat_print(0, "本回合 ^3%s^1 获胜 | 当前[CT] ^3%d^1 : [TT] ^3%d^1 | A队 %d : %d B队 (先到 %d 胜)",
			szWinnerName, iCtScore, iTtScore, g_iRoundsScore[HNS_TEAM_A], g_iRoundsScore[HNS_TEAM_B], g_iSettings[MAXROUNDS]);
		setTaskHud(0, 0.5, 1, 255, 255, 255, 4.0, "[回合制] %s 获胜!^n当前[CT] %d : [TT] %d^nA队 %d - %d B队 (先到 %d 胜)",
			szWinnerName, iCtScore, iTtScore, g_iRoundsScore[HNS_TEAM_A], g_iRoundsScore[HNS_TEAM_B], g_iSettings[MAXROUNDS]);
	}
}


public taskRoundEvent() {
	if (g_eMatchState != STATE_ENABLED) {
		if(task_exists(TASK_TIMER)) {
			remove_task(TASK_TIMER);
		}
		return;
	}

	g_flRoundTime += 0.25;
	g_eMatchInfo[e_flSidesTime][g_isTeamTT] += 0.25;

	if (g_flRoundTime / 60.0 >= get_round_time()) {
		remove_task(TASK_TIMER);
	}

	if (g_iCurrentRules == RULES_MR) {
        if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= (g_iSettings[MAXROUNDS] * 2) - 1) {
            if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] || g_eMatchInfo[e_flSidesTime][g_isTeamTT] < (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - get_round_time() * 60.0)) {
                new HNS_TEAM:iWinTeam = g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] ? g_isTeamTT : HNS_TEAM:!g_isTeamTT;
                MixFinishedMR(iWinTeam == g_isTeamTT ? 1 : 2);
            }
        }
    } else if (g_iCurrentRules == RULES_TIMER) {
        new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
        if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] >= flCapTime) {
            MixFinishedWT()
        }
    }
}

public mix_killed(victim, killer) {
	if (g_iCurrentRules != RULES_DUEL || g_eMatchState != STATE_ENABLED) {
		return;
	}

	duel_killed(victim, killer);
}

public mix_falldamage(id, Float:flDmg) {
	if (g_iCurrentRules != RULES_DUEL || g_eMatchState != STATE_ENABLED) {
		return;
	}

	duel_falldamage(id, flDmg);
}

stock points_calc_distance_value(iDistance, iDist1, iDist2, iDist3) {
	if (iDist1 <= 0 || iDist2 <= iDist1 || iDist3 <= iDist2) {
		return 0;
	}

	if (iDistance <= iDist1) {
		return floatround(float(iDistance) / float(iDist1) * 3.0, floatround_floor);
	}

	if (iDistance <= iDist2) {
		return 3 + floatround(float(iDistance - iDist1) / float(iDist2 - iDist1) * 4.0, floatround_floor);
	}

	if (iDistance <= iDist3) {
		return 7 + floatround(float(iDistance - iDist2) / float(iDist3 - iDist2) * 3.0, floatround_floor);
	}

	return 10;
}

public mix_reverttimer() {
	if (g_eMatchState != STATE_ENABLED) {
		return;
	}

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	duel_reverttimer();

	g_eMatchInfo[e_flSidesTime][g_isTeamTT] -= g_flRoundTime;

	ExecuteForward(g_hForwards[MATCH_RESET_ROUND], _);
}

public mix_player_join(id) {
	if (!is_user_connected(id))
		return;

	g_ePlayerInfo[id][PLAYER_MATCH] = false;
	g_ePlayerInfo[id][PLAYER_TEAM][0] = EOS;
	g_ePlayerInfo[id][LEAVE_IN_ROUND] = 0;

	if (deserter_is_banned(id)) {
		new iRemaining = deserter_get_ban_remaining(id);
		new szTime[32];
		if (iRemaining >= 3600) {
			formatex(szTime, charsmax(szTime), "%dh %dmin", iRemaining / 3600, (iRemaining % 3600) / 60);
		} else {
			formatex(szTime, charsmax(szTime), "%dmin", iRemaining / 60);
		}
		chat_print(id, "[^3HNS^1] 你被禁止参加比赛 %s (%d 次逃跑)。", szTime, g_iDesertCount[id]);
		transferUserToSpec(id);
		return;
	}

	if (g_eMatchInfo[e_tLeaveData] != Invalid_Trie)
		TrieGetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iNum = get_num_players_in_match(id);
		new bool:bReplaced = iNum >= g_eMatchInfo[e_mTeamSize];

		if (g_bDebugMode) server_print("[MATCH] mix_player_join | %n replaced=%d size=%d onfield=%d", id, bReplaced, g_eMatchInfo[e_mTeamSize], iNum)

		ExecuteForward(g_hForwards[MATCH_JOIN_PLAYER], _, id, bReplaced);

		if (bReplaced) {
			transferUserToSpec(id);
			return;
		}

		new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];

		if (iMatchRounds == g_ePlayerInfo[id][LEAVE_IN_ROUND]) {
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_TERRORIST : TEAM_CT);
		} else {
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_CT : TEAM_TERRORIST);
		}

		if (g_eMatchState == STATE_PAUSED)
			rg_round_respawn(id);
		return;
	}

	// 中途进服 / 未报名: 只能观战, 不能补进强制开赛的队伍
	transferUserToSpec(id);
}

public mix_player_leave(id) {
	if (g_bDebugMode) server_print("[MATCH] mix_player_leave START | %n", id)
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];

		if (g_bDebugMode) {
			server_print("[MATCH] mix_player_leave PLAYER_MATCH | %n %d", id, iMatchRounds)
		}

		g_ePlayerInfo[id][LEAVE_IN_ROUND] = iMatchRounds;

		// Apply deserter penalty
		deserter_apply_penalty(id);
		deserter_save(id);

		if (g_iCurrentRules == RULES_DUEL) {
			if (g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE])
				ExecuteForward(g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE], _);
		}
	}
	
	ExecuteForward(g_hForwards[MATCH_LEAVE_PLAYER], _, id);

	TrieSetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}

/* 赞助局结束: 把本场 GBIC 奖金加到胜方每位参赛者的皮肤金币账户
 * 娱乐局不加。投降也会走 MixFinishedMR, 用 g_bGbicAwarded 防重复发。 */
stock award_match_gbic(iWinTeam) {
	if (g_bGbicAwarded)
		return;
	g_bGbicAwarded = true;

	if (g_eMatchType != MATCH_TYPE_SPONSOR)
		return;
	if (g_iSponsorGC < 1)
		return;
	if (iWinTeam != 1 && iWinTeam != 2)
		return;

	new PLAYER_ROLES:winRole = iWinTeam == 1 ? ROLE_TEAM_A : ROLE_TEAM_B;
	new PLAYER_ROLES:winCapRole = iWinTeam == 1 ? ROLE_CAP_A : ROLE_CAP_B;
	new iAward = g_iSponsorGC;
	new iGiven;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (!is_user_connected(id))
			continue;
		if (!g_ePlayerInfo[id][PLAYER_MATCH])
			continue;
		if (g_ePlayerInfo[id][PLAYER_ROLE] != winRole && g_ePlayerInfo[id][PLAYER_ROLE] != winCapRole)
			continue;

		new iNew = hns_gc_add_player(id, iAward);
		iGiven++;
		chat_print(id, "[^3HNS^1] 赞助局胜利, 获得 ^3%d^1 GBIC (余额 ^3%d^1)", iAward, iNew);
	}

	if (iGiven)
		chat_print(0, "[^3HNS^1] 胜方每人获得 ^3%d^1 GBIC, 已同步到 /skin", iAward);
}

// bMatchFinish
stock match_reset_data(bool:bMatchFinish = false) {
	g_iMatchStatus = MATCH_NONE;
	g_eMatchState = STATE_DISABLED;

	// 关闭/结束比赛后只复位本次会话内的 g_iCurrentRules, 不清除持久化的 AI 赛制。
	// 之前这里会 PDS_SetCell("ai_match_rules", RULES_MR) 把 AI 报名记住的模式抹掉,
	// 导致换图/打完一把后 AI 报名又退回 MR —— 这是 AI 赛制记不住的根因。
	g_iCurrentRules = RULES_MR;

	cancel_match_loading();

	g_eMatchInfo[e_mTeamSize] = 0;
	g_eMatchInfo[e_mTeamSizeTT] = 0;
	g_bExternalTeamSize = false;
	g_eMatchInfo[e_flSidesTime][HNS_TEAM_B] = 0;
	g_eMatchInfo[e_flSidesTime][HNS_TEAM_A] = 0;
	g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B] = 0;
	g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] = 0;
	g_iRoundsScore[HNS_TEAM_A] = 0;
	g_iRoundsScore[HNS_TEAM_B] = 0;
	g_iRoundsPlayed = 0;
	g_eMatchInfo[e_mLeaved] = false;
	g_bGbicAwarded = false;

	// TIMER 上限必须用 hns_wintime 分钟数。e_mWintime 以前没标 Float，
	// 一直是 0，开赛后 0.25s 就会 MixFinishedWT。
	g_eMatchInfo[e_mWintime] = g_iSettings[WINTIME] > 0.0 ? g_iSettings[WINTIME] : 15.0;
	cvar_update_wintime(g_eMatchInfo[e_mWintime]);

	if (g_iSettings[MAXROUNDS] <= 0)
		g_iSettings[MAXROUNDS] = 6;

	if(g_eMatchInfo[e_tLeaveData] != Invalid_Trie) {
		TrieClear(g_eMatchInfo[e_tLeaveData]);
	}

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	if(task_exists(HUD_PAUSE)) {
		remove_task(HUD_PAUSE);
	}

	if (bMatchFinish) {
		save_reset_data();
	}

	// 比赛结束后15秒保护期，禁止 /stop 切换 training→pub
	g_flTrainingProtect = get_gametime() + 15.0;
}

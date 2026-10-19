new Float:flWaitPlayersTime;

public mode_init() {
	set_task(30.0, "Task_CheckTime", 120, .flags = "b");

	set_task(0.5, "delayed_mode");
}

public delayed_mode() {
	PDS_GetCell("match_mode", g_iCurrentMode);
	PDS_GetCell("match_gameplay", g_iCurrentGameplay);
	PDS_GetCell("match_status", g_iMatchStatus);

	// ★ 换图后赛制的权威来源是 match_rules (由管理员 /mr /timer 等直接改
	//   g_iCurrentRules, PDS_Save 时写入)。ai_match_rules 只是 AI 报名的辅助记录,
	//   只有在 match_rules 从未写过时才用它兜底, 否则会覆盖管理员的切换。
	new bool:bHasSavedRules = bool:PDS_GetCell("match_rules", g_iCurrentRules);
	if (!bHasSavedRules || g_iCurrentRules < RULES_MR || g_iCurrentRules > RULES_ROUNDS) {
		new iAiRules;
		if (PDS_GetCell("ai_match_rules", iAiRules) && iAiRules >= 0 && iAiRules <= _:RULES_ROUNDS) {
			g_iCurrentRules = NATCH_RULES:iAiRules;
			bHasSavedRules = true;
		}
	}

	if (hns_is_knife_map()) {
		g_iMatchStatus = MATCH_NONE;
		training_start();
	} else if (g_iCurrentMode == MODE_DM) {
		g_iMatchStatus = MATCH_NONE;
		training_start();
	} else if (g_iMatchStatus == MATCH_MAPPICK || g_iMatchStatus == MATCH_WAITCONNECT) {
		g_iMatchStatus = MATCH_WAITCONNECT;
		training_start();
		if (g_aPlayersLoadData) {
			flWaitPlayersTime = 180.0;
			set_task(1.0, "wait_players", .id = TASK_WAIT, .flags = "b");
		}
	} else if (g_iCurrentGameplay == GAMEPLAY_HNS && g_iCurrentMode == MODE_PUB) {
		pub_start();
	} else if (g_iCurrentGameplay == GAMEPLAY_HNS && g_iCurrentMode == MODE_DM) {
		training_start();
	} else if (g_iCurrentMode == MODE_LOBBY) {
		// ★ 比赛前公共模式: 换图后保持大厅身份, 防止被误切成训练。
		//   赛制已在上方按 match_rules 恢复, 不再用 ai_match_rules 覆盖。
		lobby_start();
	} else {
		// ★ 只有当 match_rules / ai_match_rules 都没有可用值时, 才回退到默认。
		if (!bHasSavedRules) {
			if (!g_iSettings[RULES]) {
				g_iCurrentRules = RULES_MR;
			} else {
				g_iCurrentRules = RULES_TIMER;
			}
		}
		g_iMatchStatus = MATCH_NONE;
		training_start();
	}
}

public wait_players() {
	if (g_iMatchStatus == MATCH_STARTED) {
		if(task_exists(TASK_WAIT)) {
			remove_task(TASK_WAIT);
		}
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_STARTED)) {
		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_START_LAST");
	} else {
		new iNum = get_num_players_in_match();

		if (iNum >= ArraySize(g_aPlayersLoadData)) {
			set_task(15.0, "mix_start", TASK_STARTED);
			return PLUGIN_HANDLED;
		}

		flWaitPlayersTime -= 1.0;

		new sTime[24];
		fnConvertTime(flWaitPlayersTime, sTime, charsmax(sTime));
		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_START_WAIT", sTime, ArraySize(g_aPlayersLoadData) - iNum);

		if (flWaitPlayersTime <= 0.0) {
			if(task_exists(TASK_WAIT)) {
				remove_task(TASK_WAIT);
			}
		}
	}

	return PLUGIN_HANDLED;
}

public Task_CheckTime() {
	if(g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	if((g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM) && g_iCurrentGameplay == GAMEPLAY_HNS) {
		return PLUGIN_HANDLED;
	}

	new iPlayers[MAX_PLAYERS], iNum
	get_players(iPlayers, iNum, "ch");

	if (iNum == 0) {
		// if (equali(g_szMapName, g_iSettings[KNIFEMAP]))
		// {
		// 	server_cmd("changelevel boost_qube02");
		// }
		training_start();
	}
	
	return PLUGIN_CONTINUE;
}
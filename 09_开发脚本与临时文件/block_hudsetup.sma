public taskSignupHud() {
	if (g_eState == SIGNUP_CLOSE) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			set_hudmessage(0, 255, 0, 0.02, 0.28, 0, 0.0, 1.1, 0.0, 0.0, -1);
			show_hudmessage(iPlayers[i], "正在分配队伍, 请稍候...");
		}
		return;
	}

	if (g_eState == SIGNUP_SETUP) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			new id = iPlayers[i];
			set_hudmessage(0, 255, 0, 0.02, 0.28, 0, 0.0, 1.1, 0.0, 0.0, -1);
			if (isUserVipOrAdmin(id))
				show_hudmessage(id, "赛前设置: 聊天输入 /signup 打开模式/地图菜单");
			else if (g_bVoteActive)
				show_hudmessage(id, "正在投票: 聊天输入 /signup 打开投票菜单");
			else
				show_hudmessage(id, "管理员正在选择模式/地图, 请稍候");
		}
		return;
	}

	if (g_eState != SIGNUP_OPEN || g_iSignupCount <= 0)
		return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		new szLine[96];
		ai_lang(id, "AI_HUD_COUNT", szLine, charsmax(szLine));
		format(szLine, charsmax(szLine), szLine, g_iSignupCount, SIGNUP_MAX);
		set_hudmessage(0, 255, 0, 0.02, 0.28, 0, 0.0, 1.1, 0.0, 0.0, -1);
		show_hudmessage(id, "%s", szLine);
	}
}


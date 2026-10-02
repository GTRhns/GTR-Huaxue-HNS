public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;
	g_iSetupMenuTries = 0;

	ai_print(0, "分组完成, 先选择比赛模式, 再选择地图");
	ai_print(0, "如果没看到菜单, 聊天输入 /signup 重新打开");
	showGroups(0);

	remove_task(TASK_SETUP_MENU);
	set_task(0.8, "taskShowPostGroupMenus", TASK_SETUP_MENU);
}

public taskShowPostGroupMenus() {
	if (g_eState != SIGNUP_SETUP || !g_bPostGroupSetup)
		return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		closeGameMenu(iPlayers[i]);

	if (showSetupToAdmins()) {
		if (g_iSetupMenuTries == 0)
			ai_print(0, "管理员/VIP 优先选择比赛模式 (聊天输入 /signup 可重新打开)");
	} else if (g_bVoteActive) {
		for (new i = 0; i < iNum; i++)
			reopenActiveVoteMenu(iPlayers[i]);
	} else {
		startRulesVote(0, -1);
	}

	g_iSetupMenuTries++;
	if (g_iSetupMenuTries < 3)
		set_task(1.0, "taskShowPostGroupMenus", TASK_SETUP_MENU);
}

public beginMapSelect() {
	if (!g_bPostGroupSetup) {
		startMatch();
		return;
	}

	remove_task(TASK_SETUP_MENU);

	if (g_iSkillMapCount <= 0 && g_iBoostMapCount <= 0)
		loadMapPools();

	if (!isSkillOrTimerRules()) {
		setActivePool(POOL_BOOST);
		ai_print(0, "%s 使用 Boost 地图池, 请选择随机 / 投票 / 指定地图", g_szRules[_:g_iMatchRules]);
		offerMapChoice();
		return;
	}

	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		closeGameMenu(i);
		showPoolChoiceMenu(i);
		bShown = true;
	}
	if (bShown) {
		ai_print(0, "管理员/VIP 优先选择地图池 (Skill / Boost)");
		return;
	}

	startPoolVote();
}

stock offerMapChoice() {
	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		closeGameMenu(i);
		showMapChoiceMenu(i);
		bShown = true;
	}
	if (bShown)
		return;

	startMapVote();
}


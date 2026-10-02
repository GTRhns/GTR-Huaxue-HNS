public TypeMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id)) {
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	g_bSponsorMatch = bool:equal(data, "sponsor");
	if (g_bSponsorMatch) {
		for (new i = g_iSignupCount - 1; i >= 0; i--) {
			new p = g_iSignupList[i];
			if (isGuestPlayer(p)) {
				g_bSignedUp[p] = false;
				g_iSignupTeam[p] = 0;
				g_iSignupList[i] = g_iSignupList[--g_iSignupCount];
				ai_print(p, "已从报名中移除: 盗版玩家不能参与赞助局");
			}
		}
	}

	ai_print(0, "AI 报名比赛类型已设为: ^3%s^1", g_bSponsorMatch ? "赞助局" : "娱乐局");
	broadcastStatus();
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showSetupMenu(id) {
	if (!is_user_connected(id) || !isUserVipOrAdmin(id) || !g_bPostGroupSetup)
		return;

	new szTitle[64], szRule[32];
	ai_ruleName(id, _:g_iMatchRules, szRule, charsmax(szRule));
	formatex(szTitle, charsmax(szTitle), "\r赛前设置 \y[模式: %s]", szRule);

	new menu = menu_create(szTitle, "SetupMenuHandler");
	menu_additem(menu, "选择比赛模式", "rules");
	menu_additem(menu, "选择地图", "map");
	menu_setprop(menu, MPROP_EXITNAME, "关闭");
	menu_display(id, menu);
}

public SetupMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id) || !g_bPostGroupSetup)
		return PLUGIN_HANDLED;

	if (equal(data, "map"))
		beginMapSelect();
	else
		showRulesMenu(id);
	return PLUGIN_HANDLED;
}

public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;

	ai_print(0, "分组完成, 先选择比赛模式, 再选择地图");
	showGroups(0);

	if (showSetupToAdmins()) {
		ai_print(0, "管理员/VIP 优先选择比赛模式 (聊天输入 /signup 可重新打开)");
		return;
	}

	startRulesVote(0, -1);
}

public beginMapSelect() {
	if (!g_bPostGroupSetup) {
		startMatch();
		return;
	}

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
		showMapChoiceMenu(i);
		bShown = true;
	}
	if (bShown)
		return;

	startMapVote();
}


#if defined _hnsmenu_included
  #endinput
#endif

#define _hnsmenu_included

new Float:g_flTimeToVoteMode;

new bool:g_bMinModels[MAX_PLAYERS + 1];
new bool:g_bMinModelsKnown[MAX_PLAYERS + 1];
new g_iMinModelsAction[MAX_PLAYERS + 1];

stock gtrMenuInit() {
	register_menucmd(register_menuid("GTRMainMenu"), 1023, "gtrMainMenuHandler");
	register_menucmd(register_menuid("GTRStatusMenu"), 1023, "gtrInfoMenuHandler");
	register_menucmd(register_menuid("GTRGuideMenu"), 1023, "gtrInfoMenuHandler");
	register_menucmd(register_menuid("GTRMatchMenu"), 1023, "gtrMatchMenuHandler");
	register_menucmd(register_menuid("GTRPersonalMenu"), 1023, "gtrPersonalMenuHandler");
	register_menucmd(register_menuid("GTRMatchAdmin"), 1023, "mainMatchMenuHandler");
	register_menucmd(register_menuid("GTRCustomMenu"), 1023, "customMenuHandler");
	register_menucmd(register_menuid("GTRSettingsMenu"), 1023, "settingsMatchMenuHandler");
}

stock gtrShowFixedMenu(id, const szId[], const szMenu[], iKeys) {
	show_menu(id, iKeys | MENU_KEY_0, szMenu, -1, szId);
}

stock gtrMenuText(id, const szKey[], szOut[], iLen, const szFallback[]) {
	hns_lang_get(id, szKey, szOut, iLen, szFallback);
}

public gtrMainMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMenu[512], szText[128], iLen;
	gtrMenuText(id, "MENU_MAIN_TITLE", szText, charsmax(szText), "GTR游戏菜单");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n ^n", szText);
	gtrMenuText(id, "MENU_MAIN_MATCH", szText, charsmax(szText), "比赛菜单");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szText);
	gtrMenuText(id, "MENU_MAIN_SKIN", szText, charsmax(szText), "皮肤系统");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n ^n", szText);
	gtrMenuText(id, "MENU_MAIN_SPEC", szText, charsmax(szText), "观战休息 / Spec");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n", szText);
	gtrMenuText(id, "MENU_MAIN_PERSONAL", szText, charsmax(szText), "个人设置");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n", szText);
	gtrMenuText(id, "MENU_MAIN_STATUS", szText, charsmax(szText), "比赛状态");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n ^n", szText);
	gtrMenuText(id, "MENU_MAIN_GUIDE", szText, charsmax(szText), "玩家指南");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n", szText);
	gtrMenuText(id, "MENU_MAIN_ADMIN", szText, charsmax(szText), "管理员设置");
	if (isUserAdmin(id))
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \r%s^n", szText);
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \d%s^n", szText);
	gtrMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", szText);

	gtrShowFixedMenu(id, "GTRMainMenu", szMenu, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7);
	return PLUGIN_HANDLED;
}

public gtrMainMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;

	switch (key) {
		case 0: gtrMatchMenu(id);
		case 1: client_cmd(id, "say /skin");
		case 2: client_cmd(id, "say /spec");
		case 3: gtrPersonalMenu(id);
		case 4: gtrShowStatusMenu(id);
		case 5: gtrShowGuideMenu(id);
		case 6: if (isUserAdmin(id)) client_cmd(id, "adminmenu");
	}
	return PLUGIN_HANDLED;
}

stock gtrShowStatusMenu(id) {
	new szMenu[512], szText[128], szMode[48], szStage[48], szRule[48], szPause[32];
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	switch (g_iCurrentMode) {
		case MODE_TRAINING: gtrMenuText(id, "STATUS_MODE_TRAINING", szMode, charsmax(szMode), "训练");
		case MODE_LOBBY: gtrMenuText(id, "STATUS_MODE_LOBBY", szMode, charsmax(szMode), "大厅");
		case MODE_KNIFE: gtrMenuText(id, "STATUS_MODE_KNIFE", szMode, charsmax(szMode), "刀局");
		case MODE_PUB: gtrMenuText(id, "STATUS_MODE_PUBLIC", szMode, charsmax(szMode), "娱乐");
		case MODE_DM: gtrMenuText(id, "STATUS_MODE_DM", szMode, charsmax(szMode), "死亡竞赛");
		case MODE_ZM: gtrMenuText(id, "STATUS_MODE_ZM", szMode, charsmax(szMode), "僵尸");
		case MODE_MIX: gtrMenuText(id, "STATUS_MODE_MATCH", szMode, charsmax(szMode), "比赛");
		default: copy(szMode, charsmax(szMode), "-");
	}

	switch (g_iMatchStatus) {
		case MATCH_NONE: gtrMenuText(id, "STATUS_STAGE_IDLE", szStage, charsmax(szStage), "未开赛");
		case MATCH_CAPTAINPICK, MATCH_CAPTAINKNIFE, MATCH_TEAMPICK: gtrMenuText(id, "STATUS_STAGE_PICK", szStage, charsmax(szStage), "选人中");
		case MATCH_TEAMKNIFE: gtrMenuText(id, "STATUS_STAGE_KNIFE", szStage, charsmax(szStage), "刀局中");
		case MATCH_MAPPICK: gtrMenuText(id, "STATUS_STAGE_MAP", szStage, charsmax(szStage), "选图中");
		case MATCH_WAITCONNECT: gtrMenuText(id, "STATUS_STAGE_WAIT", szStage, charsmax(szStage), "等待玩家");
		case MATCH_STARTED: gtrMenuText(id, "STATUS_STAGE_STARTED", szStage, charsmax(szStage), "比赛进行中");
		default: copy(szStage, charsmax(szStage), "-");
	}

	switch (g_iCurrentRules) {
		case RULES_MR: gtrMenuText(id, "STATUS_RULE_MR", szRule, charsmax(szRule), "MR");
		case RULES_TIMER: gtrMenuText(id, "STATUS_RULE_TIMER", szRule, charsmax(szRule), "Wintime");
		case RULES_DUEL: gtrMenuText(id, "STATUS_RULE_DUEL", szRule, charsmax(szRule), "Duel");
		case RULES_ROUNDS: gtrMenuText(id, "STATUS_RULE_ROUNDS", szRule, charsmax(szRule), "回合制");
		case RULES_POINTSCAP: gtrMenuText(id, "STATUS_RULE_POINTSCAP", szRule, charsmax(szRule), "积分上限");
		case RULES_VAMP: gtrMenuText(id, "STATUS_RULE_VAMP", szRule, charsmax(szRule), "吸血");
		default: copy(szRule, charsmax(szRule), "-");
	}
	gtrMenuText(id, g_eMatchState == STATE_PAUSED ? "STATUS_PAUSED" : "STATUS_ACTIVE", szPause, charsmax(szPause), g_eMatchState == STATE_PAUSED ? "已暂停" : "进行中");
	gtrMenuText(id, "STATUS_TITLE", szText, charsmax(szText), "当前比赛状态");
	new iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	gtrMenuText(id, "STATUS_MODE_LABEL", szText, charsmax(szText), "模式");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szMode);
	gtrMenuText(id, "STATUS_STAGE_LABEL", szText, charsmax(szText), "阶段");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szStage);
	gtrMenuText(id, "STATUS_RULE_LABEL", szText, charsmax(szText), "规则");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szRule);
	gtrMenuText(id, "STATUS_STATE_LABEL", szText, charsmax(szText), "状态");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szPause);
	gtrMenuText(id, "STATUS_PLAYERS_LABEL", szText, charsmax(szText), "在线玩家");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%d^n^n^n", szText, iNum);
	gtrMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	gtrShowFixedMenu(id, "GTRStatusMenu", szMenu, 0);
}

stock gtrShowGuideMenu(id) {
	new szMenu[512], szText[128], szCommand[128], iLen;
	gtrMenuText(id, "GUIDE_TITLE", szText, charsmax(szText), "玩家指南");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	gtrMenuText(id, "GUIDE_SIGNUP", szText, charsmax(szText), "报名比赛");
	gtrMenuText(id, "GUIDE_CMD_SIGNUP", szCommand, charsmax(szCommand), "/signup");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szCommand);
	gtrMenuText(id, "GUIDE_QUERY", szText, charsmax(szText), "比赛数据");
	gtrMenuText(id, "GUIDE_CMD_QUERY", szCommand, charsmax(szCommand), "/hnsquery");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szCommand);
	gtrMenuText(id, "GUIDE_SURRENDER", szText, charsmax(szText), "投降认输");
	gtrMenuText(id, "GUIDE_CMD_SURRENDER", szCommand, charsmax(szCommand), "/surrender");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szCommand);
	gtrMenuText(id, "GUIDE_TRAINING", szText, charsmax(szText), "热身训练");
	gtrMenuText(id, "GUIDE_CMD_TRAINING", szCommand, charsmax(szCommand), "/training");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n", szText, szCommand);
	gtrMenuText(id, "GUIDE_SKIN", szText, charsmax(szText), "皮肤菜单");
	gtrMenuText(id, "GUIDE_CMD_SKIN", szCommand, charsmax(szCommand), "/skin");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%s: \y%s^n^n^n", szText, szCommand);
	gtrMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	gtrShowFixedMenu(id, "GTRGuideMenu", szMenu, 0);
}

public gtrInfoMenuHandler(id, key) {
	if (is_user_connected(id) && key == 9)
		gtrMainMenu(id);
	return PLUGIN_HANDLED;
}

public gtrMatchMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMenu[512], szText[128], iLen;
	gtrMenuText(id, "MENU_MATCH_TITLE", szText, charsmax(szText), "比赛菜单");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	gtrMenuText(id, "MENU_MATCH_SIGNUP", szText, charsmax(szText), "报名比赛");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szText);
	gtrMenuText(id, "MENU_MATCH_SURRENDER", szText, charsmax(szText), "投降认输");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n^n", szText);
	gtrMenuText(id, "MENU_MATCH_TRAINING", szText, charsmax(szText), "热身训练");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n", szText);
	gtrMenuText(id, "MENU_MATCH_QUERY", szText, charsmax(szText), "HNS比赛查询");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \y%s^n^n", szText);
	gtrMenuText(id, "MENU_MATCH_RULES", szText, charsmax(szText), "比赛规则");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n", szText);
	gtrMenuText(id, "MENU_MATCH_ADMIN", szText, charsmax(szText), "比赛管理");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. %s%s^n^n", isUserWatcher(id) ? "\r" : "\d", szText);
	gtrMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);

	gtrShowFixedMenu(id, "GTRMatchMenu", szMenu, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6);
	return PLUGIN_HANDLED;
}

public gtrMatchMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;

	switch (key) {
		case 0: client_cmd(id, "say /signup");
		case 1: client_cmd(id, "say /surrender");
		case 2: client_cmd(id, "say /training");
		case 3: client_cmd(id, "say /hnsquery");
		case 4: chat_print(id, "[HNS] 比赛规则: 请以当前服务器规则配置和比赛公告为准。");
		case 5: if (isUserWatcher(id)) mainMatchMenu(id);
	}
	return PLUGIN_HANDLED;
}

public gtrPersonalMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!g_bMinModelsKnown[id]) {
		gtrMinModelsQuery(id, 1);
		return PLUGIN_HANDLED;
	}

	ShowPersonalMenu(id);
	gtrMinModelsQuery(id, 0);
	return PLUGIN_HANDLED;
}

ShowPersonalMenu(id) {
	new szMenu[512], szText[128], iLen;
	gtrMenuText(id, "MENU_PERSONAL_TITLE", szText, charsmax(szText), "个人设置");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	gtrMenuText(id, "MENU_PERSONAL_HUD", szText, charsmax(szText), "HUD设置");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szText);
	gtrMenuText(id, g_bMinModels[id] ? "MENU_PERSONAL_MODELS_ON" : "MENU_PERSONAL_MODELS_OFF", szText, charsmax(szText), g_bMinModels[id] ? "模型屏蔽 [ON]" : "模型屏蔽 [OFF]");
	if (g_bMinModels[id])
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \y%s^n^n", szText);
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \r%s^n^n", szText);
	gtrMenuText(id, "MENU_PERSONAL_PTS", szText, charsmax(szText), "PTS查询分数");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \y%s^n", szText);
	gtrMenuText(id, "MENU_PERSONAL_SPEED", szText, charsmax(szText), "Speed颜色修改");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n^n", szText);
	gtrMenuText(id, "MENU_PERSONAL_LANGUAGE", szText, charsmax(szText), "语言设置");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n^n", szText);
	gtrMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);

	gtrShowFixedMenu(id, "GTRPersonalMenu", szMenu, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5);
}

public gtrPersonalMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;

	switch (key) {
		case 0: client_cmd(id, "say /hud");
		case 1: gtrMinModelsQuery(id, 2);
		case 2: client_cmd(id, "say /hnsquery");
		case 3: client_cmd(id, "say /speed");
		case 4: client_cmd(id, "say /lang");
	}
	return PLUGIN_HANDLED;
}

stock gtrMinModelsReset(id) {
	g_bMinModels[id] = false;
	g_bMinModelsKnown[id] = false;
	g_iMinModelsAction[id] = 0;
}

stock gtrMinModelsQuery(id, iAction) {
	if (!is_user_connected(id))
		return;

	g_iMinModelsAction[id] = iAction;
	query_client_cvar(id, "cl_minmodels", "MinModelsCvarHandler");
}

public MinModelsCvarHandler(id, const cvar[], const value[]) {
	if (!is_user_connected(id))
		return;

	new bool:bOn = (str_to_num(value) != 0);
	g_bMinModels[id] = bOn;
	g_bMinModelsKnown[id] = true;

	new iAction = g_iMinModelsAction[id];
	g_iMinModelsAction[id] = 0;

	if (iAction == 2) {
		bOn = !bOn;
		g_bMinModels[id] = bOn;
		client_cmd(id, "cl_minmodels %d", bOn ? 1 : 0);
		if (bOn)
			client_print_color(id, print_team_red, "^4[HNS]^1 当前模型屏蔽设置: ^1开");
		else
			client_print_color(id, print_team_red, "^4[HNS]^1 当前模型屏蔽设置: ^3关");
		ShowPersonalMenu(id);
	} else if (iAction == 1) {
		ShowPersonalMenu(id);
	}
}

stock bool:matchMenu_isActive() {
	if (g_iCurrentMode == MODE_MIX || g_iCurrentMode == MODE_KNIFE)
		return true;
	if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
		return true;
	if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
		return true;
	return false;
}

stock bool:matchMenu_canCustom() {
	return (g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY
		|| g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM);
}

stock bool:matchMenu_canPause() {
	return (g_iCurrentMode == MODE_MIX || g_iCurrentMode == MODE_KNIFE);
}

public matchMenuDisabled(id, menu, item) {
	return ITEM_DISABLED;
}

public mainMatchMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return PLUGIN_HANDLED;

	new szMenu[512], szText[128], iLen, iKeys;
	iKeys = MENU_KEY_1|MENU_KEY_3|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8;
	gtrMenuText(id, "MENU_ADMIN_MATCH_TITLE", szText, charsmax(szText), "比赛管理");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	gtrMenuText(id, matchMenu_isActive() ? "MENU_ADMIN_MATCH_STOP" : "MENU_ADMIN_MATCH_START", szText, charsmax(szText), matchMenu_isActive() ? "取消比赛" : "开启比赛");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r%s^n", szText);
	gtrMenuText(id, "MENU_ADMIN_MATCH_CUSTOM", szText, charsmax(szText), "娱乐模式");
	if (matchMenu_canCustom()) {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n^n", szText);
		iKeys |= MENU_KEY_2;
	} else {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \d%s^n^n", szText);
	}
	gtrMenuText(id, "MENU_ADMIN_MATCH_SETTINGS", szText, charsmax(szText), "比赛设置");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n", szText);
	gtrMenuText(id, "MENU_ADMIN_MATCH_PAUSE", szText, charsmax(szText), "暂停比赛");
	if (!matchMenu_canPause()) {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \d%s \r[NO]^n^n", szText);
	} else if (g_eMatchState == STATE_PAUSED) {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \r%s \r[OFF]^n^n", szText);
		iKeys |= MENU_KEY_4;
	} else {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \y%s \r[NO]^n^n", szText);
		iKeys |= MENU_KEY_4;
	}
	gtrMenuText(id, "MENU_ADMIN_MATCH_RESTART", szText, charsmax(szText), "重启回合");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n", szText);
	gtrMenuText(id, "MENU_ADMIN_MATCH_SWAP", szText, charsmax(szText), "互换阵营");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n^n", szText);
	gtrMenuText(id, "MENU_ADMIN_MATCH_BANS", szText, charsmax(szText), "封禁菜单 [比赛]");
	if (isUserFullWatcher(id)) {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w%s^n^n", szText);
		iKeys |= MENU_KEY_7;
	} else {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \d%s^n^n", szText);
	}
	gtrMenuText(id, "MENU_ADMIN_MATCH_TEAMS", szText, charsmax(szText), "调整队伍");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n^n", szText);
	gtrMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);

	gtrShowFixedMenu(id, "GTRMatchAdmin", szMenu, iKeys);
	return PLUGIN_HANDLED;
}

// ICGB 金币 仅赞助局可点
public icgbItemCallback(id, menu, item) {
	if (g_eMatchType == MATCH_TYPE_SPONSOR)
		return ITEM_ENABLED;
	return ITEM_DISABLED;
}

// ============================================================
//  第8项: ICGB 金币数量调整 (仅赞助局, 5-20 每5递增)
// ============================================================
public gcAdjustMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[96];
	formatex(szMsg, charsmax(szMsg), "\rGBIC 金币数量 (当前: \y%d\r)", g_iSponsorGC);
	new hMenu = menu_create(szMsg, "gcAdjustMenuHandler");

	menu_additem(hMenu, "\y5 金币^n", "5");
	menu_additem(hMenu, "\y10 金币^n", "10");
	menu_additem(hMenu, "\y15 金币^n", "15");
	menu_additem(hMenu, "\y20 金币^n", "20");

	if (g_bSponsorGcSetup)
		menu_setprop(hMenu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public gcAdjustMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		if (g_bSponsorGcSetup)
			gcAdjustMenu(id);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iNewGC = str_to_num(szData);
	if (iNewGC < 5 || iNewGC > 20 || iNewGC % 5 != 0) {
		chat_print(id, "[^3HNS^1] GBIC 只能设置为 5-20 且为 5 的倍数。");
		gcAdjustMenu(id);
		return PLUGIN_HANDLED;
	}

	set_sponsor_gc(id, iNewGC);
	if (g_bSponsorGcSetup) {
		g_bSponsorGcSetup = false;
		start_rules_menu(id);
	} else {
		mainMatchMenu(id);
	}
	return PLUGIN_HANDLED;
}

// 设置本场赞助奖金: 只改本场 GBIC 数字, 不覆盖赞助者账户余额
// 提示里的金币数字颜色跟随赞助者队伍: TT=绿色^3, CT=蓝色^4
stock set_sponsor_gc(id, iNewGC) {
	#pragma unused id
	g_iSponsorGC = iNewGC;

	if (is_user_connected(g_iSponsorPlayer) && getUserTeam(g_iSponsorPlayer) == TEAM_CT)
		chat_print(0, "[^3HNS^1] 本场 GBIC 奖金设为 ^4%d^1", iNewGC);
	else
		chat_print(0, "[^3HNS^1] 本场 GBIC 奖金设为 ^3%d^1", iNewGC);
}

public mainMatchMenuHandler(id, key) {
	if (!is_user_connected(id) || !isUserWatcher(id) || key == 9)
		return PLUGIN_HANDLED;

	switch (key) {
		case 0: {
			if (matchMenu_isActive()) {
				if (g_iCurrentMode == MODE_MIX)
					verifMenu(id);
				else
					cmdStop(id);
			} else {
				cmdStartMatch(id);
			}
		}
		case 1: {
			if (matchMenu_canCustom())
				customMenu(id);
			else
				mainMatchMenu(id);
		}
		case 2: {
			settingsMatchMenu(id);
		}
		case 3: {
			if (!matchMenu_canPause()) {
				mainMatchMenu(id);
			} else if (g_eMatchState == STATE_PAUSED) {
				cmdStopPause(id);
				mainMatchMenu(id);
			} else {
				cmdStartPause(id);
				mainMatchMenu(id);
			}
		}
		case 4: {
			cmdRestartRound(id);
			mainMatchMenu(id);
		}
		case 5: {
			cmdSwapTeams(id);
			mainMatchMenu(id);
		}
		case 6: {
			if (isUserFullWatcher(id))
				client_cmd(id, "hns_bans_menu");
			else
				mainMatchMenu(id);
		}
		case 7: {
			client_cmd(id, "amx_teammenu");
		}
	}

	return PLUGIN_HANDLED;
}

public customMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMenu[512], szMsg[64], szText[128], iLen, iKeys;
	iKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3;
	gtrMenuText(id, "MENU_CUSTOM_TITLE", szText, charsmax(szText), "娱乐模式");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_PUB");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szMsg);
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_DM");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n", szMsg);
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_ZM");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n^n", szMsg);
	if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM) {
		gtrMenuText(id, "MENU_CUSTOM_STOP", szText, charsmax(szText), "停止自定义模式");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \r%s^n^n", szText);
		iKeys |= MENU_KEY_4;
	} else {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	gtrMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);

	gtrShowFixedMenu(id, "GTRCustomMenu", szMenu, iKeys);
	return PLUGIN_HANDLED;
}

public customMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9) {
		if (is_user_connected(id) && key == 9)
			mainMatchMenu(id);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: cmdPubMode(id);
		case 1: cmdDMMode(id);
		case 2: cmdZMMode(id);
		case 3: cmdStop(id);
	}
	return PLUGIN_HANDLED;
}

public settingsMatchMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return PLUGIN_HANDLED;

	new szMenu[768], szMsg[96], szText[128], iLen;
	gtrMenuText(id, "MENU_SETTINGS_TITLE", szText, charsmax(szText), "比赛设置");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	if (g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY)
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDTIME_TRNG");
	else
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDTIME", get_cvar_float("mp_roundtime"));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szMsg);
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_FREEZETIME", get_cvar_num("mp_freezetime"));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n", szMsg);
	switch (g_iCurrentRules) {
		case RULES_MR: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_MAXROUND", g_iSettings[MAXROUNDS], g_iSettings[MAXROUNDS] * 2);
		}
		case RULES_TIMER: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_WINTIME", g_iSettings[WINTIME]);
		}
		case RULES_DUEL: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_DUEL", g_iSettings[DUELROUNDS]);
		}
		case RULES_ROUNDS: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDS", g_iSettings[MAXROUNDS]);
		}
	}
	replace_all(szMsg, charsmax(szMsg), "^n", "");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n^n", szMsg);
	if (g_iSettings[ONEHPMODE] == 0)
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ONEHP_ON");
	else
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ONEHP_OFF");
	replace_all(szMsg, charsmax(szMsg), "^n", "");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n", szMsg);
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_FLASH", g_iSettings[FLASH]);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n", szMsg);
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_SMOKE", g_iSettings[SMOKE]);
	replace_all(szMsg, charsmax(szMsg), "^n", "");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n^n", szMsg);
	new semiclipColor[3], semiclipState[8];
	if (g_iSemiclipForceMode == 1) {
		copy(semiclipColor, charsmax(semiclipColor), "\y");
		copy(semiclipState, charsmax(semiclipState), "开");
	} else if (g_iSemiclipForceMode == 0) {
		copy(semiclipColor, charsmax(semiclipColor), "\r");
		copy(semiclipState, charsmax(semiclipState), "关");
	} else {
		copy(semiclipColor, charsmax(semiclipColor), "\w");
		copy(semiclipState, charsmax(semiclipState), "自动");
	}
	formatex(szMsg, charsmax(szMsg), "穿透模式 [%s]", semiclipState);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%s7. %s%s^n", semiclipColor, semiclipColor, szMsg);
	gtrMenuText(id, "MENU_ADMIN_MATCH_TEAMS", szText, charsmax(szText), "调整队伍");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n^n", szText);
	gtrMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);

	gtrShowFixedMenu(id, "GTRSettingsMenu", szMenu, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8);
	return PLUGIN_HANDLED;
}

public settingsMatchMenuHandler(id, key) {
	if (!is_user_connected(id) || !isUserWatcher(id) || key == 9) {
		if (is_user_connected(id) && isUserWatcher(id) && key == 9)
			mainMatchMenu(id);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: {
			new Float:roundtime = get_cvar_float("mp_roundtime");
			if (roundtime < 2.5)
				roundtime = 2.5;
			else if (roundtime < 3.0)
				roundtime = 3.0;
			else if (roundtime < 3.5)
				roundtime = 3.5;
			else if (roundtime < 4.0)
				roundtime = 4.0;
			else if (roundtime < 4.5)
				roundtime = 4.5;
			else if (roundtime < 5.0)
				roundtime = 5.0;
			else
				roundtime = 2.5;

			set_cvar_float("mp_roundtime", roundtime);
			chat_print(0, "%l", "SET_ROUNDTIME_MENU", id, roundtime);
			settingsMatchMenu(id);
		}
		case 1: {
			new freezetime = get_cvar_num("mp_freezetime");
			if (freezetime < 5)
				freezetime = 5;
			else if (freezetime < 10)
				freezetime = 10;
			else if (freezetime < 15)
				freezetime = 15;
			else if (freezetime < 20)
				freezetime = 20;
			else if (freezetime < 25)
				freezetime = 25;
			else if (freezetime < 30)
				freezetime = 30;
			else
				freezetime = 0;

			set_cvar_num("mp_freezetime", freezetime);
			chat_print(0, "%l", "SET_FREEZETIME", id, freezetime);
			settingsMatchMenu(id);
		}
		case 2: {
			switch (g_iCurrentRules) {
				case RULES_MR: {
					if (g_iSettings[MAXROUNDS] < 5 || g_iSettings[MAXROUNDS] >= 11)
						g_iSettings[MAXROUNDS] = 5;
					else
						g_iSettings[MAXROUNDS]++;
					chat_print(0, "%l", "SET_MAXROUNDS_MENU", id, g_iSettings[MAXROUNDS]);
				}
				case RULES_TIMER: {
					if (g_iSettings[WINTIME] < 10.0)
						g_iSettings[WINTIME] = 10.0;
					else if (g_iSettings[WINTIME] < 15.0)
						g_iSettings[WINTIME] = 15.0;
					else if (g_iSettings[WINTIME] < 20.0)
						g_iSettings[WINTIME] = 20.0;
					else if (g_iSettings[WINTIME] < 25.0)
						g_iSettings[WINTIME] = 25.0;
					else if (g_iSettings[WINTIME] < 30.0)
						g_iSettings[WINTIME] = 30.0;
					else if (g_iSettings[WINTIME] < 35.0)
						g_iSettings[WINTIME] = 35.0;
					else if (g_iSettings[WINTIME] < 40.0)
						g_iSettings[WINTIME] = 40.0;
					else if (g_iSettings[WINTIME] < 45.0)
						g_iSettings[WINTIME] = 45.0;
					else if (g_iSettings[WINTIME] < 50.0)
						g_iSettings[WINTIME] = 50.0;
					else if (g_iSettings[WINTIME] < 55.0)
						g_iSettings[WINTIME] = 55.0;
					else if (g_iSettings[WINTIME] < 60.0)
						g_iSettings[WINTIME] = 60.0;
					else
						g_iSettings[WINTIME] = 10.0;
					chat_print(0, "%l", "SET_WINTIME_MENU", id, g_iSettings[WINTIME]);
				}
				case RULES_DUEL: {
					if (g_iSettings[DUELROUNDS] <= 2)
						g_iSettings[DUELROUNDS] = 3;
					else if (g_iSettings[DUELROUNDS] <= 3)
						g_iSettings[DUELROUNDS] = 4;
					else if (g_iSettings[DUELROUNDS] >= 4)
						g_iSettings[DUELROUNDS] = 2;
				}
				case RULES_ROUNDS: {
					if (g_iSettings[MAXROUNDS] < 5 || g_iSettings[MAXROUNDS] >= 11)
						g_iSettings[MAXROUNDS] = 5;
					else
						g_iSettings[MAXROUNDS]++;
					chat_print(0, "%l", "SET_ROUNDS", id, g_iSettings[MAXROUNDS]);
				}
			}
			settingsMatchMenu(id);
		}
		case 3: {
			if (!g_iSettings[ONEHPMODE])
				g_iSettings[ONEHPMODE] = 1;
			else
				g_iSettings[ONEHPMODE] = 0;
			settingsMatchMenu(id);
		}
		case 4: {
			if (g_iSettings[FLASH] == 0)
				g_iSettings[FLASH] = 1;
			else if (g_iSettings[FLASH] <= 1)
				g_iSettings[FLASH] = 2;
			else if (g_iSettings[FLASH] <= 2)
				g_iSettings[FLASH] = 3;
			else if (g_iSettings[FLASH] >= 3)
				g_iSettings[FLASH] = 0;
			settingsMatchMenu(id);
		}
		case 5: {
			if (g_iSettings[SMOKE] <= 1)
				g_iSettings[SMOKE] = 2;
			else if (g_iSettings[SMOKE] >= 2)
				g_iSettings[SMOKE] = 1;
			settingsMatchMenu(id);
		}
		case 6: {
			if (g_iSemiclipForceMode == -1)
				g_iSemiclipForceMode = 1;
			else if (g_iSemiclipForceMode == 1)
				g_iSemiclipForceMode = 0;
			else
				g_iSemiclipForceMode = -1;

			new iMenuMode = g_iSemiclipForceMode == -1 ? 0 : (g_iSemiclipForceMode == 1 ? 1 : 2);
			if (!hns_semiclip_menu_set(iMenuMode)) {
				apply_hns_semiclip();
				printSemiclipState();
			}
			settingsMatchMenu(id);
		}
		case 7: client_cmd(id, "amx_teammenu");
	}
	return PLUGIN_HANDLED;
}

stock printSemiclipState() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		switch (g_iSemiclipForceMode) {
			case 1: client_print_color(iPlayers[i], print_team_blue, "^3[HNS] 穿透模式: 开");
			case 0: client_print_color(iPlayers[i], print_team_red, "^3[HNS] 穿透模式: 关");
			default: client_print_color(iPlayers[i], print_team_blue, "^1[HNS] 穿透模式: 自动");
		}
	}
}

public verifMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_VERIF_TITLE");
	new hMenu = menu_create(szMsg, "verifMenuHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NO");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_YES");
	menu_additem(hMenu, szMsg, "2");

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public verifMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(hMenu);

	switch (item) {
		case 0: {
			return PLUGIN_HANDLED;
		}
		case 1: {
			cmdStop(id);
		}
	}
	return PLUGIN_HANDLED;
}

public menuSelectMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (g_iCurrentMode == MODE_MIX) {
		chat_print(id, "%L", id, "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	// 报名即将结束: 请管理员选择比赛模式和回合地图
	play_regclose_sound("admin");

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_TITLE");
	new hMenu = menu_create(szMsg, "HandlerSelectMode");
	
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_MR");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_WINTIME");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_DUEL");
	menu_additem(hMenu, szMsg, "3");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_ROUNDS");
	menu_additem(hMenu, szMsg, "4");
		
	menu_setprop(hMenu, MPROP_EXIT, MEXIT_ALL);
	
	menu_display(id, hMenu, 0);
	
	return PLUGIN_HANDLED;
}

public HandlerSelectMode(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new index = str_to_num(szData);

	switch (index) {
		case 1: {
			cmdMrMode(id);
		}
		case 2: {
			cmdWintimeMode(id);
		}
		case 3: {
			cmdDuelMode(id);
		}
		case 4: {
			cmdRoundsMode(id);
		}
	}

	return PLUGIN_HANDLED;
}

public StartVoteRules() {
	g_flTimeToVoteMode = get_gametime() + 15.0;
	g_iVoteRules[RULES_TIMER] = g_iVoteRules[RULES_MR] = g_iVoteRules[RULES_ROUNDS] = 0;

	// 报名即将结束: 请玩家投票选择比赛模式和回合地图
	play_regclose_sound("vote");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (!is_user_connected(id))
			continue;

		if(getUserTeam(id) != TEAM_CT && getUserTeam(id) != TEAM_TERRORIST) {
			continue;
		}

		new szMsg[64];

		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_TITLE");
		new hMenu = menu_create(szMsg, "HandlerStartVoteRules");
		
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_MR");
		menu_additem(hMenu, szMsg, "1");

		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_WINTIME");
		menu_additem(hMenu, szMsg, "2");

		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_ROUNDS");
		menu_additem(hMenu, szMsg, "3");
			
		menu_setprop(hMenu, MPROP_EXIT, MEXIT_ALL);
		
		menu_display(id, hMenu, 0);
	}

	set_task(15.0, "VoteFinished", 83129);
}

public HandlerStartVoteRules(id, hMenu, item) {
	if (item == MENU_EXIT || get_gametime() > g_flTimeToVoteMode) {
		menu_destroy(hMenu);
		return;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new index = str_to_num(szData);

		if (index == 1) {
		g_iVoteRules[RULES_MR]++;
		chat_print(0, "%l", "VOTE_MR", id);
	} else if (index == 2) {
		g_iVoteRules[RULES_TIMER]++;
		chat_print(0, "%l", "VOTE_WT", id);
	} else {
		g_iVoteRules[RULES_ROUNDS]++;
		chat_print(0, "%l", "VOTE_ROUNDS", id);
	}
}

public VoteFinished() {
	new winner = RULES_MR;
	if (g_iVoteRules[RULES_TIMER] > g_iVoteRules[winner]) winner = RULES_TIMER;
	if (g_iVoteRules[RULES_ROUNDS] > g_iVoteRules[winner]) winner = RULES_ROUNDS;
	g_iCurrentRules = NATCH_RULES:winner;
	if (g_iCurrentRules == RULES_ROUNDS)
		g_iSettings[MAXROUNDS] = 7;

	new modeName[16];
	copy(modeName, charsmax(modeName), winner == RULES_MR ? "MR" : winner == RULES_TIMER ? "Wintime" : "回合制");
	chat_print(0, "%l", "VOTE_WIN", modeName);

	arrayset(g_iVoteRules, 0, sizeof g_iVoteRules);	
}

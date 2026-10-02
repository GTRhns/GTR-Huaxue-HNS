#if defined _hnsmenu_included
  #endinput
#endif

#define _hnsmenu_included

new Float:g_flTimeToVoteMode;

public mainMatchMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return PLUGIN_HANDLED;

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MIX_TITLE");
	new hMenu = menu_create(szMsg, "mainMatchMenuHandler");

	if (hns_is_knife_map()) {
		if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_CAP");
		else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_TEAMKNIFE && g_eMatchState == STATE_PAUSED)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_UNPAUSEKF");
		else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPCAP");
		else
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_NOTCAP");
	} else {
		if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPCUSTOM");
		else if ((g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY) && g_iMatchStatus <= MATCH_WAITCONNECT)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_MIX");
		else {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPMIX");
		}
	}

	menu_additem(hMenu, szMsg, "1");


	if (hns_is_knife_map()) {
		if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_NOTSTARTKF");
		else if (g_iCurrentMode == MODE_KNIFE)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPKF");
		else
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STARTKF");
	} else {
		if (g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_CUSTOM");
		else if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_BLEND");
		else {
			if (g_eMatchState != STATE_PAUSED)
				formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_PAUSE");
			else
				formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_UNPAUSE");
		}
	}
	
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_SETTINGS");
	menu_additem(hMenu, szMsg, "3");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_RESTART");
	menu_additem(hMenu, szMsg, "4");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_SWAP");
	menu_additem(hMenu, szMsg, "5");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_WTRMENU");
	menu_additem(hMenu, szMsg, "6");

	if (g_eMatchType == MATCH_TYPE_SPONSOR) {
		formatex(szMsg, charsmax(szMsg), "GBIC金币数量: \y%d", g_iSponsorGC);
		menu_additem(hMenu, szMsg, "7", _, menu_makecallback("icgbItemCallback"));
	} else {
		formatex(szMsg, charsmax(szMsg), "\dGBIC金币数量");
		menu_additem(hMenu, szMsg, "7", _, menu_makecallback("icgbItemCallback"));
	}

	if (isUserAdmin(id)) {
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_ADMMENU");
	} else {
		formatex(szMsg, charsmax(szMsg), "\d%L", id, "MENU_MAIN_ADMMENU");
	}
	menu_additem(hMenu, szMsg, "8");

	menu_display(id, hMenu, 0);

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

public mainMatchMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	
	new iKey = str_to_num(szData);
	
	switch (iKey) {
		case 1: {
			if (hns_is_knife_map()) {
				if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
					cmdCaptain(id);
				else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_TEAMKNIFE && g_eMatchState == STATE_PAUSED)
					cmdStopPause(id);
				else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE|| g_iMatchStatus == MATCH_TEAMPICK)
					cmdStop(id);
				else
					mainMatchMenu(id);
			} else {
				if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM || g_iMatchStatus == MATCH_WAITCONNECT) { // beta
					cmdStop(id);
				}
				else if ((g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY) && g_iMatchStatus <= MATCH_WAITCONNECT)
					cmdStartMatch(id);
				else {
					verifMenu(id);
				}
			}
		}
		case 2: {
			if (hns_is_knife_map()) {
				if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
					mainMatchMenu(id);
				else if (g_iCurrentMode == MODE_KNIFE)
					cmdStop(id);
				else
					cmdKnifeRound(id);
			} else {
				if (g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY)
					customMenu(id);
				else if ((g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_ZM))
					cmdBlend(id);
				else {
					if (g_eMatchState != STATE_PAUSED)
						cmdStartPause(id);
					else
						cmdStopPause(id);
				}
			}
		}
		case 3: {
			settingsMatchMenu(id);
		}
		case 4: {
			cmdRestartRound(id);
		}
		case 5: {
			cmdSwapTeams(id);
		}
		case 6: {
			client_cmd(id, "watcher");
		}
		case 7: {
			if (g_eMatchType == MATCH_TYPE_SPONSOR)
				gcAdjustMenu(id);
			else
				mainMatchMenu(id);
		}
		case 8: {
			if (isUserAdmin(id))
				client_cmd(id, "amxmodmenu");
			else
				mainMatchMenu(id);
		}
	}

	return PLUGIN_HANDLED;
}

public customMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MIX_TITLE");
	new hMenu = menu_create(szMsg, "customMenuHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_PUB");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_DM");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_ZM");
	menu_additem(hMenu, szMsg, "3");

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public customMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	new iKey = str_to_num(szData);

	switch (iKey) {
		case 1: {
			cmdPubMode(id);
		}
		case 2: {
			cmdDMMode(id);
		}
		case 3: {
			cmdZMMode(id);
		}
	}
	return PLUGIN_HANDLED;
}

public settingsMatchMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MIX_TITLE");
	new hMenu = menu_create(szMsg, "settingsMatchMenuHandler");

	if (g_iCurrentMode == MODE_TRAINING || g_iCurrentMode == MODE_LOBBY)
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDTIME_TRNG");
	else
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDTIME", get_cvar_float("mp_roundtime"));

	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_FREEZETIME", get_cvar_num("mp_freezetime"));
	menu_additem(hMenu, szMsg, "2");

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
	
	menu_additem(hMenu, szMsg, "3");

	if (g_iSettings[ONEHPMODE] == 0)
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ONEHP_ON");
	else
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ONEHP_OFF");
	
	menu_additem(hMenu, szMsg, "4");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_FLASH", g_iSettings[FLASH]);
	menu_additem(hMenu, szMsg, "5");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_SMOKE", g_iSettings[SMOKE]);
	menu_additem(hMenu, szMsg, "6");

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public settingsMatchMenuHandler(id, hMenu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		mainMatchMenu(id);
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iKey = str_to_num(szData);
	switch (iKey) {
		case 1: {
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
		case 2: {
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
		case 3: {
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
		case 4: {
			if (!g_iSettings[ONEHPMODE])
				g_iSettings[ONEHPMODE] = 1;
			else
				g_iSettings[ONEHPMODE] = 0;

			settingsMatchMenu(id);
		}
		case 5: {
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
		case 6: {
			if (g_iSettings[SMOKE] <= 1)
				g_iSettings[SMOKE] = 2;
			else if (g_iSettings[SMOKE] >= 2)
				g_iSettings[SMOKE] = 1;

			settingsMatchMenu(id);
		}
	}
	return PLUGIN_HANDLED;
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

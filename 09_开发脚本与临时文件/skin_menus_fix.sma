SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuGold(id) {
	new iGold = hns_gc_get_player(id);
	new szTitle[160], szItem[96];
	SkinLangF(id, "SKIN_GOLD_TITLE", "\yGBIC金币 \w· \r账户^n\w余额: \r%d  \w租期: \y%d天^n\w升级永久: \y%d 金币",
		szTitle, charsmax(szTitle), iGold, g_iRentDays, g_iUpgradePrice);
	new menu = menu_create(szTitle, "GoldHandler");
	SkinLangF(id, "SKIN_GOLD_UP", "升级已购皮肤为永久  \d[%d金币/款]", szItem, charsmax(szItem), g_iUpgradePrice);
	menu_additem(menu, szItem, "up");
	SkinLang(id, "SKIN_GOLD_REFRESH", szItem, charsmax(szItem), "刷新余额");
	menu_additem(menu, szItem, "refresh");
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuSqlDebug(id) {
	new szHost[64], szAuth[MAX_AUTHID_LENGTH], szStatus[64], szTitle[256], szItem[160];
	copy(szHost, charsmax(szHost), g_eDb[db_host]);
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	SkinSqlStatusText(id, szStatus, charsmax(szStatus));
	SkinLangF(id, "SKIN_SQL_TITLE", "\yMySQL连接与调试^n\w状态: %s%s^n\w主机: \y%s  \w库: \y%s^n\w你的账号: \y%s^n\w皮肤池: \y%d  \w拥有记录: \y%d  \w当前选用: \y%d",
		szTitle, charsmax(szTitle),
		g_bSqlReady ? "\y" : "\r", szStatus,
		szHost, g_eDb[db_db], szAuth,
		g_iPoolSize, g_iSqlOwnedCount, g_iSqlCurrentCount);
	new menu = menu_create(szTitle, "SqlMenuHandler");

	SkinLang(id, "SKIN_SQL_PING", szItem, charsmax(szItem), "测试连接");
	menu_additem(menu, szItem, "ping");
	SkinLang(id, "SKIN_SQL_COUNT", szItem, charsmax(szItem), "查询我的皮肤记录");
	menu_additem(menu, szItem, "count");
	SkinLang(id, "SKIN_SQL_SYNC", szItem, charsmax(szItem), "重新同步皮肤目录");
	menu_additem(menu, szItem, "sync");
	SkinLang(id, "SKIN_SQL_RELOAD", szItem, charsmax(szItem), "重新读取配置并重连");
	menu_additem(menu, szItem, "reload");
	if (g_szSqlLastErr[0]) {
		SkinLangF(id, "SKIN_SQL_ERR", "\r最近错误(%d): %s", szItem, charsmax(szItem), g_iSqlLastErr, g_szSqlLastErr);
		menu_additem(menu, szItem, "err");
	} else {
		SkinLang(id, "SKIN_SQL_ERR_NONE", szItem, charsmax(szItem), "\d最近错误: 无");
		menu_additem(menu, szItem, "err");
	}

	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

SqlPing(id) {
	if (g_hSqlTuple == Empty_Handle) {
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_NONE", "未配置 MySQL");
		MenuSqlDebug(id);
		return;
	}
	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_SQL_PING, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler", "SELECT 1", cData, sizeof(cData));
	SkinChat(id, print_team_default, "SKIN_CHAT_SQL_PING", "正在测试 MySQL 连接...");
}

SqlCountMine(id) {
	if (g_hSqlTuple == Empty_Handle) {
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_NONE", "未配置 MySQL");
		MenuSqlDebug(id);
		return;
	}
	new szAuth[MAX_AUTHID_LENGTH], szEsc[MAX_AUTHID_LENGTH * 2];
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	EscapeSql(szAuth, szEsc, charsmax(szEsc));
	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_SQL_COUNT, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("SELECT (SELECT COUNT(*) FROM %s WHERE authid='%s'), (SELECT COUNT(*) FROM %s WHERE authid='%s')",
			OWNS_TABLE, szEsc, CUR_TABLE, szEsc),
		cData, sizeof(cData));
	SkinChat(id, print_team_default, "SKIN_CHAT_SQL_COUNTING", "正在查询记录  账号: ^3%s", szAuth);
}

SqlReload(id) {
	if (g_hSqlTuple) {
		SQL_FreeHandle(g_hSqlTuple);
		g_hSqlTuple = Empty_Handle;
	}
	LoadDbCfg();
	g_hSqlTuple = SQL_MakeDbTuple(g_eDb[db_host], g_eDb[db_user], g_eDb[db_pass], g_eDb[db_db]);
	SQL_SetCharset(g_hSqlTuple, "utf8");
	copy(g_szSqlStatus, charsmax(g_szSqlStatus), "reconnect");
	DbSyncCatalog();
	new szStatus[64];
	SkinSqlStatusText(id, szStatus, charsmax(szStatus));
	SkinChat(id, print_team_default, "SKIN_CHAT_SQL_RELOADED", "已重新读取配置并同步  状态: %s", szStatus);
	MenuSqlDebug(id);
}

MenuConfirmBuy(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	if (row[pool_price] == 0) {
		DoBuy(id, idx);
		return;
	}

	new szRent[32], szTitle[160], szItem[96];
	if (g_iRentDays > 0)
		SkinLangF(id, "SKIN_DAYS", "%d天", szRent, charsmax(szRent), g_iRentDays);
	else
		SkinLang(id, "SKIN_PERM", szRent, charsmax(szRent), "永久");
	SkinLangF(id, "SKIN_BUY_TITLE", "\y确认购买^n\w皮肤: \y%s^n\w价格: \r%d 金币  \w租期: \y%s",
		szTitle, charsmax(szTitle), row[pool_key], row[pool_price], szRent);
	new menu = menu_create(szTitle, "ConfirmHandler");
	new szInfo[12];
	num_to_str(idx, szInfo, charsmax(szInfo));
	SkinLangF(id, "SKIN_BUY_OK", "确认购买  \r-%d", szItem, charsmax(szItem), row[pool_price]);
	menu_additem(menu, szItem, szInfo);
	SkinLang(id, "SKIN_CANCEL", szItem, charsmax(szItem), "取消");
	menu_additem(menu, szItem, "cancel");
	SkinMenuStyle(id, menu);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

MenuUpgrade(id) {
	new szTitle[128], szLeft[48];
	SkinLangF(id, "SKIN_UP_TITLE", "\y升级永久皮肤^n\w每款 \r%d 金币  \w余额: \r%d",
		szTitle, charsmax(szTitle), g_iUpgradePrice, hns_gc_get_player(id));
	new menu = menu_create(szTitle, "UpgradeHandler");
	new szInfo[12], szTxt[160], added;
	SkinLang(id, "SKIN_ITEM_LEFT", szLeft, charsmax(szLeft), "%s  \d[剩%d天]");
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		new exp = SkinExpire(id, row[pool_key]);
		if (exp <= 0 || exp <= get_systime())
			continue;
		format(szTxt, charsmax(szTxt), szLeft, row[pool_key], DaysLeft(id, row[pool_key]));
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}
	if (!added) {
		SkinLang(id, "SKIN_UP_EMPTY", szTxt, charsmax(szTxt), "\d(没有正在租期中的皮肤)");
		menu_additem(menu, szTxt, "none");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuConfirmUpgrade(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	new szTitle[160], szItem[96];
	SkinLangF(id, "SKIN_UP_CONFIRM", "\y升级为永久?^n\w皮肤: \y%s^n\w花费: \r%d 金币",
		szTitle, charsmax(szTitle), row[pool_key], g_iUpgradePrice);
	new menu = menu_create(szTitle, "UpgradeConfirmHandler");
	new szInfo[12];
	num_to_str(idx, szInfo, charsmax(szInfo));
	SkinLangF(id, "SKIN_UP_OK", "确认升级  \r-%d", szItem, charsmax(szItem), g_iUpgradePrice);
	menu_additem(menu, szItem, szInfo);
	SkinLang(id, "SKIN_CANCEL", szItem, charsmax(szItem), "取消");
	menu_additem(menu, szItem, "cancel");
	SkinMenuStyle(id, menu);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

MenuAdmin(id) {
	if (!IsSkinAdmin(id)) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有管理权限");
		MenuSkin(id);
		return;
	}

	new szTitle[64], szItem[64];
	SkinLang(id, "SKIN_ADMIN_TITLE", szTitle, charsmax(szTitle), "\y管理员设置 \w· \r皮肤");
	new menu = menu_create(szTitle, "AdminHandler");
	SkinLang(id, "SKIN_ADMIN_POOL", szItem, charsmax(szItem), "查看皮肤池");
	menu_additem(menu, szItem, "1");
	SkinLang(id, "SKIN_ADMIN_OWNED", szItem, charsmax(szItem), "查看玩家已拥有皮肤");
	menu_additem(menu, szItem, "2");
	SkinLang(id, "SKIN_ADMIN_GIVE", szItem, charsmax(szItem), "给玩家发放皮肤");
	menu_additem(menu, szItem, "3");
	SkinLang(id, "SKIN_ADMIN_REMOVE", szItem, charsmax(szItem), "移除玩家皮肤");
	menu_additem(menu, szItem, "4");
	SkinLang(id, "SKIN_ADMIN_GIVEALL", szItem, charsmax(szItem), "发放全部皮肤给玩家");
	menu_additem(menu, szItem, "5");
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuPoolList(id) {
	if (g_iPoolSize == 0) {
		SkinChat(id, print_team_red, "SKIN_CHAT_POOL_EMPTY", "皮肤池为空");
		return;
	}

	new szTitle[64], szTeam[16];
	SkinLangF(id, "SKIN_POOL_TITLE", "\y皮肤池  \w共 \r%d \w款", szTitle, charsmax(szTitle), g_iPoolSize);
	new menu = menu_create(szTitle, "PoolListHandler");
	new szInfo[12], szTxt[160];
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		SkinTeamName(id, row[pool_team], szTeam, charsmax(szTeam));
		format(szTxt, charsmax(szTxt), "\y[%s]\w %s  \d[%d]", szTeam, row[pool_key], row[pool_price]);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuPickPlayer(const mode[], id) {
	copy(g_pendingMode, charsmax(g_pendingMode), mode);
	g_pendingAdmin = id;

	new szTitle[64];
	if (g_pendingMode[0] == 'v')
		SkinLang(id, "SKIN_PICK_VIEW", szTitle, charsmax(szTitle), "\y选择玩家 \w· 查看拥有");
	else if (g_pendingMode[0] == 'g')
		SkinLang(id, "SKIN_PICK_GIVE", szTitle, charsmax(szTitle), "\y选择玩家 \w· 发放皮肤");
	else if (g_pendingMode[0] == 'a')
		SkinLang(id, "SKIN_PICK_ALL", szTitle, charsmax(szTitle), "\y选择玩家 \w· 发放全部");
	else
		SkinLang(id, "SKIN_PICK_REMOVE", szTitle, charsmax(szTitle), "\y选择玩家 \w· 移除皮肤");

	new menu = menu_create(szTitle, "PickPlayerHandler");
	new szTxt[80], added;
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i) || is_user_hltv(i))
			continue;
		new szName[32], szAuth[MAX_AUTHID_LENGTH];
		get_user_name(i, szName, charsmax(szName));
		GetPlayerAuth(i, szAuth, charsmax(szAuth));
		format(szTxt, charsmax(szTxt), "%s  \d[%s]", szName, szAuth);
		menu_additem(menu, szTxt, fmt("%d", i));
		added++;
	}
	if (!added) {
		SkinLang(id, "SKIN_PICK_EMPTY", szTxt, charsmax(szTxt), "\d(当前没有在线玩家)");
		menu_additem(menu, szTxt, "none");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuViewOwned(id, target) {
	g_pendingTarget = target;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new teamChar = CharOfTeam(get_member(target, m_iTeam));
	new szTeam[16], szTitle[96], szTxt[128], szSel[32], szPerm[24], szExp[24], szLeft[32];
	SkinTeamShort(id, teamChar, szTeam, charsmax(szTeam));
	SkinLangF(id, "SKIN_VIEW_TITLE", " %s 拥有的皮肤 (当前%s)", szTitle, charsmax(szTitle), szName, szTeam);
	new menu = menu_create(szTitle, "ViewOwnedHandler");
	SkinLang(id, "SKIN_TAG_SELECTED", szSel, charsmax(szSel), "  \r[已选择]");
	SkinLang(id, "SKIN_TAG_PERM", szPerm, charsmax(szPerm), "  [永久]");
	SkinLang(id, "SKIN_TAG_EXPIRED", szExp, charsmax(szExp), "  [已过期]");
	SkinLang(id, "SKIN_TAG_LEFT", szLeft, charsmax(szLeft), "  [剩%d天]");
	if (g_Owned[target] && ArraySize(g_Owned[target]) > 0) {
		for (new i = 0; i < ArraySize(g_Owned[target]); i++) {
			new key[SKIN_KEY_MAX];
			ArrayGetString(g_Owned[target], i, key, charsmax(key));
			new idx = PoolIndexOf(key);
			new exp = SkinExpire(target, key);
			new szStat[24], szTeamTag[16];
			if (exp == 0)
				copy(szStat, charsmax(szStat), szPerm);
			else if (exp > get_systime())
				format(szStat, charsmax(szStat), szLeft, DaysLeft(target, key));
			else
				copy(szStat, charsmax(szStat), szExp);
			if (idx != -1)
				SkinTeamName(id, PoolTeamChar(idx), szTeamTag, charsmax(szTeamTag));
			else
				copy(szTeamTag, charsmax(szTeamTag), "?");
			format(szTxt, charsmax(szTxt), "\y[%s]\w %s%s%s",
				szTeamTag, key, szStat,
				cur_match(target, key, teamChar) ? szSel : "");
			menu_additem(menu, szTxt);
		}
	} else {
		SkinLang(id, "SKIN_VIEW_EMPTY", szTxt, charsmax(szTxt), "\d(该玩家没有皮肤)");
		menu_additem(menu, szTxt);
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

bool:cur_match(target, const key[], teamChar) {
	new cur[SKIN_KEY_MAX];
	CurSlot(target, cur, charsmax(cur), teamChar);
	return cur[0] && equal(cur, key);
}

MenuGiveSkin(id, target) {
	g_pendingTarget = target;
	g_pendingAdmin = id;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new szTeam[16], szTitle[96], szOwn[48];
	SkinTeamShort(id, g_pendingGiveTeam, szTeam, charsmax(szTeam));
	SkinLangF(id, "SKIN_GIVE_TITLE", "\y发放皮肤 \w· %s^n\w范围: \y%s", szTitle, charsmax(szTitle), szName, szTeam);
	new menu = menu_create(szTitle, "GiveSkinHandler");
	SkinLang(id, "SKIN_ITEM_OWNED", szOwn, charsmax(szOwn), "\y[%s]\w %s  \r[已拥有]");
	new szInfo[12], szTxt[160], added, szTeamTag[16];
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (g_pendingGiveTeam && row[pool_team] != g_pendingGiveTeam)
			continue;
		SkinTeamName(id, row[pool_team], szTeamTag, charsmax(szTeamTag));
		if (HasSkin(target, row[pool_key]))
			format(szTxt, charsmax(szTxt), szOwn, szTeamTag, row[pool_key]);
		else
			format(szTxt, charsmax(szTxt), "\y[%s]\w %s", szTeamTag, row[pool_key]);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}
	if (!added) {
		SkinLang(id, "SKIN_GIVE_EMPTY", szTxt, charsmax(szTxt), "\d(没有可发放的皮肤)");
		menu_additem(menu, szTxt, "none");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuRemoveSkin(id, target) {
	g_pendingTarget = target;
	g_pendingAdmin = id;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new szTitle[96], szTxt[128], szTeamTag[16];
	SkinLangF(id, "SKIN_REMOVE_TITLE", " 移除 %s 的皮肤", szTitle, charsmax(szTitle), szName);
	new menu = menu_create(szTitle, "RemoveSkinHandler");
	if (g_Owned[target] && ArraySize(g_Owned[target]) > 0) {
		for (new i = 0; i < ArraySize(g_Owned[target]); i++) {
			new key[SKIN_KEY_MAX];
			ArrayGetString(g_Owned[target], i, key, charsmax(key));
			new idx = PoolIndexOf(key);
			if (idx != -1)
				SkinTeamShort(id, PoolTeamChar(idx), szTeamTag, charsmax(szTeamTag));
			else
				copy(szTeamTag, charsmax(szTeamTag), "?");
			format(szTxt, charsmax(szTxt), "[%s] %s", szTeamTag, key);
			menu_additem(menu, szTxt, key);
		}
	} else {
		SkinLang(id, "SKIN_VIEW_EMPTY", szTxt, charsmax(szTxt), "\d(该玩家没有皮肤)");
		menu_additem(menu, szTxt);
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

PoolTeamChar(idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	return row[pool_team];
}


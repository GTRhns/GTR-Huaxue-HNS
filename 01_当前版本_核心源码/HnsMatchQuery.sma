#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_optional_sql>
#include <hns_language>

#define DB_CFG_FILE  "mixsystem/hnsmatch-sql.cfg"
#define DEFAULT_HOST "127.0.0.1"
#define DEFAULT_USER "root"
#define DEFAULT_PASS "root"
#define DEFAULT_DB   "hns"

#define TABLE_PLAYERS "hns_players"
#define TABLE_PTS     "hns_pts"

enum _:db_e { db_host[48], db_user[32], db_pass[32], db_db[32] };

enum _:qtype_e {
	QT_PING = 1,
	QT_SELECT
};

enum _:query_data_e {
	q_pts,
	q_wins,
	q_loss,
	q_rank,
	q_source, // 0 none, 1 mysql, 2 cache
	bool:q_loaded
};

enum _:skill_info {
	skill_pts,
	skill_lvl[10]
};

new const g_eSkillData[][skill_info] = {
	{ 0,    "L-" },
	{ 650,  "L"  },
	{ 750,  "L+" },
	{ 850,  "M-" },
	{ 950,  "M"  },
	{ 1050, "M+" },
	{ 1150, "H-" },
	{ 1250, "H"  },
	{ 1350, "H+" },
	{ 1450, "P-" },
	{ 1550, "P"  },
	{ 1650, "P+" },
	{ 1750, "G-" },
	{ 1850, "G"  },
	{ 1950, "G+" }
};

new g_eDb[db_e];
new Handle:g_hSqlTuple;
new bool:g_bSqlReady;
new g_iSqlLastErr;
new g_szSqlLastErr[128];
new g_szSqlStatus[32];

new g_eQuery[MAX_PLAYERS + 1][query_data_e];
new g_eCache[MAX_PLAYERS + 1][query_data_e];

public plugin_natives() {
	hns_register_optional_sql();
}

public plugin_init() {
	register_plugin("Match: Query", "1.0.0", "OpenHNS");

	register_clcmd("hnsquery", "CmdQuery");
	register_clcmd("say /hnsquery", "CmdQuery");
	register_clcmd("say_team /hnsquery", "CmdQuery");
	register_clcmd("say /query", "CmdQuery");
	register_clcmd("say /查询", "CmdQuery");

	register_clcmd("mysqlmenu", "CmdMysqlMenu");
	register_clcmd("say /mysqlmenu", "CmdMysqlMenu");
	register_clcmd("say /mysql", "CmdMysqlMenu");
	register_menucmd(register_menuid("GTRMysqlMenu"), 1023, "MysqlMenuHandler");

	copy(g_szSqlStatus, charsmax(g_szSqlStatus), "init");
	SqlConnect(false);
}

public plugin_end() {
	SqlClose();
}

public client_disconnected(id) {
	arrayset(g_eQuery[id], 0, query_data_e);
	arrayset(g_eCache[id], 0, query_data_e);
}

public hns_pts_init_player(id, iPts, iWins, iLoss, iTop) {
	if (id < 1 || id > MaxClients)
		return;

	g_eCache[id][q_pts] = iPts;
	g_eCache[id][q_wins] = iWins;
	g_eCache[id][q_loss] = iLoss;
	g_eCache[id][q_rank] = iTop;
	g_eCache[id][q_source] = 2;
	g_eCache[id][q_loaded] = true;

	if (!g_eQuery[id][q_loaded]) {
		g_eQuery[id][q_pts] = iPts;
		g_eQuery[id][q_wins] = iWins;
		g_eQuery[id][q_loss] = iLoss;
		g_eQuery[id][q_rank] = iTop;
		g_eQuery[id][q_source] = 2;
		g_eQuery[id][q_loaded] = true;
	}
}

public CmdQuery(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	ApplyCacheIfEmpty(id);
	ShowQueryMenu(id);
	SqlSelect(id);
	return PLUGIN_HANDLED;
}

public CmdMysqlMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!isUserAdmin(id)) {
		client_print_color(id, print_team_red, "^4[HNS]^1 只有管理员可以打开 MySQL 管理菜单。");
		return PLUGIN_HANDLED;
	}

	ShowMysqlMenu(id);
	return PLUGIN_HANDLED;
}

ApplyCacheIfEmpty(id) {
	if (g_eQuery[id][q_loaded])
		return;

	if (g_eCache[id][q_loaded]) {
		g_eQuery[id][q_pts] = g_eCache[id][q_pts];
		g_eQuery[id][q_wins] = g_eCache[id][q_wins];
		g_eQuery[id][q_loss] = g_eCache[id][q_loss];
		g_eQuery[id][q_rank] = g_eCache[id][q_rank];
		g_eQuery[id][q_source] = 2;
		g_eQuery[id][q_loaded] = true;
		return;
	}

	g_eQuery[id][q_pts] = 1000;
	g_eQuery[id][q_wins] = 0;
	g_eQuery[id][q_loss] = 0;
	g_eQuery[id][q_rank] = 0;
	g_eQuery[id][q_source] = 0;
	g_eQuery[id][q_loaded] = false;
}

ShowQueryMenu(id) {
	new szName[MAX_NAME_LENGTH], szAuth[MAX_AUTHID_LENGTH];
	get_user_name(id, szName, charsmax(szName));
	get_user_authid(id, szAuth, charsmax(szAuth));

	new szSource[24];
	new szText[128];
	if (g_eQuery[id][q_source] == 1)
		copy(szSource, charsmax(szSource), g_bSqlReady ? "MySQL" : "MySQL?");
	else if (g_eQuery[id][q_source] == 2)
		HnsLang_Get(id, "QUERY_SOURCE_CACHE", szSource, charsmax(szSource));
	else
		HnsLang_Get(id, g_bSqlReady ? "QUERY_SOURCE_LOADING" : "QUERY_SOURCE_OFFLINE", szSource, charsmax(szSource));

	new iPts = g_eQuery[id][q_pts];
	new iWins = g_eQuery[id][q_wins];
	new iLoss = g_eQuery[id][q_loss];
	new iRank = g_eQuery[id][q_rank];
	new iMatches = iWins + iLoss;
	new szSkill[10];
	GetSkillName(iPts, szSkill, charsmax(szSkill));

	new szRate[16];
	if (iMatches > 0)
		formatex(szRate, charsmax(szRate), "%d%%", (iWins * 100) / iMatches);
	else
		copy(szRate, charsmax(szRate), "--");

	new szTitle[192];
	HnsLang_Get(id, "QUERY_TITLE", szText, charsmax(szText));
	new szPlayerLabel[32], szAuthLabel[32], szSourceLabel[32];
	HnsLang_Get(id, "QUERY_PLAYER", szPlayerLabel, charsmax(szPlayerLabel));
	HnsLang_Get(id, "QUERY_ACCOUNT", szAuthLabel, charsmax(szAuthLabel));
	HnsLang_Get(id, "QUERY_SOURCE", szSourceLabel, charsmax(szSourceLabel));
	formatex(szTitle, charsmax(szTitle),
		"\r>> \y%s \r<<^n\w%s: \y%s^n\w%s: \d%s^n\w%s: %s%s",
		szText, szPlayerLabel, szName, szAuthLabel, szAuth,
		szSourceLabel,
		g_eQuery[id][q_source] == 1 ? "\y" : "\d",
		szSource);

	new menu = menu_create(szTitle, "QueryMenuHandler");
	new szItem[96];

	HnsLang_Get(id, "QUERY_PTS", szText, charsmax(szText));
	formatex(szItem, charsmax(szItem), "\y%s            \r%d", szText, iPts);
	menu_additem(menu, szItem, "1");
	HnsLang_Get(id, "QUERY_MATCHES", szText, charsmax(szText));
	formatex(szItem, charsmax(szItem), "\y%s          \w%d", szText, iMatches);
	menu_additem(menu, szItem, "2");
	menu_addblank(menu, 0);

	new szWins[32], szLoss[32], szRateLabel[32];
	HnsLang_Get(id, "QUERY_WINS", szWins, charsmax(szWins));
	HnsLang_Get(id, "QUERY_LOSSES", szLoss, charsmax(szLoss));
	HnsLang_Get(id, "QUERY_WINRATE", szRateLabel, charsmax(szRateLabel));
	formatex(szItem, charsmax(szItem), "\y%s \w%d    \r%s \w%d    \d%s %s", szWins, iWins, szLoss, iLoss, szRateLabel, szRate);
	menu_additem(menu, szItem, "3");
	new szRank[32], szRanking[32];
	HnsLang_Get(id, "QUERY_RANK", szRank, charsmax(szRank));
	HnsLang_Get(id, "QUERY_RANKING", szRanking, charsmax(szRanking));
	if (iRank > 0)
		formatex(szItem, charsmax(szItem), "\y%s \r%s      \w%s \y#%d", szRank, szSkill, szRanking, iRank);
	else
		formatex(szItem, charsmax(szItem), "\y%s \r%s      \d%s --", szRank, szSkill, szRanking);
	menu_additem(menu, szItem, "4");
	menu_addblank(menu, 0);

	HnsLang_Get(id, "QUERY_REFRESH", szText, charsmax(szText));
	menu_additem(menu, szText, "5");
	menu_additem(menu, "\d----------------", "6");
	HnsLang_Get(id, "QUERY_BACK", szText, charsmax(szText));
	menu_additem(menu, szText, "7");

	HnsLang_Get(id, "MENU_EXIT", szText, charsmax(szText));
	StyleQueryMenu(menu, id, szText);
	menu_display(id, menu, 0);
}

public QueryMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szData[8], szName[64], iAccess, iCallback;
	menu_item_getinfo(menu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(menu);

	switch (str_to_num(szData)) {
		case 1, 2, 3, 4: {
			ShowQueryMenu(id);
		}
		case 5: {
			new szMessage[128];
			HnsLang_Get(id, "QUERY_REFRESHING", szMessage, charsmax(szMessage));
			client_print_color(id, print_team_blue, "^4[HNS]^1 %s", szMessage);
			SqlSelect(id);
			ShowQueryMenu(id);
		}
		case 6: {
			ShowQueryMenu(id);
		}
		case 7: {
			client_cmd(id, "say /gtr");
		}
	}
	return PLUGIN_HANDLED;
}

ShowMysqlMenu(id) {
	new szAuth[MAX_AUTHID_LENGTH], szStatus[32], szTitle[256], szItem[160];
	new szText[128], szStatusLabel[32], szHostLabel[32], szDbLabel[32], szUserLabel[32], szSteamLabel[32];
	get_user_authid(id, szAuth, charsmax(szAuth));
	SqlStatusText(szStatus, charsmax(szStatus));
	HnsLang_Get(id, "MYSQL_TITLE", szText, charsmax(szText));
	HnsLang_Get(id, "MYSQL_STATUS", szStatusLabel, charsmax(szStatusLabel));
	HnsLang_Get(id, "MYSQL_HOST", szHostLabel, charsmax(szHostLabel));
	HnsLang_Get(id, "MYSQL_DATABASE", szDbLabel, charsmax(szDbLabel));
	HnsLang_Get(id, "MYSQL_USER", szUserLabel, charsmax(szUserLabel));
	HnsLang_Get(id, "MYSQL_STEAM", szSteamLabel, charsmax(szSteamLabel));

	formatex(szTitle, charsmax(szTitle),
		"\y%s^n\w%s: %s%s^n\w%s: \y%s  \w%s: \y%s^n\w%s: \y%s^n\w%s: \d%s",
		szText, szStatusLabel, g_bSqlReady ? "\y" : "\r", szStatus,
		szHostLabel, g_eDb[db_host], szDbLabel, g_eDb[db_db],
		szUserLabel, g_eDb[db_user], szSteamLabel, szAuth);

	new szMenu[768], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "%s^n", szTitle);
	HnsLang_Get(id, "MYSQL_TEST", szText, charsmax(szText));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. %s^n", szText);
	HnsLang_Get(id, "MYSQL_RECONNECT", szText, charsmax(szText));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. %s^n^n", szText);
	HnsLang_Get(id, "MYSQL_QUERY", szText, charsmax(szText));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. %s^n", szText);
	HnsLang_Get(id, "MYSQL_LAST_ERROR", szText, charsmax(szText));
	if (g_szSqlLastErr[0])
		formatex(szItem, charsmax(szItem), "\r%s(%d): %s", szText, g_iSqlLastErr, g_szSqlLastErr);
	else
		HnsLang_Get(id, "MYSQL_LAST_ERROR_NONE", szItem, charsmax(szItem));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. %s^n^n", szItem);
	HnsLang_Get(id, "MYSQL_BACK", szText, charsmax(szText));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. %s^n^n", szText);
	HnsLang_Get(id, "MENU_EXIT", szText, charsmax(szText));
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. %s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_0, szMenu, -1, "GTRMysqlMenu");
}

public MysqlMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;

	if (!isUserAdmin(id))
		return PLUGIN_HANDLED;

	switch (key) {
		case 0: {
			SqlPing(id);
		}
		case 1: {
			SqlConnect(true);
			client_print_color(id, print_team_blue, "^4[HNS]^1 已重新读取配置并重连  主机: ^3%s^1  库: ^3%s", g_eDb[db_host], g_eDb[db_db]);
			ShowMysqlMenu(id);
		}
		case 2: {
			CmdQuery(id);
		}
		case 3: {
			ShowMysqlMenu(id);
		}
		case 4: {
			ShowQueryMenu(id);
		}
	}
	return PLUGIN_HANDLED;
}

StyleQueryMenu(menu, id, const szExit[]) {
	menu_setprop(menu, MPROP_PERPAGE, 7);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	new szBack[32], szNext[32];
	HnsLang_Get(id, "MENU_BACK", szBack, charsmax(szBack));
	HnsLang_Get(id, "MENU_NEXT", szNext, charsmax(szNext));
	menu_setprop(menu, MPROP_BACKNAME, szBack);
	menu_setprop(menu, MPROP_NEXTNAME, szNext);
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\r");
	menu_setprop(menu, MPROP_SHOWPAGE, true);
}

SqlStatusText(dest[], len) {
	if (g_hSqlTuple == Empty_Handle)
		copy(dest, len, "未配置");
	else if (equal(g_szSqlStatus, "ok") && g_bSqlReady)
		copy(dest, len, "已连接");
	else if (equal(g_szSqlStatus, "query"))
		copy(dest, len, "查询失败");
	else if (equal(g_szSqlStatus, "reconnect"))
		copy(dest, len, "重连中");
	else if (equal(g_szSqlStatus, "ping"))
		copy(dest, len, "测试中");
	else if (equal(g_szSqlStatus, "none"))
		copy(dest, len, "未配置");
	else
		copy(dest, len, g_szSqlStatus[0] ? g_szSqlStatus : "未知");
}

bool:LoadDbCfg() {
	copy(g_eDb[db_host], charsmax(g_eDb[db_host]), DEFAULT_HOST);
	copy(g_eDb[db_user], charsmax(g_eDb[db_user]), DEFAULT_USER);
	copy(g_eDb[db_pass], charsmax(g_eDb[db_pass]), DEFAULT_PASS);
	copy(g_eDb[db_db], charsmax(g_eDb[db_db]), DEFAULT_DB);

	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, DB_CFG_FILE);

	if (!file_exists(szCfg))
		return false;

	new file = fopen(szCfg, "rt");
	if (!file)
		return false;

	new szLine[256], szKey[32], szVal[64];
	while (!feof(file)) {
		fgets(file, szLine, charsmax(szLine));
		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue;

		parse(szLine, szKey, charsmax(szKey), szVal, charsmax(szVal));
		trim(szKey);
		trim(szVal);

		new iLen = strlen(szVal);
		if (iLen >= 2 && szVal[0] == '"' && szVal[iLen - 1] == '"') {
			szVal[iLen - 1] = EOS;
			for (new j = 0; szVal[j] && j < iLen; j++)
				szVal[j] = szVal[j + 1];
		}

		if (equali(szKey, "hns_host"))
			copy(g_eDb[db_host], charsmax(g_eDb[db_host]), szVal);
		else if (equali(szKey, "hns_user"))
			copy(g_eDb[db_user], charsmax(g_eDb[db_user]), szVal);
		else if (equali(szKey, "hns_pass"))
			copy(g_eDb[db_pass], charsmax(g_eDb[db_pass]), szVal);
		else if (equali(szKey, "hns_db"))
			copy(g_eDb[db_db], charsmax(g_eDb[db_db]), szVal);
	}
	fclose(file);
	return true;
}

SqlClose() {
	if (g_hSqlTuple != Empty_Handle) {
		SQL_FreeHandle(g_hSqlTuple);
		g_hSqlTuple = Empty_Handle;
	}
}

SqlConnect(bool:bReload) {
	SqlClose();
	LoadDbCfg();

	g_hSqlTuple = SQL_MakeDbTuple(g_eDb[db_host], g_eDb[db_user], g_eDb[db_pass], g_eDb[db_db]);
	if (g_hSqlTuple == Empty_Handle) {
		g_bSqlReady = false;
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		return;
	}

	SQL_SetCharset(g_hSqlTuple, "utf8");
	g_bSqlReady = false;
	copy(g_szSqlStatus, charsmax(g_szSqlStatus), bReload ? "reconnect" : "init");
	SqlPing(0);
}

SqlPing(id) {
	if (g_hSqlTuple == Empty_Handle) {
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		if (id && is_user_connected(id)) {
			client_print_color(id, print_team_red, "^4[HNS]^1 未配置 MySQL。");
			ShowMysqlMenu(id);
		}
		return;
	}

	copy(g_szSqlStatus, charsmax(g_szSqlStatus), "ping");
	new cData[2];
	cData[0] = QT_PING;
	cData[1] = id;
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", "SELECT 1", cData, sizeof(cData));
	if (id && is_user_connected(id))
		client_print_color(id, print_team_blue, "^4[HNS]^1 正在测试 MySQL 连接...");
}

SqlSelect(id) {
	if (!is_user_connected(id))
		return;

	if (g_hSqlTuple == Empty_Handle) {
		ApplyCacheIfEmpty(id);
		return;
	}

	new szAuth[MAX_AUTHID_LENGTH], szEsc[MAX_AUTHID_LENGTH * 2];
	get_user_authid(id, szAuth, charsmax(szAuth));
	EscapeSql(szAuth, szEsc, charsmax(szEsc));

	new szQuery[512];
	formatex(szQuery, charsmax(szQuery),
		"SELECT COALESCE(p.pts,1000), COALESCE(p.wins,0), COALESCE(p.loss,0), \
		(SELECT COUNT(*) FROM `%s` WHERE `pts` >= COALESCE(p.pts,1000)) \
		FROM `%s` pl LEFT JOIN `%s` p ON p.id = pl.id \
		WHERE pl.steamid = '%s' LIMIT 1",
		TABLE_PTS, TABLE_PLAYERS, TABLE_PTS, szEsc);

	new cData[2];
	cData[0] = QT_SELECT;
	cData[1] = id;
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
	new iType = cData[0];
	new id = cData[1];

	if (iFailState != TQUERY_SUCCESS) {
		g_bSqlReady = false;
		g_iSqlLastErr = iErrnum;
		copy(g_szSqlLastErr, charsmax(g_szSqlLastErr), szError);
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "query");
		log_amx("[HNS Query] SQL Error #%d - %s", iErrnum, szError);

		if (id && is_user_connected(id)) {
			ApplyCacheIfEmpty(id);
			if (iType == QT_PING)
				ShowMysqlMenu(id);
			else
				ShowQueryMenu(id);
		}
		return;
	}

	g_bSqlReady = true;
	g_iSqlLastErr = 0;
	g_szSqlLastErr[0] = EOS;
	copy(g_szSqlStatus, charsmax(g_szSqlStatus), "ok");

	if (iType == QT_PING) {
		if (id && is_user_connected(id)) {
			client_print_color(id, print_team_blue, "^4[HNS]^1 MySQL 连接正常  ^3%s^1 / ^3%s", g_eDb[db_host], g_eDb[db_db]);
			ShowMysqlMenu(id);
		}
		return;
	}

	if (iType != QT_SELECT || !id || !is_user_connected(id))
		return;

	if (SQL_NumResults(hQuery)) {
		g_eQuery[id][q_pts] = SQL_ReadResult(hQuery, 0);
		g_eQuery[id][q_wins] = SQL_ReadResult(hQuery, 1);
		g_eQuery[id][q_loss] = SQL_ReadResult(hQuery, 2);
		g_eQuery[id][q_rank] = SQL_ReadResult(hQuery, 3);
		g_eQuery[id][q_source] = 1;
		g_eQuery[id][q_loaded] = true;

		g_eCache[id][q_pts] = g_eQuery[id][q_pts];
		g_eCache[id][q_wins] = g_eQuery[id][q_wins];
		g_eCache[id][q_loss] = g_eQuery[id][q_loss];
		g_eCache[id][q_rank] = g_eQuery[id][q_rank];
		g_eCache[id][q_source] = 1;
		g_eCache[id][q_loaded] = true;
	} else {
		ApplyCacheIfEmpty(id);
		if (!g_eQuery[id][q_loaded]) {
			g_eQuery[id][q_pts] = 1000;
			g_eQuery[id][q_wins] = 0;
			g_eQuery[id][q_loss] = 0;
			g_eQuery[id][q_rank] = 0;
			g_eQuery[id][q_source] = 1;
			g_eQuery[id][q_loaded] = true;
		}
	}

	ShowQueryMenu(id);
}

GetSkillName(iPts, dest[], len) {
	copy(dest, len, "L-");
	for (new i; i < sizeof(g_eSkillData); i++) {
		if (iPts >= g_eSkillData[i][skill_pts])
			copy(dest, len, g_eSkillData[i][skill_lvl]);
	}
}

EscapeSql(const src[], dest[], len) {
	copy(dest, len, src);
	replace_all(dest, len, "\\", "\\\\");
	replace_all(dest, len, "'", "\\'");
}

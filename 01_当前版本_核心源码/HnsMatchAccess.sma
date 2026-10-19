#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <hns_matchsystem>

#define ACCESS_CFG "mixsystem/hnsmatch-sql.cfg"

enum {
	Q_LOOKUP = 1,
	Q_GRANT,
	Q_REVOKE
};

new Handle:g_hTuple = Empty_Handle;
new g_szHost[64] = "127.0.0.1";
new g_szUser[32] = "root";
new g_szPass[64];
new g_szDb[32] = "hns";
new bool:g_bApplied[MAX_PLAYERS + 1];
new g_iDays[MAX_PLAYERS + 1];
new bool:g_bRevoke[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("Match: Access", "1.0.0", "GTR");

	register_clcmd("vipmenu", "CmdVipMenu");
	register_clcmd("say /vipmenu", "CmdVipMenu");
	register_clcmd("say_team /vipmenu", "CmdVipMenu");
	register_clcmd("say /vip", "CmdVipMenu");
	register_clcmd("say_team /vip", "CmdVipMenu");
	register_menucmd(register_menuid("HnsVipDur"), 1023, "VipDurHandler");

	set_task(20.0, "AccessSweep", .flags = "b");
}

public plugin_cfg() {
	AccessConnect();
}

public plugin_end() {
	if (g_hTuple != Empty_Handle)
		SQL_FreeHandle(g_hTuple);
}

public client_authorized(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	AccessLookup(id);
}

public client_putinserver(id) {
	if (is_user_bot(id) || is_user_hltv(id))
		return;
	g_bApplied[id] = false;
	set_task(2.0, "AccessLookupTask", id);
}

public client_disconnected(id) {
	g_bApplied[id] = false;
	g_bRevoke[id] = false;
	remove_task(id);
}

public AccessLookupTask(id) {
	if (!is_user_connected(id))
		return;
	AccessLookup(id);
}

public AccessSweep() {
	new players[MAX_PLAYERS], count;
	get_players(players, count, "ch");
	for (new i; i < count; i++)
		AccessLookup(players[i]);
}

public CmdVipMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	if (!isUserAdmin(id)) {
		client_print_color(id, print_team_red, "^4[HNS]^1 只有管理员可以发放或收回 VIP。");
		return PLUGIN_HANDLED;
	}
	ShowVipMenu(id);
	return PLUGIN_HANDLED;
}

ShowVipMenu(id) {
	new szMenu[384], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r发放 VIP^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w7天^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w一个月^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w一年^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \y永久^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \r收回^n^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w退出");
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_0, szMenu, -1, "HnsVipDur");
}

public VipDurHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;
	if (!isUserAdmin(id))
		return PLUGIN_HANDLED;

	switch (key) {
		case 0: { g_bRevoke[id] = false; g_iDays[id] = 7; }
		case 1: { g_bRevoke[id] = false; g_iDays[id] = 30; }
		case 2: { g_bRevoke[id] = false; g_iDays[id] = 365; }
		case 3: { g_bRevoke[id] = false; g_iDays[id] = 0; }
		case 4: { g_bRevoke[id] = true; g_iDays[id] = 0; }
		default: return PLUGIN_HANDLED;
	}
	ShowVipPlayers(id);
	return PLUGIN_HANDLED;
}

ShowVipPlayers(id) {
	new menu = menu_create(g_bRevoke[id] ? "收回 VIP" : "选择玩家", "VipPlayerHandler");
	new players[MAX_PLAYERS], count, added;
	get_players(players, count, "ch");
	for (new i; i < count; i++) {
		new target = players[i];
		new auth[MAX_AUTHID_LENGTH];
		get_user_authid(target, auth, charsmax(auth));
		if (!ValidSteam(auth))
			continue;
		new name[MAX_NAME_LENGTH], info[8];
		get_user_name(target, name, charsmax(name));
		num_to_str(get_user_userid(target), info, charsmax(info));
		menu_additem(menu, name, info);
		added++;
	}
	if (!added) {
		menu_destroy(menu);
		client_print_color(id, print_team_red, "^4[HNS]^1 没有可操作的 Steam 玩家。");
		ShowVipMenu(id);
		return;
	}
	menu_setprop(menu, MPROP_EXITNAME, "返回");
	menu_display(id, menu);
}

public VipPlayerHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (is_user_connected(id))
			ShowVipMenu(id);
		return PLUGIN_HANDLED;
	}
	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);
	if (!is_user_connected(id) || !isUserAdmin(id))
		return PLUGIN_HANDLED;

	new target = find_player("k", str_to_num(info));
	if (!target || !is_user_connected(target)) {
		client_print_color(id, print_team_red, "^4[HNS]^1 玩家已经离开。");
		return PLUGIN_HANDLED;
	}
	if (g_bRevoke[id])
		AccessRevoke(id, target);
	else
		AccessGrant(id, target, g_iDays[id]);
	return PLUGIN_HANDLED;
}

AccessConnect() {
	LoadCfg();
	if (g_hTuple != Empty_Handle)
		SQL_FreeHandle(g_hTuple);
	g_hTuple = SQL_MakeDbTuple(g_szHost, g_szUser, g_szPass, g_szDb);
	SQL_SetCharset(g_hTuple, "utf8");

	new szErr[160], iErr;
	new Handle:conn = SQL_Connect(g_hTuple, iErr, szErr, charsmax(szErr));
	if (conn == Empty_Handle) {
		log_amx("[Access] SQL 连接失败 (%d): %s", iErr, szErr);
		return;
	}
	SqlExec(conn, "CREATE TABLE IF NOT EXISTS hns_access (steamid VARCHAR(64) NOT NULL, authid VARCHAR(64) NOT NULL DEFAULT '', role VARCHAR(16) NOT NULL DEFAULT 'vip', expire_at INT NOT NULL DEFAULT 0, revoked TINYINT NOT NULL DEFAULT 0, granted_by VARCHAR(64) NOT NULL DEFAULT '', updated_at INT NOT NULL DEFAULT 0, PRIMARY KEY (steamid, role)) ENGINE=InnoDB DEFAULT CHARSET=utf8");
	SQL_FreeHandle(conn);
	log_amx("[Access] SQL ready %s / %s", g_szHost, g_szDb);
}

SqlExec(Handle:conn, const szQuery[]) {
	new Handle:query = SQL_PrepareQuery(conn, "%s", szQuery);
	if (query == Empty_Handle)
		return;
	if (!SQL_Execute(query)) {
		new szErr[160];
		SQL_QueryError(query, szErr, charsmax(szErr));
		log_amx("[Access] SQL 执行失败: %s", szErr);
	}
	SQL_FreeHandle(query);
}

LoadCfg() {
	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, ACCESS_CFG);
	if (!file_exists(szCfg))
		return;
	new file = fopen(szCfg, "rt");
	if (!file)
		return;
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
			for (new j; szVal[j] && j < iLen; j++)
				szVal[j] = szVal[j + 1];
		}
		if (equali(szKey, "hns_host"))
			copy(g_szHost, charsmax(g_szHost), szVal);
		else if (equali(szKey, "hns_user"))
			copy(g_szUser, charsmax(g_szUser), szVal);
		else if (equali(szKey, "hns_pass"))
			copy(g_szPass, charsmax(g_szPass), szVal);
		else if (equali(szKey, "hns_db"))
			copy(g_szDb, charsmax(g_szDb), szVal);
	}
	fclose(file);
}

bool:ValidSteam(const szAuth[]) {
	if (strlen(szAuth) < 8)
		return false;
	if (containi(szAuth, "PENDING") != -1 || containi(szAuth, "LAN") != -1)
		return false;
	if (contain(szAuth, ":") == -1)
		return false;
	return equal(szAuth, "STEAM_", 6) || equal(szAuth, "VALVE_", 6);
}

EscapeSql(const src[], dest[], len) {
	new j;
	for (new i; src[i] && j < len; i++) {
		if (src[i] == 39 || src[i] == 34 || src[i] == 37 || src[i] == 92)
			continue;
		dest[j++] = src[i];
	}
	dest[j] = EOS;
}

VipBits() {
	new bits = hns_get_flag_fullwatcher();
	if (!bits)
		bits = read_flags("d");
	return bits;
}

AccessLookup(id) {
	if (g_hTuple == Empty_Handle || !is_user_connected(id))
		return;
	new szAuth[MAX_AUTHID_LENGTH], szSafe[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));
	if (!ValidSteam(szAuth))
		return;
	EscapeSql(szAuth, szSafe, charsmax(szSafe));
	new szQuery[320];
	formatex(szQuery, charsmax(szQuery), "SELECT expire_at, revoked FROM hns_access WHERE role='vip' AND (steamid='%s' OR authid='%s' OR authid='STEAM:%s') ORDER BY revoked ASC, updated_at DESC LIMIT 1", szSafe, szSafe, szSafe);
	new data[3];
	data[0] = Q_LOOKUP;
	data[1] = id;
	data[2] = get_user_userid(id);
	SQL_ThreadQuery(g_hTuple, "AccessSql", szQuery, data, sizeof data);
}

AccessGrant(admin, target, days) {
	if (g_hTuple == Empty_Handle) {
		client_print_color(admin, print_team_red, "^4[HNS]^1 数据库还没连上，不能发放 VIP。");
		return;
	}
	if (days != 0 && days != 7 && days != 30 && days != 365)
		return;
	new szAuth[MAX_AUTHID_LENGTH], szSafe[MAX_AUTHID_LENGTH], szBy[MAX_AUTHID_LENGTH], szBySafe[MAX_AUTHID_LENGTH];
	get_user_authid(target, szAuth, charsmax(szAuth));
	get_user_authid(admin, szBy, charsmax(szBy));
	if (!ValidSteam(szAuth)) {
		client_print_color(admin, print_team_red, "^4[HNS]^1 这个玩家还没有有效的 SteamID。");
		return;
	}
	EscapeSql(szAuth, szSafe, charsmax(szSafe));
	EscapeSql(szBy, szBySafe, charsmax(szBySafe));
	new iExpire = days ? get_systime() + days * 86400 : 0;
	new szQuery[512];
	formatex(szQuery, charsmax(szQuery), "INSERT INTO hns_access (steamid, authid, role, expire_at, revoked, granted_by, updated_at) VALUES ('%s', 'STEAM:%s', 'vip', %d, 0, '%s', %d) ON DUPLICATE KEY UPDATE authid=VALUES(authid), expire_at=VALUES(expire_at), revoked=0, granted_by=VALUES(granted_by), updated_at=VALUES(updated_at)", szSafe, szSafe, iExpire, szBySafe, get_systime());
	new data[5];
	data[0] = Q_GRANT;
	data[1] = admin;
	data[2] = target;
	data[3] = days;
	data[4] = get_user_userid(target);
	SQL_ThreadQuery(g_hTuple, "AccessSql", szQuery, data, sizeof data);
}

AccessRevoke(admin, target) {
	if (g_hTuple == Empty_Handle) {
		client_print_color(admin, print_team_red, "^4[HNS]^1 数据库还没连上，不能收回 VIP。");
		return;
	}
	new szAuth[MAX_AUTHID_LENGTH], szSafe[MAX_AUTHID_LENGTH];
	get_user_authid(target, szAuth, charsmax(szAuth));
	if (!ValidSteam(szAuth)) {
		client_print_color(admin, print_team_red, "^4[HNS]^1 这个玩家还没有有效的 SteamID。");
		return;
	}
	EscapeSql(szAuth, szSafe, charsmax(szSafe));
	new szQuery[384];
	formatex(szQuery, charsmax(szQuery), "UPDATE hns_access SET revoked=1, updated_at=%d WHERE role='vip' AND (steamid='%s' OR authid='%s' OR authid='STEAM:%s')", get_systime(), szSafe, szSafe, szSafe);
	new data[5];
	data[0] = Q_REVOKE;
	data[1] = admin;
	data[2] = target;
	data[3] = 0;
	data[4] = get_user_userid(target);
	SQL_ThreadQuery(g_hTuple, "AccessSql", szQuery, data, sizeof data);
}

public AccessSql(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (failstate != TQUERY_SUCCESS) {
		log_amx("[Access] SQL 失败 (%d): %s", errnum, error);
		if (data[0] != Q_LOOKUP && is_user_connected(data[1]))
			client_print_color(data[1], print_team_red, "^4[HNS]^1 VIP 写入失败，看服务器日志。");
		return PLUGIN_HANDLED;
	}
	switch (data[0]) {
		case Q_LOOKUP: ApplyLookup(query, data[1], data[2]);
		case Q_GRANT: FinishGrant(data[1], data[2], data[3], data[4]);
		case Q_REVOKE: FinishRevoke(data[1], data[2], data[4]);
	}
	return PLUGIN_HANDLED;
}

ApplyLookup(Handle:query, id, userid) {
	if (!is_user_connected(id) || get_user_userid(id) != userid)
		return;
	new bool:bKeep;
	if (SQL_NumResults(query) > 0) {
		new iExpire = SQL_ReadResult(query, 0);
		new iRevoked = SQL_ReadResult(query, 1);
		bKeep = !iRevoked && (iExpire == 0 || iExpire > get_systime());
	}
	new bits = VipBits();
	if (bKeep) {
		if (!(get_user_flags(id) & bits)) {
			set_user_flags(id, get_user_flags(id) | bits);
			g_bApplied[id] = true;
		}
	} else if (g_bApplied[id]) {
		set_user_flags(id, get_user_flags(id) & ~bits);
		g_bApplied[id] = false;
	}
}

FinishGrant(admin, target, days, userid) {
	new szLabel[16];
	if (days == 7)
		copy(szLabel, charsmax(szLabel), "7天");
	else if (days == 30)
		copy(szLabel, charsmax(szLabel), "一个月");
	else if (days == 365)
		copy(szLabel, charsmax(szLabel), "一年");
	else
		copy(szLabel, charsmax(szLabel), "永久");

	if (is_user_connected(target) && get_user_userid(target) == userid) {
		new bits = VipBits();
		if (!(get_user_flags(target) & bits)) {
			set_user_flags(target, get_user_flags(target) | bits);
			g_bApplied[target] = true;
		}
		new szName[MAX_NAME_LENGTH];
		get_user_name(target, szName, charsmax(szName));
		client_print_color(target, print_team_blue, "^4[HNS]^1 你获得了 VIP（%s）。不能使用皮肤管理、服务器封禁，也不能发放 VIP。", szLabel);
		if (is_user_connected(admin))
			client_print_color(admin, print_team_blue, "^4[HNS]^1 已给 ^3%s^1 发放 VIP（%s）。", szName, szLabel);
	} else if (is_user_connected(admin)) {
		client_print_color(admin, print_team_blue, "^4[HNS]^1 VIP（%s）已写入，玩家重进后生效。", szLabel);
	}
}

FinishRevoke(admin, target, userid) {
	if (is_user_connected(target) && get_user_userid(target) == userid && g_bApplied[target]) {
		set_user_flags(target, get_user_flags(target) & ~VipBits());
		g_bApplied[target] = false;
		client_print_color(target, print_team_red, "^4[HNS]^1 你的 VIP 已被收回。");
	}
	if (is_user_connected(admin))
		client_print_color(admin, print_team_blue, "^4[HNS]^1 已收回 VIP。");
}

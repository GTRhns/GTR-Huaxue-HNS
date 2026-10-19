#include <amxmodx>
#include <reapi>
#include <sqlx>

new g_szTablePlayers[] = "hns_players";
new g_szTableGc[] = "hns_gc";

#define SQL_CREATE_TABLE \
"CREATE TABLE IF NOT EXISTS `%s` \
( \
	`id`		INT(11) NOT NULL auto_increment PRIMARY KEY, \
	`name`		VARCHAR(32) NULL DEFAULT NULL, \
	`steamid`	VARCHAR(24) NULL DEFAULT NULL, \
	`ip`		VARCHAR(22) NULL DEFAULT NULL, \
	`playtime`		INT NOT NULL DEFAULT 1, \
	`lastconnect`	INT NOT NULL DEFAULT 0 \
);"

// 赞助局 ICGB 金币表
#define SQL_CREATE_GC \
"CREATE TABLE IF NOT EXISTS `%s` \
( \
	`id`		INT(11) NOT NULL auto_increment PRIMARY KEY, \
	`steamid`	VARCHAR(24) NULL DEFAULT NULL, \
	`gc`		INT NOT NULL DEFAULT 0, \
	UNIQUE KEY `steamid` (`steamid`) \
);"

#define SQL_SELECT_GC \
"SELECT `gc` FROM \
	`%s` \
WHERE \
	`steamid` = '%s'"

#define SQL_SET_GC \
"INSERT INTO `%s` ( \
	steamid, \
	gc \
) VALUES ( \
	'%s', \
	%d \
) ON DUPLICATE KEY UPDATE \
	`gc` = VALUES(`gc`)"

// 进服时还没读到余额, 只把这段时间攒下的点数加到原余额上, 不能整段覆盖
#define SQL_ADD_GC \
"INSERT INTO `%s` ( \
	steamid, \
	gc \
) VALUES ( \
	'%s', \
	%d \
) ON DUPLICATE KEY UPDATE \
	`gc` = `gc` + %d"

#define SQL_CREATE_DATA \
"INSERT INTO `%s` ( \
	name, \
	steamid, \
	ip \
) VALUES ( \
	'%s', \
	'%s', \
	'%s' \
)"

#define SQL_SELECT_DATA \
"SELECT * FROM \
	`%s` \
WHERE \
	`steamid` = '%s'"

#define SQL_UPDATE_NAME \
"UPDATE `%s` SET \
	`name` = '%s' \
WHERE \
	`steamid` = '%s'"

#define SQL_UPDATE_IP \
"UPDATE `%s` SET \
	`ip` = '%s' \
WHERE \
	`steamid` = '%s'"

#define SQL_SET_PLAYTIME \
"UPDATE `%s` SET \
	`playtime` = `playtime` + %d \
WHERE \
	`steamid` = '%s'"

#define SQL_SET_LASTCONNECT \
"UPDATE `%s` SET \
	`lastconnect` = '%s' \
WHERE \
	`steamid` = '%s'"

enum _:CVARS {
	HOST[48],
	USER[32],
	PASS[32],
	DB[32]
};

new g_eCvars[CVARS];

enum _:SQL {
	SQL_TABLE,
	SQL_SELECT,
	SQL_INSERT,
	SQL_NAME,
	SQL_IP,
	SQL_SAVE,
	SQL_SAVECON,
	SQL_GC_SELECT,
	SQL_GC_INSERT
};

new Handle:g_hSqlTuple;

// SQL 连接状态: 首个查询成功后才置 true
// (未连上时 hns_gc_available 返回 0, 接口自动回退本地 vault)
new bool:g_bSqlReady;

new g_iPlayerID[MAX_PLAYERS + 1];

// 赞助局 ICGB 缓存。没读完之前不能把缓存写回数据库, 否则会把真实余额盖成 0。
new g_iGcCache[MAX_PLAYERS + 1];
new bool:g_bGcLoaded[MAX_PLAYERS + 1];
new g_iGcPending[MAX_PLAYERS + 1];
new g_iGcGen[MAX_PLAYERS + 1];
new g_iGcRetry[MAX_PLAYERS + 1];
new bool:g_bGcLoading[MAX_PLAYERS + 1];
new g_szGcAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];

#define TASK_GC_LOAD 24000
#define GC_LOAD_RETRY_MAX 40

new g_hSqlForward;
new g_hAuthorizedForward;

public plugin_init() {
	register_plugin("Match: Sql", "1.1.1", "OpenHNS"); // Garey

	new pCvar;
	pCvar = create_cvar("hns_host", "127.0.0.1", FCVAR_PROTECTED, "Host");
	bind_pcvar_string(pCvar, g_eCvars[HOST], charsmax(g_eCvars[HOST]));

	pCvar = create_cvar("hns_user", "root", FCVAR_PROTECTED, "User");
	bind_pcvar_string(pCvar, g_eCvars[USER], charsmax(g_eCvars[USER]));

	pCvar = create_cvar("hns_pass", "root", FCVAR_PROTECTED, "Password");
	bind_pcvar_string(pCvar, g_eCvars[PASS], charsmax(g_eCvars[PASS]));

	pCvar = create_cvar("hns_db", "hns", FCVAR_PROTECTED, "db");
	bind_pcvar_string(pCvar, g_eCvars[DB], charsmax(g_eCvars[DB]));

	new szPath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));

	server_cmd("exec %s/mixsystem/hnsmatch-sql.cfg", szPath);
	server_exec();

	g_hSqlForward = CreateMultiForward("hns_sql_connection", ET_CONTINUE, FP_CELL);
	g_hAuthorizedForward = CreateMultiForward("hns_sql_player_authorized", ET_CONTINUE, FP_CELL);

	g_hSqlTuple = SQL_MakeDbTuple(g_eCvars[HOST], g_eCvars[USER], g_eCvars[PASS], g_eCvars[DB]);
	SQL_SetCharset(g_hSqlTuple, "utf-8");
	ExecuteForward(g_hSqlForward, _, g_hSqlTuple);

	new szQuery[512];
	new cData[1] = SQL_TABLE;
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_TABLE, g_szTablePlayers);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	// 赞助局 ICGB 表
	cData[0] = SQL_TABLE;
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_GC, g_szTableGc);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoName, "rgSetClientUserInfoName", true);
}

public plugin_natives() {
	// 必须在 plugin_natives() 注册: AMXX 在"插件加载时"就校验 #pragma reqlib,
	// 早于 plugin_init(), 放到 plugin_init() 会导致依赖 hns_gc_sql 的插件 bad load。
	register_library("hns_gc_sql"); // 供 hns_gc.inc 的 library_exists 检测
	register_library("hns_match_sql"); // 供 Pts/Ownage/Bans 检测 SQL 是否已加载

	register_native("hns_sql_get_table_name", "native_sql_get_table_name");
	register_native("hns_sql_get_player_id", "native_sql_get_player_id");

	// 赞助局 ICGB 接口 (SQL 提供方)
	register_native("hns_gc_sql_available", "native_gc_sql_available");
	register_native("hns_gc_sql_get", "native_gc_sql_get");
	register_native("hns_gc_sql_set", "native_gc_sql_set");
	register_native("hns_gc_sql_loaded", "native_gc_sql_loaded");
}

stock bool:IsPlayerIndex(id) {
	return (id >= 1 && id <= MAX_PLAYERS);
}

stock bool:IsValidPlayer(id) {
	return (IsPlayerIndex(id) && is_user_connected(id) && !is_user_hltv(id));
}

public native_gc_sql_available(amxx, params) {
	return g_bSqlReady;
}

public native_gc_sql_get(amxx, params) {
	new id = get_param(1);
	if (!IsPlayerIndex(id))
		return 0;
	// 库还没回来时只返回这段时间暂存的加减, 不能把 0 当成真实余额
	if (!g_bGcLoaded[id])
		return g_iGcPending[id];
	return g_iGcCache[id];
}

public native_gc_sql_loaded(amxx, params) {
	new id = get_param(1);
	if (!IsPlayerIndex(id))
		return 0;
	return g_bGcLoaded[id];
}

public native_gc_sql_set(amxx, params) {
	new iPlayer = get_param(1);
	new iNewAmount = get_param(2);
	if (!IsPlayerIndex(iPlayer))
		return 0;

	if (iNewAmount < 0)
		iNewAmount = 0;

	// 调用方都是先 get 再 set。没读完时 get 只有暂存值, 这里继续暂存, 等 SELECT 回来再加到原余额上。
	if (!g_bGcLoaded[iPlayer]) {
		g_iGcPending[iPlayer] = iNewAmount;
		return 1;
	}

	g_iGcCache[iPlayer] = iNewAmount;

	if (g_bSqlReady && is_user_connected(iPlayer)) {
		new szAuthId[MAX_AUTHID_LENGTH];
		get_user_authid(iPlayer, szAuthId, charsmax(szAuthId));
		if (GcAuthUsable(szAuthId))
			GC_Set(iPlayer, iNewAmount);
	}
	return 1;
}

public native_sql_get_table_name(amxx, params) {
	enum { table_name = 1, len };
	set_string(table_name, g_szTablePlayers, get_param(len));
}

public native_sql_get_player_id(amxx, params) {
	new id = get_param(1);
	if (!IsPlayerIndex(id))
		return 0;
	return g_iPlayerID[id];
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
	if (iFailState != TQUERY_SUCCESS) {
		log_amx("SQL Error #%d - %s", iErrnum, szError);
		if (iSize >= 3 && cData[0] == SQL_GC_SELECT) {
			new id = cData[1];
			if (IsPlayerIndex(id) && cData[2] == g_iGcGen[id]) {
				g_bGcLoading[id] = false;
				ScheduleGcLoad(id);
			}
		}
		return PLUGIN_HANDLED;
	}

	g_bSqlReady = true;
	if (iSize < 1)
		return PLUGIN_HANDLED;

	switch (cData[0]) {
		case SQL_SELECT: {
			if (iSize < 2)
				return PLUGIN_HANDLED;

			new id = cData[1];
			if (!IsValidPlayer(id))
				return PLUGIN_HANDLED;

			if (SQL_NumResults(hQuery)) {
				new index_id = SQL_FieldNameToNum(hQuery, "id");
				new index_name = SQL_FieldNameToNum(hQuery, "name");
				new index_ip = SQL_FieldNameToNum(hQuery, "ip");
				if (index_id < 0)
					return PLUGIN_HANDLED;

				g_iPlayerID[id] = SQL_ReadResult(hQuery, index_id);

				new szNewName[MAX_NAME_LENGTH];
				get_user_name(id, szNewName, charsmax(szNewName));

				if (index_name >= 0) {
					new szOldName[MAX_NAME_LENGTH];
					SQL_ReadResult(hQuery, index_name, szOldName, charsmax(szOldName));
					if (!equal(szNewName, szOldName))
						SQL_Name(id, szNewName);
				}

				new szNewIp[MAX_IP_LENGTH];
				get_user_ip(id, szNewIp, charsmax(szNewIp), true);

				if (index_ip >= 0) {
					new szOldIp[MAX_IP_LENGTH];
					SQL_ReadResult(hQuery, index_ip, szOldIp, charsmax(szOldIp));
					if (!equal(szNewIp, szOldIp))
						SQL_Ip(id, szNewIp);
				}

				ExecuteForward(g_hAuthorizedForward, _, id);
			} else {
				SQL_Insert(id);
			}
		}
		case SQL_INSERT: {
			if (iSize < 2)
				return PLUGIN_HANDLED;

			new id = cData[1];
			if (!IsPlayerIndex(id))
				return PLUGIN_HANDLED;

			g_iPlayerID[id] = SQL_GetInsertId(hQuery);
			if (is_user_connected(id))
				ExecuteForward(g_hAuthorizedForward, _, id);
		}
		case SQL_GC_SELECT: {
			if (iSize < 3)
				return PLUGIN_HANDLED;

			new id = cData[1];
			if (!IsValidPlayer(id) || cData[2] != g_iGcGen[id])
				return PLUGIN_HANDLED;

			new szAuthId[MAX_AUTHID_LENGTH];
			get_user_authid(id, szAuthId, charsmax(szAuthId));
			if (!GcAuthUsable(szAuthId) || !equal(szAuthId, g_szGcAuth[id]))
				return PLUGIN_HANDLED;

			new iBase = 0;
			new bool:bHadRow = false;
			if (SQL_NumResults(hQuery)) {
				new index_gc = SQL_FieldNameToNum(hQuery, "gc");
				if (index_gc >= 0) {
					iBase = SQL_ReadResult(hQuery, index_gc);
					bHadRow = true;
				}
			}
			if (iBase < 0)
				iBase = 0;

			new iPending = g_iGcPending[id];
			g_iGcPending[id] = 0;
			g_iGcCache[id] = iBase + iPending;
			g_bGcLoaded[id] = true;
			g_bGcLoading[id] = false;
			g_iGcRetry[id] = 0;
			// 没有记录, 或读取期间有签到/在线奖励, 才写回。不要在 SteamID 未就绪时插入 0。
			if (!bHadRow || iPending != 0)
				GC_Set(id, g_iGcCache[id]);
		}
		case SQL_GC_INSERT: {
			// 写入结果不改缓存, 也不要把玩家标成“已读取”。
		}
	}

	return PLUGIN_HANDLED;
}
stock bool:GcAuthUsable(const szAuth[]) {
	if (!szAuth[0])
		return false;
	if (containi(szAuth, "PENDING") != -1)
		return false;
	if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "BOT"))
		return false;
	return true;
}

stock ScheduleGcLoad(id) {
	if (!IsPlayerIndex(id) || !is_user_connected(id))
		return;
	if (g_iGcRetry[id] >= GC_LOAD_RETRY_MAX)
		return;
	g_iGcRetry[id]++;
	remove_task(id + TASK_GC_LOAD);
	set_task(0.5, "TaskGcLoad", id + TASK_GC_LOAD);
}

public TaskGcLoad(taskid) {
	new id = taskid - TASK_GC_LOAD;
	if (!is_user_connected(id))
		return;
	TryLoadGc(id);
}

stock TryLoadGc(id) {
	if (!IsValidPlayer(id) || is_user_bot(id))
		return;

	remove_task(id + TASK_GC_LOAD);

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	if (!GcAuthUsable(szAuthId)) {
		ScheduleGcLoad(id);
		return;
	}

	if (g_bGcLoaded[id] && equal(g_szGcAuth[id], szAuthId))
		return;
	if (g_bGcLoading[id] && equal(g_szGcAuth[id], szAuthId))
		return;

	if (!equal(g_szGcAuth[id], szAuthId)) {
		g_bGcLoaded[id] = false;
		g_iGcCache[id] = 0;
		copy(g_szGcAuth[id], charsmax(g_szGcAuth[]), szAuthId);
	}

	if (!g_hSqlTuple) {
		ScheduleGcLoad(id);
		return;
	}

	g_bGcLoading[id] = true;
	g_iGcGen[id]++;

	new szQuery[512];
	new cData[3];
	cData[0] = SQL_GC_SELECT;
	cData[1] = id;
	cData[2] = g_iGcGen[id];
	formatex(szQuery, charsmax(szQuery), SQL_SELECT_GC, g_szTableGc, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

stock FlushGcPending(id) {
	if (g_bGcLoaded[id] || g_iGcPending[id] <= 0)
		return;
	if (!g_hSqlTuple || !GcAuthUsable(g_szGcAuth[id]))
		return;

	new szQuery[512];
	new cData[1] = SQL_GC_INSERT;
	new iPending = g_iGcPending[id];
	g_iGcPending[id] = 0;
	formatex(szQuery, charsmax(szQuery), SQL_ADD_GC, g_szTableGc, g_szGcAuth[id], iPending, iPending);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public GC_Set(id, iAmount) {
	if (!g_hSqlTuple || !IsValidPlayer(id))
		return;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	if (!GcAuthUsable(szAuthId))
		return;

	new szQuery[512];
	new cData[2];
	cData[0] = SQL_GC_INSERT;
	cData[1] = id;

	formatex(szQuery, charsmax(szQuery), SQL_SET_GC, g_szTableGc, szAuthId, iAmount);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Select(id) {
	if (!g_hSqlTuple || !IsValidPlayer(id))
		return PLUGIN_HANDLED;

	new szQuery[512];
	new cData[2];
	cData[0] = SQL_SELECT;
	cData[1] = id;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), SQL_SELECT_DATA, g_szTablePlayers, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public SQL_Insert(id) {
	if (!g_hSqlTuple || !IsValidPlayer(id))
		return PLUGIN_HANDLED;

	new szQuery[512];
	new cData[2];
	cData[0] = SQL_INSERT;
	cData[1] = id;

	new szName[MAX_NAME_LENGTH * 2];
	SQL_QuoteString(Empty_Handle, szName, charsmax(szName), fmt("%n", id));

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new szIp[MAX_IP_LENGTH];
	get_user_ip(id, szIp, charsmax(szIp), true);

	formatex(szQuery, charsmax(szQuery), SQL_CREATE_DATA, g_szTablePlayers, szName, szAuthId, szIp);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

SQL_Name(id, szNewname[]) {
	if (!g_hSqlTuple || !IsValidPlayer(id))
		return;

	new szQuery[512];
	new cData[1] = SQL_NAME;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new szName[MAX_NAME_LENGTH * 2];
	SQL_QuoteString(Empty_Handle, szName, charsmax(szName), szNewname);

	formatex(szQuery, charsmax(szQuery), SQL_UPDATE_NAME, g_szTablePlayers, szName, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

SQL_Ip(id, szNewip[]) {
	if (!g_hSqlTuple || !IsValidPlayer(id))
		return;

	new szQuery[512];
	new cData[1] = SQL_IP;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), SQL_UPDATE_IP, g_szTablePlayers, szNewip, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public rgSetClientUserInfoName(id, infobuffer[], szNewName[]) {
	#pragma unused infobuffer

	if (!IsValidPlayer(id) || !szNewName[0])
		return;

	SQL_Name(id, szNewName);
}

public SQL_Save(id) {
	if (!g_hSqlTuple || !IsPlayerIndex(id))
		return PLUGIN_HANDLED;

	new szQuery[512];
	new cData[1] = SQL_SAVE;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new iSaveOnline = get_user_time(id);

	formatex(szQuery, charsmax(szQuery), SQL_SET_PLAYTIME, g_szTablePlayers, iSaveOnline, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public SQL_SaveConn(id) {
	if (!g_hSqlTuple || !IsPlayerIndex(id))
		return PLUGIN_HANDLED;

	new szQuery[512];
	new cData[1] = SQL_SAVECON;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new iTime[32];
	get_time("%S", iTime, charsmax(iTime));

	formatex(szQuery, charsmax(szQuery), SQL_SET_LASTCONNECT, g_szTablePlayers, iTime, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public client_authorized(id) {
	if (!IsValidPlayer(id) || is_user_bot(id))
		return;
	TryLoadGc(id);
}

public client_putinserver(id) {
	if (!IsValidPlayer(id) || is_user_bot(id))
		return;

	g_iPlayerID[id] = 0;
	g_iGcCache[id] = 0;
	g_bGcLoaded[id] = false;
	g_bGcLoading[id] = false;
	g_iGcPending[id] = 0;
	g_iGcGen[id]++;
	g_iGcRetry[id] = 0;
	g_szGcAuth[id][0] = EOS;
	remove_task(id + TASK_GC_LOAD);
	SQL_Select(id);
	TryLoadGc(id);
}

public client_disconnected(id) {
	if (!IsPlayerIndex(id))
		return;

	FlushGcPending(id);
	SQL_Save(id);
	SQL_SaveConn(id);
	remove_task(id + TASK_GC_LOAD);
	g_iPlayerID[id] = 0;
	g_iGcCache[id] = 0;
	g_bGcLoaded[id] = false;
	g_bGcLoading[id] = false;
	g_iGcPending[id] = 0;
	g_iGcGen[id]++;
	g_iGcRetry[id] = 0;
	g_szGcAuth[id][0] = EOS;
}

public plugin_end() {
	if (g_hSqlTuple)
		SQL_FreeHandle(g_hSqlTuple);
	g_hSqlTuple = Empty_Handle;
}
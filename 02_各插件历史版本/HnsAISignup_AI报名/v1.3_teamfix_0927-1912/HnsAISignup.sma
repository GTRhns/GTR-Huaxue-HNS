// ============================================================
//  AI 报名系统 (HnsAISignup)
// ------------------------------------------------------------
//  依赖: HnsMatchSystem (hns_get_mode / hns_ai_enter_lobby /
//        hns_external_* / hns_begin_external_match)
//        HnsMatchSql    (共享 SQL 连接 hns_sql_connection)
//
//  报名规则:
//   - 只有 训练模式 / 比赛前公共模式(大厅) 才能打开报名菜单
//   - 比赛进行中 / 公共模式(PUB/DM/ZM) / 暂停中 一律禁止
//   - 双重保险: 即使菜单被打开, 报名动作仍会重新校验
//   - 盗版玩家只能打娱乐局, 禁止赞助局
//
//  流程:
//   报名中(5分钟倒计时) -> 收团(全部拉观战) -> 1秒1人上场
//   -> 绿色聊天提示 -> 比赛开始
//   比赛结束 -> 清除报名 + 20 秒报名 CD
//   比赛终止 -> 清除报名
//   AI 选图换图 -> 等 30 秒人齐 -> 1秒1人上场 -> 直接开赛
// ============================================================

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <sqlx>
#include <nvault>
#include <hns_matchsystem>
#include <hns_matchsystem_sql>
#include <hns_optional_sql>
#include <hns_language>
#include <PersistentDataStorage>

#define PLUGIN_VERSION "1.3"

// ---------------- 常量 ----------------
#define SIGNUP_MIN         6        // 最少 6 人 (3v3)
#define SIGNUP_MAX         12       // 最多 12 人 (6v6)
#define SIGNUP_TIMER       300.0    // 报名 5 分钟倒计时
#define SIGNUP_CD          20.0     // 比赛结束报名冷却
#define MAP_CHANGE_WAIT    30.0     // 换图后等人齐再拉人
#define PLACE_INTERVAL     1.0      // 1 秒 1 人上场

#define TASK_COUNTDOWN     92001
#define TASK_PLACE         92002
#define TASK_AFTER_MAP     92003
#define TASK_VOTE          92004
#define TASK_SIGNUP_HUD    92005
#define TASK_SPONSOR_WAIT  92006
#define TASK_MAP_WAIT      92007

#define RULE_COUNT         4
#define POOL_SKILL         0
#define POOL_BOOST         1

#define VOTE_TIME          20       // 比赛模式/地图投票时长 (秒)
#define MAP_MAX            256
#define MAP_NAME_LEN       32
#define SPONSOR_WAIT       30.0     // 赞助者输入等待 (秒)

#define TEAM_T             1
#define TEAM_CT            2

#define PTS_WIN            15
#define PTS_LOSS           10
#define PTS_BASE           1000

// ---------------- 全局变量 ----------------
enum SIGNUP_STATE {
	SIGNUP_IDLE,     // 待命
	SIGNUP_OPEN,     // 报名中
	SIGNUP_CLOSE,    // 收团分配 (拉观战 + 1秒1人)
	SIGNUP_SETUP,    // 分组完成, 选模式/地图/赞助者
	MATCH_RUNNING    // 比赛中
};

new SIGNUP_STATE:g_eState = SIGNUP_IDLE;

new g_iSignupList[MAX_PLAYERS];      // 报名玩家 (按报名顺序)
new g_iSignupCount;                  // 报名人数
new bool:g_bSignedUp[MAX_PLAYERS + 1];
new g_iSignupTeam[MAX_PLAYERS + 1];  // 记住的队伍: 0 未分配 / 1 T / 2 CT

new Float:g_flSignupTimer;           // 报名倒计时剩余
new Float:g_flBlockedUntil;          // 冷却截止时间
new bool:g_bSponsorMatch;            // 当前报名局类型: true 赞助局 / false 娱乐局

// 收团 1 秒 1 人用的上场队列
new g_iPlaceOrder[SIGNUP_MAX];
new g_iPlaceTeam[SIGNUP_MAX];
new g_iPlaceTotal;
new g_iPlaceIndex;
new g_iPlaceTeamSize;

// 盗版玩家 SQL / 本地 vault
new Handle:g_hSqlTuple = Empty_Handle;
new bool:g_bSqlReady;
new g_iGuestVault = INVALID_HANDLE;
new bool:g_bGuest[MAX_PLAYERS + 1];
new g_iGuestId[MAX_PLAYERS + 1];

new g_szLastMap[32];

// ---------------- 参赛菜单 / 管理模式 ----------------
new const g_szRules[RULE_COUNT][] = { "MR制", "计时制", "决斗制", "回合制" };
new const g_szStateName[5][] = { "待命", "报名中", "收团分配", "赛前选择", "比赛中" };
new const g_szRuleKeys[RULE_COUNT][] = { "AI_RULE_MR", "AI_RULE_TIMER", "AI_RULE_DUEL", "AI_RULE_ROUNDS" };

new NATCH_RULES:g_iMatchRules = RULES_MR;   // 当前选择的比赛规则
new g_iTeamSizeFixed;                       // 0 = 自动(按报名人数), 3..6 = 固定人数
new bool:g_bForceStart;                     // 管理员强制开赛: 允许 1 人测试

enum VOTE_KIND {
	VOTE_NONE,
	VOTE_RULES,
	VOTE_MAP,
	VOTE_POOL
};

new VOTE_KIND:g_eVoteKind = VOTE_NONE;
new bool:g_bVoteActive;
new g_iVoteTally[RULE_COUNT];
new g_iVoteSeconds;
new bool:g_bVoteDone[MAX_PLAYERS + 1];
new bool:g_bPostGroupSetup;                 // 收团后进入模式/地图选择
new bool:g_bWaitingSponsor;                 // 等待管理员/VIP 输入赞助者
new g_iSponsorAskId;
new g_szSponsorName[33];
new bool:g_bSponsorNameInput[MAX_PLAYERS + 1];

new g_szSkillMaps[MAP_MAX][MAP_NAME_LEN];
new g_iSkillMapCount;
new g_szBoostMaps[MAP_MAX][MAP_NAME_LEN];
new g_iBoostMapCount;
new g_szMapList[MAP_MAX][MAP_NAME_LEN];
new g_iMapCount;
new g_szAllMaps[MAP_MAX][MAP_NAME_LEN];
new g_iAllMapCount;
new g_iActivePool = POOL_SKILL;
new g_szPickedMap[MAP_NAME_LEN];
new g_iMapVoteTally[MAP_MAX];
new g_iMapVoteChoice[MAX_PLAYERS + 1];
new g_iPoolVoteTally[2];
new bool:g_bPendingMatchStart;
new bool:g_bMapWaitActive;
new g_iMapWaitSeconds;
new bool:g_bKeepSavedTeams;          // 换图恢复: 保留原 T/CT, 不再随机

stock bool:canSignup(id, szReason[], iLen);
stock signupPlayer(id);

// ============================================================
//  插件初始化
// ============================================================
public plugin_natives() {
	hns_register_optional_sql();
	register_library("hns_ai_signup");
	register_native("hns_ai_force_signup", "native_force_signup");
}

// 测试人机插件用: 跳过菜单直接报名 (仍走 canSignup)
public native_force_signup(plugin, params) {
	new id = get_param(1);
	if (!is_user_connected(id) || g_bSignedUp[id])
		return 0;

	if (g_iSignupCount >= SIGNUP_MAX)
		return 0;

	new szReason[64];
	if (!canSignup(id, szReason, charsmax(szReason)))
		return 0;

	signupPlayer(id);
	return 1;
}

public plugin_init() {
	register_plugin("AI 报名系统", PLUGIN_VERSION, "HNSai");

	RegisterSayCmd("signup", "报", "cmdSignupMenu", 0, "AI 报名");
	RegisterSayCmd("cancel", "退", "cmdCancel", 0, "取消报名");
	RegisterSayCmd("aistart", "开赛", "cmdAiStart", -1, "强制收团开赛");
	RegisterSayCmd("aitype", "赛制", "cmdAiType", -1, "设置比赛类型 0娱乐/1赞助");
	RegisterSayCmd("aiabort", "停赛", "cmdAiAbort", -1, "取消报名");
	RegisterSayCmd("aivote", "投", "cmdAiVote", 0, "比赛模式投票");

	register_clcmd("say", "aiSayHandle");
	register_clcmd("say_team", "aiSayHandle");

	get_mapname(g_szLastMap, charsmax(g_szLastMap));
	loadMapPools();
	set_task(1.0, "taskSignupHud", TASK_SIGNUP_HUD, .flags = "b");
}

// 地图加载完毕: 换图会重载插件, 只能靠 PDS 恢复 pending 开赛
public plugin_cfg() {
	new szMap[32];
	get_mapname(szMap, charsmax(szMap));
	copy(g_szLastMap, charsmax(g_szLastMap), szMap);

	new iPending;
	if (PDS_GetCell("ai_pending_start", iPending) && iPending)
		onMapChange();

	if (!g_bSqlReady)
		Local_GuestInit();
}

public plugin_end() {
	if (g_iGuestVault != INVALID_HANDLE) {
		nvault_close(g_iGuestVault);
		g_iGuestVault = INVALID_HANDLE;
	}
}

// 共享 SQL 连接 (来自 HnsMatchSql)
public hns_sql_connection(hSqlTuple) {
	g_hSqlTuple = Handle:hSqlTuple;
	g_bSqlReady = (g_hSqlTuple != Empty_Handle);

	if (g_hSqlTuple == Empty_Handle)
		return;

	if (g_iGuestVault != INVALID_HANDLE) {
		nvault_close(g_iGuestVault);
		g_iGuestVault = INVALID_HANDLE;
	}

	SQL_ThreadQuery(g_hSqlTuple, "cbVoid", "CREATE TABLE IF NOT EXISTS `hns_ai_guest` ( \
		`id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY, \
		`name` VARCHAR(32) NULL DEFAULT NULL, \
		`ip` VARCHAR(22) NULL DEFAULT NULL, \
		`lastconnect` INT NOT NULL DEFAULT 0, \
		UNIQUE KEY `ip` (`ip`) \
	);");

	SQL_ThreadQuery(g_hSqlTuple, "cbVoid", "CREATE TABLE IF NOT EXISTS `hns_ai_guest_pts` ( \
		`id` INT(11) NOT NULL PRIMARY KEY, \
		`wins` INT(11) NOT NULL DEFAULT 0, \
		`loss` INT(11) NOT NULL DEFAULT 0, \
		`pts` INT(11) NOT NULL DEFAULT 1000 \
	);");
}

public cbVoid(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (failstate) {
		log_amx("HNSai SQL 失败: %s", error);
	}
}

// ============================================================
//  盗版玩家管理
// ============================================================
stock bool:isGuestPlayer(id) {
	new szAuth[32];
	get_user_authid(id, szAuth, charsmax(szAuth));

	if (!szAuth[0])
		return true;
	if (containi(szAuth, "STEAM_ID") != -1)            // STEAM_ID_LAN
		return true;
	if (containi(szAuth, "BOT") != -1)
		return true;
	if (equali(szAuth, "STEAM_0:0:0") || equali(szAuth, "STEAM_1:0:0"))
		return true;

	return false;
}

public client_putinserver(id) {
	if (isGuestPlayer(id)) {
		g_bGuest[id] = true;
		guestSqlRegister(id);
	} else {
		g_bGuest[id] = false;
	}
}

stock Local_GuestInit() {
	if (g_iGuestVault == INVALID_HANDLE)
		g_iGuestVault = nvault_open("hns_ai_guest");
}

// 盗版玩家自动注册 (以 IP 为稳定标识)
stock guestSqlRegister(id) {
	if (!g_bSqlReady || g_hSqlTuple == Empty_Handle) {
		Local_GuestInit();
		g_iGuestId[id] = 1;
		return;
	}

	new szName[32], szIp[32], szSafe[96];
	get_user_name(id, szName, charsmax(szName));
	get_user_ip(id, szIp, charsmax(szIp), 1);
	// SQL_QuoteString 第一个参数仅用于本地化, 传 tuple 句柄会报 Invalid database handle
	SQL_QuoteString(Empty_Handle, szSafe, charsmax(szSafe), szName);

	new szQuery[256];
	formatex(szQuery, charsmax(szQuery),
		"INSERT INTO `hns_ai_guest` (name, ip, lastconnect) VALUES ('%s','%s',%d) \
		ON DUPLICATE KEY UPDATE name=VALUES(name), lastconnect=VALUES(lastconnect)",
		szSafe, szIp, get_systime());

	new data[1];
	data[0] = id;
	SQL_ThreadQuery(g_hSqlTuple, "cbGuestRegister", szQuery, data, sizeof(data));
}

public cbGuestRegister(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (failstate || size < 1)
		return;

	new id = data[0];
	if (!is_user_connected(id))
		return;

	new szIp[32];
	get_user_ip(id, szIp, charsmax(szIp), 1);

	new szQuery[192];
	formatex(szQuery, charsmax(szQuery), "SELECT `id` FROM `hns_ai_guest` WHERE `ip`='%s'", szIp);

	new data2[1];
	data2[0] = id;
	SQL_ThreadQuery(g_hSqlTuple, "cbGuestId", szQuery, data2, sizeof(data2));
}

public cbGuestId(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (failstate || size < 1 || SQL_NumResults(query) == 0)
		return;

	new id = data[0];
	g_iGuestId[id] = SQL_ReadResult(query, 0);
}

// ============================================================
//  报名门槛 (双重保险: 菜单打开 & 动作执行 都校验这里)
// ============================================================

// 能否打开参赛菜单: 仅训练/比赛前公共模式, 且非暂停/比赛中
stock bool:canOpenMenu(id, szReason[], iLen) {
	#pragma unused id
	if (hns_get_state() == STATE_PAUSED) {
		copy(szReason, iLen, "比赛暂停中, 无法打开参赛菜单");
		return false;
	}

	new iMode = hns_get_mode();
	if (iMode != MODE_TRAINING && iMode != MODE_LOBBY) {
		copy(szReason, iLen, "只有训练/大厅模式才能打开参赛菜单");
		return false;
	}

	if (g_eState == MATCH_RUNNING || g_eState == SIGNUP_SETUP) {
		copy(szReason, iLen, "比赛进行中, 无法打开参赛菜单");
		return false;
	}

	return true;
}

stock bool:canSignup(id, szReason[], iLen) {
	if (g_eState == SIGNUP_CLOSE) {
		copy(szReason, iLen, "正在收团分配队伍, 请稍候");
		return false;
	}
	if (g_eState == MATCH_RUNNING || g_eState == SIGNUP_SETUP) {
		copy(szReason, iLen, "比赛正在进行中, 无法报名");
		return false;
	}
	if (hns_get_state() == STATE_PAUSED) {
		copy(szReason, iLen, "比赛暂停中, 无法报名");
		return false;
	}

	new iMode = hns_get_mode();
	if (iMode != MODE_TRAINING && iMode != MODE_LOBBY) {
		copy(szReason, iLen, "只有训练/大厅模式才能报名");
		return false;
	}

	new Float:flRemain = g_flBlockedUntil - get_gametime();
	if (flRemain > 0.0) {
		format(szReason, iLen, "报名冷却中, 剩余 %d 秒", floatround(flRemain, floatround_ceil));
		return false;
	}

	if (g_bSponsorMatch && isGuestPlayer(id)) {
		copy(szReason, iLen, "盗版玩家不能参与赞助局");
		return false;
	}

	return true;
}

// ============================================================
//  参赛菜单 (主菜单)
// ============================================================
public cmdSignupMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szReason[64];
	if (!canOpenMenu(id, szReason, charsmax(szReason))) {
		ai_print(id, "%s", szReason);
		return PLUGIN_HANDLED;
	}

	// 打开菜单即播报当前比赛状态
	ai_printModeInfo(id);
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showMainMenu(id) {
	new szTitle[192], szItem[96], szTmp[64];
	new szType[32], szSignup[64], szCancel[64], szGroup[64];
	new szReshuffle[64], szForce[64], szRules[64], szSize[64], szTypeMenu[64], szExit[32];

	ai_lang(id, "AI_TYPE_SPONSOR", szTmp, charsmax(szTmp));
	if (!g_bSponsorMatch)
		ai_lang(id, "AI_TYPE_CASUAL", szTmp, charsmax(szTmp));
	copy(szType, charsmax(szType), szTmp);

	ai_lang(id, "AI_MENU_TITLE", szTitle, charsmax(szTitle));
	format(szTitle, charsmax(szTitle), szTitle, szType, g_iSignupCount, getOnlineCount());

	new menu = menu_create(szTitle, "MainMenuHandler");

	ai_lang(id, "AI_MENU_GROUP", szGroup, charsmax(szGroup));
	ai_lang(id, "AI_MENU_SIGNUP", szSignup, charsmax(szSignup));
	ai_lang(id, "AI_MENU_CANCEL", szCancel, charsmax(szCancel));
	ai_lang(id, "AI_MENU_RESHUFFLE", szReshuffle, charsmax(szReshuffle));
	ai_lang(id, "AI_MENU_FORCE", szForce, charsmax(szForce));
	ai_lang(id, "AI_MENU_RULES", szRules, charsmax(szRules));
	ai_lang(id, "AI_MENU_SIZE", szSize, charsmax(szSize));
	ai_lang(id, "AI_MENU_TYPE", szTypeMenu, charsmax(szTypeMenu));
	ai_lang(id, "AI_MENU_EXIT", szExit, charsmax(szExit));

	menu_additem(menu, szGroup, "group");
	menu_additem(menu, g_bSignedUp[id] ? szCancel : szSignup, "signup");
	menu_additem(menu, szTypeMenu, "type");

	menu_addblank(menu, 0);

	menu_additem(menu, szReshuffle, "reshuffle");
	menu_additem(menu, szForce, "forcestart");

	menu_addblank(menu, 0);

	ai_ruleName(id, _:g_iMatchRules, szTmp, charsmax(szTmp));
	formatex(szItem, charsmax(szItem), "%s \y[%s]", szRules, szTmp);
	menu_additem(menu, szItem, "rules");

	formatex(szItem, charsmax(szItem), "%s \y[%d : %d]", szSize, getEffectiveTeamSize(), getEffectiveTeamSize());
	menu_additem(menu, szItem, "size");

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	menu_display(id, menu);
}

public MainMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (equal(data, "group")) {
		showGroups(id);
		showMainMenu(id);
	} else if (equal(data, "signup")) {
		doSignupToggle(id);
		if (is_user_connected(id) && g_eState != MATCH_RUNNING && g_eState != SIGNUP_CLOSE && g_eState != SIGNUP_SETUP)
			showMainMenu(id);
	} else if (equal(data, "type")) {
		showTypeMenu(id);
	} else if (equal(data, "reshuffle")) {
		cmdReshuffle(id);
		if (is_user_connected(id) && g_eState != MATCH_RUNNING && g_eState != SIGNUP_SETUP)
			showMainMenu(id);
	} else if (equal(data, "forcestart")) {
		cmdForceStart(id);
	} else if (equal(data, "rules")) {
		showRulesMenu(id);
	} else if (equal(data, "size")) {
		showSizeMenu(id);
	}

	return PLUGIN_HANDLED;
}

// ============================================================
//  HNS报名分组情况 (蓝色 CT / 红色 TT, 名字之间用「，」)
// ============================================================
public showGroups(const id) {
	new bool:bAssigned;
	for (new i = 0; i < g_iSignupCount; i++) {
		if (g_iSignupTeam[g_iSignupList[i]]) {
			bAssigned = true;
			break;
		}
	}

	if (!bAssigned) {
		ai_print(id, "尚未分组, 请点击「重新分配队伍」");
		return;
	}

	ai_print(id, "当前分组 \y[%d v %d]", getEffectiveTeamSize(), getEffectiveTeamSize());

	client_print_color(id, print_team_blue, "^3--------|CT|---------");
	if (!printTeamNames(id, TEAM_CT))
		client_print_color(id, print_team_blue, "^3(无)");

	client_print_color(id, print_team_default, " ");

	client_print_color(id, print_team_red, "^3--------|TT|---------");
	if (!printTeamNames(id, TEAM_T))
		client_print_color(id, print_team_red, "^3(无)");
}

// 打印某队全部名字 (过长自动换行)
stock bool:printTeamNames(const id, iTeam) {
	new szLine[192];
	new iLen, iCount;

	for (new i = 0; i < g_iSignupCount; i++) {
		new p = g_iSignupList[i];
		if (!is_user_connected(p) || g_iSignupTeam[p] != iTeam)
			continue;

		new szName[32];
		get_user_name(p, szName, charsmax(szName));

		if (iLen > 0)
			iLen += format(szLine[iLen], charsmax(szLine) - iLen, "，");

		iLen += format(szLine[iLen], charsmax(szLine) - iLen, "%s", szName);
		iCount++;

		if (iLen >= 140) {
			sendTeamLine(id, iTeam, szLine);
			szLine[0] = EOS;
			iLen = 0;
		}
	}

	if (iLen > 0)
		sendTeamLine(id, iTeam, szLine);

	return iCount > 0;
}

stock sendTeamLine(const id, iTeam, const szLine[]) {
	if (iTeam == TEAM_CT)
		client_print_color(id, print_team_blue, "^3%s", szLine);
	else
		client_print_color(id, print_team_red, "^3%s", szLine);
}

// ============================================================
//  报名 / 取消报名
// ============================================================
public cmdCancel(id) {
	doSignupToggle(id);
	return PLUGIN_HANDLED;
}

stock doSignupToggle(id) {
	if (g_bSignedUp[id]) {
		if (g_eState == MATCH_RUNNING) {
			ai_print(id, "比赛进行中, 无法取消报名");
			return;
		}
		cancelSignup(id);
		return;
	}

	// ★ 双重保险: 即使菜单已被打开, 报名动作仍重新校验
	new szReason[64];
	if (!canSignup(id, szReason, charsmax(szReason))) {
		ai_print(id, "%s", szReason);
		return;
	}
	signupPlayer(id);
}

// ============================================================
//  重新分配队伍 / 强制开启
// ============================================================
public cmdReshuffle(id) {
	if (g_eState == MATCH_RUNNING) {
		ai_print(id, "比赛进行中, 无法重新分配队伍");
		return PLUGIN_HANDLED;
	}

	if (g_iSignupCount < 1) {
		ai_print(id, "当前没有报名玩家");
		return PLUGIN_HANDLED;
	}

	shuffleTeamsNow();

	ai_print(0, "队伍已重新随机分配 (^3%d^1 人)", g_iSignupCount);
	showGroups(0);
	return PLUGIN_HANDLED;
}

public cmdForceStart(id) {
	if (!isUserVipOrAdmin(id)) {
		ai_print(id, "需要管理员权限才能强制开启比赛");
		return PLUGIN_HANDLED;
	}

	if (g_eState == MATCH_RUNNING) {
		ai_print(id, "比赛已在进行中");
		return PLUGIN_HANDLED;
	}

	if (g_iSignupCount < 1) {
		ai_print(id, "当前没有报名玩家, 无法强制开启");
		return PLUGIN_HANDLED;
	}

	g_bForceStart = true;
	ai_print(0, "[HNS测试] 管理员强制开启比赛! (^3%d^1 人)", g_iSignupCount);
	g_flSignupTimer = 0.0;
	g_eState = SIGNUP_OPEN;
	closeSignup();
	return PLUGIN_HANDLED;
}

// 强制收团开赛 (管理员) —— 与菜单「强制开启」同一入口
public cmdAiStart(id) {
	return cmdForceStart(id);
}

// ============================================================
//  HNS比赛模式 (管理员选择 / 无管理员时玩家投票)
// ============================================================
public showRulesMenu(id) {
	new szTitle[128], szRule[32];
	ai_ruleName(id, _:g_iMatchRules, szRule, charsmax(szRule));
	format(szTitle, charsmax(szTitle), "\rHNS比赛模式 \y[当前: %s]", szRule);

	new menu = menu_create(szTitle, "RulesMenuHandler");
	new szItem[96], szData[16];

	for (new i = 0; i < RULE_COUNT; i++) {
		ai_ruleName(id, i, szRule, charsmax(szRule));
		formatex(szItem, charsmax(szItem), "%s%s", (i == _:g_iMatchRules) ? "\r* " : "\w", szRule);
		formatex(szData, charsmax(szData), "rule_%d", i);
		menu_additem(menu, szItem, szData);
	}

	menu_setprop(menu, MPROP_EXITNAME, "返回");
	menu_display(id, menu);
}

public RulesMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	new iRule = str_to_num(data[5]);
	if (iRule < 0 || iRule >= RULE_COUNT)
		return PLUGIN_HANDLED;

	if (isUserVipOrAdmin(id)) {
		applyMatchRules(iRule);
		ai_print(0, "比赛模式已设为: ^3%s^1 (管理员设置)", g_szRules[iRule]);
		if (g_bPostGroupSetup)
			beginMapSelect();
		else
			showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	if (isAdminOnline()) {
		showMainMenu(id);
		ai_print(id, "有管理员在线, 请让管理员设置比赛模式");
		return PLUGIN_HANDLED;
	}

	// 无管理员在线 -> 玩家投票 (发起人的选择直接计入)
	startRulesVote(id, iRule);
	return PLUGIN_HANDLED;
}

stock applyMatchRules(iRule) {
	g_iMatchRules = NATCH_RULES:iRule;

	// 比赛已在进行中则立即生效
	if (g_eState == MATCH_RUNNING)
		hns_external_set_match_mode(_:g_iMatchRules);
}

public startRulesVote(id, iProposed) {
	if (g_bVoteActive) {
		ai_print(id, "已有投票进行中 (剩余 ^3%d^1 秒)", g_iVoteSeconds);
		return;
	}

	g_bVoteActive = true;
	g_iVoteSeconds = VOTE_TIME;

	for (new i = 0; i < RULE_COUNT; i++)
		g_iVoteTally[i] = 0;

	for (new i = 0; i <= MAX_PLAYERS; i++)
		g_bVoteDone[i] = false;

	if (id >= 1 && id <= MAX_PLAYERS && iProposed >= 0 && iProposed < RULE_COUNT) {
		g_bVoteDone[id] = true;
		g_iVoteTally[iProposed]++;
	}

	g_eVoteKind = VOTE_RULES;
	ai_print(0, "无管理员在线, 开始投票选择比赛模式 (^3%d^1 秒)", g_iVoteSeconds);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		showVoteMenu(iPlayers[i]);

	set_task(1.0, "taskVote", TASK_VOTE, .flags = "b");
}

public cmdAiVote(id) {
	if (!g_bVoteActive) {
		ai_print(id, "当前没有投票");
		return PLUGIN_HANDLED;
	}

	if (g_eVoteKind == VOTE_MAP)
		showMapVoteMenu(id);
	else if (g_eVoteKind == VOTE_POOL)
		showPoolVoteMenu(id);
	else
		showVoteMenu(id);
	return PLUGIN_HANDLED;
}

public showVoteMenu(id) {
	if (!g_bVoteActive || !is_user_connected(id) || g_eVoteKind != VOTE_RULES)
		return;

	new szTitle[192], szItem[96], szRule[32], szSkip[32];
	ai_lang(id, "AI_VOTE_RULES_TITLE", szTitle, charsmax(szTitle));
	format(szTitle, charsmax(szTitle), szTitle, g_iVoteSeconds, countVoted(), getOnlineCount());

	new menu = menu_create(szTitle, "VoteMenuHandler");
	new szData[16];
	new iTotal = getVoteTotal();

	for (new i = 0; i < RULE_COUNT; i++) {
		ai_ruleName(id, i, szRule, charsmax(szRule));
		formatex(szItem, charsmax(szItem), "%s \r[%d%%]", szRule, getVotePercent(g_iVoteTally[i], iTotal));
		formatex(szData, charsmax(szData), "vote_%d", i);
		menu_additem(menu, szItem, szData);
	}

	ai_lang(id, "AI_VOTE_SKIP", szSkip, charsmax(szSkip));
	menu_setprop(menu, MPROP_EXITNAME, szSkip);
	menu_display(id, menu);
}

public VoteMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!g_bVoteActive)
		return PLUGIN_HANDLED;

	if (g_bVoteDone[id]) {
		ai_print(id, "你已经投过票了");
		return PLUGIN_HANDLED;
	}

	new iRule = str_to_num(data[5]);
	if (iRule < 0 || iRule >= RULE_COUNT)
		return PLUGIN_HANDLED;

	g_bVoteDone[id] = true;
	g_iVoteTally[iRule]++;

	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	ai_print(0, "%s 投票: ^3%s", szName, g_szRules[iRule]);

	checkVoteDone();
	return PLUGIN_HANDLED;
}

public taskVote() {
	if (!g_bVoteActive) {
		remove_task(TASK_VOTE);
		return;
	}

	g_iVoteSeconds--;

	if (g_iVoteSeconds <= 0) {
		remove_task(TASK_VOTE);
		if (g_eVoteKind == VOTE_MAP)
			finishMapVote();
		else if (g_eVoteKind == VOTE_POOL)
			finishPoolVote();
		else
			finishRulesVote();
		return;
	}

	if (g_iVoteSeconds <= 5 || g_iVoteSeconds % 5 == 0) {
		if (g_eVoteKind == VOTE_MAP)
			ai_print(0, "地图投票剩余 ^3%d^1 秒", g_iVoteSeconds);
		else if (g_eVoteKind == VOTE_POOL)
			ai_print(0, "地图池投票剩余 ^3%d^1 秒", g_iVoteSeconds);
		else
			ai_print(0, "模式投票剩余 ^3%d^1 秒", g_iVoteSeconds);
	}
}

stock checkVoteDone() {
	if (!g_bVoteActive)
		return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	if (iNum <= 0)
		return;

	if (countVoted() >= iNum) {
		remove_task(TASK_VOTE);
		if (g_eVoteKind == VOTE_MAP)
			finishMapVote();
		else if (g_eVoteKind == VOTE_POOL)
			finishPoolVote();
		else
			finishRulesVote();
	}
}

public finishRulesVote() {
	if (!g_bVoteActive)
		return;

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	remove_task(TASK_VOTE);

	new iBest, iBestCount = -1;
	for (new i = 0; i < RULE_COUNT; i++) {
		if (g_iVoteTally[i] > iBestCount) {
			iBestCount = g_iVoteTally[i];
			iBest = i;
		}
	}

	if (iBestCount <= 0) {
		ai_print(0, "投票结束: 无人投票, 保持当前模式 ^3%s", g_szRules[_:g_iMatchRules]);
	} else {
		applyMatchRules(iBest);
		ai_print(0, "投票结束: 比赛模式设为 ^3%s^1 (%d 票)", g_szRules[iBest], iBestCount);
	}

	if (g_bPostGroupSetup)
		beginMapSelect();
}

// ============================================================
//  人数管理 (管理员手动 / 系统自动默认 5v5)
// ============================================================
public showSizeMenu(id) {
	new iSize = getEffectiveTeamSize();

	new szTitle[160];
	format(szTitle, charsmax(szTitle), "\y人数管理 \r[%d : %d]\w (自动默认 5v5)", iSize, iSize);

	new menu = menu_create(szTitle, "SizeMenuHandler");
	new szItem[96], szData[16];

	formatex(szItem, charsmax(szItem), "%s自动 (按报名人数)", g_iTeamSizeFixed ? "\w" : "\r* ");
	menu_additem(menu, szItem, "size_0");

	for (new i = 3; i <= 6; i++) {
		formatex(szItem, charsmax(szItem), "%s%d v %d", (g_iTeamSizeFixed == i) ? "\r* " : "\w", i, i);
		formatex(szData, charsmax(szData), "size_%d", i);
		menu_additem(menu, szItem, szData);
	}

	menu_setprop(menu, MPROP_EXITNAME, "返回");
	menu_display(id, menu);
}

public SizeMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		showMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id)) {
		showMainMenu(id);
		ai_print(id, "人数管理由管理员设置 (当前: %d v %d)", getEffectiveTeamSize(), getEffectiveTeamSize());
		return PLUGIN_HANDLED;
	}

	new iSize = str_to_num(data[5]);

	if (iSize == 0) {
		g_iTeamSizeFixed = 0;
		ai_print(0, "人数管理已设为: ^3自动^1 (10 人 = 5v5, 人数不足时默认 5v5)");
	} else if (iSize >= 3 && iSize <= 6) {
		g_iTeamSizeFixed = iSize;
		ai_print(0, "人数管理已设为: ^3%d v %d^1", iSize, iSize);
	}

	showMainMenu(id);
	return PLUGIN_HANDLED;
}

// 设置比赛类型 0娱乐/1赞助 (管理员)
public cmdAiType(id) {
	if (!isUserVipOrAdmin(id))
		return PLUGIN_HANDLED;

	new szArg[8];
	read_argv(1, szArg, charsmax(szArg));
	if (!szArg[0]) {
		ai_print(id, "用法: !aitype <0娱乐|1赞助> (当前: %s)", g_bSponsorMatch ? "赞助局" : "娱乐局");
		return PLUGIN_HANDLED;
	}

	new bool:bSponsor = bool:str_to_num(szArg);
	g_bSponsorMatch = bSponsor;

	if (bSponsor) {
		// 赞助局: 自动移除所有盗版玩家
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

	ai_print(0, "AI 报名比赛类型已设为: ^3%s^1", bSponsor ? "赞助局" : "娱乐局");
	broadcastStatus();
	return PLUGIN_HANDLED;
}

// 取消整个报名 (管理员)
public cmdAiAbort(id) {
	if (!isUserVipOrAdmin(id))
		return PLUGIN_HANDLED;

	abortSignup();
	ai_print(0, "AI 报名已取消, 全部清除");
	return PLUGIN_HANDLED;
}

// ============================================================
//  报名核心
// ============================================================
public signupPlayer(id) {
	if (g_bSignedUp[id])
		return;

	if (g_iSignupCount >= SIGNUP_MAX)
		return;

	g_iSignupList[g_iSignupCount++] = id;
	g_bSignedUp[id] = true;

	// 第一个报名: 激活大厅模式 + 启动 5 分钟倒计时
	if (g_iSignupCount == 1) {
		if (hns_get_mode() == MODE_TRAINING)
			hns_ai_enter_lobby();

		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = SIGNUP_TIMER;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
	} else if (g_eState == SIGNUP_IDLE) {
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = SIGNUP_TIMER;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
	}

	broadcastStatus();
}

public cancelSignup(id) {
	if (!g_bSignedUp[id])
		return;

	for (new i = 0; i < g_iSignupCount; i++) {
		if (g_iSignupList[i] == id) {
			g_iSignupList[i] = g_iSignupList[g_iSignupCount - 1];
			g_iSignupCount--;
			break;
		}
	}

	g_bSignedUp[id] = false;
	g_iSignupTeam[id] = 0;

	if (stopSignupIfEmpty())
		return;

	broadcastStatus();
}

public client_disconnected(id) {
	if (g_bSignedUp[id]) {
		for (new i = 0; i < g_iSignupCount; i++) {
			if (g_iSignupList[i] == id) {
				g_iSignupList[i] = g_iSignupList[g_iSignupCount - 1];
				g_iSignupCount--;
				break;
			}
		}
		g_bSignedUp[id] = false;
		// 队伍记忆保留, 掉线重连/下张图仍可恢复

		if (stopSignupIfEmpty())
			return;
	}
}

// 报名状态广播: 蓝色报名人数 + 白色服务器人数
public broadcastStatus() {
	ai_print(0, "已报名 %d 人 | 服务器在线 %d 人", g_iSignupCount, getOnlineCount());
}

// 报名倒计时
public taskCountdown() {
	if (g_eState == MATCH_RUNNING || g_eState == SIGNUP_IDLE) {
		remove_task(TASK_COUNTDOWN);
		return;
	}

	// 收团分配中: 暂停计时但保留任务 (分配完后继续)
	if (g_eState != SIGNUP_OPEN)
		return;

	if (stopSignupIfEmpty())
		return;

	g_flSignupTimer -= 1.0;

	if (g_flSignupTimer <= 0.0) {
		closeSignup();
		return;
	}

	new iSec = floatround(g_flSignupTimer, floatround_floor);
	if (iSec <= 5 || (iSec <= 300 && iSec % 30 == 0)) {
		ai_print(0, "报名剩余 ^3%d^1 秒 | 已报名 %d 人", iSec, g_iSignupCount);
	}
}

// ============================================================
//  收团 -> 1 秒 1 人 -> 开赛
// ============================================================
public closeSignup() {
	if (g_eState != SIGNUP_OPEN)
		return;


	// 动态队伍规模: 自动 = N/2 (上限 6v6), 或管理员在「人数管理」里固定
	g_iPlaceTeamSize = getEffectiveTeamSize();
	if (g_bKeepSavedTeams) {
		ai_print(0, "收团! 按换图前分组上场, 不再重新随机");
		g_bKeepSavedTeams = false;
	} else {
		ai_print(0, "收团! 全部玩家进入观战, 正在随机分配队伍...");
		shuffleTeamsNow();
	}
	buildPlaceQueue(g_iPlaceTeamSize);

	// ★ 人数达标 -> 聊天框播报当前分组 (蓝 CT / 红 TT)
	showGroups(0);

	// 把全部人处死拉到观战位 (含测试人机)
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "
		g_flSignupTimer = 60.0;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
		return;
	}

	g_eState = SIGNUP_CLOSE;
	ai_print(0, "收团! 全部玩家进入观战, 正在随机分配队伍...");

	// 动态队伍规模: 自动 = N/2 (上限 6v6), 或管理员在「人数管理」里固定
	g_iPlaceTeamSize = getEffectiveTeamSize();
	shuffleTeamsNow();
	buildPlaceQueue(g_iPlaceTeamSize);

	// ★ 人数达标 -> 聊天框播报当前分组 (蓝 CT / 红 TT)
	showGroups(0);

	// 把全部人处死拉到观战位
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		moveToSpec(iPlayers[i]);

	// 1 秒 1 人上场
	g_iPlaceIndex = 0;
	set_task(PLACE_INTERVAL, "taskPlacePlayer", TASK_PLACE, .flags = "b");
}

stock filterDisconnected() {
	new iNew[MAX_PLAYERS];
	new iNewCount;

	for (new i = 0; i < g_iSignupCount; i++) {
		if (is_user_connected(g_iSignupList[i]))
			iNew[iNewCount++] = g_iSignupList[i];
		else
			g_bSignedUp[g_iSignupList[i]] = false;
	}

	g_iSignupCount = iNewCount;
	for (new i = 0; i < iNewCount; i++)
		g_iSignupList[i] = iNew[i];
}

// 生成上场队列: 按洗牌后的乱序 1 秒 1 人上场 (不按 T/CT 交替)
stock buildPlaceQueue(iTeamSize) {
	new iQueue[SIGNUP_MAX], iCount;

	for (new i = 0; i < g_iSignupCount; i++) {
		new id = g_iSignupList[i];
		if (g_iSignupTeam[id] == TEAM_T || g_iSignupTeam[id] == TEAM_CT)
			iQueue[iCount++] = id;
	}

	shuffleArray(iQueue, iCount);

	g_iPlaceTotal = 0;
	new iT, iCT;
	for (new i = 0; i < iCount; i++) {
		new id = iQueue[i];
		new iTeam = g_iSignupTeam[id];
		if (iTeam == TEAM_T) {
			if (iT >= iTeamSize)
				continue;
			iT++;
		} else {
			if (iCT >= iTeamSize)
				continue;
			iCT++;
		}

		g_iPlaceOrder[g_iPlaceTotal] = id;
		g_iPlaceTeam[g_iPlaceTotal] = iTeam;
		g_iPlaceTotal++;
	}
}

stock shuffleArray(iArr[], iNum) {
	for (new i = iNum - 1; i > 0; i--) {
		new j = random(i + 1);
		new tmp = iArr[i];
		iArr[i] = iArr[j];
		iArr[j] = tmp;
	}
}

// 1 秒 1 人上场
public taskPlacePlayer() {
	if (g_eState != SIGNUP_CLOSE) {
		remove_task(TASK_PLACE);
		return;
	}

	if (g_iPlaceIndex >= g_iPlaceTotal) {
		remove_task(TASK_PLACE);
		if (g_bPendingMatchStart) {
			g_bPendingMatchStart = false;
			startMatch();
		} else {
			beginPostGroupSetup();
		}
		return;
	}

	new idx = g_iPlaceIndex;
	g_iPlaceIndex++;

	new id = g_iPlaceOrder[idx];
	if (is_user_connected(id)) {
		if (g_iPlaceTeam[idx] == TEAM_T)
			moveToTeam(id, TEAM_TERRORIST);
		else
			moveToTeam(id, TeamName:TEAM_CT);
	}
	// 掉线的直接跳过, 继续下一个
}

// 人数合适 -> 绿色聊天提示 -> 比赛开始
public startMatch() {
	filterDisconnected();

	// 统计实际两队人数
	new iT = 0, iCT = 0;
	for (new i = 0; i < g_iSignupCount; i++) {
		new id = g_iSignupList[i];
		if (!is_user_connected(id))
			continue;

		new TeamName:iTeam = getUserTeam(id);
		if (iTeam == TEAM_TERRORIST)
			iT++;
		else if (_:iTeam == TEAM_CT)
			iCT++;
	}

	// 人数不足则中止, 回到报名 (强制开赛允许 1 人测试)
	if (!g_bForceStart && (iT + iCT < SIGNUP_MIN || iT < 3 || iCT < 3)) {
		ai_print(0, "参赛人数不足 (^3T%d^1 v ^3%dCT^1), 取消开赛, 报名继续", iT, iCT);
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = 60.0;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
		return;
	}

	if (iT + iCT < 1) {
		ai_print(0, "没有上场玩家, 取消开赛");
		g_bForceStart = false;
		g_bPostGroupSetup = false;
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = 60.0;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
		return;
	}

	if (g_szPickedMap[0] && !equali(g_szPickedMap, g_szLastMap)) {
		if (!isMapSafeToLoad(g_szPickedMap)) {
			ai_print(0, "地图 ^3%s^1 缺少模型, 留在当前图开赛", g_szPickedMap);
			log_amx("[HNSai] skip unsafe map %s, stay on %s", g_szPickedMap, g_szLastMap);
			g_szPickedMap[0] = EOS;
		}savePendingMatch();
			saveSignupTeams(tch ? 1 : 0);
			PDS_SetString("ai_sponsor_name", g_szSponsorName);
			PDS_SetCell("ai_force_start", g_bForceStart ? 1 : 0);
			PDS_SetCell("ai_team_size", g_iPlaceTeamSize);
			g_eState = SIGNUP_OPEN;
			g_bPostGroupSetup = false;
			server_cmd("changelevel %s", g_szPickedMap);
			return;
		}
	}

	// ★ 绿色聊天提示 (启动比分)
	ai_print(0, "^2比赛启动!^1 T队 ^2%d^1 人 v CT队 ^2%d^1 人", iT, iCT);
	ai_print(0, "^2类型: %s ^1| ^2模式: %s ^1| 报名 %d 人 | 祝大家好运!",
		g_bSponsorMatch ? "赞助局" : "娱乐局", g_szRules[_:g_iMatchRules], iT + iCT);

	// 聊天框播报最终分组 (蓝 CT / 红 TT)
	showGroups(0);

	// 开赛
	hns_external_set_team_size(g_iPlaceTeamSize, g_iPlaceTeamSize);
	hns_external_set_match_mode(_:g_iMatchRules);
	if (g_bSponsorMatch && g_szSponsorName[0])
		hns_external_set_sponsor_name(g_szSponsorName);
	hns_begin_external_match(g_bSponsorMatch, g_iSponsorAskId);

	g_bForceStart = false;
	g_bPostGroupSetup = false;
	g_bWaitingSponsor = false;
	g_bPendingMatchStart = false;
	PDS_SetCell("ai_pending_start", 0);
	g_eState = MATCH_RUNNING;
}

// ============================================================
/g_bKeepSavedTeams = false;
	PDS_SetCell("ai_pending_start", 0);
	PDS_SetCell("ai_saved_n
// ============================================================
public hns_match_started() {
	g_eState = MATCH_RUNNING;
}

public hns_match_finished(iWinTeam) {
	// 盗版玩家记分 (SQL 或本地 vault)
	for (new i = 0; i < g_iSignupCount; i++) {
		new id = g_iSignupList[i];
		if (!is_user_connected(id) || !g_bGuest[id])
			continue;

		new iTeam = getUserTeam(id) == TEAM_TERRORIST ? 1 : 2;
		if (iTeam == iWinTeam)
			guestAddPts(id, 1, 0);
		else
			guestAddPts(id, 0, 1);
	}

	abortSignup();
	g_flBlockedUntil = get_gametime() + SIGNUP_CD;
	ai_print(0, "比赛结束! 报名已清除, 冷却 ^320^1 秒后可再次报名。");
}

public hns_match_canceled() {
	abortSignup();
	ai_print(0, "比赛已终止, 报名已清除");
}

stock guestAddPts(id, iWins, iLoss) {
	if (!g_bSqlReady || g_hSqlTuple == Empty_Handle) {
		Local_GuestInit();
		if (g_iGuestVault == INVALID_HANDLE)
			return;

		new szIp[32], szData[64];
		get_user_ip(id, szIp, charsmax(szIp), 1);

		new iCurWins, iCurLoss, iCurPts = PTS_BASE;
		if (nvault_get(g_iGuestVault, szIp, szData, charsmax(szData)) && szData[0]) {
			new szWins[16], szLoss[16], szPts[16];
			parse(szData, szWins, charsmax(szWins), szLoss, charsmax(szLoss), szPts, charsmax(szPts));
			iCurWins = str_to_num(szWins);
			iCurLoss = str_to_num(szLoss);
			iCurPts = str_to_num(szPts);
		}

		iCurWins += iWins;
		iCurLoss += iLoss;
		iCurPts += iWins * PTS_WIN - iLoss * PTS_LOSS;
		if (iCurPts < 0)
			iCurPts = 0;

		nvault_set(g_iGuestVault, szIp, fmt("%d %d %d", iCurWins, iCurLoss, iCurPts));
		return;
	}

	if (!g_iGuestId[id])
		return;

	new szQuery[192];
	formatex(szQuery, charsmax(szQuery),
		"INSERT INTO `hns_ai_guest_pts` (id, wins, loss, pts) VALUES (%d, %d, %d, %d) \
		ON DUPLICATE KEY UPDATE wins=wins+%d, loss=loss+%d, pts=pts+%d",
		g_iGuestId[id], iWins, iLoss, PTS_BASE + iWins * PTS_WIN - iLoss * PTS_LOSS,
		iWins, iLoss, iWins * PTS_WIN - iLoss * PTS_LOSS);

	SQL_ThreadQuery(g_hSqlTuple, "cbVoid", szQuery);
}

// ============================================================
//  换图处理: AI 选图后等 30 秒人齐 -> 1秒1人上场 -> 开赛
// ============================================================
public onMapChange() {
	remove_task(TASK_COUNTDOWN);
	remove_task(TASK_PLACE);
	remove_task(TASK_AFTER_MAP);
	remove_task(TASK_VOTE);
	remove_task(TASK_SPONSOR_WAIT);
	remove_task(TASK_MAP_WAIT);

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	g_bPostGroupSetup = false;
	g_bWaitingSponsor = false;
	g_bMapWaitActive = false;
	g_iMapWaitSeconds = 0;

	new iPending;
	if (PDS_GetCell("ai_pending_start", iPending) && iPending) {
		PDS_SetCell("ai_pending_start", 0);
		g_bPendingMatchStart = true;
		PDS_GetString("ai_picked_map", g_szPickedMap, charsmax(g_szPickedMap));
		new iRules, iSponsor, iForce, iSize;
		if (PDS_GetCell("ai_match_rules", iRules))
			g_iMatchRules = NATCH_RULES:iRules;
		if (PDS_GetCell("ai_sponsor_match", iSponsor))
			g_bSponsorMatch = bool:iSponsor;
		PDS_GetString("ai_sponsor_name", g_szSponsorName, charsmax(g_szSponsorName));
		if (PDS_GetCell("ai_force_start", iForce))
			g_bForceStart = bool:iForce;
		if (PDS_GetCell("ai_team_size", iSize) && iSize > 0)
			g_iPlaceTeamSize = iSize;
	}

	filterDisconnected();

	// 只有 AI 选图后的 pending 才继续开赛; 普通换图不自动报名、不开赛
	if (g_bPendingMatchStart) {
		g_eState = SIGNUP_OPEN;
		g_flBlockedUntil = 0.0;
		g_flSignupTimer = 0.0;
		g_bMapWaitActive = true;
		g_iMapWaitSeconds = floatround(MAP_CHANGE_WAIT);
		ai_print(0, "换图完成, 等待 ^3%d^1 秒等人齐后再拉人开赛", g_iMapWaitSeconds);
		set_task(1.0, "taskMapWaitTick", TASK_MAP_WAIT, .flags = "b");
		return;
	}

	g_eState = SIGNUP_IDLE;
	g_flBlockedUntil = 0.0;
	g_bKeepSavedTeams = false;
	g_flSignupTimer = 0.0;
	g_bForceStart = false;
	g_iSignupCount = 0;
	for (new i = 0; i <= MAX_PLAYERS; i++) {
		g_bSignedUp[i] = false;
		g_iSignupTeam[i] = 0;
	}
}

public taskMapWaitTick() {
	if (!g_bMapWaitActive || !g_bPendingMatchStart) {
		remove_task(TASK_MAP_WAIT);
		g_bMapWaitActive = false;
		return;
	}

	g_iMapWaitSeconds--;
	if (g_iMapWaitSeconds > 0) {
		if (g_iMapWaitSeconds <= 5 || g_iMapWaitSeconds % 10 == 0)
			ai_print(0, "换图后等待人齐, 剩余 ^3%d^1 秒 | 在线 %d 人", g_iMapWaitSeconds, getOnlineCount());
		return;
	}

	remove_task(TASK_MAP_WAIT);
	g_bMapWaitActive = false;
	taskPendingResume();
}

public taskPendingResume() {
	rebuildSignupFromOnline();
	if (g_iSignupCount < 1) {
		ai_print(0, "换图后没有在线玩家, 取消开赛");
		g_bPendingMatchStart = false;
		g_bForceStart = false;
		g_eState = SIGNUP_IDLE;
		return;
	}

	g_bForceStart = true;
	g_eState = SIGNUP_OPEN;
	ai_print(0, "人齐, 开始一个一个拉人开赛 (^3%d^1 人)", g_iSignupCount);
	closeSignup();
}

stock rebuildSignupFromOnline() {
	g_bKeepSavedTeams = false;
	for (new i = 0; i <= MAX_PLAYERS; i++) {
		g_bSignedUp[i] = false;
		g_iSignupTeam[i] = 0;
	}

	new iSavedN;
	new bool:bHaveSaved = PDS_GetCell("ai_saved_n", iSavedN) && iSavedN > 0;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "h");
	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		if (g_iSignupCount >= SIGNUP_MAX)
			break;

		new iTeam = 0;
		if (bHaveSaved)
			iTeam = loadSavedTeamFor(id);

		// 有换图前名单时, 只恢复当时报过名的人; 没有名单则退回「在线全收」
		if (bHaveSaved && !iTeam)
			continue;

		g_iSignupList[g_iSignupCount++] = id;
		g_bSignedUp[id] = true;
		g_iSignupTeam[id] = iTeam;
		if (iTeam == TEAM_T || iTeam == TEAM_CT)
			g_bKeepSavedTeams_iSignupCount++] = id;
		g_bSignedUp[id] = true;
	}
}

public taskAfterMapCooldown() {
	if (g_eState != SIGNUP_OPEN)
		return;

	filterDisconnected();

	if (stopSignupIfEmpty())
		return;


	if (g_iSignupCount >= SIGNUP_MIN) {
		ai_print(0, "冷静期结束, 参赛人数 ^3%d^1 人, 开始收团!", g_iSignupCount);
		g_flSignupTimer = 0.0;
		closeSignup();
	} else {
		ai_print(0, "冷静期结束, 当前 ^3%d^1 人 (不足 %d), 继续接受报名", g_iSignupCount, SIGNUP_MIN);
		g_flSignupTimer = 60.0;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
	}
}

// ============================================================
//  工具函数
// ============================================================
public abortSignup() {
	remove_task(TASK_COUNTDOWN);
	remove_task(TASK_PLACE);
	remove_task(TASK_AFTER_MAP);
	remove_task(TASK_VOTE);
	remove_task(TASK_SPONSOR_WAIT);
	remove_task(TASK_MAP_WAIT);

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	g_bPostGroupSetup = false;
	g_bWaitingSponsor = false;
	g_bMapWaitActive = false;

	for (new i = 0; i < MAX_PLAYERS + 1; i++) {
		g_bSignedUp[i] = false;
		g_iSignupTeam[i] = 0;
	}

	g_iSignupCount = 0;
	g_flSignupTimer = 0.0;
	g_flBlockedUntil = 0.0;
	g_bForceStart = false;
	g_szPickedMap[0] = EOS;
	g_szSponsorName[0] = EOS;
	g_iSponsorAskId = 0;
	g_bPendingMatchStart = false;
	PDS_SetCell("ai_pending_start", 0);
	g_eState = SIGNUP_IDLE;
}
g_bKeepSavedTeams = false;
	PDS_SetCell("ai_pending_start", 0);
	PDS_SetCell("ai_saved_n
stock bool:stopSignupIfEmpty() {
	if (g_iSignupCount > 0)h");
	return iNum;
}

public PDS_Save() {
	if (!g_bPendingMatchStart)
		return;

	savePendingMatch();
	saveSignupTeams();
}

stock savePendingMatch() {
	PDS_SetCell("ai_pending_start", 1);
	PDS_SetString("ai_picked_map", g_szPickedMap);
	PDS_SetCell("ai_match_rules", _:g_iMatchRules);
	PDS_SetCell("ai_sponsor_match", g_bSponsorMatch ? 1 : 0);
	PDS_SetString("ai_sponsor_name", g_szSponsorName);
	PDS_SetCell("ai_force_start", g_bForceStart ? 1 : 0);
	PDS_SetCell("ai_team_size", g_iPlaceTeamSize);
}

stock bool:isUnstableAuth(const szAuth[]) {
	if (!szAuth[0])
		return true;
	if (containi(szAuth, "BOT") != -1)
		return true;
	if (containi(szAuth, "STEAM_ID") != -1)
		return true;
	if (equali(szAuth, "STEAM_0:0:0") || equali(szAuth, "STEAM_1:0:0"))
		return true;
	return false;
}

stock getPlayerPersistId(id, szOut[], iLen) {
	new szAuth[32], szName[32];
	get_user_authid(id, szAuth, charsmax(szAuth));
	get_user_name(id, szName, charsmax(szName));

	if (is_user_bot(id) || isUnstableAuth(szAuth))
		formatex(szOut, iLen, "N:%s", szName);
	else
		copy(szOut, iLen, szAuth);
}

stock saveSignupTeams() {
	new iCount;
	for (new i = 0; i < g_iSignupCount; i++) {
		new id = g_iSignupList[i];
		if (!is_user_connected(id))
			continue;

		new iTeam = g_iSignupTeam[id];
		if (iTeam != TEAM_T && iTeam != TEAM_CT) {
			new TeamName:cur = getUserTeam(id);
			if (cur == TEAM_TERRORIST)
				iTeam = TEAM_T;
			else if (_:cur == TEAM_CT)
				iTeam = TEAM_CT;
		}
		if (iTeam != TEAM_T && iTeam != TEAM_CT)
			continue;

		new szKey[32], szId[48];
		getPlayerPersistId(id, szId, charsmax(szId));
		formatex(szKey, charsmax(szKey), "ai_saved_k%d", iCount);
		PDS_SetString(szKey, szId);
		formatex(szKey, charsmax(szKey), "ai_saved_t%d", iCount);
		PDS_SetCell(szKey, iTeam);
		iCount++;
	}
	PDS_SetCell("ai_saved_n", iCount);
	log_amx("[HNSai] saved %d signup teams before mapchange", iCount);
}

stock loadSavedTeamFor(id) {
	new iCount;
	if (!PDS_GetCell("ai_saved_n", iCount) || iCount < 1)
		return 0;

	new szId[48];
	getPlayerPersistId(id, szId, charsmax(szId));

	for (new i = 0; i < iCount; i++) {
		new szKey[32], szSaved[48], iTeam;
		formatex(szKey, charsmax(szKey), "ai_saved_k%d", i);
		if (!PDS_GetString(szKey, szSaved, charsmax(szSaved)))
			continue;
		if (!equal(szId, szSaved))
			continue;

		formatex(szKey, charsmax(szKey), "ai_saved_t%d", i);
		if (PDS_GetCell(szKey, iTeam) && (iTeam == TEAM_T || iTeam == TEAM_CT))
			return iTeam;
	}
	return 0se;

	if (g_eState != SIGNUP_OPEN && g_eState != SIGNUP_IDLE)
		return false;

	remove_task(TASK_COUNTDOWN);
	g_flSignupTimer = 0.0;

	if (g_eState == SIGNUP_OPEN)
		g_eState = SIGNUP_IDLE;

	return true;
}

stock getOnlineCount() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	return iNum;
}

stock TeamName:getUserTeam(id) {
	return get_member(id, m_iTeam);
}

stock moveToSpec(id) {
	if (is_user_alive(id))
		user_silentkill(id);

	if (getUserTeam(id) != TEAM_SPECTATOR)
		rg_set_user_team(id, TEAM_SPECTATOR);
}

stock moveToTeam(id, TeamName:iTeam) {
	if (is_user_alive(id))
		user_silentkill(id);

	rg_set_user_team(id, iTeam);
}

stock getEffectiveTeamSize() {
	new iSize;
	new iAvail = (g_iSignupCount + 1) / 2;
	if (iAvail < 1)
		iAvail = 1;

	if (g_iTeamSizeFixed > 0)
		iSize = g_iTeamSizeFixed;
	else if (g_iSignupCount >= SIGNUP_MIN)
		iSize = clamp(g_iSignupCount / 2, 3, 6);
	else if (g_bForceStart)
		iSize = iAvail;
	else
		iSize = 5;

	if ((g_bForceStart || g_iSignupCount >= SIGNUP_MIN) && iSize > iAvail)
		iSize = iAvail;

	if (g_bForceStart) {
		if (iSize < 1)
			iSize = 1;
	} else if (iSize < 3) {
		iSize = 3;
	}

	return iSize;
}

// 是否有管理员(裁判)在线
stock bool:isUserVipOrAdmin(id) {
	if (!is_user_connected(id))
		return false;

	return isUserWatcher(id) || isUserAdmin(id) || is_user_admin(id);
}

// 是否有管理员/VIP 在线
stock bool:isAdminOnline() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		if (isUserVipOrAdmin(iPlayers[i]))
			return true;
	}

	return false;
}

stock getFirstVipOrAdmin() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		if (isUserVipOrAdmin(iPlayers[i]))
			return iPlayers[i];
	}

	return 0;
}

// 已投票人数
stock countVoted() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new iVoted;
	for (new i = 0; i < iNum; i++) {
		if (g_bVoteDone[iPlayers[i]])
			iVoted++;
	}

	return iVoted;
}

// 纯随机分组: 每人独立抽 T/CT, 某队满了才进另一边 (不要 T/CT 交替)
stock shuffleTeamsNow() {
	new iSize = getEffectiveTeamSize();
	new iPool[SIGNUP_MAX], iCount;

	for (new i = 0; i < g_iSignupCount; i++)
		iPool[iCount++] = g_iSignupList[i];

	shuffleArray(iPool, iCount);

	for (new i = 0; i <= MAX_PLAYERS; i++)
		g_iSignupTeam[i] = 0;

	new iT, iCT;
	for (new i = 0; i < iCount; i++) {
		new p = iPool[i];

		if (iT >= iSize && iCT >= iSize)
			break;

		new iTeam;
		if (iT >= iSize)
			iTeam = TEAM_CT;
		else if (iCT >= iSize)
			iTeam = TEAM_T;
		else
			iTeam = random(2) ? TEAM_T : TEAM_CT;

		g_iSignupTeam[p] = iTeam;
		if (iTeam == TEAM_T)
			iT++;
		else
			iCT++;
	}
}

// [HNSai] 当前比赛模式 / 人数 / 类型 / 状态
stock ai_printModeInfo(const id) {
	ai_print(id, "当前比赛模式: ^3%s^1 | 人数: ^3%d v %d^1 | 类型: ^3%s^1 | 状态: ^3%s",
		g_szRules[_:g_iMatchRules], getEffectiveTeamSize(), getEffectiveTeamSize(),
		g_bSponsorMatch ? "赞助局" : "娱乐局", g_szStateName[_:g_eState]);
}

stock ai_print(const id, const message[], any:...) {
	new msgFormated[191];
	vformat(msgFormated, charsmax(msgFormated), message, 3);

	if (msgFormated[0] == '[')
		client_print_color(id, print_team_blue, "%s", msgFormated);
	else
		client_print_color(id, print_team_blue, "[^3HNSai^1] %s", msgFormated);
}

stock ai_lang(id, const szKey[], szOut[], iLen) {
	if (id < 1)
		id = 0;

	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0])
		copy(szOut, iLen, szKey);
}

stock ai_ruleName(id, iRule, szOut[], iLen) {
	if (iRule < 0 || iRule >= RULE_COUNT) {
		copy(szOut, iLen, g_szRules[0]);
		return;
	}

	ai_lang(id, g_szRuleKeys[iRule], szOut, iLen);
	if (!szOut[0])
		copy(szOut, iLen, g_szRules[iRule]);
}

stock getVoteTotal() {
	new iTotal;
	for (new i = 0; i < RULE_COUNT; i++)
		iTotal += g_iVoteTally[i];
	return iTotal;
}

stock bool:isSkillOrTimerRules() {
	return (g_iMatchRules == RULES_MR || g_iMatchRules == RULES_TIMER);
}

stock getVotePercent(iCount, iTotal) {
	if (iTotal <= 0)
		return 0;
	return (iCount * 100) / iTotal;
}

stock getMapVoteTotal() {
	new iTotal;
	for (new i = 0; i < g_iMapCount; i++)
		iTotal += g_iMapVoteTally[i];
	return iTotal;
}

stock bool:isMapExistLocal(const szMap[]) {
	return bool:is_map_valid(szMap);
}

stock bool:isMapSafeToLoad(const szMap[]) {
	if (!szMap[0] || !is_map_valid(szMap))
		return false;

	new szBsp[96];
	formatex(szBsp, charsmax(szBsp), "maps/%s.bsp", szMap);
	if (!file_exists(szBsp))
		return false;

	new fp = fopen(szBsp, "rb");
	if (!fp)
		return false;

	new iVersion;
	if (fread(fp, iVersion, BLOCK_INT) != BLOCK_INT || iVersion != 30) {
		fclose(fp);
		return true;
	}

	new iEntOfs, iEntLen;
	if (fread(fp, iEntOfs, BLOCK_INT) != BLOCK_INT || fread(fp, iEntLen, BLOCK_INT) != BLOCK_INT) {
		fclose(fp);
		return true;
	}

	if (iEntOfs < 124 || iEntLen <= 0 || iEntLen > 512000) {
		fclose(fp);
		return true;
	}

	if (fseek(fp, iEntOfs, SEEK_SET) != 0) {
		fclose(fp);
		return true;
	}

	new szLine[256];
	new iLeft = iEntLen;
	new bool:bSafe = true;

	while (iLeft > 0 && !feof(fp) && bSafe) {
		if (!fgets(fp, szLine, charsmax(szLine)))
			break;

		new iGot = strlen(szLine);
		if (iGot <= 0)
			break;
		iLeft -= iGot;

		new iPos = containi(szLine, "models/");
		if (iPos == -1)
			continue;

		new szModel[96];
		new iLen;
		for (iLen = 0; iLen < charsmax(szModel); iLen++) {
			new c = szLine[iPos + iLen];
			if (c <= 32 || c == '"' || c == 39 || c == ';' || c == '}' || c == '{')
				break;
			szModel[iLen] = c;
		}
		szModel[iLen] = 0;

		if (iLen >= 4 && equali(szModel[iLen - 4], ".mdl") && !file_exists(szModel, true)) {
			log_amx("[HNSai] map %s missing model %s", szMap, szModel);
			bSafe = false;
		}
	}

	fclose(fp);
	return bSafe;
}

stock loadSkillMaps() {
	loadMapPools();
}

stock addUniqueMap(szDest[][MAP_NAME_LEN], &iCount, const szMap[]) {
	if (!szMap[0] || iCount >= MAP_MAX)
		return;

	for (new i = 0; i < iCount; i++) {
		if (equali(szDest[i], szMap))
			return;
	}

	copy(szDest[iCount], MAP_NAME_LEN - 1, szMap);
	iCount++;
}

stock loadMapPools() {
	g_iSkillMapCount = 0;
	g_iBoostMapCount = 0;
	g_iMapCount = 0;
	g_iAllMapCount = 0;

	new szPath[128], szFile[160];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	formatex(szFile, charsmax(szFile), "%s/mixsystem/hns-maps.ini", szPath);

	new fp = fopen(szFile, "rt");
	if (!fp)
		return;

	new szLine[128], szMap[32], szSection[32];
	new iSection;

	while (!feof(fp)) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';')
			continue;

		if (szLine[0] == '[') {
			copy(szSection, charsmax(szSection), szLine[1]);
			replace_all(szSection, charsmax(szSection), "]", "");
			trim(szSection);
			if (equali(szSection, "skill"))
				iSection = 1;
			else if (equali(szSection, "boost"))
				iSection = 2;
			else if (equali(szSection, "knife"))
				iSection = 3;
			else
				iSection = 0;
			continue;
		}

		parse(szLine, szMap, charsmax(szMap));
		replace_all(szMap, charsmax(szMap), ".bsp", "");
		if (!szMap[0])
			continue;

		if (iSection == 1)
			addUniqueMap(g_szSkillMaps, g_iSkillMapCount, szMap);
		else if (iSection == 2)
			addUniqueMap(g_szBoostMaps, g_iBoostMapCount, szMap);

		if (iSection > 0)
			addUniqueMap(g_szAllMaps, g_iAllMapCount, szMap);
	}

	fclose(fp);
	applyActivePool();
	log_amx("[HNSai] maps loaded skill=%d boost=%d all=%d", g_iSkillMapCount, g_iBoostMapCount, g_iAllMapCount);
}

stock applyActivePool() {
	g_iMapCount = 0;

	if (g_iActivePool == POOL_SKILL && g_iSkillMapCount > 0) {
		for (new i = 0; i < g_iSkillMapCount && g_iMapCount < MAP_MAX; i++) {
			copy(g_szMapList[g_iMapCount], MAP_NAME_LEN - 1, g_szSkillMaps[i]);
			g_iMapCount++;
		}
		return;
	}

	if (g_iBoostMapCount > 0) {
		g_iActivePool = POOL_BOOST;
		for (new i = 0; i < g_iBoostMapCount && g_iMapCount < MAP_MAX; i++) {
			copy(g_szMapList[g_iMapCount], MAP_NAME_LEN - 1, g_szBoostMaps[i]);
			g_iMapCount++;
		}
		return;
	}

	if (g_iSkillMapCount > 0) {
		g_iActivePool = POOL_SKILL;
		for (new i = 0; i < g_iSkillMapCount && g_iMapCount < MAP_MAX; i++) {
			copy(g_szMapList[g_iMapCount], MAP_NAME_LEN - 1, g_szSkillMaps[i]);
			g_iMapCount++;
		}
	}
}

stock setActivePool(iPool) {
	g_iActivePool = (iPool == POOL_SKILL) ? POOL_SKILL : POOL_BOOST;
	applyActivePool();
}

public taskSignupHud() {
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

public showTypeMenu(id) {
	if (!is_user_connected(id))
		return;

	if (!isUserVipOrAdmin(id)) {
		ai_print(id, "只有管理员/VIP 才能选择比赛类型");
		showMainMenu(id);
		return;
	}

	new szTitle[64], szCasual[64], szSponsor[64], szBack[32];
	ai_lang(id, "AI_TYPE_TITLE", szTitle, charsmax(szTitle));
	ai_lang(id, "AI_TYPE_CASUAL", szCasual, charsmax(szCasual));
	ai_lang(id, "AI_TYPE_SPONSOR", szSponsor, charsmax(szSponsor));
	ai_lang(id, "AI_MENU_BACK", szBack, charsmax(szBack));

	new menu = menu_create(szTitle, "TypeMenuHandler");
	menu_additem(menu, szCasual, "casual");
	menu_additem(menu, szSponsor, "sponsor");
	menu_setprop(menu, MPROP_EXITNAME, szBack);
	menu_display(id, menu);
}

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

public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;

	ai_print(0, "分组完成, 先选择比赛模式, 再选择地图");
	showGroups(0);

	new iAdmin = getFirstVipOrAdmin();
	if (iAdmin) {
		ai_print(0, "管理员/VIP 优先选择比赛模式");
		showRulesMenu(iAdmin);
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

	new iAdmin = getFirstVipOrAdmin();
	if (iAdmin) {
		ai_print(0, "管理员/VIP 优先选择地图池 (Skill / Boost)");
		showPoolChoiceMenu(iAdmin);
		return;
	}

	startPoolVote();
}

stock offerMapChoice() {
	new iAdmin = getFirstVipOrAdmin();
	if (iAdmin) {
		showMapChoiceMenu(iAdmin);
		return;
	}

	startMapVote();
}

public showPoolChoiceMenu(id) {
	if (!is_user_connected(id))
		return;

	new szTitle[64], szSkill[64], szBoost[64];
	copy(szTitle, charsmax(szTitle), "\r选择地图池");
	ai_lang(id, "AI_POOL_SKILL", szSkill, charsmax(szSkill));
	ai_lang(id, "AI_POOL_BOOST", szBoost, charsmax(szBoost));

	new menu = menu_create(szTitle, "PoolChoiceHandler");
	menu_additem(menu, szSkill, "skill");
	menu_additem(menu, szBoost, "boost");
	menu_display(id, menu);
}

public PoolChoiceHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (g_bPostGroupSetup)
			showPoolChoiceMenu(id);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id) || !g_bPostGroupSetup)
		return PLUGIN_HANDLED;

	if (equal(data, "boost"))
		setActivePool(POOL_BOOST);
	else
		setActivePool(POOL_SKILL);

	ai_print(0, "地图池已设为: ^3%s", g_iActivePool == POOL_SKILL ? "Skill" : "Boost");
	showMapChoiceMenu(id);
	return PLUGIN_HANDLED;
}

public startPoolVote() {
	if (g_bVoteActive)
		return;

	g_bVoteActive = true;
	g_eVoteKind = VOTE_POOL;
	g_iVoteSeconds = VOTE_TIME;
	g_iPoolVoteTally[0] = 0;
	g_iPoolVoteTally[1] = 0;

	for (new i = 0; i <= MAX_PLAYERS; i++)
		g_bVoteDone[i] = false;

	ai_print(0, "开始投票选择 Skill / Boost 地图池 (^3%d^1 秒)", g_iVoteSeconds);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		showPoolVoteMenu(iPlayers[i]);

	set_task(1.0, "taskVote", TASK_VOTE, .flags = "b");
}

public showPoolVoteMenu(id) {
	if (!g_bVoteActive || g_eVoteKind != VOTE_POOL || !is_user_connected(id))
		return;

	new szTitle[192], szSkill[64], szBoost[64], szSkip[32], szItem[96];
	ai_lang(id, "AI_VOTE_POOL_TITLE", szTitle, charsmax(szTitle));
	format(szTitle, charsmax(szTitle), szTitle, g_iVoteSeconds, countVoted(), getOnlineCount());
	ai_lang(id, "AI_POOL_SKILL", szSkill, charsmax(szSkill));
	ai_lang(id, "AI_POOL_BOOST", szBoost, charsmax(szBoost));
	ai_lang(id, "AI_VOTE_SKIP", szSkip, charsmax(szSkip));

	new iTotal = g_iPoolVoteTally[0] + g_iPoolVoteTally[1];
	new menu = menu_create(szTitle, "PoolVoteHandler");

	formatex(szItem, charsmax(szItem), "%s \r[%d%%]", szSkill, getVotePercent(g_iPoolVoteTally[0], iTotal));
	menu_additem(menu, szItem, "pool_0");
	formatex(szItem, charsmax(szItem), "%s \r[%d%%]", szBoost, getVotePercent(g_iPoolVoteTally[1], iTotal));
	menu_additem(menu, szItem, "pool_1");

	menu_setprop(menu, MPROP_EXITNAME, szSkip);
	menu_display(id, menu);
}

public PoolVoteHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!g_bVoteActive || g_eVoteKind != VOTE_POOL)
		return PLUGIN_HANDLED;

	if (g_bVoteDone[id]) {
		ai_print(id, "你已经投过票了");
		return PLUGIN_HANDLED;
	}

	new iPool = str_to_num(data[5]);
	if (iPool < 0 || iPool > 1)
		return PLUGIN_HANDLED;

	g_bVoteDone[id] = true;
	g_iPoolVoteTally[iPool]++;

	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	ai_print(0, "%s 投票地图池: ^3%s", szName, iPool == POOL_SKILL ? "Skill" : "Boost");
	checkVoteDone();
	return PLUGIN_HANDLED;
}

public finishPoolVote() {
	if (!g_bVoteActive)
		return;

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	remove_task(TASK_VOTE);

	new iPool = POOL_SKILL;
	if (g_iPoolVoteTally[POOL_BOOST] > g_iPoolVoteTally[POOL_SKILL])
		iPool = POOL_BOOST;
	else if (g_iPoolVoteTally[POOL_BOOST] <= 0 && g_iPoolVoteTally[POOL_SKILL] <= 0)
		iPool = POOL_SKILL;

	setActivePool(iPool);
	ai_print(0, "地图池投票结束: ^3%s^1 (Skill %d / Boost %d)",
		g_iActivePool == POOL_SKILL ? "Skill" : "Boost",
		g_iPoolVoteTally[POOL_SKILL], g_iPoolVoteTally[POOL_BOOST]);

	offerMapChoice();
}

public showMapChoiceMenu(id) {
	if (!is_user_connected(id))
		return;

	new szTitle[64], szRandom[64], szVote[64], szPick[64], szCurrent[64], szCurMap[32];
	ai_lang(id, "AI_MAP_TITLE", szTitle, charsmax(szTitle));
	ai_lang(id, "AI_MAP_RANDOM", szRandom, charsmax(szRandom));
	ai_lang(id, "AI_MAP_VOTE", szVote, charsmax(szVote));
	ai_lang(id, "AI_MAP_PICK", szPick, charsmax(szPick));
	ai_lang(id, "AI_MAP_CURRENT", szCurrent, charsmax(szCurrent));
	get_mapname(szCurMap, charsmax(szCurMap));
	format(szCurrent, charsmax(szCurrent), szCurrent, szCurMap);

	new menu = menu_create(szTitle, "MapChoiceHandler");
	menu_additem(menu, szRandom, "random");
	menu_additem(menu, szVote, "vote");
	menu_additem(menu, szPick, "pick");
	menu_additem(menu, szCurrent, "current");
	menu_display(id, menu);
}

public MapChoiceHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (g_bPostGroupSetup)
			showMapChoiceMenu(id);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id) || !g_bPostGroupSetup)
		return PLUGIN_HANDLED;

	if (equal(data, "random")) {
		pickRandomMap();
		ai_print(0, "地图已随机选择: ^3%s", g_szPickedMap);
		afterMapChosen();
	} else if (equal(data, "vote")) {
		ai_print(0, "管理员发起地图投票");
		startMapVote();
	} else if (equal(data, "current")) {
		get_mapname(g_szPickedMap, charsmax(g_szPickedMap));
		ai_print(0, "使用当前地图: ^3%s", g_szPickedMap);
		afterMapChosen();
	} else {
		showMapPickMenu(id);
	}

	return PLUGIN_HANDLED;
}

public showMapPickMenu(id) {
	if (!is_user_connected(id))
		return;

	if (g_iAllMapCount <= 0)
		loadMapPools();

	new szTitle[64];
	ai_lang(id, "AI_MAP_LIST_TITLE", szTitle, charsmax(szTitle));
	format(szTitle, charsmax(szTitle), "%s \y(%d)", szTitle, g_iAllMapCount);
	new menu = menu_create(szTitle, "MapPickHandler");

	for (new i = 0; i < g_iAllMapCount; i++) {
		new szItem[64], szData[16];
		if (!isMapExistLocal(g_szAllMaps[i]))
			formatex(szItem, charsmax(szItem), "%s \d(缺文件)", g_szAllMaps[i]);
		else
			copy(szItem, charsmax(szItem), g_szAllMaps[i]);
		formatex(szData, charsmax(szData), "m_%d", i);
		menu_additem(menu, szItem, szData);
	}

	menu_setprop(menu, MPROP_PERPAGE, 7);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_NEXTNAME, "下一页");
	menu_setprop(menu, MPROP_BACKNAME, "上一页");
	menu_setprop(menu, MPROP_EXITNAME, "返回");
	menu_display(id, menu);
}

public MapPickHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (g_bPostGroupSetup)
			showMapChoiceMenu(id);
		return PLUGIN_HANDLED;
	}

	if (item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	new iMap = str_to_num(data[2]);
	if (iMap < 0 || iMap >= g_iAllMapCount)
		return PLUGIN_HANDLED;

	if (!isMapSafeToLoad(g_szAllMaps[iMap])) {
		ai_print(id, "地图 ^3%s^1 缺少模型或文件, 请换一张", g_szAllMaps[iMap]);
		showMapPickMenu(id);
		return PLUGIN_HANDLED;
	}

	copy(g_szPickedMap, charsmax(g_szPickedMap), g_szAllMaps[iMap]);
	ai_print(0, "指定地图: ^3%s", g_szPickedMap);
	afterMapChosen();
	return PLUGIN_HANDLED;
}

stock pickRandomMap() {
	if (g_iMapCount <= 0)
		loadMapPools();

	if (g_iMapCount <= 0) {
		get_mapname(g_szPickedMap, charsmax(g_szPickedMap));
		return;
	}

	new iStart = random(g_iMapCount);
	for (new i = 0; i < g_iMapCount; i++) {
		new iIdx = (iStart + i) % g_iMapCount;
		if (isMapSafeToLoad(g_szMapList[iIdx])) {
			copy(g_szPickedMap, charsmax(g_szPickedMap), g_szMapList[iIdx]);
			return;
		}
	}

	get_mapname(g_szPickedMap, charsmax(g_szPickedMap));
	log_amx("[HNSai] no safe map in current pool, stay on %s", g_szPickedMap);
}

public startMapVote() {
	if (g_bVoteActive)
		return;

	if (g_iMapCount <= 0)
		loadMapPools();

	if (g_iMapCount <= 0) {
		get_mapname(g_szPickedMap, charsmax(g_szPickedMap));
		afterMapChosen();
		return;
	}

	g_bVoteActive = true;
	g_eVoteKind = VOTE_MAP;
	g_iVoteSeconds = VOTE_TIME;

	for (new i = 0; i < MAP_MAX; i++)
		g_iMapVoteTally[i] = 0;
	for (new i = 0; i <= MAX_PLAYERS; i++) {
		g_bVoteDone[i] = false;
		g_iMapVoteChoice[i] = -1;
	}

	ai_print(0, "开始地图投票 (^3%d^1 秒)", g_iVoteSeconds);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		showMapVoteMenu(iPlayers[i]);

	set_task(1.0, "taskVote", TASK_VOTE, .flags = "b");
}

public showMapVoteMenu(id) {
	if (!g_bVoteActive || g_eVoteKind != VOTE_MAP || !is_user_connected(id))
		return;

	new szTitle[128];
	ai_lang(id, "AI_VOTE_MAP_TITLE", szTitle, charsmax(szTitle));
	format(szTitle, charsmax(szTitle), szTitle, g_iVoteSeconds, countVoted(), getOnlineCount());

	new menu = menu_create(szTitle, "MapVoteHandler");
	new iTotal = getMapVoteTotal();
	for (new i = 0; i < g_iMapCount; i++) {
		new szItem[96], szData[16];
		formatex(szItem, charsmax(szItem), "%s \r[%d%%]", g_szMapList[i], getVotePercent(g_iMapVoteTally[i], iTotal));
		formatex(szData, charsmax(szData), "mv_%d", i);
		menu_additem(menu, szItem, szData);
	}

	menu_setprop(menu, MPROP_PERPAGE, 7);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_NEXTNAME, "下一页");
	menu_setprop(menu, MPROP_BACKNAME, "上一页");
	menu_setprop(menu, MPROP_EXITNAME, "跳过");
	menu_display(id, menu);
}

public MapVoteHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!g_bVoteActive || g_eVoteKind != VOTE_MAP)
		return PLUGIN_HANDLED;

	if (g_bVoteDone[id]) {
		ai_print(id, "你已经投过票了");
		return PLUGIN_HANDLED;
	}

	new iMap = str_to_num(data[3]);
	if (iMap < 0 || iMap >= g_iMapCount)
		return PLUGIN_HANDLED;

	g_bVoteDone[id] = true;
	g_iMapVoteTally[iMap]++;
	g_iMapVoteChoice[id] = iMap;

	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	ai_print(0, "%s 投票地图: ^3%s", szName, g_szMapList[iMap]);
	checkVoteDone();
	return PLUGIN_HANDLED;
}

public finishMapVote() {
	if (!g_bVoteActive)
		return;

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	remove_task(TASK_VOTE);

	new iBest, iBestCount = -1;
	for (new i = 0; i < g_iMapCount; i++) {
		if (g_iMapVoteTally[i] > iBestCount) {
			iBestCount = g_iMapVoteTally[i];
			iBest = i;
		}
	}

	if (iBestCount <= 0) {
		pickRandomMap();
		ai_print(0, "地图投票无人投票, 随机选择 ^3%s", g_szPickedMap);
	} else if (!isMapSafeToLoad(g_szMapList[iBest])) {
		ai_print(0, "地图 ^3%s^1 缺少模型, 改随机安全图", g_szMapList[iBest]);
		pickRandomMap();
	} else {
		copy(g_szPickedMap, charsmax(g_szPickedMap), g_szMapList[iBest]);
		ai_print(0, "地图投票结束: ^3%s^1 (%d 票)", g_szPickedMap, iBestCount);
	}

	afterMapChosen();
}

public afterMapChosen() {
	if (g_bSponsorMatch)
		beginSponsorInput();
	else
		startMatch();
}

public beginSponsorInput() {
	new iAdmin = getFirstVipOrAdmin();
	if (!iAdmin) {
		ai_print(0, "赞助局没有管理员/VIP 在线, 跳过赞助者填写");
		startMatch();
		return;
	}

	g_bWaitingSponsor = true;
	g_iSponsorAskId = iAdmin;
	g_bSponsorNameInput[iAdmin] = true;
	ai_print(0, "请管理员/VIP 在聊天框输入赞助者名字 (剩余 %d 秒, /取消)", floatround(SPONSOR_WAIT));
	client_cmd(iAdmin, "messagemode");
	set_task(SPONSOR_WAIT, "taskSponsorTimeout", TASK_SPONSOR_WAIT);
}

public taskSponsorTimeout() {
	if (!g_bWaitingSponsor)
		return;

	g_bWaitingSponsor = false;
	if (g_iSponsorAskId)
		g_bSponsorNameInput[g_iSponsorAskId] = false;

	ai_print(0, "赞助者填写超时, 继续开赛");
	startMatch();
}

public aiSayHandle(id) {
	if (!g_bSponsorNameInput[id])
		return PLUGIN_CONTINUE;

	new szArgs[64];
	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);

	g_bSponsorNameInput[id] = false;
	g_bWaitingSponsor = false;
	remove_task(TASK_SPONSOR_WAIT);

	if (!szArgs[0] || szArgs[0] == '/') {
		ai_print(id, "已取消填写赞助者名字");
		if (g_bPostGroupSetup)
			startMatch();
		return PLUGIN_HANDLED;
	}

	copy(g_szSponsorName, charsmax(g_szSponsorName), szArgs);
	replace_all(g_szSponsorName, charsmax(g_szSponsorName), "%", "");
	hns_external_set_sponsor_name(g_szSponsorName);
	ai_print(0, "赞助者: ^3%s", g_szSponsorName);

	if (g_bPostGroupSetup)
		startMatch();

	return PLUGIN_HANDLED;
}

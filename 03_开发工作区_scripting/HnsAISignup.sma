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
//   报名中(5分钟倒计时) -> 收团(只分一次队, 换图前不拉观战) -> 选模式/地图
//   -> 换图后等 30 秒核对 SteamID -> 确认报名玩家后拉观战 -> 按换图前分组上场 -> 开赛
//   比赛结束 -> 清除报名 + 20 秒报名 CD
//   比赛终止 -> 清除报名
// ============================================================

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <sqlx>
#include <nvault>
#include <hns_matchsystem>
#include <hns_matchsystem_pts>
#include <hns_matchsystem_sql>
#include <hns_optional_sql>
#include <hns_language>
#include <PersistentDataStorage>

#define PLUGIN_VERSION "1.19"

// ---------------- 常量 ----------------
#define SIGNUP_MIN         6        // 最少 6 人 (3v3)
#define SIGNUP_MAX         12       // 最多 12 人 (6v6)
#define SIGNUP_TIMER       300.0    // 报名 5 分钟倒计时 (人满会提前收团)
#define SIGNUP_CD          20.0     // 比赛结束报名冷却
#define MAP_CHANGE_WAIT    30.0     // 换图后等 30 秒核对报名玩家, 再拉观战
#define PLACE_SPEC_WAIT    5.0      // 拉观战后先等 5 秒, 再开始上场
#define PLACE_INTERVAL     1.0      // 1 秒 1 人上场

#define TASK_COUNTDOWN     92001
#define TASK_PLACE         92002
#define TASK_AFTER_MAP     92003
#define TASK_VOTE          92004
#define TASK_SIGNUP_HUD    92005
#define TASK_SPONSOR_WAIT  92006
#define TASK_SPONSOR_GC    92010
#define TASK_MAP_WAIT      92007
#define TASK_SETUP_MENU    92008
#define TASK_PLACE_DELAY   92009
#define TASK_SPEC_JOIN     92100    // +playerid: 处死后延迟进观战
#define TASK_RANDOM_MAP    92011    // 随机地图 10 秒后才换图

#define RULE_COUNT         4
#define POOL_SKILL         0
#define POOL_BOOST         1

#define VOTE_TIME          20       // 比赛模式/地图投票时长 (秒)
#define RANDOM_MAP_WAIT    10       // 随机地图先聊天提示, 10 秒后才换图
#define MAP_MAX            256
#define MAP_NAME_LEN       32
#define SPONSOR_WAIT       30.0     // 赞助者输入等待 (秒)

#define TEAM_T             1
#define TEAM_CT            2

#define PTS_WIN            15
#define PTS_LOSS           10
#define PTS_BASE           50

native hns_obc_knife_bonus(id);

// ---------------- 全局变量 ----------------
enum SIGNUP_STATE {
	SIGNUP_IDLE,     // 待命
	SIGNUP_OPEN,     // 报名中
	SIGNUP_CLOSE,    // 收团/换图后等人 (不重新分队)
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
new g_iGuestRetry[MAX_PLAYERS + 1];
new bool:g_bGuestSchema;
#define TASK_GUEST_CHECK 93000

new g_szLastMap[32];

// ---------------- 参赛菜单 / 管理模式 ----------------
new const g_szRules[RULE_COUNT][] = { "MR制", "计时制", "决斗制", "回合制" };
new const g_szStateName[5][] = { "待命", "报名中", "收团分配", "赛前选择", "比赛中" };
new const g_szRuleKeys[RULE_COUNT][] = { "AI_RULE_MR", "AI_RULE_TIMER", "AI_RULE_DUEL", "AI_RULE_ROUNDS" };
new const g_szStateKeys[5][] = { "AI_STATE_IDLE", "AI_STATE_OPEN", "AI_STATE_CLOSE", "AI_STATE_SETUP", "AI_STATE_RUNNING" };

new NATCH_RULES:g_iMatchRules = RULES_MR;   // 当前选择的比赛规则
new g_iTeamSizeFixed;                       // 0 = 自动(按报名人数), 3..6 = 固定人数
new bool:g_bForceStart;                     // 管理员强制开赛: 允许 1 人测试
new g_iAiMenuPage[MAX_PLAYERS + 1];         // 报名菜单页: 1 或 2
new bool:g_bSignupMenuOpen[MAX_PLAYERS + 1]; // 当前是否正打开报名菜单
new bool:g_bPtsLimit;                       // PTS 积分限制, 默认关闭
new g_iPtsLimit = 50;                       // 开启后的最低 OBC
new bool:g_bPtsBalance;                     // 按 PTS/胜率/场数平衡分组, 默认关闭
new g_iBalanceMode = 1;                     // 0 关 / 1 自动 / 2 严格 / 3 宽松

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
new bool:g_bWaitingSponsorGc;               // 等待选择 GBIC 金币
new g_iSponsorAskId;
new g_szSponsorName[33];
new g_iSponsorGC;
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
new bool:g_bLevelChanging;
new bool:g_bMapWaitActive;
new g_iMapWaitSeconds;
new bool:g_bKeepSavedTeams;          // 换图恢复: 保留原 T/CT, 不再随机
new bool:g_bPlayersPlaced;           // 已经按分组送上场
new g_iSetupMenuTries;               // 收团后重试弹赛前菜单
new bool:g_bRandomMapWait;           // 随机地图倒计时中, /nomaps 可取消
new g_iRandomMapSeconds;

// ============================================================
//  插件初始化
// ============================================================
public plugin_natives() {
	hns_register_optional_sql();
	register_library("hns_ai_signup");
	register_native("hns_ai_force_signup", "native_force_signup");
	register_native("hns_ai_get_state", "native_get_state");
	register_native("hns_ai_get_team_size", "native_get_team_size");
	register_native("hns_ai_set_team_size", "native_set_team_size");
}

public plugin_init() {
	register_plugin("AI 报名系统", PLUGIN_VERSION, "HNSai");

	RegisterSayCmd("signup", "报", "cmdSignupMenu", 0, "AI 报名");
	RegisterSayCmd("cancel", "退", "cmdCancel", 0, "取消报名");
	RegisterSayCmd("aistart", "开赛", "cmdAiStart", -1, "强制收团开赛");
	RegisterSayCmd("aitype", "赛制", "cmdAiType", -1, "设置比赛类型 0娱乐/1赞助");
	RegisterSayCmd("nomaps", "不换图", "cmdNoMaps", 0, "取消随机换图");
	RegisterSayCmd("aiabort", "停赛", "cmdAiAbort", -1, "取消报名");
	RegisterSayCmd("aivote", "投", "cmdAiVote", 0, "比赛模式投票");

	register_clcmd("say", "aiSayHandle");
	register_clcmd("say_team", "aiSayHandle");
	register_menucmd(register_menuid("AISignupMenu"), 1023, "AiSignupMenuHandler");

	RegisterHookChain(RG_ShowVGUIMenu, "hcShowVGUIMenu", false);
	RegisterHookChain(RG_ShowMenu, "hcShowMenu", false);
	// 对齐 10.6: 不挂 FM_ChangeLevel, 换图清理只走 plugin_end。

	get_mapname(g_szLastMap, charsmax(g_szLastMap));
	loadMapPools();
}

public hcShowVGUIMenu(const id, VGUIMenu:menuType) {
	if (!shouldBlockGameMenu())
		return HC_CONTINUE;

	if (menuType == VGUI_Menu_Team || menuType == VGUI_Menu_Class_T || menuType == VGUI_Menu_Class_CT) {
		set_member(id, m_iMenu, Menu_OFF);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public hcShowMenu(const id, const keys, const time, const needMore, const menu[]) {
	if (is_user_connected(id) && g_bSignupMenuOpen[id] && !equal(menu, "AISignupMenu"))
		g_bSignupMenuOpen[id] = false;

	if (!shouldBlockGameMenu())
		return HC_CONTINUE;

	new szText[32];
	copy(szText, charsmax(szText), menu);
	if (containi(szText, "Team_Select") != -1 || containi(szText, "Terrorist_Select") != -1 || containi(szText, "CT_Select") != -1) {
		set_member(id, m_iMenu, Menu_OFF);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

stock bool:shouldBlockGameMenu() {
	// 换图后等人期间不拦选队, 否则会出现观战 UI 但记分板已是 CT
	if (g_bMapWaitActive)
		return false;
	return (g_eState == SIGNUP_CLOSE || g_eState == SIGNUP_SETUP);
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

stock ai_stop_for_level_change() {
	g_bLevelChanging = true;
	remove_task(TASK_COUNTDOWN);
	remove_task(TASK_PLACE);
	remove_task(TASK_PLACE_DELAY);
	remove_task(TASK_AFTER_MAP);
	remove_task(TASK_VOTE);
	remove_task(TASK_SIGNUP_HUD);
	remove_task(TASK_SPONSOR_WAIT);
	remove_task(TASK_SPONSOR_GC);
	remove_task(TASK_MAP_WAIT);
	remove_task(TASK_SETUP_MENU);
	remove_task(TASK_RANDOM_MAP);
	clearSpecJoinTasks();
}

public plugin_end() {
	// 对齐 10.6: 不在 FM_ChangeLevel 里清理, 只在卸载时停任务。
	ai_stop_for_level_change();
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
		`pts` INT(11) NOT NULL DEFAULT 50, \
		`obc_ready` TINYINT NOT NULL DEFAULT 1 \
	);");
	SQL_ThreadQuery(g_hSqlTuple, "cbGuestDropIp", "ALTER TABLE `hns_ai_guest` DROP INDEX `ip`");
}

public cbGuestDropIp(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (g_hSqlTuple == Empty_Handle)
		return;
	SQL_ThreadQuery(g_hSqlTuple, "cbGuestNameKey", "ALTER TABLE `hns_ai_guest` ADD UNIQUE KEY `uk_name` (`name`)");
}

public cbGuestNameKey(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	g_bGuestSchema = true;
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id) && g_bGuest[id] && !g_iGuestId[id])
			guestSqlRegister(id);
	}
	if (g_hSqlTuple != Empty_Handle)
		SQL_ThreadQuery(g_hSqlTuple, "cbGuestPtsReady", "ALTER TABLE `hns_ai_guest_pts` ADD COLUMN `obc_ready` TINYINT NOT NULL DEFAULT 0");
}

public cbGuestPtsReady(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (g_hSqlTuple == Empty_Handle)
		return;
	SQL_ThreadQuery(g_hSqlTuple, "cbVoid", "ALTER TABLE `hns_ai_guest_pts` ALTER COLUMN `pts` SET DEFAULT 50");
	SQL_ThreadQuery(g_hSqlTuple, "cbVoid", "UPDATE `hns_ai_guest_pts` SET `pts`=GREATEST(50 + `wins`*15 - `loss`*10, 0), `obc_ready`=1 WHERE `obc_ready`=0");
}

public cbVoid(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	if (failstate) {
		log_amx("HNSai SQL 失败: %s", error);
	}
}

stock bool:isGuestPlayer(id) {
	new szAuth[32];
	get_user_authid(id, szAuth, charsmax(szAuth));

	if (!szAuth[0])
		return true;
	if (containi(szAuth, "STEAM_ID") != -1)
		return true;
	if (containi(szAuth, "PENDING") != -1)
		return true;
	if (containi(szAuth, "BOT") != -1)
		return true;
	if (equali(szAuth, "STEAM_0:0:0") || equali(szAuth, "STEAM_1:0:0"))
		return true;

	if (has_reunion()) {
		new client_auth_type:t = REU_GetAuthtype(id);
		if (t == CA_TYPE_NONE)
			return false;
		if (t != CA_TYPE_STEAM && t != CA_TYPE_HLTV)
			return true;
	}

	return false;
}

stock Local_GuestInit() {
	if (g_iGuestVault == INVALID_HANDLE)
		g_iGuestVault = nvault_open("hns_ai_guest");
}

public client_putinserver(id) {
	g_iGuestRetry[id] = 0;
	g_bGuest[id] = false;
	g_iGuestId[id] = 0;
	set_task(1.0, "taskGuestCheck", id + TASK_GUEST_CHECK);
}

public taskGuestCheck(taskid) {
	new id = taskid - TASK_GUEST_CHECK;
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	if (has_reunion() && REU_GetAuthtype(id) == CA_TYPE_NONE && g_iGuestRetry[id] < 20) {
		g_iGuestRetry[id]++;
		set_task(0.5, "taskGuestCheck", taskid);
		return;
	}
	if (isGuestPlayer(id)) {
		g_bGuest[id] = true;
		guestSqlRegister(id);
	} else {
		g_bGuest[id] = false;
		g_iGuestId[id] = 0;
	}
}

// 盗版按名字登记, 不使用 IP。
stock guestSqlRegister(id) {
	if (!g_bSqlReady || g_hSqlTuple == Empty_Handle) {
		Local_GuestInit();
		g_iGuestId[id] = 1;
		return;
	}
	if (!g_bGuestSchema) {
		set_task(1.0, "taskGuestCheck", id + TASK_GUEST_CHECK);
		return;
	}

	new szName[32], szSafe[96];
	get_user_name(id, szName, charsmax(szName));
	if (!szName[0])
		copy(szName, charsmax(szName), "unnamed");
	// SQL_QuoteString 第一个参数仅用于本地化, 传 tuple 句柄会报 Invalid database handle
	SQL_QuoteString(Empty_Handle, szSafe, charsmax(szSafe), szName);

	new szQuery[256];
	formatex(szQuery, charsmax(szQuery),
		"INSERT INTO `hns_ai_guest` (name, ip, lastconnect) VALUES ('%s','',%d) \
		ON DUPLICATE KEY UPDATE lastconnect=VALUES(lastconnect)",
		szSafe, get_systime());

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

	new szName[32], szSafe[96];
	get_user_name(id, szName, charsmax(szName));
	if (!szName[0])
		copy(szName, charsmax(szName), "unnamed");
	SQL_QuoteString(Empty_Handle, szSafe, charsmax(szSafe), szName);

	new szQuery[192];
	formatex(szQuery, charsmax(szQuery), "SELECT `id` FROM `hns_ai_guest` WHERE `name`='%s' ORDER BY `id` ASC LIMIT 1", szSafe);

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
stock bool:canOpenMenu(id) {
	if (hns_get_state() == STATE_PAUSED) {
		ai_print_lang(id, "AI_CHAT_ERR_PAUSED_MENU", "比赛暂停中, 无法打开参赛菜单");
		return false;
	}

	new iMode = hns_get_mode();
	if (iMode != MODE_TRAINING && iMode != MODE_LOBBY) {
		ai_print_lang(id, "AI_CHAT_ERR_MODE_MENU", "只有训练/大厅模式才能打开参赛菜单");
		return false;
	}

	if (g_eState == MATCH_RUNNING) {
		ai_print_lang(id, "AI_CHAT_ERR_MATCH_MENU", "比赛进行中, 无法打开参赛菜单");
		return false;
	}
	if (g_eState == SIGNUP_SETUP) {
		ai_print_lang(id, "AI_CHAT_ERR_SETUP_MENU", "正在选择比赛模式/地图, 请稍候");
		return false;
	}

	return true;
}

stock bool:canSignup(id, bool:bSilent = false) {
	if (g_eState == SIGNUP_CLOSE) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_CLOSE_WAIT", "正在收团分配队伍, 请稍候");
		return false;
	}
	if (g_eState == MATCH_RUNNING || g_eState == SIGNUP_SETUP) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_MATCH_SIGNUP", "比赛正在进行中, 无法报名");
		return false;
	}
	if (hns_get_state() == STATE_PAUSED) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_PAUSED_SIGNUP", "比赛暂停中, 无法报名");
		return false;
	}

	new iMode = hns_get_mode();
	if (iMode != MODE_TRAINING && iMode != MODE_LOBBY) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_MODE_SIGNUP", "只有训练/大厅模式才能报名");
		return false;
	}

	new Float:flRemain = g_flBlockedUntil - get_gametime();
	if (flRemain > 0.0) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_COOLDOWN", "报名冷却中, 剩余 %d 秒", floatround(flRemain, floatround_ceil));
		return false;
	}

	if (g_bSponsorMatch && isGuestPlayer(id)) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_GUEST_SPONSOR", "盗版玩家不能参与赞助局");
		return false;
	}

	if (g_bPtsLimit && !passesPtsLimit(id)) {
		if (!bSilent)
			ai_print_lang(id, "AI_CHAT_ERR_PTS_LIMIT", "OBS不足, 报名需要 %d 分 (当前 %d)", g_iPtsLimit, getPlayerPts(id));
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

	if (g_eState == SIGNUP_SETUP) {
		closeGameMenu(id);
		if (isUserVipOrAdmin(id)) {
			showSetupMenu(id);
			return PLUGIN_HANDLED;
		}
		if (g_bVoteActive) {
			reopenActiveVoteMenu(id);
			return PLUGIN_HANDLED;
		}
		ai_print_lang(id, "AI_CHAT_ERR_SETUP_WAIT", "管理员正在选择比赛模式/地图, 请稍候");
		return PLUGIN_HANDLED;
	}

	if (!canOpenMenu(id))
		return PLUGIN_HANDLED;

	// 打开菜单即播报当前比赛状态
	ai_printModeInfo(id);
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showMainMenu(id) {
	new szMenu[1024], szTitle[192], szItem[160], szTmp[64], szLabel[64], szState[32];
	new szNext[32], szBack[32];
	new iLen, iNeed, iKeys;

	if (!is_user_connected(id))
		return;

	g_bSignupMenuOpen[id] = true;
	g_iAiMenuPage[id] = 1;
	ai_lang(id, "AI_TYPE_SPONSOR", szTmp, charsmax(szTmp));
	if (!g_bSponsorMatch)
		ai_lang(id, "AI_TYPE_CASUAL", szTmp, charsmax(szTmp));
	ai_lang(id, "AI_MENU_TITLE", szTitle, charsmax(szTitle));
	// AI_MENU_TITLE = ...[%s]...%d...%d → type + signup + online
	format(szTitle, charsmax(szTitle), szTitle, szTmp, g_iSignupCount, getOnlineCount());
	iLen = formatex(szMenu, charsmax(szMenu), "%s^n", szTitle);

	iNeed = getSignupNeed();
	ai_lang(id, g_bSignedUp[id] ? "AI_MENU_CANCEL" : "AI_MENU_SIGNUP", szLabel, charsmax(szLabel));
	formatex(szItem, charsmax(szItem), "%s \r[%d/%d]", szLabel, g_iSignupCount, iNeed);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. %s^n", szItem);

	ai_lang(id, "AI_MENU_GROUP", szLabel, charsmax(szLabel));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n^n", szLabel);

	ai_lang(id, "AI_MENU_RULES", szLabel, charsmax(szLabel));
	ai_ruleName(id, _:g_iMatchRules, szTmp, charsmax(szTmp));
	if (isUserVipOrAdmin(id))
		formatex(szItem, charsmax(szItem), "\y%s \y[%s]", szLabel, szTmp);
	else
		formatex(szItem, charsmax(szItem), "\d%s \d[%s]", szLabel, szTmp);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. %s^n", szItem);

	ai_lang(id, "AI_MENU_FORCE", szLabel, charsmax(szLabel));
	if (isUserAdmin(id))
		formatex(szItem, charsmax(szItem), "\r%s", szLabel);
	else
		formatex(szItem, charsmax(szItem), "\d%s", szLabel);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. %s^n", szItem);

	ai_lang(id, "AI_MENU_RESHUFFLE", szLabel, charsmax(szLabel));
	if (isUserVipOrAdmin(id))
		formatex(szItem, charsmax(szItem), "\y%s", szLabel);
	else
		formatex(szItem, charsmax(szItem), "\d%s", szLabel);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. %s^n^n", szItem);

	ai_lang(id, "AI_MENU_PTS", szLabel, charsmax(szLabel));
	if (g_bPtsLimit)
		formatex(szState, charsmax(szState), "%d", g_iPtsLimit);
	else
		ai_lang(id, "AI_MENU_PTS_OFF", szState, charsmax(szState));
	formatex(szItem, charsmax(szItem), "\d%s \d[%s]", szLabel, szState);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. %s^n", szItem);

	ai_lang(id, "AI_MENU_SIZE", szLabel, charsmax(szLabel));
	formatex(szItem, charsmax(szItem), "\y%s \y[%d vs %d]", szLabel, getEffectiveTeamSize(), getEffectiveTeamSize());
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. %s^n", szItem);

	ai_lang(id, "AI_MENU_SQL", szLabel, charsmax(szLabel));
	if (isUserAdmin(id)) {
		ai_lang(id, g_bSqlReady ? "AI_MENU_SQL_ON" : "AI_MENU_SQL_OFF", szState, charsmax(szState));
		formatex(szItem, charsmax(szItem), "\y%s \y[%s]", szLabel, szState);
	} else {
		formatex(szItem, charsmax(szItem), "\d%s", szLabel);
	}
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. %s^n^n", szItem);

	ai_lang(id, "AI_MENU_NEXT", szNext, charsmax(szNext));
	ai_lang(id, "AI_MENU_BACK", szBack, charsmax(szBack));
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%s^n\r0. \w%s", szNext, szBack);

	iKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0;
	show_menu(id, iKeys, szMenu, -1, "AISignupMenu");
}

public showMainMenu2(id) {
	new szMenu[768], szTitle[128], szItem[160], szLabel[64], szState[32], szBack[32];
	new iLen;

	if (!is_user_connected(id))
		return;
	g_bSignupMenuOpen[id] = true;

	g_iAiMenuPage[id] = 2;
	ai_lang(id, "AI_MENU_TITLE_2", szTitle, charsmax(szTitle));
	iLen = formatex(szMenu, charsmax(szMenu), "%s^n", szTitle);

	ai_lang(id, "AI_MENU_MATCH", szLabel, charsmax(szLabel));
	ai_lang(id, g_bSponsorMatch ? "AI_MATCH_SPONSOR" : "AI_MATCH_CASUAL", szState, charsmax(szState));
	if (!szState[0] || contain(szState, "AI_MATCH_") != -1)
		copy(szState, charsmax(szState), g_bSponsorMatch ? "赞助" : "娱乐");
	if (isUserVipOrAdmin(id))
		formatex(szItem, charsmax(szItem), "\y%s \y[%s]", szLabel, szState);
	else
		formatex(szItem, charsmax(szItem), "\d%s \d[%s]", szLabel, szState);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. %s^n", szItem);

	ai_lang(id, "AI_MENU_POOL", szLabel, charsmax(szLabel));
	if (!szLabel[0] || contain(szLabel, "AI_MENU_POOL") != -1)
		copy(szLabel, charsmax(szLabel), "当前地图池");
	ai_poolName(id, g_iActivePool, szState, charsmax(szState));
	if (isUserVipOrAdmin(id))
		formatex(szItem, charsmax(szItem), "\y%s \y[%s]", szLabel, szState);
	else
		formatex(szItem, charsmax(szItem), "\d%s \d[%s]", szLabel, szState);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. %s^n^n", szItem);

	ai_lang(id, "AI_MENU_STATUS", szLabel, charsmax(szLabel));
	if (!szLabel[0] || contain(szLabel, "AI_MENU_STATUS") != -1)
		copy(szLabel, charsmax(szLabel), "报名状态");
	ai_stateName(id, szState, charsmax(szState));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s \y[%s]^n^n", szLabel, szState);

	ai_lang(id, "AI_MENU_BACK", szBack, charsmax(szBack));
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szBack);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, szMenu, -1, "AISignupMenu");
}

public AiSignupMenuHandler(id, key) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (g_iAiMenuPage[id] == 2) {
		switch (key) {
			case 0: {
				if (isUserVipOrAdmin(id))
					showTypeMenu(id);
				else {
					ai_print_lang(id, "AI_CHAT_ERR_TYPE_VIP", "只有管理员/VIP 才能选择比赛类型");
					showMainMenu2(id);
				}
			}
			case 1: {
				announceCurrentPool(id, g_iActivePool);
				showMainMenu2(id);
			}
			case 2: {
				ai_printModeInfo(id);
				showMainMenu2(id);
			}
			case 9: showMainMenu(id);
		}
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: {
			doSignupToggle(id);
			if (is_user_connected(id) && g_eState != MATCH_RUNNING && g_eState != SIGNUP_CLOSE && g_eState != SIGNUP_SETUP)
				showMainMenu(id);
		}
		case 1: {
			showGroups(id);
			showMainMenu(id);
		}
		case 2: {
			if (isUserVipOrAdmin(id))
				showRulesMenu(id);
			else {
				ai_print_lang(id, "AI_CHAT_ERR_RULES_VIP", "只有VIP和管理员可以设置比赛模式");
				showMainMenu(id);
			}
		}
		case 3: {
			if (isUserAdmin(id))
				cmdForceStart(id);
			else {
				ai_print_lang(id, "AI_CHAT_ERR_FORCE_ADMIN", "只有管理员可以强制开启比赛");
				showMainMenu(id);
			}
		}
		case 4: {
			if (isUserVipOrAdmin(id))
				cmdReshuffle(id);
			showMainMenu(id);
		}
		case 5: {
			if (isUserVipOrAdmin(id))
				showPtsMenu(id);
			else {
				ai_print_lang(id, "AI_CHAT_ERR_PTS_ADMIN", "只有VIP和管理员可以设置OBS限制");
				showMainMenu(id);
			}
		}
		case 6: {
			if (isUserVipOrAdmin(id))
				showSizeMenu(id);
			else {
				ai_print_lang(id, "AI_CHAT_ERR_SIZE_ADMIN", "人数管理由管理员设置 (当前: %d v %d)", getEffectiveTeamSize(), getEffectiveTeamSize());
				showMainMenu(id);
			}
		}
		case 7: {
			if (isUserAdmin(id))
				showSqlMenu(id);
			else {
				ai_print_lang(id, "AI_CHAT_ERR_SQL_ADMIN", "只有管理员可以查看MySQL连接");
				showMainMenu(id);
			}
		}
		case 8: showMainMenu2(id);
		case 9: {
			g_bSignupMenuOpen[id] = false;
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_HANDLED;
}

// ============================================================
//  HNS报名分组情况 (蓝色 CT / 红色 TT, 名字之间用「，」)
// ============================================================
public showGroups(const id) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			showGroups(iPlayers[i]);
		return;
	}

	new bool:bAssigned;
	for (new i = 0; i < g_iSignupCount; i++) {
		if (g_iSignupTeam[g_iSignupList[i]]) {
			bAssigned = true;
			break;
		}
	}

	if (!bAssigned) {
		ai_print_lang(id, "AI_CHAT_ERR_NO_GROUPS", "尚未分组, 请点击「重新分配队伍」");
		return;
	}

	ai_print_lang(id, "AI_CHAT_GROUPS_TITLE", "当前分组 ^3[%d v %d]", getEffectiveTeamSize(), getEffectiveTeamSize());

	client_print_color(id, print_team_blue, "^3--------|CT|---------");
	if (!printTeamNames(id, TEAM_CT)) {
		new szNone[32];
		ai_lang(id, "AI_CHAT_TEAM_NONE", szNone, charsmax(szNone));
		if (!szNone[0] || equal(szNone, "AI_CHAT_TEAM_NONE"))
			copy(szNone, charsmax(szNone), "(无)");
		client_print_color(id, print_team_blue, "^3%s", szNone);
	}

	client_print_color(id, print_team_default, " ");

	client_print_color(id, print_team_red, "^3--------|TT|---------");
	if (!printTeamNames(id, TEAM_T)) {
		new szNone[32];
		ai_lang(id, "AI_CHAT_TEAM_NONE", szNone, charsmax(szNone));
		if (!szNone[0] || equal(szNone, "AI_CHAT_TEAM_NONE"))
			copy(szNone, charsmax(szNone), "(无)");
		client_print_color(id, print_team_red, "^3%s", szNone);
	}
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
			ai_print_lang(id, "AI_CHAT_ERR_CANCEL_MATCH", "比赛进行中, 无法取消报名");
			return;
		}
		cancelSignup(id);
		return;
	}

	// ★ 双重保险: 即使菜单已被打开, 报名动作仍重新校验
	if (!canSignup(id))
		return;
	signupPlayer(id);
}

// ============================================================
//  重新分配队伍 / 强制开启
// ============================================================
public cmdReshuffle(id) {
	if (!isUserVipOrAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_NEED_ADMIN", "需要管理员权限才能重新分配队伍");
		return PLUGIN_HANDLED;
	}

	if (g_eState == MATCH_RUNNING) {
		ai_print_lang(id, "AI_CHAT_ERR_RESHUFFLE_MATCH", "比赛进行中, 无法重新分配队伍");
		return PLUGIN_HANDLED;
	}

	if (g_iSignupCount < 1) {
		ai_print_lang(id, "AI_CHAT_ERR_NO_PLAYERS", "当前没有报名玩家");
		return PLUGIN_HANDLED;
	}

	shuffleTeamsNow();

	new szMode[32];
	balanceModeName(0, szMode, charsmax(szMode));
	ai_print_lang(0, "AI_CHAT_RESHUFFLED", "队伍已按 ^3%s^1 重新分配 (^3%d^1 人)", szMode, g_iSignupCount);
	showGroups(0);
	return PLUGIN_HANDLED;
}

public cmdForceStart(id) {
	if (!isUserAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_FORCE_ADMIN", "只有管理员可以强制开启比赛");
		return PLUGIN_HANDLED;
	}

	if (g_eState == MATCH_RUNNING) {
		ai_print_lang(id, "AI_CHAT_ERR_ALREADY_RUNNING", "比赛已在进行中");
		return PLUGIN_HANDLED;
	}

	if (g_iSignupCount < 1) {
		ai_print_lang(id, "AI_CHAT_ERR_FORCE_EMPTY", "当前没有报名玩家, 无法强制开启");
		return PLUGIN_HANDLED;
	}

	g_bForceStart = true;
	ai_print_lang(0, "AI_CHAT_FORCE_START", "^3[HNS测试]^1 管理员强制开启比赛! (^3%d^1 人)", g_iSignupCount);
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
		ai_print_rule(0, "AI_CHAT_RULES_SET", "比赛模式已设为: ^3%s^1 (管理员设置)", iRule);
		if (g_bPostGroupSetup)
			beginMapSelect();
		else
			showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	if (isAdminOnline()) {
		showMainMenu(id);
		ai_print_lang(id, "AI_CHAT_ERR_ADMIN_SET_RULES", "有管理员在线, 请让管理员设置比赛模式");
		return PLUGIN_HANDLED;
	}

	// 无管理员在线 -> 玩家投票 (发起人的选择直接计入)
	startRulesVote(id, iRule);
	return PLUGIN_HANDLED;
}

stock applyMatchRules(iRule) {
	g_iMatchRules = NATCH_RULES:iRule;
	PDS_SetCell("ai_match_rules", iRule);
	PDS_SetCell("match_rules", iRule);
	// 赛制状态只有一份：AI 菜单选择后立即同步到 MatchSystem。
	// 无论是否 pending、是否正在比赛，都不再允许两套状态分叉。
	hns_external_set_match_mode(_:g_iMatchRules);
}

public startRulesVote(id, iProposed) {
	if (g_bVoteActive) {
		ai_print_lang(id, "AI_CHAT_ERR_VOTE_RUNNING", "已有投票进行中 (剩余 ^3%d^1 秒)", g_iVoteSeconds);
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
	ai_print_lang(0, "AI_CHAT_VOTE_RULES_START", "无管理员在线, 开始投票选择比赛模式 (^3%d^1 秒)", g_iVoteSeconds);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		showVoteMenu(iPlayers[i]);

	set_task(1.0, "taskVote", TASK_VOTE, .flags = "b");
}

public cmdAiVote(id) {
	if (!g_bVoteActive) {
		ai_print_lang(id, "AI_CHAT_ERR_NO_VOTE", "当前没有投票");
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
		ai_print_lang(id, "AI_CHAT_ERR_ALREADY_VOTED", "你已经投过票了");
		return PLUGIN_HANDLED;
	}

	new iRule = str_to_num(data[5]);
	if (iRule < 0 || iRule >= RULE_COUNT)
		return PLUGIN_HANDLED;

	g_bVoteDone[id] = true;
	g_iVoteTally[iRule]++;

	new szName[32], szRuleName[32];
	get_user_name(id, szName, charsmax(szName));
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		ai_ruleName(iPlayers[i], iRule, szRuleName, charsmax(szRuleName));
		ai_print_lang(iPlayers[i], "AI_CHAT_VOTED_RULE", "%s 投票: ^3%s", szName, szRuleName);
	}

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

	if (g_iVoteSeconds <= 5 || g_iVoteSeconds == 10) {
		if (g_eVoteKind == VOTE_MAP)
			ai_print_lang(0, "AI_CHAT_VOTE_LEFT_MAP", "地图投票剩余 ^3%d^1 秒", g_iVoteSeconds);
		else if (g_eVoteKind == VOTE_POOL)
			ai_print_lang(0, "AI_CHAT_VOTE_LEFT_POOL", "地图池投票剩余 ^3%d^1 秒", g_iVoteSeconds);
		else
			ai_print_lang(0, "AI_CHAT_VOTE_LEFT_RULES", "模式投票剩余 ^3%d^1 秒", g_iVoteSeconds);
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
		ai_print_rule(0, "AI_CHAT_VOTE_RULES_KEEP", "投票结束: 无人投票, 保持当前模式 ^3%s", _:g_iMatchRules);
	} else {
		applyMatchRules(iBest);
		ai_print_rule_count(0, "AI_CHAT_VOTE_RULES_SET", "投票结束: 比赛模式设为 ^3%s^1 (%d 票)", iBest, iBestCount);
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
	format(szTitle, charsmax(szTitle), "\y人数管理 \r[%d : %d]\w (满员立即收团)", iSize, iSize);

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
		ai_print_lang(id, "AI_CHAT_ERR_SIZE_ADMIN", "人数管理由管理员设置 (当前: %d v %d)", getEffectiveTeamSize(), getEffectiveTeamSize());
		return PLUGIN_HANDLED;
	}

	new iSize = str_to_num(data[5]);

	if (iSize == 0) {
		g_iTeamSizeFixed = 0;
		ai_print_lang(0, "AI_CHAT_SIZE_AUTO", "人数管理已设为: ^3自动^1 (满 12 人或等 5 分钟再收团, 按人数分 3v3~6v6)");
	} else if (iSize >= 3 && iSize <= 6) {
		g_iTeamSizeFixed = iSize;
		ai_print_lang(0, "AI_CHAT_SIZE_FIXED", "人数管理已设为: ^3%d v %d^1 (满 %d 人立即收团, 不再等 5 分钟)", iSize, iSize, iSize * 2);
		tryCloseWhenFull();
	}

	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showPtsMenu(id) {
	if (!is_user_connected(id) || !isUserVipOrAdmin(id)) {
		showMainMenu(id);
		return;
	}

	new szTitle[192], szItem[128], szData[16], szOff[32], szMode[32];
	ai_lang(id, "AI_MENU_PTS_TITLE", szTitle, charsmax(szTitle));
	new menu = menu_create(szTitle, "PtsMenuHandler");

	ai_lang(id, "AI_MENU_PTS_OFF", szOff, charsmax(szOff));
	formatex(szItem, charsmax(szItem), "%s%s", g_bPtsLimit ? "\w" : "\r* ", szOff);
	menu_additem(menu, szItem, "pts_0");

	new const iLimits[] = { 30, 50, 70, 100 };
	for (new i = 0; i < sizeof(iLimits); i++) {
		ai_lang(id, "AI_MENU_PTS_MIN", szOff, charsmax(szOff));
		if (!szOff[0] || contain(szOff, "AI_MENU_PTS_MIN") != -1)
			copy(szOff, charsmax(szOff), "最低OBS %d");
		formatex(szItem, charsmax(szItem), "%s", (g_bPtsLimit && g_iPtsLimit == iLimits[i]) ? "\r* " : "\w");
		new iMark = strlen(szItem);
		formatex(szItem[iMark], charsmax(szItem) - iMark, szOff, iLimits[i]);
		formatex(szData, charsmax(szData), "pts_%d", iLimits[i]);
		menu_additem(menu, szItem, szData);
		if (i == 1)
			menu_addblank(menu, 0);
	}
	menu_addblank(menu, 0);

	balanceModeName(id, szMode, charsmax(szMode));
	ai_lang(id, "AI_MENU_BALANCE", szOff, charsmax(szOff));
	if (!szOff[0] || contain(szOff, "AI_MENU_BALANCE") != -1)
		copy(szOff, charsmax(szOff), "OBS平衡分组");
	formatex(szItem, charsmax(szItem), "\y%s \y[%s]", szOff, szMode);
	menu_additem(menu, szItem, "pts_balance");

	ai_lang(id, "AI_MENU_BALANCE_NOW", szOff, charsmax(szOff));
	if (!szOff[0] || contain(szOff, "AI_MENU_BALANCE_NOW") != -1)
		copy(szOff, charsmax(szOff), "立即按当前设置重新分组");
	menu_additem(menu, szOff, "pts_now");

	ai_lang(id, "AI_MENU_BACK", szOff, charsmax(szOff));
	menu_setprop(menu, MPROP_EXITNAME, szOff);
	menu_display(id, menu);
}

public PtsMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		showMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_PTS_ADMIN", "只有VIP和管理员可以设置OBS限制");
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(data, "pts_balance")) {
		showBalanceMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(data, "pts_now")) {
		if (g_iSignupCount < 1)
			ai_print_lang(id, "AI_CHAT_ERR_NO_PLAYERS", "当前没有报名玩家");
		else if (g_eState == MATCH_RUNNING)
			ai_print_lang(id, "AI_CHAT_ERR_RESHUFFLE_MATCH", "比赛进行中, 无法重新分配队伍");
		else {
			shuffleTeamsNow();
			new szMode[32];
			balanceModeName(0, szMode, charsmax(szMode));
			ai_print_lang(0, "AI_CHAT_BALANCE_DONE", "已按 ^3%s^1 重新分组 (^3%d^1 人)", szMode, g_iSignupCount);
			showGroups(0);
		}
		showPtsMenu(id);
		return PLUGIN_HANDLED;
	}

	new iLimit = str_to_num(data[4]);
	if (iLimit <= 0) {
		g_bPtsLimit = false;
		ai_print_lang(0, "AI_CHAT_PTS_OFF", "OBS积分限制已关闭");
	} else {
		g_bPtsLimit = true;
		g_iPtsLimit = iLimit;
		ai_print_lang(0, "AI_CHAT_PTS_ON", "OBS积分限制已开启: 最低 ^3%d^1 分", g_iPtsLimit);
	}

	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showBalanceMenu(id) {
	if (!is_user_connected(id) || !isUserVipOrAdmin(id)) {
		showMainMenu(id);
		return;
	}

	new szTitle[192], szItem[96], szLine[64];
	ai_lang(id, "AI_MENU_BALANCE_TITLE", szTitle, charsmax(szTitle));
	if (!szTitle[0] || contain(szTitle, "AI_MENU_BALANCE_TITLE") != -1)
		copy(szTitle, charsmax(szTitle), "\rOBS平衡分组");

	new menu = menu_create(szTitle, "BalanceMenuHandler");

	ai_lang(id, "AI_MENU_BALANCE_OFF", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_OFF") != -1)
		copy(szLine, charsmax(szLine), "关闭 (随机分组)");
	formatex(szItem, charsmax(szItem), "%s%s", (!g_bPtsBalance) ? "\r* " : "\w", szLine);
	menu_additem(menu, szItem, "bal_0");

	ai_lang(id, "AI_MENU_BALANCE_AUTO", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_AUTO") != -1)
		copy(szLine, charsmax(szLine), "自动平衡");
	formatex(szItem, charsmax(szItem), "%s%s", (g_bPtsBalance && g_iBalanceMode == 1) ? "\r* " : "\w", szLine);
	menu_additem(menu, szItem, "bal_1");

	ai_lang(id, "AI_MENU_BALANCE_STRICT", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_STRICT") != -1)
		copy(szLine, charsmax(szLine), "严格平衡");
	formatex(szItem, charsmax(szItem), "%s%s", (g_bPtsBalance && g_iBalanceMode == 2) ? "\r* " : "\w", szLine);
	menu_additem(menu, szItem, "bal_2");

	ai_lang(id, "AI_MENU_BALANCE_LOOSE", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_LOOSE") != -1)
		copy(szLine, charsmax(szLine), "宽松平衡");
	formatex(szItem, charsmax(szItem), "%s%s", (g_bPtsBalance && g_iBalanceMode == 3) ? "\r* " : "\w", szLine);
	menu_additem(menu, szItem, "bal_3");

	ai_lang(id, "AI_MENU_BALANCE_NEW", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_NEW") != -1)
		copy(szLine, charsmax(szLine), "新人: 按中位估算");
	menu_additem(menu, szLine, "bal_info");

	ai_lang(id, "AI_MENU_BALANCE_FEW", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_FEW") != -1)
		copy(szLine, charsmax(szLine), "少于5场: 往中位靠");
	menu_additem(menu, szLine, "bal_info");
	menu_addblank(menu, 0);

	ai_lang(id, "AI_MENU_BALANCE_SRC", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_SRC") != -1)
		copy(szLine, charsmax(szLine), "数据: MySQL OBS/胜率/场数");
	menu_additem(menu, szLine, "bal_info");

	ai_lang(id, "AI_MENU_BALANCE_NOW", szLine, charsmax(szLine));
	if (!szLine[0] || contain(szLine, "AI_MENU_BALANCE_NOW") != -1)
		copy(szLine, charsmax(szLine), "立即按当前设置重新分组");
	menu_additem(menu, szLine, "bal_now");

	ai_lang(id, "AI_MENU_BACK", szLine, charsmax(szLine));
	menu_setprop(menu, MPROP_EXITNAME, szLine);
	menu_display(id, menu);
}

public BalanceMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		showMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_BALANCE_ADMIN", "只有VIP和管理员可以设置OBS平衡分组");
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(data, "bal_info")) {
		ai_print_lang(id, "AI_CHAT_BALANCE_INFO", "没打过按本局中位估算, 少于5场会往中位靠, 不会把新人当高手");
		showBalanceMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(data, "bal_now")) {
		if (g_iSignupCount < 1)
			ai_print_lang(id, "AI_CHAT_ERR_NO_PLAYERS", "当前没有报名玩家");
		else if (g_eState == MATCH_RUNNING)
			ai_print_lang(id, "AI_CHAT_ERR_RESHUFFLE_MATCH", "比赛进行中, 无法重新分配队伍");
		else {
			shuffleTeamsNow();
			new szMode[32];
			balanceModeName(0, szMode, charsmax(szMode));
			ai_print_lang(0, "AI_CHAT_BALANCE_DONE", "已按 ^3%s^1 重新分组 (^3%d^1 人)", szMode, g_iSignupCount);
			showGroups(0);
		}
		showBalanceMenu(id);
		return PLUGIN_HANDLED;
	}

	new iMode = str_to_num(data[4]);
	if (iMode <= 0) {
		g_bPtsBalance = false;
		g_iBalanceMode = 0;
		ai_print_lang(0, "AI_CHAT_BALANCE_OFF", "OBS平衡分组已关闭, 改为随机分组");
	} else {
		g_bPtsBalance = true;
		g_iBalanceMode = iMode;
		new szMode[32];
		balanceModeName(0, szMode, charsmax(szMode));
		ai_print_lang(0, "AI_CHAT_BALANCE_ON", "OBS平衡分组已开启: ^3%s", szMode);
	}

	showBalanceMenu(id);
	return PLUGIN_HANDLED;
}

public showSqlMenu(id) {
	if (!is_user_connected(id) || !isUserAdmin(id)) {
		showMainMenu(id);
		return;
	}

	new szHost[48], szUser[32], szDb[32], szStatus[32];
	new szTitle[192], szItem[128], szBack[32];
	get_cvar_string("hns_host", szHost, charsmax(szHost));
	get_cvar_string("hns_user", szUser, charsmax(szUser));
	get_cvar_string("hns_db", szDb, charsmax(szDb));
	if (!szHost[0])
		copy(szHost, charsmax(szHost), "127.0.0.1");
	if (!szUser[0])
		copy(szUser, charsmax(szUser), "root");
	if (!szDb[0])
		copy(szDb, charsmax(szDb), "hns");

	ai_lang(id, g_bSqlReady ? "AI_MENU_SQL_ON" : "AI_MENU_SQL_OFF", szStatus, charsmax(szStatus));
	ai_lang(id, "AI_MENU_SQL_TITLE", szTitle, charsmax(szTitle));
	format(szTitle, charsmax(szTitle), szTitle, g_bSqlReady ? "\y" : "\r", szStatus, szHost, szDb, szUser);

	new menu = menu_create(szTitle, "SqlMenuHandler");
	ai_lang(id, "AI_MENU_SQL_TEST", szItem, charsmax(szItem));
	menu_additem(menu, szItem, "sql_test");
	ai_lang(id, "AI_MENU_BACK", szBack, charsmax(szBack));
	menu_setprop(menu, MPROP_EXITNAME, szBack);
	menu_display(id, menu);
}

public SqlMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		showMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_SQL_ADMIN", "只有管理员可以查看MySQL连接");
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(data, "sql_test")) {
		if (!g_bSqlReady || g_hSqlTuple == Empty_Handle) {
			ai_print_lang(id, "AI_CHAT_SQL_FAIL", "MySQL未连接");
			showSqlMenu(id);
		} else {
			new iData[1];
			iData[0] = id;
			SQL_ThreadQuery(g_hSqlTuple, "cbSqlPing", "SELECT 1", iData, sizeof(iData));
		}
	}
	return PLUGIN_HANDLED;
}

public cbSqlPing(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime) {
	new id = (size > 0) ? data[0] : 0;
	if (!is_user_connected(id))
		return;

	if (failstate) {
		g_bSqlReady = false;
		ai_print_lang(id, "AI_CHAT_SQL_FAIL", "MySQL未连接");
	} else {
		g_bSqlReady = true;
		ai_print_lang(id, "AI_CHAT_SQL_OK", "MySQL连接正常");
	}
	showSqlMenu(id);
}

// 设置比赛类型 0娱乐/1赞助 (管理员)
public cmdAiType(id) {
	if (!isUserVipOrAdmin(id))
		return PLUGIN_HANDLED;

	new szArg[8];
	read_argv(1, szArg, charsmax(szArg));
	if (!szArg[0]) {
		new szType[32];
		ai_typeName(id, szType, charsmax(szType));
		ai_print_lang(id, "AI_CHAT_AITYPE_USAGE", "用法: !aitype <0娱乐|1赞助> (当前: %s)", szType);
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
				ai_print_lang(p, "AI_CHAT_GUEST_REMOVED", "已从报名中移除: 盗版玩家不能参与赞助局");
			}
		}
	}

	ai_print_type(0, "AI_CHAT_TYPE_SET", "比赛类型已设为: ^3%s");
	return PLUGIN_HANDLED;
}

// 取消整个报名 (管理员)
public cmdAiAbort(id) {
	if (!isUserVipOrAdmin(id))
		return PLUGIN_HANDLED;

	abortSignup();
	ai_print_lang(0, "AI_CHAT_ABORTED", "AI 报名已取消, 全部清除");
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

	// 第一个报名: 保持训练模式, 不进大厅/比赛模式
	if (g_iSignupCount == 1) {
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = SIGNUP_TIMER;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
	} else if (g_eState == SIGNUP_IDLE) {
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = SIGNUP_TIMER;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
	}

	ai_print_lang(id, "AI_CHAT_SIGNED", "报名成功 (已报名 %d 人 | 在线 %d 人)", g_iSignupCount, getOnlineCount());
	broadcastSignupCount();
	refreshSignupMenus();
	tryCloseWhenFull();
}

// 测试人机插件用: 跳过菜单直接报名 (仍走 canSignup)
public native_force_signup(plugin, params) {
	new id = get_param(1);
	if (!is_user_connected(id) || g_bSignedUp[id])
		return 0;

	if (g_iSignupCount >= SIGNUP_MAX)
		return 0;

	if (!canSignup(id, true))
		return 0;

	signupPlayer(id);
	return 1;
}

public native_get_state(plugin, params) {
	return _:g_eState;
}

public native_get_team_size(plugin, params) {
	return g_iTeamSizeFixed;
}

// size: 3..6 固定人数, 0 恢复自动。比赛中、收团、赛前选择时拒绝。
public native_set_team_size(plugin, params) {
	new iSize = get_param(1);
	if (iSize != 0 && (iSize < 3 || iSize > 6))
		return 0;
	if (g_eState == SIGNUP_CLOSE || g_eState == SIGNUP_SETUP || g_eState == MATCH_RUNNING)
		return 0;

	g_iTeamSizeFixed = iSize;
	if (iSize > 0 && g_eState == SIGNUP_OPEN)
		tryCloseWhenFull();
	return 1;
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
	g_bSignupMenuOpen[id] = false;
	g_iSignupTeam[id] = 0;

	if (stopSignupIfEmpty())
		return;

	refreshSignupMenus();
	ai_print_lang(id, "AI_CHAT_CANCELLED", "已取消报名 (剩余 %d 人 | 在线 %d 人)", g_iSignupCount, getOnlineCount());
}

public client_disconnected(id) {
	g_bGuest[id] = false;
	g_iGuestId[id] = 0;
	g_iGuestRetry[id] = 0;
	remove_task(id + TASK_GUEST_CHECK);

	if (g_bWaitingSponsorGc && id == g_iSponsorAskId) {
		g_bWaitingSponsorGc = false;
		remove_task(TASK_SPONSOR_GC);
		if (g_iSponsorGC < 5)
			g_iSponsorGC = 5;
		if (g_bPostGroupSetup)
			startMatch();
	}

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
		// 换图 pending 时人会先掉线, 不要把报名状态清成 IDLE, 否则 PDS_Save 会用空名单覆盖分组

		if (!g_bPendingMatchStart && stopSignupIfEmpty())
			return;
	}
}

// 报名人数广播和菜单刷新
public broadcastSignupCount() {
	ai_print(0, "[^4HNSai^1]当前报名人数 ^3%d", g_iSignupCount);
}

stock refreshSignupMenus() {
	if (g_eState != SIGNUP_OPEN && g_eState != SIGNUP_IDLE)
		return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		if (!g_bSignupMenuOpen[id])
			continue;

		if (g_iAiMenuPage[id] == 2)
			showMainMenu2(id);
		else
			showMainMenu(id);
	}
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

	tryCloseWhenFull();
	if (g_eState != SIGNUP_OPEN)
		return;

	new iNeed = (g_iTeamSizeFixed > 0) ? (g_iTeamSizeFixed * 2) : SIGNUP_MAX;
	new iSec = floatround(g_flSignupTimer, floatround_floor);
	if (iSec <= 5 || iSec == 60 || iSec == 180 || iSec == 300) {
		ai_print_lang(0, "AI_CHAT_COUNTDOWN", "报名剩余 ^3%d^1 秒 | 已报名 %d/%d 人 (%d v %d)", iSec, g_iSignupCount, iNeed, getEffectiveTeamSize(), getEffectiveTeamSize());
	}
}

// ============================================================
//  收团 -> 1 秒 1 人 -> 开赛
// ============================================================
public closeSignup() {
	if (g_eState != SIGNUP_OPEN)
	return;

	remove_task(TASK_COUNTDOWN);

	// 过滤掉线玩家
	filterDisconnected();

	if (stopSignupIfEmpty()) {
	g_bForceStart = false;
	return;
	}

	new iNeed = getRequiredSignupCount();
	if (!g_bForceStart && g_iSignupCount < iNeed) {
	ai_print_lang(0, "AI_CHAT_NOT_ENOUGH", "报名人数不足 (^3%d^1/^3%d^1 = %d v %d), 报名继续...", g_iSignupCount, iNeed, getEffectiveTeamSize(), getEffectiveTeamSize());
	g_eState = SIGNUP_OPEN;
	g_flSignupTimer = 60.0;
	set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
	return;
	}

	g_eState = SIGNUP_CLOSE;
	g_bPlayersPlaced = false;

	// 动态队伍规模: 自动 = N/2 (上限 6v6), 或管理员在「人数管理」里固定
	g_iPlaceTeamSize = getEffectiveTeamSize();
	if (g_bKeepSavedTeams) {
		ai_print_lang(0, "AI_CHAT_CLOSE_KEEP", "收团! 按换图前分组上场, 不再重新随机");
		g_bKeepSavedTeams = false;
	} else {
		ai_print_lang(0, "AI_CHAT_CLOSE_SETUP", "收团! 先记分组, 换图前不拉观战, 先选模式和地图");
		shuffleTeamsNow();
	}
	saveSignupTeams();
	buildPlaceQueue(g_iPlaceTeamSize);

	// ★ 人数达标 -> 聊天框播报当前分组 (蓝 CT / 红 TT)
	showGroups(0);

	placeAllNow();
}

stock placeAllNow() {
	remove_task(TASK_PLACE);
	remove_task(TASK_PLACE_DELAY);
	g_iPlaceIndex = 0;

	if (g_bPendingMatchStart) {
		startPlacingOneByOne();
		return;
	}

	// 换图前不拉观战, 只记分组, 直接进赛前设置
	beginPostGroupSetup();
}

stock specEveryoneNow() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "h");
	for (new i = 0; i < iNum; i++)
		moveToSpec(iPlayers[i]);
}

stock startPlacingOneByOne() {
	remove_task(TASK_PLACE);
	remove_task(TASK_PLACE_DELAY);
	g_eState = SIGNUP_CLOSE;
	g_bPlayersPlaced = false;
	g_iPlaceIndex = 0;
	specEveryoneNow();

	if (g_iPlaceTotal < 1)
		buildPlaceQueue(g_iPlaceTeamSize);

	if (g_iPlaceTotal < 1) {
		ai_print_lang(0, "AI_CHAT_NO_PLACE", "没有可上场玩家");
		g_bPlayersPlaced = true;
		if (g_bPendingMatchStart)
			startMatch();
		else
			beginPostGroupSetup();
		return;
	}

	ai_print_lang(0, "AI_CHAT_SPEC_WAIT", "先观战 ^35^1 秒, 再按换图前分组 1 秒 1 人上场 (^3%d^1 人)", g_iPlaceTotal);
	set_task(PLACE_SPEC_WAIT, "taskStartPlaceAfterSpec", TASK_PLACE_DELAY);
}

public taskStartPlaceAfterSpec() {
	remove_task(TASK_PLACE_DELAY);
	if (g_eState != SIGNUP_CLOSE) {
		return;
	}

	if (g_iPlaceTotal < 1) {
		g_bPlayersPlaced = true;
		if (g_bPendingMatchStart)
			startMatch();
		else
			beginPostGroupSetup();
		return;
	}

	set_task(PLACE_INTERVAL, "taskPlacePlayer", TASK_PLACE, .flags = "b");
	taskPlacePlayer();
}

stock placeQueuedPlayers() {
	if (g_iPlaceTotal < 1)
		buildPlaceQueue(g_iPlaceTeamSize);

	for (new i = 0; i < g_iPlaceTotal; i++) {
		new id = g_iPlaceOrder[i];
		if (!is_user_connected(id))
			continue;
		moveToTeam(id, (g_iPlaceTeam[i] == TEAM_T) ? TEAM_TERRORIST : TeamName:TEAM_CT);
	}
	g_iPlaceIndex = g_iPlaceTotal;
	g_bPlayersPlaced = true;
}

stock countAssignedTeams(&iT, &iCT) {
	iT = 0;
	iCT = 0;

	if (g_iPlaceTotal > 0) {
		for (new i = 0; i < g_iPlaceTotal; i++) {
			new id = g_iPlaceOrder[i];
			if (!is_user_connected(id))
				continue;
			if (g_iPlaceTeam[i] == TEAM_T)
				iT++;
			else
				iCT++;
		}
		return;
	}

	for (new i = 0; i < g_iSignupCount; i++) {
		new id = g_iSignupList[i];
		if (!is_user_connected(id))
			continue;
		if (g_iSignupTeam[id] == TEAM_T)
			iT++;
		else if (g_iSignupTeam[id] == TEAM_CT)
			iCT++;
	}
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

// 1 秒 1 人上场 (换图后按换图前分组送)
public taskPlacePlayer() {
	if (g_eState != SIGNUP_CLOSE) {
		remove_task(TASK_PLACE);
		return;
	}

	if (g_iPlaceIndex >= g_iPlaceTotal) {
		remove_task(TASK_PLACE);
		g_bPlayersPlaced = true;
		startMatch();
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

		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		log_amx("[HNSai] place %d/%d: %s -> %s", g_iPlaceIndex, g_iPlaceTotal, szName, (g_iPlaceTeam[idx] == TEAM_T) ? "T" : "CT");
	}
}

// 人数合适 -> 绿色聊天提示 -> 比赛开始
public startMatch() {
	filterDisconnected();

	// 按已分组计数, 不看当前是否已经站上 T/CT (赛前设置期间全员留观战)
	new iT, iCT;
	countAssignedTeams(iT, iCT);

	// 人数不足则中止, 回到报名 (强制开赛允许 1 人测试)
	new iNeed = getEffectiveTeamSize();
	if (!g_bForceStart && (iT < iNeed || iCT < iNeed)) {
		ai_print_lang(0, "AI_CHAT_START_NOT_ENOUGH", "参赛人数不足 (^3T%d^1 v ^3%dCT^1, 需要 %d v %d), 取消开赛, 报名继续", iT, iCT, iNeed, iNeed);
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = 60.0;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
		return;
	}

	if (iT + iCT < 1) {
		ai_print_lang(0, "AI_CHAT_START_NO_PLAYERS", "没有上场玩家, 取消开赛");
		g_bForceStart = false;
		g_bPostGroupSetup = false;
		g_eState = SIGNUP_OPEN;
		g_flSignupTimer = 60.0;
		set_task(1.0, "taskCountdown", TASK_COUNTDOWN, .flags = "b");
		return;
	}

	if (g_szPickedMap[0] && !equali(g_szPickedMap, g_szLastMap)) {
		if (!isMapSafeToLoad(g_szPickedMap)) {
			ai_print_lang(0, "AI_CHAT_MAP_UNSAFE", "地图 ^3%s^1 缺少模型, 留在当前图开赛", g_szPickedMap);
			log_amx("[HNSai] skip unsafe map %s, stay on %s", g_szPickedMap, g_szLastMap);
			g_szPickedMap[0] = EOS;
		} else {
			ai_print_lang(0, "AI_CHAT_MAP_CHANGE", "即将换图到 ^3%s^1, 换图后先核对报名玩家, 再拉观战上场", g_szPickedMap);
			g_bPendingMatchStart = true;
			g_bPlayersPlaced = false;
			savePendingMatch();
			saveSignupTeams();
			g_eState = SIGNUP_OPEN;
			g_bPostGroupSetup = false;
			server_cmd("changelevel %s", g_szPickedMap);
			return;
		}
	}

	if (!g_bPlayersPlaced) {
		specEveryoneNow();
		startPlacingOneByOne();
		return;
	}

	ai_print_lang(0, "AI_CHAT_MATCH_START", "^2比赛启动!^1 T队 ^2%d^1 人 v CT队 ^2%d^1 人", iT, iCT);
	announceMapStyle(0);
	ai_print_match_info(0, iT + iCT);
	showGroups(0);

	// 开赛: 用实际上场人数锁规模, 避免 1 人强制开赛被写成 1v1
	// 然后中途进服的人被当成补位
	hns_external_set_team_size(iCT, iT);
	hns_external_set_match_mode(_:g_iMatchRules);
	if (g_bSponsorMatch && g_szSponsorName[0])
		hns_external_set_sponsor_name(g_szSponsorName);
	if (g_bSponsorMatch && g_iSponsorGC >= 5)
		hns_external_set_sponsor_gc(g_iSponsorGC);
	// 报名阶段不切公共/死斗/僵尸; 人到齐并选完地图后才正式开赛
	hns_begin_external_match(g_bSponsorMatch, 0);

	g_bForceStart = false;
	g_bPlayersPlaced = false;
	g_bPostGroupSetup = false;
	g_bWaitingSponsor = false;
	g_bWaitingSponsorGc = false;
	g_bPendingMatchStart = false;
	g_bKeepSavedTeams = false;
	PDS_SetCell("ai_pending_start", 0);
	PDS_SetCell("ai_saved_n", 0);
	g_eState = MATCH_RUNNING;
}

// ============================================================
//  比赛开始 / 结束
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

		new iTeam = hns_get_player_match_team(id);
		if (iTeam > 0 && iTeam == iWinTeam)
			guestAddPts(id, 1, 0);
		else
			guestAddPts(id, 0, 1);
	}

	abortSignup();
	g_flBlockedUntil = get_gametime() + SIGNUP_CD;
	ai_print_lang(0, "AI_CHAT_MATCH_END", "比赛结束! 报名已清除, 冷却 ^320^1 秒后可再次报名。");
}

public hns_match_canceled() {
	abortSignup();
	ai_print_lang(0, "AI_CHAT_MATCH_CANCEL", "比赛已终止, 报名已清除");
}

stock GuestKnifeBonus(id) {
	if (!LibraryExists("hns_obc", LibType_Library))
		return 0;
	return hns_obc_knife_bonus(id);
}

stock GuestUnpack(const szData[], &iWins, &iLoss, &iPts) {
	new szA[16], szB[16], szC[16], szD[16];
	parse(szData, szA, charsmax(szA), szB, charsmax(szB), szC, charsmax(szC), szD, charsmax(szD));
	if (equal(szA, "v2")) {
		iWins = str_to_num(szB);
		iLoss = str_to_num(szC);
		iPts = str_to_num(szD);
		return;
	}
	iWins = str_to_num(szA);
	iLoss = str_to_num(szB);
	iPts = PTS_BASE + iWins * PTS_WIN - iLoss * PTS_LOSS;
	if (iPts < 0)
		iPts = 0;
}

stock guestAddPts(id, iWins, iLoss) {
	if (!g_bSqlReady || g_hSqlTuple == Empty_Handle) {
		Local_GuestInit();
		if (g_iGuestVault == INVALID_HANDLE)
			return;

		new szName[32], szData[64];
		get_user_name(id, szName, charsmax(szName));
		if (!szName[0])
			copy(szName, charsmax(szName), "unnamed");

		new iCurWins, iCurLoss, iCurPts = PTS_BASE;
		if (nvault_get(g_iGuestVault, szName, szData, charsmax(szData)) && szData[0])
			GuestUnpack(szData, iCurWins, iCurLoss, iCurPts);

		iCurWins += iWins;
		iCurLoss += iLoss;
		iCurPts += iWins * PTS_WIN - iLoss * PTS_LOSS + GuestKnifeBonus(id);
		if (iCurPts < 0)
			iCurPts = 0;

		nvault_set(g_iGuestVault, szName, fmt("v2 %d %d %d", iCurWins, iCurLoss, iCurPts));
		return;
	}

	if (!g_iGuestId[id])
		return;

	new iDelta = iWins * PTS_WIN - iLoss * PTS_LOSS + GuestKnifeBonus(id);
	new szQuery[384];
	formatex(szQuery, charsmax(szQuery),
		"INSERT INTO `hns_ai_guest_pts` (id, wins, loss, pts, obc_ready) VALUES (%d, %d, %d, %d, 1) \
		ON DUPLICATE KEY UPDATE wins=wins+%d, loss=loss+%d, pts=GREATEST(pts+%d, 0), obc_ready=1",
		g_iGuestId[id], iWins, iLoss, PTS_BASE + iDelta,
		iWins, iLoss, iDelta);

	SQL_ThreadQuery(g_hSqlTuple, "cbVoid", szQuery);
}

// ============================================================
//  换图处理: AI 选图后等 30 秒人齐 -> 1秒1人上场 -> 开赛
// ============================================================
public onMapChange() {
	remove_task(TASK_COUNTDOWN);
	remove_task(TASK_PLACE);
	remove_task(TASK_PLACE_DELAY);
	remove_task(TASK_AFTER_MAP);
	remove_task(TASK_VOTE);
	remove_task(TASK_SPONSOR_WAIT);
	remove_task(TASK_SPONSOR_GC);
	remove_task(TASK_MAP_WAIT);
	remove_task(TASK_SETUP_MENU);
	remove_task(TASK_RANDOM_MAP);
	clearSpecJoinTasks();

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	g_bPostGroupSetup = false;
	g_bWaitingSponsor = false;
	g_bWaitingSponsorGc = false;
	g_bMapWaitActive = false;
	g_bPlayersPlaced = false;
	g_bRandomMapWait = false;

	new iPending;
	if (PDS_GetCell("ai_pending_start", iPending) && iPending) {
		PDS_SetCell("ai_pending_start", 0);
		g_bPendingMatchStart = true;
		PDS_GetString("ai_picked_map", g_szPickedMap, charsmax(g_szPickedMap));
		new iRules, iSponsor, iForce, iSize;
		if (PDS_GetCell("ai_match_rules", iRules) && iRules >= 0 && iRules < RULE_COUNT) {
			g_iMatchRules = NATCH_RULES:iRules;
			PDS_SetCell("match_rules", iRules);
			hns_external_set_match_mode(_:g_iMatchRules);
		}
		if (PDS_GetCell("ai_sponsor_match", iSponsor))
			g_bSponsorMatch = bool:iSponsor;
		PDS_GetString("ai_sponsor_name", g_szSponsorName, charsmax(g_szSponsorName));
		new iSponsorGc;
		if (PDS_GetCell("ai_sponsor_gc", iSponsorGc) && iSponsorGc >= 5)
			g_iSponsorGC = iSponsorGc;
		if (PDS_GetCell("ai_force_start", iForce))
			g_bForceStart = bool:iForce;
		if (PDS_GetCell("ai_team_size", iSize) && iSize > 0)
			g_iPlaceTeamSize = iSize;
	}

	filterDisconnected();

	// 只有 AI 选图后的 pending 才继续开赛; 普通换图不自动报名、不开赛
	if (g_bPendingMatchStart) {
		g_eState = SIGNUP_CLOSE;
		g_flBlockedUntil = 0.0;
		g_flSignupTimer = 0.0;
		g_iPlaceTotal = 0;
		g_iPlaceIndex = 0;
		g_bMapWaitActive = true;
		g_iMapWaitSeconds = floatround(MAP_CHANGE_WAIT);
		// 换图后先等人核对, 不在这里切公共模式。
		// pub_start 会马上 hns_restart_round, 和换图加载、玩家重进叠在一起会把进程打崩。
		log_amx("[HNSai] map wait %d sec on %s, skip pub restart", g_iMapWaitSeconds, g_szLastMap);
		ai_print_lang(0, "AI_CHAT_MAP_PUB", "换图完成, 已切换公共模式");
		ai_print_lang(0, "AI_CHAT_MAP_WAIT", "换图完成, 先等 ^3%d^1 秒核对报名玩家, 确认后再拉观战", g_iMapWaitSeconds);
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
		if (g_iMapWaitSeconds <= 5 || g_iMapWaitSeconds == 20 || g_iMapWaitSeconds == 10)
			ai_print_lang(0, "AI_CHAT_MAP_WAIT_TICK", "核对报名玩家中, 剩余 ^3%d^1 秒 | 在线 %d 人", g_iMapWaitSeconds, getOnlineCount());
		return;
	}

	remove_task(TASK_MAP_WAIT);
	g_bMapWaitActive = false;
	taskPendingResume();
}

public taskPendingResume() {
	rebuildSignupFromOnline();
	if (g_iSignupCount < 1) {
		ai_print_lang(0, "AI_CHAT_MAP_NO_PLAYERS", "换图后没有在线玩家, 取消开赛");
		g_bPendingMatchStart = false;
		g_bForceStart = false;
		g_eState = SIGNUP_IDLE;
		return;
	}

	g_bForceStart = true;
	g_eState = SIGNUP_CLOSE;
	if (g_iPlaceTeamSize < 1)
		g_iPlaceTeamSize = getEffectiveTeamSize();
	ai_print_lang(0, "AI_CHAT_MAP_CONFIRMED", "已确认报名玩家 ^3%d^1 人, 先拉观战, 等 5 秒再 1 秒 1 人上场", g_iSignupCount);
	if (g_bKeepSavedTeams) {
		ai_print_lang(0, "AI_CHAT_CLOSE_KEEP", "收团! 按换图前分组上场, 不再重新随机");
	} else {
		ai_print_lang(0, "AI_CHAT_MAP_RESHUFFLE", "没对上换图前名单, 只能重新分一次");
		shuffleTeamsNow();
	}
	g_bKeepSavedTeams = false;
	buildPlaceQueue(g_iPlaceTeamSize);
	showGroups(0);
	startPlacingOneByOne();
}

stock rebuildSignupFromOnline() {
	g_iSignupCount = 0;
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
			g_bKeepSavedTeams = true;

		new szName[32], szAuth[32];
		get_user_name(id, szName, charsmax(szName));
		get_user_authid(id, szAuth, charsmax(szAuth));
		log_amx("[HNSai] confirm %s | %s | %s", szName, szAuth, (iTeam == TEAM_T) ? "T" : "CT");
	}
}

public taskAfterMapCooldown() {
	if (g_eState != SIGNUP_OPEN)
	return;

	filterDisconnected();

	if (stopSignupIfEmpty())
	return;


	new iNeed = getRequiredSignupCount();
	if (g_iSignupCount >= iNeed) {
	ai_print_lang(0, "AI_CHAT_CD_CLOSE", "冷静期结束, 参赛人数 ^3%d^1/%d 人, 开始收团!", g_iSignupCount, iNeed);
	g_flSignupTimer = 0.0;
	closeSignup();
	} else {
	ai_print_lang(0, "AI_CHAT_CD_CONTINUE", "冷静期结束, 当前 ^3%d^1 人 (不足 %d = %d v %d), 继续接受报名", g_iSignupCount, iNeed, getEffectiveTeamSize(), getEffectiveTeamSize());
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
	remove_task(TASK_PLACE_DELAY);
	remove_task(TASK_AFTER_MAP);
	remove_task(TASK_VOTE);
	remove_task(TASK_SPONSOR_WAIT);
	remove_task(TASK_SPONSOR_GC);
	remove_task(TASK_MAP_WAIT);
	remove_task(TASK_SETUP_MENU);
	remove_task(TASK_RANDOM_MAP);
	clearSpecJoinTasks();

	g_bVoteActive = false;
	g_eVoteKind = VOTE_NONE;
	g_bPostGroupSetup = false;
	g_bWaitingSponsor = false;
	g_bWaitingSponsorGc = false;
	g_bMapWaitActive = false;
	g_bRandomMapWait = false;

	for (new i = 0; i < MAX_PLAYERS + 1; i++) {
	g_bSignedUp[i] = false;
	g_iSignupTeam[i] = 0;
	}

	g_bPlayersPlaced = false;
	g_iSignupCount = 0;
	g_flSignupTimer = 0.0;
	g_flBlockedUntil = 0.0;
	g_bForceStart = false;
	g_szPickedMap[0] = EOS;
	g_szSponsorName[0] = EOS;
	g_iSponsorGC = 0;
	g_iSponsorAskId = 0;
	g_bPendingMatchStart = false;
	g_bKeepSavedTeams = false;
	PDS_SetCell("ai_pending_start", 0);
	PDS_SetCell("ai_saved_n", 0);
	g_eState = SIGNUP_IDLE;
	}

	stock bool:stopSignupIfEmpty() {
	if (g_iSignupCount > 0)
	return false;

	if (g_eState != SIGNUP_OPEN && g_eState != SIGNUP_IDLE)
	return false;

	remove_task(TASK_COUNTDOWN);
	g_flSignupTimer = 0.0;

	if (g_eState == SIGNUP_OPEN)
	g_eState = SIGNUP_IDLE;

	return true;
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
	PDS_SetCell("ai_sponsor_gc", g_iSponsorGC);
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

	stock countConnectedSignedWithTeam() {
	new iCount;
	for (new i = 0; i < g_iSignupCount; i++) {
		new id = g_iSignupList[i];
		if (!is_user_connected(id))
			continue;
		if (g_iSignupTeam[id] == TEAM_T || g_iSignupTeam[id] == TEAM_CT)
			iCount++;
	}
	return iCount;
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

	new szKey[32], szId[48], szName[32];
	getPlayerPersistId(id, szId, charsmax(szId));
	get_user_name(id, szName, charsmax(szName));

	formatex(szKey, charsmax(szKey), "ai_saved_k%d", iCount);
	PDS_SetString(szKey, szId);
	formatex(szKey, charsmax(szKey), "ai_saved_nm%d", iCount);
	PDS_SetString(szKey, szName);
	formatex(szKey, charsmax(szKey), "ai_saved_t%d", iCount);
	PDS_SetCell(szKey, iTeam);
	iCount++;
	}
	PDS_SetCell("ai_saved_n", iCount);
	log_amx("[HNSai] saved %d signup teams before mapchange", iCount);
	}

	stock bool:savedSlotMatches(id, iSlot) {
	new szKey[32], szSaved[48], szCur[48];

	formatex(szKey, charsmax(szKey), "ai_saved_k%d", iSlot);
	if (PDS_GetString(szKey, szSaved, charsmax(szSaved)) && szSaved[0]) {
		getPlayerPersistId(id, szCur, charsmax(szCur));
		if (equali(szCur, szSaved))
			return true;
	}

	formatex(szKey, charsmax(szKey), "ai_saved_nm%d", iSlot);
	if (PDS_GetString(szKey, szSaved, charsmax(szSaved)) && szSaved[0]) {
		get_user_name(id, szCur, charsmax(szCur));
		if (equali(szCur, szSaved))
			return true;
	}

	return false;
	}

	stock loadSavedTeamFor(id) {
	new iCount;
	if (!PDS_GetCell("ai_saved_n", iCount) || iCount < 1)
	return 0;

	for (new i = 0; i < iCount; i++) {
	if (!savedSlotMatches(id, i))
		continue;

	new szKey[32], iTeam;
	formatex(szKey, charsmax(szKey), "ai_saved_t%d", i);
	if (PDS_GetCell(szKey, iTeam) && (iTeam == TEAM_T || iTeam == TEAM_CT))
		return iTeam;
	}
	return 0;
	}

stock getOnlineCount() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "h");
	return iNum;
}

stock TeamName:getUserTeam(id) {
	return get_member(id, m_iTeam);
}

stock moveToSpec(id) {
	if (!is_user_connected(id))
		return;

	remove_task(TASK_SPEC_JOIN + id);
	set_member(id, m_bTeamChanged, false);
	set_member(id, m_iJoiningState, JOINED);
	set_member(id, m_iMenu, Menu_OFF);
	closeGameMenu(id);

	if (getUserTeam(id) == TEAM_SPECTATOR) {
		finishMoveToSpec(id);
		return;
	}

	// 训练/大厅有无敌, 先关掉再处死, 否则容易只死不进观战
	set_entvar(id, var_takedamage, DAMAGE_AIM);
	if (is_user_alive(id))
		user_silentkill(id);

	// 同一帧 jointeam 经常还停在死亡画面, 隔一帧再拉观战
	set_task(0.1, "taskFinishMoveToSpec", TASK_SPEC_JOIN + id);
}

public taskFinishMoveToSpec(iTaskId) {
	new id = iTaskId - TASK_SPEC_JOIN;
	if (!is_user_connected(id))
		return;
	finishMoveToSpec(id);
}

stock finishMoveToSpec(id) {
	if (g_bLevelChanging || !is_user_connected(id))
		return;

	set_member(id, m_bTeamChanged, false);
	set_member(id, m_iMenu, Menu_OFF);

	if (getUserTeam(id) != TEAM_SPECTATOR) {
		if (!rg_join_team(id, TEAM_SPECTATOR)) {
			rg_internal_cmd(id, "jointeam", "6");
			if (getUserTeam(id) != TEAM_SPECTATOR)
				rg_set_user_team(id, TEAM_SPECTATOR, MODEL_UNASSIGNED, true, false);
		}
	}

	set_member(id, m_iJoiningState, JOINED);
	set_member(id, m_iMenu, Menu_OFF);
	set_entvar(id, var_solid, SOLID_NOT);
	set_entvar(id, var_movetype, MOVETYPE_NOCLIP);
	set_member(id, m_afPhysicsFlags, get_member(id, m_afPhysicsFlags) | PFLAG_OBSERVER);
	set_entvar(id, var_iuser1, OBS_ROAMING);
	if (get_member(id, m_afPhysicsFlags) & PFLAG_OBSERVER)
		rg_set_observer_mode(id, OBS_ROAMING);

	closeGameMenu(id);
}

stock clearSpecJoinTasks() {
	for (new i = 1; i <= MaxClients; i++)
		remove_task(TASK_SPEC_JOIN + i);
}

stock moveToTeam(id, TeamName:iTeam) {
	if (g_bLevelChanging || !is_user_connected(id))
		return;

	remove_task(TASK_SPEC_JOIN + id);
	set_member(id, m_bTeamChanged, false);
	set_member(id, m_iJoiningState, JOINED);
	set_member(id, m_iMenu, Menu_OFF);
	// rg_join_team 会弹选队/选模型, 看起来像观战 UI; 直接设队并出生
	rg_set_user_team(id, iTeam, MODEL_AUTO, true, false);
	set_member(id, m_iJoiningState, JOINED);
	set_member(id, m_iMenu, Menu_OFF);
	closeGameMenu(id);
	if (!is_user_alive(id))
		rg_round_respawn(id);
}

stock closeGameMenu(id) {
	if (!is_user_connected(id))
		return;

	show_menu(id, 0, "", 1);
	set_member(id, m_iMenu, Menu_OFF);
}

stock reopenActiveVoteMenu(id) {
	if (!g_bVoteActive || !is_user_connected(id) || isFakeOrBot(id))
		return;

	if (g_eVoteKind == VOTE_MAP)
		showMapVoteMenu(id);
	else if (g_eVoteKind == VOTE_POOL)
		showPoolVoteMenu(id);
	else if (g_eVoteKind == VOTE_RULES)
		showVoteMenu(id);
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

stock getRequiredSignupCount() {
	if (g_iTeamSizeFixed > 0)
		return g_iTeamSizeFixed * 2;
	return SIGNUP_MIN;
}

stock tryCloseWhenFull() {
	if (g_eState != SIGNUP_OPEN || g_bForceStart)
		return;

	new iNeed;
	if (g_iTeamSizeFixed > 0)
		iNeed = g_iTeamSizeFixed * 2;
	else
		iNeed = SIGNUP_MAX;

	if (g_iSignupCount < iNeed)
		return;

	ai_print_lang(0, "AI_CHAT_FULL", "报名已满 ^3%d^1 人, 开始收团", g_iSignupCount, getEffectiveTeamSize(), getEffectiveTeamSize());
	g_flSignupTimer = 0.0;
	closeSignup();
}

stock getSignupNeed() {
	if (g_iTeamSizeFixed > 0)
		return g_iTeamSizeFixed * 2;
	return SIGNUP_MAX;
}

stock getPlayerPts(id) {
	if (id < 1 || id > MaxClients)
		return PTS_BASE;
	if (g_ePlayerPtsData[id][e_bInit])
		return g_ePlayerPtsData[id][e_iPts];
	return PTS_BASE;
}

stock bool:useModeBucket(id, &iPts, &iWins, &iLoss) {
	if (id < 1 || id > MaxClients || !g_ePlayerPtsData[id][e_bInit])
		return false;

	if (g_iActivePool == POOL_BOOST && (g_ePlayerPtsData[id][e_iBoostWins] + g_ePlayerPtsData[id][e_iBoostLoss]) > 0) {
		iPts = g_ePlayerPtsData[id][e_iBoostPts];
		iWins = g_ePlayerPtsData[id][e_iBoostWins];
		iLoss = g_ePlayerPtsData[id][e_iBoostLoss];
		return true;
	}
	if (g_iActivePool == POOL_SKILL && (g_ePlayerPtsData[id][e_iSkillWins] + g_ePlayerPtsData[id][e_iSkillLoss]) > 0) {
		iPts = g_ePlayerPtsData[id][e_iSkillPts];
		iWins = g_ePlayerPtsData[id][e_iSkillWins];
		iLoss = g_ePlayerPtsData[id][e_iSkillLoss];
		return true;
	}

	iPts = g_ePlayerPtsData[id][e_iPts];
	iWins = g_ePlayerPtsData[id][e_iWins];
	iLoss = g_ePlayerPtsData[id][e_iLoss];
	return true;
}

stock getTrackedPts(id) {
	new iPts, iWins, iLoss;
	if (!useModeBucket(id, iPts, iWins, iLoss))
		return PTS_BASE;
	return iPts;
}

stock getPlayerMatches(id) {
	new iPts, iWins, iLoss;
	if (!useModeBucket(id, iPts, iWins, iLoss))
		return 0;
	return iWins + iLoss;
}

stock getPlayerWinRate(id) {
	new iPts, iWins, iLoss;
	if (!useModeBucket(id, iPts, iWins, iLoss))
		return 50;
	new iGames = iWins + iLoss;
	if (iGames < 1)
		return 50;
	return (iWins * 100) / iGames;
}

// 赢 +15、输 -10。50% 胜率每场仍会涨 2.5, 先扣掉, 避免场次越多分越高
stock getRawSkill(id) {
	new iGames = getPlayerMatches(id);
	if (iGames < 1)
		return PTS_BASE;
	return getTrackedPts(id) - (iGames * 5) / 2;
}

// 0 场 = 基准。5 场只信一半, 之后才逐渐接近自己的实力分
stock getBalanceScore(id, iPrior) {
	new iGames = getPlayerMatches(id);
	if (id < 1 || id > MaxClients || !g_ePlayerPtsData[id][e_bInit] || iGames < 1)
		return iPrior;

	return (getRawSkill(id) * iGames + iPrior * 5) / (iGames + 5);
}

// 基准只用打满 5 场的人。没有这样的人时, 新人统一按 50, 不拿 1 场胜率当中位
stock getSignupPrior() {
	new iScores[SIGNUP_MAX], iCount;
	for (new i = 0; i < g_iSignupCount && iCount < SIGNUP_MAX; i++) {
		new p = g_iSignupList[i];
		if (getPlayerMatches(p) < 5)
			continue;
		iScores[iCount++] = getRawSkill(p);
	}

	if (iCount < 1)
		return PTS_BASE;

	for (new i = 1; i < iCount; i++) {
		new v = iScores[i], j = i - 1;
		while (j >= 0 && iScores[j] > v) {
			iScores[j + 1] = iScores[j];
			j--;
		}
		iScores[j + 1] = v;
	}

	if (iCount % 2)
		return iScores[iCount / 2];
	return (iScores[iCount / 2 - 1] + iScores[iCount / 2]) / 2;
}

stock balanceModeName(id, szOut[], iLen) {
	new szKey[32];
	if (!g_bPtsBalance || g_iBalanceMode <= 0)
		copy(szKey, charsmax(szKey), "AI_MENU_BALANCE_OFF");
	else if (g_iBalanceMode == 2)
		copy(szKey, charsmax(szKey), "AI_MENU_BALANCE_STRICT");
	else if (g_iBalanceMode == 3)
		copy(szKey, charsmax(szKey), "AI_MENU_BALANCE_LOOSE");
	else
		copy(szKey, charsmax(szKey), "AI_MENU_BALANCE_AUTO");

	ai_lang(id, szKey, szOut, iLen);
	if (!szOut[0] || contain(szOut, "AI_MENU_BALANCE") != -1) {
		if (!g_bPtsBalance || g_iBalanceMode <= 0)
			copy(szOut, iLen, "关闭");
		else if (g_iBalanceMode == 2)
			copy(szOut, iLen, "严格");
		else if (g_iBalanceMode == 3)
			copy(szOut, iLen, "宽松");
		else
			copy(szOut, iLen, "自动");
	}
}

stock bool:passesPtsLimit(id) {
	if (!g_bPtsLimit || isUserVipOrAdmin(id))
		return true;
	return getPlayerPts(id) >= g_iPtsLimit;
}

stock bool:isFakeOrBot(id) {
	if (!is_user_connected(id))
		return false;
	if (is_user_bot(id))
		return true;
	if (get_entvar(id, var_flags) & FL_FAKECLIENT)
		return true;

	new szAuth[32];
	get_user_authid(id, szAuth, charsmax(szAuth));
	if (containi(szAuth, "BOT") != -1)
		return true;
	return false;
}

stock bool:isUserVipOrAdmin(id) {
	if (!is_user_connected(id) || isFakeOrBot(id))
		return false;

	return isUserFullWatcher(id) || isUserAdmin(id) || is_user_admin(id);
}

stock bool:isAdminOnline() {
	for (new i = 1; i <= MaxClients; i++) {
		if (isUserVipOrAdmin(i))
			return true;
	}
	return false;
}

stock getFirstVipOrAdmin() {
	for (new i = 1; i <= MaxClients; i++) {
		if (isUserVipOrAdmin(i))
			return i;
	}
	return 0;
}

stock bool:showSetupToAdmins() {
	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		if (!hasAmxxMenu(i))
			showSetupMenu(i);
		bShown = true;
	}
	return bShown;
}

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

// 关闭平衡: 随机分组. 开启平衡: 按估算分从高到低轮流, 并在宽松度内随机
stock shuffleTeamsNow() {
	if (g_bPtsBalance)
		balanceTeamsNow();
	else
		randomTeamsNow();
}

stock randomTeamsNow() {
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

stock balanceTeamsNow() {
	new iSize = getEffectiveTeamSize();
	new iPool[SIGNUP_MAX], iScore[SIGNUP_MAX], iCount;
	new iPrior = getSignupPrior();
	new iNoise;
	if (g_iBalanceMode == 3)
		iNoise = 60;
	else if (g_iBalanceMode != 2)
		iNoise = 15;

	for (new i = 0; i < g_iSignupCount && iCount < SIGNUP_MAX; i++) {
		new p = g_iSignupList[i];
		iPool[iCount] = p;
		iScore[iCount] = getBalanceScore(p, iPrior);
		if (iNoise > 0)
			iScore[iCount] += random(iNoise * 2 + 1) - iNoise;
		iCount++;
	}

	for (new i = 1; i < iCount; i++) {
		new p = iPool[i], s = iScore[i], j = i - 1;
		while (j >= 0 && iScore[j] < s) {
			iScore[j + 1] = iScore[j];
			iPool[j + 1] = iPool[j];
			j--;
		}
		iScore[j + 1] = s;
		iPool[j + 1] = p;
	}

	for (new i = 0; i <= MAX_PLAYERS; i++)
		g_iSignupTeam[i] = 0;

	new iT, iCT, iSumT, iSumCT;
	for (new i = 0; i < iCount; i++) {
		if (iT >= iSize && iCT >= iSize)
			break;

		new p = iPool[i];
		new iTeam;
		if (iT >= iSize)
			iTeam = TEAM_CT;
		else if (iCT >= iSize)
			iTeam = TEAM_T;
		else if (iT != iCT)
			iTeam = (iT < iCT) ? TEAM_T : TEAM_CT;
		else if (iSumT < iSumCT)
			iTeam = TEAM_T;
		else if (iSumCT < iSumT)
			iTeam = TEAM_CT;
		else
			iTeam = random(2) ? TEAM_T : TEAM_CT;

		g_iSignupTeam[p] = iTeam;
		if (iTeam == TEAM_T) {
			iT++;
			iSumT += iScore[i];
		} else {
			iCT++;
			iSumCT += iScore[i];
		}
	}
}

// [HNSai] 当前比赛模式 / 人数 / 类型 / 状态
stock ai_printModeInfo(const id) {
	new szRule[32], szType[32], szState[32];
	ai_ruleName(id, _:g_iMatchRules, szRule, charsmax(szRule));
	ai_typeName(id, szType, charsmax(szType));
	ai_stateName(id, szState, charsmax(szState));
	ai_print_lang(id, "AI_CHAT_MODE_INFO", "当前比赛模式: ^3%s^1 | 人数: ^3%d v %d^1 | 类型: ^3%s^1 | 状态: ^3%s",
		szRule, getEffectiveTeamSize(), getEffectiveTeamSize(), szType, szState);
}

stock ai_unescape(szText[], iLen) {
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^2", "^2");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock ai_print_send(const id, const msgFormated[]) {
	if (!is_user_connected(id))
		return;

	if (msgFormated[0] == '[')
		client_print_color(id, print_team_default, "%s", msgFormated);
	else
		client_print_color(id, print_team_default, "[^4HNS^1] %s", msgFormated);
}

stock ai_print(const id, const message[], any:...) {
	new msgFormated[191];
	vformat(msgFormated, charsmax(msgFormated), message, 3);

	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_send(iPlayers[i], msgFormated);
		return;
	}

	ai_print_send(id, msgFormated);
}

stock ai_print_lang(const id, const szKey[], const szFallback[], any:...) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			new szFmt[191], szOut[191];
			ai_lang(iPlayers[i], szKey, szFmt, charsmax(szFmt));
			if (!szFmt[0] || equal(szFmt, szKey))
				copy(szFmt, charsmax(szFmt), szFallback);
			vformat(szOut, charsmax(szOut), szFmt, 4);
			ai_print_send(iPlayers[i], szOut);
		}
		return;
	}

	new szFmt[191], szOut[191];
	ai_lang(id, szKey, szFmt, charsmax(szFmt));
	if (!szFmt[0] || equal(szFmt, szKey))
		copy(szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, charsmax(szOut), szFmt, 4);
	ai_print_send(id, szOut);
}

stock ai_print_rule(const id, const szKey[], const szFallback[], iRule) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_rule(iPlayers[i], szKey, szFallback, iRule);
		return;
	}

	new szRule[32];
	ai_ruleName(id, iRule, szRule, charsmax(szRule));
	ai_print_lang(id, szKey, szFallback, szRule);
}

stock ai_print_rule_count(const id, const szKey[], const szFallback[], iRule, iCount) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_rule_count(iPlayers[i], szKey, szFallback, iRule, iCount);
		return;
	}

	new szRule[32];
	ai_ruleName(id, iRule, szRule, charsmax(szRule));
	ai_print_lang(id, szKey, szFallback, szRule, iCount);
}

stock ai_print_type(const id, const szKey[], const szFallback[]) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_type(iPlayers[i], szKey, szFallback);
		return;
	}

	new szType[32];
	ai_typeName(id, szType, charsmax(szType));
	ai_print_lang(id, szKey, szFallback, szType);
}

stock ai_print_match_info(const id, iPlayers) {
	if (id == 0) {
		new iList[MAX_PLAYERS], iNum;
		get_players(iList, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_match_info(iList[i], iPlayers);
		return;
	}

	new szType[32], szRule[32];
	ai_typeName(id, szType, charsmax(szType));
	ai_ruleName(id, _:g_iMatchRules, szRule, charsmax(szRule));
	ai_print_lang(id, "AI_CHAT_MATCH_START_INFO", "^2类型: %s ^1| ^2模式: %s ^1| 报名 %d 人 | 祝大家好运!", szType, szRule, iPlayers);
}

stock ai_lang(id, const szKey[], szOut[], iLen) {
	if (id < 1)
		id = 0;

	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0])
		copy(szOut, iLen, szKey);
	ai_unescape(szOut, iLen);
}

stock ai_typeName(id, szOut[], iLen) {
	ai_lang(id, g_bSponsorMatch ? "AI_TYPE_SPONSOR_CHAT" : "AI_TYPE_CASUAL_CHAT", szOut, iLen);
	if (!szOut[0] || equal(szOut, "AI_TYPE_SPONSOR_CHAT") || equal(szOut, "AI_TYPE_CASUAL_CHAT"))
		copy(szOut, iLen, g_bSponsorMatch ? "赞助局" : "娱乐局");
}

stock ai_stateName(id, szOut[], iLen) {
	new iState = _:g_eState;
	if (iState < 0 || iState >= 5) {
		copy(szOut, iLen, g_szStateName[0]);
		return;
	}

	ai_lang(id, g_szStateKeys[iState], szOut, iLen);
	if (!szOut[0] || equal(szOut, g_szStateKeys[iState]))
		copy(szOut, iLen, g_szStateName[iState]);
}

stock ai_poolName(id, iPool, szOut[], iLen) {
	ai_lang(id, (iPool == POOL_SKILL) ? "AI_POOL_SKILL_CHAT" : "AI_POOL_BOOST_CHAT", szOut, iLen);
	if (!szOut[0] || equal(szOut, "AI_POOL_SKILL_CHAT") || equal(szOut, "AI_POOL_BOOST_CHAT"))
		copy(szOut, iLen, (iPool == POOL_SKILL) ? "Skill" : "Boost");
}

stock ai_print_pool(const id, const szKey[], const szFallback[], iPool) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_pool(iPlayers[i], szKey, szFallback, iPool);
		return;
	}

	new szPool[16];
	ai_poolName(id, iPool, szPool, charsmax(szPool));
	ai_print_lang(id, szKey, szFallback, szPool);
}

stock ai_print_pool_end(const id, iPool, iSkill, iBoost) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
			ai_print_pool_end(iPlayers[i], iPool, iSkill, iBoost);
		return;
	}

	new szPool[16];
	ai_poolName(id, iPool, szPool, charsmax(szPool));
	ai_print_lang(id, "AI_CHAT_POOL_VOTE_END", "地图池投票结束: ^3%s^1 (Skill %d / Boost %d)", szPool, iSkill, iBoost);
}

stock ai_ruleName(id, iRule, szOut[], iLen) {
	if (iRule < 0 || iRule >= RULE_COUNT) {
		copy(szOut, iLen, g_szRules[0]);
		return;
	}

	ai_lang(id, g_szRuleKeys[iRule], szOut, iLen);
	if (!szOut[0] || equal(szOut, g_szRuleKeys[iRule]))
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

stock mapPoolOf(const szMap[]) {
	if (!szMap[0])
		return -1;

	for (new i = 0; i < g_iSkillMapCount; i++) {
		if (equali(g_szSkillMaps[i], szMap))
			return POOL_SKILL;
	}
	for (new i = 0; i < g_iBoostMapCount; i++) {
		if (equali(g_szBoostMaps[i], szMap))
			return POOL_BOOST;
	}
	return -1;
}

stock announceMapStyle(const id) {
	if (g_iSkillMapCount <= 0 && g_iBoostMapCount <= 0)
		loadMapPools();

	new szMap[MAP_NAME_LEN];
	if (g_szPickedMap[0])
		copy(szMap, charsmax(szMap), g_szPickedMap);
	else
		get_mapname(szMap, charsmax(szMap));

	new iPool = mapPoolOf(szMap);
	if (iPool < 0)
		iPool = g_iActivePool;
	announceCurrentPool(id, iPool);
}

stock announceCurrentPool(const id, iPool) {
	if (iPool == POOL_SKILL)
		ai_print_lang(id, "AI_CHAT_SKILL_MATCH", "当前池: ^3Skill");
	else
		ai_print_lang(id, "AI_CHAT_BOOST_MATCH", "当前池: ^4Boost");
}

public showTypeMenu(id) {
	if (!is_user_connected(id))
		return;

	if (!isUserVipOrAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_TYPE_VIP", "只有管理员/VIP 才能选择比赛类型");
		showMainMenu2(id);
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
		showMainMenu2(id);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id)) {
		showMainMenu2(id);
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
				ai_print_lang(p, "AI_CHAT_GUEST_REMOVED", "已从报名中移除: 盗版玩家不能参与赞助局");
			}
		}
	}

	ai_print_type(0, "AI_CHAT_TYPE_SET", "比赛类型已设为: ^3%s");
	showMainMenu2(id);
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

	ai_print_lang(0, "AI_CHAT_SETUP_DONE", "分组完成, 现在选择地图");
	remove_task(TASK_SETUP_MENU);
	beginMapSelect();
}

public taskShowPostGroupMenus() {
	if (g_eState != SIGNUP_SETUP || !g_bPostGroupSetup)
		return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		if (!hasAmxxMenu(iPlayers[i]))
			closeGameMenu(iPlayers[i]);
	}

	if (showSetupToAdmins()) {
		if (g_iSetupMenuTries == 0)
			ai_print_lang(0, "AI_CHAT_SETUP_ADMIN", "管理员/VIP 优先选择比赛模式 (聊天输入 /signup 可重新打开)");
	} else if (g_bVoteActive) {
		for (new i = 0; i < iNum; i++)
			reopenActiveVoteMenu(iPlayers[i]);
	} else {
		startRulesVote(0, -1);
	}

	g_iSetupMenuTries++;
	if (g_iSetupMenuTries < 8)
		set_task(0.5, "taskShowPostGroupMenus", TASK_SETUP_MENU);
}

stock bool:hasAmxxMenu(id) {
	if (!is_user_connected(id))
		return false;

	new iMenu, iNewMenu;
	if (!player_menu_info(id, iMenu, iNewMenu))
		return false;
	return (iNewMenu != -1);
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
		announceCurrentPool(0, POOL_BOOST);
		ai_print_rule(0, "AI_CHAT_BOOST_POOL", "%s 使用 Boost 地图池, 请选择随机 / 投票 / 指定地图", _:g_iMatchRules);
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
		ai_print_lang(0, "AI_CHAT_POOL_ADMIN", "管理员/VIP 优先选择地图池 (Skill / Boost)");
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

	announceCurrentPool(0, g_iActivePool);
	ai_print_pool(0, "AI_CHAT_POOL_SET", "地图池已设为: ^3%s", g_iActivePool);
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

	ai_print_lang(0, "AI_CHAT_POOL_VOTE_START", "开始投票选择 Skill / Boost 地图池 (^3%d^1 秒)", g_iVoteSeconds);

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
		ai_print_lang(id, "AI_CHAT_ERR_ALREADY_VOTED", "你已经投过票了");
		return PLUGIN_HANDLED;
	}

	new iPool = str_to_num(data[5]);
	if (iPool < 0 || iPool > 1)
		return PLUGIN_HANDLED;

	g_bVoteDone[id] = true;
	g_iPoolVoteTally[iPool]++;

	new szName[32], szPool[16];
	get_user_name(id, szName, charsmax(szName));
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		ai_poolName(iPlayers[i], iPool, szPool, charsmax(szPool));
		ai_print_lang(iPlayers[i], "AI_CHAT_VOTED_POOL", "%s 投票地图池: ^3%s", szName, szPool);
	}
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
	announceCurrentPool(0, g_iActivePool);
	ai_print_pool_end(0, g_iActivePool, g_iPoolVoteTally[POOL_SKILL], g_iPoolVoteTally[POOL_BOOST]);

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
		beginRandomMapWait();
	} else if (equal(data, "vote")) {
		ai_print_lang(0, "AI_CHAT_MAP_VOTE_ADMIN", "管理员发起地图投票");
		startMapVote();
	} else if (equal(data, "current")) {
		get_mapname(g_szPickedMap, charsmax(g_szPickedMap));
		ai_print_lang(0, "AI_CHAT_MAP_CURRENT", "使用当前地图: ^3%s", g_szPickedMap);
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
		ai_print_lang(id, "AI_CHAT_MAP_MISSING", "地图 ^3%s^1 缺少模型或文件, 请换一张", g_szAllMaps[iMap]);
		showMapPickMenu(id);
		return PLUGIN_HANDLED;
	}

	copy(g_szPickedMap, charsmax(g_szPickedMap), g_szAllMaps[iMap]);
	ai_print_lang(0, "AI_CHAT_MAP_PICKED", "指定地图: ^3%s", g_szPickedMap);
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

	ai_print_lang(0, "AI_CHAT_MAP_VOTE_START", "开始地图投票 (^3%d^1 秒)", g_iVoteSeconds);

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
		ai_print_lang(id, "AI_CHAT_ERR_ALREADY_VOTED", "你已经投过票了");
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
	ai_print_lang(0, "AI_CHAT_VOTED_MAP", "%s 投票地图: ^3%s", szName, g_szMapList[iMap]);
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
		ai_print_lang(0, "AI_CHAT_MAP_VOTE_NONE", "地图投票无人投票, 随机选择 ^3%s", g_szPickedMap);
	} else if (!isMapSafeToLoad(g_szMapList[iBest])) {
		ai_print_lang(0, "AI_CHAT_MAP_VOTE_UNSAFE", "地图 ^3%s^1 缺少模型, 改随机安全图", g_szMapList[iBest]);
		pickRandomMap();
	} else {
		copy(g_szPickedMap, charsmax(g_szPickedMap), g_szMapList[iBest]);
		ai_print_lang(0, "AI_CHAT_MAP_VOTE_END", "地图投票结束: ^3%s^1 (%d 票)", g_szPickedMap, iBestCount);
	}

	afterMapChosen();
}

public afterMapChosen() {
	if (g_bSponsorMatch)
		beginSponsorInput();
	else
		startMatch();
}


stock beginRandomMapWait() {
	remove_task(TASK_RANDOM_MAP);
	g_bRandomMapWait = true;
	g_iRandomMapSeconds = RANDOM_MAP_WAIT;
	ai_print_lang(0, "AI_CHAT_MAP_RANDOM_WAIT", "随机地图: ^3%s^1, ^3%d^1 秒后换图. 管理员输入 ^3/nomaps^1 可取消", g_szPickedMap, g_iRandomMapSeconds);
	set_task(1.0, "taskRandomMapWait", TASK_RANDOM_MAP, .flags = "b");
}

public taskRandomMapWait() {
	if (!g_bRandomMapWait) {
		remove_task(TASK_RANDOM_MAP);
		return;
	}

	g_iRandomMapSeconds--;
	if (g_iRandomMapSeconds > 0) {
		ai_print_lang(0, "AI_CHAT_MAP_RANDOM_TICK", "随机地图 ^3%s^1, 剩余 ^3%d^1 秒换图. 管理员 ^3/nomaps^1 取消", g_szPickedMap, g_iRandomMapSeconds);
		return;
	}

	remove_task(TASK_RANDOM_MAP);
	g_bRandomMapWait = false;
	ai_print_lang(0, "AI_CHAT_MAP_RANDOM", "地图已随机选择: ^3%s", g_szPickedMap);
	afterMapChosen();
}

public cmdNoMaps(id) {
	if (!isUserAdmin(id)) {
		ai_print_lang(id, "AI_CHAT_ERR_NOMAPS_ADMIN", "只有管理员可以取消随机换图");
		return PLUGIN_HANDLED;
	}

	if (!g_bRandomMapWait) {
		ai_print_lang(id, "AI_CHAT_ERR_NOMAPS_NONE", "当前没有正在倒计时的随机换图");
		return PLUGIN_HANDLED;
	}

	remove_task(TASK_RANDOM_MAP);
	g_bRandomMapWait = false;
	g_iRandomMapSeconds = 0;
	g_szPickedMap[0] = EOS;

	ai_print_lang(0, "AI_CHAT_MAP_RANDOM_STOP", "管理员取消了随机换图, 重新选择地图");
	if (is_user_connected(id))
		showMapChoiceMenu(id);
	return PLUGIN_HANDLED;
}
public beginSponsorInput() {
	new iAdmin = getFirstVipOrAdmin();
	if (!iAdmin) {
		ai_print_lang(0, "AI_CHAT_SPONSOR_SKIP", "赞助局没有管理员/VIP 在线, 跳过赞助者填写");
		startMatch();
		return;
	}

	g_bWaitingSponsor = true;
	g_iSponsorAskId = iAdmin;
	g_bSponsorNameInput[iAdmin] = true;
	ai_print_lang(0, "AI_CHAT_SPONSOR_ASK", "请管理员/VIP 在聊天框输入赞助者名字 (剩余 %d 秒, /取消)", floatround(SPONSOR_WAIT));
	client_cmd(iAdmin, "messagemode");
	set_task(SPONSOR_WAIT, "taskSponsorTimeout", TASK_SPONSOR_WAIT);
}

public taskSponsorTimeout() {
	if (!g_bWaitingSponsor)
		return;

	g_bWaitingSponsor = false;
	if (g_iSponsorAskId)
		g_bSponsorNameInput[g_iSponsorAskId] = false;

	ai_print_lang(0, "AI_CHAT_SPONSOR_TIMEOUT", "赞助者填写超时, 继续开赛");
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
		ai_print_lang(id, "AI_CHAT_SPONSOR_CANCEL", "已取消填写赞助者名字");
		if (g_bPostGroupSetup)
			startMatch();
		return PLUGIN_HANDLED;
	}

	copy(g_szSponsorName, charsmax(g_szSponsorName), szArgs);
	replace_all(g_szSponsorName, charsmax(g_szSponsorName), "%", "");
	hns_external_set_sponsor_name(g_szSponsorName);
	ai_print_lang(0, "AI_CHAT_SPONSOR_NAME", "赞助者: ^3%s^1, 请选择 GBIC 金币数量", g_szSponsorName);

	beginSponsorGcMenu(id);
	return PLUGIN_HANDLED;
}

public beginSponsorGcMenu(id) {
	if (!is_user_connected(id)) {
		if (g_bPostGroupSetup)
			startMatch();
		return;
	}

	g_bWaitingSponsorGc = true;
	g_iSponsorAskId = id;
	showSponsorGcMenu(id);
	set_task(SPONSOR_WAIT, "taskSponsorGcTimeout", TASK_SPONSOR_GC);
}

public showSponsorGcMenu(id) {
	new szTitle[96];
	formatex(szTitle, charsmax(szTitle), "\r选择 GBIC 金币数量");
	new menu = menu_create(szTitle, "SponsorGcMenuHandler");
	menu_additem(menu, "\y5 金币", "5");
	menu_additem(menu, "\y10 金币", "10");
	menu_additem(menu, "\y15 金币", "15");
	menu_additem(menu, "\y20 金币", "20");
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu);
}

public SponsorGcMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (g_bWaitingSponsorGc)
			showSponsorGcMenu(id);
		return PLUGIN_HANDLED;
	}

	new data[8], name[32], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!g_bWaitingSponsorGc)
		return PLUGIN_HANDLED;

	new iGC = str_to_num(data);
	if (iGC < 5 || iGC > 20 || iGC % 5 != 0) {
		ai_print_lang(id, "AI_CHAT_GC_INVALID", "GBIC 只能选 5 / 10 / 15 / 20");
		showSponsorGcMenu(id);
		return PLUGIN_HANDLED;
	}

	g_bWaitingSponsorGc = false;
	remove_task(TASK_SPONSOR_GC);
	g_iSponsorGC = iGC;
	hns_external_set_sponsor_gc(iGC);
	ai_print_lang(0, "AI_CHAT_SPONSOR_GC", "赞助者: ^3%s^1 | GBIC: ^3%d", g_szSponsorName, g_iSponsorGC);

	if (g_bPostGroupSetup)
		startMatch();
	return PLUGIN_HANDLED;
}

public taskSponsorGcTimeout() {
	if (!g_bWaitingSponsorGc)
		return;

	g_bWaitingSponsorGc = false;
	if (g_iSponsorGC < 5)
		g_iSponsorGC = 5;
	hns_external_set_sponsor_gc(g_iSponsorGC);
	ai_print_lang(0, "AI_CHAT_GC_TIMEOUT", "GBIC 选择超时, 默认 ^3%d^1, 继续开赛", g_iSponsorGC);
	startMatch();
}

/*
 * HnsAISignupBots.sma
 * AI 报名测试人机: 凑人数测报名 / 分组 / 换图保队
 *
 * 用法:
 *   say /aibots          打开测试人机菜单
 *   say /aibot           同上
 *   say /aibots 10       直接凑满指定人数 (上限 12)
 *   say /aibotskill      踢掉全部测试人机
 *   say /aisignupbots    给已在场的测试人机补报名
 *
 * 注意:
 *   - 假客户端 steamid 是 BOT, 只能测娱乐局, 赞助局会被报名系统拒绝
 *   - 换图后会按保存名单自动重建同名 AIBot, 用于测保队
 *   - 必须 changelevel 后才会加载本插件
 */
#include <amxmodx>
#include <fakemeta>
#include <fakemeta_stocks>
#include <reapi>
#include <hns_matchsystem>
#include <hns_ai_signup>
#include <PersistentDataStorage>

#define PLUGIN_VERSION "1.5"
#define BOT_MAX        12
#define BOT_PREFIX     "AIBot"

new const g_szBotNames[BOT_MAX][] = {
	"AIBot01", "AIBot02", "AIBot03", "AIBot04",
	"AIBot05", "AIBot06", "AIBot07", "AIBot08",
	"AIBot09", "AIBot10", "AIBot11", "AIBot12"
};

public plugin_init() {
	register_plugin("AI 报名测试人机", PLUGIN_VERSION, "HNSai");

	register_clcmd("say /aibots", "cmdAiBots");
	register_clcmd("say /aibot", "cmdAiBots");
	register_clcmd("say /aibotskill", "cmdAiBotsKill");
	register_clcmd("say /aisignupbots", "cmdAiSignupBots");
	register_concmd("aibots", "cmdAiBots");
	register_concmd("aibot", "cmdAiBots");
	register_concmd("aibotskill", "cmdAiBotsKill");
	register_concmd("aisignupbots", "cmdAiSignupBots");

	new iCount;
	if (PDS_GetCell("ai_saved_n", iCount) && iCount > 0)
		set_task(2.0, "taskRecreateSavedBots");
}

public taskRecreateSavedBots() {
	new iCount;
	if (!PDS_GetCell("ai_saved_n", iCount) || iCount < 1)
		return;

	new iMade;
	for (new i = 0; i < iCount; i++) {
		new szKey[32], szSaved[48];
		formatex(szKey, charsmax(szKey), "ai_saved_k%d", i);
		if (!PDS_GetString(szKey, szSaved, charsmax(szSaved)))
			continue;
		if (contain(szSaved, "N:AIBot") != 0)
			continue;

		new szName[32];
		copy(szName, charsmax(szName), szSaved[2]);
		if (createBotNamed(szName, false))
			iMade++;
	}

	if (iMade)
		log_amx("[AIBOT] recreated %d test bots after mapchange", iMade);
}

public cmdAiBots(id) {
	new szArg[16];
	read_argv(1, szArg, charsmax(szArg));
	if (contain(szArg, "/aibot") == 0)
		read_argv(2, szArg, charsmax(szArg));

	new iWant = str_to_num(szArg);
	if (iWant > 0) {
		fillBots(id, iWant);
		return PLUGIN_HANDLED;
	}

	showBotMenu(id);
	return PLUGIN_HANDLED;
}

public showBotMenu(id) {
	if (!is_user_connected(id))
		return;

	new iHumans = countHumans();
	new iBots = countTestBots();
	new iOnline = iHumans + iBots;

	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "\yAI 测试人机^n\w真人 %d | 人机 %d | 在线 %d", iHumans, iBots, iOnline);

	new menu = menu_create(szTitle, "BotMenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "凑满 6 人 \y(3v3)");
	menu_additem(menu, szItem, "fill_6");
	formatex(szItem, charsmax(szItem), "凑满 8 人 \y(4v4)");
	menu_additem(menu, szItem, "fill_8");
	formatex(szItem, charsmax(szItem), "凑满 10 人 \y(5v5)");
	menu_additem(menu, szItem, "fill_10");
	formatex(szItem, charsmax(szItem), "凑满 12 人 \y(6v6)");
	menu_additem(menu, szItem, "fill_12");

	menu_addblank(menu, 0);

	formatex(szItem, charsmax(szItem), "再加 1 个测试人机");
	menu_additem(menu, szItem, "add_1");
	formatex(szItem, charsmax(szItem), "给人机补报名");
	menu_additem(menu, szItem, "signup");
	formatex(szItem, charsmax(szItem), "\r踢掉全部测试人机");
	menu_additem(menu, szItem, "kill");

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_EXITNAME, "退出");
	menu_display(id, menu);
}

public BotMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (equal(data, "fill_6"))
		fillBots(id, 6);
	else if (equal(data, "fill_8"))
		fillBots(id, 8);
	else if (equal(data, "fill_10"))
		fillBots(id, 10);
	else if (equal(data, "fill_12"))
		fillBots(id, 12);
	else if (equal(data, "add_1")) {
		new iWant = countHumans() + countTestBots() + 1;
		if (iWant > BOT_MAX)
			iWant = BOT_MAX;
		fillBots(id, iWant);
	} else if (equal(data, "signup"))
		cmdAiSignupBots(id);
	else if (equal(data, "kill"))
		cmdAiBotsKill(id);

	// 收团/赛前设置时不要重开人机菜单, 否则会盖住模式/地图选择
	if (hns_ai_get_state() >= 2)
		return PLUGIN_HANDLED;

	showBotMenu(id);
	return PLUGIN_HANDLED;
}

stock fillBots(id, iWant) {
	if (iWant < 1)
		iWant = 6;
	if (iWant > BOT_MAX)
		iWant = BOT_MAX;

	new iMode = hns_get_mode();
	if (iMode != MODE_TRAINING && iMode != MODE_LOBBY)
		hns_set_mode(MODE_TRAINING);

	new iHumans = countHumans();
	new iNeed = iWant - iHumans;
	if (iNeed < 1) {
		client_print_color(id, print_team_blue, "[^3HNSai^1] 已有 ^3%d^1 名真人, 无需加人机", iHumans);
		signupAllBots();
		return;
	}

	new iCreated;
	for (new i = 0; i < BOT_MAX && iCreated < iNeed; i++) {
		if (createBotNamed(g_szBotNames[i], true))
			iCreated++;
	}

	new iSigned = signupAllBots();
	client_print_color(0, print_team_blue,
		"[^3HNSai^1] 测试人机: 新建 ^3%d^1, 报名 ^3%d^1 | 目标 ^3%d^1 人 (含真人 %d)",
		iCreated, iSigned, iWant, iHumans);
	log_amx("[AIBOT] created=%d signed=%d want=%d humans=%d", iCreated, iSigned, iWant, iHumans);

	if (hns_ai_get_state() >= 2)
		client_print_color(id, print_team_blue, "[^3HNSai^1] 人数已满, 请选择比赛模式/地图 (聊天输入 /signup)");
}

public cmdAiBotsKill(id) {
	new iCount;
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i) || !is_user_bot(i))
			continue;

		new szName[32];
		get_user_name(i, szName, charsmax(szName));
		if (strncmp(szName, BOT_PREFIX, 5) != 0)
			continue;

		server_cmd("kick #%d", get_user_userid(i));
		iCount++;
	}

	client_print_color(id, print_team_blue, "[^3HNSai^1] 已踢测试人机 ^3%d^1 个", iCount);
	log_amx("[AIBOT] kicked %d test bots", iCount);
	return PLUGIN_HANDLED;
}

public cmdAiSignupBots(id) {
	new iSigned = signupAllBots();
	client_print_color(id, print_team_blue, "[^3HNSai^1] 已给测试人机补报名 ^3%d^1 人", iSigned);
	return PLUGIN_HANDLED;
}

stock signupAllBots() {
	new iSigned;
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i) || !is_user_bot(i))
			continue;

		new szName[32];
		get_user_name(i, szName, charsmax(szName));
		if (strncmp(szName, BOT_PREFIX, 5) != 0)
			continue;

		if (hns_ai_force_signup(i))
			iSigned++;
	}
	return iSigned;
}

stock countHumans() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	return iNum;
}

stock countTestBots() {
	new iCount;
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i) || !is_user_bot(i))
			continue;

		new szName[32];
		get_user_name(i, szName, charsmax(szName));
		if (strncmp(szName, BOT_PREFIX, 5) == 0)
			iCount++;
	}
	return iCount;
}

stock bool:createBotNamed(const szName[], bool:bSpec) {
	if (findBotByName(szName))
		return false;

	new ent = EF_CreateFakeClient(szName);
	if (!ent)
		return false;

	new player = get_user_index(szName);
	if (!player)
		player = ent;

	if (!is_user_connected(player))
		dllfunc(DLLFunc_ClientPutInServer, player);

	if (!is_user_connected(player))
		return false;

	remove_task(player);
	remove_user_flags(player);
	set_member(player, m_bTeamChanged, false);
	set_member(player, m_iJoiningState, JOINED);
	set_member(player, m_iMenu, Menu_OFF);
	if (bSpec)
		rg_set_user_team(player, TEAM_SPECTATOR, MODEL_UNASSIGNED, false, false);
	return true;
}

stock findBotByName(const szName[]) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "dh");
	for (new i = 0; i < iNum; i++) {
		new szCur[32];
		get_user_name(iPlayers[i], szCur, charsmax(szCur));
		if (equal(szCur, szName))
			return iPlayers[i];
	}
	return 0;
}

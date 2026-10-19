/* ============================================================
   HnsPlayerAdmin  -  管理员玩家管理
   从 14lukas14-admin-menu 改写, 菜单走 hns_language.txt
   入口: 管理员设置第8项 / hns_playermenu
   功能: 选人, 拍打, 处死, 踢出, 封禁, 换队, 处死全队
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <hns_language>
#include <hns_matchsystem>

#define PLUGIN "HNS Player Admin"
#define VERSION "1.0.0"
#define AUTHOR "GTR"

new g_iTarget[MAX_PLAYERS + 1];
new bool:g_bForceRevive[MAX_PLAYERS + 1];
new g_iFilter[MAX_PLAYERS + 1];
new bool:g_bAliveOnly[MAX_PLAYERS + 1];
new g_szReason[MAX_PLAYERS + 1][192];
new g_iPunish[MAX_PLAYERS + 1];

enum _:PUNISH {
	PUNISH_NONE = 0,
	PUNISH_SLAP,
	PUNISH_SLAY,
	PUNISH_KICK,
	PUNISH_BAN,
	PUNISH_BANIP
}

stock Lang(id, const key[], out[], len, const fallback[]) {
	HnsLang_Get(id, key, out, len);
	if (!out[0])
		copy(out, len, fallback);
	replace_all(out, len, "^^n", "^n");
	replace_all(out, len, "^^1", "^1");
	replace_all(out, len, "^^3", "^3");
	replace_all(out, len, "^^4", "^4");
}

stock bool:CanUse(id) {
	if (!is_user_connected(id))
		return false;
	if (isUserAdmin(id) || isUserFullWatcher(id))
		return true;
	return (get_user_flags(id) & (ADMIN_BAN|ADMIN_KICK|ADMIN_SLAY|ADMIN_RCON)) != 0;
}

stock DisplayPlayerMenu(id, menu) {
	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return;
	}
	menu_display(id, menu);
}

stock bool:IsVipOnly(id) {
	return isUserFullWatcher(id) && !isUserAdmin(id);
}

stock Deny(id) {
	new szText[96];
	Lang(id, "PADM_ADMIN_ONLY", szText, charsmax(szText), "^4[HNS]^1 只有管理员可以使用。");
	client_print_color(id, print_team_red, "%s", szText);
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_library("hns_playeradmin");

	register_clcmd("hns_playermenu", "CmdMenu");
	register_clcmd("say /playermenu", "CmdMenu");
	register_clcmd("say_team /playermenu", "CmdMenu");
	register_clcmd("hns_padm_reason", "CmdCustomReason");
	RegisterHookChain(RG_CSGameRules_FPlayerCanRespawn, "OnCanRespawn");
}

public OnCanRespawn(id) {
	if (g_bForceRevive[id]) {
		SetHookChainReturn(ATYPE_INTEGER, true);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public plugin_natives() {
	register_native("hns_playeradmin_open", "NativeOpen");
}

public NativeOpen(plugin, params) {
	if (params < 1)
		return 0;
	new id = get_param(1);
	if (!is_user_connected(id) || !CanUse(id))
		return 0;
	ShowFilterMenu(id);
	return 1;
}

public client_disconnected(id) {
	g_iTarget[id] = 0;
	g_bForceRevive[id] = false;
	g_iFilter[id] = 0;
	g_bAliveOnly[id] = false;
	g_iPunish[id] = PUNISH_NONE;
	g_szReason[id][0] = 0;
}

public CmdMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	if (!CanUse(id)) {
		Deny(id);
		return PLUGIN_HANDLED;
	}
	ShowFilterMenu(id);
	return PLUGIN_HANDLED;
}

ShowFilterMenu(id) {
	new szTitle[64], szItem[64];
	Lang(id, "PADM_FILTER_TITLE", szTitle, charsmax(szTitle), "选择玩家范围");
	new menu = menu_create(szTitle, "FilterHandler");

	Lang(id, "PADM_FILTER_ALL", szItem, charsmax(szItem), "全部玩家");
	menu_additem(menu, szItem, "0");
	Lang(id, "PADM_FILTER_TT", szItem, charsmax(szItem), "只看 T");
	menu_additem(menu, szItem, "1");
	Lang(id, "PADM_FILTER_CT", szItem, charsmax(szItem), "只看 CT");
	menu_additem(menu, szItem, "2");
	Lang(id, "PADM_FILTER_SPEC", szItem, charsmax(szItem), "只看观察者");
	menu_additem(menu, szItem, "3");
	Lang(id, "PADM_FILTER_TT_ALIVE", szItem, charsmax(szItem), "存活 T");
	menu_additem(menu, szItem, "4");
	Lang(id, "PADM_FILTER_CT_ALIVE", szItem, charsmax(szItem), "存活 CT");
	menu_additem(menu, szItem, "5");
	Lang(id, "PADM_SLAY_TT", szItem, charsmax(szItem), "处死全部存活 T");
	menu_additem(menu, szItem, "6");
	Lang(id, "PADM_SLAY_CT", szItem, charsmax(szItem), "处死全部存活 CT");
	menu_additem(menu, szItem, "7");
	Lang(id, "PADM_SPEC_TARGET", szItem, charsmax(szItem), "处罚正在观察的玩家");
	menu_additem(menu, szItem, "8");

	new szExit[32];
	Lang(id, "MENU_EXIT", szExit, charsmax(szExit), "退出");
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	DisplayPlayerMenu(id, menu);
}

public FilterHandler(id, menu, item) {
	if (!is_user_connected(id) || item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if (!CanUse(id)) {
		menu_destroy(menu);
		Deny(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);

	switch (str_to_num(info)) {
		case 0: { g_iFilter[id] = 0; g_bAliveOnly[id] = false; ShowPlayers(id); }
		case 1: { g_iFilter[id] = 1; g_bAliveOnly[id] = false; ShowPlayers(id); }
		case 2: { g_iFilter[id] = 2; g_bAliveOnly[id] = false; ShowPlayers(id); }
		case 3: { g_iFilter[id] = 3; g_bAliveOnly[id] = false; ShowPlayers(id); }
		case 4: { g_iFilter[id] = 1; g_bAliveOnly[id] = true; ShowPlayers(id); }
		case 5: { g_iFilter[id] = 2; g_bAliveOnly[id] = true; ShowPlayers(id); }
		case 6: {
			if (IsVipOnly(id)) {
				new szText[96];
				Lang(id, "PADM_VIP_LIMIT", szText, charsmax(szText), "^4[HNS]^1 VIP不能处死全队。");
				client_print_color(id, print_team_red, "%s", szText);
				ShowFilterMenu(id);
			} else
				SlayTeam(id, 1);
		}
		case 7: {
			if (IsVipOnly(id)) {
				new szText[96];
				Lang(id, "PADM_VIP_LIMIT", szText, charsmax(szText), "^4[HNS]^1 VIP不能处死全队。");
				client_print_color(id, print_team_red, "%s", szText);
				ShowFilterMenu(id);
			} else
				SlayTeam(id, 2);
		}
		case 8: PickSpectated(id);
	}
	return PLUGIN_HANDLED;
}

ShowPlayers(id) {
	new szTitle[64], szExit[32], szBack[32], szNext[32];
	Lang(id, "PADM_PLAYER_TITLE", szTitle, charsmax(szTitle), "选择玩家");
	new menu = menu_create(szTitle, "PlayerHandler");

	new players[MAX_PLAYERS], count, added;
	get_players(players, count, "ch");
	for (new i; i < count; i++) {
		new target = players[i];
		if (g_iFilter[id] && get_user_team(target) != g_iFilter[id])
			continue;
		if (g_bAliveOnly[id] && !is_user_alive(target))
			continue;

		new name[MAX_NAME_LENGTH], info[8], line[64];
		get_user_name(target, name, charsmax(name));
		num_to_str(target, info, charsmax(info));
		if (is_user_alive(target))
			formatex(line, charsmax(line), "\w%s", name);
		else
			formatex(line, charsmax(line), "\d%s", name);
		menu_additem(menu, line, info);
		added++;
	}

	if (!added) {
		new szEmpty[48];
		Lang(id, "PADM_EMPTY", szEmpty, charsmax(szEmpty), "没有符合条件的玩家");
		menu_additem(menu, szEmpty, "0", 0);
	}

	Lang(id, "MENU_BACK", szBack, charsmax(szBack), "返回");
	Lang(id, "MENU_NEXT", szNext, charsmax(szNext), "下一页");
	Lang(id, "MENU_EXIT", szExit, charsmax(szExit), "退出");
	menu_setprop(menu, MPROP_BACKNAME, szBack);
	menu_setprop(menu, MPROP_NEXTNAME, szNext);
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	DisplayPlayerMenu(id, menu);
}

public PlayerHandler(id, menu, item) {
	if (!is_user_connected(id) || item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		if (is_user_connected(id) && item == MENU_EXIT)
			client_cmd(id, "adminmenu");
		return PLUGIN_HANDLED;
	}
	if (item == MENU_BACK) {
		menu_destroy(menu);
		ShowFilterMenu(id);
		return PLUGIN_HANDLED;
	}
	if (!CanUse(id)) {
		menu_destroy(menu);
		Deny(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);

	new target = str_to_num(info);
	if (!target || !is_user_connected(target)) {
		ShowPlayers(id);
		return PLUGIN_HANDLED;
	}

	g_iTarget[id] = target;
	new szPicked[96], name[MAX_NAME_LENGTH];
	get_user_name(target, name, charsmax(name));
	Lang(id, "PADM_PICKED", szPicked, charsmax(szPicked), "^4[HNS]^1 已选择: ^3%s");
	client_print_color(id, print_team_red, szPicked, name);
	ShowPunish(id);
	return PLUGIN_HANDLED;
}

ShowPunish(id) {
	new target = g_iTarget[id];
	if (!is_user_connected(target)) {
		ShowPlayers(id);
		return;
	}

	new name[MAX_NAME_LENGTH], szFmt[96], szTitle[128];
	get_user_name(target, name, charsmax(name));
	Lang(id, "PADM_PUNISH_TITLE", szFmt, charsmax(szFmt), "处罚: %s");
	formatex(szTitle, charsmax(szTitle), szFmt, name);

	new menu = menu_create(szTitle, "PunishHandler");
	new szItem[64];
	Lang(id, "PADM_SLAP", szItem, charsmax(szItem), "拍打");
	menu_additem(menu, szItem, "1");
	Lang(id, "PADM_SLAY", szItem, charsmax(szItem), "处死");
	menu_additem(menu, szItem, "2");
	Lang(id, "PADM_KICK", szItem, charsmax(szItem), "踢出");
	menu_additem(menu, szItem, "3");
	Lang(id, "PADM_BAN", szItem, charsmax(szItem), "封禁");
	menu_additem(menu, szItem, "4");
	Lang(id, "PADM_BANIP", szItem, charsmax(szItem), "封禁IP");
	menu_additem(menu, szItem, "5");
	Lang(id, "PADM_TEAM_TT", szItem, charsmax(szItem), "移到 T");
	menu_additem(menu, szItem, "6");
	Lang(id, "PADM_TEAM_CT", szItem, charsmax(szItem), "移到 CT");
	menu_additem(menu, szItem, "7");
	Lang(id, "PADM_TEAM_SPEC", szItem, charsmax(szItem), "移到观察者");
	menu_additem(menu, szItem, "8");
	Lang(id, "PADM_REVIVE", szItem, charsmax(szItem), "立刻复活");
	menu_additem(menu, szItem, "9");

	new szBack[32], szExit[32];
	Lang(id, "MENU_BACK", szBack, charsmax(szBack), "返回");
	Lang(id, "MENU_EXIT", szExit, charsmax(szExit), "退出");
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	menu_setprop(menu, MPROP_BACKNAME, szBack);
	DisplayPlayerMenu(id, menu);
}

public PunishHandler(id, menu, item) {
	if (!is_user_connected(id) || item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if (item == MENU_BACK) {
		menu_destroy(menu);
		ShowPlayers(id);
		return PLUGIN_HANDLED;
	}
	if (!CanUse(id)) {
		menu_destroy(menu);
		Deny(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);

	new target = g_iTarget[id];
	if (!is_user_connected(target)) {
		ShowPlayers(id);
		return PLUGIN_HANDLED;
	}
	if (IsProtected(id, target))
		return PLUGIN_HANDLED;

	new action = str_to_num(info);
	if (IsVipOnly(id) && (action == 2 || action == 4 || action == 5)) {
		new szText[96];
		Lang(id, "PADM_VIP_LIMIT", szText, charsmax(szText), "^4[HNS]^1 VIP不能处死或封禁玩家。");
		client_print_color(id, print_team_red, "%s", szText);
		ShowPunish(id);
		return PLUGIN_HANDLED;
	}

	switch (action) {
		case 1: {
			user_slap(target, 0);
			ShowPunish(id);
		}
		case 2: {
			user_kill(target);
			ShowPlayers(id);
		}
		case 3: { g_iPunish[id] = PUNISH_KICK; ShowReason(id); }
		case 4: { g_iPunish[id] = PUNISH_BAN; ShowReason(id); }
		case 5: { g_iPunish[id] = PUNISH_BANIP; ShowReason(id); }
		case 9: ReviveNow(id, target);
		case 6: { MoveTeam(id, target, CS_TEAM_T); }
		case 7: { MoveTeam(id, target, CS_TEAM_CT); }
		case 8: { MoveTeam(id, target, CS_TEAM_SPECTATOR); }
	}
	return PLUGIN_HANDLED;
}

ShowReason(id) {
	new szTitle[96], szItem[64];
	Lang(id, "PADM_REASON_TITLE", szTitle, charsmax(szTitle), "选择原因");
	new menu = menu_create(szTitle, "ReasonHandler");

	Lang(id, "PADM_REASON_CUSTOM", szItem, charsmax(szItem), "自定义原因");
	menu_additem(menu, szItem, "0");
	if (g_iPunish[id] != PUNISH_KICK) {
		Lang(id, "PADM_REASON_AIM", szItem, charsmax(szItem), "瞄准辅助 (5分钟)");
		menu_additem(menu, szItem, "5");
		Lang(id, "PADM_REASON_CHAT", szItem, charsmax(szItem), "辱骂 (10分钟)");
		menu_additem(menu, szItem, "10");
		Lang(id, "PADM_REASON_MIC", szItem, charsmax(szItem), "麦克风干扰 (15分钟)");
		menu_additem(menu, szItem, "15");
		Lang(id, "PADM_REASON_BLOCK", szItem, charsmax(szItem), "恶意干扰 (30分钟)");
		menu_additem(menu, szItem, "30");
		Lang(id, "PADM_REASON_REST", szItem, charsmax(szItem), "冷静一下 (60分钟)");
		menu_additem(menu, szItem, "60");
		Lang(id, "PADM_REASON_CHEAT", szItem, charsmax(szItem), "作弊 (永久)");
		menu_additem(menu, szItem, "999");
	}

	new szBack[32], szExit[32];
	Lang(id, "MENU_BACK", szBack, charsmax(szBack), "返回");
	Lang(id, "MENU_EXIT", szExit, charsmax(szExit), "退出");
	menu_setprop(menu, MPROP_BACKNAME, szBack);
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	DisplayPlayerMenu(id, menu);
}

public ReasonHandler(id, menu, item) {
	if (!is_user_connected(id) || item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if (item == MENU_BACK) {
		menu_destroy(menu);
		ShowPunish(id);
		return PLUGIN_HANDLED;
	}
	if (!CanUse(id)) {
		menu_destroy(menu);
		Deny(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);

	if (equal(info, "0")) {
		new szHint[96];
		Lang(id, "PADM_REASON_HINT", szHint, charsmax(szHint), "^4[HNS]^1 请输入原因。封禁请先写分钟数, 例如: 30 辱骂");
		client_print_color(id, print_team_red, "%s", szHint);
		client_cmd(id, "messagemode hns_padm_reason");
		return PLUGIN_HANDLED;
	}

	new minutes = str_to_num(info);
	new szReason[64];
	switch (minutes) {
		case 5: Lang(id, "PADM_REASON_AIM", szReason, charsmax(szReason), "瞄准辅助");
		case 10: Lang(id, "PADM_REASON_CHAT", szReason, charsmax(szReason), "辱骂");
		case 15: Lang(id, "PADM_REASON_MIC", szReason, charsmax(szReason), "麦克风干扰");
		case 30: Lang(id, "PADM_REASON_BLOCK", szReason, charsmax(szReason), "恶意干扰");
		case 60: Lang(id, "PADM_REASON_REST", szReason, charsmax(szReason), "冷静一下");
		default: Lang(id, "PADM_REASON_CHEAT", szReason, charsmax(szReason), "作弊");
	}
	if (minutes >= 999)
		minutes = 0;
	ApplyPunish(id, minutes, szReason);
	return PLUGIN_HANDLED;
}

public CmdCustomReason(id) {
	if (!is_user_connected(id) || !CanUse(id))
		return PLUGIN_HANDLED;

	read_args(g_szReason[id], charsmax(g_szReason[]));
	remove_quotes(g_szReason[id]);
	trim(g_szReason[id]);
	if (!g_szReason[id][0])
		return PLUGIN_HANDLED;

	if (g_iPunish[id] == PUNISH_KICK) {
		ApplyPunish(id, 0, g_szReason[id]);
		return PLUGIN_HANDLED;
	}

	new szTime[8], szReason[160];
	argbreak(g_szReason[id], szTime, charsmax(szTime), szReason, charsmax(szReason));
	if (!szReason[0])
		copy(szReason, charsmax(szReason), szTime);
	ApplyPunish(id, str_to_num(szTime), szReason);
	return PLUGIN_HANDLED;
}

ApplyPunish(id, minutes, const reason[]) {
	new target = g_iTarget[id];
	if (!is_user_connected(target)) {
		ShowPlayers(id);
		return;
	}
	if (IsProtected(id, target))
		return;

	new userid = get_user_userid(target);
	new name[MAX_NAME_LENGTH];
	get_user_name(target, name, charsmax(name));

	switch (g_iPunish[id]) {
		case PUNISH_KICK: {
			server_cmd("kick #%d ^"%s^"", userid, reason);
			server_exec();
		}
		case PUNISH_BAN: {
			server_cmd("amx_ban #%d %d ^"%s^"", userid, minutes, reason);
			server_exec();
		}
		case PUNISH_BANIP: {
			server_cmd("amx_banip #%d %d ^"%s^"", userid, minutes, reason);
			server_exec();
		}
	}

	new szDone[128];
	Lang(id, "PADM_DONE", szDone, charsmax(szDone), "^4[HNS]^1 已处理: ^3%s");
	client_print_color(id, print_team_red, szDone, name);
	g_iPunish[id] = PUNISH_NONE;
	ShowPlayers(id);
}

ReviveNow(id, target) {
	if (!is_user_connected(target)) {
		ShowPlayers(id);
		return;
	}

	new team = get_user_team(target);
	if (team != 1 && team != 2) {
		new szText[96];
		Lang(id, "PADM_REVIVE_SPEC", szText, charsmax(szText), "^4[HNS]^1 观察者不能复活, 先移到 T 或 CT。");
		client_print_color(id, print_team_red, "%s", szText);
		ShowPunish(id);
		return;
	}

	if (is_user_alive(target)) {
		new szText[96];
		Lang(id, "PADM_REVIVE_ALIVE", szText, charsmax(szText), "^4[HNS]^1 这个玩家还活着。");
		client_print_color(id, print_team_red, "%s", szText);
		ShowPunish(id);
		return;
	}

	g_bForceRevive[target] = true;
	rg_round_respawn(target);
	g_bForceRevive[target] = false;

	if (!is_user_alive(target))
		ExecuteHamB(Ham_CS_RoundRespawn, target);

	new szDone[96], name[MAX_NAME_LENGTH];
	get_user_name(target, name, charsmax(name));
	Lang(id, "PADM_REVIVED", szDone, charsmax(szDone), "^4[HNS]^1 已复活: ^3%s");
	client_print_color(id, print_team_red, szDone, name);
	ShowPunish(id);
}

MoveTeam(id, target, CsTeams:team) {
	if (!is_user_connected(target))
		return;
	if (IsProtected(id, target))
		return;
	cs_set_user_team(target, team);
	new szDone[96], name[MAX_NAME_LENGTH];
	get_user_name(target, name, charsmax(name));
	Lang(id, "PADM_MOVED", szDone, charsmax(szDone), "^4[HNS]^1 已移动: ^3%s");
	client_print_color(id, print_team_red, szDone, name);
	ShowPunish(id);
}

SlayTeam(id, team) {
	if (!CanUse(id)) {
		Deny(id);
		return;
	}
	new players[MAX_PLAYERS], count, killed;
	get_players(players, count, "ach");
	for (new i; i < count; i++) {
		new target = players[i];
		if (get_user_team(target) != team)
			continue;
		if (get_user_flags(target) & ADMIN_IMMUNITY)
			continue;
		user_kill(target);
		killed++;
	}
	new szDone[96];
	Lang(id, "PADM_SLAY_DONE", szDone, charsmax(szDone), "^4[HNS]^1 已处死 %d 名玩家。");
	client_print_color(id, print_team_red, szDone, killed);
	ShowFilterMenu(id);
}

PickSpectated(id) {
	if (is_user_alive(id)) {
		new szText[96];
		Lang(id, "PADM_ALIVE", szText, charsmax(szText), "^4[HNS]^1 你还活着, 不能选择正在观察的玩家。");
		client_print_color(id, print_team_red, "%s", szText);
		ShowFilterMenu(id);
		return;
	}

	new target = pev(id, pev_iuser2);
	if (target < 1 || target > MaxClients || !is_user_connected(target)) {
		new szText[96];
		Lang(id, "PADM_NO_TARGET", szText, charsmax(szText), "^4[HNS]^1 没有找到正在观察的玩家。");
		client_print_color(id, print_team_red, "%s", szText);
		ShowFilterMenu(id);
		return;
	}
	if (IsProtected(id, target))
		return;

	g_iTarget[id] = target;
	ShowPunish(id);
}

bool:IsProtected(id, target) {
	if ((get_user_flags(target) & ADMIN_IMMUNITY) && !(get_user_flags(id) & ADMIN_IMMUNITY)) {
		new szText[96];
		Lang(id, "PADM_IMMUNE", szText, charsmax(szText), "^4[HNS]^1 该玩家受管理员免疫保护。");
		client_print_color(id, print_team_red, "%s", szText);
		return true;
	}
	return false;
}

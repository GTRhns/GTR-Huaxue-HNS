#include <amxmodx>
#include <hns_matchsystem>
#include <hns_language>

stock AdminMenuText(id, const key[], output[], length, const fallback[]) {
	HnsLang_Get(id, key, output, length);
	if (!output[0])
		copy(output, length, fallback);
}

stock bool:IsAdminVip(id) {
	return !isUserAdmin(id) && (get_user_flags(id) & hns_get_flag_fullwatcher()) != 0;
}

stock bool:CanOpenAdminMenu(id) {
	return isUserAdmin(id) || IsAdminVip(id);
}

public plugin_init() {
	register_plugin("Match: Admin", "1.0.0", "GTR");

	register_clcmd("adminmenu", "CmdAdminMenu");
	register_clcmd("say /adminmenu", "CmdAdminMenu");
	register_clcmd("say /admin", "CmdAdminMenu");
	register_clcmd("say /管理员", "CmdAdminMenu");

	register_menucmd(register_menuid("GTRAdminMenu"), 1023, "AdminMenuHandler");
	register_menucmd(register_menuid("GTRQuickMenu"), 1023, "QuickMenuHandler");
	register_menucmd(register_menuid("GTRQuickMenu2"), 1023, "QuickMenu2Handler");
	register_menucmd(register_menuid("GTRQuickMenu3"), 1023, "QuickMenu3Handler");
}

public CmdAdminMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id)) {
		client_print_color(id, print_team_red, "^4[HNS]^1 只有管理员/VIP可以打开管理员设置。");
		return PLUGIN_HANDLED;
	}

	ShowAdminMenu(id);
	return PLUGIN_HANDLED;
}

ShowAdminMenu(id) {
	new szMenu[512], szText[128], iLen;
	AdminMenuText(id, "MENU_ADMIN_TITLE", szText, charsmax(szText), "管理员设置");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_ADMIN_MYSQL", szText, charsmax(szText), "MySQL管理与连接");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r1. \d%s^n" : "\r1. \y%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_SERVER_BAN", szText, charsmax(szText), "服务器封禁 (AMXX)");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r2. \d%s^n" : "\r2. \y%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_COMP_BAN_MENU", szText, charsmax(szText), "比赛封禁菜单");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r3. \d%s^n^n" : "\r3. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_ADMIN_ONLINE_BAN", szText, charsmax(szText), "在线比赛封禁");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r4. \d%s^n" : "\r4. \w%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_OFFLINE_BAN", szText, charsmax(szText), "离线比赛封禁");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r5. \d%s^n^n" : "\r5. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_ADMIN_UNBAN", szText, charsmax(szText), "解除比赛封禁");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r6. \d%s^n" : "\r6. \w%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_QUICK", szText, charsmax(szText), "快捷设置");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, IsAdminVip(id) ? "\r7. \d%s^n^n" : "\r7. \y%s^n^n", szText);
	AdminMenuText(id, "MENU_ADMIN_SLAY", szText, charsmax(szText), "处死玩家 (拍打菜单)");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_KICK", szText, charsmax(szText), "踢出玩家");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, szMenu, -1, "GTRAdminMenu");
}

public AdminMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;
	if (IsAdminVip(id) && key < 6) {
		client_print_color(id, print_team_red, "^4[HNS]^1 VIP只能使用处死玩家和踢出玩家。");
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "mysqlmenu");
		case 1: client_cmd(id, "amx_banmenu");
		case 2: client_cmd(id, "hns_bans_menu");
		case 3: client_cmd(id, "hns_banmenu");
		case 4: client_cmd(id, "hns_offbanmenu");
		case 5: client_cmd(id, "hns_unbanmenu");
		case 6: ShowQuickMenu(id);
		case 7: ShowPlayerActionMenu(id, false);
		case 8: ShowPlayerActionMenu(id, true);
	}
	return PLUGIN_HANDLED;
}

ShowPlayerActionMenu(id, bool:bKick) {
	new szTitle[64];
	formatex(szTitle, charsmax(szTitle), bKick ? "踢出玩家" : "拍打玩家");
	new menu = menu_create(szTitle, bKick ? "KickPlayerMenuHandler" : "SlapPlayerMenuHandler");
	new players[MAX_PLAYERS], count;
	get_players(players, count, "ch");

	for (new i; i < count; i++) {
		new target = players[i];
		new name[MAX_NAME_LENGTH], info[8];
		get_user_name(target, name, charsmax(name));
		num_to_str(get_user_userid(target), info, charsmax(info));
		menu_additem(menu, name, info);
	}

	menu_display(id, menu);
}

public SlapPlayerMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);
	new target = find_player("k", str_to_num(info));
	if (target && is_user_connected(target)) {
		if ((get_user_flags(target) & ADMIN_IMMUNITY) && !(get_user_flags(id) & ADMIN_IMMUNITY))
			client_print_color(id, print_team_red, "^4[HNS]^1 该玩家受管理员免疫保护。");
		else
			user_slap(target, 1);
	}
	return PLUGIN_HANDLED;
}

public KickPlayerMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);
	new target = find_player("k", str_to_num(info));
	if (target && is_user_connected(target)) {
		if ((get_user_flags(target) & ADMIN_IMMUNITY) && !(get_user_flags(id) & ADMIN_IMMUNITY))
			client_print_color(id, print_team_red, "^4[HNS]^1 该玩家受管理员免疫保护。");
		else {
			new userid = get_user_userid(target);
			server_cmd("kick #%d ^"管理员操作^"", userid);
			server_exec();
		}
	}
	return PLUGIN_HANDLED;
}

ShowQuickMenu(id) {
	new szMenu[512], szText[128], iLen;
	AdminMenuText(id, "MENU_QUICK_TITLE", szText, charsmax(szText), "快捷设置");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_START", szText, charsmax(szText), "开启比赛 /mix");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \y%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_LIVE", szText, charsmax(szText), "开始比赛 /startmix");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_STOP", szText, charsmax(szText), "停止比赛 /stop");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \r%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_PAUSE", szText, charsmax(szText), "暂停 /pause");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_RESUME", szText, charsmax(szText), "继续 /live");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_RESTART", szText, charsmax(szText), "重启回合 /rr");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_SWAP", szText, charsmax(szText), "互换阵营 /swap");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w%s^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0, szMenu, -1, "GTRQuickMenu");
}

public QuickMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9) {
		if (is_user_connected(id) && CanOpenAdminMenu(id) && key == 9)
			ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;
	if (IsAdminVip(id) && key < 7) {
		client_print_color(id, print_team_red, "^4[HNS]^1 VIP只能查看快捷设置，不能执行快捷操作。");
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "say /mix");
		case 1: client_cmd(id, "say /startmix");
		case 2: client_cmd(id, "say /stop");
		case 3: client_cmd(id, "say /pause");
		case 4: client_cmd(id, "say /live");
		case 5: client_cmd(id, "say /rr");
		case 6: client_cmd(id, "say /swap");
		case 7: ShowQuickMenu2(id);
	}
	return PLUGIN_HANDLED;
}

ShowQuickMenu2(id) {
	new szMenu[512], szText[128], iLen;
	AdminMenuText(id, "MENU_QUICK_TITLE_2", szText, charsmax(szText), "快捷设置 2");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_SPECALL", szText, charsmax(szText), "全部观战 /specall");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_TTALL", szText, charsmax(szText), "全部TT /ttall");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_CTALL", szText, charsmax(szText), "全部CT /ctall");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_BALANCE", szText, charsmax(szText), "打乱队伍 /bld");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_KNIFE", szText, charsmax(szText), "刀局 /kniferound");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_CAPTAIN", szText, charsmax(szText), "队长模式 /captain");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w%s^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0, szMenu, -1, "GTRQuickMenu2");
}

public QuickMenu2Handler(id, key) {
	if (!is_user_connected(id) || key == 9) {
		if (is_user_connected(id) && isUserAdmin(id) && key == 9)
			ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;
	if (IsAdminVip(id) && key < 6) {
		client_print_color(id, print_team_red, "^4[HNS]^1 VIP只能查看快捷设置，不能执行快捷操作。");
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "say /specall");
		case 1: client_cmd(id, "say /ttall");
		case 2: client_cmd(id, "say /ctall");
		case 3: client_cmd(id, "say /bld");
		case 4: client_cmd(id, "say /kniferound");
		case 5: client_cmd(id, "say /captain");
		case 6: ShowQuickMenu3(id);
		case 7: ShowQuickMenu(id);
	}
	return PLUGIN_HANDLED;
}

ShowQuickMenu3(id) {
	new szMenu[512], szText[128], iLen;
	AdminMenuText(id, "MENU_QUICK_TITLE_3", szText, charsmax(szText), "快捷设置 3");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_PUB", szText, charsmax(szText), "娱乐PUB /pub");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_DM", szText, charsmax(szText), "死亡竞赛 /dm");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_ZM", szText, charsmax(szText), "僵尸模式 /zm");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_SKILL", szText, charsmax(szText), "技巧模式 /skill");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_BOOST", szText, charsmax(szText), "Boost模式 /boost");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_MATCH_MENU", szText, charsmax(szText), "比赛管理菜单");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w%s^n^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_0, szMenu, -1, "GTRQuickMenu3");
}

public QuickMenu3Handler(id, key) {
	if (!is_user_connected(id) || key == 9) {
		if (is_user_connected(id) && isUserAdmin(id) && key == 9)
			ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;
	if (IsAdminVip(id) && key < 6) {
		client_print_color(id, print_team_red, "^4[HNS]^1 VIP只能查看快捷设置，不能执行快捷操作。");
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "say /pub");
		case 1: client_cmd(id, "say /dm");
		case 2: client_cmd(id, "say /zm");
		case 3: client_cmd(id, "say /skill");
		case 4: client_cmd(id, "say /boost");
		case 5: client_cmd(id, "say /mix");
		case 6: ShowQuickMenu2(id);
	}
	return PLUGIN_HANDLED;
}
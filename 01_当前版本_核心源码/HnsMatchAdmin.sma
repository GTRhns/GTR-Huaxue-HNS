#include <amxmodx>
#include <hns_matchsystem>
#include <hns_language>

stock AdminMenuText(id, const key[], output[], length, const fallback[]) {
	HnsLang_Get(id, key, output, length);
	if (!output[0])
		copy(output, length, fallback);
}

stock AdminSay(id, const key[], const fallback[]) {
	new szMsg[192];
	HnsLang_Get(id, key, szMsg, charsmax(szMsg));
	if (!szMsg[0])
		copy(szMsg, charsmax(szMsg), fallback);
	client_print_color(id, print_team_red, "%s", szMsg);
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

	register_menucmd(register_menuid("AdmSetPage1"), 1023, "AdminMenuHandler");
	register_menucmd(register_menuid("AdmSetPage2"), 1023, "AdminMenu2Handler");
	register_menucmd(register_menuid("QkSetPage1"), 1023, "QuickMenuHandler");
	register_menucmd(register_menuid("QkSetPage2"), 1023, "QuickMenu2Handler");
	register_menucmd(register_menuid("QkSetPage3"), 1023, "QuickMenu3Handler");
}

public CmdAdminMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id)) {
		AdminSay(id, "ADMIN_MENU_ONLY", "^4[HNS]^1 只有管理员/VIP可以打开管理员设置。");
		return PLUGIN_HANDLED;
	}

	ShowAdminMenu(id);
	return PLUGIN_HANDLED;
}

public OpenAdminMenu(id) {
	if (is_user_connected(id) && CanOpenAdminMenu(id))
		ShowAdminMenu(id);
}

ShowAdminMenu(id) {
	new szMenu[768], szText[128], iLen;
	new bool:bVip = IsAdminVip(id);
	AdminMenuText(id, "MENU_ADMIN_TITLE", szText, charsmax(szText), "管理员设置");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s 1/2^n^n", szText);
	AdminMenuText(id, "MENU_ADMIN_MYSQL", szText, charsmax(szText), "MySQL管理与连接");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \y%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_QUICK", szText, charsmax(szText), "快捷设置");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \y%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_PLAYERS", szText, charsmax(szText), "玩家管理");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_ADMIN_BUILD", szText, charsmax(szText), "客户端版本");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, CanBuildMenu(id) ? "\r4. \y%s^n" : "\r4. \d%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_UNBAN", szText, charsmax(szText), "解除比赛封禁");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_ADMIN_SERVER_BAN", szText, charsmax(szText), "服务器封禁 (AMXX)");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, bVip ? "\r6. \d%s^n" : "\r6. \r%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_COMP_BAN_MENU", szText, charsmax(szText), "比赛封禁菜单");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \r%s^n ^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \d%s^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%s^n", szText);
	AdminMenuText(id, "MENU_EXIT", szText, charsmax(szText), "退出");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_9|MENU_KEY_0, szMenu, -1, "AdmSetPage1");
}

public AdminMenuHandler(id, key) {
	if (!is_user_connected(id) || key == 9)
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;

	if (key == 5 && IsAdminVip(id)) {
		AdminSay(id, "ADMIN_VIP_NO_BAN", "^4[HNS]^1 VIP不能使用服务器封禁。");
		ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "mysqlmenu");
		case 1: ShowQuickMenu(id);
		case 2: OpenPlayerAdmin(id);
		case 3: OpenBuildMenu(id);
		case 4: client_cmd(id, "hns_unbanmenu");
		case 5: client_cmd(id, "amx_banmenu");
		case 6: client_cmd(id, "hns_bans_menu");
		case 8: ShowAdminMenu2(id);
	}
	return PLUGIN_HANDLED;
}

ShowAdminMenu2(id) {
	new szMenu[768], szText[128], iLen;
	AdminMenuText(id, "MENU_ADMIN_TITLE", szText, charsmax(szText), "管理员设置");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s 2/2^n^n", szText);
	AdminMenuText(id, "MENU_ADMIN_ONLINE_BAN", szText, charsmax(szText), "在线比赛封禁");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_OFFLINE_BAN", szText, charsmax(szText), "离线比赛封禁");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \r%s^n", szText);
	AdminMenuText(id, "MENU_ADMIN_KICK", szText, charsmax(szText), "踢出玩家");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \r%s^n ^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \d%s^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_8|MENU_KEY_0, szMenu, -1, "AdmSetPage2");
}

public AdminMenu2Handler(id, key) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;

	if (key == 9 || key == 7) {
		ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "hns_banmenu");
		case 1: client_cmd(id, "hns_offbanmenu");
		case 2: ShowPlayerActionMenu(id, true);
	}
	return PLUGIN_HANDLED;
}

stock bool:CanBuildMenu(id) {
	if (callfunc_begin("hns_build_can", "HnsClientBuild.amxx") != 1)
		return false;
	callfunc_push_int(id);
	return bool:callfunc_end();
}

OpenBuildMenu(id) {
	if (!CanBuildMenu(id)) {
		AdminSay(id, "ADMIN_BUILD_DENIED", "^4[HNS]^1 只有后台白名单里的 SteamID 能打开客户端版本。");
		ShowAdminMenu(id);
		return;
	}

	show_menu(id, 0, "^n", 1);
	if (callfunc_begin("CmdMenu", "HnsClientBuild.amxx") == 1) {
		callfunc_push_int(id);
		callfunc_end();
		return;
	}

	AdminSay(id, "ADMIN_BUILD_MISSING", "^4[HNS]^1 客户端版本插件没有加载。");
	ShowAdminMenu(id);
}

OpenPlayerAdmin(id) {
	if (!is_user_connected(id))
		return;

	show_menu(id, 0, "^n", 1);
	if (callfunc_begin("CmdMenu", "HnsPlayerAdmin.amxx") == 1) {
		callfunc_push_int(id);
		callfunc_end();
		return;
	}

	AdminSay(id, "ADMIN_PLAYER_MISSING", "^4[HNS]^1 玩家管理插件没有加载。");
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
			AdminSay(id, "ADMIN_IMMUNE", "^4[HNS]^1 该玩家受管理员免疫保护。");
		else
			user_slap(target, 1);
	}
	return PLUGIN_HANDLED;
}

public KickPlayerMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		ShowAdminMenu2(id);
		return PLUGIN_HANDLED;
	}

	new info[8], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);
	new target = find_player("k", str_to_num(info));
	if (target && is_user_connected(target)) {
		if ((get_user_flags(target) & ADMIN_IMMUNITY) && !(get_user_flags(id) & ADMIN_IMMUNITY))
			AdminSay(id, "ADMIN_IMMUNE", "^4[HNS]^1 该玩家受管理员免疫保护。");
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
	AdminMenuText(id, "MENU_QUICK_TITLE", szText, charsmax(szText), "快捷设置 1/3 比赛");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_START", szText, charsmax(szText), "开启比赛 /mix");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \y%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_LIVE", szText, charsmax(szText), "开始比赛 /startmix");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_STOP", szText, charsmax(szText), "停止比赛 /stop");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \r%s^n ^n", szText);
	AdminMenuText(id, "MENU_QUICK_PAUSE", szText, charsmax(szText), "暂停 /pause");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_RESUME", szText, charsmax(szText), "继续 /live");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_QUICK_RESTART", szText, charsmax(szText), "重启回合 /rr");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_SWAP", szText, charsmax(szText), "互换阵营 /swap");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \d%s^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%s^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_9|MENU_KEY_0, szMenu, -1, "QkSetPage1");
}

public QuickMenuHandler(id, key) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;

	if (key == 9) {
		ShowAdminMenu(id);
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
		case 8: ShowQuickMenu2(id);
	}
	return PLUGIN_HANDLED;
}

ShowQuickMenu2(id) {
	new szMenu[512], szText[128], iLen;
	AdminMenuText(id, "MENU_QUICK_TITLE_2", szText, charsmax(szText), "快捷设置 2/3 队伍");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_SPECALL", szText, charsmax(szText), "全部观战 /specall");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_TTALL", szText, charsmax(szText), "全部TT /ttall");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_CTALL", szText, charsmax(szText), "全部CT /ctall");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_QUICK_BALANCE", szText, charsmax(szText), "打乱队伍 /bld");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_KNIFE", szText, charsmax(szText), "刀局 /kniferound");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_QUICK_CAPTAIN", szText, charsmax(szText), "队长模式 /captain");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_MAPS", szText, charsmax(szText), "地图选择 /maps");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \y%s^n ^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%s^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, szMenu, -1, "QkSetPage2");
}

public QuickMenu2Handler(id, key) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;

	if (key == 9) {
		ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: client_cmd(id, "say /specall");
		case 1: client_cmd(id, "say /ttall");
		case 2: client_cmd(id, "say /ctall");
		case 3: client_cmd(id, "say /bld");
		case 4: client_cmd(id, "say /kniferound");
		case 5: client_cmd(id, "say /captain");
		case 6: client_cmd(id, "say /maps");
		case 7: ShowQuickMenu(id);
		case 8: ShowQuickMenu3(id);
	}
	return PLUGIN_HANDLED;
}

ShowQuickMenu3(id) {
	new szMenu[512], szText[128], iLen;
	new bool:bVip = IsAdminVip(id);
	AdminMenuText(id, "MENU_QUICK_TITLE_3", szText, charsmax(szText), "快捷设置 3/3 功能");
	iLen = formatex(szMenu, charsmax(szMenu), "\r%s^n^n", szText);
	AdminMenuText(id, "MENU_QUICK_VIP", szText, charsmax(szText), "发放VIP /vipmenu");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, bVip ? "\r1. \d%s^n" : "\r1. \y%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_SIGNUP", szText, charsmax(szText), "AI报名 /signup");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_MFLASH", szText, charsmax(szText), "多重闪光 /mflash");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_QUICK_FLY", szText, charsmax(szText), "飞行手雷 /fly");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_RTS", szText, charsmax(szText), "模式投票 /rts");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_QUICK_RTV", szText, charsmax(szText), "换图投票 /rtv");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%s^n", szText);
	AdminMenuText(id, "MENU_QUICK_HMS", szText, charsmax(szText), "HMS中屏 /hms");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w%s^n ^n", szText);
	AdminMenuText(id, "MENU_PREV_PAGE", szText, charsmax(szText), "上一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%s^n", szText);
	AdminMenuText(id, "MENU_NEXT_PAGE", szText, charsmax(szText), "下一页");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \d%s^n", szText);
	AdminMenuText(id, "MENU_BACK", szText, charsmax(szText), "返回");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szText);
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0, szMenu, -1, "QkSetPage3");
}

public QuickMenu3Handler(id, key) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanOpenAdminMenu(id))
		return PLUGIN_HANDLED;

	if (key == 9) {
		ShowAdminMenu(id);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: {
			if (IsAdminVip(id)) {
				AdminSay(id, "ADMIN_VIP_NO_GRANT", "^4[HNS]^1 VIP不能发放或收回VIP。");
				ShowQuickMenu3(id);
			} else
				client_cmd(id, "vipmenu");
		}
		case 1: client_cmd(id, "say /signup");
		case 2: client_cmd(id, "say /mflash");
		case 3: client_cmd(id, "say /fly");
		case 4: client_cmd(id, "say /rts");
		case 5: client_cmd(id, "say /rtv");
		case 6: client_cmd(id, "say /hms");
		case 7: ShowQuickMenu2(id);
	}
	return PLUGIN_HANDLED;
}
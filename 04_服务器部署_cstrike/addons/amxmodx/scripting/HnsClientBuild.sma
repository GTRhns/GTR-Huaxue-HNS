#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <reapi_rechecker>
#include <hns_language>

#define PLUGIN_VERSION "1.1.0"
#define TASK_BUILD 51000
#define BUILD_WAIT 15.0
#define MAX_ALLOW 8
#define MAX_ADMIN 16
#define LOG_MAX 8

new QueryFileHook:g_Query
new bool:g_bChecker
new bool:g_bEnforce
new g_iAllow[MAX_ALLOW]
new g_iAllowCount
new g_szAdmin[MAX_ADMIN][36]
new g_iAdminCount
new bool:g_bHaveHash[MAX_PLAYERS + 1]
new g_iHash[MAX_PLAYERS + 1]
new bool:g_bDropped[MAX_PLAYERS + 1]
new Float:g_fJoin[MAX_PLAYERS + 1]
new g_iPick[MAX_PLAYERS + 1]
new g_iMode[MAX_PLAYERS + 1]
new g_szKick[LOG_MAX][96]
new g_iKickWrite
new g_iKickCount

public plugin_precache()
{
	LoadConfig()
	LoadAdmins()
	g_bChecker = bool:has_rechecker()
	if (!g_bChecker)
		return

	// 换图会清掉一致性列表, 但旧的查询回调还在. 先卸再注册, 避免每张图叠一层.
	if (_:g_Query)
	{
		UnRegisterQueryFile(g_Query)
		g_Query = QueryFileHook:0
	}

	g_Query = RegisterQueryFile("../hw.dll", "OnHwHash", RES_TYPE_HASH_ANY)
	if (!_:g_Query)
	{
		g_bChecker = false
		log_amx("[HnsClientBuild] RegisterQueryFile ../hw.dll 失败")
	}
}

public plugin_init()
{
	register_plugin("HnsClientBuild", PLUGIN_VERSION, "GTR")
	register_concmd("hns_build_trust", "CmdTrust", ADMIN_RCON, "<name|#userid> - 把这个玩家的 hw.dll 当成唯一允许的 10210")
	register_concmd("hns_build_enforce", "CmdEnforce", ADMIN_RCON, "<0|1> - 1 踢其他哈希, 0 只记录")
	register_concmd("hns_build_status", "CmdStatus", ADMIN_RCON, "[name|#userid]")
	register_clcmd("say /build", "CmdMenu", -1, "版本菜单")
	register_clcmd("say .build", "CmdMenu", -1, "版本菜单")
	register_clcmd("say_team /build", "CmdMenu", -1, "版本菜单")
	register_clcmd("say /版本", "CmdMenu", -1, "版本菜单")
	register_clcmd("say_team /版本", "CmdMenu", -1, "版本菜单")
	register_concmd("hns_build_menu", "CmdMenu", -1, "打开版本菜单")
	register_menucmd(register_menuid("BuildPage1"), 1023, "BuildMainHandler")

	if (g_iAdminCount <= 0)
		log_amx("[HnsClientBuild] 版本白名单是空的, 游戏里没人能放行. 编辑 configs/mixsystem/client_build_admins.cfg")
	else
		log_amx("[HnsClientBuild] 版本白名单 %d 个 SteamID, 聊天 /build 打开菜单", g_iAdminCount)

	if (!bool:has_rechecker())
	{
		log_amx("[HnsClientBuild] ReChecker 没加载, 不会踢人. metamod plugins.ini 加上 rechecker, 放在 amxmodx 上面")
		return
	}
	if (!_:g_Query)
	{
		log_amx("[HnsClientBuild] hw.dll 查询没注册上, 不会踢人")
		return
	}

	if (g_bEnforce && g_iAllowCount > 0)
		log_amx("[HnsClientBuild] 已开启, 只允许 %d 个 hw.dll 哈希", g_iAllowCount)
	else if (g_bEnforce)
		log_amx("[HnsClientBuild] enforce=1 但允许列表是空的, 先不踢人")
	else
		log_amx("[HnsClientBuild] 只记录 hw.dll 哈希. 确认是 10210 的人进服后执行 hns_build_trust")
}

public plugin_end()
{
	if (_:g_Query)
	{
		UnRegisterQueryFile(g_Query)
		g_Query = QueryFileHook:0
	}
}

public client_connect(id)
{
	ResetPlayer(id)
	return PLUGIN_CONTINUE
}

public client_disconnected(id)
{
	remove_task(id + TASK_BUILD)
	ResetPlayer(id)
}

public client_putinserver(id)
{
	if (is_user_bot(id) || is_user_hltv(id))
		return

	g_fJoin[id] = get_gametime()
	if (!ShouldEnforce() || SkipHash(id))
		return

	if (g_bHaveHash[id])
	{
		if (g_iHash[id] == 0 || !HashAllowed(g_iHash[id]))
		{
			g_bDropped[id] = false
			DropWrong(id)
		}
		return
	}

	if (!task_exists(id + TASK_BUILD))
		set_task(BUILD_WAIT, "TaskBuildTimeout", id + TASK_BUILD)
}

public OnHwHash(const id, const hash)
{
	if (id < 1 || id > MaxClients)
		return

	g_bHaveHash[id] = true
	g_iHash[id] = hash

	new hex[12], name[32], auth[36]
	BuildHashHex(hash, hex, charsmax(hex))
	get_user_name(id, name, charsmax(name))
	get_user_authid(id, auth, charsmax(auth))
	log_amx("[HnsClientBuild] %s<%s> hw.dll %s", name, auth, hex)

	if (is_user_bot(id) || is_user_hltv(id) || !ShouldEnforce() || SkipHash(id))
		return

	if (hash == 0 || !HashAllowed(hash))
		DropWrong(id, hex)
}

public TaskBuildTimeout(taskid)
{
	new id = taskid - TASK_BUILD
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return
	if (!ShouldEnforce() || g_bDropped[id] || SkipHash(id))
		return
	if (!g_bHaveHash[id] || g_iHash[id] == 0 || !HashAllowed(g_iHash[id]))
		DropWrong(id)
}

public CmdTrust(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED
	if (!CanManage(id))
	{
		PrintAdmin(id, "[版本] 只有后台白名单里的 SteamID 能放行版本")
		return PLUGIN_HANDLED
	}

	new arg[32]
	read_argv(1, arg, charsmax(arg))
	new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
	if (!player)
		return PLUGIN_HANDLED

	if (!g_bHaveHash[player] || g_iHash[player] == 0)
	{
		PrintAdmin(id, "[HnsClientBuild] 还没有这个玩家的 hw.dll 哈希. 等他进完服, 或他的客户端没有 hw.dll")
		return PLUGIN_HANDLED
	}

	g_iAllowCount = 1
	g_iAllow[0] = g_iHash[player]
	g_bEnforce = true
	SaveConfig()

	new hex[12], msg[160]
	BuildHashHex(g_iAllow[0], hex, charsmax(hex))
	formatex(msg, charsmax(msg), "[HnsClientBuild] 已只允许 hw.dll %s. 其他哈希会被踢", hex)
	PrintAdmin(id, msg)
	log_amx("%s", msg)

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || SkipHash(i))
			continue
		if (g_bHaveHash[i] && g_iHash[i] != g_iAllow[0])
			DropWrong(i)
	}
	return PLUGIN_HANDLED
}

public CmdEnforce(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED
	if (!CanManage(id))
	{
		PrintAdmin(id, "[版本] 只有后台白名单里的 SteamID 能改拦截")
		return PLUGIN_HANDLED
	}

	new arg[8]
	read_argv(1, arg, charsmax(arg))
	new on = str_to_num(arg) != 0
	if (on && g_iAllowCount <= 0)
	{
		PrintAdmin(id, "[HnsClientBuild] 允许列表是空的, 不能开启. 先让 10210 进服再 hns_build_trust")
		return PLUGIN_HANDLED
	}

	g_bEnforce = on != 0
	SaveConfig()
	PrintAdmin(id, g_bEnforce ? "[HnsClientBuild] 已开启, 哈希不对会被踢" : "[HnsClientBuild] 已关闭踢人, 只记录哈希")
	return PLUGIN_HANDLED
}

public CmdStatus(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	new msg[192]
	formatex(msg, charsmax(msg), "[HnsClientBuild] rechecker=%d enforce=%d allow=%d", _:g_bChecker, _:g_bEnforce, g_iAllowCount)
	PrintAdmin(id, msg)

	for (new i = 0; i < g_iAllowCount; i++)
	{
		new hex[12]
		BuildHashHex(g_iAllow[i], hex, charsmax(hex))
		formatex(msg, charsmax(msg), "[HnsClientBuild] allow %s", hex)
		PrintAdmin(id, msg)
	}

	if (read_argc() < 2)
		return PLUGIN_HANDLED

	new arg[32]
	read_argv(1, arg, charsmax(arg))
	new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
	if (!player)
		return PLUGIN_HANDLED

	if (!g_bHaveHash[player])
		PrintAdmin(id, "[HnsClientBuild] 这个玩家还没有 hw.dll 哈希")
	else
	{
		new hex[12]
		BuildHashHex(g_iHash[player], hex, charsmax(hex))
		formatex(msg, charsmax(msg), "[HnsClientBuild] %n hw.dll %s", player, hex)
		PrintAdmin(id, msg)
	}
	return PLUGIN_HANDLED
}

stock bool:ShouldEnforce()
{
	return g_bChecker && g_bEnforce && g_iAllowCount > 0
}

stock bool:SkipHash(id)
{
	return CanManage(id)
}

stock bool:HashAllowed(hash)
{
	for (new i = 0; i < g_iAllowCount; i++)
	{
		if (g_iAllow[i] == hash)
			return true
	}
	return false
}

stock DropWrong(id, const hex[] = "", const why[] = "未放行")
{
	if (id < 1 || id > MaxClients || g_bDropped[id] || !is_user_connected(id))
		return

	g_bDropped[id] = true
	remove_task(id + TASK_BUILD)

	new shown[12]
	if (hex[0])
		copy(shown, charsmax(shown), hex)
	else if (g_bHaveHash[id])
		BuildHashHex(g_iHash[id], shown, charsmax(shown))
	else
		copy(shown, charsmax(shown), "none")

	PushLog(id, shown, why)
	log_amx("[HnsClientBuild] kick %n hw.dll %s %s", id, shown, why)
	rh_drop_client(id, "请使用官方客户端 2024-10-07 (10210)")
}

stock ResetPlayer(id)
{
	g_bHaveHash[id] = false
	g_iHash[id] = 0
	g_bDropped[id] = false
	g_fJoin[id] = 0.0
	g_iPick[id] = 0
	g_iMode[id] = 0
}

stock BuildHashHex(hash, dest[], len)
{
	formatex(dest, len, "%02x%02x%02x%02x", hash & 0xFF, (hash >> 8) & 0xFF, (hash >> 16) & 0xFF, (hash >> 24) & 0xFF)
}

stock bool:ParseMd5Prefix(const text[], &hash)
{
	new i, n, c, v, bytes[4]
	while (text[i] == ' ' || text[i] == 9)
		i++

	for (n = 0; n < 8; n++)
	{
		c = text[i++]
		if (!c)
			return false
		if (c >= '0' && c <= '9')
			v = c - '0'
		else if (c >= 'a' && c <= 'f')
			v = c - 'a' + 10
		else if (c >= 'A' && c <= 'F')
			v = c - 'A' + 10
		else
			return false

		if (n & 1)
			bytes[n / 2] |= v
		else
			bytes[n / 2] = v << 4
	}

	hash = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)
	return true
}

stock CfgPath(dest[], len)
{
	new dir[64]
	get_configsdir(dir, charsmax(dir))
	formatex(dest, len, "%s/mixsystem/client_build.cfg", dir)
}

stock LoadConfig()
{
	g_bEnforce = false
	g_iAllowCount = 0

	new path[128], line[128], fp
	CfgPath(path, charsmax(path))
	fp = fopen(path, "rt")
	if (!fp)
		return

	while (!feof(fp) && fgets(fp, line, charsmax(line)))
	{
		TrimLine(line)
		if (!line[0] || line[0] == ';' || line[0] == '#' || line[0] == '/')
			continue

		if (equali(line, "enforce", 7))
		{
			new value[16]
			CopyFrom(line, SkipSpaces(line, 7), value, charsmax(value))
			g_bEnforce = str_to_num(value) != 0
		}
		else if (equali(line, "allow", 5) && g_iAllowCount < MAX_ALLOW)
		{
			new hex[40], hash
			CopyFrom(line, 5, hex, charsmax(hex))
			if (ParseMd5Prefix(hex, hash) && !HashAllowed(hash))
				g_iAllow[g_iAllowCount++] = hash
		}
	}
	fclose(fp)
}

stock SaveConfig()
{
	new path[128]
	CfgPath(path, charsmax(path))
	new fp = fopen(path, "wt")
	if (!fp)
	{
		log_amx("[HnsClientBuild] 写不了 %s", path)
		return
	}

	fprintf(fp, "; enforce 0 = log only, 1 = kick other hw.dll hashes^n")
	fprintf(fp, "; allow lines are the first 8 hex chars of the hw.dll md5^n")
	fprintf(fp, "enforce %d^n", _:g_bEnforce)
	for (new i = 0; i < g_iAllowCount; i++)
	{
		new hex[12]
		BuildHashHex(g_iAllow[i], hex, charsmax(hex))
		fprintf(fp, "allow %s^n", hex)
	}
	fclose(fp)
}

stock TrimLine(text[])
{
	new len = strlen(text)
	while (len > 0 && (text[len - 1] == 10 || text[len - 1] == 13 || text[len - 1] == ' ' || text[len - 1] == 9))
		text[--len] = 0

	new i
	while (text[i] == ' ' || text[i] == 9)
		i++
	if (!i)
		return

	new j
	while ((text[j] = text[i++]) != 0)
		j++
}

stock SkipSpaces(const text[], start)
{
	while (text[start] == ' ' || text[start] == 9)
		start++
	return start
}

stock CopyFrom(const text[], start, dest[], len)
{
	new i
	while (i < len && text[start])
		dest[i++] = text[start++]
	dest[i] = 0
}

stock PrintAdmin(id, const msg[])
{
	if (!id)
		server_print("%s", msg)
	else
	{
		console_print(id, "%s", msg)
		client_print(id, print_console, "%s", msg)
	}
}

stock BuildText(id, const key[], output[], length, const fallback[])
{
	HnsLang_Get(id, key, output, length)
	if (!output[0])
		copy(output, length, fallback)
}

stock BuildSay(id, const key[], const fallback[], any:...)
{
	new szFmt[192], szMsg[192], i
	if (id)
	{
		BuildText(id, key, szFmt, charsmax(szFmt), fallback)
		vformat(szMsg, charsmax(szMsg), szFmt, 4)
		client_print_color(id, print_team_default, "%s", szMsg)
		return
	}
	for (i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i))
			continue
		BuildText(i, key, szFmt, charsmax(szFmt), fallback)
		vformat(szMsg, charsmax(szMsg), szFmt, 4)
		client_print_color(i, print_team_default, "%s", szMsg)
	}
}

public CmdMenu(id)
{
	if (id && !is_user_connected(id))
		return PLUGIN_HANDLED
	if (!CanManage(id))
	{
		BuildSay(id, "BUILD_DENIED", "^4[HNS]^1 只有后台白名单里的 SteamID 能打开客户端版本。")
		return PLUGIN_HANDLED
	}
	ShowMain(id, 0)
	return PLUGIN_HANDLED
}

public hns_build_can(id)
{
	return CanManage(id) ? 1 : 0
}

public ShowMain(id, page)
{
	if (!is_user_connected(id) || page < 0)
		return

	new humans, ok, bad, wait, szMenu[1024], iLen, szItem[32]
	new szTitle[32], szCheck[32], szBlock[32], szOk[32], szDown[32], szOn[32], szOff[32]
	new szAllow[32], szAdmins[32], szOnline[32], szPass[32], szBad[32], szWait[32]
	CountBuild(humans, ok, bad, wait)
	BuildText(id, "BUILD_TITLE", szTitle, charsmax(szTitle), "客户端版本")
	BuildText(id, "BUILD_CHECK", szCheck, charsmax(szCheck), "检测")
	BuildText(id, "BUILD_BLOCK", szBlock, charsmax(szBlock), "拦截")
	BuildText(id, "BUILD_OK", szOk, charsmax(szOk), "正常")
	BuildText(id, "BUILD_DOWN", szDown, charsmax(szDown), "没挂上")
	BuildText(id, "BUILD_ON", szOn, charsmax(szOn), "开启")
	BuildText(id, "BUILD_OFF", szOff, charsmax(szOff), "关闭")
	BuildText(id, "BUILD_ALLOW", szAllow, charsmax(szAllow), "放行")
	BuildText(id, "BUILD_ADMINS", szAdmins, charsmax(szAdmins), "白名单")
	BuildText(id, "BUILD_ONLINE", szOnline, charsmax(szOnline), "在线")
	BuildText(id, "BUILD_PASS", szPass, charsmax(szPass), "通过")
	BuildText(id, "BUILD_BAD", szBad, charsmax(szBad), "未放行")
	BuildText(id, "BUILD_WAIT", szWait, charsmax(szWait), "等待")
	iLen = formatex(szMenu, charsmax(szMenu), "\y%s \r10210^n\w%s  %s    \w%s  %s^n\w%s \y%d    \w%s \y%d^n\w%s \y%d    \y%s \w%d    \r%s \w%d    \d%s \w%d^n^n",
		szTitle, szCheck, g_bChecker ? szOk : szDown, szBlock, ShouldEnforce() ? szOn : szOff,
		szAllow, g_iAllowCount, szAdmins, g_iAdminCount,
		szOnline, humans, szPass, ok, szBad, bad, szWait, wait)
	BuildText(id, "BUILD_PLAYERS", szItem, charsmax(szItem), "在线检测")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%s^n", szItem)
	BuildText(id, "BUILD_ALLOW_VER", szItem, charsmax(szItem), "放行版本")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%s^n", szItem)
	BuildText(id, "BUILD_HASHES", szItem, charsmax(szItem), "已放行的哈希")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%s  \y[%d]^n ^n", szItem, g_iAllowCount)
	BuildText(id, "BUILD_LOGS", szItem, charsmax(szItem), "最近拦截")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%s  \y[%d]^n", szItem, g_iKickCount)
	BuildText(id, "BUILD_LIST", szItem, charsmax(szItem), "后台白名单")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%s^n ^n", szItem)
	BuildText(id, "BUILD_SWITCH", szItem, charsmax(szItem), "拦截开关")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \r%s  %s^n", szItem, ShouldEnforce() ? szOn : szOff)
	BuildText(id, "BUILD_SWEEP", szItem, charsmax(szItem), "立即清场")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \r%s  \d[%d]^n ^n", szItem, bad + wait)
	BuildText(id, "BUILD_PREV", szItem, charsmax(szItem), "上一页")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \d%s^n", szItem)
	BuildText(id, "BUILD_NEXT", szItem, charsmax(szItem), "下一页")
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \d%s^n", szItem)
	BuildText(id, "BUILD_BACK", szItem, charsmax(szItem), "返回")
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s", szItem)
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_0, szMenu, -1, "BuildPage1")
}

public BuildMainHandler(id, key)
{
	if (!is_user_connected(id) || !CanManage(id))
		return PLUGIN_HANDLED
	switch (key)
	{
		case 0, 1: ShowPlayers(id)
		case 2: ShowAllows(id)
		case 3: ShowLogs(id)
		case 4: ShowAdmins(id)
		case 5: ShowEnforce(id)
		case 6: AskSweep(id)
		case 9: ReturnAdmin(id)
	}
	return PLUGIN_HANDLED
}

public ShowPlayers(id)
{
	new humans, ok, bad, wait, title[160]
	CountBuild(humans, ok, bad, wait)
	formatex(title, charsmax(title), "\y在线检测  \d1通过  2未放行^n\w在线 \y%d    \y通过 \w%d    \r未放行 \w%d    \d等待 \w%d", humans, ok, bad, wait)
	new menu = menu_create(title, "PlayerHandler")
	new count
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i))
			continue
		new st = HashState(i)
		if (st == 0 || st == 1)
		{
			AddPlayerItem(menu, i)
			count++
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i))
			continue
		new st = HashState(i)
		if (st == 2 || st == 3)
		{
			AddPlayerItem(menu, i)
			count++
		}
	}
	if (!count)
		menu_additem(menu, "\d当前没有玩家", "none")
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public PlayerHandler(id, menu, item)
{
	if (item == MENU_EXIT || !CanManage(id))
	{
		menu_destroy(menu)
		if (item == MENU_EXIT && CanManage(id))
			ShowMain(id, 0)
		return PLUGIN_HANDLED
	}

	new data[12], name[8], access, cb
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), cb)
	menu_destroy(menu)
	if (equal(data, "none"))
	{
		ShowMain(id, 0)
		return PLUGIN_HANDLED
	}

	new player = str_to_num(data[3])
	if (!is_user_connected(player))
	{
		ShowPlayers(id)
		return PLUGIN_HANDLED
	}
	g_iPick[id] = player
	ShowAct(id)
	return PLUGIN_HANDLED
}

public ShowAct(id)
{
	new player = g_iPick[id]
	if (!is_user_connected(player) || is_user_bot(player) || is_user_hltv(player))
	{
		ShowPlayers(id)
		return
	}

	new name[32], auth[36], hex[16], title[192]
	get_user_name(player, name, charsmax(name))
	get_user_authid(player, auth, charsmax(auth))
	new st = HashState(player)
	if (g_bHaveHash[player] && g_iHash[player] != 0)
		BuildHashHex(g_iHash[player], hex, charsmax(hex))
	else
		copy(hex, charsmax(hex), "--------")

	formatex(title, charsmax(title), "\y%s^n\d%s^n\whw.dll  \w%s^n\w状态  %s", name, auth, hex, st == 1 ? "\y已放行" : (st == 2 ? "\r未放行" : (st == 3 ? "\r没有hw.dll" : "\d检测中")))
	console_print(id, "[版本] %s <%s> hw.dll %s", name, auth, hex)
	new menu = menu_create(title, "ActHandler")
	if (st == 1 || st == 2)
	{
		menu_additem(menu, "设为唯一允许的版本", "only")
		menu_additem(menu, "追加到允许列表", "add")
	}
	if (st == 1)
		menu_additem(menu, "\d这个版本已经放行", "nope")
	else
		menu_additem(menu, "\r踢出这个玩家", "kick")
	menu_additem(menu, "刷新检测", "redo")
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public ActHandler(id, menu, item)
{
	if (item == MENU_EXIT || !CanManage(id))
	{
		menu_destroy(menu)
		if (item == MENU_EXIT && CanManage(id))
			ShowPlayers(id)
		return PLUGIN_HANDLED
	}

	new data[12], name[8], access, cb
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), cb)
	menu_destroy(menu)

	if (equal(data, "redo") || equal(data, "nope"))
	{
		if (equal(data, "nope"))
			BuildSay(id, "BUILD_ALREADY", "^4[版本]^1 这个版本已经放行")
		ShowAct(id)
		return PLUGIN_HANDLED
	}

	if (equal(data, "only"))
		g_iMode[id] = 1
	else if (equal(data, "add"))
		g_iMode[id] = 2
	else if (equal(data, "kick"))
		g_iMode[id] = 3
	else
	{
		ShowAct(id)
		return PLUGIN_HANDLED
	}
	ShowConfirm(id)
	return PLUGIN_HANDLED
}

public ShowEnforce(id)
{
	new title[128]
	formatex(title, charsmax(title), "\y拦截开关^n\w当前  %s^n\d关闭后只记录哈希, 不踢人", ShouldEnforce() ? "\r开启" : "\d关闭")
	new menu = menu_create(title, "EnforceHandler")
	menu_additem(menu, "\r开启拦截", "on")
	menu_additem(menu, "只记录, 不踢人", "off")
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public EnforceHandler(id, menu, item)
{
	if (item == MENU_EXIT || !CanManage(id))
	{
		menu_destroy(menu)
		if (item == MENU_EXIT && CanManage(id))
			ShowMain(id, 1)
		return PLUGIN_HANDLED
	}

	new data[8], name[8], access, cb
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), cb)
	menu_destroy(menu)

	if (equal(data, "on"))
	{
		if (g_iAllowCount <= 0)
			BuildSay(id, "BUILD_NEED_ALLOW", "^4[版本]^1 还没有放行的版本, 不能开启拦截")
		else
		{
			g_bEnforce = true
			SaveConfig()
			BuildSay(0, "BUILD_ENFORCE_ON", "^4[版本]^1 拦截已开启, 未放行的 hw.dll 会被踢")
			log_amx("[HnsClientBuild] %n 开启拦截", id)
		}
	}
	else if (equal(data, "off"))
	{
		g_bEnforce = false
		SaveConfig()
		BuildSay(0, "BUILD_ENFORCE_OFF", "^4[版本]^1 拦截已关闭, 现在只记录哈希")
		log_amx("[HnsClientBuild] %n 关闭拦截", id)
	}
	ShowMain(id, 1)
	return PLUGIN_HANDLED
}

public ShowAllows(id)
{
	new title[96], item[64], data[8], hex[12]
	formatex(title, charsmax(title), "\y已放行的哈希 \r[%d/%d]^n\d点一条可以取消放行", g_iAllowCount, MAX_ALLOW)
	new menu = menu_create(title, "AllowHandler")
	if (g_iAllowCount <= 0)
		menu_additem(menu, "\d还没有放行任何版本", "none")
	for (new i = 0; i < g_iAllowCount; i++)
	{
		BuildHashHex(g_iAllow[i], hex, charsmax(hex))
		formatex(item, charsmax(item), "\y%s    \w在线 \y%d", hex, CountHash(g_iAllow[i]))
		formatex(data, charsmax(data), "al_%d", i)
		menu_additem(menu, item, data)
	}
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public AllowHandler(id, menu, item)
{
	if (item == MENU_EXIT || !CanManage(id))
	{
		menu_destroy(menu)
		if (item == MENU_EXIT && CanManage(id))
			ShowMain(id, 0)
		return PLUGIN_HANDLED
	}

	new data[8], name[8], access, cb
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), cb)
	menu_destroy(menu)
	if (equal(data, "none"))
	{
		ShowMain(id, 0)
		return PLUGIN_HANDLED
	}
	g_iMode[id] = 5
	g_iPick[id] = str_to_num(data[3])
	ShowConfirm(id)
	return PLUGIN_HANDLED
}

public ShowLogs(id)
{
	new title[768], line[96], n
	copy(title, charsmax(title), "\y最近拦截")
	if (g_iKickCount <= 0)
		format(title, charsmax(title), "%s^n^n\d还没有拦截记录", title)
	else
	{
		for (new i = 0; i < g_iKickCount; i++)
		{
			new pos = (g_iKickWrite - 1 - i + LOG_MAX * 2) % LOG_MAX
			formatex(line, charsmax(line), "^n%s", g_szKick[pos])
			add(title, charsmax(title), line)
			if (++n >= LOG_MAX)
				break
		}
	}
	new menu = menu_create(title, "BackHandler")
	menu_additem(menu, "返回", "back")
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public ShowAdmins(id)
{
	new title[768], line[48]
	formatex(title, charsmax(title), "\y后台白名单 \r[%d]^n\d只认配置文件, 菜单里不能加", g_iAdminCount)
	if (g_iAdminCount <= 0)
		add(title, charsmax(title), "^n^n\dclient_build_admins.cfg 是空的")
	for (new i = 0; i < g_iAdminCount; i++)
	{
		formatex(line, charsmax(line), "^n\w%s", g_szAdmin[i])
		add(title, charsmax(title), line)
	}
	new menu = menu_create(title, "BackHandler")
	menu_additem(menu, "返回", "back")
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public BackHandler(id, menu, item)
{
	menu_destroy(menu)
	if (CanManage(id))
		ShowMain(id, 0)
	return PLUGIN_HANDLED
}

AskSweep(id)
{
	if (g_iAllowCount <= 0)
	{
		BuildSay(id, "BUILD_NEED_SWEEP", "^4[版本]^1 还没有放行的版本, 不能清场")
		ShowMain(id, 1)
		return
	}
	g_iMode[id] = 4
	ShowConfirm(id)
}

public ShowConfirm(id)
{
	new title[192], hex[12], name[32]
	switch (g_iMode[id])
	{
		case 1, 2:
		{
			new player = g_iPick[id]
			if (!is_user_connected(player) || !g_bHaveHash[player] || g_iHash[player] == 0)
			{
				BuildSay(id, "BUILD_NO_HASH", "^4[版本]^1 还没有这个玩家的 hw.dll 哈希")
				ShowAct(id)
				return
			}
			get_user_name(player, name, charsmax(name))
			BuildHashHex(g_iHash[player], hex, charsmax(hex))
			if (g_iMode[id] == 1)
				formatex(title, charsmax(title), "\y确认放行^n\w%s^n\y%s \w设为唯一版本^n\d其他哈希会被踢", name, hex)
			else
				formatex(title, charsmax(title), "\y确认追加^n\w%s^n\y%s \w加进允许列表^n\d最多 %d 条", name, hex, MAX_ALLOW)
		}
		case 3:
		{
			new player = g_iPick[id]
			if (!is_user_connected(player))
			{
				ShowPlayers(id)
				return
			}
			get_user_name(player, name, charsmax(name))
			formatex(title, charsmax(title), "\y确认踢出^n\w%s^n\d提示使用官方客户端 10210", name)
		}
		case 4:
			formatex(title, charsmax(title), "\y确认清场^n\d未放行、没有 hw.dll、还在检测的人都会被踢")
		case 5:
		{
			if (g_iPick[id] < 0 || g_iPick[id] >= g_iAllowCount)
			{
				ShowAllows(id)
				return
			}
			BuildHashHex(g_iAllow[g_iPick[id]], hex, charsmax(hex))
			formatex(title, charsmax(title), "\y取消放行^n\y%s^n\d取消后, 这个哈希再进会被踢", hex)
		}
		default:
		{
			ShowMain(id, 0)
			return
		}
	}

	new menu = menu_create(title, "ConfirmHandler")
	menu_additem(menu, "\y确认", "yes")
	menu_additem(menu, "取消", "no")
	MenuStyle(menu, true)
	menu_display(id, menu, 0)
}

public ConfirmHandler(id, menu, item)
{
	if (!CanManage(id))
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new data[8], name[8], access, cb, yes
	if (item != MENU_EXIT)
	{
		menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), cb)
		yes = equal(data, "yes")
	}
	menu_destroy(menu)
	if (item == MENU_EXIT || !yes)
	{
		BackFromConfirm(id)
		return PLUGIN_HANDLED
	}

	switch (g_iMode[id])
	{
		case 1: DoTrust(id, true)
		case 2: DoTrust(id, false)
		case 3: DoKickOne(id)
		case 4: DoSweep(id)
		case 5: DoRemoveAllow(id)
	}
	g_iMode[id] = 0
	return PLUGIN_HANDLED
}

DoTrust(id, bool:only)
{
	new player = g_iPick[id]
	if (!is_user_connected(player) || !g_bHaveHash[player] || g_iHash[player] == 0)
	{
		BuildSay(id, "BUILD_NO_HASH", "^4[版本]^1 还没有这个玩家的 hw.dll 哈希")
		ShowPlayers(id)
		return
	}

	new hash = g_iHash[player]
	new hex[12]
	BuildHashHex(hash, hex, charsmax(hex))
	if (!only && HashAllowed(hash))
	{
		BuildSay(id, "BUILD_IN_LIST", "^4[版本]^1 ^3%s ^1已经在放行列表里", hex)
		ShowMain(id, 0)
		return
	}
	if (!only && g_iAllowCount >= MAX_ALLOW)
	{
		BuildSay(id, "BUILD_LIST_FULL", "^4[版本]^1 放行列表已满, 最多 %d 条", MAX_ALLOW)
		ShowAllows(id)
		return
	}

	if (only)
	{
		g_iAllowCount = 1
		g_iAllow[0] = hash
		g_bEnforce = true
	}
	else
		g_iAllow[g_iAllowCount++] = hash

	SaveConfig()
	log_amx("[HnsClientBuild] %n 放行 hw.dll %s only=%d", id, hex, _:only)
	BuildSay(0, "BUILD_ALLOWED", "^4[版本]^1 已放行 hw.dll ^3%s", hex)

	if (ShouldEnforce())
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || SkipHash(i))
				continue
			if (g_bHaveHash[i] && g_iHash[i] != 0 && !HashAllowed(g_iHash[i]))
				DropWrong(i, "", "未放行")
		}
	}
	ShowMain(id, 0)
}

DoKickOne(id)
{
	new player = g_iPick[id]
	if (!is_user_connected(player) || is_user_bot(player) || is_user_hltv(player))
	{
		ShowPlayers(id)
		return
	}
	log_amx("[HnsClientBuild] %n 手动踢出 %n", id, player)
	DropWrong(player, "", "手动踢出")
	ShowPlayers(id)
}

DoSweep(id)
{
	if (g_iAllowCount <= 0)
	{
		BuildSay(id, "BUILD_NEED_SWEEP", "^4[版本]^1 还没有放行的版本, 不能清场")
		ShowMain(id, 1)
		return
	}

	new n
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || g_bDropped[i] || SkipHash(i))
			continue
		if (!g_bHaveHash[i] || g_iHash[i] == 0 || !HashAllowed(g_iHash[i]))
		{
			DropWrong(i, "", "清场")
			n++
		}
	}
	log_amx("[HnsClientBuild] %n 清场 %d 人", id, n)
	BuildSay(id, "BUILD_SWEPT", "^4[版本]^1 已踢出 ^3%d ^1人", n)
	ShowMain(id, 1)
}

DoRemoveAllow(id)
{
	new slot = g_iPick[id]
	if (slot < 0 || slot >= g_iAllowCount)
	{
		ShowAllows(id)
		return
	}

	new hex[12]
	BuildHashHex(g_iAllow[slot], hex, charsmax(hex))
	for (new i = slot; i < g_iAllowCount - 1; i++)
		g_iAllow[i] = g_iAllow[i + 1]
	g_iAllowCount--
	if (g_iAllowCount <= 0)
		g_bEnforce = false
	SaveConfig()
	log_amx("[HnsClientBuild] %n 取消放行 %s", id, hex)
	if (g_iAllowCount <= 0)
		BuildSay(0, "BUILD_REVOKED_OFF", "^4[版本]^1 已取消放行 ^3%s^1, 拦截已暂停", hex)
	else
		BuildSay(0, "BUILD_REVOKED", "^4[版本]^1 已取消放行 ^3%s", hex)
	ShowAllows(id)
}

BackFromConfirm(id)
{
	switch (g_iMode[id])
	{
		case 1, 2, 3: ShowAct(id)
		case 4: ShowMain(id, 1)
		case 5: ShowAllows(id)
		default: ShowMain(id, 0)
	}
}

stock MenuStyle(menu, bool:sub, perpage = -1)
{
	menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE)
	if (perpage >= 0)
		menu_setprop(menu, MPROP_PERPAGE, perpage)
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\r")
	menu_setprop(menu, MPROP_BACKNAME, "上一页")
	menu_setprop(menu, MPROP_NEXTNAME, "下一页")
	menu_setprop(menu, MPROP_EXITNAME, sub ? "返回" : "关闭")
}

stock ReturnAdmin(id)
{
	if (callfunc_begin("OpenAdminMenu", "HnsMatchAdmin.amxx") == 1)
	{
		callfunc_push_int(id)
		callfunc_end()
	}
}

stock AddPlayerItem(menu, player)
{
	new item[96], data[8], hex[12], name[32]
	get_user_name(player, name, charsmax(name))
	new st = HashState(player)
	if (st == 1 || st == 2)
	{
		BuildHashHex(g_iHash[player], hex, charsmax(hex))
		formatex(item, charsmax(item), "\w%s   %s%s", name, st == 1 ? "\y" : "\r", hex)
	}
	else if (st == 3)
		formatex(item, charsmax(item), "\w%s   \r没有hw.dll", name)
	else
		formatex(item, charsmax(item), "\w%s   \d检测中", name)
	formatex(data, charsmax(data), "id_%d", player)
	menu_additem(menu, item, data)
}

stock CountBuild(&humans, &ok, &bad, &wait)
{
	humans = 0
	ok = 0
	bad = 0
	wait = 0
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i))
			continue
		humans++
		switch (HashState(i))
		{
			case 1: ok++
			case 2, 3: bad++
			default: wait++
		}
	}
}

stock HashState(id)
{
	if (SkipHash(id))
		return 1
	if (!g_bHaveHash[id])
	{
		if (g_fJoin[id] > 0.0 && get_gametime() - g_fJoin[id] >= BUILD_WAIT)
			return 3
		return 0
	}
	if (g_iHash[id] == 0)
		return 3
	if (HashAllowed(g_iHash[id]))
		return 1
	return 2
}

stock CountHash(hash)
{
	new n
	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_connected(i) && g_bHaveHash[i] && g_iHash[i] == hash)
			n++
	}
	return n
}

stock PushLog(id, const hex[], const why[])
{
	new name[32], line[96]
	get_user_name(id, name, charsmax(name))
	formatex(line, charsmax(line), "\w%s  \d%s  \r%s", name, hex, why)
	copy(g_szKick[g_iKickWrite], charsmax(g_szKick[]), line)
	g_iKickWrite = (g_iKickWrite + 1) % LOG_MAX
	if (g_iKickCount < LOG_MAX)
		g_iKickCount++
}

stock AdminPath(dest[], len)
{
	new dir[64]
	get_configsdir(dir, charsmax(dir))
	formatex(dest, len, "%s/mixsystem/client_build_admins.cfg", dir)
}

stock LoadAdmins()
{
	g_iAdminCount = 0
	new path[128], line[64], fp
	AdminPath(path, charsmax(path))
	fp = fopen(path, "rt")
	if (!fp)
		return

	while (!feof(fp) && fgets(fp, line, charsmax(line)))
	{
		TrimLine(line)
		if (!line[0] || line[0] == ';' || line[0] == '#' || line[0] == '/')
			continue
		if (containi(line, "STEAM_") == -1 && containi(line, "VALVE_") == -1)
			continue
		if (g_iAdminCount >= MAX_ADMIN || AdminListed(line))
			continue
		copy(g_szAdmin[g_iAdminCount], charsmax(g_szAdmin[]), line)
		g_iAdminCount++
	}
	fclose(fp)
}

stock bool:AdminListed(const auth[])
{
	for (new i = 0; i < g_iAdminCount; i++)
	{
		if (SameSteam(auth, g_szAdmin[i]))
			return true
	}
	return false
}

stock bool:CanManage(id)
{
	if (id == 0)
		return true
	if (!is_user_connected(id))
		return false
	new auth[36]
	get_user_authid(id, auth, charsmax(auth))
	return AdminListed(auth)
}

stock bool:SameSteam(const a[], const b[])
{
	if (equali(a, b))
		return true

	new ay, az, by, bz
	if (!SteamParts(a, ay, az) || !SteamParts(b, by, bz))
		return false
	return ay == by && az == bz
}

stock bool:SteamParts(const auth[], &y, &z)
{
	new i
	while (auth[i] && auth[i] != ':')
		i++
	if (auth[i] != ':')
		return false
	i++
	y = str_to_num(auth[i])
	while (auth[i] && auth[i] != ':')
		i++
	if (auth[i] != ':')
		return false
	z = str_to_num(auth[i + 1])
	return z > 0 || auth[i + 1] == '0'
}

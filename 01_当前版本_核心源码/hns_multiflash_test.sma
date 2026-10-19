/* ============================================================
   HNS Multi-Flash TEST
   Independent test menu. Not wired to last-T 1/0.

   say /mflash  open menu
   1 personal on/off (next flash splits after 0.3s into 6, explode together)
   2 give self flashbang
   3 global test on/off (admin)
   ============================================================ */

#include <amxmodx>
#include <reapi>

#define PLUGIN  "HNS MultiFlash Test"
#define VERSION "0.2.0"
#define AUTHOR  "GTR"

#define TASK_SPLIT  73001
#define MAX_EXTRA   8

new g_pCvarEnabled;
new g_pCvarDelay;
new g_pCvarCount;
new bool:g_bPlayerOn[MAX_PLAYERS + 1];
new bool:g_bSpawning;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_pCvarEnabled = create_cvar("hns_mflash_test", "0", FCVAR_NONE, "0=menu only, 1=every flash splits");
	g_pCvarDelay = create_cvar("hns_mflash_delay", "0.3", FCVAR_NONE, "Seconds after throw before split");
	g_pCvarCount = create_cvar("hns_mflash_count", "6", FCVAR_NONE, "Total flashes including original");

	RegisterHookChain(RG_ThrowFlashbang, "OnThrowFlashbang", true);

	register_clcmd("say /mflash", "CmdMenu");
	register_clcmd("say_team /mflash", "CmdMenu");
	register_clcmd("say /multiflash", "CmdMenu");
	register_clcmd("say_team /multiflash", "CmdMenu");
	register_clcmd("say /mflashmenu", "CmdMenu");
	register_clcmd("say_team /mflashmenu", "CmdMenu");
	register_concmd("hns_mflash", "CmdMenu", ADMIN_ALL, "Open multi-flash test menu");
}

public client_disconnected(id)
{
	g_bPlayerOn[id] = false;
}

public CmdMenu(id)
{
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return PLUGIN_HANDLED;

	ShowMFlashMenu(id);
	return PLUGIN_HANDLED;
}

stock ShowMFlashMenu(id)
{
	new sz[128];
	formatex(sz, charsmax(sz), "\y多重闪光测试^n\d出手 %.2fs 后裂成 %d 颗，同时爆", get_pcvar_float(g_pCvarDelay), get_pcvar_num(g_pCvarCount));
	new menu = menu_create(sz, "MFlashMenuHandler");

	formatex(sz, charsmax(sz), "个人测试: %s", g_bPlayerOn[id] ? "\y开" : "\r关");
	menu_additem(menu, sz, "toggle");

	menu_additem(menu, "给自己闪光弹", "give");

	formatex(sz, charsmax(sz), "全服测试: %s%s", get_pcvar_num(g_pCvarEnabled) ? "\y开" : "\r关", (get_user_flags(id) & ADMIN_CFG) ? "" : " \d(管理员)");
	menu_additem(menu, sz, "global");

	menu_setprop(menu, MPROP_EXITNAME, "关闭");
	menu_display(id, menu, 0);
}

public MFlashMenuHandler(id, menu, item)
{
	if (item == MENU_EXIT || !is_user_connected(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new info[16], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);

	if (equal(info, "toggle"))
	{
		g_bPlayerOn[id] = !g_bPlayerOn[id];
		if (g_bPlayerOn[id])
			client_print_color(id, print_team_default, "^4[HNS]^1 个人多重闪光 ^3开^1：下一颗闪光 0.3 秒后裂成 6 颗，同时爆。");
		else
			client_print_color(id, print_team_default, "^4[HNS]^1 个人多重闪光 ^3关^1。");
		ShowMFlashMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(info, "give"))
	{
		GiveTestFlash(id);
		ShowMFlashMenu(id);
		return PLUGIN_HANDLED;
	}

	if (equal(info, "global"))
	{
		if (!(get_user_flags(id) & ADMIN_CFG))
		{
			client_print_color(id, print_team_red, "^4[HNS]^1 全服测试需要管理员。");
			ShowMFlashMenu(id);
			return PLUGIN_HANDLED;
		}

		set_pcvar_num(g_pCvarEnabled, get_pcvar_num(g_pCvarEnabled) ? 0 : 1);
		if (get_pcvar_num(g_pCvarEnabled))
			client_print_color(0, print_team_default, "^4[HNS]^1 全服多重闪光测试 ^3开^1（每次闪光都裂）。");
		else
			client_print_color(0, print_team_default, "^4[HNS]^1 全服多重闪光测试 ^3关^1。");
		ShowMFlashMenu(id);
	}

	return PLUGIN_HANDLED;
}

stock GiveTestFlash(id)
{
	if (!is_user_alive(id))
	{
		client_print_color(id, print_team_red, "^4[HNS]^1 活着才能给闪光弹。");
		return;
	}

	new ammo = rg_get_user_bpammo(id, WEAPON_FLASHBANG);
	if (ammo < 1)
		rg_give_item(id, "weapon_flashbang");
	else
		rg_set_user_bpammo(id, WEAPON_FLASHBANG, ammo + 1);

	if (!g_bPlayerOn[id] && !get_pcvar_num(g_pCvarEnabled))
		client_print_color(id, print_team_default, "^4[HNS]^1 已给闪光。先把 ^3个人测试^1 打开，再扔。");
	else
		client_print_color(id, print_team_default, "^4[HNS]^1 已给闪光，扔出去测试裂开。");
}

public OnThrowFlashbang(id, Float:vecStart[3], Float:vecVelocity[3], Float:time)
{
	if (g_bSpawning)
		return HC_CONTINUE;

	if (!is_user_connected(id))
		return HC_CONTINUE;

	if (!get_pcvar_num(g_pCvarEnabled) && !g_bPlayerOn[id])
		return HC_CONTINUE;

	new ent = GetHookChainReturn(ATYPE_INTEGER);
	if (ent <= 0 || !is_entity(ent))
		return HC_CONTINUE;

	new Float:delay = get_pcvar_float(g_pCvarDelay);
	if (delay < 0.05)
		delay = 0.05;

	new data[3];
	data[0] = ent;
	data[1] = id;
	data[2] = floatround(time * 100.0);
	set_task(delay, "TaskSplitFlash", TASK_SPLIT + ent, data, sizeof data);

	client_print_color(id, print_team_default, "^4[HNS]^1 多重闪光已出手，^3%.2f^1 秒后裂开。", delay);
	return HC_CONTINUE;
}

public TaskSplitFlash(data[])
{
	new ent = data[0];
	new owner = data[1];
	new Float:origFuse = float(data[2]) / 100.0;

	if (ent <= 0 || !is_entity(ent))
		return;

	new classname[16];
	get_entvar(ent, var_classname, classname, charsmax(classname));
	if (!equal(classname, "grenade"))
		return;

	new extra = get_pcvar_num(g_pCvarCount) - 1;
	if (extra < 1)
		return;
	if (extra > MAX_EXTRA)
		extra = MAX_EXTRA;

	new Float:origin[3], Float:velocity[3], Float:dmgtime;
	get_entvar(ent, var_origin, origin);
	get_entvar(ent, var_velocity, velocity);
	get_entvar(ent, var_dmgtime, dmgtime);

	new Float:remain = dmgtime - get_gametime();
	if (remain < 0.08)
		remain = origFuse - get_pcvar_float(g_pCvarDelay);
	if (remain < 0.08)
		remain = 0.08;

	new TeamName:team = TEAM_TERRORIST;
	if (is_user_connected(owner))
		team = get_member(owner, m_iTeam);

	g_bSpawning = true;
	for (new i = 0; i < extra; i++)
	{
		new Float:src[3], Float:vel[3];
		src[0] = origin[0] + random_float(-6.0, 6.0);
		src[1] = origin[1] + random_float(-6.0, 6.0);
		src[2] = origin[2];
		vel[0] = velocity[0] + random_float(-18.0, 18.0);
		vel[1] = velocity[1] + random_float(-18.0, 18.0);
		vel[2] = velocity[2];
		rg_spawn_grenade(WEAPON_FLASHBANG, owner, src, vel, remain, team);
	}
	g_bSpawning = false;

	if (is_user_connected(owner))
		client_print_color(owner, print_team_default, "^4[HNS]^1 已裂成 ^3%d^1 颗，剩余引信 ^3%.2f^1 秒（与原闪光同时爆）。", extra + 1, remain);
}

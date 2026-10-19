/* ============================================================
   HNS Multi-Flash
   出手 0.3 秒后裂成 N 颗，剩余引信对齐原闪光，同时爆。

   自动: 仅 MODE_MIX 开启
   比赛设置: 开 / 关 / 自动
   VIP+: say /mflash 独立菜单加减数量 (2-9, 默认 6)

   包里还有闪光: 当普通闪光，不裂。
   最后一颗 (扔完 bpammo == 0) 才裂开。
   ============================================================ */

#include <amxmodx>
#include <reapi>
#include <hns_language>

native hns_get_mode();
native hns_get_flag_fullwatcher();
native hns_get_flag_admin();

enum _:HNS_MODES
{
	MODE_TRAINING,
	MODE_LOBBY,
	MODE_KNIFE,
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_MIX
}

#define PLUGIN  "HNS MultiFlash"
#define VERSION "1.1.0"
#define AUTHOR  "GTR"

#define TASK_SPLIT  73001
#define MAX_EXTRA   8
#define MIN_COUNT   2
#define MAX_COUNT   9
#define DEF_COUNT   6

new g_pCvarForce;
new g_pCvarDelay;
new g_pCvarCount;
new bool:g_bSpawning;
new g_iForceMode = -1;
new g_iAmmoBefore[MAX_PLAYERS + 1];

public plugin_natives()
{
	set_native_filter("NativeFilter");

	register_library("hns_mflash");
	register_native("hns_mflash_get_force", "native_get_force");
	register_native("hns_mflash_set_force", "native_set_force");
	register_native("hns_mflash_get_count", "native_get_count");
	register_native("hns_mflash_set_count", "native_set_count");
	register_native("hns_mflash_is_active", "native_is_active");
}

public NativeFilter(const szName[], iIndex, iTrap)
{
	if (iTrap)
		return PLUGIN_CONTINUE;

	if (equal(szName, "hns_get_mode")
		|| equal(szName, "hns_get_flag_fullwatcher")
		|| equal(szName, "hns_get_flag_admin")
		|| equal(szName, "HnsLang_Get"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public native_get_force()
{
	return g_iForceMode;
}

public native_set_force()
{
	new iMode = get_param(1);
	if (iMode > 1)
		iMode = 1;
	else if (iMode < -1)
		iMode = -1;

	g_iForceMode = iMode;
	if (g_pCvarForce)
		set_pcvar_num(g_pCvarForce, iMode);
	return 1;
}

public native_get_count()
{
	return clamp_count(get_pcvar_num(g_pCvarCount));
}

public native_set_count()
{
	new iCount = clamp_count(get_param(1));
	set_pcvar_num(g_pCvarCount, iCount);
	return iCount;
}

public native_is_active()
{
	return mflash_active() ? 1 : 0;
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_pCvarForce = create_cvar("hns_mflash_force", "-1", FCVAR_NONE, "-1 auto (mix only), 0 off, 1 on");
	g_pCvarDelay = create_cvar("hns_mflash_delay", "0.3", FCVAR_NONE, "Seconds after throw before split");
	g_pCvarCount = create_cvar("hns_mflash_count", "6", FCVAR_NONE, "Total flashes including original (2-9)");

	g_iForceMode = get_pcvar_num(g_pCvarForce);

	RegisterHookChain(RG_ThrowFlashbang, "OnThrowFlashbangPre", false);
	RegisterHookChain(RG_ThrowFlashbang, "OnThrowFlashbang", true);

	register_clcmd("say /mflash", "CmdCountMenu");
	register_clcmd("say_team /mflash", "CmdCountMenu");
	register_clcmd("say /multiflash", "CmdCountMenu");
	register_clcmd("say_team /multiflash", "CmdCountMenu");
	register_clcmd("say /闪光数量", "CmdCountMenu");
	register_clcmd("say_team /闪光数量", "CmdCountMenu");
	register_concmd("hns_mflash", "CmdCountMenu", ADMIN_ALL, "VIP multi-flash count menu");
}

stock clamp_count(iCount)
{
	if (iCount < MIN_COUNT)
		return MIN_COUNT;
	if (iCount > MAX_COUNT)
		return MAX_COUNT;
	return iCount;
}

stock bool:mflash_active()
{
	g_iForceMode = get_pcvar_num(g_pCvarForce);

	if (g_iForceMode == 1)
		return true;
	if (g_iForceMode == 0)
		return false;

	return hns_get_mode() == MODE_MIX;
}

stock bool:CanEditCount(id)
{
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return false;

	if (get_user_flags(id) & hns_get_flag_admin())
		return true;
	if (get_user_flags(id) & hns_get_flag_fullwatcher())
		return true;

	return false;
}

stock mflash_lang(id, const szKey[], szOut[], iLen, const szFallback[])
{
	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0])
		copy(szOut, iLen, szFallback);

	replace_all(szOut, iLen, "^^n", "^n");
	replace_all(szOut, iLen, "^^1", "^1");
	replace_all(szOut, iLen, "^^3", "^3");
	replace_all(szOut, iLen, "^^4", "^4");
}

stock mflash_print(id, const szKey[], const szFallback[], any:...)
{
	new szFmt[191], szOut[191];
	if (id == 0)
	{
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++)
		{
			mflash_lang(iPlayers[i], szKey, szFmt, charsmax(szFmt), szFallback);
			vformat(szOut, charsmax(szOut), szFmt, 4);
			client_print_color(iPlayers[i], print_team_default, "^4[HNS]^1 %s", szOut);
		}
		return;
	}

	mflash_lang(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, charsmax(szOut), szFmt, 4);
	client_print_color(id, print_team_default, "^4[HNS]^1 %s", szOut);
}

public CmdCountMenu(id)
{
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!CanEditCount(id))
	{
		mflash_print(id, "MFLASH_VIP_ONLY", "只有 VIP 及以上可以调整多重闪光数量。");
		return PLUGIN_HANDLED;
	}

	ShowCountMenu(id);
	return PLUGIN_HANDLED;
}

stock ShowCountMenu(id)
{
	new iCount = clamp_count(get_pcvar_num(g_pCvarCount));
	new szFmt[128], sz[128];

	mflash_lang(id, "MFLASH_MENU_TITLE", szFmt, charsmax(szFmt), "多重闪光数量^n\d出手 %.2fs 后裂成 %d 颗，同时爆");
	formatex(sz, charsmax(sz), szFmt, get_pcvar_float(g_pCvarDelay), iCount);
	new menu = menu_create(sz, "CountMenuHandler");

	mflash_lang(id, "MFLASH_MENU_PLUS", szFmt, charsmax(szFmt), "增加数量 \y[%d/%d]");
	formatex(sz, charsmax(sz), szFmt, iCount, MAX_COUNT);
	menu_additem(menu, sz, "plus");

	mflash_lang(id, "MFLASH_MENU_MINUS", szFmt, charsmax(szFmt), "减少数量 \y[%d/%d]");
	formatex(sz, charsmax(sz), szFmt, iCount, MAX_COUNT);
	menu_additem(menu, sz, "minus");

	mflash_lang(id, "MFLASH_MENU_EXIT", sz, charsmax(sz), "关闭");
	menu_setprop(menu, MPROP_EXITNAME, sz);
	menu_display(id, menu, 0);
}

public CountMenuHandler(id, menu, item)
{
	if (item == MENU_EXIT || !is_user_connected(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (!CanEditCount(id))
	{
		menu_destroy(menu);
		mflash_print(id, "MFLASH_VIP_ONLY", "只有 VIP 及以上可以调整多重闪光数量。");
		return PLUGIN_HANDLED;
	}

	new info[16], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);

	new iCount = clamp_count(get_pcvar_num(g_pCvarCount));
	// 包里还有闪光: 普通出手，不裂。最后一颗才裂。
	if (rg_get_user_bpammo(id, WEAPON_FLASHBANG) > 0)
		return HC_CONTINUE;

	if (equal(info, "plus"))
	{
		if (iCount >= MAX_COUNT)
			mflash_print(id, "MFLASH_COUNT_MAX", "已经是最大数量 ^3%d^1。", MAX_COUNT);
		else
		{
			iCount++;
			set_pcvar_num(g_pCvarCount, iCount);
			mflash_print(0, "MFLASH_COUNT_SET", "多重闪光数量: ^3%d^1", iCount);
		}
	}
	else if (equal(info, "minus"))
	{
		if (iCount <= MIN_COUNT)
			mflash_print(id, "MFLASH_COUNT_MIN", "已经是最小数量 ^3%d^1。", MIN_COUNT);
		else
		{
			iCount--;
			set_pcvar_num(g_pCvarCount, iCount);
			mflash_print(0, "MFLASH_COUNT_SET", "多重闪光数量: ^3%d^1", iCount);
		}
	}

	ShowCountMenu(id);
	return PLUGIN_HANDLED;
}

public OnThrowFlashbangPre(id, Float:vecStart[3], Float:vecVelocity[3], Float:time)
{
	#pragma unused vecStart, vecVelocity, time
	if (id >= 1 && id <= MaxClients)
		g_iAmmoBefore[id] = rg_get_user_bpammo(id, WEAPON_FLASHBANG);
	return HC_CONTINUE;
}

stock bool:is_last_flash(id)
{
	if (id < 1 || id > MaxClients)
		return true;

	new remain = rg_get_user_bpammo(id, WEAPON_FLASHBANG);
	new leftover = (remain < g_iAmmoBefore[id]) ? remain : (remain - 1);
	return leftover <= 0;
}

public OnThrowFlashbang(id, Float:vecStart[3], Float:vecVelocity[3], Float:time)
{
	if (g_bSpawning)
		return HC_CONTINUE;

	if (!is_user_connected(id))
		return HC_CONTINUE;

	if (!mflash_active())
		return HC_CONTINUE;

	// 包里还有闪光: 当普通闪光。最后一颗才裂。
	if (!is_last_flash(id))
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
	return HC_CONTINUE;
}

public TaskSplitFlash(data[])
{
	new ent = data[0];
	new owner = data[1];
	new Float:origFuse = float(data[2]) / 100.0;

	if (ent <= 0 || !is_entity(ent))
		return;

	if (!mflash_active())
		return;

	new classname[16];
	get_entvar(ent, var_classname, classname, charsmax(classname));
	if (!equal(classname, "grenade"))
		return;

	new extra = clamp_count(get_pcvar_num(g_pCvarCount)) - 1;
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
}

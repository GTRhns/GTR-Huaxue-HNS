/* ============================================================
   HnsSatchelTeleport 2.1
   最后一名 CT 扔烟雾弹后, 按攻击键传送到烟雾位置并继承速度.

   开关规则:
   - skill 地图池: 关闭
   - boost 地图池: 开启
   - 其他地图: 关闭
   - 仅公共模式 / 比赛模式按地图开关
   - 管理员可强制开启 (覆盖地图/模式)

   重写原因:
   旧版每帧改 pev_viewmodel / Deploy 刀, 把刀皮手模盖成左手烟雾弹.
   本版禁止改手模、禁止切枪、禁止 Deploy.
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_maps>

#define PLUGIN_NAME    "HNS Satchel Teleport"
#define PLUGIN_VERSION "2.1.0"
#define PLUGIN_AUTHOR  "GTR"

#define EXPLODE_SOUND        "weapons/explode4.wav"
#define SMOKE_GROUND_OFFSET  6
#define VOID_Z               -2000.0
#define HUD_TASK             52001
#define CHECK_TASK           52002

new const Float:g_sign[4][2] = {
	{1.0, 1.0}, {1.0, -1.0}, {-1.0, -1.0}, {-1.0, 1.0}
};

new g_iNadeEnt[MAX_PLAYERS + 1];
new bool:g_bHasSatchel[MAX_PLAYERS + 1];
new bool:g_bNadeThrown[MAX_PLAYERS + 1];
new Float:g_fLastUseTime[MAX_PLAYERS + 1];

new bool:g_bEnabled = true;
new bool:g_bForceEnabled = false;
new bool:g_bIsBoostMap = false;
new bool:g_bIsSkillMap = false;
new g_iNadeDuration = 5;
new g_iCooldown = 30;

public plugin_natives() {
	set_native_filter("NativeFilter");

	register_native("hns_satchel_get_force", "native_get_force");
	register_native("hns_satchel_set_force", "native_set_force");
	register_native("hns_satchel_get_state", "native_get_state");
}

public NativeFilter(const szName[], iIndex, iTrap) {
	if (iTrap)
		return PLUGIN_CONTINUE;

	if (equal(szName, "hns_get_mode")
		|| equal(szName, "hns_get_status")
		|| equal(szName, "hnsmatch_maps_is_boost")
		|| equal(szName, "hnsmatch_maps_is_skill"))
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

// -1 自动, 0 强制关, 1 强制开
public native_get_force() {
	return get_cvar_num("hns_satchel_force");
}

public native_set_force(iMode) {
	if (iMode < -1)
		iMode = -1;
	if (iMode > 1)
		iMode = 1;

	set_cvar_num("hns_satchel_force", iMode);

	if (iMode == 1) {
		g_bForceEnabled = true;
		g_bEnabled = true;
		set_cvar_num("hns_satchel_enabled", 1);
		set_task(0.1, "CheckLastCT", CHECK_TASK);
	} else if (iMode == 0) {
		g_bForceEnabled = false;
		g_bEnabled = false;
		set_cvar_num("hns_satchel_enabled", 0);
		for (new i = 1; i <= MaxClients; i++)
			CleanupPlayer(i, true);
	} else {
		g_bForceEnabled = false;
		g_bEnabled = bool:get_cvar_num("hns_satchel_enabled");
		if (!isAllowed()) {
			for (new i = 1; i <= MaxClients; i++)
				CleanupPlayer(i, true);
		} else {
			set_task(0.1, "CheckLastCT", CHECK_TASK);
		}
	}
	return 1;
}

// 0 关, 1 开, 2 管理员强制开
public native_get_state() {
	if (g_bForceEnabled)
		return 2;
	if (g_bEnabled && isAllowed())
		return 1;
	return 0;
}

public plugin_precache() {
	precache_sound(EXPLODE_SOUND);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	register_library("hns_satchel");

	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "OnPlayerKilled", true);
	RegisterHookChain(RG_ThrowSmokeGrenade, "OnThrowSmoke", true);
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "OnExplodeSmoke", false);

	register_forward(FM_CmdStart, "OnCmdStart");

	register_event("DeathMsg", "Event_DeathMsg", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");

	register_clcmd("say /fly", "CmdSatchelMenu");
	register_clcmd("say_team /fly", "CmdSatchelMenu");
	register_clcmd("say /satchel", "CmdSatchelMenu");
	register_clcmd("say_team /satchel", "CmdSatchelMenu");
	register_clcmd("say /st", "CmdSatchelMenu");
	register_clcmd("say_team /st", "CmdSatchelMenu");
	register_clcmd("say /satcheladmin", "CmdAdminMenu");
	register_clcmd("say_team /satcheladmin", "CmdAdminMenu");
	register_concmd("hns_satchel", "CmdAdminMenu", ADMIN_CFG, "Satchel Teleport Admin");

	register_menucmd(register_menuid("Satchel Menu"), 1023, "HandleSatchelMenu");
	register_menucmd(register_menuid("Satchel Admin"), 1023, "HandleAdminMenu");

	register_cvar("hns_satchel_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	register_cvar("hns_satchel_enabled", "1");
	register_cvar("hns_satchel_force", "-1"); // 比赛设置菜单用: -1自动 0强制关 1强制开
	register_cvar("hns_satchel_duration", "5");
	register_cvar("hns_satchel_cooldown", "30");

	RefreshMapFlags();
}

public plugin_cfg() {
	g_bEnabled = bool:get_cvar_num("hns_satchel_enabled");
	g_iNadeDuration = get_cvar_num("hns_satchel_duration");
	g_iCooldown = get_cvar_num("hns_satchel_cooldown");
	RefreshMapFlags();
}

public client_disconnected(id) {
	CleanupPlayer(id, false);
}

public OnPlayerSpawn(id) {
	if (!is_user_alive(id))
		return HC_CONTINUE;

	CleanupPlayer(id, false);

	if (g_bEnabled && isAllowed())
		set_task(0.3, "CheckLastCT", CHECK_TASK);

	return HC_CONTINUE;
}

public OnPlayerKilled(victim) {
	CleanupPlayer(victim, true);
	return HC_CONTINUE;
}

public Event_DeathMsg() {
	new victim = read_data(2);
	CleanupPlayer(victim, true);
	if (isAllowed())
		set_task(0.2, "CheckLastCT", CHECK_TASK);
}

public Event_NewRound() {
	for (new i = 1; i <= MaxClients; i++) {
		CleanupPlayer(i, true);
		g_fLastUseTime[i] = 0.0;
	}

	g_bEnabled = bool:get_cvar_num("hns_satchel_enabled");
	g_iNadeDuration = get_cvar_num("hns_satchel_duration");
	g_iCooldown = get_cvar_num("hns_satchel_cooldown");
	RefreshMapFlags();

	if (g_bEnabled && isAllowed())
		set_task(1.0, "CheckLastCT", CHECK_TASK);
}

public CheckLastCT() {
	if (!g_bEnabled || !isAllowed())
		return;

	new iCTCount, iLastCT;
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_alive(i) && TeamName:get_member(i, m_iTeam) == TEAM_CT) {
			iCTCount++;
			iLastCT = i;
		}
	}

	if (iCTCount == 1 && iLastCT > 0)
		GiveSatchel(iLastCT);
}

GiveSatchel(id) {
	if (!is_user_alive(id))
		return;
	if (get_gametime() - g_fLastUseTime[id] < float(g_iCooldown))
		return;
	if (g_bHasSatchel[id])
		return;

	g_bHasSatchel[id] = true;
	rg_give_item(id, "weapon_smokegrenade");

	set_dhudmessage(0, 255, 255, -1.0, 0.30, 0, 0.0, 4.0, 0.5, 0.5);
	show_dhudmessage(id, "最后一名CT! 扔出烟雾弹后按攻击键传送!");
}

public OnThrowSmoke(id, Float:vecStart[3], Float:vecVelocity[3], Float:time, const usEvent) {
	if (!g_bEnabled || !isAllowed())
		return HC_CONTINUE;
	if (id < 1 || id > MaxClients || !is_user_alive(id))
		return HC_CONTINUE;
	if (TeamName:get_member(id, m_iTeam) != TEAM_CT)
		return HC_CONTINUE;
	if (!g_bHasSatchel[id] || g_bNadeThrown[id])
		return HC_CONTINUE;

	new ent = GetHookChainReturn(ATYPE_INTEGER);
	if (is_nullent(ent))
		return HC_CONTINUE;
	if (GetGrenadeType(ent) != WEAPON_SMOKEGRENADE)
		return HC_CONTINUE;

	g_iNadeEnt[id] = ent;
	g_bNadeThrown[id] = true;
	set_entvar(ent, var_dmgtime, get_gametime() + 99999.0);

	client_print(id, print_center, "烟雾弹已扔出! 按攻击键传送到烟雾弹位置!");
	remove_task(id + HUD_TASK);
	set_task(0.2, "TaskHud", id + HUD_TASK, .flags = "b");
	return HC_CONTINUE;
}

public OnExplodeSmoke(ent) {
	if (is_nullent(ent))
		return HC_CONTINUE;

	for (new i = 1; i <= MaxClients; i++) {
		if (g_bNadeThrown[i] && g_iNadeEnt[i] == ent)
			return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public TaskHud(taskid) {
	new id = taskid - HUD_TASK;
	if (!is_user_alive(id) || !g_bNadeThrown[id] || !IsOurNade(g_iNadeEnt[id])) {
		remove_task(taskid);
		return;
	}

	set_dhudmessage(0, 255, 255, -1.0, 0.85, 0, 0.0, 0.25, 0.0, 0.0);
	show_dhudmessage(id, "烟雾弹已放置 | 按攻击键传送过去");
}

public OnCmdStart(id, uc_handle) {
	if (!g_bEnabled || !isAllowed() || !is_user_alive(id) || !g_bNadeThrown[id])
		return FMRES_IGNORED;
	if (TeamName:get_member(id, m_iTeam) != TEAM_CT)
		return FMRES_IGNORED;

	new ent = g_iNadeEnt[id];
	if (!IsOurNade(ent)) {
		CleanupPlayer(id, true);
		return FMRES_IGNORED;
	}

	new buttons = get_uc(uc_handle, UC_Buttons);
	if (buttons & (IN_ATTACK | IN_ATTACK2)) {
		buttons &= ~(IN_ATTACK | IN_ATTACK2);
		set_uc(uc_handle, UC_Buttons, buttons);
		TeleportPlayer(id, ent);
	}
	return FMRES_IGNORED;
}

TeleportPlayer(id, ent) {
	new Float:vOrigin[3], Float:vVelocity[3];
	get_entvar(ent, var_origin, vOrigin);
	get_entvar(ent, var_velocity, vVelocity);

	if (vOrigin[2] < VOID_Z || engfunc(EngFunc_PointContents, vOrigin) == CONTENTS_SKY) {
		FailTeleport(id);
		return;
	}

	new Float:mins[3];
	get_entvar(id, var_mins, mins);
	vOrigin[2] -= mins[2] + SMOKE_GROUND_OFFSET;

	new hull = (get_entvar(id, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
	new bool:bOk = false;

	if (is_hull_vacant(vOrigin, hull)) {
		engfunc(EngFunc_SetOrigin, id, vOrigin);
		bOk = true;
	} else {
		new Float:vec[3];
		vec[2] = vOrigin[2];
		for (new i = 0; i < 4; i++) {
			vec[0] = vOrigin[0] - mins[0] * g_sign[i][0];
			vec[1] = vOrigin[1] - mins[1] * g_sign[i][1];
			if (is_hull_vacant(vec, hull)) {
				engfunc(EngFunc_SetOrigin, id, vec);
				bOk = true;
				break;
			}
		}
	}

	if (!bOk) {
		FailTeleport(id);
		return;
	}

	set_entvar(id, var_velocity, vVelocity);
	g_fLastUseTime[id] = get_gametime();

	if (is_user_alive(id))
		rg_remove_item(id, "weapon_smokegrenade", false);

	CleanupPlayer(id, true);

	if (is_user_connected(id))
		engfunc(EngFunc_EmitSound, id, CHAN_STATIC, EXPLODE_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

	set_dhudmessage(0, 255, 100, -1.0, 0.30, 0, 0.0, 3.0, 0.5, 0.5);
	show_dhudmessage(id, "传送成功! 继承速度!");
}

FailTeleport(id) {
	set_dhudmessage(255, 50, 50, -1.0, 0.35, 0, 0.0, 3.0, 0.5, 0.5);
	show_dhudmessage(id, "该实体已被锁定, 无法传送!");
	if (is_user_alive(id))
		rg_remove_item(id, "weapon_smokegrenade", false);
	CleanupPlayer(id, true);
}

CleanupPlayer(id, bool:removeNade) {
	remove_task(id + HUD_TASK);

	if (removeNade && g_iNadeEnt[id] && !is_nullent(g_iNadeEnt[id]) && IsOurNade(g_iNadeEnt[id]))
		set_entvar(g_iNadeEnt[id], var_flags, get_entvar(g_iNadeEnt[id], var_flags) | FL_KILLME);

	g_bHasSatchel[id] = false;
	g_bNadeThrown[id] = false;
	g_iNadeEnt[id] = 0;
}

bool:IsOurNade(ent) {
	if (is_nullent(ent))
		return false;
	new szClass[32];
	get_entvar(ent, var_classname, szClass, charsmax(szClass));
	if (!equal(szClass, "grenade"))
		return false;
	return GetGrenadeType(ent) == WEAPON_SMOKEGRENADE;
}

RefreshMapFlags() {
	g_bIsBoostMap = bool:hnsmatch_maps_is_boost();
	g_bIsSkillMap = bool:hnsmatch_maps_is_skill();
}

bool:isAllowed() {
	RefreshMapFlags();

	// 管理员强制: 任意地图/模式都开
	if (g_bForceEnabled)
		return true;

	// 只在公共/比赛里按地图池开关
	switch (hns_get_mode()) {
		case MODE_PUB, MODE_MIX: {}
		default: return false;
	}

	// skill 图关, boost 图开, 其他图关
	if (g_bIsSkillMap)
		return false;
	return g_bIsBoostMap;
}

bool:is_hull_vacant(const Float:origin[3], hull) {
	new tr = 0;
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, tr);
	return !get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && get_tr2(tr, TR_InOpen);
}

public CmdSatchelMenu(id) {
	if (get_user_flags(id) & ADMIN_CFG)
		return CmdAdminMenu(id);

	new szMenu[512], len;
	len = formatex(szMenu, charsmax(szMenu), "\r[Satchel 遥控传送]^n^n");

	if (g_bForceEnabled)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r状态: \y已启用 (管理员强制)^n");
	else if (g_bEnabled && isAllowed())
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r状态: \y已启用^n");
	else
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r状态: \r已禁用^n");

	if (g_bIsSkillMap)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图: \rskill 图 (关闭)^n");
	else if (g_bIsBoostMap)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图: \yboost 图 (开启)^n");
	else
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图: \w其他图 (关闭)^n");

	new iMode = hns_get_mode();
	if (iMode == MODE_PUB || iMode == MODE_MIX) {
		if (g_bIsBoostMap && !g_bIsSkillMap)
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\r模式: \y%s 按地图开启^n", iMode == MODE_PUB ? "公共模式" : "比赛模式");
		else
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\r模式: \r%s 按地图关闭^n", iMode == MODE_PUB ? "公共模式" : "比赛模式");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r模式: \r当前模式禁止^n");
	}

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r说明:^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\w最后一名 CT 扔出烟雾弹后^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\w按攻击键传送到烟雾弹位置^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\w并继承手雷速度^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 关闭");

	show_menu(id, 1023, szMenu, -1, "Satchel Menu");
	return PLUGIN_HANDLED;
}

public HandleSatchelMenu(id, key) {
	return PLUGIN_HANDLED;
}

public CmdAdminMenu(id) {
	if (!(get_user_flags(id) & ADMIN_CFG)) {
		client_print(id, print_chat, "[Satchel] 仅管理员可用.");
		return PLUGIN_HANDLED;
	}

	new szMenu[512], len;
	len = formatex(szMenu, charsmax(szMenu), "\r[Satchel 管理员]^n^n");

	if (g_bForceEnabled)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w 强制开启: \y[ON]^n");
	else
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w 强制开启: \r[OFF]^n");

	if (g_bIsSkillMap)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图池: \rskill (默认关)^n");
	else if (g_bIsBoostMap)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图池: \yboost (默认开)^n");
	else
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图池: \w其他 (默认关)^n");

	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w 测试传送^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3.\w 烟雾弹时长: \y%d^n", g_iNadeDuration);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4.\w 冷却: \y%d^n^n", g_iCooldown);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 关闭");

	show_menu(id, 1023, szMenu, -1, "Satchel Admin");
	return PLUGIN_HANDLED;
}

public HandleAdminMenu(id, key) {
	if (key == 0) {
		g_bForceEnabled = !g_bForceEnabled;
		client_print(0, print_chat, "[Satchel] 强制开启: %s", g_bForceEnabled ? "ON" : "OFF");
		if (g_bForceEnabled) {
			set_task(0.1, "CheckLastCT", CHECK_TASK);
		} else if (!isAllowed()) {
			for (new i = 1; i <= MaxClients; i++)
				CleanupPlayer(i, true);
		}
		CmdAdminMenu(id);
	} else if (key == 1) {
		if (is_user_alive(id)) {
			g_bHasSatchel[id] = true;
			g_bNadeThrown[id] = false;
			g_iNadeEnt[id] = 0;
			rg_give_item(id, "weapon_smokegrenade");
			client_print(id, print_chat, "[Satchel] 测试: 已给烟雾弹, 扔出后按攻击键传送!");
		} else {
			client_print(id, print_chat, "[Satchel] 你已死亡, 无法测试.");
		}
		CmdAdminMenu(id);
	} else if (key == 2) {
		g_iNadeDuration += 1;
		if (g_iNadeDuration > 15)
			g_iNadeDuration = 5;
		set_cvar_num("hns_satchel_duration", g_iNadeDuration);
		CmdAdminMenu(id);
	} else if (key == 3) {
		g_iCooldown += 5;
		if (g_iCooldown > 120)
			g_iCooldown = 15;
		set_cvar_num("hns_satchel_cooldown", g_iCooldown);
		CmdAdminMenu(id);
	}
	return PLUGIN_HANDLED;
}

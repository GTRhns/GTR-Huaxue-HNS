#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <hns_matchsystem>
#include <hns_language>

new g_szPrefix[24];

stock TrainingText(id, const key[], output[], length, const fallback[]) {
	HnsLang_Get(id, key, output, length);
	if (!output[0] || contain(output, key) != -1)
		copy(output, length, fallback);
}

stock TrainingChat(id, const key[], const fallback[], any:...) {
	new szFmt[128], szMsg[192];
	TrainingText(id, key, szFmt, charsmax(szFmt), fallback);
	vformat(szMsg, charsmax(szMsg), szFmt, 4);
	client_print_color(id, print_team_blue, "%s", szMsg);
}

new bool:g_bDamage[MAX_PLAYERS + 1];
new bool:g_bSaveAngles[MAX_PLAYERS + 1];

new Float:g_fCheckpointAngles[MAX_PLAYERS + 1][3];
new Float:g_fCheckpoints[MAX_PLAYERS + 1][2][3];
new bool:g_fCheckpointAlternate[MAX_PLAYERS + 1];
new g_iSaveCount[MAX_PLAYERS + 1];
new g_iLoadCount[MAX_PLAYERS + 1];
new g_szLastTeam[MAX_PLAYERS + 1][16];

new bool:g_bInvisPlayers[MAX_PLAYERS + 1];

new g_hResetBugForward;

public plugin_init() {
	register_plugin("Match: Training", "1.1", "OpenHNS");

	RegisterSayCmd("training", "tr", "hns_training_menu");

	RegisterSayCmd("checkpoint", "cp", "CmdCheckpoint");
	RegisterSayCmd("teleport", "tp", "CmdGoCheck");
	RegisterSayCmd("gocheck", "gc", "CmdGoCheck");
	RegisterSayCmd("stuck", "st", "CmdStuck");
	RegisterSayCmd("respawn", "rp", "CmdRespawn");
	RegisterSayCmd("noclip", "clip", "CmdClipMode");
	RegisterSayCmd("showdamage", "showdmg", "CmdShowDamage");
	RegisterSayCmd("angles", "ang", "CmdSaveAngles");
	RegisterSayCmd("invis", "inv", "cmdInvis");

	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgFlPlayerFallDamage", true);
	register_event("TeamInfo", "EventTeamInfo", "a");
	register_logevent("EventRoundStart", 2, "1=Round_Start");

	register_forward(FM_AddToFullPack, "fmAddToFullPack", 1);
	
	g_hResetBugForward = CreateMultiForward("fwResetBug", ET_IGNORE, FP_CELL);
}

public client_putinserver(id) {
	g_bDamage[id] = true;
	g_bSaveAngles[id] = true;
	g_bInvisPlayers[id] = false;
	ResetPointCount(id);
	g_szLastTeam[id][0] = 0;
}

public client_disconnected(id) {
	ResetPointCount(id);
	g_szLastTeam[id][0] = 0;
}

public EventTeamInfo() {
	new id = read_data(1);
	if (id < 1 || id > MaxClients)
		return;

	new szTeam[16];
	read_data(2, szTeam, charsmax(szTeam));
	if (g_szLastTeam[id][0] && !equal(g_szLastTeam[id], szTeam))
		ResetPointCount(id);
	copy(g_szLastTeam[id], charsmax(g_szLastTeam[]), szTeam);
}

public EventRoundStart() {
	new id;
	for (id = 1; id <= MaxClients; id++)
		ResetPointCount(id);
}

stock ResetPointCount(id) {
	g_iSaveCount[id] = 0;
	g_iLoadCount[id] = 0;
}

stock TrainingStatusChat(id, const key[], const fallback[]) {
	new szBody[96];
	TrainingText(id, key, szBody, charsmax(szBody), fallback);
	client_print_color(id, print_team_default, "^1%s %s", g_szPrefix, szBody);
}

stock GiveTrainingNade(id, const szWeapon[], WeaponIdType:wid) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED)
		return;
	if (!is_user_alive(id)) {
		TrainingChat(id, "TRNING_NOT_ALIVE", "%s 你必须活着", g_szPrefix);
		return;
	}

	new iAmmo = rg_get_user_bpammo(id, wid);
	if (iAmmo < 0)
		iAmmo = 0;
	if (iAmmo >= 10)
		return;

	new ent = rg_find_weapon_bpack_by_name(id, szWeapon);
	if (ent <= 0)
		ent = rg_give_item(id, szWeapon);
	if (ent > 0)
		rg_set_iteminfo(ent, ItemInfo_iMaxAmmo1, 10);
	rg_set_user_bpammo(id, wid, iAmmo + 1);
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public CmdClipMode(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id))  {
		TrainingChat(id, "TRNING_NOT_ALIVE", "%s 你必须活着", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	new iClip = get_entvar(id, var_movetype) != MOVETYPE_NOCLIP ? MOVETYPE_NOCLIP : MOVETYPE_WALK;

	set_entvar(id, var_movetype, iClip);

	if (iClip == MOVETYPE_NOCLIP) {
		TrainingChat(id, "TRNING_CLIP_ON", "%s 穿墙: 开", g_szPrefix);
	} else {
		TrainingChat(id, "TRNING_CLIP_OFF", "%s 穿墙: 关", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}


public CmdCheckpoint(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id)) {
		TrainingChat(id, "TRNING_NOT_ALIVE", "%s 你必须活着", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	get_entvar(id, var_origin, g_fCheckpoints[id][g_fCheckpointAlternate[id] ? 1 : 0]);
	get_entvar(id, var_v_angle, g_fCheckpointAngles[id]);

	g_fCheckpointAlternate[id] = !g_fCheckpointAlternate[id];
	g_iSaveCount[id]++;
	TrainingStatusChat(id, "TRNING_CPNT_SAVE", "检查点已保存");

	return PLUGIN_HANDLED;
}

public CmdRespawn(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if (rg_get_user_team(id) != TEAM_SPECTATOR) {
		rg_round_respawn(id);
	}

	return PLUGIN_HANDLED;
}

public CmdGoCheck(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id)) {
		TrainingChat(id, "TRNING_NOT_ALIVE", "%s 你必须活着", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	if(!g_fCheckpoints[id][0][0]) {
		TrainingChat(id, "TRNING_TLPRT_NOT", "%s 还没有保存检查点", g_szPrefix);
		return PLUGIN_HANDLED;
	}
	
	set_entvar(id, var_velocity, Float:{0.0, 0.0, 0.0});
	set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
	set_entvar(id, var_origin, g_fCheckpoints[id][!g_fCheckpointAlternate[id]]);

	if(g_bSaveAngles[id]) {
		set_entvar(id, var_angles, g_fCheckpointAngles[id]);
		set_entvar(id, var_v_angle, g_fCheckpointAngles[id]);
		set_entvar(id, var_fixangle, 1);
	}

	new iReturn;
	ExecuteForward(g_hResetBugForward, iReturn, id);
	g_iLoadCount[id]++;
	TrainingStatusChat(id, "TRNING_TLPRT_OK", "已回到检查点");

	return PLUGIN_HANDLED;
}

public CmdStuck(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id)) {
		TrainingChat(id, "TRNING_NOT_ALIVE", "%s 你必须活着", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	if(!g_fCheckpoints[id][0][0] || !g_fCheckpoints[id][1][0]) {
		TrainingChat(id, "TRNING_STUCK_NOT", "%s 需要先保存两个检查点", g_szPrefix);
		return PLUGIN_HANDLED;
	}
		
	set_entvar(id, var_velocity, Float:{0.0, 0.0, 0.0});
	set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
	set_entvar(id, var_origin, g_fCheckpoints[id][g_fCheckpointAlternate[id]]);

	g_fCheckpointAlternate[id] = !g_fCheckpointAlternate[id];
	
	if(g_bSaveAngles[id]) {
		set_entvar(id, var_angles, g_fCheckpointAngles[id]);
		set_entvar(id, var_fixangle, 1);
	}

	return PLUGIN_HANDLED;
}

public CmdShowDamage(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	g_bDamage[id] = !g_bDamage[id];

	if (g_bDamage[id]) {
		TrainingChat(id, "TRNING_SHOW_ON", "%s 伤害显示: 开", g_szPrefix);
	} else {
		TrainingChat(id, "TRNING_SHOW_OFF", "%s 伤害显示: 关", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public CmdSaveAngles(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	g_bSaveAngles[id] = !g_bSaveAngles[id];

	if (g_bSaveAngles[id]) {
		TrainingChat(id, "TRNING_ANGLES_ON", "%s 保存视角: 开", g_szPrefix);
	} else {
		TrainingChat(id, "TRNING_ANGLES_OFF", "%s 保存视角: 关", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public cmdInvis(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	g_bInvisPlayers[id] = !g_bInvisPlayers[id];

	if (g_bInvisPlayers[id]) {
		TrainingChat(id, "TRNING_INVIS_ON", "%s 隐身: 开", g_szPrefix);
	} else {
		TrainingChat(id, "TRNING_INVIS_OFF", "%s 隐身: 关", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public hns_training_menu(id) {
	if ((hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) || !is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[64], szItem[96];

	TrainingText(id, "MENU_TRNING_TITLE", szMsg, charsmax(szMsg), "训练菜单");
	new hMenu = menu_create(szMsg, "hns_training_menu_code");

	TrainingText(id, "MENU_TRNING_CPNT", szMsg, charsmax(szMsg), "保存检查点");
	formatex(szItem, charsmax(szItem), "%s \r[%d]", szMsg, g_iSaveCount[id]);
	menu_additem(hMenu, szItem, "1");

	TrainingText(id, "MENU_TRNING_TLPRT", szMsg, charsmax(szMsg), "传送到检查点");
	formatex(szItem, charsmax(szItem), "%s \r[%d]", szMsg, g_iLoadCount[id]);
	menu_additem(hMenu, szItem, "2");

	TrainingText(id, "MENU_TRNING_NOCLIP", szMsg, charsmax(szMsg), "穿墙");
	menu_additem(hMenu, szMsg, "3");

	TrainingText(id, "MENU_TRNING_RESPAWN", szMsg, charsmax(szMsg), "复活");
	menu_additem(hMenu, szMsg, "4");

	TrainingText(id, "MENU_TRNING_DAMAGE", szMsg, charsmax(szMsg), "伤害显示");
	menu_additem(hMenu, szMsg, "5");

	if (g_bSaveAngles[id]) {
		TrainingText(id, "MENU_TRNING_ANGL_ON", szMsg, charsmax(szMsg), "保存视角 [开]");
	} else {
		TrainingText(id, "MENU_TRNING_ANGL_OFF", szMsg, charsmax(szMsg), "保存视角 [关]");
	}

	menu_additem(hMenu, szMsg, "6");

	if (g_bInvisPlayers[id]) {
		TrainingText(id, "MENU_TRNING_INVIS_ON", szMsg, charsmax(szMsg), "隐身 [开]");
	} else {
		TrainingText(id, "MENU_TRNING_INVIS_OFF", szMsg, charsmax(szMsg), "隐身 [关]");
	}

	menu_additem(hMenu, szMsg, "7");

	TrainingText(id, "MENU_TRNING_FLASH", szMsg, charsmax(szMsg), "获得闪光弹");
	menu_additem(hMenu, szMsg, "8");

	TrainingText(id, "MENU_TRNING_SMOKE", szMsg, charsmax(szMsg), "获得烟雾弹");
	menu_additem(hMenu, szMsg, "9");

	menu_setprop(hMenu, MPROP_PERPAGE, 0);
	menu_setprop(hMenu, MPROP_EXIT, MEXIT_FORCE);
	TrainingText(id, "MENU_TRNING_BACK", szMsg, charsmax(szMsg), "返回");
	menu_setprop(hMenu, MPROP_EXITNAME, szMsg);
	menu_display(id, hMenu, 0);
	
	return PLUGIN_HANDLED;
}

public hns_training_menu_code(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iKey = str_to_num(szData);
	switch (iKey) {
		case 1: {
			CmdCheckpoint(id);
		}
		case 2: {
			CmdGoCheck(id);
		}
		case 3: {
			CmdClipMode(id);
		}
		case 4: {
			CmdRespawn(id);
		}
		case 5: {
			CmdShowDamage(id);
		}
		case 8: {
			GiveTrainingNade(id, "weapon_flashbang", WEAPON_FLASHBANG);
		}
		case 9: {
			GiveTrainingNade(id, "weapon_smokegrenade", WEAPON_SMOKEGRENADE);
		}
		case 6: {
			CmdSaveAngles(id);
		}
		case 7: {
			cmdInvis(id);
		}
	}
	hns_training_menu(id);

	return PLUGIN_HANDLED;
}

public rgFlPlayerFallDamage(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return HC_CONTINUE
	}

	new dmg = floatround(Float:GetHookChainReturn(ATYPE_FLOAT));

	if(g_bDamage[id]) {
		TrainingChat(id, "TRNING_DMG", "%s 掉落伤害: %d", g_szPrefix, dmg);
	}

	return HC_CONTINUE;
}

public fmAddToFullPack(es, e, iEnt, id, hostflags, player, pSet) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return FMRES_IGNORED;
	}
	
	if (id == iEnt)
		return FMRES_IGNORED;

	if (player) {
		if (is_user_alive(iEnt)) {
			if (g_bInvisPlayers[id]) {
				set_es(es, ES_Solid, SOLID_NOT);
				set_es(es, ES_RenderMode, kRenderTransTexture);
				set_es(es, ES_RenderAmt, 0);
				set_es(es, ES_Origin, { 999999999.0, 999999999.0, 999999999.0 });
			}
		}
	}
	
	return FMRES_IGNORED;
}


public plugin_end() {
	DestroyForward(g_hResetBugForward);
}
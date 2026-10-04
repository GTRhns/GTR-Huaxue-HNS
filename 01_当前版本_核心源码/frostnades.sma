/* ============================================================
   HNS Frost Smoke 1.0  (原 Avalanche FrostNades 2.14 改造版)
   烟雾弹冰冻, 只冻 CT, 走 HnsLanguage

   规则 (按服主要求):
   - 只有烟雾弹会变成冰冻弹 (fn_nadetypes 只保留烟雾)
   - 只有 T 扔出的烟雾弹才生效 (CT 的烟雾弹, 包括遥控传送弹, 不受影响)
   - 只有 CT 会被冻住/减速 (T 站在爆炸范围内也不受影响)
   - 公共/死斗/僵尸 默认开启, 其他模式默认关闭
   - 玩家可 /frost 投票关闭或开启 (2/3 人数, 5 秒倒计时, 7 秒计票)
   - 管理员可在 比赛设置 里强制 开/关/自动
   - 死斗换队 / 僵尸感染 / 复活 / 死亡 后立刻解除冰冻
   ============================================================ */

#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <reapi>
#include <hns_matchsystem>
#include <hns_language>

new const VERSION[] = "1.0.0";
new const PLUGIN_NAME[] = "HNS Frost Smoke";

#define message_begin_fl(%1,%2,%3,%4) engfunc(EngFunc_MessageBegin, %1, %2, %3, %4)
#define write_coord_fl(%1) engfunc(EngFunc_WriteCoord, %1)

#define m_pPlayer			41
#define m_pActiveItem		373
#define m_flFlashedUntil	514
#define m_flFlashHoldTime	517
#define Ham_Player_ResetMaxSpeed Ham_Item_PreFrame

#define DMG_GRENADE		(1<<24)
#define FFADE_IN			0x0000
#define BREAK_GLASS		0x01
#define STATUS_HIDE		0
#define STATUS_SHOW		1
#define STATUS_FLASH		2

#define GLOW_AMOUNT		1.0
#define FROST_RADIUS		240.0

#define NT_FLASHBANG		(1<<0)
#define NT_HEGRENADE		(1<<1)
#define NT_SMOKEGRENADE		(1<<2)

/*
 * 只有 T 扔出的烟雾弹才是冰冻弹, 所以把 fn_teams 默认值设成 T。
 * 1 = T, 2 = CT, 3 = 双方
 */
#define FROST_TEAM_T		1
#define FROST_TEAM_CT		2

#define ICON_HASNADE		1
#define ICON_ISCHILLED		2

#define TASK_REMOVE_CHILL	100
#define TASK_REMOVE_FREEZE	200

#define TASK_VOTE_TICK		54001
#define TASK_MENU_COUNTDOWN	54002
#define TASK_HUD		54003

#define FROST_MODE_COUNT	3
#define FROST_VOTE_NONE		-1

#define FROST_NEED_NUM		2
#define FROST_NEED_DEN		3
#define FROST_COUNTDOWN		5
#define FROST_VOTE_SECONDS	7

new const MODEL_FROZEN[]	= "models/frostnova.mdl";
new const MODEL_GLASSGIBS[]	= "models/glassgibs.mdl";

new const SOUND_EXPLODE[]	= "x/x_shoot1.wav";
new const SOUND_FROZEN[]	= "debris/glass1.wav";
new const SOUND_UNFROZEN[]	= "debris/glass3.wav";
new const SOUND_CHILLED[]	= "player/pl_duct2.wav";
new const SOUND_PICKUP[]	= "items/gunpickup2.wav";

new const SPRITE_TRAIL[]	= "sprites/laserbeam.spr";
new const SPRITE_SMOKE[]	= "sprites/steam1.spr";
new const SPRITE_EXPLO[]	= "sprites/shockwave.spr";

new pcv_enabled, pcv_override, pcv_nadetypes, pcv_teams, pcv_price, pcv_limit, pcv_buyzone, pcv_color, pcv_icon,
		pcv_by_radius, pcv_hitself, pcv_los, pcv_maxdamage, pcv_mindamage, pcv_chill_maxchance, pcv_chill_minchance,
		pcv_chill_duration, pcv_chill_variance, pcv_chill_speed, pcv_freeze_maxchance, pcv_freeze_minchance,
		pcv_freeze_duration, pcv_freeze_variance, pcv_force_mode;

new maxPlayers, gmsgScreenFade, gmsgStatusIcon, gmsgBlinkAcct, gmsgAmmoPickup, gmsgTextMsg,
		gmsgWeapPickup, glassGibs, trailSpr, smokeSpr, exploSpr, mp_friendlyfire, czero, bot_quota, czBotHams,
		fmFwdPPT, fnFwdPlayerChilled, fnFwdPlayerFrozen, bool:roundRestarting;

new isChilled[33], isFrozen[33], frostKilled[33], novaDisplay[33], Float:glowColor[33][3], Float:oldGravity[33],
		oldRenderFx[33], Float:oldRenderColor[33][3], oldRenderMode[33], Float:oldRenderAmt[33],
		hasFrostNade[33], nadesBought[33], bool:g_bHadNova[33];

/* 开关状态 */
new g_iForceMode = -1;      // -1 自动, 0 强制关, 1 强制开
new bool:g_bPlayersOff;     // 玩家投票关闭
new bool:g_bNoNovaModel;    // frostnova.mdl 不存在, 跳过 nova 实体

/* 投票状态 */
new g_iVoteChoice[MAX_PLAYERS + 1];
new bool:g_bMenuOpen[MAX_PLAYERS + 1];
new bool:g_bWantVote[MAX_PLAYERS + 1];
new g_iVotes[2];
new g_iWantCount, g_iVoteLeft, g_iMenuCountdown;
new bool:g_bVoting, g_bMenuCountdown;

public plugin_natives()
{
	set_native_filter("NativeFilter");

	register_native("hns_frost_get", "native_frost_get");
	register_native("hns_frost_set", "native_frost_set");
	register_native("hns_frost_get_force", "native_frost_get_force");
	register_native("hns_frost_set_force", "native_frost_set_force");
	register_native("hns_frost_is_active", "native_frost_is_active");
}

public NativeFilter(const szName[], iIndex, iTrap)
{
	if (iTrap)
		return PLUGIN_CONTINUE;

	if (equal(szName, "hns_get_mode")
		|| equal(szName, "hns_get_status")
		|| equal(szName, "HnsLang_Get"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public native_frost_get()
{
	return g_bPlayersOff ? 0 : 1;
}

public native_frost_set(iOn)
{
	g_bPlayersOff = (iOn == 0);
	apply_state_change();
	return 1;
}

public native_frost_get_force()
{
	return g_iForceMode;
}

public native_frost_set_force(iMode)
{
	if (iMode < -1)
		iMode = -1;
	if (iMode > 1)
		iMode = 1;

	g_iForceMode = iMode;
	set_pcvar_num(pcv_force_mode, iMode);
	if (iMode != -1)
		g_bPlayersOff = false;

	apply_state_change();
	return 1;
}

public native_frost_is_active()
{
	return bool:frost_active() ? 1 : 0;
}

/* 模式改变 / 开关改变后清理冻结 */
apply_state_change()
{
	if (frost_active())
		return;

	for (new i = 1; i <= maxPlayers; i++)
	{
		if (isChilled[i])
			task_remove_chill(TASK_REMOVE_CHILL + i);
		if (isFrozen[i])
			task_remove_freeze(TASK_REMOVE_FREEZE + i);
	}
}

/* 当前是否生效: 管理员强制 > 地图/模式默认 > 玩家投票 */
bool:frost_active()
{
	if (g_iForceMode == 1)
		return true;
	if (g_iForceMode == 0)
		return false;

	if (g_bPlayersOff)
		return false;

	switch (hns_get_mode())
	{
		case MODE_PUB, MODE_DM, MODE_ZM: return true;
	}

	return false;
}

bool:frost_mode_allowed()
{
	switch (hns_get_mode())
	{
		case MODE_PUB, MODE_DM, MODE_ZM: return true;
	}
	return false;
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, VERSION, "GTR (Avalanche base)");
	register_library("hns_frost");
	register_cvar("fn_version", VERSION, FCVAR_SERVER);

	pcv_enabled = register_cvar("fn_enabled","1");
	pcv_override = register_cvar("fn_override","1");
	pcv_nadetypes = register_cvar("fn_nadetypes","4");   // 只要烟雾弹
	pcv_teams = register_cvar("fn_teams","1");            // 只要 T 扔出的烟雾弹
	pcv_force_mode = register_cvar("fn_force_mode","-1"); // 比赛设置菜单用: -1自动 0强制关 1强制开
	pcv_price = register_cvar("fn_price","300");
	pcv_icon = register_cvar("fn_icon","1");
	pcv_limit = register_cvar("fn_limit","0");
	pcv_buyzone = register_cvar("fn_buyzone","1");
	pcv_color = register_cvar("fn_color","0 206 209");

	pcv_by_radius = register_cvar("fn_by_radius","0.0");
	pcv_hitself = register_cvar("fn_hitself","0");
	pcv_los = register_cvar("fn_los","1");
	pcv_maxdamage = register_cvar("fn_maxdamage","0.0");
	pcv_mindamage = register_cvar("fn_mindamage","0.0");
	pcv_chill_maxchance = register_cvar("fn_chill_maxchance","100.0");
	pcv_chill_minchance = register_cvar("fn_chill_minchance","100.0");
	pcv_chill_duration = register_cvar("fn_chill_duration","15.0");
	pcv_chill_variance = register_cvar("fn_chill_variance","1.0");
	pcv_chill_speed = register_cvar("fn_chill_speed","60.0");
	pcv_freeze_maxchance = register_cvar("fn_freeze_maxchance","110.0");
	pcv_freeze_minchance = register_cvar("fn_freeze_minchance","40.0");
	pcv_freeze_duration = register_cvar("fn_freeze_duration","10.0");
	pcv_freeze_variance = register_cvar("fn_freeze_variance","0.5");

	mp_friendlyfire = get_cvar_pointer("mp_friendlyfire");

	new mod[6];
	get_modname(mod,5);
	if(equal(mod,"czero"))
	{
		czero = 1;
		bot_quota = get_cvar_pointer("bot_quota");
	}

	maxPlayers = get_maxplayers();
	gmsgScreenFade = get_user_msgid("ScreenFade");
	gmsgStatusIcon = get_user_msgid("StatusIcon");
	gmsgBlinkAcct = get_user_msgid("BlinkAcct");
	gmsgAmmoPickup = get_user_msgid("AmmoPickup");
	gmsgWeapPickup = get_user_msgid("WeapPickup");
	gmsgTextMsg = get_user_msgid("TextMsg");

	register_forward(FM_SetModel,"fw_setmodel",1);
	register_forward(FM_PlayerPreThink,"fw_playerprethink",0);
	register_message(get_user_msgid("DeathMsg"),"msg_deathmsg");

	register_event("ResetHUD", "event_resethud", "b");
	register_event("TextMsg", "event_round_restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0");

	RegisterHam(Ham_Spawn,"player","ham_player_spawn",1);
	RegisterHam(Ham_Killed,"player","ham_player_killed",1);
	RegisterHam(Ham_Player_ResetMaxSpeed,"player","ham_player_resetmaxspeed",1);
	RegisterHam(Ham_Think,"grenade","ham_grenade_think",0);
	RegisterHam(Ham_Use, "player_weaponstrip", "ham_player_weaponstrip_use", 1);

	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawnHC", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "OnPlayerKilledHC", true);

	register_clcmd("say /frost", "CmdFrostVote");
	register_clcmd("say_team /frost", "CmdFrostVote");
	register_clcmd("say /frostnade", "CmdFrostVote");
	register_clcmd("say_team /frostnade", "CmdFrostVote");

	register_menucmd(register_menuid("HNS Frost Vote"), (MENU_KEY_1|MENU_KEY_2|MENU_KEY_0), "HandleVoteMenu");

	fnFwdPlayerChilled = CreateMultiForward("frostnades_player_chilled", ET_STOP, FP_CELL, FP_CELL);
	fnFwdPlayerFrozen  = CreateMultiForward("frostnades_player_frozen",  ET_STOP, FP_CELL, FP_CELL);

	g_iForceMode = -1;
	g_bPlayersOff = false;

	set_task(1.0, "TaskWatchMode", 54010, .flags = "b");
}

public plugin_end()
{
	DestroyForward(fnFwdPlayerChilled);
	DestroyForward(fnFwdPlayerFrozen);
}

public plugin_precache()
{
	if (file_exists(MODEL_FROZEN))
	{
		precache_model(MODEL_FROZEN);
		g_bNoNovaModel = false;
	}
	else
	{
		// 缺模型不能拦着插件加载, 只是不放 nova 实体
		g_bNoNovaModel = true;
	}

	if (file_exists(MODEL_GLASSGIBS))
		glassGibs = precache_model(MODEL_GLASSGIBS);
	else
		glassGibs = 0;

	precache_sound(SOUND_EXPLODE);
	precache_sound(SOUND_FROZEN);
	precache_sound(SOUND_UNFROZEN);
	precache_sound(SOUND_CHILLED);
	precache_sound(SOUND_PICKUP);

	trailSpr = precache_model(SPRITE_TRAIL);
	smokeSpr = precache_model(SPRITE_SMOKE);
	exploSpr = precache_model(SPRITE_EXPLO);
}

/* 每次模式切换后重新清理一次 (死斗/僵尸/公共互切) */
public TaskWatchMode()
{
	apply_state_change();
}

public client_putinserver(id)
{
	isChilled[id] = 0;
	isFrozen[id] = 0;
	frostKilled[id] = 0;
	novaDisplay[id] = 0;
	hasFrostNade[id] = 0;
	g_bHadNova[id] = false;
	g_iVoteChoice[id] = FROST_VOTE_NONE;
	g_bMenuOpen[id] = false;
	g_bWantVote[id] = false;

	if(czero && !czBotHams && is_user_bot(id) && get_pcvar_num(bot_quota) > 0)
		set_task(0.1,"czbot_hook_ham",id);
}

public client_disconnect(id)
{
	if(isChilled[id]) task_remove_chill(TASK_REMOVE_CHILL+id);
	if(isFrozen[id]) task_remove_freeze(TASK_REMOVE_FREEZE+id);

	if (g_bWantVote[id])
	{
		g_bWantVote[id] = false;
		if (g_iWantCount > 0)
			g_iWantCount--;
	}
	if (g_bVoting && g_iVoteChoice[id] != FROST_VOTE_NONE)
		RemoveFrostVote(id);
}

public czbot_hook_ham(id)
{
	if(!czBotHams && is_user_connected(id) && is_user_bot(id) && get_pcvar_num(bot_quota) > 0)
	{
		RegisterHamFromEntity(Ham_Spawn,id,"ham_player_spawn",1);
		RegisterHamFromEntity(Ham_Killed,id,"ham_player_killed",1);
		RegisterHamFromEntity(Ham_Player_ResetMaxSpeed,id,"ham_player_resetmaxspeed",1);
		czBotHams = 1;
	}
}

/****************************************
* 购买 (原有 /fn 逻辑保留, 但默认走烟雾弹)
****************************************/

public buy_frostnade(id)
{
	if(!get_pcvar_num(pcv_enabled) || get_pcvar_num(pcv_override))
		return PLUGIN_CONTINUE;

	if(!is_user_alive(id)) return PLUGIN_HANDLED;

	if(get_pcvar_num(pcv_buyzone) && !cs_get_user_buyzone(id))
	{
		client_print(id,print_center,"You are not in a buy zone.");
		return PLUGIN_HANDLED;
	}

	if(!(get_pcvar_num(pcv_teams) & _:cs_get_user_team(id)))
	{
		message_begin(MSG_ONE,gmsgTextMsg,_,id);
		write_byte(print_center);
		write_string("#Alias_Not_Avail");
		write_string("Frost Grenade");
		message_end();
		return PLUGIN_HANDLED;
	}

	if(hasFrostNade[id])
	{
		client_print(id,print_center,"#Cstrike_Already_Own_Weapon");
		return PLUGIN_HANDLED;
	}

	new limit = get_pcvar_num(pcv_limit);
	if(limit && nadesBought[id] >= limit)
	{
		client_print(id,print_center,"#Cstrike_TitlesTXT_Cannot_Carry_Anymore");
		return PLUGIN_HANDLED;
	}

	new money = cs_get_user_money(id), price = get_pcvar_num(pcv_price);

	if(money < price)
	{
		client_print(id,print_center,"#Cstrike_TitlesTXT_Not_Enough_Money");
		message_begin(MSG_ONE_UNRELIABLE,gmsgBlinkAcct,_,id);
		write_byte(2);
		message_end();
		return PLUGIN_HANDLED;
	}

	// 只给烟雾弹
	new wpnid = CSW_SMOKEGRENADE, ammoid = CSW_SMOKEGRENADE, wpnName[20] = "weapon_smokegrenade";

	hasFrostNade[id] = wpnid;
	nadesBought[id]++;
	cs_set_user_money(id,money - price);

	new ammo = cs_get_user_bpammo(id,wpnid);

	if(!ammo) give_item(id,wpnName);
	else
	{
		cs_set_user_bpammo(id,wpnid,ammo+1);

		message_begin(MSG_ONE,gmsgAmmoPickup,_,id);
		write_byte(ammoid);
		write_byte(ammo+1);
		message_end();

		message_begin(MSG_ONE,gmsgWeapPickup,_,id);
		write_byte(wpnid);
		message_end();

		engfunc(EngFunc_EmitSound,id,CHAN_ITEM,SOUND_PICKUP,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
		grenade_added(id, wpnid);
	}

	return PLUGIN_HANDLED;
}

/****************************************
* 标记冰冻烟雾弹
****************************************/

public fw_setmodel(ent,model[])
{
	if(!get_pcvar_num(pcv_enabled) || !frost_active()) return FMRES_IGNORED;

	new owner = pev(ent,pev_owner);
	if(!is_user_connected(owner)) return FMRES_IGNORED;

	new Float:dmgtime;
	pev(ent,pev_dmgtime,dmgtime);
	if(dmgtime == 0.0) return FMRES_IGNORED;

	new type, csw;
	if(model[7] == 'w' && model[8] == '_')
	{
		switch(model[9])
		{
			case 'h': { type = NT_HEGRENADE; csw = CSW_HEGRENADE; }
			case 'f': { type = NT_FLASHBANG; csw = CSW_FLASHBANG; }
			case 's': { type = NT_SMOKEGRENADE; csw = CSW_SMOKEGRENADE; }
		}
	}
	if(!type) return FMRES_IGNORED;

	// 只有烟雾弹能冰冻
	if (!(type & NT_SMOKEGRENADE))
		return FMRES_IGNORED;

	new team = _:cs_get_user_team(owner);

	// 只让 T 的烟雾弹变成冰冻弹 -> CT 的遥控传送弹不受影响
	if (!(get_pcvar_num(pcv_teams) & team))
		return FMRES_IGNORED;

	if (!(get_pcvar_num(pcv_override) && (get_pcvar_num(pcv_nadetypes) & type)))
		return FMRES_IGNORED;

	set_pev(ent,pev_team,team);
	set_pev(ent,pev_bInDuck,1); // 标记为冰冻弹

	new rgb[3], Float:rgbF[3];
	get_rgb_colors(team,rgb);
	IVecFVec(rgb, rgbF);

	set_pev(ent,pev_rendermode,kRenderNormal);
	set_pev(ent,pev_renderfx,kRenderFxGlowShell);
	set_pev(ent,pev_rendercolor,rgbF);
	set_pev(ent,pev_renderamt,16.0);

	set_beamfollow(ent,10,10,rgb,100);

	return FMRES_IGNORED;
}

/****************************************
* 冰冻 / 减速
****************************************/

public fw_playerprethink(id)
{
	// 冻结期间换队 / 复活 / 死亡后如果已经不是 CT, 立刻解冻
	if (isFrozen[id] || isChilled[id])
	{
		if (!is_user_alive(id) || _:cs_get_user_team(id) != _:CS_TEAM_CT)
		{
			if (isFrozen[id]) task_remove_freeze(TASK_REMOVE_FREEZE+id);
			if (isChilled[id]) task_remove_chill(TASK_REMOVE_CHILL+id);
			return FMRES_IGNORED;
		}
	}

	if(isFrozen[id])
	{
		set_pev(id,pev_velocity,Float:{0.0,0.0,0.0});

		new Float:gravity;
		pev(id,pev_gravity,gravity);

		if(gravity != 0.000000001 && gravity != 999999999.9)
			oldGravity[id] = gravity;

		if((pev(id,pev_button) & IN_JUMP) && !(pev(id,pev_oldbuttons) & IN_JUMP) && (pev(id,pev_flags) & FL_ONGROUND))
			set_pev(id,pev_gravity,999999999.9);
		else
			set_pev(id,pev_gravity,0.000000001);
	}

	return FMRES_IGNORED;
}

public msg_deathmsg(msg_id,msg_dest,msg_entity)
{
	new victim = get_msg_arg_int(2);
	if(!is_user_connected(victim) || !frostKilled[victim]) return PLUGIN_CONTINUE;

	static weapon[8];
	get_msg_arg_string(4,weapon,7);
	if(equal(weapon,"grenade")) set_msg_arg_string(4,"frostgrenade");

	return PLUGIN_CONTINUE;
}

public event_resethud(id)
{
	if(!is_user_alive(id) || !get_pcvar_num(pcv_enabled)) return;

	if(get_pcvar_num(pcv_icon) == ICON_HASNADE)
	{
		new status = player_has_frostnade(id);
		show_icon(id, status);
	}
}

public event_round_restart()
{
	roundRestarting = true;
}

public event_new_round()
{
	if(roundRestarting)
	{
		roundRestarting = false;
		for(new i=1;i<=maxPlayers;i++)
			hasFrostNade[i] = 0;
	}
}

public OnPlayerSpawnHC(id)
{
	nadesBought[id] = 0;

	if(is_user_alive(id))
	{
		if(isChilled[id]) task_remove_chill(TASK_REMOVE_CHILL+id);
		if(isFrozen[id]) task_remove_freeze(TASK_REMOVE_FREEZE+id);
	}

	return HC_CONTINUE;
}

public OnPlayerKilledHC(id)
{
	hasFrostNade[id] = 0;

	if(get_pcvar_num(pcv_enabled) && get_pcvar_num(pcv_icon) == ICON_HASNADE)
		show_icon(id, STATUS_HIDE);

	if(isChilled[id]) task_remove_chill(TASK_REMOVE_CHILL+id);
	if(isFrozen[id]) task_remove_freeze(TASK_REMOVE_FREEZE+id);

	return HC_CONTINUE;
}

public ham_player_spawn(id)
{
	nadesBought[id] = 0;

	if(is_user_alive(id))
	{
		if(isChilled[id]) task_remove_chill(TASK_REMOVE_CHILL+id);
		if(isFrozen[id]) task_remove_freeze(TASK_REMOVE_FREEZE+id);
	}

	return HAM_IGNORED;
}

public ham_player_killed(id)
{
	hasFrostNade[id] = 0;

	if(get_pcvar_num(pcv_enabled) && get_pcvar_num(pcv_icon) == ICON_HASNADE)
		show_icon(id, STATUS_HIDE);

	if(isChilled[id]) task_remove_chill(TASK_REMOVE_CHILL+id);
	if(isFrozen[id]) task_remove_freeze(TASK_REMOVE_FREEZE+id);

	return HAM_IGNORED;
}

public ham_player_resetmaxspeed(id)
{
	if(get_pcvar_num(pcv_enabled) && frost_active())
		set_user_chillfreeze_speed(id);

	return HAM_IGNORED;
}

public ham_grenade_think(ent)
{
	if(!pev_valid(ent) || !pev(ent,pev_bInDuck)) return HAM_IGNORED;

	new Float:dmgtime;
	pev(ent,pev_dmgtime,dmgtime);
	if(dmgtime > get_gametime()) return HAM_IGNORED;

	frostnade_explode(ent);

	return HAM_SUPERCEDE;
}

public ham_player_weaponstrip_use(ent, idcaller, idactivator, use_type, Float:value)
{
	if(idcaller >= 1 && idcaller <= maxPlayers)
	{
		hasFrostNade[idcaller] = 0;

		if(is_user_alive(idcaller) && get_pcvar_num(pcv_enabled) && get_pcvar_num(pcv_icon) == ICON_HASNADE)
		{
			new status = player_has_frostnade(idcaller);
			show_icon(idcaller, status);
		}
	}

	return HAM_IGNORED;
}

/****************************************
* 爆炸: 只处理 CT
****************************************/

public frostnade_explode(ent)
{
	new owner = pev(ent,pev_owner), Float:nadeOrigin[3];
	pev(ent,pev_origin,nadeOrigin);

	new ownerTeam = is_user_connected(owner) ? (_:cs_get_user_team(owner)) : 0;
	message_begin_fl(MSG_PVS,SVC_TEMPENTITY,nadeOrigin,0);
	write_byte(TE_SMOKE);
	write_coord_fl(nadeOrigin[0]);
	write_coord_fl(nadeOrigin[1]);
	write_coord_fl(nadeOrigin[2]);
	write_short(smokeSpr);
	write_byte(random_num(30,40));
	write_byte(5);
	message_end();

	create_blast(ownerTeam, nadeOrigin);
	emit_sound(ent,CHAN_ITEM,SOUND_EXPLODE,VOL_NORM,ATTN_NORM,0,PITCH_HIGH);

	new Float:by_radius = get_pcvar_float(pcv_by_radius),
			hitself = get_pcvar_num(pcv_hitself), los = get_pcvar_num(pcv_los),
			Float:maxdamage = get_pcvar_float(pcv_maxdamage),
			Float:mindamage = get_pcvar_float(pcv_mindamage),
			Float:chill_maxchance = get_pcvar_float(pcv_chill_maxchance),
			Float:chill_minchance = get_pcvar_float(pcv_chill_minchance),
			Float:freeze_maxchance, Float:freeze_minchance;

	if(!by_radius)
	{
		freeze_maxchance = get_pcvar_float(pcv_freeze_maxchance);
		freeze_minchance = get_pcvar_float(pcv_freeze_minchance);
	}

	new Float:targetOrigin[3], Float:distance, tr = create_tr2(), Float:fraction, Float:damage, gotFrozen = 0;
	for(new target=1;target<=maxPlayers;target++)
	{
		if(!is_user_alive(target) || pev(target,pev_takedamage) == DAMAGE_NO
		|| (pev(target,pev_flags) & FL_GODMODE) || (target == owner && !hitself))
			continue;

		// 只冻 CT
		if(_:cs_get_user_team(target) != _:CS_TEAM_CT)
			continue;

		pev(target,pev_origin,targetOrigin);
		distance = vector_distance(nadeOrigin,targetOrigin);

		if(distance > FROST_RADIUS) continue;

		if(los)
		{
			nadeOrigin[2] += 2.0;
			engfunc(EngFunc_TraceLine,nadeOrigin,targetOrigin,DONT_IGNORE_MONSTERS,ent,tr);
			nadeOrigin[2] -= 2.0;

			get_tr2(tr,TR_flFraction,fraction);
			if(fraction != 1.0 && get_tr2(tr,TR_pHit) != target) continue;
		}

		if(maxdamage > 0.0)
		{
			damage = radius_calc(distance,FROST_RADIUS,maxdamage,mindamage);
			if(damage > 0.0)
			{
				frostKilled[target] = 1;
				ExecuteHamB(Ham_TakeDamage,target,ent,owner,damage,DMG_GRENADE);
				if(!is_user_alive(target)) continue;
				frostKilled[target] = 0;
			}
		}

		// 冻结
		if((by_radius && radius_calc(distance,FROST_RADIUS,100.0,0.0) >= by_radius)
		|| (!by_radius && random_num(1,100) <= floatround(radius_calc(distance,FROST_RADIUS,freeze_maxchance,freeze_minchance))))
		{
			if(freeze_player(target,owner,ownerTeam))
			{
				gotFrozen = 1;
				emit_sound(target,CHAN_ITEM,SOUND_FROZEN,1.0,ATTN_NONE,0,PITCH_LOW);
			}
		}

		// 减速
		if(by_radius || random_num(1,100) <= floatround(radius_calc(distance,FROST_RADIUS,chill_maxchance,chill_minchance)))
		{
			if(chill_player(target,owner,ownerTeam))
			{
				if(!gotFrozen) emit_sound(target,CHAN_ITEM,SOUND_CHILLED,VOL_NORM,ATTN_NORM,0,PITCH_HIGH);
			}
		}
	}

	free_tr2(tr);
	set_pev(ent,pev_flags,pev(ent,pev_flags)|FL_KILLME);
}

freeze_player(id,attacker,nadeTeam)
{
	new fwdRetVal = PLUGIN_CONTINUE;
	ExecuteForward(fnFwdPlayerFrozen, fwdRetVal, id, attacker);

	if(fwdRetVal == PLUGIN_HANDLED || fwdRetVal == PLUGIN_HANDLED_MAIN)
		return 0;

	if(_:cs_get_user_team(id) != _:CS_TEAM_CT)
		return 0;

	if(!isFrozen[id])
	{
		pev(id,pev_gravity,oldGravity[id]);

		if(!fmFwdPPT)
			fmFwdPPT = register_forward(FM_PlayerPreThink,"fw_playerprethink",0);
	}

	isFrozen[id] = nadeTeam;

	set_pev(id,pev_velocity,Float:{0.0,0.0,0.0});
	set_user_chillfreeze_speed(id);

	new Float:duration = get_pcvar_float(pcv_freeze_duration), Float:variance = get_pcvar_float(pcv_freeze_variance);
	duration += random_float(-variance,variance);

	remove_task(TASK_REMOVE_FREEZE+id);
	set_task(duration,"task_remove_freeze",TASK_REMOVE_FREEZE+id);

	if(!g_bNoNovaModel)
	{
		if(!pev_valid(novaDisplay[id])) create_nova(id);
		g_bHadNova[id] = true;
	}

	if(get_pcvar_num(pcv_icon) == ICON_ISCHILLED)
		show_icon(id, STATUS_FLASH);

	return 1;
}

public task_remove_freeze(taskid)
{
	new id = taskid-TASK_REMOVE_FREEZE;

	if(pev_valid(novaDisplay[id]))
	{
		new Float:origin[3];
		pev(novaDisplay[id],pev_origin,origin);

		message_begin_fl(MSG_PVS,SVC_TEMPENTITY,origin,0);
		write_byte(TE_IMPLOSION);
		write_coord_fl(origin[0]);
		write_coord_fl(origin[1]);
		write_coord_fl(origin[2] + 8.0);
		write_byte(64);
		write_byte(10);
		write_byte(3);
		message_end();

		message_begin_fl(MSG_PVS,SVC_TEMPENTITY,origin,0);
		write_byte(TE_SPARKS);
		write_coord_fl(origin[0]);
		write_coord_fl(origin[1]);
		write_coord_fl(origin[2]);
		message_end();

		if(glassGibs)
		{
			message_begin_fl(MSG_PAS,SVC_TEMPENTITY,origin,0);
			write_byte(TE_BREAKMODEL);
			write_coord_fl(origin[0]);
			write_coord_fl(origin[1]);
			write_coord_fl(origin[2] + 24.0);
			write_coord_fl(16.0);
			write_coord_fl(16.0);
			write_coord_fl(16.0);
			write_coord(random_num(-50,50));
			write_coord(random_num(-50,50));
			write_coord_fl(25.0);
			write_byte(10);
			write_short(glassGibs);
			write_byte(10);
			write_byte(25);
			write_byte(BREAK_GLASS);
			message_end();
		}

		emit_sound(novaDisplay[id],CHAN_ITEM,SOUND_UNFROZEN,VOL_NORM,ATTN_NORM,0,PITCH_LOW);
		set_pev(novaDisplay[id],pev_flags,pev(novaDisplay[id],pev_flags)|FL_KILLME);
	}

	isFrozen[id] = 0;
	novaDisplay[id] = 0;
	g_bHadNova[id] = false;

	unregister_prethink();

	if(!is_user_connected(id)) return;

	ExecuteHam(Ham_Player_ResetMaxSpeed, id);
	set_user_chillfreeze_speed(id);

	set_pev(id,pev_gravity,oldGravity[id]);

	new status = STATUS_HIDE;

	if(isChilled[id])
	{
		status = STATUS_SHOW;

		new rgb[3];
		get_rgb_colors(isChilled[id],rgb);
		set_beamfollow(id,30,8,rgb,100);
	}

	if(get_pcvar_num(pcv_icon) == ICON_ISCHILLED)
		show_icon(id, status);
}

chill_player(id,attacker,nadeTeam)
{
	new fwdRetVal = PLUGIN_CONTINUE;
	ExecuteForward(fnFwdPlayerChilled, fwdRetVal, id, attacker);

	if(fwdRetVal == PLUGIN_HANDLED || fwdRetVal == PLUGIN_HANDLED_MAIN)
		return 0;

	if(_:cs_get_user_team(id) != _:CS_TEAM_CT)
		return 0;

	if(!isChilled[id])
	{
		oldRenderFx[id] = pev(id,pev_renderfx);
		pev(id,pev_rendercolor,oldRenderColor[id]);
		oldRenderMode[id] = pev(id,pev_rendermode);
		pev(id,pev_renderamt,oldRenderAmt[id]);
	}

	isChilled[id] = nadeTeam;

	set_user_chillfreeze_speed(id);

	new Float:duration = get_pcvar_float(pcv_chill_duration), Float:variance = get_pcvar_float(pcv_chill_variance);
	duration += random_float(-variance,variance);

	remove_task(TASK_REMOVE_CHILL+id);
	set_task(duration,"task_remove_chill",TASK_REMOVE_CHILL+id);

	new rgb[3];
	get_rgb_colors(nadeTeam,rgb);
	IVecFVec(rgb, glowColor[id]);

	set_user_rendering(id, kRenderFxGlowShell, rgb[0], rgb[1], rgb[2], kRenderNormal, floatround(GLOW_AMOUNT));
	set_beamfollow(id,30,8,rgb,100);

	message_begin(MSG_ONE,gmsgScreenFade,_,id);
	write_short(floatround(4096.0 * duration));
	write_short(floatround(3072.0 * duration));
	write_short(FFADE_IN);
	write_byte(rgb[0]);
	write_byte(rgb[1]);
	write_byte(rgb[2]);
	write_byte(100);
	message_end();

	if(get_pcvar_num(pcv_icon) == ICON_ISCHILLED && !isFrozen[id])
		show_icon(id, STATUS_SHOW);

	return 1;
}

public task_remove_chill(taskid)
{
	new id = taskid-TASK_REMOVE_CHILL;

	isChilled[id] = 0;

	if(!is_user_connected(id)) return;

	ExecuteHam(Ham_Player_ResetMaxSpeed, id);
	set_user_chillfreeze_speed(id);

	set_user_rendering(id, oldRenderFx[id], floatround(oldRenderColor[id][0]), floatround(oldRenderColor[id][1]),
		floatround(oldRenderColor[id][2]), oldRenderMode[id], floatround(oldRenderAmt[id]));

	clear_beamfollow(id);

	new Float:flashedUntil = get_pdata_float(id,m_flFlashedUntil),
			Float:flashHoldTime = get_pdata_float(id,m_flFlashHoldTime),
			Float:endOfFlash = flashedUntil + (flashHoldTime * 0.67);

	if(get_gametime() >= endOfFlash)
	{
		message_begin(MSG_ONE,gmsgScreenFade,_,id);
		write_short(0);
		write_short(0);
		write_short(FFADE_IN);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(255);
		message_end();
	}

	if(get_pcvar_num(pcv_icon) == ICON_ISCHILLED && !isFrozen[id])
		show_icon(id, STATUS_HIDE);
}

create_nova(id)
{
	new nova = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!pev_valid(nova)) return;

	engfunc(EngFunc_SetSize,nova,Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 });
	engfunc(EngFunc_SetModel,nova,MODEL_FROZEN);

	new Float:angles[3];
	angles[1] = random_float(0.0,360.0);
	set_pev(nova,pev_angles,angles);

	new Float:novaOrigin[3];
	pev(id,pev_origin,novaOrigin);
	if(pev(id, pev_flags) & FL_DUCKING) novaOrigin[2] -= 15.0
	else novaOrigin[2] -= 35.0
	engfunc(EngFunc_SetOrigin,nova,novaOrigin);

	new rgb[3];
	get_rgb_colors(isFrozen[id], rgb);
	IVecFVec(rgb, angles);

	set_pev(nova,pev_rendercolor,angles);
	set_pev(nova,pev_rendermode,kRenderTransAlpha);
	set_pev(nova,pev_renderfx,kRenderFxGlowShell);
	set_pev(nova,pev_renderamt,128.0);

	novaDisplay[id] = nova;
}

/****************************************
* 投票 (2/3 人数 -> 5 秒倒计时 -> 7 秒计票)
****************************************/

public CmdFrostVote(id)
{
	if (!is_user_connected(id) || is_user_bot(id))
		return PLUGIN_HANDLED;

	if (!frost_mode_allowed())
	{
		frost_print_lang(id, "FROST_VOTE_MODE_BLOCK", "当前模式不支持冰冻烟雾投票。");
		return PLUGIN_HANDLED;
	}

	if (g_iForceMode != -1)
	{
		frost_print_lang(id, "FROST_VOTE_FORCED", "管理员已固定冰冻烟雾开关, 无法投票。");
		return PLUGIN_HANDLED;
	}

	if (g_bVoting)
	{
		g_bMenuOpen[id] = true;
		ShowFrostVoteMenu(id);
		return PLUGIN_HANDLED;
	}

	if (g_bMenuCountdown)
	{
		frost_print_lang(id, "FROST_VOTE_COUNTING", "冰冻烟雾投票将在 ^3%d^1 秒后开始。", g_iMenuCountdown);
		return PLUGIN_HANDLED;
	}

	new iNeed = FrostNeedVotes();
	new iLeft = iNeed - g_iWantCount;
	if (iLeft < 0) iLeft = 0;

	if (g_bWantVote[id])
	{
		frost_print_lang(id, "FROST_VOTE_ALREADY", "你已经请求过了！还需要 ^3%d^1 票。", iLeft);
		return PLUGIN_HANDLED;
	}

	g_bWantVote[id] = true;
	g_iWantCount++;

	iLeft = iNeed - g_iWantCount;
	if (iLeft < 0) iLeft = 0;

	if (g_iWantCount >= iNeed)
	{
		StartFrostCountdown();
		return PLUGIN_HANDLED;
	}

	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	frost_print_lang(0, "FROST_VOTE_NEED", "玩家 ^3%s^1 请求切换冰冻烟雾。需要 ^3%d^1/^3%d^1 票, 还差 ^3%d^1 票。", szName, g_iWantCount, iNeed, iLeft);
	return PLUGIN_HANDLED;
}

StartFrostCountdown()
{
	g_bMenuCountdown = true;
	g_bVoting = false;
	g_iMenuCountdown = FROST_COUNTDOWN;
	ResetFrostVotes();
	ResetFrostWants();

	frost_print_lang(0, "FROST_VOTE_COUNTING", "冰冻烟雾投票将在 ^3%d^1 秒后开始。", g_iMenuCountdown);
	client_cmd(0, "spk Gman/Gman_Choose2");

	remove_task(TASK_MENU_COUNTDOWN);
	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_HUD);
	set_task(1.0, "TaskFrostCountdown", TASK_MENU_COUNTDOWN, .flags = "b");
}

public TaskFrostCountdown()
{
	if (!g_bMenuCountdown)
	{
		remove_task(TASK_MENU_COUNTDOWN);
		return;
	}

	if (!frost_mode_allowed())
	{
		CancelFrostVote("FROST_VOTE_MODE_BLOCK", "当前模式不支持冰冻烟雾投票。");
		return;
	}

	g_iMenuCountdown--;
	if (g_iMenuCountdown > 0)
	{
		frost_print_lang(0, "FROST_VOTE_COUNTING", "冰冻烟雾投票将在 ^3%d^1 秒后开始。", g_iMenuCountdown);
		return;
	}

	remove_task(TASK_MENU_COUNTDOWN);
	g_bMenuCountdown = false;
	BeginFrostVote();
}

BeginFrostVote()
{
	g_bVoting = true;
	g_bMenuCountdown = false;
	g_iVoteLeft = FROST_VOTE_SECONDS;
	ResetFrostVotes();
	ResetFrostWants();

	frost_print_lang(0, "FROST_VOTE_START", "冰冻烟雾投票开始, 请在 ^3%d^1 秒内选择。", FROST_VOTE_SECONDS);
	client_cmd(0, "spk Gman/Gman_Choose2");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++)
	{
		new pid = iPlayers[i];
		if (is_user_bot(pid)) continue;
		g_bMenuOpen[pid] = true;
		ShowFrostVoteMenu(pid);
	}

	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_HUD);
	set_task(1.0, "TaskFrostVoteTick", TASK_VOTE_TICK, .flags = "b");
}

public TaskFrostVoteTick()
{
	if (!g_bVoting)
	{
		remove_task(TASK_VOTE_TICK);
		return;
	}

	g_iVoteLeft--;
	if (g_iVoteLeft > 0)
	{
		frost_print_lang(0, "FROST_VOTE_LEFT", "冰冻烟雾投票剩余 ^3%d^1 秒。", g_iVoteLeft);
		RefreshFrostMenus();
		return;
	}

	remove_task(TASK_VOTE_TICK);
	FinishFrostVote();
}

ShowFrostVoteMenu(id)
{
	if (!is_user_connected(id) || is_user_bot(id))
		return;

	new szMenu[512], szText[128], len;
	new bool:bOn = frost_active();

	frost_lang(id, "FROST_MENU_TITLE", szText, charsmax(szText), "\r[HNS] 冰冻烟雾投票^n");
	len = copy(szMenu, charsmax(szMenu), szText);
	frost_lang(id, "FROST_MENU_TIME", szText, charsmax(szText), "\w剩余 \y%d\w 秒  在线 \y%d\w 人^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, szText, g_iVoteLeft, FrostCountHumans());

	if (bOn)
		frost_lang(id, "FROST_MENU_STATE_ON", szText, charsmax(szText), "\w当前状态: \y开启^n^n");
	else
		frost_lang(id, "FROST_MENU_STATE_OFF", szText, charsmax(szText), "\w当前状态: \r关闭^n^n");
	len += copy(szMenu[len], charsmax(szMenu) - len, szText);

	frost_lang(id, "FROST_MENU_ITEM_ON", szText, charsmax(szText), "\r1.\w 开启冰冻烟雾 \d[%d%%]%s^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, szText, FrostPercent(0), (g_iVoteChoice[id] == 0) ? " \y<" : "");
	frost_lang(id, "FROST_MENU_ITEM_OFF", szText, charsmax(szText), "\r2.\w 关闭冰冻烟雾 \d[%d%%]%s^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, szText, FrostPercent(1), (g_iVoteChoice[id] == 1) ? " \y<" : "");

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");
	frost_lang(id, "FROST_MENU_HIDE", szText, charsmax(szText), "\r0.\w 隐藏菜单 (投票不结束)");
	len += copy(szMenu[len], charsmax(szMenu) - len, szText);

	show_menu(id, (MENU_KEY_1|MENU_KEY_2|MENU_KEY_0), szMenu, -1, "HNS Frost Vote");
}

public HandleVoteMenu(id, key)
{
	if (!g_bVoting)
	{
		g_bMenuOpen[id] = false;
		return PLUGIN_HANDLED;
	}

	if (key == 9)
	{
		g_bMenuOpen[id] = false;
		frost_print_lang(id, "FROST_MENU_HIDDEN", "菜单已隐藏, 输入 ^3/frost^1 可重新打开。");
		return PLUGIN_HANDLED;
	}

	g_bMenuOpen[id] = true;
	if (key == 0 || key == 1)
		SetFrostVote(id, key);

	ShowFrostVoteMenu(id);
	return PLUGIN_HANDLED;
}

SetFrostVote(id, choice)
{
	if (choice < 0 || choice > 1) return;
	if (g_iVoteChoice[id] == choice) return;

	RemoveFrostVote(id);
	g_iVoteChoice[id] = choice;
	g_iVotes[choice]++;

	new szName[32], szChoice[32];
	get_user_name(id, szName, charsmax(szName));
	frost_lang(id, choice == 0 ? "FROST_CHOICE_ON" : "FROST_CHOICE_OFF", szChoice, charsmax(szChoice), choice == 0 ? "开启" : "关闭");
	frost_print_lang(0, "FROST_VOTED", "^3%s^1 投票: ^3%s^1 (%d%%)。", szName, szChoice, FrostPercent(choice));
	RefreshFrostMenus();
}

RemoveFrostVote(id)
{
	new old = g_iVoteChoice[id];
	if (old == FROST_VOTE_NONE) return;

	if (old >= 0 && old < 2 && g_iVotes[old] > 0)
		g_iVotes[old]--;

	g_iVoteChoice[id] = FROST_VOTE_NONE;
}

FinishFrostVote()
{
	if (!g_bVoting) return;

	g_bVoting = false;
	CloseFrostMenus();

	if (g_iVotes[0] < 1 && g_iVotes[1] < 1)
	{
		frost_print_lang(0, "FROST_VOTE_NONE", "没有有效投票, 保持当前设置。");
		ResetFrostVotes();
		return;
	}

	new iWinner;
	if (g_iVotes[0] == g_iVotes[1])
		iWinner = random_num(0, 1);
	else
		iWinner = (g_iVotes[0] > g_iVotes[1]) ? 0 : 1;

	if (iWinner == 0)
	{
		g_bPlayersOff = false;
		frost_print_lang(0, "FROST_RESULT_ON", "投票结果: 冰冻烟雾 ^3已开启^1。");
	}
	else
	{
		g_bPlayersOff = true;
		frost_print_lang(0, "FROST_RESULT_OFF", "投票结果: 冰冻烟雾 ^3已关闭^1。");
	}

	apply_state_change();
	ResetFrostVotes();
}

CancelFrostVote(const szKey[], const szFallback[])
{
	g_bVoting = false;
	g_bMenuCountdown = false;
	g_iVoteLeft = 0;
	g_iMenuCountdown = 0;

	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_MENU_COUNTDOWN);
	remove_task(TASK_HUD);

	CloseFrostMenus();
	ResetFrostVotes();
	ResetFrostWants();
	frost_print_lang(0, szKey, szFallback);
}

ResetFrostVotes()
{
	g_iVotes[0] = 0;
	g_iVotes[1] = 0;
	for (new i = 1; i <= MaxClients; i++)
		g_iVoteChoice[i] = FROST_VOTE_NONE;
}

ResetFrostWants()
{
	g_iWantCount = 0;
	for (new i = 1; i <= MaxClients; i++)
		g_bWantVote[i] = false;
}

RefreshFrostMenus()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++)
	{
		new pid = iPlayers[i];
		if (g_bMenuOpen[pid])
			ShowFrostVoteMenu(pid);
	}
}

CloseFrostMenus()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++)
	{
		new pid = iPlayers[i];
		g_bMenuOpen[pid] = false;
		if (is_user_connected(pid))
			show_menu(pid, 0, "^n", 1);
	}
}

FrostCountHumans()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new n;
	for (new i; i < iNum; i++)
	{
		if (!is_user_bot(iPlayers[i]))
			n++;
	}
	return n;
}

FrostNeedVotes()
{
	new n = FrostCountHumans();
	new need = floatround(float(n) * float(FROST_NEED_NUM) / float(FROST_NEED_DEN), floatround_ceil);
	if (need < 1) need = 1;
	return need;
}

FrostPercent(choice)
{
	new n = FrostCountHumans();
	if (n < 1) return 0;
	return floatround(float(g_iVotes[choice]) * 100.0 / float(n));
}

stock frost_unescape(szText[], iLen)
{
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock frost_lang(id, const szKey[], szOut[], iLen, const szFallback[])
{
	szOut[0] = EOS;
	HnsLang_Get(id < 1 ? 0 : id, szKey, szOut, iLen);
	if (!szOut[0] || equal(szOut, szKey))
		copy(szOut, iLen, szFallback);
	frost_unescape(szOut, iLen);
}

stock frost_print_lang(const id, const szKey[], const szFallback[], any:...)
{
	if (id == 0)
	{
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++)
		{
			new szFmt[191], szOut[191];
			frost_lang(iPlayers[i], szKey, szFmt, charsmax(szFmt), szFallback);
			vformat(szOut, charsmax(szOut), szFmt, 4);
			client_print_color(iPlayers[i], print_team_blue, "^4[HNS]^1 %s", szOut);
		}
		return;
	}

	new szFmt[191], szOut[191];
	frost_lang(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, charsmax(szOut), szFmt, 4);
	client_print_color(id, print_team_blue, "^4[HNS]^1 %s", szOut);
}

/****************************************
* 工具
****************************************/

unregister_prethink()
{
	if(fmFwdPPT)
	{
		new i;
		for(i=1;i<=maxPlayers;i++) if(isFrozen[i]) break;
		if(i > maxPlayers)
		{
			unregister_forward(FM_PlayerPreThink,fmFwdPPT,0);
			fmFwdPPT = 0;
		}
	}
}

create_blast(team,Float:origin[3])
{
	new rgb[3];
	get_rgb_colors(team,rgb);

	message_begin_fl(MSG_PVS,SVC_TEMPENTITY,origin,0);
	write_byte(TE_BEAMCYLINDER);
	write_coord_fl(origin[0]);
	write_coord_fl(origin[1]);
	write_coord_fl(origin[2]);
	write_coord_fl(origin[0]);
	write_coord_fl(origin[1]);
	write_coord_fl(origin[2] + 385.0);
	write_short(exploSpr);
	write_byte(0);
	write_byte(0);
	write_byte(4);
	write_byte(60);
	write_byte(0);
	write_byte(rgb[0]);
	write_byte(rgb[1]);
	write_byte(rgb[2]);
	write_byte(100);
	write_byte(0);
	message_end();

	message_begin_fl(MSG_PVS,SVC_TEMPENTITY,origin,0);
	write_byte(TE_BEAMCYLINDER);
	write_coord_fl(origin[0]);
	write_coord_fl(origin[1]);
	write_coord_fl(origin[2]);
	write_coord_fl(origin[0]);
	write_coord_fl(origin[1]);
	write_coord_fl(origin[2] + 470.0);
	write_short(exploSpr);
	write_byte(0);
	write_byte(0);
	write_byte(4);
	write_byte(60);
	write_byte(0);
	write_byte(rgb[0]);
	write_byte(rgb[1]);
	write_byte(rgb[2]);
	write_byte(100);
	write_byte(0);
	message_end();

	message_begin_fl(MSG_PVS,SVC_TEMPENTITY,origin,0);
	write_byte(TE_BEAMCYLINDER);
	write_coord_fl(origin[0]);
	write_coord_fl(origin[1]);
	write_coord_fl(origin[2]);
	write_coord_fl(origin[0]);
	write_coord_fl(origin[1]);
	write_coord_fl(origin[2] + 555.0);
	write_short(exploSpr);
	write_byte(0);
	write_byte(0);
	write_byte(4);
	write_byte(60);
	write_byte(0);
	write_byte(rgb[0]);
	write_byte(rgb[1]);
	write_byte(rgb[2]);
	write_byte(100);
	write_byte(0);
	message_end();
}

set_beamfollow(ent,life,width,rgb[3],brightness)
{
	clear_beamfollow(ent);

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(ent);
	write_short(trailSpr);
	write_byte(life);
	write_byte(width);
	write_byte(rgb[0]);
	write_byte(rgb[1]);
	write_byte(rgb[2]);
	write_byte(brightness);
	message_end();
}

clear_beamfollow(ent)
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_KILLBEAM);
	write_short(ent);
	message_end();
}

show_icon(id, status)
{
	static rgb[3];
	if(status) get_rgb_colors(_:cs_get_user_team(id), rgb);

	message_begin(MSG_ONE,gmsgStatusIcon,_,id);
	write_byte(status);
	write_string("dmg_cold");
	write_byte(rgb[0]);
	write_byte(rgb[1]);
	write_byte(rgb[2]);
	message_end();
}

is_wid_in_nadetypes(wid)
{
	new types = get_pcvar_num(pcv_nadetypes);

	return ( (wid == CSW_HEGRENADE && (types & NT_HEGRENADE))
		|| (wid == CSW_FLASHBANG && (types & NT_FLASHBANG))
		|| (wid == CSW_SMOKEGRENADE && (types & NT_SMOKEGRENADE)) );
}

player_has_frostnade(id)
{
	new retVal = STATUS_HIDE, curwpn = get_user_weapon(id);

	if(hasFrostNade[id])
	{
		retVal = (curwpn == hasFrostNade[id] ? STATUS_FLASH : STATUS_SHOW);
	}
	else if(get_pcvar_num(pcv_override) && (get_pcvar_num(pcv_teams) & _:cs_get_user_team(id)))
	{
		new types = get_pcvar_num(pcv_nadetypes);

		if((types & NT_HEGRENADE) && cs_get_user_bpammo(id, CSW_HEGRENADE) > 0)
			retVal = (curwpn == CSW_HEGRENADE ? STATUS_FLASH : STATUS_SHOW);

		if(retVal != STATUS_FLASH && (types & NT_FLASHBANG) && cs_get_user_bpammo(id, CSW_FLASHBANG) > 0)
			retVal = (curwpn == CSW_FLASHBANG ? STATUS_FLASH : STATUS_SHOW);

		if(retVal != STATUS_FLASH && (types & NT_SMOKEGRENADE) && cs_get_user_bpammo(id, CSW_SMOKEGRENADE) > 0)
			retVal = (curwpn == CSW_SMOKEGRENADE ? STATUS_FLASH : STATUS_SHOW);
	}

	return retVal;
}

get_rgb_colors(team,rgb[3])
{
	static color[12], parts[3][4];
	get_pcvar_string(pcv_color,color,11);

	if(equali(color,"team",4))
	{
		if(team == 1)
		{
			rgb[0] = 150; rgb[1] = 0; rgb[2] = 0;
		}
		else
		{
			rgb[0] = 0; rgb[1] = 0; rgb[2] = 150;
		}
	}
	else
	{
		parse(color,parts[0],3,parts[1],3,parts[2],3);
		rgb[0] = str_to_num(parts[0]);
		rgb[1] = str_to_num(parts[1]);
		rgb[2] = str_to_num(parts[2]);
	}
}

Float:radius_calc(Float:distance,Float:radius,Float:maxVal,Float:minVal)
{
	if(maxVal <= 0.0) return 0.0;
	if(minVal >= maxVal) return minVal;
	return minVal + ((1.0 - (distance / radius)) * (maxVal - minVal));
}

set_user_chillfreeze_speed(id)
{
	if(isFrozen[id])
		set_user_maxspeed(id, 0.0);
	else if(isChilled[id])
		set_user_maxspeed(id, get_default_maxspeed(id)*(get_pcvar_float(pcv_chill_speed)/100.0));
}

stock Float:get_default_maxspeed(id)
{
	new wEnt = get_pdata_cbase(id, m_pActiveItem), Float:result = 250.0;

	if(pev_valid(wEnt))
		ExecuteHam(Ham_CS_Item_GetMaxSpeed, wEnt, result);

	return result;
}

grenade_deployed(id, wid)
{
	if(get_pcvar_num(pcv_enabled) && is_user_alive(id) && get_pcvar_num(pcv_icon) == ICON_HASNADE)
	{
		if( wid == hasFrostNade[id]
			|| (get_pcvar_num(pcv_override) && (get_pcvar_num(pcv_teams) & _:cs_get_user_team(id)) && is_wid_in_nadetypes(wid)) )
			show_icon(id, STATUS_FLASH);
	}
}

grenade_holstered(id, wid)
{
	if(get_pcvar_num(pcv_enabled) && is_user_alive(id) && get_pcvar_num(pcv_icon) == ICON_HASNADE)
	{
		if( wid == hasFrostNade[id]
			|| (get_pcvar_num(pcv_override) && (get_pcvar_num(pcv_teams) & _:cs_get_user_team(id)) && is_wid_in_nadetypes(wid)) )
		{
			new status = (player_has_frostnade(id) != STATUS_HIDE ? STATUS_SHOW : STATUS_HIDE);
			show_icon(id, status);
		}
	}
}

grenade_added(id, wid)
{
	if(get_pcvar_num(pcv_enabled) && is_user_alive(id) && get_pcvar_num(pcv_icon) == ICON_HASNADE)
	{
		if( wid == hasFrostNade[id]
			|| (get_pcvar_num(pcv_override) && (get_pcvar_num(pcv_teams) & _:cs_get_user_team(id)) && is_wid_in_nadetypes(wid)) )
		{
			new status = player_has_frostnade(id);
			show_icon(id, status);
		}
	}
}

#include <amxmodx>
#include <amxmisc>
#include <crxknives_const>
#include <cromchat>
#include <fakemeta>
#include <hamsandwich>
#include <sqlx>
#include <reapi_reunion>

native bool:has_reunion();
native bool:rh_emit_sound2(const entity, const recipient, const channel, const sample[], Float:vol, Float:attn, const flags, const pitch, emitFlags, const Float:origin[3]);

native crxranks_get_max_levels()
native crxranks_get_rank_by_level(level, buffer[], len)
native crxranks_get_user_level(id)
native crxranks_get_user_xp(id)

new const g_szNatives[][] =
{
	"crxranks_get_max_levels",
	"crxranks_get_rank_by_level",
	"crxranks_get_user_level",
	"crxranks_get_user_xp"
}

#if !defined m_pPlayer
const m_pPlayer = 41
#endif

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

new const PLUGIN_VERSION[] = "3.1.1"
const Float:DELAY_ON_CONNECT = 3.0

#if !defined MAX_AUTHID_LENGTH
const MAX_AUTHID_LENGTH = 35
#endif

#if !defined MAX_NAME_LENGTH
const MAX_NAME_LENGTH = 32
#endif

#if !defined MAX_PLAYERS
const MAX_PLAYERS = 32
#endif

#define KNIFE_DB_CFG "mixsystem/hnsmatch-sql.cfg"
#define KNIFE_CURRENT_TABLE "cpm_player_current"
#define TASK_KNIFE_LOAD 28100

new Handle:g_hSqlTuple = Empty_Handle
new g_szDbHost[64] = "127.0.0.1"
new g_szDbUser[48] = "root"
new g_szDbPass[64] = "root"
new g_szDbName[48] = "hns"
new bool:g_bSqlReady
new bool:g_bHasReunion
new bool:g_bKnifeLoaded[MAX_PLAYERS + 1]
new bool:g_bKnifePicked[MAX_PLAYERS + 1]
new bool:g_bKnifeHadRow[MAX_PLAYERS + 1]
new g_iLoadRetry[MAX_PLAYERS + 1]
new g_iLoadGeneration[MAX_PLAYERS + 1]

enum
{
	SOUND_NONE = 0,
	SOUND_DEPLOY,
	SOUND_HIT,
	SOUND_HITWALL,
	SOUND_SLASH,
	SOUND_STAB
}

enum _:Knives
{
	NAME[MAX_NAME_LENGTH],
	V_MODEL[CRXKNIVES_MAX_SOUND_LENGTH],
	P_MODEL[CRXKNIVES_MAX_SOUND_LENGTH],
	DEPLOY_SOUND[CRXKNIVES_MAX_SOUND_LENGTH],
	HIT_SOUND[CRXKNIVES_MAX_SOUND_LENGTH],
	HITWALL_SOUND[CRXKNIVES_MAX_SOUND_LENGTH],
	SLASH_SOUND[CRXKNIVES_MAX_SOUND_LENGTH],
	STAB_SOUND[CRXKNIVES_MAX_SOUND_LENGTH],
	SELECT_SOUND[CRXKNIVES_MAX_SOUND_LENGTH],
	FLAG,
	LEVEL,
	XP,
	SELECT_MESSAGES_NUM,
	bool:SHOW_RANK,
	bool:HAS_CUSTOM_SOUND,
	Array:SELECT_MESSAGES,
	Trie:ATTRIBUTES
}

enum _:CvarsReg
{
	cvar_km_open_at_spawn,
	cvar_km_save_choice,
	cvar_km_only_dead,
	cvar_km_select_message,
	cvar_km_knife_only_skills,
	cvar_km_admin_bypass
}

enum _:Cvars
{
	km_open_at_spawn,
	km_save_choice,
	km_only_dead,
	km_select_message,
	km_knife_only_skills,
	km_admin_bypass
}

new Array:g_aKnives,
	bool:g_bFirstTime[MAX_PLAYERS + 1],
	bool:g_bRankSystem,
	bool:g_bGetLevel,
	bool:g_bGetXP,
	g_eCvars[Cvars],
	g_eCvarsReg[CvarsReg],
	g_eKnife[MAX_PLAYERS + 1][Knives],
	g_szAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH],
	g_iKnife[MAX_PLAYERS + 1],
	g_fwdKnifeUpdated,
	g_fwdAttemptChange,
	g_iMenuFlags,
	g_iKnivesNum,
	g_iCallback,
	bool:g_bTeamKnifeEmit

public plugin_init()
{
	register_plugin("Knife Models", PLUGIN_VERSION, "OciXCrom")
	g_bHasReunion = has_reunion()
	register_cvar("CRXKnifeModels", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)

	if(!g_iKnivesNum)
	{
		set_fail_state("No knives found in the configuration file.")
	}

	register_dictionary("KnifeModels.txt")

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", 1)
	register_forward(FM_EmitSound,	"OnEmitSound")
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnSelectKnife", 1)

	register_clcmd("say /knife",       "Cmd_Knife")
	register_clcmd("say_team /knife",  "Cmd_Knife")
	register_clcmd("crxknives_select", "Cmd_Select", _, "<knife id>")

	g_fwdKnifeUpdated  = CreateMultiForward("crxknives_knife_updated",  ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_fwdAttemptChange = CreateMultiForward("crxknives_attempt_change", ET_STOP,   FP_CELL, FP_CELL)

	g_iCallback = menu_makecallback("CheckKnifeAccess")

	g_eCvarsReg[cvar_km_open_at_spawn]     = register_cvar("km_open_at_spawn",     "0")
	g_eCvarsReg[cvar_km_save_choice]       = register_cvar("km_save_choice",       "1")
	g_eCvarsReg[cvar_km_only_dead]         = register_cvar("km_only_dead",         "0")
	g_eCvarsReg[cvar_km_select_message]    = register_cvar("km_select_message",    "1")
	g_eCvarsReg[cvar_km_knife_only_skills] = register_cvar("km_knife_only_skills", "1")
	g_eCvarsReg[cvar_km_admin_bypass]      = register_cvar("km_admin_bypass",      "0")
}

public plugin_precache()
{
	if(LibraryExists("crxranks", LibType_Library))
	{
		g_bRankSystem = true
	}

	g_aKnives = ArrayCreate(Knives)
	ReadFile()
}

public plugin_cfg()
{
	g_eCvars[km_save_choice]       = get_pcvar_num(g_eCvarsReg[cvar_km_save_choice])
	g_eCvars[km_open_at_spawn]     = get_pcvar_num(g_eCvarsReg[cvar_km_open_at_spawn])
	g_eCvars[km_only_dead]         = get_pcvar_num(g_eCvarsReg[cvar_km_only_dead])
	g_eCvars[km_select_message]    = get_pcvar_num(g_eCvarsReg[cvar_km_select_message])
	g_eCvars[km_knife_only_skills] = get_pcvar_num(g_eCvarsReg[cvar_km_knife_only_skills])
	g_eCvars[km_admin_bypass]      = get_pcvar_num(g_eCvarsReg[cvar_km_admin_bypass])

	if(g_eCvars[km_save_choice])
	{
		load_database_config()
		g_hSqlTuple = SQL_MakeDbTuple(g_szDbHost, g_szDbUser, g_szDbPass, g_szDbName)
		SQL_SetCharset(g_hSqlTuple, "utf8")
		SQL_ThreadQuery(g_hSqlTuple, "knife_sql_handler", "CREATE TABLE IF NOT EXISTS cpm_player_current (authid VARCHAR(64) NOT NULL, team CHAR(1) NOT NULL DEFAULT '', model_key VARCHAR(32) NOT NULL DEFAULT '', updated INT NOT NULL DEFAULT 0, PRIMARY KEY (authid, team)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")
	}
}

public plugin_end()
{
	for(new eKnife[Knives], i; i < g_iKnivesNum; i++)
	{
		ArrayGetArray(g_aKnives, i, eKnife)
		ArrayDestroy(eKnife[SELECT_MESSAGES])
		TrieDestroy(eKnife[ATTRIBUTES])
	}

	if(g_eCvars[km_save_choice])
	{
		for(new id = 1; id <= MaxClients; id++)
			save_knife_mysql(id)
	}

	ArrayDestroy(g_aKnives)

	if(g_hSqlTuple != Empty_Handle)
	{
		SQL_FreeHandle(g_hSqlTuple)
		g_hSqlTuple = Empty_Handle
	}
}

ReadFile()
{
	new szFilename[256]
	get_configsdir(szFilename, charsmax(szFilename))
	add(szFilename, charsmax(szFilename), "/KnifeModels.ini")
	new iFilePointer = fopen(szFilename, "rt")

	if(iFilePointer)
	{
		new szData[160], szKey[32], szValue[128], szSound[128], iMaxLevels
		new eKnife[Knives], bool:bCustom

		if(g_bRankSystem)
		{
			iMaxLevels = crxranks_get_max_levels()
		}

		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)

			switch(szData[0])
			{
				case EOS, '#', ';': continue
				case '[':
				{
					if(szData[strlen(szData) - 1] == ']')
					{
						if(g_iKnivesNum)
						{
							push_knife(eKnife)
						}

						g_iKnivesNum++
						replace(szData, charsmax(szData), "[", "")
						replace(szData, charsmax(szData), "]", "")
						copy(eKnife[NAME], charsmax(eKnife[NAME]), szData)

						eKnife[V_MODEL][0] = EOS
						eKnife[P_MODEL][0] = EOS
						eKnife[DEPLOY_SOUND][0] = EOS
						eKnife[HIT_SOUND][0] = EOS
						eKnife[HITWALL_SOUND][0] = EOS
						eKnife[SLASH_SOUND][0] = EOS
						eKnife[STAB_SOUND][0] = EOS
						eKnife[SELECT_SOUND][0] = EOS
						eKnife[FLAG] = ADMIN_ALL
						eKnife[HAS_CUSTOM_SOUND] = false
						eKnife[SELECT_MESSAGES_NUM] = 0
						eKnife[SELECT_MESSAGES] = _:ArrayCreate(CRXKNIVES_MAX_MESSAGE_LENGTH)
						eKnife[ATTRIBUTES] = _:TrieCreate()

						if(g_bRankSystem)
						{
							eKnife[LEVEL] = 0
							eKnife[SHOW_RANK] = false
							eKnife[XP] = 0
						}

						static const ATTRIBUTE_NAME[] = "NAME"
						TrieSetString(eKnife[ATTRIBUTES], ATTRIBUTE_NAME, szData)
					}
					else continue
				}
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
					bCustom = true

					TrieSetString(eKnife[ATTRIBUTES], szKey, szValue)

					if(equal(szKey, "FLAG"))
					{
						eKnife[FLAG] = read_flags(szValue)
						g_iMenuFlags |= eKnife[FLAG]
					}
					else if(equal(szKey, "LEVEL") && g_bRankSystem)
					{
						eKnife[LEVEL] = clamp(str_to_num(szValue), 0, iMaxLevels)

						if(!g_bGetLevel)
						{
							g_bGetLevel = true
						}
					}
					else if(equal(szKey, "SHOW_RANK") && g_bRankSystem)
					{
						eKnife[SHOW_RANK] = _:clamp(str_to_num(szValue), false, true)
					}
					else if(equal(szKey, "XP") && g_bRankSystem)
					{
						eKnife[XP] = _:clamp(str_to_num(szValue), 0)

						if(!g_bGetXP)
						{
							g_bGetXP = true
						}
					}
					else if(equal(szKey, "V_MODEL"))
					{
						copy(eKnife[V_MODEL], charsmax(eKnife[V_MODEL]), szValue)
					}
					else if(equal(szKey, "P_MODEL"))
					{
						copy(eKnife[P_MODEL], charsmax(eKnife[P_MODEL]), szValue)
					}
					else if(equal(szKey, "DEPLOY_SOUND"))
					{
						copy(eKnife[DEPLOY_SOUND], charsmax(eKnife[DEPLOY_SOUND]), szValue)
					}
					else if(equal(szKey, "HIT_SOUND"))
					{
						copy(eKnife[HIT_SOUND], charsmax(eKnife[HIT_SOUND]), szValue)
					}
					else if(equal(szKey, "HITWALL_SOUND"))
					{
						copy(eKnife[HITWALL_SOUND], charsmax(eKnife[HITWALL_SOUND]), szValue)
					}
					else if(equal(szKey, "SLASH_SOUND"))
					{
						copy(eKnife[SLASH_SOUND], charsmax(eKnife[SLASH_SOUND]), szValue)
					}
					else if(equal(szKey, "STAB_SOUND"))
					{
						copy(eKnife[STAB_SOUND], charsmax(eKnife[STAB_SOUND]), szValue)
					}
					else if(equal(szKey, "SELECT_SOUND"))
					{
						bCustom = false
						copy(eKnife[SELECT_SOUND], charsmax(eKnife[SELECT_SOUND]), szValue)
					}
					else if(equal(szKey, "SELECT_MESSAGE"))
					{
						ArrayPushString(eKnife[SELECT_MESSAGES], szValue)
						eKnife[SELECT_MESSAGES_NUM]++
					}
					else continue

					static const szModelArg[] = "_MODEL"
					static const szSoundArg[] = "_SOUND"

					if(contain(szKey, szModelArg) != -1)
					{
						if(!file_exists(szValue))
						{
							log_amx("ERROR: model ^"%s^" not found!", szValue)
						}
						else
						{
							precache_model(szValue)
						}
					}
					else if(contain(szKey, szSoundArg) != -1)
					{
						formatex(szSound, charsmax(szSound), "sound/%s", szValue)

						if(!file_exists(szSound))
						{
							log_amx("ERROR: sound ^"%s^" not found!", szSound)
						}
						else
						{
							precache_sound(szValue)
						}

						if(bCustom)
						{
							eKnife[HAS_CUSTOM_SOUND] = true
						}
					}
				}
			}
		}

		if(g_iKnivesNum)
		{
			push_knife(eKnife)
		}

		fclose(iFilePointer)
	}
}

public client_connect(id)
{
	g_bFirstTime[id] = true
	g_bKnifeLoaded[id] = false
	g_bKnifePicked[id] = false
	g_bKnifeHadRow[id] = false
	g_iLoadRetry[id] = 0
	g_szAuth[id][0] = 0
	remove_task(id)
	ArrayGetArray(g_aKnives, 0, g_eKnife[id])
	g_iKnife[id] = 0

	new iReturn
	ExecuteForward(g_fwdKnifeUpdated, iReturn, id, g_iKnife[id], true)

	if(g_eCvars[km_save_choice])
		set_task(DELAY_ON_CONNECT, "load_data", id)
}

public client_disconnected(id)
{
	remove_task(id)
	if(g_eCvars[km_save_choice])
	{
		if(!g_szAuth[id][0])
			get_knife_auth(id, g_szAuth[id], charsmax(g_szAuth[]))
		save_knife_mysql(id)
	}
	g_iLoadGeneration[id]++
	g_bKnifeLoaded[id] = false
	g_bKnifePicked[id] = false
	g_bKnifeHadRow[id] = false
}

play_knife_sound_team(const id, const iChannel, const szSound[])
{
	new iTeam = get_user_team(id)
	new iPlayers[MAX_PLAYERS], iNum
	get_players(iPlayers, iNum, "c")

	new Float:vecNull[3]
	g_bTeamKnifeEmit = true
	for(new i; i < iNum; i++)
	{
		new iPlayer = iPlayers[i]
		if(!is_user_connected(iPlayer))
			continue
		if(iPlayer != id && (iTeam != 1 && iTeam != 2 || get_user_team(iPlayer) != iTeam))
			continue
		rh_emit_sound2(id, iPlayer, iChannel, szSound, 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecNull)
	}
	g_bTeamKnifeEmit = false
}

public OnEmitSound(id, iChannel, const szSample[])
{
	if(g_bTeamKnifeEmit)
		return FMRES_IGNORED

	if(!is_user_connected(id) || !is_knife_sound(szSample))
		return FMRES_IGNORED

	// 切刀声按距离传给所有人，对面能靠这个找位置。拦掉原声，只发给同队。
	if(detect_knife_sound(szSample) == SOUND_DEPLOY)
	{
		if(g_eKnife[id][HAS_CUSTOM_SOUND] && g_eKnife[id][DEPLOY_SOUND][0])
			play_knife_sound_team(id, iChannel, g_eKnife[id][DEPLOY_SOUND])
		else
			play_knife_sound_team(id, iChannel, szSample)
		return FMRES_SUPERCEDE
	}

	if(!g_eKnife[id][HAS_CUSTOM_SOUND])
		return FMRES_IGNORED

	switch(detect_knife_sound(szSample))
	{
		case SOUND_HIT: 		if(g_eKnife[id][HIT_SOUND][0]) 			{ play_knife_sound(id, g_eKnife[id][HIT_SOUND][0]);         return FMRES_SUPERCEDE; }
		case SOUND_HITWALL:		if(g_eKnife[id][HITWALL_SOUND][0]) 		{ play_knife_sound(id, g_eKnife[id][HITWALL_SOUND][0]);     return FMRES_SUPERCEDE; }
		case SOUND_SLASH: 		if(g_eKnife[id][SLASH_SOUND][0]) 		{ play_knife_sound(id, g_eKnife[id][SLASH_SOUND][0]);       return FMRES_SUPERCEDE; }
		case SOUND_STAB: 		if(g_eKnife[id][STAB_SOUND][0]) 		{ play_knife_sound(id, g_eKnife[id][STAB_SOUND][0]);        return FMRES_SUPERCEDE; }
	}

	return FMRES_IGNORED
}

public Cmd_Knife(id)
{
	if(g_eCvars[km_only_dead] && is_user_alive(id))
	{
		CC_SendMessage(id, "%L %L", id, "KM_CHAT_PREFIX", id, "KM_ONLY_DEAD")
		return PLUGIN_HANDLED
	}

	static eKnife[Knives]
	new szTitle[128], szItem[128], iLevel, iXP
	formatex(szTitle, charsmax(szTitle), "%L", id, "KM_MENU_TITLE")

	if(g_bGetLevel)
	{
		iLevel = crxranks_get_user_level(id)
	}

	if(g_bGetXP)
	{
		iXP = crxranks_get_user_xp(id)
	}

	new iMenu = menu_create(szTitle, "MenuHandler")

	for(new iFlags = get_user_flags(id), i; i < g_iKnivesNum; i++)
	{
		ArrayGetArray(g_aKnives, i, eKnife)
		copy(szItem, charsmax(szItem), eKnife[NAME])

		if(g_bRankSystem)
		{
			if(eKnife[LEVEL] && iLevel < eKnife[LEVEL])
			{
				if(eKnife[SHOW_RANK])
				{
					static szRank[32]
					crxranks_get_rank_by_level(eKnife[LEVEL], szRank, charsmax(szRank))
					format(szItem, charsmax(szItem), "%s %L", szItem, id, "KM_MENU_RANK", szRank)
				}
				else
				{
					format(szItem, charsmax(szItem), "%s %L", szItem, id, "KM_MENU_LEVEL", eKnife[LEVEL])
				}
			}

			if(eKnife[XP] && iXP < eKnife[XP])
			{
				format(szItem, charsmax(szItem), "%s %L", szItem, id, "KM_MENU_XP", eKnife[XP])
			}
		}

		if(eKnife[FLAG] != ADMIN_ALL && !(iFlags & eKnife[FLAG]))
		{
			format(szItem, charsmax(szItem), "%s %L", szItem, id, "KM_MENU_VIP_ONLY")
		}

		if(g_iKnife[id] == i)
		{
			format(szItem, charsmax(szItem), "%s %L", szItem, id, "KM_MENU_SELECTED")
		}

		menu_additem(iMenu, szItem, eKnife[NAME], eKnife[FLAG], g_iCallback)
	}

	if(menu_pages(iMenu) > 1)
	{
		formatex(szItem, charsmax(szItem), "%s%L", szTitle, id, "KM_MENU_TITLE_PAGE")
		menu_setprop(iMenu, MPROP_TITLE, szItem)
	}

	menu_display(id, iMenu)
	return PLUGIN_HANDLED
}

public Cmd_Select(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 2))
	{
		return PLUGIN_HANDLED
	}

	if(g_eCvars[km_only_dead] && is_user_alive(id))
	{
		CC_SendMessage(id, "%L %L", id, "KM_CHAT_PREFIX", id, "KM_ONLY_DEAD")
		return PLUGIN_HANDLED
	}

	new szKnife[4]
	read_argv(1, szKnife, charsmax(szKnife))

	new iKnife = str_to_num(szKnife)

	if(!is_knife_valid(iKnife))
	{
		console_print(id, "%l", "KM_INVALID_KNIFE", g_iKnivesNum - 1)
		return PLUGIN_HANDLED
	}

	if(!has_knife_access(id, iKnife))
	{
		console_print(id, "%l", "KM_NO_ACCESS")
		return PLUGIN_HANDLED
	}

	select_knife(id, iKnife)
	return PLUGIN_HANDLED
}

public MenuHandler(id, iMenu, iItem)
{
	if(g_eCvars[km_only_dead] && is_user_alive(id))
	{
		CC_SendMessage(id, "%L %L", id, "KM_CHAT_PREFIX", id, "KM_ONLY_DEAD")
		goto @MENU_DESTROY
	}

	if(!is_user_connected(id))
	{
		goto @MENU_DESTROY
	}

	if(iItem != MENU_EXIT)
	{
		select_knife(id, iItem)
	}

	@MENU_DESTROY:
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

select_knife(id, iKnife)
{
	new iReturn
	ExecuteForward(g_fwdAttemptChange, iReturn, id, iKnife)

	if(iReturn == PLUGIN_HANDLED)
	{
		return
	}

	g_bKnifePicked[id] = true
	g_bKnifeLoaded[id] = true
	g_bKnifeHadRow[id] = true
	g_iLoadGeneration[id]++
	g_iKnife[id] = iKnife
	if(!g_szAuth[id][0])
		get_knife_auth(id, g_szAuth[id], charsmax(g_szAuth[]))
	if(g_eCvars[km_save_choice])
		save_knife_mysql(id)
	ArrayGetArray(g_aKnives, iKnife, g_eKnife[id])
	ExecuteForward(g_fwdKnifeUpdated, iReturn, id, iKnife, false)

	if(is_user_alive(id) && get_user_weapon(id) == CSW_KNIFE)
	{
		refresh_knife_model(id)
	}

	if(g_eCvars[km_select_message])
	{
		CC_SendMessage(id, "%L %L", id, "KM_CHAT_PREFIX", id, "KM_CHAT_SELECTED", g_eKnife[id][NAME])
	}

	if(g_eKnife[id][SELECT_MESSAGES_NUM])
	{
		for(new i; i < g_eKnife[id][SELECT_MESSAGES_NUM]; i++)
		{
			CC_SendMessage(id, "%a", ArrayGetStringHandle(g_eKnife[id][SELECT_MESSAGES], i))
		}
	}

	if(g_eKnife[id][SELECT_SOUND][0])
	{
		play_knife_sound(id, g_eKnife[id][SELECT_SOUND])
	}
}

public load_data(id)
{
	if(!is_user_connected(id) || !g_eCvars[km_save_choice] || g_bKnifePicked[id])
		return

	if(g_hSqlTuple == Empty_Handle || !g_bSqlReady || knife_auth_pending(id))
	{
		if(g_iLoadRetry[id] < 30)
		{
			g_iLoadRetry[id]++
			set_task(0.5, "load_data", id)
		}
		return
	}

	load_knife_mysql(id)
}

public CheckKnifeAccess(id, iMenu, iItem)
{
	return ((g_iKnife[id] == iItem) || !has_knife_access(id, iItem)) ? ITEM_DISABLED : ITEM_ENABLED
}

public OnPlayerSpawn(id)
{
	if(is_user_alive(id) && g_eCvars[km_open_at_spawn] && !g_iKnife[id] && g_bFirstTime[id] && (g_iMenuFlags & ADMIN_USER || get_user_flags(id) & g_iMenuFlags))
	{
		g_bFirstTime[id] = false
		Cmd_Knife(id)
	}
}

public OnSelectKnife(iEnt)
{
	new id = get_pdata_cbase(iEnt, m_pPlayer, 4)

	if(is_user_connected(id))
	{
		refresh_knife_model(id)
	}
}

bool:hns_knife_view_hidden(const id)
{
	if(cvar_exists("hns_hideknife") && get_cvar_num("hns_hideknife"))
		return true

	new szValue[4]
	get_user_info(id, "_hknife", szValue, charsmax(szValue))
	return szValue[0] == '1'
}

refresh_knife_model(const id)
{
	if(hns_knife_view_hidden(id))
		set_pev(id, pev_viewmodel2, "")
	else
		set_pev(id, pev_viewmodel2, g_eKnife[id][V_MODEL])
	set_pev(id, pev_weaponmodel2, g_eKnife[id][P_MODEL])
}

push_knife(eKnife[Knives])
{
	if(!eKnife[V_MODEL][0])
	{
		copy(eKnife[V_MODEL], charsmax(eKnife[V_MODEL]), CRXKNIVES_DEFAULT_V)
	}

	if(!eKnife[P_MODEL][0])
	{
		copy(eKnife[P_MODEL], charsmax(eKnife[P_MODEL]), CRXKNIVES_DEFAULT_P)
	}

	if(!eKnife[FLAG])
	{
		g_iMenuFlags |= ADMIN_USER
	}

	ArrayPushArray(g_aKnives, eKnife)
}

bool:has_knife_access(const id, const iKnife)
{
	static eKnife[Knives]
	ArrayGetArray(g_aKnives, iKnife, eKnife)

	if(eKnife[FLAG] != ADMIN_ALL)
	{
		if(get_user_flags(id) & eKnife[FLAG])
		{
			if(g_eCvars[km_admin_bypass])
			{
				return true
			}
		}
		else
		{
			return false
		}
	}

	if(g_bRankSystem)
	{
		if(eKnife[LEVEL] && crxranks_get_user_level(id) < eKnife[LEVEL])
		{
			return false
		}

		if(eKnife[XP] && crxranks_get_user_xp(id) < eKnife[XP])
		{
			return false
		}
	}

	return true
}

bool:is_knife_sound(const szSample[])
{
	return bool:equal(szSample[8], "kni", 3)
}

detect_knife_sound(const szSample[])
{
	static iSound
	iSound = SOUND_NONE

	if(equal(szSample, "weapons/knife_deploy1.wav"))
	{
		iSound = SOUND_DEPLOY
	}
	else if(equal(szSample[14], "hit", 3))
	{
		iSound = szSample[17] == 'w' ? SOUND_HITWALL : SOUND_HIT
	}
	else if(equal(szSample[14], "sla", 3))
	{
		iSound = SOUND_SLASH
	}
	else if(equal(szSample[14], "sta", 3))
	{
		iSound = SOUND_STAB
	}

	return iSound
}

load_database_config()
{
	new szPath[PLATFORM_MAX_PATH], szLine[192], szKey[32], szValue[128]
	get_configsdir(szPath, charsmax(szPath))
	add(szPath, charsmax(szPath), "/")
	add(szPath, charsmax(szPath), KNIFE_DB_CFG)
	new file = fopen(szPath, "rt")
	if(!file)
		return

	while(!feof(file))
	{
		fgets(file, szLine, charsmax(szLine))
		trim(szLine)
		if(!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue
		parse(szLine, szKey, charsmax(szKey), szValue, charsmax(szValue))
		remove_quotes(szValue)
		if(equali(szKey, "hns_host")) copy(g_szDbHost, charsmax(g_szDbHost), szValue)
		else if(equali(szKey, "hns_user")) copy(g_szDbUser, charsmax(g_szDbUser), szValue)
		else if(equali(szKey, "hns_pass")) copy(g_szDbPass, charsmax(g_szDbPass), szValue)
		else if(equali(szKey, "hns_db")) copy(g_szDbName, charsmax(g_szDbName), szValue)
	}
	fclose(file)
}

bool:is_pending_auth(const szAuth[])
{
	if(!szAuth[0])
		return true
	return equali(szAuth, "STEAM_ID_PENDING")
		|| equali(szAuth, "VALVE_ID_PENDING")
		|| equali(szAuth, "STEAM_ID_LAN")
		|| equali(szAuth, "VALVE_ID_LAN")
		|| equali(szAuth, "BOT")
}

bool:is_real_steam(id)
{
	if(!is_user_connected(id))
		return false
	if(!g_bHasReunion)
		return true
	return REU_GetAuthtype(id) == CA_TYPE_STEAM
}

bool:usable_ip(const szIp[])
{
	if(!szIp[0] || equal(szIp, "0.0.0.0") || contain(szIp, ".") == -1)
		return false
	return true
}

bool:build_pirate_auth(id, dest[], len)
{
	new szIp[22]
	get_user_ip(id, szIp, charsmax(szIp), 1)
	new iColon = contain(szIp, ":")
	if(iColon != -1)
		szIp[iColon] = 0
	if(!usable_ip(szIp))
		return false

	new szName[MAX_NAME_LENGTH]
	get_user_name(id, szName, charsmax(szName))
	if(!szName[0])
		copy(szName, charsmax(szName), "unnamed")
	formatex(dest, len, "NAME:%s|%s", szIp, szName)
	return dest[0] != 0
}

bool:knife_auth_pending(id)
{
	if(!is_user_connected(id))
		return true
	if(g_bHasReunion)
	{
		new client_auth_type:t = REU_GetAuthtype(id)
		if(t == CA_TYPE_NONE)
			return true
		if(t != CA_TYPE_STEAM)
		{
			if(equali(g_szAuth[id], "NAME:", 5))
				return false
			new szKey[MAX_AUTHID_LENGTH]
			return !build_pirate_auth(id, szKey, charsmax(szKey))
		}
	}
	new szSteam[64]
	get_user_authid(id, szSteam, charsmax(szSteam))
	return is_pending_auth(szSteam) && !equali(g_szAuth[id], "STEAM:", 6)
}

get_knife_auth(id, dest[], len)
{
	if(g_bHasReunion && is_user_connected(id) && REU_GetAuthtype(id) == CA_TYPE_NONE)
	{
		if(equali(g_szAuth[id], "STEAM:", 6))
			copy(dest, len, g_szAuth[id])
		else
			dest[0] = EOS
		return
	}

	new szSteam[64]
	get_user_authid(id, szSteam, charsmax(szSteam))
	if(is_real_steam(id) && !is_pending_auth(szSteam))
	{
		formatex(dest, len, "STEAM:%s", szSteam)
		copy(g_szAuth[id], charsmax(g_szAuth[]), dest)
		return
	}

	if(equali(g_szAuth[id], "STEAM:", 6))
	{
		copy(dest, len, g_szAuth[id])
		return
	}

	if(!build_pirate_auth(id, dest, len))
	{
		if(equali(g_szAuth[id], "NAME:", 5))
			copy(dest, len, g_szAuth[id])
		else
			dest[0] = 0
		return
	}
	copy(g_szAuth[id], charsmax(g_szAuth[]), dest)
}

escape_sql(const src[], dest[], len)
{
	copy(dest, len, src)
	replace_all(dest, len, "'", "''")
}

load_knife_mysql(id)
{
	new szAuth[MAX_AUTHID_LENGTH]
	get_knife_auth(id, szAuth, charsmax(szAuth))
	if(!szAuth[0])
		return
	copy(g_szAuth[id], charsmax(g_szAuth[]), szAuth)

	new szEsc[MAX_AUTHID_LENGTH * 2], data[2]
	escape_sql(szAuth, szEsc, charsmax(szEsc))
	data[0] = id
	data[1] = g_iLoadGeneration[id]
	SQL_ThreadQuery(g_hSqlTuple, "knife_sql_handler", fmt("SELECT model_key FROM %s WHERE authid='%s' AND team='K'", KNIFE_CURRENT_TABLE, szEsc), data, sizeof(data))
}

save_knife_mysql(id)
{
	if(g_hSqlTuple == Empty_Handle || !g_bSqlReady || !g_szAuth[id][0])
		return
	if(!g_bKnifePicked[id] && !g_bKnifeHadRow[id])
		return
	if(is_user_connected(id) && !knife_auth_pending(id))
	{
		new szLive[MAX_AUTHID_LENGTH]
		get_knife_auth(id, szLive, charsmax(szLive))
		if(szLive[0] && !equal(szLive, g_szAuth[id]))
			return
	}

	new szEscAuth[MAX_AUTHID_LENGTH * 2], szKey[32], szEscKey[64], szQuery[384]
	formatex(szKey, charsmax(szKey), "knife:%d", g_iKnife[id])
	escape_sql(g_szAuth[id], szEscAuth, charsmax(szEscAuth))
	escape_sql(szKey, szEscKey, charsmax(szEscKey))
	formatex(szQuery, charsmax(szQuery), "INSERT INTO %s (authid, team, model_key, updated) VALUES ('%s','K','%s',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE model_key='%s', updated=UNIX_TIMESTAMP()", KNIFE_CURRENT_TABLE, szEscAuth, szEscKey, szEscKey)
	new iErr, szErr[128]
	new Handle:hDb = SQL_Connect(g_hSqlTuple, iErr, szErr, charsmax(szErr))
	if(hDb == Empty_Handle)
	{
		log_amx("[KnifeModels] save connect failed (%d): %s", iErr, szErr)
		return
	}
	if(!SQL_SimpleQuery(hDb, szQuery, szErr, charsmax(szErr)))
		log_amx("[KnifeModels] save failed: %s", szErr)
	SQL_FreeHandle(hDb)
}

public knife_sql_handler(failstate, Handle:query, error[], errorNum, data[], dataSize)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("[KnifeModels] MySQL error (%d): %s", errorNum, error)
		return
	}

	if(dataSize < 2)
	{
		g_bSqlReady = true
		return
	}

	new id = data[0]
	if(!is_user_connected(id) || data[1] != g_iLoadGeneration[id] || g_bKnifePicked[id])
		return

	g_bKnifeLoaded[id] = true
	new key[32], knife
	if(SQL_NumResults(query))
		g_bKnifeHadRow[id] = true
	if(SQL_NumResults(query) && SQL_ReadResult(query, 0, key, charsmax(key)) && containi(key, "knife:") == 0)
	{
		knife = str_to_num(key[6])
		if(is_knife_valid(knife) && has_knife_access(id, knife))
		{
			g_iKnife[id] = knife
			new iReturn
			ArrayGetArray(g_aKnives, knife, g_eKnife[id])
			ExecuteForward(g_fwdKnifeUpdated, iReturn, id, knife, false)
			if(is_user_alive(id) && get_user_weapon(id) == CSW_KNIFE)
				refresh_knife_model(id)
		}
	}
}

play_knife_sound(const id, const szSound[])
{
	engfunc(EngFunc_EmitSound, id, CHAN_AUTO, szSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

bool:is_knife_valid(const iKnife)
{
	return 0 <= iKnife < g_iKnivesNum
}

public plugin_natives()
{
	register_library("crxknives")
	register_native("crxknives_can_use_skill",       "_crxknives_can_use_skill")
	register_native("crxknives_get_attribute_int",   "_crxknives_get_attribute_int")
	register_native("crxknives_get_attribute_float", "_crxknives_get_attribute_float")
	register_native("crxknives_get_attribute_str",   "_crxknives_get_attribute_str")
	register_native("crxknives_get_knives_num",      "_crxknives_get_knives_num")
	register_native("crxknives_get_user_knife",      "_crxknives_get_user_knife")
	register_native("crxknives_select_knife",        "_crxknives_select_knife")
	register_native("crxknives_has_knife_access",    "_crxknives_has_knife_access")
	register_native("crxknives_is_knife_valid",      "_crxknives_is_knife_valid")
	set_native_filter("native_filter")
}

public native_filter(const szNative[], id, iTrap)
{
	if(!iTrap)
	{
		static i

		for(i = 0; i < sizeof(g_szNatives); i++)
		{
			if(equal(szNative, g_szNatives[i]))
			{
				return PLUGIN_HANDLED
			}
		}
	}

	return PLUGIN_CONTINUE
}

public bool:_crxknives_can_use_skill(iPlugin, iParams)
{
	return !g_eCvars[km_knife_only_skills] || (get_user_weapon(get_param(1)) == CSW_KNIFE)
}

public bool:_crxknives_get_attribute_int(iPlugin, iParams)
{
	static szAttribute[MAX_NAME_LENGTH], szValue[CRXKNIVES_MAX_ATTRIBUTE_LENGTH], id
	get_string(2, szAttribute, charsmax(szAttribute))
	id = get_param(1)

	if(!get_param(4))
	{
		if(!is_knife_valid(id))
		{
			return false
		}

		static eKnife[Knives]
		ArrayGetArray(g_aKnives, id, eKnife)

		if(!TrieKeyExists(eKnife[ATTRIBUTES], szAttribute))
		{
			return false
		}

		TrieGetString(eKnife[ATTRIBUTES], szAttribute, szValue, charsmax(szValue))
		goto @SET_ATTRIBUTE
	}

	if(!TrieKeyExists(g_eKnife[id][ATTRIBUTES], szAttribute))
	{
		return false
	}

	TrieGetString(g_eKnife[id][ATTRIBUTES], szAttribute, szValue, charsmax(szValue))

	@SET_ATTRIBUTE:
	set_param_byref(3, str_to_num(szValue))
	return true
}

public bool:_crxknives_get_attribute_float(iPlugin, iParams)
{
	static szAttribute[MAX_NAME_LENGTH], szValue[CRXKNIVES_MAX_ATTRIBUTE_LENGTH], id
	get_string(2, szAttribute, charsmax(szAttribute))
	id = get_param(1)

	if(!get_param(4))
	{
		if(!is_knife_valid(id))
		{
			return false
		}

		static eKnife[Knives]
		ArrayGetArray(g_aKnives, id, eKnife)

		if(!TrieKeyExists(eKnife[ATTRIBUTES], szAttribute))
		{
			return false
		}

		TrieGetString(eKnife[ATTRIBUTES], szAttribute, szValue, charsmax(szValue))
		goto @SET_ATTRIBUTE
	}

	if(!TrieKeyExists(g_eKnife[id][ATTRIBUTES], szAttribute))
	{
		return false
	}

	TrieGetString(g_eKnife[id][ATTRIBUTES], szAttribute, szValue, charsmax(szValue))

	@SET_ATTRIBUTE:
	set_float_byref(3, str_to_float(szValue))
	return true
}

public bool:_crxknives_get_attribute_str(iPlugin, iParams)
{
	static szAttribute[MAX_NAME_LENGTH], szValue[CRXKNIVES_MAX_ATTRIBUTE_LENGTH], id
	get_string(2, szAttribute, charsmax(szAttribute))
	id = get_param(1)

	if(!get_param(5))
	{
		if(!is_knife_valid(id))
		{
			return false
		}

		static eKnife[Knives]
		ArrayGetArray(g_aKnives, id, eKnife)

		if(!TrieKeyExists(eKnife[ATTRIBUTES], szAttribute))
		{
			return false
		}

		TrieGetString(eKnife[ATTRIBUTES], szAttribute, szValue, charsmax(szValue))
		goto @SET_ATTRIBUTE
	}

	if(!TrieKeyExists(g_eKnife[id][ATTRIBUTES], szAttribute))
	{
		return false
	}

	TrieGetString(g_eKnife[id][ATTRIBUTES], szAttribute, szValue, charsmax(szValue))

	@SET_ATTRIBUTE:
	set_string(3, szValue, get_param(4))
	return true
}

public _crxknives_get_knives_num(iPlugin, iParams)
{
	return g_iKnivesNum
}

public _crxknives_get_user_knife(iPlugin, iParams)
{
	return g_iKnife[get_param(1)]
}

public _crxknives_select_knife(iPlugin, iParams)
{
	new id = get_param(1)
	new knife = get_param(2)
	if(!is_user_connected(id) || !is_knife_valid(knife))
		return 0

	select_knife(id, knife)
	return 1
}

public bool:_crxknives_has_knife_access(iPlugin, iParams)
{
	return has_knife_access(get_param(1), get_param(2))
}

public bool:_crxknives_is_knife_valid(iPlugin, iParams)
{
	return is_knife_valid(get_param(1))
}
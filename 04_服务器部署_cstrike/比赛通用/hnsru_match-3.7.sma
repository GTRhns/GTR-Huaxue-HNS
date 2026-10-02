/* 
	* Plugin created by Sideways (c) 2014-2015
	* HideNSeek Mix System
	* For www.hnsru.net
	* My Steam Profile: steamcommunity.com/id/sidewayshns
	
	Version 1.0:
		Release plugin
	
	Version 2.0:
		Added Semiclip + (Cvar ON/OFF)
		Added HideNSeek
		Added command say /knife, /hideknife
		Added many useful Cvars
		Added WarMap 
		Added Godmode
		Added Hook
		Added CheckPoints
		Added Cvar to prefix
		Added KnifeRound + command say /kfstop
		Added Cvar GameName
		Added message a new round auto score
		Fixed command say /stop
		Fixed Welcome message
		Fixed a message bug
		Deleted hnsru_hns,cfg and hnsru_kf.cfg
		
	Version: 2.1 
		Auto control cvar mp_timelimit
		Added menu (say /mix)
		
	Version: 2.2
		New hook code (Fixed bug)
		New hnsru_acess to control the mix
		
	Version: 2.3
		New hook code (Fixed bug)
	
	Version: 2.4
		??????? ? ??? ???????? ???? /knife - ????? ????.
		??????? ?? ??? ?????? ??? ??? ??? ??? ??????????? ? ????? ????????
		
	Version: 2.4.9
		???????????/start ??????? ???
		
	Version: 2.5
		?????????????? ??? ???/mix ????? ????/pause ?/live
		????? hnsru_pause
		
	Version: 2.6
		???? screenfade (????? ?? ct)
		
	Version: 3.0 beta
		??? ??????? hud ??chat (hnsru_hud 1/0)
		???????????????????(??? ? ?? ??????????)
		????? ????????
		?????????
		???????? ??
		
	Version: 3.0 stable
		????? ???
		??????? JumpStats HNSRU (cvar hnsru_stats_amxx 1/0)
		
	Version: 3.1 FunMode
		???? FunMode ??????? ???????/fun
		??? ?????/stop
		
	Version: 3.2 FunMode
		????? ??? ?funmode
		???????funmode
		?????playermodel.amxx ????(hnsru_playermodel 1/0 - ?????????cl_minmodels 
	
	Version: 3.3
		???? ??????????? ???
		??? hnsru_playermodel (cl_minmodels)
		? ?? ????????????
		????????fun ??
		??? Auto Join Taem
		???? ???? ?join team: tt/spec ???
		
	Version: 3.3.1
		????????? ?? /spec, /tt, /ct
		????? ??? ?hnsru_welcome ? debug'?
		
	Version: 3.3.2
		??? ??????? ????????? ??? ? ??- ? ??? ?????

	Version: 3.3.3
		?? ? ? ???????????? ? ?, ? ? ? ??? ??? ??

	Version 3.4 
		???????
		????? ?????
		??? ???????? ???DHUD ??????+ ??????
		????????????? ????? ???
		??? ????/kfstop (??? knife round ???????? ???? /stop)
		?????? ?????????checkpoint'?
		???? ???checkpoint'??(? ????? ??????? ?spectator'?)
		??? ???????? ????? HNSRU (??? ??? ????????? ???
		??????????????????CS (???? ??????? ????????? ?????? ????? CS)
		?????? /knife ? kniferound'?
		???????? /mix
		
	Version 3.5
		??????????/???????????????? (???)
		???????????????? (say /mix) ???????????????????????
		
	Version 3.5.1
		????? ????? ??? vote ?votemap ?????
		
	Version 3.6
		????????? is_user_connected ?hns ?? (???? debug)
		
	Version 3.7
		???? ???????????????

	Help search integrations plugins
		HNSRU_Hook_Integration
		HNSRU_GodMode_Integration 
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <colorchat>
#include <fun>
//#include <dhudmessage>
#include <screenfade_util.inc>
#include <sqlx>

#define hnsru_ACESS ADMIN_LEVEL_F // flag "r"
#define hnsru_PLUGIN "HNSRU Match System"
#define hnsru_VERSION "3.7.0"
#define hnsru_AUTHOR "Sideways"

/* Other */
new hnsru_prefix
new hnsru_tag[16]
new hnsru_publicModeCvar
new bool:hnsru_publicMode
/* /Other */

/* Training */
new hnsru_training
/* /Training */


/* Training CheckPoints */
new hnsru_checkpoints
new gChecks[33]
new gGoChecks[33]
new bool:gCheckpoint[33]
new gCheckpointPos[33][3]
new Float:gCheckpointAngle[33][3]
new gLastCheckpointPos[33][3]
new Float:gLastCheckpointAngle[33][3]
/* /Training CheckPoints */


/* HNSRU_Hook_Integration */
new hnsru_hook
new bool:hnsru_hooked[32]
new hookorigin[32][3]
/* /HNSRU_Hook_Integration */


/* Mix Pause */
new hnsru_cvar_pause
new bool:hnsru_paused
/* /Mix Pause */

/* Fun Mode HNS Mix */
new hnsru_fun_amxx
new bool:hnsru_funmode
/* /Fun Mode HNS Mix */


/* Mix System */
new team1_name[32]
new team1_score = 0
new team2_name[32]
new team2_score = 0
new roundcount = 0
new readycount = 0
new bool:war 
new bool:hnsru_autoscore // Aaoi auaia n?aoa ea?aue ?aoia
new bool:live
new bool:segparte
new bool:jgdrpronto[32]
new hnsru_team1name
new hnsru_team2name	
new hnsru_autorec			
new hnsru_switchround
new hnsru_roundsdraw
new hnsru_roundswin
/* /Mix System */

/* HNSRU LongJumps Stats */
new hnsru_stats_amxx
/* /HNSRU LongJumps Stats */

/* Knife Round */
new bool:hnsru_kniferound
new g_iMaxPlayers
new hnsru_kf_slash
new hnsru_kf
/* /Knife Round */


/* SemiClip */
new hnsru_semiclip
new bool:plrSolid[33]
new bool:plrRestore[33]
// new g_iMaxPlayers // O?a eniieucoaony a eiaeo ?aoiaa
new plrTeam[33]
/* /SemiClip */

/* PTS */
new StoredAuthID[2][32][64];
new StoredLeaverAuth[32][64];
new LeaversNum;
new bool:leav_reconn[32]

new Host[]     = "nemo.beget.ru"
new User[]    = "fh7906wz_hnsru"
new Pass[]     = "a_1sP.Zs_S!oiASI@91"
new Db[]     = "fh7906wz_hnsru"

new Handle:g_SqlTuple
new g_Error[512]
new iPts[33]

new g_sBuffer[4096]
new Style[] = "<meta charset=UTF-8><style>body{font-family:Arial;}img{margin-bottom:10px;}th{background:#57b9ff;color:#FFF;padding:5px;border-bottom:2px #24a4ff solid;text-align:left}td{padding:3px;border-bottom:1px #8aceff dashed}table{color:#2c75ff;background:#FFF;font-size:12px}h2,h3{color:#333;font-family:Verdana}#c{background:#F0F7E2}#r{height:10px;background:#717171}#clr{background:none;color:#575757;font-size:20px}</style>"
/* /PTS */

/* Hide'N'Seek Mode */
#define DONT_SWITCH_TEAM_SCORES
#if defined SWITCH_TEAM_SCORES
new OrpheuFunction:g_OfSwapAllPlayers
new g_pGameRules
new bool:g_bSwapTeamsOnNextRound
#endif
#if defined DONT_SWITCH_TEAM_SCORES
new hnsru_iMaxPlayers
#endif
new bool:g_bFreezePeriod
new bool:g_bLastFlash
new g_On, g_Destroy, g_FlashNum, g_SmokeNum, g_NewFlashNum, g_ScreenColor, g_NewSmokeNum, g_Switch, g_Footsteps
new g_iHostageEnt, g_iRegisterSpawn, g_szNadeMenu[ 64 ];
new g_iSpectatedId[33];
new g_msgScreenFade;
const m_pPlayer = 41;
new bool:gOnOff[33] = { true, ... };
const EXTRAOFFSET_WEAPONS = 4;
const m_flNextPrimaryAttack = 46;
const m_flNextSecondaryAttack = 47;

/* Team Auto Join */
enum
{
	TEAM_NONE = 0,
	TEAM_T,
	TEAM_CT,
	TEAM_SPEC,
	
	MAX_TEAMS
};
new const g_cTeamChars[MAX_TEAMS] =
{
	'U',
	'T',
	'C',
	'S'
};
new const g_sTeamNums[MAX_TEAMS][] =
{
	"0",
	"1",
	"2",
	"3"
};
new const g_sClassNums[MAX_TEAMS][] =
{
	"1",
	"2",
	"3",
	"4"
};

// Old Style Menus
stock const FIRST_JOIN_MSG[] =		"#Team_Select";
stock const FIRST_JOIN_MSG_SPEC[] =	"#Team_Select_Spect";
stock const INGAME_JOIN_MSG[] =		"#IG_Team_Select";
stock const INGAME_JOIN_MSG_SPEC[] =	"#IG_Team_Select_Spect";
const iMaxLen = sizeof(INGAME_JOIN_MSG_SPEC);

// New VGUI Menus
stock const VGUI_JOIN_TEAM_NUM =		2;

new g_iTeam[33];
new g_iPlayers[MAX_TEAMS];

new tjm_join_team;
new tjm_switch_team;
new tjm_class[MAX_TEAMS];
new tjm_block_change;
/* HNSRU Join */
new bool:hnsru_checkTeamJoin
/* /Team Auto Join */


/* HideNSeek */
new g_soundlist[] = "weapons/knife_deploy1.wav"

const MENU_KEYS = ( 1<<0 | 1<<1 );
new const g_szDefaultEntities[][] = {
	"func_hostage_rescue",
	"info_hostage_rescue",
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"armoury_entity",
	"monster_scentist"
}

public plugin_precache() {
	g_iRegisterSpawn = register_forward(FM_Spawn, "fwdSpawn", 1)
	#if defined SWITCH_TEAM_SCORES
	OrpheuRegisterHook(OrpheuGetFunction("InstallGameRules"), "OnInstallGameRules_Post", OrpheuHookPost)
	#endif
}

#if defined SWITCH_TEAM_SCORES
public OnInstallGameRules_Post()
{
	g_pGameRules = OrpheuGetReturn()
}
#endif

public plugin_cfg( )
{
	new iLen = charsmax( g_szNadeMenu );
	
	add( g_szNadeMenu, iLen, "\rNew nades?^n" );
	add( g_szNadeMenu, iLen, "^n\r1. \wYes" );
	add( g_szNadeMenu, iLen, "^n\r2. \wNo" );
	
	register_menucmd( register_menuid( "NadesMenu" ), MENU_KEYS, "HandleNadesMenu" );
	get_pcvar_string(hnsru_prefix, hnsru_tag, 15);
	
	/* Team Auto Join */
	set_cvar_num("mp_limitteams", 32);
	set_cvar_num("sv_restart", 1);
}

public fwdSpawn(entid) {
	static szClassName[32];
	if(pev_valid(entid)) 	{
		pev(entid, pev_classname, szClassName, 31);
		
		for(new i = 0; i < sizeof g_szDefaultEntities; i++) 		{
			if(equal(szClassName, g_szDefaultEntities[i]))			{
				engfunc(EngFunc_RemoveEntity, entid);
				break;
			}
		}
	}
}
/* /Hide'N'Seek Mode */



public plugin_init() {
	register_plugin(hnsru_PLUGIN, hnsru_VERSION, hnsru_AUTHOR)
	
	/* Mix Commands */
	register_concmd("say /start", "concmd_start", hnsru_ACESS)
	register_concmd("say /stop", "concmd_stop", hnsru_ACESS)
	register_concmd("say /score", "clcmd_score" )
	register_concmd("say /s", "clcmd_score" )
	register_concmd("say /spec", "hnsru_transfer_spec", hnsru_ACESS)
	register_concmd("say /tt", "hnsru_transfer_tt", hnsru_ACESS)
	register_concmd("say /ct", "hnsru_transfer_ct", hnsru_ACESS)
	
	/* Mode */
	register_concmd("say /pub", "hnsru_pub", hnsru_ACESS)
	register_concmd("say /def", "hnsru_pub_off", hnsru_ACESS)
	
	/* Settings Commands*/
	register_concmd("say /skill", "hnsru_skill", hnsru_ACESS )
	register_concmd("say /boost", "hnsru_boost", hnsru_ACESS )
	register_concmd("say /aa10", "hnsru_aa10", hnsru_ACESS )
	register_concmd("say /aa100", "hnsru_aa100", hnsru_ACESS )
	register_concmd("say /mr5", "hnsru_mr5", hnsru_ACESS )
	register_concmd("say /mr7", "hnsru_mr7", hnsru_ACESS )
	register_concmd("say /mr9", "hnsru_mr9", hnsru_ACESS )
	register_clcmd( "say /rr", "CmdRestartRound",  hnsru_ACESS )
	register_clcmd( "say /swap", "hnsru_swap_teams",  hnsru_ACESS)
	
	/* Knife Round Commands */
	register_clcmd( "say /kf", "CmdKnifeRound",  hnsru_ACESS )
	
	/* Training Commands */
	/* CheckPoints */
	register_clcmd("say /cp", "Checkpoint")
	register_clcmd("say cp", "Checkpoint")
	register_clcmd("say /gc", "GoCheckpoint")
	register_clcmd("say gc", "GoCheckpoint")
	register_clcmd("say /tp", "GoCheckpoint")
	register_clcmd("say tp", "GoCheckpoint")
	
	/* HNSRU_Hook_Integration */
	register_clcmd("+hook","hnsru_hook_on")
	register_clcmd("-hook","hnsru_hook_off")
	
	/* PTS */
	register_clcmd("say /pts", "Show_Top")
	register_clcmd("say /top15", "Show_Top")
	register_clcmd("say /top10", "Show_Top")
	register_clcmd("say /top", "Show_Top")
	register_clcmd("say /rank", "Show_Rank")	

	/* HideNSeek Commands */
	register_clcmd ( "say /knife", "cmdShowKnife");
	register_clcmd ( "say /showknife", "cmdShowKnife");
	register_clcmd ( "say /hideknife", "cmdShowKnife");
	
	/* Pause / UnPause */
	register_clcmd( "say /pause", "hnsru_startpause", hnsru_ACESS );
	register_clcmd( "say /live", "hnsru_unpause", hnsru_ACESS );
	
	/* Fun Mode SwapPawns */
	register_clcmd ( "say /fun", "hnsru_funmode_func", hnsru_ACESS )
	
	/* Menu Code */
	register_clcmd ( "say /mix", "hnsru_mix_menu", hnsru_ACESS )
	register_clcmd ( "say /mr", "hnsru_mr_menu", hnsru_ACESS )
	register_clcmd ( "say /aa", "hnsru_aa_menu", hnsru_ACESS )
	register_clcmd ( "say /type", "hnsru_semi_menu", hnsru_ACESS )
	register_clcmd ( "say /trans", "hnsru_trans_menu", hnsru_ACESS )
	register_clcmd ( "say /mode", "hnsru_mode_menu", hnsru_ACESS )

	/* Block Cmd Vote in console */
	register_clcmd("vote", "hnsru_block_vote_cmd")
	register_clcmd("votemap", "hnsru_block_vote_cmd")
	
	/* Pause / UnPause */
	hnsru_cvar_pause = register_cvar( "hnsru_pause", "1" )
	
	/* Other Cvars */
	hnsru_prefix = 		register_cvar( "hnsru_match_prefix", "HNSRU")
	
	/* Mix Cvars */
	hnsru_team1name = 		register_cvar("hnsru_team1", "Blue") // CT
	hnsru_team2name = 		register_cvar("hnsru_team2", "Red") // TT
	hnsru_autorec = 		register_cvar("hnsru_autorec", "1")
	hnsru_roundswin = 		register_cvar("hnsru_win", "7")	
	hnsru_roundsdraw = 		register_cvar("hnsru_draw", "6")
	hnsru_switchround = 		register_cvar("hnsru_swap", "6")
	/* Knife Round Cvars */
	hnsru_kf = 			register_cvar("hnsru_kf",  "1")
	hnsru_kf_slash = 		register_cvar("hnsru_noslash", "1")
	
	/* LongJumps Stats */
	hnsru_stats_amxx = 		register_cvar("hnsru_stats_amxx",  "1")
	
	/* Fun SwapPawns */
	hnsru_fun_amxx = 		register_cvar("hnsru_fun",  "1")
	
	/* Public Mode */
	hnsru_publicModeCvar = 		register_cvar("hnsru_public",  "1")
	
	/* SemiClip Cvar */
	hnsru_semiclip = 		register_cvar("hnsru_semiclip", "0")
	
	/* Training Cvar */
	hnsru_training = 		register_cvar("hnsru_training",  "1")
	hnsru_checkpoints =		register_cvar("hnsru_checkpoints",  "1")
	hnsru_hook =			register_cvar("hnsru_hook",  "1")
	
	/* PTS */
	register_concmd( "hnsru_givepts", "CmdGivePts", hnsru_ACESS, "<STEAMID> <AMOUNT>");
	
	/* HideNSeek Mode Cvars */
	//state initializing;
	g_On= 			register_cvar("hnsru_hns",     "1" )
	g_Footsteps = 		register_cvar("hnsru_footsteps", "1" )
	g_Switch =		register_cvar("hnsru_switch", "0")
	g_ScreenColor = 	register_cvar("hnsru_screenfade", "000000000255") // RRRGGGBBB / R=Red G=Green B=Blue A=Alpha
	g_Destroy = 		register_cvar("hnsru_destroy",     "1" )
	g_FlashNum =		register_cvar("hnsru_flash",     "2" )
	g_SmokeNum = 		register_cvar("hnsru_smoke",     "1" )
	g_NewFlashNum = 	register_cvar("hnsru_flash_add", "2")
	g_NewSmokeNum= 		register_cvar("hnsru_smoke_add", "1")

	/* Team Auto Join */
	register_event("TeamInfo", "event_TeamInfo", "a");
	register_message(get_user_msgid("ShowMenu"), "message_ShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "message_VGUIMenu");
	tjm_join_team = register_cvar("hnsru_join_team", "1");
	tjm_switch_team = register_cvar("hnsru_switch_team", "0");
	tjm_class[TEAM_T] = register_cvar("hnsru_class_t", "3");
	tjm_class[TEAM_CT] = register_cvar("hnsru_class_ct", "4");
	tjm_block_change = register_cvar("hnsru_block_change", "0");

	/* Mix Settings */
	register_event("SendAudio","event_EndRound","a","2=%!MRAD_terwin","2=%!MRAD_ctwin")
	register_event("ResetHUD", "event_ResetHud", "b")
	
	/* Mix Settings */
	register_event( "HLTV", "new_round", "a", "1=0", "2=0" )
	
	/* Knife Round Settings */
	register_clcmd( "shield", "BlockCmds" )
	register_clcmd( "cl_rebuy", "BlockCmds" )
	register_event( "CurWeapon", "EventCurWeapon", "be", "2!29" )
	register_logevent( "EventRoundEnd", 2, "0=World triggered", "1=Round_Draw", "1=Round_End" )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_knife", "HamKnifePrimAttack" )
	g_iMaxPlayers = get_maxplayers( )
	
	/* SemiClip Settings */
	register_forward(FM_PlayerPreThink, "preThink")
	register_forward(FM_PlayerPostThink, "postThink")
	register_forward(FM_AddToFullPack, "addToFullPack", 1)
	/* g_iMaxPlayers = get_maxplayers( ) (????????N?? ?? Knife Round'e)*/

	/* AutoRestart ????N????N??????N????????*/
	set_task(3.0, "hnsru_auto_restart") /* ????N?????????????????, ??N?N??????ZN??? N?????? ?????N????????? mix N???N?N???N?*/
	
	/* PTS */
	set_task(1.0, "MySql_Init") // set a task to activate the mysql_init


	/* HideNSeek mode Settings */
	register_forward(FM_EmitSound, "block_sound")
	
	//g_msgScreenFade = get_user_msgid("ScreenFade");
	//register_message( g_msgScreenFade, "msg_ScreenFade" );
	
	g_iHostageEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hostage_entity"));
	set_pev(g_iHostageEnt, pev_origin, Float:{ 0.0, 0.0, -55000.0 });
	set_pev(g_iHostageEnt, pev_size, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 });
	dllfunc(DLLFunc_Spawn, g_iHostageEnt);
	
	register_forward( FM_AddToFullPack, "fwdAddToFullPack_Post", 1 );
	register_message(get_user_msgid("Money"), "MessageMoney")
	register_event("CurWeapon", "eCurWeapon", "be", "1!0")
	register_event( "DeathMsg", "event_DeathMsg", "a" )
	register_event("HLTV", "Event_Pre_Freezetime", "a", "1=0", "2=0") // Detect freezetime started
	register_event( "SpecHealth2", "eventSpecHealth2", "bd" );
	register_logevent("Event_Post_Freezetime", 2, "0=World triggered", "1=Round_Start") // Detect freezetime ended
	register_logevent("eventRoundEnd", 2, "0=World triggered", "1=Round_Draw", "1=Round_End");
	
	RegisterHam( Ham_Spawn, "player", "CBasePlayer_Spawn_Post", true)
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_knife", "FwdKnifePrim" );
	RegisterHam( Ham_Item_Deploy, "weapon_knife", "FwdDeployKnife", 1 )
	#if defined SWITCH_TEAM_SCORES
	g_OfSwapAllPlayers = OrpheuGetFunction("SwapAllPlayers", "CHalfLifeMultiplay")
	#endif
	#if defined DONT_SWITCH_TEAM_SCORES
	hnsru_iMaxPlayers = get_maxplayers();
	#endif
	unregister_forward(FM_Spawn, g_iRegisterSpawn, 1)
	

	/* GoodMode */
	RegisterHam(Ham_Spawn, "player", "hnsru_godmode",1) //HNSRU_GodMode_Integration
	
	/* ???????????????? ????CS - DHUD ?????*/
	set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET)
}

public hnsru_block_vote_cmd(id) {
	client_print(id, print_console, "WWW.HNSRU.NET - This command is blocked")
	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	set_task(2.0,"hnsru_welcome",id+213)	// welcome to the server
	g_iSpectatedId[id] = 0			// hns mode
	Load_MySql(id) 					// PTS
	remove_hook(id) 			// hnsru_hook_int
}

public client_connect(id)
{
	gOnOff[id] = true // hns mode
}

public client_disconnect(id)
{
	Save_MySql(id) // PTS
	if(war)
	{
		if(get_user_team(id) == 1 || get_user_team(id) == 2 || leav_reconn[id])
		{
			LeaversNum++
			set_task(300.0, "MarkAsLeaver", LeaversNum+19657);
			get_user_authid(id, StoredLeaverAuth[LeaversNum], 63)
			for (new loopId = 0; loopId <= charsmax(StoredAuthID); loopId++) {
				if (equali(StoredAuthID[0][loopId],StoredLeaverAuth[LeaversNum]) == 1) {
					StoredAuthID[0][loopId] = "";		
					break
				}
				if (equali(StoredAuthID[1][loopId],StoredLeaverAuth[LeaversNum]) == 1) {
					StoredAuthID[1][loopId] = "";		
					break
				}
			}
		}
	} // PTS

	if(jgdrpronto[id]) // mix system
	{
		jgdrpronto[id] = false

		readycount--
	}
	g_iSpectatedId[id] = 0;
	
	remove_hook(id) // hnsru_hook_int
	
	if(task_exists(id+213)) // kill welcome to the server
	remove_task(id+213) // kill welcome to the server
	
	remove_task(id) // Team Auto Join
}

public hnsru_auto_restart()
{
	if(get_pcvar_num(hnsru_stats_amxx))
		server_cmd("amxx unpause hnsru_stats.amxx")
	
	if(get_pcvar_num(hnsru_fun_amxx)) {
		server_cmd("hnsru_swapspawns 0")
		server_cmd("hnsru_colored_smoke 0")
		if(!hnsru_funmode) {
			hnsru_funmode = false
			server_cmd("hnsru_swapspawns 0")
		}
	}
		
	hnsru_paused = false 
	hnsru_checkTeamJoin = false
	hnsru_publicMode = false
	
	server_cmd( "hnsru_hns 1" )
	server_cmd( "hnsru_training 1" )
	server_cmd( "hnsru_hook 1" )
	server_cmd( "hnsru_checkpoints 1" )
	server_cmd( "mp_freezetime 0" )
	server_cmd( "hnsru_footsteps 0" )
	server_cmd( "sv_alltalk 1" )
	server_cmd( "sv_restart 1" )
	server_cmd( "sv_restart 1" )
}

public hnsru_welcome(taskid)
{
	new cvar_hostname = get_cvar_pointer("hostname")
	new hostname[65]
	get_pcvar_string(cvar_hostname, hostname, 64)
	new name[32],id=taskid-213
	
	get_user_name(id,name,31)
	{
		if(hnsru_checkTeamJoin)
			hnsru_autospec(id)
			
		ColorChat(id, RED, "^1[^3%s^1] Welcome to the: ^3%s", hnsru_tag, hostname)
		ColorChat(id, RED, "^1[^3%s^1] ^4Used: ^1hns match system by ^3Sideways ^1(^4v%s ^1beta ^3Point-System^1)", hnsru_tag, hnsru_VERSION)
	}
}

public hnsru_autospec(id) 
{
	cs_set_user_team(id, CS_TEAM_SPECTATOR)
	user_kill(id, 1)

	ColorChat(id,GREY,"^1[^3%s^1] ^3Match is being started,you can not join", hnsru_tag)
	
	return PLUGIN_HANDLED
}

public hnsru_godmode(id) 
{
	if(get_pcvar_num(hnsru_training) && is_user_alive(id)) set_user_godmode(id, 1)
}



/* Pause */
/* Pause */
/* Pause */
public hnsru_hud_paused() 
{	
	if(hnsru_paused && get_pcvar_num(hnsru_cvar_pause)) 
	{
		//set_dhudmessage(0, 127, 255, -1.0, 0.60, 0, 0.1, 0.1, 10.0, 0.1)
	//	show_dhudmessage(0, "HNSRU MATCH PAUSED")
	}
}

public hnsru_hud_unpaused() 
{
	if(!hnsru_paused && get_pcvar_num(hnsru_cvar_pause))
	{
	//	set_dhudmessage(241, 58, 19, -1.0, 0.60, 0, 3.0, 5.5, 0.1, 1.0)
//show_dhudmessage(0, "LIVE LIVE LIVE")
	}
}

public hnsru_startpause(id, level, cid) 
{
	if(cmd_access(id, level, cid, 1) && get_pcvar_num(hnsru_cvar_pause) && war && !hnsru_paused)
	{	
		hnsru_paused = true
		hnsru_autoscore = false
		hnsru_checkTeamJoin = true
		
		set_task(0.1, "hnsru_hud_paused", _, _, _, "b")
		
		if(get_pcvar_num(hnsru_stats_amxx))
		server_cmd("amxx unpause hnsru_stats.amxx")
		server_cmd("sv_restart 1")
		server_cmd("mp_freezetime 0")
		server_cmd("sv_alltalk 1")
		server_cmd("hnsru_training 1")
		server_cmd("hnsru_checkpoints 1")
		server_cmd("hnsru_hook 1")
		server_cmd("hnsru_block_change 0")		
	}
	return PLUGIN_HANDLED
}

public hnsru_unpause(id, level, cid) 
{
	if(cmd_access(id, level, cid, 1) && get_pcvar_num(hnsru_cvar_pause) && war && hnsru_paused)
	{
		hnsru_paused = false
		hnsru_autoscore = true
		hnsru_checkTeamJoin = true
		
		set_task(2.0,"hnsru_hud_unpaused",777,_,_,"a",1)
		
		if(get_pcvar_num(hnsru_stats_amxx))
		server_cmd("amxx pause hnsru_stats.amxx")
		server_cmd("sv_restart 1")
		server_cmd("mp_freezetime 15")
		server_cmd("sv_alltalk 0")
		server_cmd("hnsru_training 0")
		server_cmd("hnsru_checkpoints 0")
		server_cmd("hnsru_hook 0")
		client_cmd(0,"-hook")
		server_cmd("hnsru_block_change 1")
	}
	return PLUGIN_HANDLED
}
/* /Pause */
/* /Pause */
/* /Pause */



/* DHud messages */
/* DHud messages */
/* DHud messages */
public hud_start() {
	if(war) { 
		if(!hnsru_funmode) {
		//	set_dhudmessage(84, 20, 100, -1.0, 0.60, 0, 0.0, 0.2, 0.0, 0.0)
			if(get_pcvar_num(hnsru_autorec))
			//show_dhudmessage(0, "THE MATCH WILL BE STARTED^nIN 5 SECOUNDS^nthe demo is recording")
			else
		//	show_dhudmessage(0, "THE MATCH WILL BE STARTED^nIN 5 SECOUNDS")
		} else {
		//	set_dhudmessage(34, 113, 179, -1.0, 0.60, 0, 0.0, 0.2, 0.0, 0.0)
			if(get_pcvar_num(hnsru_autorec))
			//show_dhudmessage(0, "FUN MODE ACTIVATED^nTHE MATCH WILL BE STARTED^nIN 10 SECOUNDS^nthe demo is recording")
			else
		//	show_dhudmessage(0, "FUN MODE ACTIVATED^nTHE MATCH WILL BE STARTED^nIN 10 SECOUNDS")
		}
	}
}

public hud_live() {
	//set_dhudmessage(0, 128, 0, -1.0, 0.60, 2, 0.0, 10.0, 0.15, 1.5)
	if(war)
	///show_dhudmessage(0, "LIVE LIVE LIVE^nGood Luck & Have Fun")
}

public hnsru_hud_auto_swap_message() 
{
	//set_dhudmessage(246, 74, 70, -1.0, 0.60, 0, 0.0, 0.2, 0.0, 0.0)
	if(war)
	//show_dhudmessage(0, "1ST HALF %d:%d^nSWITCHING SIDES...^n2ND HALF IN 5 SECOUND", team1_score, team2_score)
}

public hud_autoswap() {
	//set_dhudmessage(0, 128, 0, -1.0, 0.60, 2, 0.0, 10.0, 0.15, 1.5)
	if(war)
	//show_dhudmessage(0, "LIVE LIVE LIVE^n2ND HALF")
}

public hud_stopmatch() {
	//set_dhudmessage(204, 6, 5, -1.0, 0.60, 0, 0.0, 0.2, 0.0, 0.0)
	if(!war) 
	///show_dhudmessage(0, "MATCH WAS STOPPED")	
}

public hnsru_hud_finished_1_mix() {
	//set_dhudmessage(0, 107, 82, -1.0, 0.60, 2, 0.0, 10.0, 0.1, 1.5)
//show_dhudmessage(0, "MATCH FINISHED^nWINNER: %s", team1_name)
}

public hnsru_hud_finished_2_mix() {
	///set_dhudmessage(0, 107, 82, -1.0, 0.60, 2, 0.0, 10.0, 0.1, 1.5)
	show_dhudmessage(0, "MATCH FINISHED^nWINNER: %s", team2_name)
}

public hnsru_hud_draw_mix() {
	///set_dhudmessage(0, 128, 0, -1.0, 0.60, 2, 0.0, 10.0, 0.15, 1.5)
///	show_dhudmessage(0, "MATCH FINISHED^nDRAW DRAW DRAW")
}

public hnsru_hud_start_kf() {
///	set_dhudmessage(0, 128, 0, -1.0, 0.60, 0, 0.0, 0.2, 0.0, 0.0)
	if(hnsru_kniferound)
	///show_dhudmessage(0, "STARTED THE KNIFE ROUND")
}

public hnsru_hud_stopped_kf() {
	set_dhudmessage(255, 0, 0, -1.0, 0.60, 0, 3.0, 1.0, 0.1, 1.0)
	if(!hnsru_kniferound)
	show_dhudmessage(0, "KNIFE ROUND WAS STOPPED")
}

public hnsru_hud_kfwin_ct() {
	set_dhudmessage(34, 93, 255, -1.0, 0.60, 0, 3.0, 5.0, 0.1, 1.0)
	if(!hnsru_kniferound)
	show_dhudmessage(0, "KNIFE ROUND WIN COUNTER-TERRORISTS")
}

public hnsru_hud_kfwin_tt() {
	////set_dhudmessage(239, 27, 27, -1.0, 0.60, 0, 3.0, 5.0, 0.1, 1.0)
	if(!hnsru_kniferound)
	///show_dhudmessage(0, "KNIFE ROUND WIN TERRORISTS")
}
/* /DHud messages */
/* /DHud messages */
/* /DHud messages */



/* Functions set_task for DHud Messages */
/* Functions set_task for DHud Messages */
/* Functions set_task for DHud Messages */
public func_live() {
	if(war) {
		server_cmd( "sv_restart 1" )
		live = true
		hnsru_paused = false
	}
	return PLUGIN_CONTINUE
}

public hnsru_hud_func_rr () {
	if(get_pcvar_num(hnsru_stats_amxx))
		server_cmd("amxx pause hnsru_stats.amxx")
	server_cmd( "sv_restart 1" )
	server_cmd( "hnsru_hns 1" )
	server_cmd( "hnsru_footsteps 1" )
	server_cmd( "mp_freezetime 15" )
	server_cmd( "sv_alltalk 0" )
	server_cmd( "hnsru_training 0" )
	server_cmd( "hnsru_checkpoints 0" )
	server_cmd( "hnsru_hook 0" )
	server_cmd( "mp_timelimit 0" )
	server_cmd( "hnsru_block_change 1" )

	client_cmd(0,"-hook")
	set_task(5.0,"func_autoscore_launch",007,_,_,"a",1)
	live = true
	hnsru_paused = false
	hnsru_checkTeamJoin = true
	
	return PLUGIN_CONTINUE
}

public hnsru_hud_auto_swap() {
	server_cmd( "mp_freezetime 15" )
	set_task(7.0,"hnsru_hud_func_rr",666,_,_,"a",1)
	set_task(9.0,"hud_autoswap",1488,_,_,"a",1)
	set_task(5.1,"hud_remove_autoswap",666,_,_,"a",1)
}

public func_autoscore_launch() {
	hnsru_autoscore = true
}

public hud_remove_autoswap() {
	remove_task(1337)
}
/* /Functions set_task for DHud Messages */
/* /Functions set_task for DHud Messages */
/* /Functions set_task for DHud Messages */



/* Match System */
/* Match System */
/* Match System */
public hnsru_funmode_func(id, level, cid) 
{
	if(!cmd_access(id, level, cid, 0) && !segparte) return PLUGIN_HANDLED
	if(get_pcvar_num(hnsru_fun_amxx)) {
		if(!hnsru_publicMode) {
			if(!hnsru_kniferound) {
				if(!war) 
				{
					new hnsru_name[32]
					get_user_name(id, hnsru_name, 31)
					ColorChat(0,RED,"^1[^3%s^1] ^4%s ^3started the match ^1(^4Fun Mode^1)", hnsru_tag, hnsru_name ) 
					
					reniciar_dados()
					hnsru_shake()
					hnsru_funmode = true
					war = true
					hnsru_checkTeamJoin = true
					
					set_task(0.1, "hud_start", 228, _, _, "a", 50)
					set_task(6.9, "func_live", 228, _, _, "a", 1)
					set_task(9.0,"hud_live",228,_,_,"a",1)
					set_task(9.1,"func_autoscore_launch",228,_,_,"a",1)
					
					if(get_pcvar_num(hnsru_autorec)) pov_record()
					if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx pause hnsru_stats.amxx")	
				
					server_cmd("hnsru_swapspawns 1")
					server_cmd("hnsru_colored_smoke 1")
					server_cmd("hnsru_hns 1")
					server_cmd("hnsru_footsteps 1")
					server_cmd("mp_forcechasecam 2")
					server_cmd("mp_forcecamera 2")
					server_cmd("mp_freezetime 15")
					server_cmd("sv_alltalk 0")
					server_cmd("hnsru_training 0")
					server_cmd("hnsru_checkpoints 1")
					server_cmd("hnsru_hook 1")
					server_cmd("mp_timelimit 0")
					server_cmd("hnsru_block_change 1")
					client_cmd(0,"-hook")
				} else 
				ColorChat(id, RED, "^1[^3%s^1] Match is ^4already running ^1(^3say ^1/start ^3is blocked^1)", hnsru_tag)
			} else
			ColorChat(id, RED, "^1[^3%s^1] ^3Stop knife round to start match", hnsru_tag)
		} else
		ColorChat(id, RED, "^1[^3%s^1] ^3Disable public HNS mode to start a match ^1(^4say /def^1)", hnsru_tag)
	} else 
	ColorChat(id, RED, "^1[^3%s^1] FunMode^3 disabled ^1(^4hnsru_fun^3 0^1)", hnsru_tag)
		
	return PLUGIN_HANDLED
}


public concmd_start(id, level, cid) 
{
	if(!cmd_access(id, level, cid, 0) && !segparte) return PLUGIN_HANDLED
	if(!hnsru_publicMode) {
		if(!hnsru_kniferound) {
			if(!war) 
			{
				new hnsru_name[32]
				get_user_name(id, hnsru_name, 31)
				ColorChat(0,RED,"^1[^3%s^1] ^4%s ^3started the match", hnsru_tag, hnsru_name ) 
				
				reniciar_dados()
				hnsru_shake()
				war = true
				hnsru_checkTeamJoin = true
				
				set_task(0.1, "hud_start", 228, _, _, "a", 50)
				set_task(6.9, "func_live", 228, _, _, "a", 1)
				set_task(9.0,"hud_live",228,_,_,"a",1)
				set_task(9.1,"func_autoscore_launch",228,_,_,"a",1)
				
				if(get_pcvar_num(hnsru_autorec)) pov_record()
				if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx pause hnsru_stats.amxx")	
				if(get_pcvar_num(hnsru_fun_amxx)) {
					server_cmd("hnsru_swapspawns 0")
					server_cmd("hnsru_colored_smoke 0")
				}
				
				server_cmd( "hnsru_hns 1" )
				server_cmd( "hnsru_footsteps 1" )
				server_cmd("mp_forcechasecam 2")
				server_cmd("mp_forcecamera 2")
				server_cmd( "mp_freezetime 15" )
				server_cmd( "sv_alltalk 0" )
				server_cmd( "hnsru_training 0" )
				server_cmd( "hnsru_checkpoints 1" )
				server_cmd( "hnsru_hook 1" )
				server_cmd( "mp_timelimit 0" )
				server_cmd( "hnsru_block_change 1" )
				client_cmd(0,"-hook")
			} else 
			ColorChat(id, RED, "^1[^3%s^1] Match is ^4already running ^1(^3say ^1/start ^3is blocked^1)", hnsru_tag)
		} else 
		ColorChat(id, RED, "^1[^3%s^1] ^3Stop knife round to start match", hnsru_tag)
	} else 
	ColorChat(id, RED, "^1[^3%s^1] ^3Disable public HNS mode to start a match ^1(^4say /def^1)", hnsru_tag)
		
	return PLUGIN_HANDLED
}

public hnsru_shake() { 
      new all[32], all_num 
      get_players(all,all_num,"a") 
      for (new i=0;i<all_num;i++) { 

      new gmsgShake = get_user_msgid("ScreenShake") 
      message_begin(MSG_ONE, gmsgShake, {0,0,0}, all[i])
      write_short(255<< 14 ) //ammount 
      write_short(10 << 14) //lasts this long 
      write_short(250<< 14) //frequency 
      message_end() 
      } 
}

public clcmd_score(id) {
	if(!war) return PLUGIN_CONTINUE

	get_pcvar_string(hnsru_team1name, team1_name, 31)
	get_pcvar_string(hnsru_team2name, team2_name, 31)
	
	if(!hnsru_funmode) {
		if(hnsru_paused) 
		ColorChat(0,BLUE,"^1[^3%s^1] Score: ^4%s ^3%d^1:^3%d ^4%s ^1(^3MATCH PAUSED^1)", hnsru_tag, team1_name, team1_score, team2_score, team2_name)
		else 
		ColorChat(id,BLUE,"^1[^3%s^1] Score: ^4%s ^3%d^1:^3%d ^4%s ^1(^3MR%d^1)", hnsru_tag, team1_name, team1_score, team2_score, team2_name, get_pcvar_num(hnsru_roundswin))
	} 
	else {
		if(hnsru_paused) 
		ColorChat(0,BLUE,"^1[^3%s^1] ^4FunMode^1 Score: ^4%s ^3%d^1:^3%d ^4%s ^1(^3MATCH PAUSED^1)", hnsru_tag, team1_name, team1_score, team2_score, team2_name)
		else 
		ColorChat(id,BLUE,"^1[^3%s^1] ^4FunMode^1 Score: ^4%s ^3%d^1:^3%d ^4%s ^1(^3MR%d^1)", hnsru_tag, team1_name, team1_score, team2_score, team2_name, get_pcvar_num(hnsru_roundswin))
	}	
	return PLUGIN_HANDLED
}

public event_EndRound()
{
	if(!hnsru_paused) {
		get_pcvar_string(hnsru_team1name, team1_name, 31)
		get_pcvar_string(hnsru_team2name, team2_name, 31)
		
		if(live)
		{
			new numroundswin = get_pcvar_num(hnsru_roundswin)
			new numroundsdraw = get_pcvar_num(hnsru_roundsdraw)
			
			new msg[32]
			read_data(2,msg,32)
			
			if(containi(msg,"ct") != -1) 
			{
				if(segparte)
					team2_score++
				else
					team1_score++
			}
			
			else if(contain(msg,"ter") != -1) 
			{
				if(segparte)
					team1_score++
				else
					team2_score++
			}
			
			if(team1_score == numroundswin) 
			{
				ColorChat(0,RED,"^1[^3%s^1] ^4Winner: %s ^1(^3%d^1:^3%d^1)", hnsru_tag, team1_name, team1_score, team2_score)
				
				MixFinished(1) // PTS
				
				reniciar_dados()
				hnsru_autoscore = false
				live = false
				war = false
				hnsru_checkTeamJoin = false
				if(get_pcvar_num(hnsru_stats_amxx)) hnsru_funmode = false
					
				set_task(0.1,"hnsru_hud_finished_1_mix",228,_,_,"a",111)
				
				if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx unpause hnsru_stats.amxx")
				if(get_pcvar_num(hnsru_fun_amxx)) {
					server_cmd("hnsru_swapspawns 0")
					server_cmd("hnsru_colored_smoke 0")
				}
					
				server_cmd("hnsru_hns 1")
				server_cmd("hnsru_training 1")
				server_cmd("hnsru_checkpoints 1")
				server_cmd("hnsru_hook 1")
				server_cmd("mp_freezetime 0")
				server_cmd("hnsru_footsteps 0")
				server_cmd("sv_alltalk 1")
				server_cmd("sv_restart 1")
				server_cmd("mp_timelimit 40")
				server_cmd("hnsru_block_change 0")
				
				return PLUGIN_HANDLED
			}
	
			else if(team2_score == numroundswin) 
			{
				ColorChat(0,RED,"^1[^3%s^1] ^4Winner: %s ^1(^3%d^1:^3%d^1)", hnsru_tag, team2_name, team2_score, team1_score)
				
				MixFinished(2) // PTS
				
				reniciar_dados()
				hnsru_autoscore = false
				live = false
				war = false
				hnsru_checkTeamJoin = false
				if(get_pcvar_num(hnsru_stats_amxx)) hnsru_funmode = false
					
				set_task(0.1,"hnsru_hud_finished_2_mix",228,_,_,"a",111)
				
				if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx unpause hnsru_stats.amxx")
				if(get_pcvar_num(hnsru_fun_amxx)) {
					server_cmd("hnsru_swapspawns 0")
					server_cmd("hnsru_colored_smoke 0")
				}
					
				server_cmd("hnsru_hns 1")
				server_cmd("hnsru_training 1")
				server_cmd("hnsru_checkpoints 1")
				server_cmd("hnsru_hook 1")
				server_cmd("mp_freezetime 0")
				server_cmd("hnsru_footsteps 0")
				server_cmd("sv_alltalk 1")
				server_cmd("sv_restart 1")
				server_cmd("mp_timelimit 40")
				server_cmd("hnsru_block_change 0")

				return PLUGIN_HANDLED
			}
			
			else if(team1_score == numroundsdraw && team2_score == numroundsdraw)
			{
				ColorChat(0,RED,"^1[^3%s^1] ^4Draw ^1(^3%d^1:^3%d^1)", hnsru_tag, team1_score, team2_score)
				
				MixFinished(0) // PTS
				
				reniciar_dados()
				hnsru_autoscore = false
				live = false
				war = false
				hnsru_checkTeamJoin = false
				if(get_pcvar_num(hnsru_stats_amxx)) hnsru_funmode = false
					
				set_task(0.1,"hnsru_hud_draw_mix",228,_,_,"a",111)
				
				if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx unpause hnsru_stats.amxx")
				if(get_pcvar_num(hnsru_fun_amxx)) {
					server_cmd("hnsru_swapspawns 0")
					server_cmd("hnsru_colored_smoke 0")
				}
					
				server_cmd("hnsru_hns 1")
				server_cmd("hnsru_training 1")
				server_cmd("hnsru_checkpoints 1")
				server_cmd("hnsru_hook 1")
				server_cmd("mp_freezetime 0")
				server_cmd("hnsru_footsteps 0")
				server_cmd("sv_alltalk 1")
				server_cmd("sv_restart 1")
				server_cmd("mp_timelimit 40")
				server_cmd("hnsru_block_change 0")

				return PLUGIN_HANDLED
			}
			
			else 
			{
				roundcount++
				
				if(roundcount == get_pcvar_num(hnsru_switchround)) 
				{
					live = false
					hnsru_autoscore = false
					segparte = true
					
					set_task(4.4,"hnsru_hud_auto_swap",228,_,_,"a",1)
					set_task(0.1,"hnsru_hud_auto_swap_message",1337,_,_,"b")
					set_task(1.0, "trocar_equipas")
					
					ColorChat(0,GREY,"^1[^3%s^1] ^3End of first part", hnsru_tag)
					ColorChat(0,BLUE,"^1[^3%s^1] ^3Swithing sides...", hnsru_tag)
				}
			}
		}
	}
	return PLUGIN_CONTINUE
}

public reniciar_dados() 
{
	team1_score = 0
	team2_score = 0
	roundcount = 0
	segparte = false
	readycount = 0
	hnsru_autoscore = false
	for(new i; i < 32; i++)
		jgdrpronto[i] = false
}

public trocar_equipas() 
{
	new jogador[32], numjogadores, i
	
	get_players(jogador, numjogadores, "h") 
	
	for(i = 0; i < numjogadores; i++)
	{
		if(is_user_connected(jogador[i])) 
		{
			if(cs_get_user_team(jogador[i]) != CS_TEAM_SPECTATOR) 
			{
				if(cs_get_user_team(jogador[i]) == CS_TEAM_CT) 
					cs_set_user_team(jogador[i], CS_TEAM_T)
				else
					cs_set_user_team(jogador[i], CS_TEAM_CT)
			}
		}
	}
}

public pov_record() 
{
	new jogador[32], numjogadores, i
	
	get_players(jogador, numjogadores, "h")
	
	new time_date[32]
	new map_name[32]
	
	get_mapname ( map_name, 31 )
	
	get_time("%d-%m-%Y_%H-%M",time_date,31)
	
	get_pcvar_string(hnsru_team1name, team1_name, 31)
	get_pcvar_string(hnsru_team2name, team2_name, 31)
	
	for(i = 0; i < numjogadores; i++)
	{
		if(is_user_connected(jogador[i]))
		{
			if(cs_get_user_team(jogador[i]) != CS_TEAM_SPECTATOR)
			{
				new demo[256]
				
				formatex(demo, sizeof(demo), "%s_%s_vs_%s_%s_%s", hnsru_tag, team1_name, team2_name, time_date, map_name)
				
				client_cmd(jogador[i], "stop")
				
				while(replace(demo,255,"/","_")) {}
				while(replace(demo,255,"\","_")) {}
				while(replace(demo,255,":","_")) {}
				while(replace(demo,255,"*","_")) {}
				while(replace(demo,255,"?","_")) {}
				while(replace(demo,255,">","_")) {}
				while(replace(demo,255,"<","_")) {}
				while(replace(demo,255,"|","_")) {}
				
				client_cmd(jogador[i], "record ^"%s.dem.dem^"", demo)
			}
		}
	}
}
/* /Match System */
/* /Match System */
/* /Match System */


/* AutoScore */
/* AutoScore */
/* AutoScore */
public new_round() {
	if(hnsru_autoscore) {
		if(war) {
			get_pcvar_string(hnsru_team1name, team1_name, 31)
			get_pcvar_string(hnsru_team2name, team2_name, 31)
			ColorChat(0, BLUE, "^1[^3%s^1] Score: ^4%s ^3%d^1:^3%d ^4%s", hnsru_tag, team1_name, team1_score, team2_score, team2_name)
		}
	}
	return PLUGIN_CONTINUE
}
/* /AutoScore */
/* /AutoScore */
/* /AutoScore */


/* Stop Knife Round and Match (say /stop) */
/* Stop Knife Round and Match (say /stop) */
/* Stop Knife Round and Match (say /stop) */
public concmd_stop(id, level, cid) 
{
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	
	if(hnsru_kniferound) {
		if(get_pcvar_num(hnsru_kf)) {

			
			ColorChat(0,RED,"^1[^3%s^1] ^4%s ^3stopped the kniferound", hnsru_tag, hnsru_name)
			
			hnsru_kniferound = false
			hnsru_checkTeamJoin = false
			
			set_task(0.1,"hnsru_hud_stopped_kf",228,_,_,"a",50)
			
			if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx unpause hnsru_stats.amxx")
			server_cmd( "hnsru_hns 1" )
			server_cmd( "hnsru_footsteps 1" )
			server_cmd( "sv_alltalk 0" )
			server_cmd( "hnsru_training 1" )
			server_cmd( "hnsru_checkpoints 1" )
			server_cmd( "hnsru_hook 1" )
			server_cmd( "mp_freezetime 0" )
			server_cmd( "hnsru_footsteps 0" )
			server_cmd( "sv_alltalk 1" )
			server_cmd( "sv_restart 1" )
			server_cmd( "mp_timelimit 50" )
			server_cmd( "hnsru_block_change 0" )
		} 
	} 
	else 
	{
		if(war) 
		{
			ColorChat(0,RED,"^1[^3%s^1] ^4%s ^3stopped the match", hnsru_tag, hnsru_name)
			
			hnsru_paused = false
			war = false
			hnsru_autoscore = false
			hnsru_checkTeamJoin = false
			
			set_task(0.1, "hud_stopmatch", 228, _, _, "a", 111)
			
			if(hnsru_funmode) {	
				server_cmd("hnsru_swapspawns 0")
				server_cmd("hnsru_colored_smoke 0")
				hnsru_funmode = false
			}
			
			if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx unpause hnsru_stats.amxx")
			server_cmd( "hnsru_hns 1" )
			server_cmd( "sv_restart 1" )
			server_cmd( "hnsru_training 1" )
			server_cmd( "hnsru_checkpoints 1" )
			server_cmd( "hnsru_hook 1" )
			server_cmd( "mp_freezetime 0" )
			server_cmd( "hnsru_footsteps 0" )
			server_cmd( "sv_alltalk 1" )
			server_cmd( "mp_timelimit 60" )
			server_cmd( "hnsru_block_change 0" )
		} else 
			ColorChat(id, RED, "^1[^3%s^1] Match or Knife Round is ^3not running", hnsru_tag)
		}
	
	return PLUGIN_HANDLED
}
/* /Stop Knife Round and Match (say /stop) */
/* /Stop Knife Round and Match (say /stop) */
/* /Stop Knife Round and Match (say /stop) */




/* Knife Round */
/* Knife Round */
/* Knife Round */
public EventCurWeapon(id) 
{
    if( hnsru_kniferound ) engclient_cmd(id, "weapon_knife")
    return PLUGIN_CONTINUE
}

public CmdKnifeRound(id, level, cid) 
{    
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	if(!hnsru_publicMode) {
		if(get_pcvar_num(hnsru_kf)) 
		{
			if(!war) 
			{
				new hnsru_name[32]
				get_user_name(id, hnsru_name, 31)
				ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1started the ^3kniferound", hnsru_tag, hnsru_name)
	
				set_task(0.1, "hnsru_hud_start_kf" ,227, _, _, "a", 50)
				set_task(2.0, "KnifeRoundStart", id)
				remove_task(228)
				
				hnsru_checkTeamJoin = true
				
				if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx pause hnsru_stats.amxx")
				server_cmd("hnsru_hns 0")
				server_cmd("hnsru_training 0")
				server_cmd("hnsru_footsteps 0")
				server_cmd("mp_freezetime 0")
				server_cmd("sv_alltalk 0")
				server_cmd("mp_timelimit 0")
				server_cmd("mp_forcechasecam 2")
				server_cmd("mp_forcecamera 2")
				server_cmd("hnsru_block_change 1")
				server_cmd("sv_restart 1")
			}
			else {
				ColorChat(id, RED, "^1[^3%s^1] ^3Stop match to start kniferound", hnsru_tag)
			}
		}
	} else 
	ColorChat(id, RED, "^1[^3%s^1] ^3Disable public HNS mode to start a match ^1(^4say /def^1)", hnsru_tag)
		
	return PLUGIN_HANDLED
}

public KnifeRoundStart() 
{
	hnsru_kniferound = true
    
	new players[ 32 ], num
	get_players( players, num )
    
	for( new i = 0; i < num ; i++ )
	{
		new item = players[ i ]
		EventCurWeapon( item )
	}
    
	return PLUGIN_CONTINUE
}

public EventRoundEnd() 
{
	if( hnsru_kniferound && get_pcvar_num( hnsru_kf ) ) 
	{
		new players[ 32 ], num
		get_players(players, num, "ae", "TERRORIST")
		
		if(get_pcvar_num(hnsru_stats_amxx)) server_cmd("amxx unpause hnsru_stats.amxx")
		server_cmd("hnsru_hns 1")
		server_cmd("hnsru_training 1")
		server_cmd("hnsru_checkpoints 1")
		server_cmd("hnsru_hook 1")
		server_cmd("mp_freezetime 0")
		server_cmd("hnsru_footsteps 0")
		server_cmd("sv_alltalk 1")
		server_cmd("sv_restart 1")
		server_cmd("mp_timelimit 60")
		server_cmd("hnsru_block_change 0")
	
		if(!num) 
		{
			ColorChat(0, BLUE, "^1[^3%s^1] Kniferound win ^3counter-terrorists", hnsru_tag)
			set_task(1.9,"hnsru_hud_kfwin_ct",228,_,_,"a",1)
			
		}
		else
		{   
			ColorChat(0, RED, "^1[^3%s^1] Kniferound win ^3terrorists", hnsru_tag )
			set_task(1.9,"hnsru_hud_kfwin_tt",228,_,_,"a",1)
		}
	}
	hnsru_kniferound = false
	return PLUGIN_CONTINUE
}




public HamKnifePrimAttack(iEnt) {
    if(hnsru_kniferound && get_pcvar_num(hnsru_kf_slash)) 
    {
        ExecuteHamB( Ham_Weapon_SecondaryAttack, iEnt )        
        return HAM_SUPERCEDE
    }
    return HAM_IGNORED
}

public BlockCmds( ) {
    if(hnsru_kniferound) 
        return PLUGIN_HANDLED_MAIN
    
    return PLUGIN_CONTINUE
}

/* Knife Round */
/* Knife Round */
/* Knife Round */







/* Team Join Management */
/* Team Join Management */
/* Team Join Management */
public event_TeamInfo()
{
	new id = read_data(1);
	new sTeam[32], iTeam;
	read_data(2, sTeam, sizeof(sTeam) - 1);
	for(new i = 0; i < MAX_TEAMS; i++)
	{
		if(g_cTeamChars[i] == sTeam[0])
		{
			iTeam = i;
			break;
		}
	}
	
	if(g_iTeam[id] != iTeam)
	{
		g_iPlayers[g_iTeam[id]]--;
		g_iTeam[id] = iTeam;
		g_iPlayers[iTeam]++;
	}
}

public message_ShowMenu(iMsgid, iDest, id)
{
	static sMenuCode[iMaxLen];
	get_msg_arg_string(4, sMenuCode, sizeof(sMenuCode) - 1);
	if(equal(sMenuCode, FIRST_JOIN_MSG) || equal(sMenuCode, FIRST_JOIN_MSG_SPEC))
	{
		if(should_autojoin(id))
		{
			set_autojoin_task(id, iMsgid);
			return PLUGIN_HANDLED;
		}
	}
	else if(equal(sMenuCode, INGAME_JOIN_MSG) || equal(sMenuCode, INGAME_JOIN_MSG_SPEC))
	{
		if(should_autoswitch(id))
		{
			set_autoswitch_task(id, iMsgid);
			return PLUGIN_HANDLED;
		}
		else if(get_pcvar_num(tjm_block_change))
		{
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_CONTINUE;
}

public message_VGUIMenu(iMsgid, iDest, id)
{
	if(get_msg_arg_int(1) != VGUI_JOIN_TEAM_NUM)
	{
		return PLUGIN_CONTINUE;
	}
	
	if(should_autojoin(id))
	{
		set_autojoin_task(id, iMsgid);
		return PLUGIN_HANDLED;
	}
	else if(should_autoswitch(id))
	{
		set_autoswitch_task(id, iMsgid);
		return PLUGIN_HANDLED;
	}
	else if((TEAM_NONE < g_iTeam[id] < TEAM_SPEC) && get_pcvar_num(tjm_block_change))
	{
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public task_Autojoin(iParam[], id)
{
	new iTeam = get_new_team(get_pcvar_num(tjm_join_team));
	if(iTeam != -1)
	{
		handle_join(id, iParam[0], iTeam);
	}
}

public task_Autoswitch(iParam[], id)
{
	new iTeam = get_switch_team(id);
	if(iTeam != -1)
	{
		handle_join(id, iParam[0], iTeam);
	}
}

stock handle_join(id, iMsgid, iTeam)
{
	new iMsgBlock = get_msg_block(iMsgid);
	set_msg_block(iMsgid, BLOCK_SET);
	
	engclient_cmd(id, "jointeam", g_sTeamNums[iTeam]);
	
	new iClass = get_team_class(iTeam);
	if(1 <= iClass <= 4)
	{
		engclient_cmd(id, "joinclass", g_sClassNums[iClass - 1]);
	}
	set_msg_block(iMsgid, iMsgBlock);
}

stock get_new_team(iCvar)
{
	switch(iCvar)
	{
		case 1:
		{
			return TEAM_T;
		}
		case 2:
		{
			return TEAM_CT;
		}
		case 3:
		{
			return TEAM_SPEC;
		}
		case 4:
		{
			new iTCount = g_iPlayers[TEAM_T];
			new iCTCount = g_iPlayers[TEAM_CT];
			if(iTCount < iCTCount)
			{
				return TEAM_T;
			}
			else if(iTCount > iCTCount)
			{
				return TEAM_CT;
			}
			else
			{
				return random_num(TEAM_T, TEAM_CT);
			}
		}
	}
	return -1;
}

stock get_switch_team(id)
{
	new iTeam;
	
	new iTCount = g_iPlayers[TEAM_T];
	new iCTCount = g_iPlayers[TEAM_CT];
	switch(g_iTeam[id])
	{
		case TEAM_T: iTCount--;
		case TEAM_CT: iCTCount--;
	}
	if(iTCount < iCTCount)
	{
		iTeam = TEAM_T;
	}
	else if(iTCount > iCTCount)
	{
		iTeam = TEAM_CT;
	}
	else
	{
		iTeam = random_num(TEAM_T, TEAM_CT);
	}
	
	if(iTeam != g_iTeam[id])
	{
		return iTeam;
	}
	
	return -1;
}

stock get_team_class(iTeam)
{
	new iClass;
	if(TEAM_NONE < iTeam < TEAM_SPEC)
	{
		iClass = get_pcvar_num(tjm_class[iTeam]);
		if(iClass < 1 || iClass > 4)
		{
			iClass = random_num(1, 4);
		}
	}
	return iClass;
}

stock set_autojoin_task(id, iMsgid)
{
	new iParam[2];
	iParam[0] = iMsgid;
	set_task(0.1, "task_Autojoin", id, iParam, sizeof(iParam));
}

stock set_autoswitch_task(id, iMsgid)
{
	new iParam[2];
	iParam[0] = iMsgid;
	set_task(0.1, "task_Autoswitch", id, iParam, sizeof(iParam));
}

stock bool:should_autojoin(id)
{
	return ((5 > get_pcvar_num(tjm_join_team) > 0) && is_user_connected(id) && !(TEAM_NONE < g_iTeam[id] < TEAM_SPEC) && !task_exists(id));
}

stock bool:should_autoswitch(id)
{
	return (get_pcvar_num(tjm_switch_team) && is_user_connected(id) && (TEAM_NONE < g_iTeam[id] < TEAM_SPEC) && !task_exists(id));
}
/* /Team Join Management */
/* /Team Join Management */
/* /Team Join Management */



/* Check Points */
/* Check Points */
/* Check Points */
public Checkpoint(id) {
	if ( !get_pcvar_num(hnsru_training) || !get_pcvar_num(hnsru_checkpoints)) 
	{
		if((cs_get_user_team(id) == CS_TEAM_SPECTATOR))
			ColorChat(id,RED,"^1[^3%s^1] Checkpoints is ^3disabled^1 for spectators", hnsru_tag)
		else
			ColorChat(id,RED,"^1[^3%s^1] Checkpoints is ^3disabled^1", hnsru_tag)
	}
	else 
	{
		if((war && !hnsru_paused) || (!war && hnsru_paused)) return PLUGIN_HANDLED
		
		if (gCheckpoint[id]) 
		{
			gLastCheckpointPos[id][0]=gCheckpointPos[id][0]
			gLastCheckpointPos[id][1]=gCheckpointPos[id][1]
			gLastCheckpointPos[id][2]=gCheckpointPos[id][2]
			
			gLastCheckpointAngle[id][0]=gCheckpointAngle[id][0]
			gLastCheckpointAngle[id][1]=gCheckpointAngle[id][1]
			gLastCheckpointAngle[id][2]=gCheckpointAngle[id][2]
		}
		
		pev(id, pev_origin, gCheckpointPos[id])
		pev(id, pev_v_angle, gCheckpointAngle[id])
		gCheckpointPos[id][2] += 5
		gCheckpoint[id]=true
		gChecks[id]++
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public GoCheckpoint(id) 
{
	if (!get_pcvar_num(hnsru_training) || !get_pcvar_num(hnsru_checkpoints) || (cs_get_user_team(id) == CS_TEAM_SPECTATOR))
	{
		if((cs_get_user_team(id) == CS_TEAM_SPECTATOR))
			ColorChat(id,RED,"^1[^3%s^1] Checkpoints is ^3disabled^1 for spectators", hnsru_tag)
		else
			ColorChat(id,RED,"^1[^3%s^1] Training is ^3disabled^1", hnsru_tag)
	}
	else 
	{
		if((war && !hnsru_paused) || (!war && hnsru_paused)) return PLUGIN_HANDLED
		
		if (!gCheckpoint[id]) 
		{
			ColorChat(id,RED,"^1[^3%s^1] ^3You don't have a checkpoint", hnsru_tag)
			
			return PLUGIN_CONTINUE
		}
		move_to_check(id)
		gGoChecks[id]++
		
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_DUCKING)
		engfunc(EngFunc_SetSize, id, {-16, -16, -18}, {16, 16, 18})
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

stock move_to_check(id) 
{
	if((war && !hnsru_paused) || (!war && hnsru_paused)) return PLUGIN_HANDLED
	
	new vVelocity[3]
	set_pev( id, pev_velocity, vVelocity )
	
	engfunc(EngFunc_SetOrigin, id, gCheckpointPos[id])
	set_pev(id, pev_angles, gCheckpointAngle[id])
	set_pev(id, pev_fixangle, 1)
	
	return PLUGIN_CONTINUE
}
/* /Check Points */
/* /Check Points */
/* /Check Points */









/* Hook */
/* Hook */
/* Hook */
public hnsru_hook_on(id) {
	if ( get_pcvar_num(hnsru_training) == 0 || !get_pcvar_num(hnsru_hook))
		return PLUGIN_HANDLED
		
	if((cs_get_user_team(id) == CS_TEAM_SPECTATOR)) 
	{
		remove_hook(id)
	}
	else {
		if((war && !hnsru_paused) || (!war && hnsru_paused))
			return PLUGIN_HANDLED
			
	
	
		get_user_origin(id,hookorigin[id-1],3)
		
		hnsru_hooked[id-1] = true
		
		set_task(0.1,"hnsru_hook_task",id,"",0,"ab")
		hnsru_hook_task(id)
	}
	
	return PLUGIN_HANDLED
	
}

public is_hooked(id) {
	return hnsru_hooked[id-1]
}

public hnsru_hook_off(id) {
	remove_hook(id)
	
	return PLUGIN_HANDLED
}

public hnsru_hook_task(id) {
	if(!is_user_connected(id) || !is_user_alive(id))
		remove_hook(id)
	
	
	if((cs_get_user_team(id) == CS_TEAM_SPECTATOR)) 
	{
		remove_hook(id)
	}
	else {
		new origin[3], Float:velocity[3]
		get_user_origin(id,origin) 
		new distance = get_distance(hookorigin[id-1],origin)
		if(distance > 25)  { 
			velocity[0] = (hookorigin[id-1][0] - origin[0]) * (1.0 * 700 / distance)
			velocity[1] = (hookorigin[id-1][1] - origin[1]) * (1.0 * 700 / distance)
			velocity[2] = (hookorigin[id-1][2] - origin[2]) * (1.0 * 700 / distance)
			
			entity_set_vector(id,EV_VEC_velocity,velocity)
		} 
		else {
			entity_set_vector(id,EV_VEC_velocity,Float:{0.0,0.0,0.0})
			remove_hook(id)
		}
	}
}


public remove_hook(id) {
	if(task_exists(id))
		remove_task(id)
	hnsru_hooked[id-1] = false
}
/* /Hook */
/* /Hook */
/* /Hook */





/* Semiclip */
/* Semiclip */
/* Semiclip */
public addToFullPack(es, e, ent, host, hostflags, player, pSet)
{ 
	if(!get_pcvar_num(hnsru_semiclip)) {
		if(player)
		{
			if(plrSolid[host] && plrSolid[ent] && plrTeam[host] == plrTeam[ent])
			{
				set_es(es, ES_Solid, SOLID_NOT)
			}
		}
	}
}

FirstThink()
{ 
	if(!get_pcvar_num(hnsru_semiclip))
	{
		for(new i = 1; i <= g_iMaxPlayers; i++)
		{
			if(!is_user_alive(i))
			{
				plrSolid[i] = false
				continue
			}
			
			plrTeam[i] = get_user_team(i)
			plrSolid[i] = pev(i, pev_solid) == SOLID_SLIDEBOX ? true : false
		}
	}
}

public preThink(id)
{ 
	if(!get_pcvar_num(hnsru_semiclip)) 
	{
		static i, LastThink
		
		if(LastThink > id)
		{
			FirstThink()
		}
		LastThink = id
	
		
		if(!plrSolid[id]) return
		
		for(i = 1; i <= g_iMaxPlayers; i++)
		{
			if(!plrSolid[i] || id == i) continue
			
			if(plrTeam[i] == plrTeam[id])
			{
				set_pev(i, pev_solid, SOLID_NOT)
				plrRestore[i] = true
			}
		}
	}
}

public postThink(id)
{ 
	if(!get_pcvar_num(hnsru_semiclip)) {
		static i
		
		for(i = 1; i <= g_iMaxPlayers; i++)
		{
			if(plrRestore[i])
			{
				set_pev(i, pev_solid, SOLID_SLIDEBOX)
				plrRestore[i] = false
			}
		}
	}
}
/* /Semiclip */
/* /Semiclip */
/* /Semiclip */


/* Commands for management */
/* Commands for management */
/* Commands for management */
public hnsru_pub(id, level, cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	
	if(!hnsru_publicMode) {
		if(get_pcvar_num(hnsru_publicModeCvar) && !war && !hnsru_kniferound) {
			hnsru_publicMode = true
			
			server_cmd("mp_forcechasecam 0")
			server_cmd("mp_forcecamera 0")
			server_cmd("hnsru_switch 1")
			server_cmd("hnsru_footsteps 1")
			server_cmd("mp_autoteambalance 1")
			server_cmd("mp_roundtime 2.5")
			server_cmd("mp_freezetime 3")
			server_cmd("hnsru_flash 1")
			server_cmd("hnsru_join_team 4") // random
			server_cmd("hnsru_block_change 0")
			server_cmd("hnsru_training 0")
			server_cmd("hnsru_checkpoints 1")
			server_cmd("hnsru_hook 1")
			server_cmd("sv_restart 1")

			ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1activated public HNS mode", hnsru_tag, hnsru_name)
		}
	} else 
	ColorChat(id, RED, "^1[^3%s^1] ^4%s ^1Public HNS mode is ^4already running", hnsru_tag, hnsru_name)
	
	return PLUGIN_HANDLED
}

public hnsru_pub_off(id, level, cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	
	if(hnsru_publicMode) {
		if(get_pcvar_num(hnsru_publicModeCvar) && !war && !hnsru_kniferound) {
			hnsru_publicMode = false
			
			server_cmd("mp_forcechasecam 2")
			server_cmd("mp_forcecamera 2")
			server_cmd("hnsru_switch 0")
			server_cmd("hnsru_training 1")
			server_cmd("hnsru_footsteps 0")
			server_cmd("mp_roundtime 3")
			server_cmd("mp_freezetime 0")
			server_cmd("hnsru_flash 3")
			server_cmd("mp_autoteambalance 0")
			server_cmd("hnsru_join_team 1")
			server_cmd("hnsru_block_change 0")
			server_cmd("sv_restart 1")
			
			ColorChat(0, RED, "^1[^3%s^1] ^4%s ^3disabled ^1public HNS mode", hnsru_tag, hnsru_name)
		}
	} else 
	ColorChat(id, RED, "^1[^3%s^1] ^4%s ^1Public HNS mode is ^3not running", hnsru_tag, hnsru_name)
	
	return PLUGIN_HANDLED
}

public CmdRestartRound(id, level, cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^3did restart", hnsru_tag, hnsru_name)
	
	server_cmd("sv_restart 1")

	return PLUGIN_HANDLED
}

public hnsru_swap_teams(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    
	new hnsru_name[32]
	get_user_name(id, hnsru_name, charsmax(hnsru_name))
	ColorChat(0, TEAM_COLOR, "^1[^3%s^1] ^4%s ^3swap teams", hnsru_tag, hnsru_name)
    
	hnsru_SwapTeams()
	server_cmd("sv_restart 1")
	
	return PLUGIN_HANDLED
}

public hnsru_SwapTeams( ) {
	for( new i = 1; i <= g_iMaxPlayers; i++ ) {
		if( is_user_connected( i ) )
		{
			switch( cs_get_user_team( i ) )
			{
			case CS_TEAM_T: cs_set_user_team( i, CS_TEAM_CT )        
			case CS_TEAM_CT: cs_set_user_team( i, CS_TEAM_T )
			}
		}
	}
}

public hnsru_transfer_spec(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	ColorChat( 0, GREY,"^1[^3%s^1] ^4%s ^1transfered all players to ^3Spectators", hnsru_tag, hnsru_name )
	new Players[32], Num; get_players(Players, Num, "h")
       
	for(new i = 0; i < Num; i++)
	{
		if(is_user_alive(Players[i]))
		user_kill(Players[i], 0)
		if(cs_get_user_team(Players[i]) != CS_TEAM_SPECTATOR)
		cs_set_user_team(Players[i], CS_TEAM_SPECTATOR, CS_DONTCHANGE)
	}
	return PLUGIN_HANDLED
}

public hnsru_transfer_tt(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	ColorChat( 0, RED,"^1[^3%s^1] ^4%s ^1transfered all players to ^3TTs", hnsru_tag, hnsru_name )
	new Players[32], Num; get_players(Players, Num, "h")
       
	for(new i = 0; i < Num; i++)
	{
		if(is_user_alive(Players[i]))
		user_kill(Players[i], 0)
		if(cs_get_user_team(Players[i]) != CS_TEAM_T)
		cs_set_user_team(Players[i], CS_TEAM_T, CS_T_ARCTIC)
	}
       
	return PLUGIN_HANDLED
}

public hnsru_transfer_ct(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	ColorChat( 0, BLUE,"^1[^3%s^1] ^4%s ^1transfered all players to ^3CTs", hnsru_tag, hnsru_name )
	new Players[32], Num; get_players(Players, Num, "h")
       
	for(new i = 0; i < Num; i++)
	{
		if(is_user_alive(Players[i]))
		user_kill(Players[i], 0)
		if(cs_get_user_team(Players[i]) != CS_TEAM_CT)
		cs_set_user_team(Players[i], CS_TEAM_CT, CS_CT_GIGN)
	}

	return PLUGIN_HANDLED
}

public hnsru_skill(id,level,cid) {
	if(!cmd_access(id, level, cid, 1 )) return PLUGIN_HANDLED
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1changed ^3hnsru_semiclip^1 to^4 1", hnsru_tag, hnsru_name)
	
	server_cmd("hnsru_semiclip 0")
	
	return PLUGIN_HANDLED
}

public hnsru_boost(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1changed ^3hnsru_semiclip^1 to^4 0", hnsru_tag, hnsru_name)
	
	server_cmd("hnsru_semiclip 1")
	
	return PLUGIN_HANDLED
}

public hnsru_aa10(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED	
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1changed ^3sv_airaccelerate^1 to^4 10", hnsru_tag, hnsru_name)

	server_cmd("sv_airaccelerate 10")

	return PLUGIN_HANDLED
}

public hnsru_aa100(id,level,cid) {
	if(!cmd_access(id, level, cid, 1 )) return PLUGIN_HANDLED;	
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1changed ^3sv_airaccelerate^1 to^4 100", hnsru_tag, hnsru_name)
	
	server_cmd("sv_airaccelerate 100")
	
	return PLUGIN_HANDLED
}

public hnsru_mr5(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED	
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1established the ^3MR5^1 system ^4(^1rounds:^3 4^4)", hnsru_tag, hnsru_name)
	
	server_cmd( "hnsru_win 5" )
	server_cmd( "hnsru_draw 4" )
	server_cmd( "hnsru_swap 4" )
	
	return PLUGIN_HANDLED;
}

public hnsru_mr7(id,level,cid) {
	if(!cmd_access(id, level, cid, 1 ) ) return PLUGIN_HANDLED	
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1established the ^3MR7^1 system ^4(^1rounds:^3 6^4)", hnsru_tag, hnsru_name)
	
	server_cmd( "hnsru_win 7" )
	server_cmd( "hnsru_draw 6" )
	server_cmd( "hnsru_swap 6" )
	
	return PLUGIN_HANDLED
}

public hnsru_mr9(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED	
	new hnsru_name[32]
	get_user_name(id,hnsru_name, 31)
	ColorChat(0, RED, "^1[^3%s^1] ^4%s ^1established the ^3MR9^1 system ^4(^1rounds:^3 8^4)", hnsru_tag, hnsru_name)

	server_cmd( "hnsru_win 9" )
	server_cmd( "hnsru_draw 8" )
	server_cmd( "hnsru_swap 8" )

	return PLUGIN_HANDLED
}
/* Commands for management */
/* Commands for management */
/* Commands for management */





/* Menu (say /mix) */
/* Menu (say /mix) */
/* Menu (say /mix) */
public hnsru_mix_menu(id) 
{ 
	new i_Menu = menu_create("HNSRU MATCH SYSTEM", "hnsru_mix_menu_code") 
	new hnsru_pcvar_aa = get_cvar_pointer("sv_airaccelerate")
	
	// ?????? ???
	if(!war) 
	menu_additem(i_Menu, "Start match", "1", 0) 
	else 
	menu_additem(i_Menu, "\rSTOP match", "1", 0) 
	
	
	// ?????? ????
	if(!war) 
	menu_additem(i_Menu, "Start \rFun\yMode\w mix", "666", 0) 
	
	
	// ?????? ??????+ ??????
	if(!war) {
		if( hnsru_kniferound ) 
		menu_additem(i_Menu, "\rSTOP kniferound", "2", 0) 
		else 
		menu_additem(i_Menu, "Start kniferound", "2", 0) 
	}
	else {
		if(!hnsru_paused) 
		menu_additem(i_Menu, "\yPAUSE match \r(\y!\r)", "2", 0) 
		else 
		menu_additem(i_Menu, "\rUNPAUSE match \d(\ylive\d)", "2", 0) 
	 }

	 //??????
	menu_addblank(i_Menu, 0)
	 
	// ???????
	menu_additem(i_Menu, "Restart round", "4", 0) 
	
	// ????????????
	menu_additem(i_Menu, "Swap teams", "3", 0) 
	
	// ??????
	if(hnsru_publicMode)
	menu_additem(i_Menu, "Server mode: \yPublic HNS", "999", 0) 
	else {
		if(hnsru_kniferound) {
			menu_additem(i_Menu, "Server mode: \rKnife Round", "999", 0) 
		} else {
			if(war)
			menu_additem(i_Menu, "Server mode: \rMatch", "999", 0) 
			else
			menu_additem(i_Menu, "Server mode: \rTraining", "999", 0) 
		}
	}
	
	
	
	
	
	//??????
	menu_addblank(i_Menu, 0)
	
	// ????????MR
	if(get_pcvar_num(hnsru_roundswin ) == 5) 
	menu_additem(i_Menu, "RoundSystem: \r5", "5", 0) 
	if(get_pcvar_num(hnsru_roundswin ) == 7) 
	menu_additem(i_Menu, "RoundSystem: \r7", "5", 0) 
	if(get_pcvar_num(hnsru_roundswin ) == 9) 
	menu_additem(i_Menu, "RoundSystem: \r9", "5", 0) 
	
	
	// sv_airaccelerate
	if(get_pcvar_num( hnsru_pcvar_aa ) == 100) 
	menu_additem(i_Menu, "sv_airaccelerate: \r100", "6", 0) 
	if(get_pcvar_num( hnsru_pcvar_aa ) == 10) 
	menu_additem(i_Menu, "sv_airaccelerate: \r10", "6", 0) 
	
	
	// Boost / Skill
	if(get_pcvar_num(hnsru_semiclip) == 1) 
	menu_additem(i_Menu, "Game type: \rBoost", "7", 0) 
	if(get_pcvar_num(hnsru_semiclip) == 0) 
	menu_additem(i_Menu, "Game type: \rSkill", "7", 0) 
	 
	 
	// ????AmxModX ??
	menu_additem(i_Menu, "\wOpen AmxModX", "8", ADMIN_MENU) 
	
	
	// ?????? ????????????
	menu_additem(i_Menu, "\wTransferning players", "9", ADMIN_MENU) 
	
	// ????
	menu_setprop(i_Menu, MPROP_EXIT, MEXIT_ALL) 
	
	menu_display(id, i_Menu, 0) 
	
	return PLUGIN_HANDLED 
} 
/* /Menu (say /mix) */
/* /Menu (say /mix) */
/* /Menu (say /mix) */



/* Menu Functions (say /mix) */
/* Menu Functions (say /mix) */
/* Menu Functions (say /mix) */
public hnsru_mix_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 
	
	switch(i_Key) 
	{ 
		case 1: 
		{ 
			if(!war)
			client_cmd(id, "say /start")
			else 
			client_cmd(id, "say /stop")
		} 
		case 666: 
		{ 
			client_cmd(id, "say /fun")
		} 
		case 2: 
		{ 
			if(!war) {
				if( hnsru_kniferound ) 
				client_cmd(id, "say /stop")
				else 
				client_cmd(id, "say /kf")
			}
			else {
				if(!hnsru_paused) 
				client_cmd(id, "say /pause")
				else 
				client_cmd(id, "say /live")  
			}
		} 
		case 3: 
		{ 
			client_cmd(id, "say /swap")
		} 
		case 4: 
		{ 
			client_cmd(id, "say /rr")
		} 
		case 999:
		{
			client_cmd(id, "say /mode")
		}
		case 5: 
		{ 
			client_cmd(id, "say /mr")
		} 
		case 6: 
		{ 
			client_cmd(id, "say /aa")
		}
		 case 7: 
		 { 
			client_cmd(id, "say /type")
		 } 
		 case 8: 
		 { 
			client_cmd(id, "amxmodmenu") 
		 } 
		 case 9: 
		 { 
			client_cmd(id, "say /trans")
		 } 
	} 

	menu_destroy(menu) 
	return PLUGIN_HANDLED
}


public hnsru_mr_menu(id) { 
	new i_Menu = menu_create("HNSRU MR", "hnsru_mr_menu_code") 

	menu_additem(i_Menu, "mr5 \drounds: 4", "1", 0) 
	menu_additem(i_Menu, "mr7 \drounds: 6", "2", 0) 
	menu_additem(i_Menu, "mr9 \drounds: 8", "3", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "Back \dsay /mix", "4", 0)
	menu_additem(i_Menu, "Exit", "5", MPROP_EXIT, MEXIT_ALL)

	menu_setprop(i_Menu,MEXIT_ALL, 0)
	menu_display(id, i_Menu, 0) 

	return PLUGIN_HANDLED 
} 

public hnsru_mr_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /mr5")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /mr7")
		} 
		case 3: 
		{ 
			client_cmd(id, "say /mr9")
		} 
		case 4: 
		{ 
			hnsru_mix_menu(id)
		}
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hnsru_semi_menu(id) { 
	new i_Menu = menu_create("HNSRU TYPE", "hnsru_semi_menu_code") 

	menu_additem(i_Menu, "Boost \dhnsru_semiclip 0", "1", 0) 
	menu_additem(i_Menu, "Skill \dhnsru_semiclip 1", "2", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "Back \dsay /mix", "3", 0)
	menu_additem(i_Menu, "Exit", "5", MPROP_EXIT, MEXIT_ALL)

	menu_setprop(i_Menu,MEXIT_ALL, 0)
	menu_display(id, i_Menu, 0) 
	return PLUGIN_HANDLED 
}

public hnsru_semi_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	}
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{ 
		case 1: 
		{ 
			client_cmd(id, "say /boost")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /skill") 
		} 
		case 3: 
		{ 
			hnsru_mix_menu(id)
		} 
	}
	
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hnsru_aa_menu(id) { 
	new i_Menu = menu_create("HNSRU AA", "hnsru_aa_menu_code") 

	menu_additem(i_Menu, "100aa \dsv_airaccelerate 100", "1", 0) 
	menu_additem(i_Menu, "10aa \dsv_airaccelerate 10", "2", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "Back \dsay /mix", "3", 0)
	menu_additem(i_Menu, "Exit", "5", MPROP_EXIT, MEXIT_ALL)
	
	menu_setprop(i_Menu,MEXIT_ALL, 0)
	menu_display(id, i_Menu, 0) 
	return PLUGIN_HANDLED 
} 

public hnsru_aa_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /aa100")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /aa10")
		} 
		case 3: 
		{ 
			hnsru_mix_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hnsru_trans_menu(id) { 
	new i_Menu = menu_create("HNSRU TRANSFERS", "hnsru_trans_menu_code") 
	menu_additem(i_Menu, "All spectators \d(say /spec)", "1", 0) 
	menu_additem(i_Menu, "All terrorist \d(say /tt)", "2", 0) 
	menu_additem(i_Menu, "All counter-terrorist \d(say /ct)", "3", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "Back \dsay /mix", "4", 0)
	menu_additem(i_Menu, "Exit", "5", MPROP_EXIT, MEXIT_ALL)
	
	menu_setprop(i_Menu,MEXIT_ALL, 0)
	menu_display(id, i_Menu, 0) 
	return PLUGIN_HANDLED 
} 

public hnsru_trans_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{ 
		case 1: 
		{ 
			client_cmd(id, "say /spec")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /tt")
		} 
		case 3: 
		{ 
			client_cmd(id, "say /ct")
		} 
		case 4: 
		{ 
			hnsru_mix_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hnsru_mode_menu(id) { 
	new i_Menu = menu_create("HNSRU MODE", "hnsru_mode_menu_code") 

	if(hnsru_publicMode) {
	menu_additem(i_Menu, "\dPublic HNS mode \d(\rrunning\d)", "1", 0) 
	menu_additem(i_Menu, "Training + Matches", "2", 0)
	} else {
	menu_additem(i_Menu, "Public HNS mode", "1", 0) 
	menu_additem(i_Menu, "\dTraining + Matches \d(\rrunning\d)", "2", 0)
	}
	
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "Back \dsay /mix", "3", 0)
	menu_additem(i_Menu, "Exit", "5", MPROP_EXIT, MEXIT_ALL)
	
	menu_setprop(i_Menu,MEXIT_ALL, 0)
	menu_display(id, i_Menu, 0) 
	return PLUGIN_HANDLED 
} 

public hnsru_mode_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /pub")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /def")
		} 
		case 3: 
		{ 
			hnsru_mix_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}
/* /Menu Functions (say /mix) */
/* /Menu Functions (say /mix) */
/* /Menu Functions (say /mix) */












/* PTS */
/* PTS */
/* PTS */
public MySql_Init()
{
	// we tell the API that this is the information we want to connect to,
	// just not yet. basically it's like storing it in global variables
	g_SqlTuple = SQL_MakeDbTuple(Host,User,Pass,Db)
	
	// ok, we're ready to connect
	new ErrorCode,Handle:SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode,g_Error,charsmax(g_Error))
	if(SqlConnection == Empty_Handle)
		// stop the plugin with an error message
	set_fail_state(g_Error)
	
	new Handle:Queries
	// we must now prepare some random queries
	Queries = SQL_PrepareQuery(SqlConnection,"CREATE TABLE IF NOT EXISTS `gather` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `steamid` varchar(32) NOT NULL, `user_name` varchar(72) NOT NULL, `pts` INT(11) NOT NULL, `total` INT(11) NOT NULL, `win` INT(11) NOT NULL, `loss` INT(11) NOT NULL, `draw` INT(11) NOT NULL, `leav` INT(11) NOT NULL)");
	
	if(!SQL_Execute(Queries))
	{
		// if there were any problems the plugin will set itself to bad load.
		SQL_QueryError(Queries,g_Error,charsmax(g_Error))
		set_fail_state(g_Error)
		
	}
	
	// Free the querie
	SQL_FreeHandle(Queries)
	
	// you free everything with SQL_FreeHandle
	SQL_FreeHandle(SqlConnection)
}

public QueryHandle(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime)
{
	if( iFailState != TQUERY_SUCCESS )
	{
		log_amx("SQL Error #%d - %s", iErrnum, szError)
		
		
	}
	
	return PLUGIN_CONTINUE
}

public Load_MySql(id)
{
	new szSteamId[32], szTemp[512]
	get_user_authid(id, szSteamId, charsmax(szSteamId))
	
	new Data[1]
	Data[0] = id
	
	//we will now select from the table `tutorial` where the steamid match
	format(szTemp,charsmax(szTemp),"SELECT * FROM `gather` WHERE (`gather`.`steamid` = '%s')", szSteamId)
	SQL_ThreadQuery(g_SqlTuple,"register_client",szTemp,Data,1)
}

public register_client(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("Load Query failed. [%d] %s", Errcode, Error)
	}
	
	new id
	id = Data[0]
	
	if(SQL_NumResults(Query) < 1) 
	{
		//.if there are no results found
		
		new szSteamId[32], szNickName[72]
		get_user_authid(id, szSteamId, charsmax(szSteamId)) // get user's steamid
		get_user_name(id, szNickName, charsmax(szNickName))
		//  if its still pending we can't do anything with it
		if (equal(szSteamId,"ID_PENDING"))
			return PLUGIN_HANDLED
		
		new szTemp[512]
		
		// now we will insturt the values into our table.
		format(szTemp,charsmax(szTemp),"INSERT INTO `gather` ( `steamid` ,`user_name`, `pts`)VALUES ('%s','%s','500');",szSteamId,szNickName)
		iPts[id] = 500;
		SQL_ThreadQuery(g_SqlTuple,"QueryHandle",szTemp)
	} 
	else 
	{
		// if there are results found
		iPts[id]         = SQL_ReadResult(Query, 3)
	}
	
	return PLUGIN_HANDLED
}  

public Save_MySql(id)
{
	new szSteamId[32], szNickName[72], szTemp[512]
	get_user_name(id, szNickName, charsmax(szNickName))
	get_user_authid(id, szSteamId, charsmax(szSteamId)) // get user's steamid
	
	// Here we will update the user hes information in the database where the steamid matches.
	format(szTemp,charsmax(szTemp),"UPDATE `gather` SET `user_name` = '%s' WHERE `gather`.`steamid` = '%s';",szNickName, szSteamId)
	SQL_ThreadQuery(g_SqlTuple,"QueryHandle",szTemp)
} 

public Store_Players()
{
	new iPlayers[32], iNum, id;
	get_players(iPlayers, iNum, "ch")
	for(new i = 0; i < iNum; i++)
	{		
		id = iPlayers[i]
		if(get_user_team(id) == 1)
		{
			get_user_authid(id, StoredAuthID[0][id], 63);
		}
		if(get_user_team(id) == 2)
		{
			get_user_authid(id, StoredAuthID[1][id], 63);
		}
	}	
}

public client_authorized(id)
{
	Load_MySql(id)
	new authid[32]
	get_user_authid(id,authid,31)
	for (new loopId = 0; loopId <= LeaversNum; loopId++) {
		if (equali(StoredLeaverAuth[loopId],authid) == 1)
		{
			leav_reconn[id] = true;
			remove_task(LeaversNum+19657);
			LeaversNum--
			StoredLeaverAuth[loopId] = "";	
			break;
		}
	}
}

public MarkAsLeaver(tempid)
{
	new id = tempid-19657;
	new szTemp[512];
	format(szTemp,charsmax(szTemp),"UPDATE `gather` SET `pts` = `pts` - 20, `total` = `total` + 1,`leav` = `win` + 1,`loss` = `loss` + 1 WHERE `gather`.`steamid` = '%s';", StoredLeaverAuth[id])
	SQL_ThreadQuery(g_SqlTuple,"QueryHandle",szTemp)
	
}

public MixFinished(status)
{
	for( new i = 1; i <= g_iMaxPlayers; i++ ) {
		if( is_user_connected( i ) )
		{
			switch( cs_get_user_team( i ) )
			{
			case CS_TEAM_T:
			{
				switch(status)
				{
					case 0:
					{
						SetPts(i, 0)
					}
					case 1:
					{
						SetPts(i, 1)
					}
					case 2:
					{
						SetPts(i, 2)
					}
				}
			}			
			case CS_TEAM_CT:
			{
				switch(status)
				{
					case 0:
					{
						SetPts(i, 0)
					}
					case 1:
					{
						SetPts(i, 2)
					}
					case 2:
					{
						SetPts(i, 1)
					}
				}	
			}
			}
			Load_MySql(i);
		}
	}
}	

public SetPts(id, status)
{
	new authid[64]
	get_user_authid(id, authid, 63)
	new szTemp[512],Points, win, loss, draw;
	switch( status )
	{
		case 0:
		{
			Points = 3;
			draw = 1
			win = 0
			loss = 0
		}
		case 1:
		{
			Points = 6;
			loss = 0
			win = 1
			draw = 0
		}
		case 2:
		{
			Points = -3;
			loss = 1
			win = 0
			draw = 0					
		}
	}
	
	format(szTemp,charsmax(szTemp),"UPDATE `gather` SET `pts` = `pts` + %d, `total` = `total` + 1,`win` = `win` + %d,`loss` = `loss` + %d,`draw` = `draw` + %d WHERE `gather`.`steamid` = '%s'",Points,win,loss,draw, authid)
	SQL_ThreadQuery(g_SqlTuple,"QueryHandle",szTemp)
}

public Show_Top(id) {
	new Data[1]; Data[0] = id
	new szTemp[512]
	format(szTemp,charsmax(szTemp),"SELECT * FROM `gather` ORDER BY pts DESC LIMIT 0,10")
	SQL_ThreadQuery(g_SqlTuple, "Sql_Top", szTemp, Data, 1)
	
	new hnsru_name[32]
	get_user_name(id, hnsru_name, 31)
	ColorChat(0,GREY,"^1[^3HNSRU^1] ^4%s ^3reads the - say ^4/pts^3", hnsru_name)
	
	return PLUGIN_HANDLED
}
public Sql_Top(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) {
	if(FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if(FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)

	new id; id = Data[0];
	
	new rows1 = SQL_NumResults(Query)
	new aPoints[12], name1[12][64],steamid[12][64],total[12],wins[12],draws[12],loses[12],leavs[10]
	if(SQL_MoreResults(Query)) {
		for(new i=0;i<rows1;i++) {
			SQL_ReadResult(Query, 2, name1[i], 63)
			SQL_ReadResult(Query, 1, steamid[i], 63)
			aPoints[i] = SQL_ReadResult(Query, 3)
			total[i] = SQL_ReadResult(Query, 4)
			wins[i] = SQL_ReadResult(Query, 5)			
			loses[i] = SQL_ReadResult(Query, 6)
			draws[i] = SQL_ReadResult(Query, 7)
			leavs[i] = SQL_ReadResult(Query, 8)
			SQL_NextRow(Query)
		}
	}
	if(rows1>0) {
		new iLen=0;
		iLen = format(g_sBuffer[iLen], 4095, Style)
		iLen += format(g_sBuffer[iLen], 4095 - iLen, "<body><center><img src=^"http://hnsru.net/templates/sv_downloadurl/hnsru_PTS.png^" width=590/></center><table width=100%% border=0 align=center cellpadding=0 cellspacing=1>")	
		iLen += format(g_sBuffer[iLen], 4095 - iLen, "<tr><th>%s<th>%s<th>%s<th>%s<th>%s<th>%s<th>%s<th>%s<th>%s</tr>","#","Nick","PTS","TOTAL","WINS","DRAWS","LOSES","LEAVED","STEAMID")
		
		//iLen += format(g_sBuffer[iLen], 2047 - iLen, "<tr><td><td><td>(2)<td>(3)<td>(-1)<td>(-1)<td>")
		
		for(new i=0;i<rows1;i++) {
			replace_all(name1[i], 63, "&", "&amp;");
			replace_all(name1[i], 63, "<", "&lt;");
			replace_all(name1[i], 63, ">", "&gt;");

			iLen += format(g_sBuffer[iLen], 4095 - iLen, "<tr><td>%d<td><b>%s</b><td>%i<td>%i<td>%i<td>%i<td>%i<td>%i<td>%s", i + 1, name1[i], aPoints[i], total[i],wins[i],draws[i],loses[i],leavs[i],steamid[i])
		}
		show_motd(id, g_sBuffer, "HNSRU Points System")
	}	
	
	return PLUGIN_HANDLED
} 

public CmdGivePts(id, level, cid)
{
	if ( !cmd_access( id, level, cid, 3 ) )
	{
		return PLUGIN_HANDLED
	}
	
	new Arg1[ 32 ]
	new Arg2[ 6 ]
	
	read_argv( 1, Arg1, charsmax( Arg1 ) )
	read_argv( 2, Arg2, charsmax( Arg2 ) )
	
	new iPoints = str_to_num( Arg2 )
	
	new szTemp[512]
	format(szTemp,charsmax(szTemp),"UPDATE `gather` SET `pts` = `pts` + %d WHERE `gather`.`steamid` = '%s'",iPoints, Arg1)
	SQL_ThreadQuery(g_SqlTuple,"QueryHandle",szTemp)	
	
	return PLUGIN_HANDLED
}

public Show_Rank(id) {
	new Data[1]; Data[0] = id
	
	new szTemp[512]
	format(szTemp,charsmax(szTemp),"SELECT COUNT(*) FROM `gather` WHERE `pts` >= %i", iPts[id])
	SQL_ThreadQuery(g_SqlTuple, "Sql_Rank", szTemp, Data, sizeof(Data))
	
	return PLUGIN_CONTINUE
}
public Sql_Rank(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) {
	if(FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if(FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)
	
	new count = 0;
	count = SQL_ReadResult(Query,0);
	if(count == 0)
		count = 1
		
	new id
	id = Data[0]
	
	new szName[32]; get_user_name(id, szName, charsmax(szName));
	
	ColorChat(id, BLUE, "^1[^3HNSRU^1] ^4%s ^1You rank is ^3%i^1 with ^3%i points", szName, count, iPts[id])
	
	return PLUGIN_HANDLED
} 
/* PTS */
/* PTS */
/* PTS */



/* HNS MODE */
/* HNS MODE */
/* HNS MODE */
public cmdShowKnife(id)
{
	if(is_user_connected( id ))
	{
		if(hnsru_kniferound) {
			ColorChat( id, RED, "^1[^3%s^1] During the Knife Round the cmd ^3/knife^1 is disabled", hnsru_tag)
		}
		else {
			
			if( gOnOff[id] )
			{
				entity_set_string( id, EV_SZ_viewmodel, "")
				gOnOff[id] = false;
				ColorChat( id, RED, "^1[^3%s^1] Knife for terrorists is^3 hidden", hnsru_tag )
				
			}
			else
			{
				entity_set_string( id, EV_SZ_viewmodel, "models/v_knife.mdl")
				gOnOff[id] = true;
				ColorChat( id, GREEN, "^1[^3%s^1] Knife for terrorists is^4 visible", hnsru_tag)
			}
		}
	}
}

public msg_ScreenFade( iMsgId, iMsgDest, id ) <initializing, initialized>
{
	//if(war) {
	if(get_pcvar_num( g_On))
	{		
		if( get_msg_arg_int( 4 ) == 255 && get_msg_arg_int( 5 ) == 255 && get_msg_arg_int( 6 ) == 255 )
		{
			if(is_user_connected(id)) {
				if((cs_get_user_team(id) == CS_TEAM_T) || (cs_get_user_team(id) == CS_TEAM_SPECTATOR))
				{
					return PLUGIN_HANDLED;
				}	
			}
		}
	}
	//}
	return PLUGIN_CONTINUE;
}

public event_DeathMsg( )
{
	if(!get_pcvar_num( g_On))
		return
	
	new iVictim = read_data( 2 );
	
	if( get_pcvar_num( g_On ) && cs_get_user_team( iVictim ) == CS_TEAM_T )
	{
		new iPlayers[ 32 ], iNum;
		get_players( iPlayers, iNum, "ae", "TERRORIST" );
		
		if( iNum == 1 )
		{
			if(g_bLastFlash == false)
			{
				if((get_pcvar_num( g_NewFlashNum ) >= 1) || (get_pcvar_num( g_NewSmokeNum ) >= 1))
					show_menu( iPlayers[ 0 ], MENU_KEYS, g_szNadeMenu, -1, "NadesMenu" );
				g_bLastFlash = true
			}
		}
	}
}

public Event_Pre_Freezetime() {
	g_bLastFlash = false
	g_bFreezePeriod = true

	if(war)
	{
		Store_Players()
	}

	if(!get_pcvar_num( g_On))
		return
	#if defined SWITCH_TEAM_SCORES
	if( g_bSwapTeamsOnNextRound )
	{
		g_bSwapTeamsOnNextRound = false
		OrpheuCall(g_OfSwapAllPlayers, g_pGameRules)
	}
	#endif
	if(get_pcvar_num(g_Destroy))
		set_task(0.1, "TaskDestroyBreakables") // if eneity killed in previous round it will be spawn on this round so we need to wait spawn entity the move it.
	else
		TaskDestroyBreakables( )	 // just move back entities
}

public Event_Post_Freezetime() {
	new iPlayers[32], iNum, iColor[3], iAlpha
	get_players(iPlayers, iNum, "ae", "CT")
	g_bFreezePeriod = false
	for(--iNum; iNum>=0; iNum--)	{
		get_pcvar_color_alpha(g_ScreenColor, iColor, iAlpha)
		UTIL_ScreenFade(iPlayers[iNum], iColor, 2.0, _, iAlpha)
	}	
}

public eventRoundEnd()
{
	if( get_pcvar_num( g_On) )
	{
		new iPlayers[ 32 ], iNum;
		get_players(iPlayers, iNum, "ae", "TERRORIST");
		
		if(!iNum) // CT win
		{
			if( get_pcvar_num( g_Switch ) )
			{
				#if defined DONT_SWITCH_TEAM_SCORES
				for( new i = 1; i <= hnsru_iMaxPlayers; i++ )
				{
					if( is_user_connected( i ) )
					{
						switch( cs_get_user_team( i ) )
						{
							case CS_TEAM_CT: cs_set_user_team( i, CS_TEAM_T );
							case CS_TEAM_T: cs_set_user_team( i, CS_TEAM_CT );
						}
					}
				}
				#endif
				#if defined SWITCH_TEAM_SCORES
				g_bSwapTeamsOnNextRound = true
				#endif
			}
		}
	}
}

public CBasePlayer_Spawn_Post(id) {
	if (!is_user_alive(id))
	return;
	show_menu(id, 0, ""); // to prevent bugs with nades menu
	SetRole(id)
}

public FwdKnifePrim( const iPlayer )
{
	if( get_pcvar_num( g_On ))
	{
		ExecuteHamB( Ham_Weapon_SecondaryAttack, iPlayer );
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

public SetRole(id) {
	if(!get_pcvar_num(g_On))
		return
	
	new CsTeams:team = cs_get_user_team(id)
	strip_user_weapons(id)
	if( get_pcvar_num( g_Footsteps ) == 3 )
		set_user_footsteps( id, 1 );
	else
		set_user_footsteps( id, get_pcvar_num( g_Footsteps ) == _:team ? 1 : 0 );
	switch (team)
	{
		case CS_TEAM_T:
		{
			give_item(id, "weapon_knife")
			if( get_pcvar_num( g_FlashNum ) >= 1 )
			{
				give_item( id, "weapon_flashbang" );
				cs_set_user_bpammo( id, CSW_FLASHBANG, get_pcvar_num( g_FlashNum ) );
			}
			if( get_pcvar_num( g_SmokeNum ) >= 1 )
			{
				give_item( id, "weapon_smokegrenade" );
				cs_set_user_bpammo( id, CSW_SMOKEGRENADE, get_pcvar_num( g_SmokeNum ) );
			}
		}
		case CS_TEAM_CT:
		{
			give_item(id, "weapon_knife")
			if(g_bFreezePeriod) {
				if(war) {
					if(!hnsru_paused) {
						new iColor[3], iAlpha
						get_pcvar_color_alpha(g_ScreenColor, iColor, iAlpha)
						UTIL_ScreenFade(id,iColor,0.0,_,iAlpha,FFADE_OUT|FFADE_STAYOUT, true)
					}
					
				}
			}
		}
	}
}

public eCurWeapon(id) {
	if(!get_pcvar_num( g_On))
		return
	
	new CsTeams:team = cs_get_user_team(id)
	if(!g_bFreezePeriod)
		return
	if (team == CS_TEAM_T)
	cs_reset_user_maxspeed(id)
}

public cs_reset_user_maxspeed(id) {
	engfunc(EngFunc_SetClientMaxspeed, id, 250.0);
	set_pev(id, pev_maxspeed, 250.0)
	return PLUGIN_HANDLED
}

public TaskDestroyBreakables( ) {
	new iEntity = -1
	while ( ( iEntity = find_ent_by_class( iEntity, "func_breakable" ) ) ) 	{
		if( entity_get_float( iEntity , EV_FL_takedamage ) ) {
			switch(get_pcvar_num(g_Destroy))
			{
				case 0:
					entity_set_vector( iEntity, EV_VEC_origin, Float:{  0.0, 0.0, 0.0} )
				case 1:
					entity_set_vector( iEntity, EV_VEC_origin, Float:{  10000.0, 10000.0, 10000.0} )
			}
		}
	}
}

public HandleNadesMenu( iPlayer, iKey )
{
	if( !iKey )
	{
		if( get_pcvar_num( g_On ))
		{
			new clip, ammo
			if( get_pcvar_num( g_NewFlashNum ) >= 1 )
			{
				get_user_ammo(iPlayer, CSW_FLASHBANG, clip, ammo)
				if(( get_pcvar_num(g_FlashNum ) < 1 ) || ammo == 0)
				{
					give_item( iPlayer, "weapon_flashbang" );
					cs_set_user_bpammo( iPlayer, CSW_FLASHBANG, get_pcvar_num( g_NewFlashNum ) )
				}
				else
				{
					cs_set_user_bpammo( iPlayer, CSW_FLASHBANG, 0) // Prevent no pick sound bug
					give_item( iPlayer, "weapon_flashbang" )
					cs_set_user_bpammo( iPlayer, CSW_FLASHBANG, ammo+get_pcvar_num( g_NewFlashNum ) )
				}
			}
			if( get_pcvar_num( g_NewSmokeNum ) >= 1 )
			{
				get_user_ammo(iPlayer, CSW_SMOKEGRENADE, clip, ammo)
				if(( get_pcvar_num(g_SmokeNum ) < 1 ) || ammo == 0)
				{
					give_item( iPlayer, "weapon_smokegrenade" );
					cs_set_user_bpammo( iPlayer, CSW_SMOKEGRENADE, get_pcvar_num( g_NewSmokeNum ) )
				}
				else
				{
					cs_set_user_bpammo( iPlayer, CSW_SMOKEGRENADE, 0) // Prevent no pick sound bug
					give_item( iPlayer, "weapon_smokegrenade" );
					cs_set_user_bpammo( iPlayer, CSW_SMOKEGRENADE, ammo+get_pcvar_num( g_NewSmokeNum ) )
				}
			}
		}
	}
	show_menu(iPlayer, 0, "");
}

public fwdAddToFullPack_Post( es_handle, e, ent, host, hostflags, player, pset )
{
	if(g_bFreezePeriod && get_pcvar_num( g_On))
		if( player && host != ent && ent != g_iSpectatedId[host] && get_user_team(host) == 2 && get_user_team(ent) == 1 )
	{
		set_es( es_handle, ES_Origin, { 999999999.0, 999999999.0, 999999999.0 } );
		set_es( es_handle, ES_RenderMode, kRenderTransAlpha );
		set_es( es_handle, ES_RenderAmt, 0 );
		return FMRES_IGNORED;
	}
	
	return FMRES_IGNORED;
}

public MessageMoney(msgid, dest, id)
{
	set_pdata_int(id, 115, 0);
	set_msg_arg_int(1, ARG_LONG, 0);
}

public eventSpecHealth2( id )
{
	g_iSpectatedId[id] = read_data( 2 );
}


stock bool:isFlashBang2( ent )
{
	new iBits = get_pdata_int(ent, 114, 5)
	if( !iBits )
	{
		return true;
	}
	return false;
}

public FwdDeployKnife( const iEntity )
{
	if(!get_pcvar_num(g_On))
		return HAM_IGNORED;
	
	new iClient = get_pdata_cbase( iEntity, m_pPlayer, EXTRAOFFSET_WEAPONS );
	
	if( get_user_team( iClient ) == 1 )
	{
		if(!gOnOff[iClient] )
		{
			entity_set_string( iClient, EV_SZ_viewmodel, "" )
		}
		else
		{
			entity_set_string( iClient, EV_SZ_viewmodel, "models/v_knife.mdl" )
		}
		set_pdata_float( iEntity, m_flNextPrimaryAttack, 9999.0, EXTRAOFFSET_WEAPONS );
		set_pdata_float( iEntity, m_flNextSecondaryAttack, 9999.0, EXTRAOFFSET_WEAPONS );
	}
	return HAM_IGNORED;
}

public event_ResetHud(id)
{

	
}

get_pcvar_color_alpha( g_pCvar , iColor[] , &iAlpha=0 ) {
	if(war) {
		if(!hnsru_paused) {
			new szColor[13]
			if( get_pcvar_string(g_pCvar, szColor, charsmax(szColor)) != charsmax(szColor) )
			{
				abort(AMX_ERR_GENERAL, "Color cvar must be 12 chars, format ^"RRRGGGBBBAAA^"")
			}
			iColor[Red] = parse_color( szColor, 0 )
			iColor[Green] = parse_color( szColor, 3 )
			iColor[Blue] = parse_color( szColor, 6 )
			iAlpha = parse_color( szColor, 9 )
		}
	}
}

parse_color(szColor[], iStart) {
	return 100 * szColor[iStart] + 10 * szColor[iStart+1] + szColor[iStart+2] - 5328
}

public block_sound(entity, channel, const sound[]) {
        if ( equali(sound, g_soundlist) )
        return FMRES_SUPERCEDE
        else
                return FMRES_IGNORED
       
        return FMRES_IGNORED
}
#if defined _globals_included
  #endinput
#endif

#define _globals_included

#define TASK_TIMER 54345
#define HUD_PAUSE 23931

#define TASK_WAIT 12319
#define TASK_WAIT_CUP 11331
#define TASK_STARTED 13339

#define TASK_WAITCAP 13131
#define TASK_WAITLEAVECAP 15151
#define TASK_RANDOMPICK 17171

#define TASK_SURRENDER 55566

// 姣旇禌寮€濮?10 绉掔紦鍐叉湡浠诲姟
#define TASK_MATCH_BUFFER 13340

// 姣旇禌绫诲瀷閫夋嫨鑿滃崟 5 绉掕秴鏃朵换鍔?
#define TASK_SPONSOR_PICK 13341

// 闅忔満鍦板浘鍒囨崲寤惰繜浠诲姟 (鍏堟樉绀洪殢鏈虹粨鏋? 鍐嶆崲鍥?
#define TASK_RANDOMMAP 13342

// 瑙傚療鑰呮ā寮忓垵濮嬪寲寤惰繜浠诲姟 (jointeam 6 鍚庡欢杩熻缃?iuser1/iuser2, 閬垮厤琚紩鎿庤鐩?
#define TASK_SPEC_INIT 13343

// 鈽?璧炲姪妯″紡: 鑱婂ぉ妗嗗嚭鐜?璧炲姪灞€"鍗抽粯璁や负璧炲姪姣旇禌
new bool:g_bSponsorMatch;
new g_iSponsorPlayer;
// 鈽?鎸佷箙鍖栬禐鍔╂ā寮? 妫€娴嬪埌"璧炲姪灞€"鍚? 涓嬩竴鎶婃瘮璧涗粛淇濇寔璧炲姪灞€ UI
new bool:g_bPersistentSponsor;
// 鈽?鍙戣捣姣旇禌鐨勭帺瀹?(鐢ㄤ簬鑿滃崟閫夋嫨鍚庣殑缂撳啿鏈熸彁绀?
new g_iMatchStarter;
// 鈽?缂撳啿鏈熷凡瀹屾垚鏍囧織: 璧扮紦鍐叉湡(宸插埛鏂?娆″洖鍚?鍚? mix_start() 涓嶅啀閲嶅鍒锋柊鍥炲悎
new bool:g_bMatchBufferDone;
// 鈽?寮€璧涚1绉?鍒锋柊鍥炲悎"闃插惊鐜爣蹇? 姣忓満姣旇禌鍙埛鏂颁竴娆?
new bool:g_bRoundStartRefreshed;

new bool:g_bDebugMode;

new g_szCurrentPrefix[16];
new g_szBaseHostname[128];

stock update_hostname_prefix(const szPrefix[]) {
	new szHostname[128];
	get_cvar_string("hostname", szHostname, charsmax(szHostname));

	if (!g_szBaseHostname[0]) {
		copy(g_szBaseHostname, charsmax(g_szBaseHostname), szHostname);
	}

	new szOld[32];
	format(szOld, charsmax(szOld), "[%s] ", g_szCurrentPrefix);
	if (contain(szHostname, szOld) == 0) {
		new len = strlen(szOld);
		copy(szHostname, charsmax(szHostname), szHostname[len]);
	}

	if (szPrefix[0]) {
		new szNew[128];
		formatex(szNew, charsmax(szNew), "[%s] %s", szPrefix, szHostname);
		set_cvar_string("hostname", szNew);
	} else {
		set_cvar_string("hostname", szHostname);
	}

	copy(g_szCurrentPrefix, charsmax(g_szCurrentPrefix), szPrefix);
}

new g_iRegisterSpawn;
new const g_szDefaultEntities[][] = {
	"func_hostage_rescue",
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"armoury_entity",
	"monster_scentist"
}

new g_szLogPath[64];

new iBeam;
new g_sprBeam;

new g_PluginId;

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL,
	RULES_POINTSCAP,   // 鐐逛綅绉垎鍒?
	RULES_VAMP,        // 鐐逛綅鎵ｉ櫎鍒?
	RULES_ROUNDS       // 鍥炲悎鍒?
}

new NATCH_RULES:g_iCurrentRules;

enum MATCH_STATUS {
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
	MATCH_CUPKNIFE,
	MATCH_CUPPICK,
	MATCH_TEAMKNIFE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}
new MATCH_STATUS:g_iMatchStatus;

enum MODE_STATES {
	STATE_DISABLED,
	STATE_PREPARE,
	STATE_PAUSED,
	STATE_ENABLED
}
new MODE_STATES:g_eMatchState;

enum HNS_TEAM {
	HNS_TEAM_B,
	HNS_TEAM_A
}

new HNS_TEAM:g_isTeamTT;

enum _:MATCH_INFO {
	e_mTeamSize,
	e_mTeamSizeTT,
	Float:e_mWintime,
	Float:e_flSidesTime[HNS_TEAM],
	e_iSidesRounds[HNS_TEAM],
	Trie:e_tLeaveData,
	bool:e_mLeaved
};

new g_eMatchInfo[MATCH_INFO];

enum _:SurrenderData_s {
	bool:e_sStarted,
	e_sInitiator,
	Float:e_sFlDelay,
	Float:e_sFlTime
};
new g_eSurrenderData[SurrenderData_s];

new bool:g_bNoplay[MAX_PLAYERS + 1];

new Float:g_flRoundTime;

new g_iPlayerDistance;
new g_iPointsDistance;

new g_szMapName[32]
new g_iHostageEnt;

// const
new const sndDenySelect[] = "common/wpn_denyselect.wav";
new const sndUseSound[] = "buttons/blip1.wav";

enum _: Forwards {
	MATCH_START,
	MATCH_RESET_ROUND,
	MATCH_FINISH,
	MATCH_FINISH_POST,
	MATCH_CANCEL,
	MATCH_LEAVE_PLAYER,
	MATCH_JOIN_PLAYER,
	HNS_ROUND_START,
	HNS_ROUND_END,
	HNS_ROUND_FREEZEEND,
	// 鈽?v5.6.0: 姣旇禌鏆傚仠/鎭㈠浜嬩欢
	MATCH_PAUSED,
	MATCH_UNPAUSED
};

new g_hForwards[Forwards];

enum PLAYER_ROLES { 
	ROLE_SPEC = 0, 
	ROLE_CAP_A, 
	ROLE_TEAM_A, 
	ROLE_CAP_B, 
	ROLE_TEAM_B
};

enum _: PLAYER_INFO {
	PLAYER_ROLES:PLAYER_ROLE,
	bool:PLAYER_MATCH,
	bool:IS_PICK_ME,
	PLAYER_TEAM[16],
	LEAVE_IN_ROUND
};

new g_ePlayerInfo[MAX_PLAYERS + 1][PLAYER_INFO];

new g_iCaptainPick;
new g_iCaptainPickSteam[MAX_AUTHID_LENGTH];

new g_iCaptainFirst;
new g_iCaptainSecond;

new Array:g_aPlayersLoadData;

new TeamName:g_eSpecBack[MAX_PLAYERS + 1];

new g_msgMoney;

// === PointScap System Globals ===
#define TASK_POINTSCAP_DETECT  67890
#define TASK_POINTSCAP_KNIFE   67891
#define TASK_POINTSCAP_HUD     67892
#define TASK_POINTSCAP_FALLBACK 67893
#define TASK_POINTSCAP_FORCE   67894
#define TASK_POINTSCAP_ROUNDTIMER 67895
#define TASK_FREEZE            93761
#define MAX_ZONES 10

new Float:g_flPointScapDetectTime;
new Float:g_flPointScapKnifeTime;
new Float:g_flPointScapStayTime;
new Float:g_flTrainingProtect; // 姣旇禌缁撴潫鍚?5绉掍繚鎶ゆ湡锛岀姝?training鈫抪ub 鍒囨崲
new bool:g_bReGameDLLRoundFired; // ReGameDLL 閽╁瓙宸茶Е鍙戞湰鍥炲悎浜嬩欢锛孉MXX fallback 璺宠繃
new Float:g_flPointScapScore5;
new Float:g_flPointScapScore4;
new Float:g_flPointScapScore3;
new g_iPointScapKnifeBonus;
new g_iPointScapTargetScore;
new g_iPointScapVampInit;

// 鈽?鍥炲悎鍒舵ā寮?(MODE_ROUNDS)
new g_iRoundsMaxRounds = 10;
new g_iRoundsWinRounds = 6;
new g_iRoundsScoreT;
new g_iRoundsScoreCT;
new g_iRoundsTotalPlayed;
new g_iRoundsTargetScore;
new bool:g_bRoundsManual = false;
new bool:g_bRoundsSwapSides = true;  // 鈽?鍥炲悎鍒舵槸鍚﹀崐鍦烘崲杈?(榛樿true=鎹㈣竟)
new g_iPointScapDetectTime;
new g_iPointScapKnifeTime;
new g_iPointScapSoundCapture;
new g_iPointScapSoundKnife;
new g_iPointScapSoundScore;

enum _:ZONE_DATA {
	ZONE_LABEL,           // 鍖哄煙鏍囩 (0=A, 1=B, ...)
	ZONE_ENABLED,         // 鏄惁鍚敤
	Float:ZONE_MINS[3],   // 鍖哄煙鏈€灏忓潗鏍?
	Float:ZONE_MAXS[3],   // 鍖哄煙鏈€澶у潗鏍?
	ZONE_TYPE,            // 鐐逛綅绫诲瀷 (3=3浜? 4=4浜? 5=5浜?
	Float:ZONE_SCORE,     // 璇ョ偣浣嶅垎鏁?
	ZONE_CAPTURED,        // 鏄惁宸插崰棰?
	Float:ZONE_CAPTURE_TIME, // 鍗犵偣杩涘害/鍗犻鐢ㄦ椂
	ZONE_STATUS,          // 0=鏈崰, 1=宸插崰, 2=宸查攣瀹?
	ZONE_CAPTURED_TYPE,   // 3=3浜虹偣, 4=4浜虹偣, 5=5浜虹偣
	ZONE_PLAYER_COUNT,    // 鍖哄煙鍐呯帺瀹舵暟
	// Legacy fields (kept for compatibility)
	ZONE_POINT3_ENABLED,
	Float:ZONE_POINT3_MINS[3],
	Float:ZONE_POINT3_MAXS[3],
	ZONE_POINT4_ENABLED,
	Float:ZONE_POINT4_MINS[3],
	Float:ZONE_POINT4_MAXS[3],
	ZONE_POINT5_ENABLED,
	Float:ZONE_POINT5_MINS[3],
	Float:ZONE_POINT5_MAXS[3]
};

new g_eZones[MAX_ZONES][ZONE_DATA];
new g_iZoneCount;
new Float:g_flScoreA;  // Ascension: T鏂圭Н鍒?/ Vampire: 褰撳墠T鏂瑰垎鏁?
new Float:g_flScoreB;  // Ascension: CT鏂圭Н鍒?/ Vampire: 褰撳墠CT鏂瑰垎鏁?
new bool:g_bPointScapSpectatorJoin; // 鏄惁鍏佽瑙傛垬鑰呭姞鍏?
new g_iPointScapRound;  // 鐐逛綅妯″紡鍥炲悎鏁?
new bool:g_bPointScapDetectFirstRun; // 鐐逛綅妫€娴嬮娆¤繍琛屾爣璁?
new Float:g_flScorePreRound[2];      // 鈽?鍥炲悎寮€濮嬫椂鐨勫垎鏁?[A, B]锛屾殏鍋滄仮澶嶇敤
new Float:g_flLastPauseTime;             // 鈽?闃查噸澶嶆殏鍋?

// === Deserter System ===
new g_iDesertCount[MAX_PLAYERS + 1];

// === Knife ViewModel Settings ===
new bool:g_bKnifeViewModel[MAX_PLAYERS + 1];  // 姣忎釜鐜╁鏄惁鏄剧ず鍒€妯″瀷锛坱rue=鏄剧ず, false=闅愯棌锛?
new bool:g_bKnifeSkipSpec = false;  // 鈽?AI鎶ュ悕鎭㈠鏈熼棿璺宠繃瑙傛垬鎷変汉


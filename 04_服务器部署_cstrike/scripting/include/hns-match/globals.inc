#if defined _globals_included
  #endinput
#endif

#define _globals_included

#define TASK_TIMER 54345
#define HUD_PAUSE 23931
#define TASK_PAUSE_SND 23932

#define TASK_WAIT 12319
#define TASK_STARTED 13339

#define TASK_WAITCAP 13131

#define TASK_SURRENDER 55566

new bool:g_bDebugMode;

new g_PluginId;

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL,
	RULES_ROUNDS,
	RULES_POINTSCAP,
	RULES_VAMP
}

enum HNS_TEAM {
	HNS_TEAM_B,
	HNS_TEAM_A
}

new NATCH_RULES:g_iCurrentRules;
new g_iVoteRules[NATCH_RULES];
new g_iRoundsScore[HNS_TEAM];
new g_iRoundsPlayed;

new HNS_TEAM:g_isTeamTT;

enum MATCH_STATUS {
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
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

enum _:MatchInfo_s {
	e_mTeamSize,
	e_mTeamSizeTT,
	Float:e_flSidesTime[HNS_TEAM],
	e_iRoundsPlayed[HNS_TEAM],
	e_iSidesRounds[HNS_TEAM],
	e_iMatchSwapped,
	e_mLeaved,
	Float:e_mWintime,
	e_tLeaveData
};

new g_eMatchInfo[MatchInfo_s];

enum _:SurrenderData_s {
	bool:e_sStarted,
	bool:e_sInitiator,
	Float:e_sFlDelay,
	Float:e_sFlTime
};
new g_eSurrenderData[SurrenderData_s];

new bool:g_bNoplay[MAX_PLAYERS + 1];
new bool:g_bPlayersListLoaded;
new bool:g_bExternalTeamSize; // AI/外部开赛已指定队伍规模, mix_start 不要按场上人数覆盖

// 穿透覆盖: -1 跟随地图默认, 0 强制关闭, 1 强制开启队友穿透
new g_iSemiclipForceMode = -1;

new Float:g_flRoundTime;

new g_szMapName[32]
new g_iHostageEnt

new g_szBaseHostname[128];


// const
new const sndDenySelect[] = "common/wpn_denyselect.wav";
new const sndUseSound[] = "buttons/blip1.wav";
new const sndPauseTalk[] = "fvox/eighty.wav";
new const sndUnpauseAcquired[] = "fvox/acquired.wav";

enum _: Forwards {
	MATCH_START,
	MATCH_RESET_ROUND,
	MATCH_FINISH,
	MATCH_FINISH_POST,
	MATCH_JOIN_PLAYER,
	MATCH_LEAVE_PLAYER,
	MATCH_CANCEL,
	HNS_ROUND_START,
	HNS_ROUND_END,
	HNS_ROUND_FREEZEEND
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
	PLAYER_TEAM[16],
	PLAYER_SAVE_SWAP,
	LEAVE_IN_ROUND
};

new g_ePlayerInfo[MAX_PLAYERS + 1][PLAYER_INFO];

new Trie:g_PlayersLeaveData;

new bool:g_bPlayersLeaved;

new Array:g_aPlayersLoadData;

new g_szBuffer[2048];

new TeamName:g_eSpecBack[MAX_PLAYERS + 1];

new g_msgMoney;

new bool:g_bMatchBufferDone;
new bool:g_bSponsorMatch;
new bool:g_bPersistentSponsor;
new g_iSponsorPlayer;

// ==================== 比赛类型: 赞助局 / 娱乐局 / 个人局 ====================
enum HNS_MATCH_TYPE {
	MATCH_TYPE_NONE,		// 未设置
	MATCH_TYPE_SPONSOR,		// 赞助局
	MATCH_TYPE_CASUAL,		// 娱乐局
	MATCH_TYPE_RANKED		// 个人局
}
new HNS_MATCH_TYPE:g_eMatchType;

// 赞助局数据
new g_szSponsorName[33];	// 赞助玩家名字
new g_iSponsorGC;			// 本场赞助奖金 (ICGB), 比赛结束发给胜方
new bool:g_bSponsorGcSetup;	// 填完赞助者名字后正在选 GBIC
new bool:g_bGbicAwarded;		// 本场奖金是否已结算, 防止投降/结束重复发

// 正在等待玩家输入赞助者名字 (say 捕获)
new bool:g_bSponsorNameInput[MAX_PLAYERS + 1];

// 金币存储: SQL 连接是否可用 (可用走 hns_gc 表, 否则本地 vault)
new bool:g_bGcSqlConnected;

// 比赛开场加载流程
#define TASK_LOADING_BAR	24001	// 加载进度条逐格推进
#define TASK_LOADING_DONE	24002	// C4进度条走满后进入回合刷新
#define TASK_REFRESH_WAVE	24003	// 回合刷新
#define TASK_MATCH_ACTIVATE	24004	// 缓冲期结束, 正式激活比赛
#define TASK_MATCH_HUD		24005	// 开场缓冲倒计时 HUD

new bool:g_bMatchLoading;	// 正在执行开场加载流程 (进度条/回合刷新/缓冲期)
new g_iRefreshWave;			// 已执行的回合刷新次数
new g_iLoadingStep;			// 加载进度条当前步
new g_iMatchCountdown;		// 缓冲期倒计时 (秒)

// 开场加载: C4进度条7秒 → 类型HUD → 刷新4次(每5秒) → 缓冲15秒倒计时 → 激活
#define LOADING_STEPS			70		// 进度条总步数 (0.1秒/步 = 7秒)
#define LOADING_BAR_TIME		7.0		// C4进度条总时长 (秒)
#define REFRESH_WAVES			4		// 回合刷新次数
#define REFRESH_WAVE_INTERVAL	5.0		// 每次刷新间隔 (秒)
#define MATCH_ACTIVATE_DELAY	15.0	// 缓冲期 (秒)

new Float:g_flTrainingProtect;

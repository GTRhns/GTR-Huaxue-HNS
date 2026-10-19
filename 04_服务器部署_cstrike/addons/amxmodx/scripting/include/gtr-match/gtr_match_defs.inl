#if defined _gtr_match_defs_included
	#endinput
#endif
#define _gtr_match_defs_included

#define GTR_MIX_VERSION "0.2.0"
#define TASK_GTR_SETTLE 0x67747201

enum _:GTR_MODE {
	GTR_MODE_IDLE = 0,
	GTR_MODE_MIX
}

enum _:GTR_STATUS {
	GTR_STATUS_NONE = 0,
	GTR_STATUS_STARTED = 7 // align MATCH_STARTED value used by menus/AI
}

enum _:GTR_STATE {
	GTR_STATE_DISABLED = 0,
	GTR_STATE_PREPARE,
	GTR_STATE_PAUSED,
	GTR_STATE_ENABLED
}

enum _:GTR_RULES {
	GTR_RULES_MR = 0,
	GTR_RULES_TIMER,
	GTR_RULES_DUEL,
	GTR_RULES_ROUNDS
}

#define GTR_HOST_PLUGIN "HnsMatchSystem.amxx"

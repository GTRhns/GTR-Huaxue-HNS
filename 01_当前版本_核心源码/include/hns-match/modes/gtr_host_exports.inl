#if defined _gtr_host_exports_included
	#endinput
#endif
#define _gtr_host_exports_included

/*
 * Host exports for GtrMatchMix.
 * Gtr owns match decisions; this shell applies world/menu globals.
 */

public GtrHost_ApplyMixStart() {
	// Re-enter old mix_start body without recursion through Gtr.
	g_bGtrMixApplying = true;
	mix_start();
	g_bGtrMixApplying = false;
	return 1;
}

public GtrHost_ApplyMixStop() {
	g_bGtrMixApplying = true;
	mix_stop();
	g_bGtrMixApplying = false;
	return 1;
}

public GtrHost_ApplyMixPause() {
	mix_pause();
	return 1;
}

public GtrHost_ApplyMixUnpause() {
	mix_unpause();
	return 1;
}

public GtrHost_MarkPlayingPlayers() {
	markPlayingPlayersForMatch();
	return 1;
}

public GtrHost_SetExternalTeamSize(iSize, iSizeTT) {
	if (iSize < 0 || iSize > 32 || iSizeTT < 0 || iSizeTT > 32)
		return 0;
	if (iSize + iSizeTT < 1)
		return 0;

	g_eMatchInfo[e_mTeamSize] = iSize + iSizeTT;
	g_eMatchInfo[e_mTeamSizeTT] = iSizeTT;
	g_bExternalTeamSize = true;
	return 1;
}

public GtrHost_SetMatchRules(iMode) {
	if (iMode < _:RULES_MR || iMode > _:RULES_ROUNDS)
		return 0;

	g_iCurrentRules = NATCH_RULES:iMode;
	PDS_SetCell("match_rules", iMode);
	if (g_iCurrentRules == RULES_ROUNDS) {
		g_iSettings[MAXROUNDS] = 7;
	} else if (g_iCurrentRules == RULES_MR) {
		if (g_iSettings[MAXROUNDS] <= 0)
			g_iSettings[MAXROUNDS] = 6;
	} else if (g_iCurrentRules == RULES_TIMER) {
		g_eMatchInfo[e_mWintime] = hns_wintime_minutes();
	}
	return 1;
}

public GtrHost_SetSponsorName(const szName[]) {
	new szClean[33];
	copy(szClean, charsmax(szClean), szName);
	trim(szClean);
	replace_all(szClean, charsmax(szClean), "%", "");
	copy(g_szSponsorName, charsmax(g_szSponsorName), szClean);

	g_iSponsorPlayer = 0;
	if (szClean[0]) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			new szPName[32];
			get_user_name(iPlayers[i], szPName, charsmax(szPName));
			if (equali(szPName, szClean)) {
				g_iSponsorPlayer = iPlayers[i];
				if (g_iSponsorGC < 5)
					g_iSponsorGC = clamp(hns_gc_get_player(iPlayers[i]), 5, 20);
				break;
			}
		}
		g_bPersistentSponsor = true;
	}
	return 1;
}

public GtrHost_SetSponsorGC(iGC) {
	if (iGC < 5) iGC = 5;
	if (iGC > 20) iGC = 20;
	iGC = (iGC / 5) * 5;
	if (iGC < 5) iGC = 5;
	g_iSponsorGC = iGC;
	return 1;
}

public GtrHost_PrepareExternalMatch(bool:bSponsor, iStarter) {
	g_eMatchType = bSponsor ? MATCH_TYPE_SPONSOR : MATCH_TYPE_CASUAL;
	g_bSponsorMatch = bSponsor;
	g_iSponsorPlayer = iStarter;

	new iAiRules;
	if (PDS_GetCell("ai_match_rules", iAiRules) && iAiRules >= _:RULES_MR && iAiRules <= _:RULES_ROUNDS) {
		g_iCurrentRules = NATCH_RULES:iAiRules;
		PDS_SetCell("match_rules", iAiRules);
		if (g_iCurrentRules == RULES_ROUNDS)
			g_iSettings[MAXROUNDS] = 7;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "h");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		new TeamName:iTeam = getUserTeam(id);
		if (iTeam == TEAM_TERRORIST || iTeam == TEAM_CT) {
			g_ePlayerInfo[id][PLAYER_MATCH] = true;
			copy(g_ePlayerInfo[id][PLAYER_TEAM], charsmax(g_ePlayerInfo[][PLAYER_TEAM]), iTeam == TEAM_TERRORIST ? "TERRORIST" : "CT");
		}
	}
	return 1;
}

public GtrHost_GetMode() {
	return g_iCurrentMode;
}

public GtrHost_GetStatus() {
	return _:g_iMatchStatus;
}

public GtrHost_GetState() {
	return _:g_eMatchState;
}

public GtrHost_GetRules() {
	return _:g_iCurrentRules;
}

public GtrHost_GetPlayerMatchTeam(id) {
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return 0;
	switch (g_ePlayerInfo[id][PLAYER_ROLE]) {
		case ROLE_CAP_A, ROLE_TEAM_A: return 1;
		case ROLE_CAP_B, ROLE_TEAM_B: return 2;
	}
	return 0;
}

public GtrHost_EnterLobby() {
	if (g_iCurrentMode != MODE_TRAINING)
		return 0;
	lobby_start();
	return 1;
}

public GtrHost_FireMatchStarted() {
	ExecuteForward(g_hForwards[MATCH_START], _);
	return 1;
}

public GtrHost_FireMatchCanceled() {
	ExecuteForward(g_hForwards[MATCH_CANCEL], _);
	return 1;
}

public GtrHost_FireMatchFinished(iWinTeam) {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);
	return 1;
}

#if defined _hns_matchsystem_included
	#endinput
#endif
#define _hns_matchsystem_included

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

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

enum MATCH_STATUS
{
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
	MATCH_TEAMKNIFE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}

enum MODE_STATES
{
    STATE_DISABLED,
    STATE_PREPARE,
    STATE_PAUSED,
    STATE_ENABLED
}

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL,
	RULES_ROUNDS
}

/*
* Gets the system prefix.
*
* @param szPrefix   Buffer to copy prefix to
* @param iLen Maximum buffer size
*
* @noreturn
*/
native hns_get_prefix(szPrefix[], iLen);

/*
* 
*
* 
* 
*
* 
*/
native hns_get_flag_watcher();

/*
* 
*
* 
* 
*
* 
*/
native hns_get_flag_fullwatcher();

/*
* 
*
* 
* 
*
* 
*/
native hns_get_flag_admin();

/*
* Gets mode system.
*
* @return enum HNS_MODES
*/
native hns_get_mode();

/*
* Set mode system.
*
* @noreturn
*/
native hns_set_mode(iMode);

/*
* 进入比赛前公共模式 (MODE_LOBBY)。仅当当前为训练模式时生效,
* 且该模式只能由比赛流程激活, 任何指令/菜单都调不出来。
*
* @return 1 成功进入大厅, 0 无效(当前不是训练模式)
*/
native hns_ai_enter_lobby();

native hns_external_set_team_size(iSize, iSizeTT);
native hns_external_set_match_mode(iMode);
native hns_external_set_sponsor_name(const szName[]);
native hns_external_set_sponsor_gc(iGC);
native hns_begin_external_match(bool:bSponsor, iStarter);

/*
* Gets match status.
*
* @return type MATCH_STATUS
*/
native MATCH_STATUS:hns_get_status();

/*
* Gets match state
*
* @return type MODE_STATES
*/
native MODE_STATES:hns_get_state();

native hns_match_pause(id);
native hns_match_unpause(id);

/*
* Gets match rules
*
* @return type NATCH_RULES
*/
native NATCH_RULES:hns_get_rules();
native TeamName:hns_get_match_team_cs(iMatchTeam);
native hns_get_player_match_team(id);

/* 
* Gets score in match (For RULES_DUEL)
*
* @return type Score TT

native hns_get_score_tt();

* Gets score in match (For RULES_DUEL)
*
* @return type Score CT

native hns_get_score_ct(); */

/*
* Called when the match play begins.
*
* @noreturn
*/
forward hns_match_started();

/*
* Called when a match round is reset.
*
* @noreturn
*/
forward hns_match_reset_round();

/*
* Called, the match is canceled.
*
* @noreturn
*/
forward hns_match_canceled();

/*
* Called when the match is over.
*
* @param iWinTeam The winning team
*				1 - TT
*				1 - CT
* @noreturn
*/
forward hns_match_finished(iWinTeam);

forward hns_round_start();

forward hns_round_freezeend();

forward hns_round_end();

stock RegisterSayCmd(const szCmd[], const szShort[], const szFunc[], flags = -1, szInfo[] = "") {
	new szTemp[65], szInfoLang[65];
	format(szInfoLang, 64, "%L", LANG_SERVER, szInfo);

	format(szTemp, 64, "say /%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say /%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	return 1;
}

stock bool:isUserWatcher(id) {
	if (get_user_flags(id) & hns_get_flag_watcher())
		return true;
	else
		return false;
}

stock bool:isUserFullWatcher(id) {
	if (get_user_flags(id) & hns_get_flag_fullwatcher())
		return true;
	else
		return false;
}

stock bool:isUserVip(id) {
	return isUserFullWatcher(id);
}

stock bool:isUserAdmin(id) {
	if (get_user_flags(id) & hns_get_flag_admin())
		return true;
	else
		return false;
}
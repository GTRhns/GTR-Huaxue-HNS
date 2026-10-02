stock moveToSpec(id) {
	if (is_user_alive(id))
		user_silentkill(id);

	if (getUserTeam(id) != TEAM_SPECTATOR)
		rg_set_user_team(id, TEAM_SPECTATOR);

	closeGameMenu(id);
}

stock moveToTeam(id, TeamName:iTeam) {
	if (is_user_alive(id))
		user_silentkill(id);

	rg_set_user_team(id, iTeam, MODEL_AUTO);
	closeGameMenu(id);
}

stock closeGameMenu(id) {
	if (!is_user_connected(id))
		return;

	show_menu(id, 0, "", 1);
	set_member(id, m_iMenu, Menu_OFF);
}

stock reopenActiveVoteMenu(id) {
	if (!g_bVoteActive || !is_user_connected(id) || isFakeOrBot(id))
		return;

	if (g_eVoteKind == VOTE_MAP)
		showMapVoteMenu(id);
	else if (g_eVoteKind == VOTE_POOL)
		showPoolVoteMenu(id);
	else if (g_eVoteKind == VOTE_RULES)
		showVoteMenu(id);
}


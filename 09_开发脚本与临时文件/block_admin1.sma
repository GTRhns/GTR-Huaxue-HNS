stock getEffectiveTeamSize() {
	new iSize;
	new iAvail = (g_iSignupCount + 1) / 2;
	if (iAvail < 1)
		iAvail = 1;

	if (g_iTeamSizeFixed > 0)
		iSize = g_iTeamSizeFixed;
	else if (g_iSignupCount >= SIGNUP_MIN)
		iSize = clamp(g_iSignupCount / 2, 3, 6);
	else if (g_bForceStart)
		iSize = iAvail;
	else
		iSize = 5;

	if ((g_bForceStart || g_iSignupCount >= SIGNUP_MIN) && iSize > iAvail)
		iSize = iAvail;

	if (g_bForceStart) {
		if (iSize < 1)
			iSize = 1;
	} else if (iSize < 3) {
		iSize = 3;
	}

	return iSize;
}

stock bool:isFakeOrBot(id) {
	if (!is_user_connected(id))
		return false;
	if (is_user_bot(id))
		return true;
	if (get_entvar(id, var_flags) & FL_FAKECLIENT)
		return true;

	new szAuth[32];
	get_user_authid(id, szAuth, charsmax(szAuth));
	if (containi(szAuth, "BOT") != -1)
		return true;
	return false;
}

stock bool:isUserVipOrAdmin(id) {
	if (!is_user_connected(id) || isFakeOrBot(id))
		return false;

	return isUserWatcher(id) || isUserAdmin(id) || is_user_admin(id);
}

stock bool:isAdminOnline() {
	for (new i = 1; i <= MaxClients; i++) {
		if (isUserVipOrAdmin(i))
			return true;
	}
	return false;
}

stock getFirstVipOrAdmin() {
	for (new i = 1; i <= MaxClients; i++) {
		if (isUserVipOrAdmin(i))
			return i;
	}
	return 0;
}

stock bool:showSetupToAdmins() {
	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		showSetupMenu(i);
		bShown = true;
	}
	return bShown;
}


	if (g_eState == SIGNUP_SETUP) {
		closeGameMenu(id);
		if (isUserVipOrAdmin(id)) {
			showSetupMenu(id);
			return PLUGIN_HANDLED;
		}
		if (g_bVoteActive) {
			reopenActiveVoteMenu(id);
			return PLUGIN_HANDLED;
		}
		ai_print(id, "管理员正在选择比赛模式/地图, 请稍候");
		return PLUGIN_HANDLED;
	}


enum _:HNS_MODES
{
	MODE_TRAINING,
	MODE_LOBBY, // 比赛前公共模式: 比赛流程专用, 任何指令/函数/菜单都调不出来
	MODE_KNIFE,
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_MIX
}
new g_iCurrentMode; 

enum _:MODE_FUNCS
{
	MODEFUNC_START,
	MODEFUNC_PAUSE,
	MODEFUNC_UNPAUSE,
	MODEFUNC_END,
	MODEFUNC_ROUNDSTART,
	MODEFUNC_ROUNDEND,
	MODEFUNC_FREEZEEND,
	MODEFUNC_KILL,
	MODEFUNC_RESTARTROUND,
	MODEFUNC_SWAP,
	MODEFUNC_PLAYER_JOIN,
	MODEFUNC_PLAYER_LEAVE,
	MODEFUNC_FALLDAMAGE
};

new g_ModFuncs[HNS_MODES][MODE_FUNCS];

public InitGameModes() {
	mix_init();
	kniferound_init();
	pub_init();
	dm_init();
	zm_init();
	mode_init();
	trainingmode_init();
	lobby_init();
}

public set_cvars_mode(iMode) {
	new szPath[128];
	get_configsdir(szPath, 127);
	format(szPath, 127, "%s/mixsystem/mode", szPath);

	switch (iMode) {
		case MODE_TRAINING: server_cmd("exec %s/training.cfg", szPath);
		case MODE_LOBBY: server_cmd("exec %s/training.cfg", szPath); // 大厅复用训练玩法配置
		case MODE_KNIFE: server_cmd("exec %s/knife.cfg", szPath);
		case MODE_PUB: server_cmd("exec %s/public.cfg", szPath);
		case MODE_DM: server_cmd("exec %s/deathmatch.cfg", szPath);
		case MODE_MIX: server_cmd("exec %s/match.cfg", szPath);
		case MODE_ZM: server_cmd("exec %s/zombie.cfg", szPath);
	}

	// 立即执行排队的 exec: 让 mode cfg 先生效
	// (否则 server_cmd 排队的 exec 会在帧末执行,
	//  覆盖后续 loadMapCFG() 从 maps.ini 设置的 mp_freezetime)
	server_exec();
	set_cvar_num("mp_flashlight", 1);
}

stock set_pause_settings() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ac");
	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		rg_remove_all_items(iPlayer);
		rg_give_item(iPlayer, "weapon_knife");
		setUserGodmode(iPlayer, true);
		rg_reset_maxspeed(iPlayer);
	}

	set_task(1.0, "taskHudPaused", .id = HUD_PAUSE, .flags = "b");
	remove_task(TASK_PAUSE_SND);
	set_task(0.4, "taskPlayPauseSound", TASK_PAUSE_SND);

	server_cmd("sv_alltalk 1");
}

stock set_unpause_settings() {
	if(task_exists(HUD_PAUSE)) {
		remove_task(HUD_PAUSE);
	}
	remove_task(TASK_PAUSE_SND);

	set_task(1.0, "taskHudUnpaused");
	play_sound_all(sndUnpauseAcquired);
	server_cmd("sv_alltalk 3");
}

public taskPlayPauseSound() {
	if (g_eMatchState != STATE_PAUSED)
		return;

	play_sound_all(sndPauseTalk);
}

stock play_sound_all(const szSample[]) {
	new szSpk[64];
	copy(szSpk, charsmax(szSpk), szSample);
	replace(szSpk, charsmax(szSpk), ".wav", "");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		if (!is_user_connected(iPlayers[i]))
			continue;
		client_cmd(iPlayers[i], "spk %s", szSpk);
	}
}

public taskHudPaused() {
	if (g_eMatchState == STATE_PAUSED)
		showLangDhud(0, "HUD_PAUSE", "比赛暂停", 255, 255, 255, 1.0);
}

public taskHudUnpaused() {
	showLangDhud(0, "HUD_UNPAUSE", "比赛继续^n开始！开始！开始！", 255, 255, 255, 3.0);
}
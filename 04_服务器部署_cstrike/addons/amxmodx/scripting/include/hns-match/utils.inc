#if defined _utils_included
  #endinput
#endif

#define _utils_included

enum {
	SEMICLIP_ON,
	SEMICLIP_OFF
}

stock hns_restart_round(Float:delay = 0.5) {
	// 不传英文 "Round Restarted", 避免引擎再往聊天框打一条英文
	rg_round_end(delay, WINSTATUS_DRAW, ROUND_END_DRAW, "", "none");

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_RESTARTROUND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_RESTARTROUND], _);
}

stock hns_swap_teams() {
	g_eMatchState = STATE_PREPARE;

	rg_swap_all_players();

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_SWAP])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_SWAP], _);
}

stock chat_print(const id, const message[], any:...) {
	new msgFormated[191];

	// %l 在 vformat 里走全局翻译目标, 默认是 amx_language (多为 en)。
	// 全服广播必须按每个玩家自己的 lang (/lang) 翻译, 否则中文玩家会看到英文。
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			SetGlobalTransTarget(iPlayers[i]);
			vformat(msgFormated, charsmax(msgFormated), message, 3);
			chat_print_send(iPlayers[i], msgFormated);
		}
		SetGlobalTransTarget(LANG_SERVER);
		return;
	}

	SetGlobalTransTarget(id);
	vformat(msgFormated, charsmax(msgFormated), message, 3);
	chat_print_send(id, msgFormated);
}

stock chat_print_send(const id, const msgFormated[]) {
	if (msgFormated[0] == '[')
		client_print_color(id, print_team_blue, "%s", msgFormated);
	else if (!g_iSettings[PREFIX][0])
		client_print_color(id, print_team_blue, "%s", msgFormated);
	else
		client_print_color(id, print_team_blue, "[^3%s^1] %s", g_iSettings[PREFIX], msgFormated);
}

stock chat_lang_print(const id, const szKey[], const szFallback[], any:...) {
	new szFmt[191], szOut[191];
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			hns_lang_get(iPlayers[i], szKey, szFmt, charsmax(szFmt), szFallback);
			vformat(szOut, charsmax(szOut), szFmt, 4);
			chat_print_send(iPlayers[i], szOut);
		}
		return;
	}

	hns_lang_get(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, charsmax(szOut), szFmt, 4);
	chat_print_send(id, szOut);
}

stock get_match_type_name(id, szOut[], iLen) {
	switch (g_eMatchType) {
		case MATCH_TYPE_SPONSOR: hns_lang_get(id, "MATCH_TYPE_NAME_SPONSOR", szOut, iLen, "赞助");
		case MATCH_TYPE_CASUAL: hns_lang_get(id, "MATCH_TYPE_NAME_CASUAL", szOut, iLen, "娱乐");
		case MATCH_TYPE_RANKED: hns_lang_get(id, "MATCH_TYPE_NAME_RANKED", szOut, iLen, "个人");
		default: hns_lang_get(id, "MATCH_TYPE_NAME_UNKNOWN", szOut, iLen, "未知");
	}
}

stock get_match_rule_name(id, szOut[], iLen) {
	switch (g_iCurrentRules) {
		case RULES_MR: hns_lang_get(id, "STATUS_RULE_MR", szOut, iLen, "MR");
		case RULES_TIMER: hns_lang_get(id, "STATUS_RULE_TIMER", szOut, iLen, "Wintime");
		case RULES_DUEL: hns_lang_get(id, "STATUS_RULE_DUEL", szOut, iLen, "Duel");
		case RULES_ROUNDS: hns_lang_get(id, "STATUS_RULE_ROUNDS", szOut, iLen, "回合制");
		case RULES_POINTSCAP: hns_lang_get(id, "STATUS_RULE_POINTSCAP", szOut, iLen, "积分上限");
		case RULES_VAMP: hns_lang_get(id, "STATUS_RULE_VAMP", szOut, iLen, "吸血");
		default: hns_lang_get(id, "STATUS_RULE_ROUNDS", szOut, iLen, "回合制");
	}
}

stock print_match_start_chat() {
	new iTT, iCT, iOnline;
	get_match_side_counts(iTT, iCT);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	iOnline = iNum;

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		new szType[16], szRules[16], szFmt[191], szOut[191];
		get_match_type_name(id, szType, charsmax(szType));
		get_match_rule_name(id, szRules, charsmax(szRules));

		hns_lang_get(id, "MATCH_CHAT_FORMAT", szFmt, charsmax(szFmt), "本场对阵: ^3%dv%d^1");
		formatex(szOut, charsmax(szOut), szFmt, iTT, iCT);
		chat_print_send(id, szOut);

		hns_lang_get(id, "MATCH_CHAT_INFO", szFmt, charsmax(szFmt), "类型: ^4%s局^1  |  规则: ^3%s^1  |  地图: ^4%s");
		formatex(szOut, charsmax(szOut), szFmt, szType, szRules, g_szMapName);
		chat_print_send(id, szOut);

		hns_lang_get(id, "MATCH_CHAT_PLAYERS", szFmt, charsmax(szFmt), "人数: T ^3%d^1  |  CT ^3%d^1  |  在线 ^4%d");
		formatex(szOut, charsmax(szOut), szFmt, iTT, iCT, iOnline);
		chat_print_send(id, szOut);

		hns_lang_get(id, "MATCH_CHAT_READY", szFmt, charsmax(szFmt), "比赛即将开始, ^3祝你好运^1!");
		chat_print_send(id, szFmt);
	}
}

stock print_match_format_chat(id = 0) {
	new iTT, iCT;
	get_match_side_counts(iTT, iCT);
	chat_lang_print(id, "MATCH_CHAT_ANNOUNCE", "当前对阵: ^3%dv%d^1  |  T ^3%d^1  |  CT ^3%d^1", iTT, iCT, iTT, iCT);
}

stock hns_team_semiclip_plugin() {
	new iPlugin = find_plugin_byfile("team-semiclip.amxx");
	if (iPlugin == -1)
		iPlugin = find_plugin_byfile("hns_semiclip.amxx");
	return iPlugin;
}

stock bool:hns_team_semiclip_call(const szFunc[], iArg = 0, bool:bPush = true) {
	new iPlugin = hns_team_semiclip_plugin();
	if (iPlugin == -1)
		return false;

	new iFunc = get_func_id(szFunc, iPlugin);
	if (iFunc == -1)
		return false;

	callfunc_begin_i(iFunc, iPlugin);
	if (bPush)
		callfunc_push_int(iArg);
	callfunc_end();
	return true;
}

stock set_semiclip(opt, bool:enemy = false) {
	#pragma unused enemy
	// 只用 team-semiclip，永远只穿队友，不走 Rulzy 全员穿透。
	if (!hns_team_semiclip_call("HnsSemiclipApply", opt == SEMICLIP_ON ? 1 : 0)) {
		set_cvar_num("semiclip_enabled", opt == SEMICLIP_ON ? 1 : 0);
		set_cvar_num("semiclip_teamclip", 1);
	}
}

stock apply_hns_semiclip() {
	new iMenuMode = 0;
	if (g_iSemiclipForceMode == 1)
		iMenuMode = 1;
	else if (g_iSemiclipForceMode == 0)
		iMenuMode = 2;

	if (!hns_semiclip_menu_set(iMenuMode)) {
		if (g_iSemiclipForceMode == 0)
			set_semiclip(SEMICLIP_OFF);
		else
			set_semiclip((g_iSemiclipForceMode == 1 || !g_iSettings[HNSBOOST]) ? SEMICLIP_ON : SEMICLIP_OFF);
	}
}

stock bool:hns_semiclip_menu_set(iMode) {
	return hns_team_semiclip_call("HnsSemiclipMenuSet", iMode);
}

stock hns_semiclip_menu_get_mode() {
	new iPlugin = hns_team_semiclip_plugin();
	if (iPlugin == -1)
		return 0;

	new iFunc = get_func_id("HnsSemiclipMenuGetMode", iPlugin);
	if (iFunc == -1)
		return 0;

	callfunc_begin_i(iFunc, iPlugin);
	return callfunc_end();
}

stock bool:hns_semiclip_menu_get_enabled() {
	new iPlugin = hns_team_semiclip_plugin();
	if (iPlugin == -1)
		return false;

	new iFunc = get_func_id("HnsSemiclipMenuGetEnabled", iPlugin);
	if (iFunc == -1)
		return false;

	callfunc_begin_i(iFunc, iPlugin);
	return bool:callfunc_end();
}

stock fnConvertTime(Float:time, convert_time[], len, bool:with_intpart = true) {
	new szTemp[24];
	new Float:flSeconds = time, iMinutes;

	iMinutes = floatround(flSeconds / 60.0, floatround_floor);
	flSeconds -= iMinutes * 60.0;
	new intpart = floatround(flSeconds, floatround_floor);
	new Float:decpart = (flSeconds - intpart) * 100.0;

	if (with_intpart) {
		intpart = floatround(decpart);
		formatex(szTemp, charsmax(szTemp), "%02i:%02.0f.%d", iMinutes, flSeconds, intpart);
	} else {
		formatex(szTemp, charsmax(szTemp), "%02i:%02.0f", iMinutes, flSeconds);
	}

	formatex(convert_time, len, "%s", szTemp);

	return PLUGIN_HANDLED;
}

// hns_language.txt 里的 ^n/^1/^3 是字面字符, 显示前转成真正的换行和聊天颜色
stock hns_lang_unescape(szText[], iLen) {
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock hns_lang_get(id, const szKey[], szOut[], iLen, const szFallback[]) {
	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0])
		copy(szOut, iLen, szFallback);
	hns_lang_unescape(szOut, iLen);
}

// 按每个玩家 /lang 取词, 不要用 setTaskHud(0) 否则全员同一句英文
stock showLangDhud(id, const szKey[], const szFallback[], Red, Green, Blue, Float:HoldTime) {
	showLangDhudFmt(id, 0.0, Red, Green, Blue, HoldTime, szKey, szFallback);
}

// 全员广播也按每人自己的 /lang 格式化, 可带延迟和参数
stock showLangDhudFmt(id, Float:Delay, Red, Green, Blue, Float:HoldTime, const szKey[], const szFallback[], any:...) {
	new iPlayers[MAX_PLAYERS], iNum;
	if (id) {
		iPlayers[0] = id;
		iNum = 1;
	} else {
		get_players(iPlayers, iNum, "ch");
	}

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		if (!is_user_connected(iPlayer))
			continue;

		new szFmt[128], szText[128];
		hns_lang_get(iPlayer, szKey, szFmt, charsmax(szFmt), szFallback);
		vformat(szText, charsmax(szText), szFmt, 9);
		setTaskHud(iPlayer, Delay, 1, Red, Green, Blue, HoldTime, "%s", szText);
	}
}

stock chat_print_lang(const id, const szKey[], const szFallback[], any:...) {
	new iPlayers[MAX_PLAYERS], iNum;
	if (id) {
		iPlayers[0] = id;
		iNum = 1;
	} else {
		get_players(iPlayers, iNum, "ch");
	}

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		new szFmt[191], szMsg[191];
		hns_lang_get(iPlayer, szKey, szFmt, charsmax(szFmt), szFallback);
		vformat(szMsg, charsmax(szMsg), szFmt, 4);
		chat_print_send(iPlayer, szMsg);
	}
}

stock setTaskHud(id, Float:Time, Dhud, Red, Green, Blue, Float:HoldTime, const Text[], any: ...) {
	new szMessage[128]; vformat(szMessage, charsmax(szMessage), Text, 9);
	new szArgs[7];
	szArgs[0] = id;
	szArgs[1] = encodeText(szMessage);
	szArgs[2] = Red;
	szArgs[3] = Green;
	szArgs[4] = Blue;
	szArgs[5] = Dhud;
	szArgs[6] = _:HoldTime;
	if (Time > 0.0)
		set_task(Time, "taskHudMessage", 89000 + id, szArgs, 7);
	else
		taskHudMessage(szArgs);
}

public taskHudMessage(Params[]) {
	new id, Text[128], RRR, GGG, BBB, dhud, Float:HoldTime;
	id = Params[0];
	decodeText(Params[1], Text, charsmax(Text));
	RRR = Params[2];
	GGG = Params[3];
	BBB = Params[4];
	dhud = Params[5];
	HoldTime = Float:Params[6];
	if (!id || is_user_connected(id)) {
		if (dhud) {
			set_dhudmessage(RRR, GGG, BBB, -1.0, 0.16, 0, 0.0, HoldTime, 0.1, 0.1);
			show_dhudmessage(id, Text);
		} else {
			set_hudmessage(RRR, GGG, BBB, -1.0, 0.16, 0, 0.0, HoldTime, 0.1, 0.1, -1);
			show_hudmessage(id, Text);
		}
	}
}

stock encodeText(const text[]) {
	return engfunc(EngFunc_AllocString, text);
}

stock decodeText(const text, string[], const length) {
	global_get(glb_pStringBase, text, string, length);
}

stock loadMapCFG() {
	if (hnsmatch_maps_load_settings()) {
		return;
	}

	new szPath[128];
	get_configsdir(szPath, 127);
	format(szPath, 127, "%s/mixsystem", szPath);
	if (!dir_exists(szPath))
		mkdir(szPath);

	format(szPath, 127, "%s/mapcfg/%s.cfg", szPath, g_szMapName);

	if (file_exists(szPath)) {
		server_cmd("exec %s", szPath);
	} else {
		if (g_iSettings[HNSBOOST]) {
			set_cvar_num("mp_freezetime", 15);
			set_cvar_float("mp_roundtime", 3.5);
			g_iSettings[FLASH] = 3;
			g_iSettings[SMOKE] = 1;
		} else {
			set_cvar_num("mp_freezetime", 5);
			set_cvar_float("mp_roundtime", 2.5);
			g_iSettings[FLASH] = 1;
			g_iSettings[SMOKE] = 1;
		}
	}
}

stock bool:hns_is_knife_map() {
	return hnsmatch_maps_is_knife();
}

stock update_hostname_prefix(const szPrefix[]) {
	if (!g_szBaseHostname[0])
		get_cvar_string("hostname", g_szBaseHostname, charsmax(g_szBaseHostname));

	strip_mix_hostname_prefix(g_szBaseHostname, charsmax(g_szBaseHostname));

	if (szPrefix[0])
		set_cvar_string("hostname", fmt("[%s] %s", szPrefix, g_szBaseHostname));
	else
		set_cvar_string("hostname", g_szBaseHostname);
}

stock strip_mix_hostname_prefix(szName[], iLen) {
	while (szName[0] == '['
		&& (szName[1] == 'M' || szName[1] == 'm')
		&& (szName[2] == 'I' || szName[2] == 'i')
		&& (szName[3] == 'X' || szName[3] == 'x')
		&& szName[4] == ']')
	{
		new iStart = 5;
		if (szName[iStart] == ' ')
			iStart++;

		new szTmp[128];
		copy(szTmp, charsmax(szTmp), szName[iStart]);
		copy(szName, iLen, szTmp);
	}
}

// 比赛开始语音播报: 逐玩家按自己 /lang 选择的语言播放
//  文件: sound/match/start_<类型>_<语言>.wav (sponsor/casual/ranked, cn/tw/en/ru)
//  tw 无独立播报, 归入 cn; 玩家语言文件缺失时按 cn→en→ru 顺序兜底
stock play_match_start_sound() {
	new szType[8];
	switch (g_eMatchType) {
		case MATCH_TYPE_SPONSOR:	copy(szType, charsmax(szType), "sponsor");
		case MATCH_TYPE_CASUAL:		copy(szType, charsmax(szType), "casual");
		case MATCH_TYPE_RANKED:		copy(szType, charsmax(szType), "ranked");
		default: {
			client_cmd(0, "spk fvox/activated.wav");
			return;
		}
	}

	new iPlayers[MAX_PLAYERS], iNum, i;
	get_players(iPlayers, iNum, "ch");
	for (i = 0; i < iNum; i++) {
		new szLang[4], szPath[96];
		switch (HnsLang_GetPlayer(iPlayers[i])) {
			case HNS_LANG_EN:		copy(szLang, charsmax(szLang), "en");
			case HNS_LANG_RU:		copy(szLang, charsmax(szLang), "ru");
			default:				copy(szLang, charsmax(szLang), "cn");	// 含 tw
		}

		// 玩家语言文件缺失时兜底: cn → en → ru
		static const szFallback[][4] = { "cn", "en", "ru" };
		new j, bPlayed;
		for (j = 0; j < sizeof(szFallback); j++) {
			if (j > 0 && equal(szLang, szFallback[j - 1]))
				continue;	// 跳过与玩家语言重复的兜底

			formatex(szPath, charsmax(szPath), "sound/match/start_%s_%s.wav", szType, j == 0 ? szLang : szFallback[j]);
			if (file_exists(szPath)) {
				client_cmd(iPlayers[i], "spk %s", szPath);
				bPlayed = true;
				break;
			}
		}
		if (!bPlayed)
		client_cmd(iPlayers[i], "spk sound/match/start_%s_cn.wav", szType);	// 文件缺失, 静默失败不影响流程
	}
}

// 报名即将结束语音播报: 逐玩家按语言播放
//  文件: sound/match/regclose_<场景>_<语言>.wav (vote=玩家投票 / admin=管理员选择, cn/en/ru)
//  语言文件缺失时按 cn→en→ru 顺序兜底, 全部缺失静默失败
stock play_regclose_sound(const szScene[]) {
	new iPlayers[MAX_PLAYERS], iNum, i;
	get_players(iPlayers, iNum, "ch");
	for (i = 0; i < iNum; i++) {
		new szLang[4], szPath[96];
		switch (HnsLang_GetPlayer(iPlayers[i])) {
			case HNS_LANG_EN:		copy(szLang, charsmax(szLang), "en");
			case HNS_LANG_RU:		copy(szLang, charsmax(szLang), "ru");
			default:				copy(szLang, charsmax(szLang), "cn");
		}

		static const szFallback[][4] = { "cn", "en", "ru" };
		new j, bPlayed;
		for (j = 0; j < sizeof(szFallback); j++) {
			if (j > 0 && equal(szLang, szFallback[j - 1]))
				continue;

			formatex(szPath, charsmax(szPath), "sound/match/regclose_%s_%s.wav", szScene, j == 0 ? szLang : szFallback[j]);
			if (file_exists(szPath)) {
				client_cmd(iPlayers[i], "spk %s", szPath);
				bPlayed = true;
				break;
			}
		}
		if (!bPlayed)
			client_cmd(iPlayers[i], "spk sound/match/regclose_%s_cn.wav", szScene);
	}
}

// 引擎 BarTime 底部加载条 (原版加载栏机制): iSeconds 为秒, 0 隐藏
// 由引擎绘制, 随 LOADING_BAR_TIME 倒计时自然走完, 到点自动消失
stock show_engine_loading_bar(iSeconds) {
	static iMsgBarTime;
	if (!iMsgBarTime)
		iMsgBarTime = get_user_msgid("BarTime");
	if (!iMsgBarTime)
		return;

	new iPlayers[MAX_PLAYERS], iNum, i;
	get_players(iPlayers, iNum, "ch");
	for (i = 0; i < iNum; i++) {
		message_begin(MSG_ONE, iMsgBarTime, _, iPlayers[i]);
		write_short(iSeconds);
		message_end();
	}
}

// 比赛开场加载: 混合进度条
//  底部 = 引擎 BarTime 原生条 (照搬原版加载栏机制)
//  上方 = DHUD 模式文字 + 加载百分比, 颜色跟随比赛类型
//  赞助局=黄字 + 赞助者信息, 娱乐局=红字, 个人局=绿字
stock draw_match_loading_bar(iStep, iTotal) {
	static szText[160];
	new iRed, iGreen, iBlue;

	switch (g_eMatchType) {
		case MATCH_TYPE_SPONSOR: {
			formatex(szText, charsmax(szText), "赞助局 由谁赞助: %s", g_szSponsorName[0] ? g_szSponsorName : "未填写");
			iRed = 255; iGreen = 200; iBlue = 0;	// 黄色
		}
		case MATCH_TYPE_CASUAL: {
			copy(szText, charsmax(szText), "娱乐局");
			iRed = 255; iGreen = 40; iBlue = 40;	// 红色
		}
		case MATCH_TYPE_RANKED: {
			copy(szText, charsmax(szText), "个人局");
			iRed = 40; iGreen = 255; iBlue = 40;	// 绿色
		}
		default: {
			copy(szText, charsmax(szText), "比赛加载中...");
			iRed = 255; iGreen = 200; iBlue = 0;
		}
	}

	new iPercent = iStep * 100 / iTotal;

	set_dhudmessage(iRed, iGreen, iBlue, -1.0, 0.38, 0, 0.0, 0.11, 0.04, 0.04);
	show_dhudmessage(0, "%s^n[加载中 %d%%]", szText, iPercent);
}

remove_entity_m(const Zone[]) {
	new iEntity = 0;
	while ((iEntity = rg_find_ent_by_class(iEntity, Zone))) {
		set_entvar(iEntity, var_flags, get_entvar(iEntity, var_flags) | FL_KILLME);
		set_entvar(iEntity, var_nextthink, get_gametime());
	}

	set_member_game(m_bMapHasBuyZone, true);
	set_member_game(m_bMapHasBombZone, false);
}

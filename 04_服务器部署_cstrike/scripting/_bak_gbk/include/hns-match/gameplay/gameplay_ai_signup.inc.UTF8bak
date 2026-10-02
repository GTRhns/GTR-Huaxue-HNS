// ============================================================================
// AI SIGNUP SYSTEM — 集成到主菜单，报名→拼刀→投票→比赛
// v2.0: 分组认人 + 穿透模式 + 阵营显示
// ============================================================================

#define AIS_AUTO_KNIFE_DELAY 3  // 自动开始拼刀基础延迟(秒)，实际延迟 3-7 秒

// 状态机
enum _:AIS_STATE {
	AIS_IDLE = 0,
	AIS_SIGNUP,
	AIS_KNIFE_PENDING,
	AIS_KNIFE_ACTIVE,
	AIS_VOTE_MODE,
	AIS_FINAL,
	AIS_LOCKED
};

// 投票模式
enum _:AIS_MODE {
	AISM_MR = 0,
	AISM_TIMER,
	AISM_POINTSCAP,
	AISM_VAMP,
	AISM_ROUNDS,
	AISM_COUNT
};

// 地图类型
enum _:AIS_MAP_TYPE {
	AISMAP_BOOST = 0,
	AISMAP_SKILL
};

// 地图数据
enum _:AIS_MAP_DATA {
	AISMD_NAME[32],
	AISMD_TYPE
};

// 玩家数据
enum _:AIS_PLR {
	bool:AIS_SIGNED,
	AIS_SIGN_TIME,
	AIS_TEAM   // 0=未分配, 1=T(A队), 2=CT(B队)
};

// ==================== 全局变量 ====================
new AIS_STATE:g_eAISState = AIS_IDLE;
new g_eAISPlayers[MAX_PLAYERS + 1][AIS_PLR];
new g_iAISSignedCount;
new g_iAISSignupRemaining;
new g_iAISSignupTime;
new g_iAISTeamSize = 3;
new g_iAISTotalPlayers;
new g_iAISVoteModeCount[AISM_COUNT];
new AIS_MODE:g_iAISChosenMode;
new g_iAISVoteCount;
new g_iAISMapCountdown;
new g_szAISChosenMap[32];
new g_iAISHudSync;
new g_iAISTeamsHudSync;   // 阵营显示 HUD

// ★ FIX P1-4: 拼刀启动重试计数器
new g_iAISKnifeRetryCount;

// ★ FIX P1-6: 等待玩家连接计数器（替代 static 变量）
new g_iAISWaitCount;

// ★ 分组数据 — 保存报名玩家身份用于换图恢复
new g_szAISSignupPlayers[MAX_PLAYERS + 1][35];  // authid (SteamID 或 IP)
new g_iAISSignupPlayerCount;
new g_szAISTeamAPlayers[MAX_PLAYERS + 1][35];   // A队 (T方) authid
new g_iAISTeamACount;
new g_szAISTeamBPlayers[MAX_PLAYERS + 1][35];   // B队 (CT方) authid
new g_iAISTeamBCount;
new bool:g_bAISTeamsAssigned = false;            // 是否已完成分组

// ★ 恢复等待
new bool:g_bAISWaitingRecovery = false;

// ★ 穿透模式
new bool:g_bAISPenMode = false;

// 地图池
new g_eAISMaps[256][AIS_MAP_DATA];
new g_iAISMapCount;

// CVars
new g_pAISSignupTime;
new g_pAISAutoSignup;
new g_pAISMinPlayers;

// 菜单ID
new g_iAISMenuMain;
new g_iAISMenuVote;

// ==================== 初始化 ====================
ais_init() {
	g_pAISSignupTime = register_cvar("ais_signup_time", "60");
	g_pAISAutoSignup = register_cvar("ais_auto_signup", "0");
	g_pAISMinPlayers = register_cvar("ais_min_players", "2");

	// 菜单
	g_iAISMenuMain = register_menuid("AIS_MainMenu");
	g_iAISMenuVote = register_menuid("AIS_VoteMenu");
	register_menucmd(g_iAISMenuMain, 1023, "aisHandleMainMenu");
	register_menucmd(g_iAISMenuVote, 1023, "aisHandleVoteMenu");

	// HUD
	g_iAISHudSync = CreateHudSyncObj();
	g_iAISTeamsHudSync = CreateHudSyncObj();

	// 加载地图
	aisLoadMaps();

	// 换图后恢复
	aisCheckRecovery();
}

// ==================== 地图加载 ====================
aisLoadMaps() {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/hns-maps.ini");

	g_iAISMapCount = 0;

	new f = fopen(szPath, "r");
	if (!f) return;

	new szLine[256], iType = AISMAP_BOOST;
	new bool:bSkip = false;

	while (!feof(f) && g_iAISMapCount < 256 && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') continue;

		if (szLine[0] == '[') {
			new szSec[32], iEnd = strlen(szLine) - 1;
			if (szLine[iEnd] == ']') szLine[iEnd] = '^0';
			copy(szSec, charsmax(szSec), szLine[1]);
			if (equali(szSec, "boost"))      { iType = AISMAP_BOOST; bSkip = false; }
			else if (equali(szSec, "skill")) { iType = AISMAP_SKILL; bSkip = false; }
			else if (equali(szSec, "knife")) { bSkip = true; }
			continue;
		}
		if (bSkip) continue;

		new szName[32];
		parse(szLine, szName, charsmax(szName));
		if (szName[0] == '^0') continue;

		copy(g_eAISMaps[g_iAISMapCount][AISMD_NAME], 32, szName);
		g_eAISMaps[g_iAISMapCount][AISMD_TYPE] = iType;
		g_iAISMapCount++;
	}
	fclose(f);
}

// ==================== 报名 ====================
public aisJoin(id) {
	if (g_eAISState == AIS_LOCKED) {
		client_print(id, print_chat, "[AI报名] 比赛进行中，无法报名。");
		return PLUGIN_HANDLED;
	}
	if (g_eAISState == AIS_KNIFE_ACTIVE || g_eAISState == AIS_KNIFE_PENDING) {
		client_print(id, print_chat, "[AI报名] 拼刀进行中，无法报名。");
		return PLUGIN_HANDLED;
	}
	if (g_eAISState == AIS_VOTE_MODE || g_eAISState == AIS_FINAL) {
		client_print(id, print_chat, "[AI报名] 投票进行中，无法报名。");
		return PLUGIN_HANDLED;
	}

	// Toggle
	if (g_eAISPlayers[id][AIS_SIGNED]) {
		g_eAISPlayers[id][AIS_SIGNED] = false;
		g_eAISPlayers[id][AIS_TEAM] = 0;
		g_iAISSignedCount--;
		if (g_iAISSignedCount < 0) g_iAISSignedCount = 0;  // ★ FIX P1-5
		new szName[32]; get_user_name(id, szName, charsmax(szName));
		client_print(0, print_chat, "[AI报名] %s 取消了报名。(已报名: %d人)", szName, g_iAISSignedCount);
		if (g_iAISSignedCount <= 0 && g_eAISState == AIS_SIGNUP) aisCancel();
		return PLUGIN_HANDLED;
	}

	if (g_eAISState == AIS_IDLE) aisStart();

	g_eAISPlayers[id][AIS_SIGNED] = true;
	g_eAISPlayers[id][AIS_SIGN_TIME] = get_systime();
	g_eAISPlayers[id][AIS_TEAM] = 0;
	g_iAISSignedCount++;

	new szName[32]; get_user_name(id, szName, charsmax(szName));
	new iOnline = aisGetOnline();
	client_print(0, print_chat, "[AI报名] %s 报名了！(在线:%d 报名:%d)", szName, iOnline, g_iAISSignedCount);

	aisCheckFull();
	return PLUGIN_HANDLED;
}

public aisUnjoin(id) {
	if (g_eAISState != AIS_SIGNUP) return PLUGIN_HANDLED;
	if (g_eAISPlayers[id][AIS_SIGNED]) {
		g_eAISPlayers[id][AIS_SIGNED] = false;
		g_eAISPlayers[id][AIS_TEAM] = 0;
		g_iAISSignedCount--;
		if (g_iAISSignedCount < 0) g_iAISSignedCount = 0;  // ★ FIX P1-5
		new szName[32]; get_user_name(id, szName, charsmax(szName));
		client_print(0, print_chat, "[AI报名] %s 退出了报名。(已报名: %d人)", szName, g_iAISSignedCount);
		if (g_iAISSignedCount <= 0) aisCancel();
	}
	return PLUGIN_HANDLED;
}

aisStart() {
	g_eAISState = AIS_SIGNUP;
	g_iAISSignedCount = 0;
	g_iAISSignupTime = get_pcvar_num(g_pAISSignupTime);
	g_iAISSignupRemaining = g_iAISSignupTime;

	// ★ FIX P1-4/P1-6: 重置重试计数器和等待计数器
	g_iAISKnifeRetryCount = 0;
	aisResetWaitCount();

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		g_eAISPlayers[i][AIS_SIGNED] = false;
		g_eAISPlayers[i][AIS_SIGN_TIME] = 0;
		g_eAISPlayers[i][AIS_TEAM] = 0;
	}

	arrayset(g_iAISVoteModeCount, 0, sizeof(g_iAISVoteModeCount));
	g_iAISChosenMode = AISM_MR;
	g_iAISVoteCount = 0;
	g_szAISChosenMap[0] = '^0';

	// ★ 清空分组数据
	g_iAISSignupPlayerCount = 0;
	g_iAISTeamACount = 0;
	g_iAISTeamBCount = 0;
	g_bAISTeamsAssigned = false;
	g_bAISWaitingRecovery = false;

	client_print(0, print_chat, "[AI报名] 报名开始！输入 ^3/join^1 报名。(%d秒)", g_iAISSignupTime);

	remove_task(2001);
	remove_task(2002);
	set_task(1.0, "aisTaskCountdown", 2001, _, _, "b");
	set_task(float(g_iAISSignupTime), "aisTaskTimeout", 2002);
}

aisCancel() {
	g_eAISState = AIS_IDLE;
	g_iAISSignedCount = 0;
	remove_task(2001);
	remove_task(2002);
	remove_task(2011);  // 恢复等待
	remove_task(2012);  // 阵营HUD
	remove_task(2013);  // ★ FIX P0-1: 状态机轮询任务

	// ★ FIX P1-6: 重置等待计数器
	aisResetWaitCount();

	// ★ FIX P1-4: 重置重试计数器
	g_iAISKnifeRetryCount = 0;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		g_eAISPlayers[i][AIS_SIGNED] = false;
		g_eAISPlayers[i][AIS_SIGN_TIME] = 0;
		g_eAISPlayers[i][AIS_TEAM] = 0;
	}

	g_iAISSignupPlayerCount = 0;
	g_iAISTeamACount = 0;
	g_iAISTeamBCount = 0;
	g_bAISTeamsAssigned = false;
	g_bAISWaitingRecovery = false;

	client_print(0, print_chat, "[AI报名] 报名已取消。");
}

aisCheckFull() {
	new iMax = g_iAISTeamSize * 2;
	if (g_iAISSignedCount >= iMax) {
		client_print(0, print_chat, "[AI报名] 报名已满！(%d/%d) 立即分组...", g_iAISSignedCount, iMax);
		remove_task(2002);
		set_task(0.5, "aisTaskTimeout", 2002);
	}
}

aisGetMax() { return g_iAISTeamSize * 2; }
aisGetOnline() { new p[MAX_PLAYERS], n; get_players(p, n, "ch"); return n; }

// ==================== 倒计时 & HUD ====================
public aisTaskCountdown() {
	g_iAISSignupRemaining--;

	new iOnline = aisGetOnline();
	set_hudmessage(255, 255, 0, -1.0, 0.12, 0, 0.0, 1.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iAISHudSync,
		"AI报名系统^n在线: %d人 | 已报名: %d人 | 需要: %d人^n剩余: %d秒 | 输入 /join 报名",
		iOnline, g_iAISSignedCount, aisGetMax(), g_iAISSignupRemaining);

	if (g_iAISSignupRemaining <= 10 && g_iAISSignupRemaining > 0) {
		client_print(0, print_chat, "[AI报名] 最后 %d 秒！已报名: %d/%d",
			g_iAISSignupRemaining, g_iAISSignedCount, aisGetMax());
	}
	if (g_iAISSignupRemaining <= 0) remove_task(2001);
}

public aisTaskTimeout() {
	if (g_eAISState != AIS_SIGNUP) return;
	remove_task(2001);

	new iMin = get_pcvar_num(g_pAISMinPlayers);
	if (g_iAISSignedCount < iMin) {
		client_print(0, print_chat, "[AI报名] 人数不足 (%d<%d)，取消。", g_iAISSignedCount, iMin);
		aisCancel();
		return;
	}

	g_iAISTotalPlayers = g_iAISSignedCount;
	if (g_iAISTotalPlayers > aisGetMax()) g_iAISTotalPlayers = aisGetMax();
	if (g_iAISTotalPlayers % 2 != 0) g_iAISTotalPlayers--;

	// ★ FIX P2-7: 防止奇偶截断后人数不足2人
	if (g_iAISTotalPlayers < 2) {
		client_print(0, print_chat, "[AI报名] 有效人数不足2人，取消。");
		aisCancel();
		return;
	}

	g_iAISTeamSize = g_iAISTotalPlayers / 2;

	client_print(0, print_chat, "[AI报名] 报名结束！%d人参加，%dv%d",
		g_iAISTotalPlayers, g_iAISTeamSize, g_iAISTeamSize);

	// ★ 先分组再换图
	aisShowTeamsAssignment();

	// 延迟3秒后开始拼刀流程（让玩家看到分组）
	set_task(3.0, "aisStartKnife");
}

// ==================== 分组 (Snake Draft) ====================
aisShowTeamsAssignment() {
	// 收集已报名玩家的 authid
	g_iAISSignupPlayerCount = 0;
	new szTempIds[MAX_PLAYERS + 1][35];
	new iTempCount = 0;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (g_eAISPlayers[i][AIS_SIGNED]) {
			new szAuth[35];
			// 优先使用 SteamID，盗版服会用 IP
			if (!get_user_authid(i, szAuth, charsmax(szAuth)) || equal(szAuth, "STEAM_ID_PENDING") || equal(szAuth, "STEAM_ID_LAN")) {
				get_user_ip(i, szAuth, charsmax(szAuth), 1);
			}
			if (szAuth[0] != '^0') {
				copy(szTempIds[iTempCount], 34, szAuth);
				iTempCount++;
			}
		}
	}

	// 简单交替分配: A,B,A,B... (随机决定谁先)
	g_iAISTeamACount = 0;
	g_iAISTeamBCount = 0;
	new bool:bTeamATurn = (random_num(0, 1) == 0) ? true : false;

	// ★ FIX P0-4: 限制只分配 g_iAISTotalPlayers 人
	new iMaxAssign = g_iAISTotalPlayers;
	if (iMaxAssign > iTempCount) iMaxAssign = iTempCount;

	for (new i = 0; i < iMaxAssign; i++) {
		if (bTeamATurn) {
			copy(g_szAISTeamAPlayers[g_iAISTeamACount], 34, szTempIds[i]);
			g_iAISTeamACount++;
		} else {
			copy(g_szAISTeamBPlayers[g_iAISTeamBCount], 34, szTempIds[i]);
			g_iAISTeamBCount++;
		}

		bTeamATurn = !bTeamATurn;
	}

	g_bAISTeamsAssigned = true;

	// ★ 显示分组结果
	new szMsg[512], len;
	len = formatex(szMsg, charsmax(szMsg), "========== AI报名分组结果 ==========");
	len += formatex(szMsg[len], charsmax(szMsg) - len, "^n[A队 - T方] (%d人):", g_iAISTeamACount);

	for (new i = 0; i < g_iAISTeamACount; i++) {
		new szName[32];
		aisGetNameByAuth(g_szAISTeamAPlayers[i], szName, charsmax(szName));
		len += formatex(szMsg[len], charsmax(szMsg) - len, "^n  %d. %s", i + 1, szName);
	}

	len += formatex(szMsg[len], charsmax(szMsg) - len, "^n^n[B队 - CT方] (%d人):", g_iAISTeamBCount);

	for (new i = 0; i < g_iAISTeamBCount; i++) {
		new szName[32];
		aisGetNameByAuth(g_szAISTeamBPlayers[i], szName, charsmax(szName));
		len += formatex(szMsg[len], charsmax(szMsg) - len, "^n  %d. %s", i + 1, szName);
	}

	len += formatex(szMsg[len], charsmax(szMsg) - len, "^n======================================");

	// 聊天显示 (分多行避免截断)
	client_print(0, print_chat, "[AI报名] ========== 分组结果 ==========");
	client_print(0, print_chat, "[AI报名] A队(T方): %d人 | B队(CT方): %d人", g_iAISTeamACount, g_iAISTeamBCount);

	// HUD 显示 (保留10秒)
	set_hudmessage(0, 255, 255, -1.0, 0.15, 0, 0.0, 10.0, 0.0, 0.0, 0.0, 1);
	ShowSyncHudMsg(0, g_iAISHudSync, szMsg);

	server_print("[AI报名] 分组完成: A队(T)=%d人, B队(CT)=%d人", g_iAISTeamACount, g_iAISTeamBCount);
}

// 通过 authid 获取玩家名
aisGetNameByAuth(const szAuth[], szName[], iLen) {
	copy(szName, iLen, "<未连接>");

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i)) continue;

		new szPlayerAuth[35];
		if (!get_user_authid(i, szPlayerAuth, charsmax(szPlayerAuth)) || equal(szPlayerAuth, "STEAM_ID_PENDING") || equal(szPlayerAuth, "STEAM_ID_LAN")) {
			get_user_ip(i, szPlayerAuth, charsmax(szPlayerAuth), 1);
		}

		if (equal(szPlayerAuth, szAuth)) {
			get_user_name(i, szName, iLen);
			return;
		}
	}
}

// 通过 authid 获取玩家ID
aisGetIdByAuth(const szAuth[]) {
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i)) continue;

		new szPlayerAuth[35];
		if (!get_user_authid(i, szPlayerAuth, charsmax(szPlayerAuth)) || equal(szPlayerAuth, "STEAM_ID_PENDING") || equal(szPlayerAuth, "STEAM_ID_LAN")) {
			get_user_ip(i, szPlayerAuth, charsmax(szPlayerAuth), 1);
		}

		if (equal(szPlayerAuth, szAuth)) return i;
	}
	return 0;
}

// ==================== 拼刀阶段 ====================
public aisStartKnife() {
	g_eAISState = AIS_KNIFE_PENDING;

	// ★ 如果当前已经在拼刀地图，直接开始拼刀不换图
	if (hns_is_knife_map()) {
		client_print(0, print_chat, "[AI报名] 当前已是拼刀地图，直接开始！");
		// ★ 不换图时，直接分配队伍然后开始拼刀
		set_task(1.0, "aisTaskTeamAssignDirect");
		return;
	}

	aisSaveRecovery();

	new szKnifeMap[32];
	aisGetRandomKnifeMap(szKnifeMap, charsmax(szKnifeMap));
	client_print(0, print_chat, "[AI报名] 即将切换到拼刀地图: %s", szKnifeMap);
	server_cmd("changelevel %s", szKnifeMap);
}

// ★ 不换图时直接分配队伍
public aisTaskTeamAssignDirect() {
	if (g_eAISState != AIS_KNIFE_PENDING) return;

	g_bKnifeSkipSpec = true;
	aisDoTeamAssign();
	g_bKnifeSkipSpec = false;

	// 分配完成后开始拼刀
	new Float:flDelay = float(AIS_AUTO_KNIFE_DELAY) + random_float(0.0, 4.0);
	set_task(flDelay, "aisAutoStartKnife");
}

aisGetRandomKnifeMap(szOut[], iLen) {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/hns-maps.ini");

	new f = fopen(szPath, "r");
	if (!f) { copy(szOut, iLen, "35hp_knife_v2"); return; }

	new szLine[256], szMaps[256][32], iKnifeCount;
	new bool:bKnife;
	while (!feof(f) && iKnifeCount < 256 && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') continue;
		if (szLine[0] == '[') {
			new szSec[32], iEnd = strlen(szLine) - 1;
			if (szLine[iEnd] == ']') szLine[iEnd] = '^0';
			copy(szSec, charsmax(szSec), szLine[1]);
			bKnife = equali(szSec, "knife");
			continue;
		}
		if (bKnife) {
			new szName[32]; parse(szLine, szName, charsmax(szName));
			if (szName[0] != '^0') { copy(szMaps[iKnifeCount], 32, szName); iKnifeCount++; }
		}
	}
	fclose(f);

	// ★ FIX P3-15: 防止 random(0) 边界问题
	if (iKnifeCount <= 0) { copy(szOut, iLen, "35hp_knife_v2"); return; }
	copy(szOut, iLen, szMaps[random(iKnifeCount)]);
}

// ==================== 换图恢复 ====================
aisCheckRecovery() {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/ais_recovery.txt");
	if (!file_exists(szPath)) return;

	new f = fopen(szPath, "r");
	if (!f) return;

	// ★ 读取恢复数据
	new szLine[256];
	new bool:bHasState = false;
	new iSavedTeamSize = 3;
	new iSavedTotal = 6;

	// 临时存储
	new szSavedTeamA[MAX_PLAYERS + 1][35], iSavedTeamACount;
	new szSavedTeamB[MAX_PLAYERS + 1][35], iSavedTeamBCount;

	while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == '^0') continue;
		new szKey[32], szVal[64];
		parse(szLine, szKey, charsmax(szKey), szVal, charsmax(szVal));

		if (equal(szKey, "state") && str_to_num(szVal) == _:AIS_KNIFE_PENDING) {
			bHasState = true;
		}
		if (equal(szKey, "team_size")) iSavedTeamSize = str_to_num(szVal);
		if (equal(szKey, "total_players")) iSavedTotal = str_to_num(szVal);

		// ★ 读取队伍数据
		if (equal(szKey, "teama") && iSavedTeamACount < MAX_PLAYERS) {
			copy(szSavedTeamA[iSavedTeamACount], 34, szVal);
			iSavedTeamACount++;
		}
		if (equal(szKey, "teamb") && iSavedTeamBCount < MAX_PLAYERS) {
			copy(szSavedTeamB[iSavedTeamBCount], 34, szVal);
			iSavedTeamBCount++;
		}
	}
	fclose(f);
	delete_file(szPath);

	if (!bHasState) return;

	// 恢复状态
	g_eAISState = AIS_KNIFE_PENDING;
	g_iAISTeamSize = iSavedTeamSize;
	g_iAISTotalPlayers = iSavedTotal;
	g_bAISTeamsAssigned = true;

	// 恢复队伍数据
	g_iAISTeamACount = iSavedTeamACount;
	g_iAISTeamBCount = iSavedTeamBCount;
	for (new i = 0; i < iSavedTeamACount; i++) {
		copy(g_szAISTeamAPlayers[i], 34, szSavedTeamA[i]);
	}
	for (new i = 0; i < iSavedTeamBCount; i++) {
		copy(g_szAISTeamBPlayers[i], 34, szSavedTeamB[i]);
	}

	client_print(0, print_chat, "[AI报名] %dv%d 恢复拼刀！等待玩家连接...", g_iAISTeamSize, g_iAISTeamSize);
	server_print("[AI报名] 恢复数据: A队=%d人, B队=%d人", g_iAISTeamACount, g_iAISTeamBCount);

	// ★ 不要直接调用 kniferound_start()
	// 先等待玩家连接，然后分配队伍
	g_bAISWaitingRecovery = true;
	g_bKnifeSkipSpec = true;  // ★ 阻止 kniferound_player_join 拉观战
	remove_task(2011);
	set_task(2.0, "aisTaskTeamCheck", 2011, _, _, "b");
}

// ★ 等待玩家连接后分配队伍
public aisTaskTeamCheck() {
	if (g_eAISState != AIS_KNIFE_PENDING || !g_bAISWaitingRecovery) {
		remove_task(2011);
		return;
	}

	// 检查已连接的报名玩家数
	new iConnected = 0;
	for (new i = 0; i < g_iAISTeamACount; i++) {
		if (aisGetIdByAuth(g_szAISTeamAPlayers[i]) > 0) iConnected++;
	}
	for (new i = 0; i < g_iAISTeamBCount; i++) {
		if (aisGetIdByAuth(g_szAISTeamBPlayers[i]) > 0) iConnected++;
	}

	new iNeeded = g_iAISTeamACount + g_iAISTeamBCount;

	// 至少一半玩家连入就开始，最多等30秒
	// ★ FIX P1-6: 使用全局变量替代 static，避免残留
	if (iConnected >= iNeeded || g_iAISWaitCount >= 15) {
		remove_task(2011);
		g_bAISWaitingRecovery = false;
		g_iAISWaitCount = 0;

		// 分配队伍
		aisDoTeamAssign();

		// ★ 队伍分配完毕，恢复拉观战行为
		g_bKnifeSkipSpec = false;

		// 延迟后开始拼刀
		new Float:flDelay = float(AIS_AUTO_KNIFE_DELAY) + random_float(0.0, 4.0);
		set_task(flDelay, "aisAutoStartKnife");
		return;
	}

	g_iAISWaitCount++;

	// 显示等待状态
	set_hudmessage(255, 200, 0, -1.0, 0.15, 0, 0.0, 2.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iAISHudSync,
		"[AI报名] 等待玩家连接...^n已连接: %d/%d",
		iConnected, iNeeded);
}

// ★ 核心修复: 分配玩家到 T/CT 队伍
aisDoTeamAssign() {
	new iAssigned = 0;

	// 分配 A队 → T
	for (new i = 0; i < g_iAISTeamACount; i++) {
		new id = aisGetIdByAuth(g_szAISTeamAPlayers[i]);
		if (id > 0) {
			rg_set_user_team(id, TEAM_TERRORIST, MODEL_AUTO);
			g_eAISPlayers[id][AIS_TEAM] = 1;

			new szName[32]; get_user_name(id, szName, charsmax(szName));
			server_print("[AI报名] 分配 %s (%s) -> T (A队)", szName, g_szAISTeamAPlayers[i]);
			iAssigned++;
		}
	}

	// 分配 B队 → CT
	for (new i = 0; i < g_iAISTeamBCount; i++) {
		new id = aisGetIdByAuth(g_szAISTeamBPlayers[i]);
		if (id > 0) {
			rg_set_user_team(id, TEAM_CT, MODEL_AUTO);
			g_eAISPlayers[id][AIS_TEAM] = 2;

			new szName[32]; get_user_name(id, szName, charsmax(szName));
			server_print("[AI报名] 分配 %s (%s) -> CT (B队)", szName, g_szAISTeamBPlayers[i]);
			iAssigned++;
		}
	}

	client_print(0, print_chat, "[AI报名] 队伍分配完成！已分配 %d 人 (A队=T方, B队=CT方)", iAssigned);

	// ★ 开始阵营HUD显示
	remove_task(2012);
	set_task(1.0, "aisShowTeamsHud", 2012, _, _, "b");
}

// ★ 自动开始拼刀
public aisAutoStartKnife() {
	if (g_eAISState != AIS_KNIFE_PENDING) return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	if (iNum < 2) {
		// ★ FIX P1-4: 最多重试10次(约30秒)，超过后取消
		g_iAISKnifeRetryCount++;
		if (g_iAISKnifeRetryCount >= 10) {
			client_print(0, print_chat, "[AI报名] 玩家不足，已等待30秒，取消拼刀。");
			aisCancel();
			return;
		}
		client_print(0, print_chat, "[AI报名] 玩家不足，等待... (%d/10)", g_iAISKnifeRetryCount);
		set_task(3.0, "aisAutoStartKnife");
		return;
	}

	// ★ FIX P0-1: 设置为拼刀激活状态
	g_eAISState = AIS_KNIFE_ACTIVE;
	g_iAISKnifeRetryCount = 0;

	// ★ 设置为团队拼刀，否则 kniferound_roundstart 会切到训练模式导致秒结束
	g_iMatchStatus = MATCH_TEAMKNIFE;
	kniferound_start();

	// ★ FIX P0-1: 启动状态机轮询任务，监控拼刀→投票→比赛→结束的状态转换
	remove_task(2013);
	set_task(2.0, "aisTaskStateMachine", 2013, _, _, "b");
}

// ★ 拼刀期间阵营HUD
public aisShowTeamsHud() {
	// ★ FIX P2-9: 比赛开始后停止显示拼刀阵营HUD
	if (g_eAISState != AIS_KNIFE_PENDING && g_eAISState != AIS_KNIFE_ACTIVE) {
		remove_task(2012);
		return;
	}

	new szMsg[512], len;
	len = formatex(szMsg, charsmax(szMsg), "=== 阵营 ===^n");

	len += formatex(szMsg[len], charsmax(szMsg) - len, "[T - A队]");
	for (new i = 0; i < g_iAISTeamACount; i++) {
		new szName[32];
		aisGetNameByAuth(g_szAISTeamAPlayers[i], szName, charsmax(szName));
		if (i > 0) len += formatex(szMsg[len], charsmax(szMsg) - len, ", ");
		len += formatex(szMsg[len], charsmax(szMsg) - len, szName);
	}

	len += formatex(szMsg[len], charsmax(szMsg) - len, "^n[CT - B队]");
	for (new i = 0; i < g_iAISTeamBCount; i++) {
		new szName[32];
		aisGetNameByAuth(g_szAISTeamBPlayers[i], szName, charsmax(szName));
		if (i > 0) len += formatex(szMsg[len], charsmax(szMsg) - len, ", ");
		len += formatex(szMsg[len], charsmax(szMsg) - len, szName);
	}

	set_hudmessage(100, 255, 100, 0.02, 0.02, 0, 0.0, 1.2, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iAISTeamsHudSync, szMsg);
}

// ★ FIX P0-1/P0-2: 状态机轮询任务 — 自动推进 AIS 状态
public aisTaskStateMachine() {
	switch (g_eAISState) {
		case AIS_KNIFE_ACTIVE: {
			// 拼刀结束: g_iMatchStatus 从 MATCH_TEAMKNIFE 变为 MATCH_MAPPICK
			if (g_iMatchStatus != MATCH_TEAMKNIFE) {
				g_eAISState = AIS_VOTE_MODE;
				client_print(0, print_chat, "[AI报名] 拼刀结束，进入投票/选图阶段。");
			}
		}
		case AIS_VOTE_MODE: {
			// 比赛开始: g_iMatchStatus 到达 MATCH_WAITCONNECT 或 MATCH_STARTED
			if (g_iMatchStatus == MATCH_WAITCONNECT || g_iMatchStatus == MATCH_STARTED) {
				g_eAISState = AIS_LOCKED;
				client_print(0, print_chat, "[AI报名] 比赛开始！AI系统已锁定。");
			}
			// 异常回退: 如果状态回到 NONE
			if (g_iMatchStatus == MATCH_NONE) {
				client_print(0, print_chat, "[AI报名] 比赛未开始，AI系统重置。");
				aisCancel();
			}
		}
		case AIS_LOCKED: {
			// 比赛结束: g_iMatchStatus 回到 MATCH_NONE
			if (g_iMatchStatus == MATCH_NONE) {
				client_print(0, print_chat, "[AI报名] 比赛结束，AI系统重置。");
				aisCancel();
			}
		}
		default: {
			// AIS_IDLE / AIS_SIGNUP / AIS_KNIFE_PENDING / AIS_FINAL — 不需要处理
			remove_task(2013);
		}
	}
}

// ★ FIX P1-6: 重置 aisTaskTeamCheck 中的 static 计数器
aisResetWaitCount() {
	// 通过 set_pcvar 或直接操作无法重置 static 变量
	// 改为使用全局变量替代 static
	g_iAISWaitCount = 0;
}

aisSaveRecovery() {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/ais_recovery.txt");

	new szDir[128];
	get_configsdir(szDir, charsmax(szDir));
	format(szDir, charsmax(szDir), "%s/mixsystem", szDir);
	if (!dir_exists(szDir)) mkdir(szDir);

	new f = fopen(szPath, "wt");
	if (f) {
		fprintf(f, "state %d^n", _:g_eAISState);
		fprintf(f, "team_size %d^n", g_iAISTeamSize);
		fprintf(f, "total_players %d^n", g_iAISTotalPlayers);

		// ★ 保存队伍分配
		for (new i = 0; i < g_iAISTeamACount; i++) {
			fprintf(f, "teama %s^n", g_szAISTeamAPlayers[i]);
		}
		for (new i = 0; i < g_iAISTeamBCount; i++) {
			fprintf(f, "teamb %s^n", g_szAISTeamBPlayers[i]);
		}

		fclose(f);
		server_print("[AI报名] 恢复数据已保存: A队=%d, B队=%d", g_iAISTeamACount, g_iAISTeamBCount);
	}
}

// ==================== 穿透模式 (/re 命令) ====================
public aisToggleRe(id) {
	if (!isUserWatcher(id) && !isUserAdmin(id)) {
		client_print(id, print_chat, "[AI报名] 仅管理员/观察者可使用。");
		return PLUGIN_HANDLED;
	}

	if (g_eAISState != AIS_KNIFE_PENDING && g_eAISState != AIS_KNIFE_ACTIVE) {
		client_print(id, print_chat, "[AI报名] 仅在拼刀阶段可切换穿透模式。");
		return PLUGIN_HANDLED;
	}

	g_bAISPenMode = !g_bAISPenMode;
	aisTogglePen(g_bAISPenMode);

	new szName[32]; get_user_name(id, szName, charsmax(szName));
	client_print(0, print_chat, "[AI报名] %s %s了穿透模式！", szName, g_bAISPenMode ? "开启" : "关闭");
	return PLUGIN_HANDLED;
}

aisTogglePen(bool:bEnable) {
	if (bEnable) {
		// 设置穿透: 半透明 + 服务器穿透
		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_alive(i)) continue;
			new iTeam = get_user_team(i);
			if (iTeam == TEAM_TERRORIST || iTeam == TEAM_CT) {
				set_pev(i, pev_rendermode, kRenderTransTexture);
				set_pev(i, pev_renderamt, 100.0);
			}
		}
		server_cmd("mp_solidplayers 0");
	} else {
		// 关闭穿透
		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_alive(i)) continue;
			new iTeam = get_user_team(i);
			if (iTeam == TEAM_TERRORIST || iTeam == TEAM_CT) {
				set_pev(i, pev_rendermode, kRenderNormal);
				set_pev(i, pev_renderamt, 255.0);
			}
		}
		server_cmd("mp_solidplayers 1");
	}
}

// ==================== /teams 命令 ====================
public aisShowTeams(id) {
	if (!g_bAISTeamsAssigned) {
		client_print(id, print_chat, "[AI报名] 还未分组。");
		return PLUGIN_HANDLED;
	}

	client_print(id, print_chat, "[AI报名] ===== 阵营分配 =====");

	client_print(id, print_chat, "[A队 - T方] (%d人):", g_iAISTeamACount);
	for (new i = 0; i < g_iAISTeamACount; i++) {
		new szName[32];
		aisGetNameByAuth(g_szAISTeamAPlayers[i], szName, charsmax(szName));
		client_print(id, print_chat, "  %d. %s", i + 1, szName);
	}

	client_print(id, print_chat, "[B队 - CT方] (%d人):", g_iAISTeamBCount);
	for (new i = 0; i < g_iAISTeamBCount; i++) {
		new szName[32];
		aisGetNameByAuth(g_szAISTeamBPlayers[i], szName, charsmax(szName));
		client_print(id, print_chat, "  %d. %s", i + 1, szName);
	}

	return PLUGIN_HANDLED;
}



// ==================== 管理菜单 ====================
aisShowMainMenu(id) {
	new szState[32];
	switch (g_eAISState) {
		case AIS_IDLE:          copy(szState, charsmax(szState), "\d空闲");
		case AIS_SIGNUP:        copy(szState, charsmax(szState), "\y报名中");
		case AIS_KNIFE_PENDING: copy(szState, charsmax(szState), "\y拼刀待命");
		case AIS_KNIFE_ACTIVE:  copy(szState, charsmax(szState), "\r拼刀中");
		case AIS_VOTE_MODE:     copy(szState, charsmax(szState), "\y投票中");
		case AIS_FINAL:         copy(szState, charsmax(szState), "\g准备开始");
		case AIS_LOCKED:        copy(szState, charsmax(szState), "\r比赛中");
	}

	new szMenu[512], len;
	len  = formatex(szMenu, charsmax(szMenu), "\rAI报名系统^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r状态: %s | 在线: %d人^n", szState, aisGetOnline());
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r已报名: %d/%d^n^n", g_iAISSignedCount, aisGetMax());
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w 开始报名^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w 强制开始^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3.\w 取消报名^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4.\w 每队人数: %d^n", g_iAISTeamSize);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5.\w %s穿透模式^n", g_bAISPenMode ? "关闭" : "开启");
	if (g_bAISTeamsAssigned)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6.\w 查看阵营^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r^n\r说明: 玩家输入 /join 报名^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r满%d人自动分组(%dv%d)^n^n", aisGetMax(), g_iAISTeamSize, g_iAISTeamSize);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 返回");

	new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9);
	if (g_bAISTeamsAssigned) iKeys |= (1<<5);
	show_menu(id, iKeys, szMenu, -1, "AIS_MainMenu");
}

public aisHandleMainMenu(id, key) {
	if (!isUserWatcher(id) && !isUserAdmin(id)) return PLUGIN_HANDLED;

	if (key == 0) {
		if (g_eAISState == AIS_LOCKED) {
			client_print(id, print_chat, "[AI报名] 比赛进行中。");
		} else if (g_eAISState == AIS_SIGNUP) {
			client_print(id, print_chat, "[AI报名] 已经在报名中。");
		} else {
			aisStart();
			client_print(0, print_chat, "[AI报名] 管理员 %n 启动了报名。", id);
		}
	} else if (key == 1) {
		if (g_eAISState == AIS_LOCKED) {
			client_print(id, print_chat, "[AI报名] 比赛进行中。");
		} else if (g_eAISState == AIS_SIGNUP) {
			remove_task(2002);
			set_task(0.3, "aisTaskTimeout", 2002);
			client_print(0, print_chat, "[AI报名] 管理员 %n 强制结束报名。", id);
		} else if (g_eAISState == AIS_KNIFE_PENDING || g_eAISState == AIS_KNIFE_ACTIVE) {
			client_print(id, print_chat, "[AI报名] 拼刀已经在进行中。");
		} else {
			g_iAISTotalPlayers = aisGetMax();
			g_iAISTeamSize = g_iAISTotalPlayers / 2;
			client_print(0, print_chat, "[AI报名] 管理员 %n 强制开始，%dv%d 拼刀！", id, g_iAISTeamSize, g_iAISTeamSize);
			aisShowTeamsAssignment();
			set_task(3.0, "aisStartKnife");
		}
	} else if (key == 2) {
		aisCancel();
		client_print(0, print_chat, "[AI报名] 管理员 %n 取消了报名。", id);
	} else if (key == 3) {
		g_iAISTeamSize++;
		if (g_iAISTeamSize > 10) g_iAISTeamSize = 2;
		client_print(0, print_chat, "[AI报名] 每队人数: %d (%dv%d=%d人)", g_iAISTeamSize, g_iAISTeamSize, g_iAISTeamSize, aisGetMax());
	} else if (key == 4) {
		aisToggleRe(id);
		return PLUGIN_HANDLED;
	} else if (key == 5) {
		aisShowTeams(id);
		return PLUGIN_HANDLED;
	} else if (key == 9) {
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	aisShowMainMenu(id);
	return PLUGIN_HANDLED;
}

// ==================== 模式投票菜单 (给原系统用) ====================
aisShowVoteMenu(id) {
	new szModes[5][32] = { "MR", "计时", "点位积分", "吸血", "回合制" };
	new szMenu[512], len;
	len  = formatex(szMenu, charsmax(szMenu), "\r选择比赛模式^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r参赛: %dv%d^n^n", g_iAISTeamSize, g_iAISTeamSize);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w MR^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w 计时^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3.\w 点位积分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4.\w 吸血^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5.\w 回合制^n^n\r0.\w 退出");

	new iVoteKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9);
	show_menu(id, iVoteKeys, szMenu, -1, "AIS_VoteMenu");
}

public aisHandleVoteMenu(id, key) {
	return PLUGIN_HANDLED;
}

// ==================== 玩家事件 ====================
aisOnDisconnect(id) {
	if (g_eAISState == AIS_SIGNUP && g_eAISPlayers[id][AIS_SIGNED]) {
		g_eAISPlayers[id][AIS_SIGNED] = false;
		g_eAISPlayers[id][AIS_TEAM] = 0;
		g_eAISPlayers[id][AIS_SIGN_TIME] = 0;  // ★ FIX P2-8: 清除报名时间
		g_iAISSignedCount--;
		if (g_iAISSignedCount < 0) g_iAISSignedCount = 0;  // ★ FIX P1-5
		if (g_iAISSignedCount <= 0) aisCancel();
	}

	// ★ FIX P2-10: 拼刀阶段断线清理队伍数据
	if (g_bAISTeamsAssigned) {
		new szAuth[35];
		if (!get_user_authid(id, szAuth, charsmax(szAuth)) || equal(szAuth, "STEAM_ID_PENDING") || equal(szAuth, "STEAM_ID_LAN")) {
			get_user_ip(id, szAuth, charsmax(szAuth), 1);
		}

		// 从 A 队移除
		for (new i = 0; i < g_iAISTeamACount; i++) {
			if (equal(g_szAISTeamAPlayers[i], szAuth)) {
				// 把最后一个移到当前位置
				if (i < g_iAISTeamACount - 1) {
					copy(g_szAISTeamAPlayers[i], 34, g_szAISTeamAPlayers[g_iAISTeamACount - 1]);
				}
				g_szAISTeamAPlayers[g_iAISTeamACount - 1][0] = EOS;
				g_iAISTeamACount--;
				break;
			}
		}

		// 从 B 队移除
		for (new i = 0; i < g_iAISTeamBCount; i++) {
			if (equal(g_szAISTeamBPlayers[i], szAuth)) {
				if (i < g_iAISTeamBCount - 1) {
					copy(g_szAISTeamBPlayers[i], 34, g_szAISTeamBPlayers[g_iAISTeamBCount - 1]);
				}
				g_szAISTeamBPlayers[g_iAISTeamBCount - 1][0] = EOS;
				g_iAISTeamBCount--;
				break;
			}
		}

		// ★ FIX P2-8: 同步递减总人数
		if (g_iAISTotalPlayers > 0) g_iAISTotalPlayers--;
	}
}

aisOnPutInServer(id) {
	g_eAISPlayers[id][AIS_SIGNED] = false;
	g_eAISPlayers[id][AIS_SIGN_TIME] = 0;
	g_eAISPlayers[id][AIS_TEAM] = 0;

	if (get_pcvar_num(g_pAISAutoSignup) && g_eAISState == AIS_SIGNUP) {
		g_eAISPlayers[id][AIS_SIGNED] = true;
		g_eAISPlayers[id][AIS_SIGN_TIME] = get_systime();
		g_iAISSignedCount++;
		aisCheckFull();
	}
}

// ==================== 自动报名 ====================
public hns_match_reset_round() {
	if (get_pcvar_num(g_pAISAutoSignup) && g_eAISState == AIS_IDLE) {
		new szCurMap[64]; get_mapname(szCurMap, charsmax(szCurMap));
		if (containi(szCurMap, "knife") == -1)
			set_task(2.0, "aisAutoStart");
	}
}

public aisAutoStart() {
	if (g_eAISState == AIS_IDLE) aisStart();
}

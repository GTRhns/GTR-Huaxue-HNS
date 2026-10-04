/* ============================================================
   HnsModeVote 1.2
   /rts 模式投票, 走 HnsLanguage (/lang)

   规则:
   - 比赛中 (MODE_MIX / 刀局 / 大厅 / 报名流程) 禁用
   - 需要在线人数的三分之二输入 /rts 才开启投票 (和 /rtv 一样)
   - 达到 2/3 后先 5 秒倒计时, 再弹出 7 秒投票菜单
   - 7 秒后按比例最高的模式切换; 持平则在持平模式里随机
   - 当前模式显示红色 [%]
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <hns_matchsystem>
#include <hns_language>

#define PLUGIN_NAME    "HNS Mode Vote"
#define PLUGIN_VERSION "1.2.1"
#define PLUGIN_AUTHOR  "GTR"

#define TASK_VOTE_TICK       53001
#define TASK_REFRESH         53002
#define TASK_APPLY           53003
#define TASK_HUD             53004
#define TASK_MENU_COUNTDOWN  53005

#define VOTE_NONE      -1

#define RTS_NEED_NUM            2
#define RTS_NEED_DEN            3
#define RTS_COUNTDOWN_SECONDS   5
#define RTS_VOTE_SECONDS        7
#define RTS_APPLY_DELAY         3.0

#define MENU_KEYS (MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_0)

enum {
	RTS_PUB = 0,
	RTS_DM,
	RTS_ZM,
	RTS_TRAINING,
	RTS_MODE_COUNT
};

new const g_iModeIds[RTS_MODE_COUNT] = {
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_TRAINING
};

new const g_szModeKeys[RTS_MODE_COUNT][] = {
	"RTS_MODE_PUB",
	"RTS_MODE_DM",
	"RTS_MODE_ZM",
	"RTS_MODE_TRAINING"
};

new const g_szModeFallback[RTS_MODE_COUNT][] = {
	"公共模式",
	"死斗模式",
	"僵尸模式",
	"训练模式"
};

new g_iVoteChoice[MAX_PLAYERS + 1];
new bool:g_bMenuOpen[MAX_PLAYERS + 1];
new bool:g_bWantVote[MAX_PLAYERS + 1];
new g_iVotes[RTS_MODE_COUNT];
new g_iWantCount;
new g_iVoteLeft;
new g_iMenuCountdown;
new bool:g_bVoting;
new bool:g_bMenuCountdown;
new bool:g_bApplying;
new g_iPendingMode = -1;
new g_szPrefix[24];

public plugin_natives() {
	set_native_filter("NativeFilter");
}

public NativeFilter(const szName[], iIndex, iTrap) {
	if (equal(szName, "hns_get_mode")
		|| equal(szName, "hns_set_mode")
		|| equal(szName, "hns_get_status")
		|| equal(szName, "hns_get_prefix")
		|| equal(szName, "HnsLang_Get"))
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

	register_clcmd("say /rts", "CmdRts");
	register_clcmd("say_team /rts", "CmdRts");
	register_clcmd("say rts", "CmdRts");
	register_clcmd("say_team rts", "CmdRts");
	register_clcmd("say /modevote", "CmdRts");
	register_clcmd("say_team /modevote", "CmdRts");

	register_menucmd(register_menuid("HNS RTS Vote"), MENU_KEYS, "HandleVoteMenu");

	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
	if (!g_szPrefix[0])
		copy(g_szPrefix, charsmax(g_szPrefix), "[^3HNS^1]");
}

public client_putinserver(id) {
	g_iVoteChoice[id] = VOTE_NONE;
	g_bMenuOpen[id] = false;
	g_bWantVote[id] = false;

	if (g_bVoting) {
		g_bMenuOpen[id] = true;
		ShowVoteMenu(id);
	}
}

public client_disconnected(id) {
	if (g_bWantVote[id]) {
		g_bWantVote[id] = false;
		if (g_iWantCount > 0)
			g_iWantCount--;
	}

	if (g_bVoting && g_iVoteChoice[id] != VOTE_NONE)
		RemoveVote(id);

	g_iVoteChoice[id] = VOTE_NONE;
	g_bMenuOpen[id] = false;
}

public CmdRts(id) {
	if (!is_user_connected(id) || is_user_bot(id))
		return PLUGIN_HANDLED;

	if (rts_match_blocked()) {
		rts_print_lang(id, "RTS_MATCH_BLOCK", "比赛进行中，不能投票切换模式。");
		return PLUGIN_HANDLED;
	}

	if (g_bApplying) {
		rts_print_lang(id, "RTS_APPLYING", "模式即将切换，请稍候。");
		return PLUGIN_HANDLED;
	}

	if (g_bMenuCountdown) {
		rts_print_lang(id, "RTS_START_COUNTDOWN", "模式投票将在 ^3%d^1 秒后开始。", g_iMenuCountdown);
		return PLUGIN_HANDLED;
	}

	if (g_bVoting) {
		g_bMenuOpen[id] = true;
		ShowVoteMenu(id);
		return PLUGIN_HANDLED;
	}

	new iNeed = NeedStartVotes();
	new iLeft = iNeed - g_iWantCount;
	if (iLeft < 0)
		iLeft = 0;

	if (g_bWantVote[id]) {
		rts_print_lang(id, "RTS_ALREADY", "你已经投过票了！至少还需要 ^3%d^1 票（^3%d^1/^3%d^1）。", iLeft, g_iWantCount, iNeed);
		return PLUGIN_HANDLED;
	}

	g_bWantVote[id] = true;
	g_iWantCount++;

	iLeft = iNeed - g_iWantCount;
	if (iLeft < 0)
		iLeft = 0;

	if (g_iWantCount >= iNeed) {
		StartCountdown();
		return PLUGIN_HANDLED;
	}

	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	rts_print_lang(0, "RTS_NEED_START", "玩家 ^3%s^1 已请求换模式。至少需要 ^3%d^1/^3%d^1 票（三分之二），还差 ^3%d^1 票。", szName, g_iWantCount, iNeed, iLeft);
	return PLUGIN_HANDLED;
}

StartCountdown() {
	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_MATCH", "比赛已开始，模式投票取消。");
		return;
	}

	g_bMenuCountdown = true;
	g_bVoting = false;
	g_bApplying = false;
	g_iPendingMode = -1;
	g_iMenuCountdown = RTS_COUNTDOWN_SECONDS;
	ResetVotes();
	ResetWants();

	rts_print_lang(0, "RTS_START_COUNTDOWN", "模式投票将在 ^3%d^1 秒后开始。", g_iMenuCountdown);
	client_cmd(0, "spk Gman/Gman_Choose2");
	ShowCountdownHud();

	remove_task(TASK_MENU_COUNTDOWN);
	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	remove_task(TASK_HUD);
	set_task(1.0, "TaskMenuCountdown", TASK_MENU_COUNTDOWN, .flags = "b");
}

public TaskMenuCountdown() {
	if (!g_bMenuCountdown) {
		remove_task(TASK_MENU_COUNTDOWN);
		return;
	}

	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_MATCH", "比赛已开始，模式投票取消。");
		return;
	}

	g_iMenuCountdown--;
	if (g_iMenuCountdown > 0) {
		rts_print_lang(0, "RTS_START_COUNTDOWN", "模式投票将在 ^3%d^1 秒后开始。", g_iMenuCountdown);
		ShowCountdownHud();
		return;
	}

	remove_task(TASK_MENU_COUNTDOWN);
	g_bMenuCountdown = false;
	BeginVote();
}

BeginVote() {
	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_MATCH", "比赛已开始，模式投票取消。");
		return;
	}

	g_bVoting = true;
	g_bMenuCountdown = false;
	g_bApplying = false;
	g_iPendingMode = -1;
	g_iVoteLeft = RTS_VOTE_SECONDS;
	ResetVotes();
	ResetWants();

	rts_print_lang(0, "RTS_VOTE_START", "模式投票开始，请在 ^3%d^1 秒内选择。", RTS_VOTE_SECONDS);
	client_cmd(0, "spk Gman/Gman_Choose2");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (is_user_bot(id))
			continue;
		g_bMenuOpen[id] = true;
		ShowVoteMenu(id);
	}

	ShowVoteHud();
	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	remove_task(TASK_HUD);
	set_task(1.0, "TaskVoteTick", TASK_VOTE_TICK, .flags = "b");
}

public TaskVoteTick() {
	if (!g_bVoting) {
		remove_task(TASK_VOTE_TICK);
		return;
	}

	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_MATCH", "比赛已开始，模式投票取消。");
		return;
	}

	g_iVoteLeft--;
	if (g_iVoteLeft > 0) {
		rts_print_lang(0, "RTS_VOTE_LEFT", "模式投票剩余 ^3%d^1 秒。", g_iVoteLeft);
		ShowVoteHud();
		RefreshOpenMenus();
		return;
	}

	remove_task(TASK_VOTE_TICK);
	FinishVote();
}

ShowVoteMenu(id) {
	if (!is_user_connected(id) || is_user_bot(id))
		return;

	new szMenu[512], szText[128], szItem[96], szName[32], len;
	new iCurrent = hns_get_mode();
	new iPlayers = CountHumans();

	rts_lang(id, "RTS_MENU_TITLE", szText, charsmax(szText), "\r[HNS] 模式投票^n");
	len = copy(szMenu, charsmax(szMenu), szText);
	rts_lang(id, "RTS_MENU_TIME", szText, charsmax(szText), "\w剩余 \y%d\w 秒  在线 \y%d\w 人^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, szText, g_iVoteLeft, iPlayers);
	rts_lang(id, "RTS_MENU_HINT", szText, charsmax(szText), "\d当前模式显示为红色 [%]^n^n");
	len += copy(szMenu[len], charsmax(szMenu) - len, szText);

	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		GetModeName(id, i, szName, charsmax(szName));
		rts_lang(id, "RTS_MENU_ITEM", szItem, charsmax(szItem), "%d. %s [%d%%]");
		if (g_iModeIds[i] == iCurrent)
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\r");
		else
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\w");
		len += formatex(szMenu[len], charsmax(szMenu) - len, szItem, i + 1, szName, VotePercent(i));
		if (g_iVoteChoice[id] == i)
			len += formatex(szMenu[len], charsmax(szMenu) - len, " \y<");
		len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");
	}

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");
	rts_lang(id, "RTS_MENU_HIDE", szText, charsmax(szText), "\r0.\w 隐藏菜单 (投票不结束)");
	len += copy(szMenu[len], charsmax(szMenu) - len, szText);

	show_menu(id, MENU_KEYS, szMenu, -1, "HNS RTS Vote");
}

public HandleVoteMenu(id, key) {
	if (!g_bVoting) {
		g_bMenuOpen[id] = false;
		return PLUGIN_HANDLED;
	}

	if (key == 9) {
		g_bMenuOpen[id] = false;
		rts_print_lang(id, "RTS_HIDDEN", "菜单已隐藏，输入 ^3/rts^1 可重新打开。投票不会结束。");
		return PLUGIN_HANDLED;
	}

	g_bMenuOpen[id] = true;
	if (key >= 0 && key < RTS_MODE_COUNT)
		SetVote(id, key);

	ShowVoteMenu(id);
	return PLUGIN_HANDLED;
}

SetVote(id, choice) {
	if (choice < 0 || choice >= RTS_MODE_COUNT)
		return;
	if (g_iVoteChoice[id] == choice)
		return;

	RemoveVote(id);
	g_iVoteChoice[id] = choice;
	g_iVotes[choice]++;

	new szName[32], szMode[32];
	get_user_name(id, szName, charsmax(szName));
	GetModeName(id, choice, szMode, charsmax(szMode));
	rts_print_lang(0, "RTS_VOTED", "^3%s^1 投票给 ^3%s^1 (%d%%)。", szName, szMode, VotePercent(choice));
	RefreshOpenMenus();
}

RemoveVote(id) {
	new old = g_iVoteChoice[id];
	if (old == VOTE_NONE)
		return;

	if (old >= 0 && old < RTS_MODE_COUNT && g_iVotes[old] > 0)
		g_iVotes[old]--;

	g_iVoteChoice[id] = VOTE_NONE;
}

FinishVote() {
	if (!g_bVoting || g_bApplying)
		return;

	g_bVoting = false;
	CloseAllMenus();

	new iBestVotes = 0;
	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		if (g_iVotes[i] > iBestVotes)
			iBestVotes = g_iVotes[i];
	}

	if (iBestVotes < 1) {
		rts_print_lang(0, "RTS_NO_VOTES", "没有有效投票，保持当前模式。");
		ResetVotes();
		return;
	}

	new iTied[RTS_MODE_COUNT], iTiedNum;
	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		if (g_iVotes[i] == iBestVotes)
			iTied[iTiedNum++] = i;
	}

	new iWinner = iTied[0];
	new bool:bTie = (iTiedNum > 1);
	if (bTie)
		iWinner = iTied[random_num(0, iTiedNum - 1)];

	new iMode = g_iModeIds[iWinner];
	new iPercent = VotePercent(iWinner);

	if (bTie) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			new szMode[32];
			GetModeName(iPlayers[i], iWinner, szMode, charsmax(szMode));
			rts_print_lang(iPlayers[i], "RTS_TIE_RANDOM", "^3%s^1 与其他模式持平，已随机选中。", szMode);
		}
	}

	StartApply(iMode, iPercent);
}

StartApply(iMode, iPercent) {
	g_bApplying = true;
	g_iPendingMode = iMode;

	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	CloseAllMenus();

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	if (iMode == hns_get_mode()) {
		for (new i; i < iNum; i++) {
			new szMode[32];
			GetModeNameById(iPlayers[i], iMode, szMode, charsmax(szMode));
			rts_print_lang(iPlayers[i], "RTS_ALREADY_MODE", "^3%s^1 已达 ^3%d%%^1，当前已经是该模式。", szMode, iPercent);
		}
		g_bApplying = false;
		g_iPendingMode = -1;
		ResetVotes();
		return;
	}

	for (new i; i < iNum; i++) {
		new szMode[32], szHud[64];
		GetModeNameById(iPlayers[i], iMode, szMode, charsmax(szMode));
		rts_print_lang(iPlayers[i], "RTS_WILL_SWITCH", "将在 ^3%.0f^1 秒后切换到 ^3%s^1 (%d%%)。", RTS_APPLY_DELAY, szMode, iPercent);
		rts_lang(iPlayers[i], "RTS_SWITCH_HUD", szHud, charsmax(szHud), "即将切换到 %s");
		set_hudmessage(0, 255, 80, -1.0, 0.28, 0, 0.0, 3.0, 0.1, 0.1, -1);
		show_hudmessage(iPlayers[i], szHud, szMode);
	}

	set_task(RTS_APPLY_DELAY, "TaskApplyMode", TASK_APPLY);
}

public TaskApplyMode() {
	if (!g_bApplying)
		return;

	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_SWITCH", "比赛已开始，模式切换取消。");
		return;
	}

	new iMode = g_iPendingMode;
	g_bApplying = false;
	g_iPendingMode = -1;
	ResetVotes();

	if (iMode < 0)
		return;

	hns_set_mode(iMode);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new szMode[32];
		GetModeNameById(iPlayers[i], iMode, szMode, charsmax(szMode));
		rts_print_lang(iPlayers[i], "RTS_SWITCHED", "已切换到 ^3%s^1。", szMode);
	}
}

CancelAll(const szKey[], const szFallback[]) {
	g_bVoting = false;
	g_bMenuCountdown = false;
	g_bApplying = false;
	g_iPendingMode = -1;
	g_iVoteLeft = 0;
	g_iMenuCountdown = 0;

	remove_task(TASK_VOTE_TICK);
	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	remove_task(TASK_HUD);
	remove_task(TASK_MENU_COUNTDOWN);

	CloseAllMenus();
	ResetVotes();
	ResetWants();
	rts_print_lang(0, szKey, szFallback);
}

ResetVotes() {
	arrayset(g_iVotes, 0, sizeof(g_iVotes));
	for (new i = 1; i <= MaxClients; i++)
		g_iVoteChoice[i] = VOTE_NONE;
}

ResetWants() {
	g_iWantCount = 0;
	for (new i = 1; i <= MaxClients; i++)
		g_bWantVote[i] = false;
}

RefreshOpenMenus() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (g_bMenuOpen[id])
			ShowVoteMenu(id);
	}
}

CloseAllMenus() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		g_bMenuOpen[id] = false;
		if (is_user_connected(id))
			show_menu(id, 0, "^n", 1);
	}
}

ShowCountdownHud() {
	ShowVoteHudEx(g_iMenuCountdown);
}

ShowVoteHud() {
	ShowVoteHudEx(g_iVoteLeft);
}

ShowVoteHudEx(iLeft) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	set_hudmessage(255, 40, 40, -1.0, 0.28, 0, 0.0, 1.1, 0.0, 0.1, -1);
	for (new i; i < iNum; i++) {
		new szHud[64];
		rts_lang(iPlayers[i], "RTS_COUNTDOWN_HUD", szHud, charsmax(szHud), "模式投票倒计时 %d");
		show_hudmessage(iPlayers[i], szHud, iLeft);
	}
	client_cmd(0, "spk fvox/bell");
}

CountHumans() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new n;
	for (new i; i < iNum; i++) {
		if (!is_user_bot(iPlayers[i]))
			n++;
	}
	return n;
}

NeedStartVotes() {
	new n = CountHumans();
	new need = floatround(float(n) * float(RTS_NEED_NUM) / float(RTS_NEED_DEN), floatround_ceil);
	if (need < 1)
		need = 1;
	return need;
}

VotePercent(choice) {
	new n = CountHumans();
	if (n < 1)
		return 0;
	return floatround(float(g_iVotes[choice]) * 100.0 / float(n));
}

bool:rts_match_blocked() {
	new iMode = hns_get_mode();
	if (iMode == MODE_MIX || iMode == MODE_KNIFE || iMode == MODE_LOBBY)
		return true;
	if (hns_get_status() != MATCH_NONE)
		return true;
	return false;
}

GetModeName(id, iIndex, szOut[], iLen) {
	if (iIndex < 0 || iIndex >= RTS_MODE_COUNT) {
		rts_lang(id, "RTS_MODE_UNKNOWN", szOut, iLen, "未知模式");
		return;
	}
	rts_lang(id, g_szModeKeys[iIndex], szOut, iLen, g_szModeFallback[iIndex]);
}

GetModeNameById(id, iMode, szOut[], iLen) {
	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		if (g_iModeIds[i] == iMode) {
			GetModeName(id, i, szOut, iLen);
			return;
		}
	}
	rts_lang(id, "RTS_MODE_UNKNOWN", szOut, iLen, "未知模式");
}

stock rts_unescape(szText[], iLen) {
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock rts_lang(id, const szKey[], szOut[], iLen, const szFallback[]) {
	szOut[0] = EOS;
	if (id < 1)
		id = 0;
	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0] || equal(szOut, szKey))
		copy(szOut, iLen, szFallback);
	rts_unescape(szOut, iLen);
}

stock rts_print_send(const id, const msgFormated[]) {
	if (!is_user_connected(id))
		return;
	client_print_color(id, print_team_blue, "^4%s^1 %s", g_szPrefix, msgFormated);
}

stock rts_print_lang(const id, const szKey[], const szFallback[], any:...) {
	if (id == 0) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++) {
			new szFmt[191], szOut[191];
			rts_lang(iPlayers[i], szKey, szFmt, charsmax(szFmt), szFallback);
			vformat(szOut, charsmax(szOut), szFmt, 4);
			rts_print_send(iPlayers[i], szOut);
		}
		return;
	}

	new szFmt[191], szOut[191];
	rts_lang(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, charsmax(szOut), szFmt, 4);
	rts_print_send(id, szOut);
}

/* ============================================================
   HnsModeVote 1.1
   /rts 模式投票, 走 HnsLanguage (/lang)

   规则:
   - 比赛中 (MODE_MIX / 刀局 / 大厅 / 报名流程) 禁用
   - 输入 /rts 后先 5 秒读秒, 再弹出投票菜单
   - 菜单不自动关掉, 投票过程中刷新票数
   - 当前模式显示红色 [%]
   - 可弃权 = 继续当前模式
   - 某一模式达到在线玩家 60% 后, 3 秒刷新回合切到该模式
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_matchsystem>
#include <hns_language>

#define PLUGIN_NAME    "HNS Mode Vote"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR  "GTR"

#define TASK_COUNTDOWN  53001
#define TASK_REFRESH    53002
#define TASK_APPLY      53003
#define TASK_HUD        53004

#define VOTE_NONE      -1
#define VOTE_ABSTAIN   4

#define RTS_PRE_SECONDS     5
#define RTS_NEED_PERCENT    60
#define RTS_APPLY_DELAY     3.0

#define MENU_KEYS (MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_0)

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
new g_iVotes[RTS_MODE_COUNT];
new g_iAbstain;
new g_iVoters;
new g_iPreLeft;
new bool:g_bPreCountdown;
new bool:g_bVoting;
new bool:g_bApplying;
new g_iPendingMode = -1;
new g_szPrefix[24];

public plugin_natives() {
	set_native_filter("NativeFilter");
		|| equal(szName, "HnsLang_Get")
}

public NativeFilter(const szName[], iIndex, iTrap) {
	if (equal(szName, "hns_get_mode")
		|| equal(szName, "hns_set_mode")
		|| equal(szName, "hns_get_status")
		|| equal(szName, "hns_get_prefix"))
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

public client_disconnected(id) {
	if (g_bVoting && g_iVoteChoice[id] != VOTE_NONE)
		RemoveVote(id);

	g_iVoteChoice[id] = VOTE_NONE;
	g_bMenuOpen[id] = false;

	if (g_bVoting)
		CheckWin();
}

public CmdRts(id) {
	if (!is_user_connected(id) || is_user_bot(id))
		return PLUGIN_HANDLED;

	if (rts_ma_lang(id, "RTS_MATCH_BLOCK", "比赛进行中，不能投票切换模式。");
		return PLUGIN_HANDLED;
	}

	if (g_bApplying) {
		rts_print_lang(id, "RTS_APPLYING"ng) {
		rts_print(id, "模式即将切换，请稍候。");
		return PLUGIN_HANDLED;
	}

	if (g_bVoting) {
		g_bMenuOpen[id] = true;
		ShowVoteMenu(id);
		return PLUGIN_HANDLED;
	}

	if (g_bPre_lang(id, "RTS_START_COUNTDOWN"ntdown) {
		rts_print(id, "模式投票将在 ^3%d^1 秒后开始。", g_iPreLeft);
		return PLUGIN_HANDLED;
	}

	StartPreCountdown();
	return PLUGIN_HANDLED;
}

StartPreCountdown() {
	g_bPreCountdown = true;
	g_bVoting = false;
	g_bApplying = false;
	g_iPendingMode = -1;
	g_iPreLeft = RTS_PRE_SECONDS;

	ResetVotes();

	remove_task(TASK_COUNTDOWN);
	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	remove_task(TASK_HUD);

	rts_print_lang(0, "RTS_START_COUNTDOWN", "模式投票将在 ^3%d^1 秒后开始。", g_iPreLeft);
	ShowCountdownHud();
	set_task(1.0, "TaskPreCountdown", TASK_COUNTDOWN, .flags = "b");
}

public TaskPreCountdown() {
	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_MATCH", "比赛已开始，模式投票取消。");
		return;
	}

	g_iPreLeft--;
	if (g_iPreLeft > 0) {
		rts_print_lang(0, "RTS_COUNTDOWN", "模式投票倒计时: ^3%d", g_iPreLeft);
		ShowCountdownHud();
		return;
	}

	remove_task(TASK_COUNTDOWN);
	g_bPreCountdown = false;
	BeginVote();
}

BeginVote() {
	if (rts_match_blocked()) {
		CancelAll("RTS_CANCEL_MATCH", "比赛已开始，模式投票取消。");
		return;
	}

	g_bVoting = true;
	g_bApplying = false;
	ResetVotes();

	rts_print_lang(0, "RTS_VOTE_START", "模式投票开始。某一模式达到 ^3%d%%^1 后切换。可选择弃权继续当前模式。", RTS_NEED_PERCENT);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (is_user_bot(id))
			continue;
		g_bMenuOpen[id] = true;
		ShowVoteMenu(id);
	}

	remove_task(TASK_REFRESH);
	set_task(1.0, "TaskRefreshMenus", TASK_REFRESH, .flags = "b");
}

public TaskRefreshMenus() {
	if (!g_bVoting) {
		remove_task(TASK_REFRESH);
		return;
	}

	if (rts_match_blocked()) {
		CancelAll("比赛已开始，模式投票取消。");
		return;
	}

	RefreshOpenMenus();
	CheckWin();
}

ShowVoteMenu(id) {
	if (!is_user_connected(id) || is_user_bot(id))
		return;

	new szMenu[512], len;
	new iCurrent = hns_get_mode();
	new iNeed = NeedVotes();
	new iPlayers = CountHumans();

	len = formatex(szMenu, charsmax(szMenu), "\r[HNS] 模式投票^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\w需要 \y%d%%\w (\y%d/%d\w) 切换模式^n", RTS_NEED_PERCENT, iNeed, iPlayers);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\d当前模式显示为红色 [%]^n^n");

	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		new bool:bCurrent = (g_iModeIds[i] == iCurrent);
		new bool:bMine = (g_iVoteChoice[id] == i);

		if (bCurrent)
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d. %s [%d%%]\w", i + 1, g_szModeNames[i], VotePercent(i));
		else
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\w%d. %s [%d%%]", i + 1, g_szModeNames[i], VotePercent(i));

		if (bMine)
			len += formatex(szMenu[len], charsmax(szMenu) - len, " \y<");

		len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");
	}

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");
	if (g_iVoteChoice[id] == VOTE_ABSTAIN)
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\y5. 弃权 (继续当前模式) [%d] <^n", g_iAbstain);
	else
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\w5. 弃权 (继续当前模式) [%d]^n", g_iAbstain);

	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 隐藏菜单 (投票不结束)");

	show_menu(id, MENU_KEYS, szMenu, -1, "HNS RTS Vote");
}

public HandleVoteMenu(id, key) {
	if (!g_bVoting) {
		g_bMenuOpen[id] = false;
		return PLUGIN_HANDLED;
	}

	if (key == 9) {
		g_bMenuOpen[id] = false;
		rts_print(id, "菜单已隐藏，输入 ^3/rts^1 可重新打开。投票不会结束。");
		return PLUGIN_HANDLED;
	}

	g_bMenuOpen[id] = true;

	if (key >= 0 && key <= 3) {
		SetVote(id, key);
	} else if (key == 4) {
		SetVote(id, VOTE_ABSTAIN);
	}

	ShowVoteMenu(id);
	CheckWin();
	return PLUGIN_HANDLED;
}

SetVote(id, choice) {
	if (g_iVoteChoice[id] == choice)
		return;

	RemoveVote(id);
	g_iVoteChoice[id] = choice;

	if (choice == VOTE_ABSTAIN) {
		g_iAbstain++;
		g_iVoters++;
		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		rts_print(0, "^3%s^1 选择弃权，继续当前模式。", szName);
	} else if (choice >= 0 && choice < RTS_MODE_COUNT) {
		g_iVotes[choice]++;
		g_iVoters++;
		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		rts_print(0, "^3%s^1 投票给 ^3%s^1 (%d%%)。", szName, g_szModeNames[choice], VotePercent(choice));
	}

	RefreshOpenMenus();
}

RemoveVote(id) {
	new old = g_iVoteChoice[id];
	if (old == VOTE_NONE)
		return;

	if (old == VOTE_ABSTAIN) {
		if (g_iAbstain > 0)
			g_iAbstain--;
	} else if (old >= 0 && old < RTS_MODE_COUNT) {
		if (g_iVotes[old] > 0)
			g_iVotes[old]--;
	}

	if (g_iVoters > 0)
		g_iVoters--;

	g_iVoteChoice[id] = VOTE_NONE;
}

CheckWin() {
	if (!g_bVoting || g_bApplying)
		return;

	new iNeed = NeedVotes();
	if (iNeed < 1)
		iNeed = 1;

	new iBest = -1;
	new iBestVotes = 0;
	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		if (g_iVotes[i] > iBestVotes) {
			iBestVotes = g_iVotes[i];
			iBest = i;
		}
	}

	if (iBest == -1 || iBestVotes < iNeed)
		return;

	StartApply(g_iModeIds[iBest], g_szModeNames[iBest]);
}

StartApply(iMode, const szName[]) {
	g_bVoting = false;
	g_bApplying = true;
	g_iPendingMode = iMode;

	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	CloseAllMenus();

	if (iMode == hns_get_mode()) {
		rts_print(0, "^3%s^1 已达 ^3%d%%^1，当前已经是该模式。", szName, RTS_NEED_PERCENT);
		g_bApplying = false;
		g_iPendingMode = -1;
		ResetVotes();
		return;
	}

	rts_print(0, "^3%s^1 已达 ^3%d%%^1，^3%.0f^1 秒后刷新回合切换。", szName, RTS_NEED_PERCENT, RTS_APPLY_DELAY);
	set_hudmessage(0, 255, 80, -1.0, 0.28, 0, 0.0, 3.0, 0.1, 0.1, -1);
	show_hudmessage(0, "即将切换到 %s", szName);
	set_task(RTS_APPLY_DELAY, "TaskApplyMode", TASK_APPLY);
}

public TaskApplyMode() {
	if (!g_bApplying)
		return;

	if (rts_match_blocked()) {
		CancelAll("比赛已开始，模式切换取消。");
		return;
	}

	new iMode = g_iPendingMode;
	g_bApplying = false;
	g_iPendingMode = -1;
	ResetVotes();

	if (iMode < 0)
		return;

	hns_set_mode(iMode);

	new szName[32];
	GetModeName(iMode, szName, charsmax(szName));
	rts_print(0, "已切换到 ^3%s^1。", szName);
}

CancelAll(const szReason[]) {
	g_bPreCountdown = false;
	g_bVoting = false;
	g_bApplying = false;
	g_iPendingMode = -1;
	g_iPreLeft = 0;

	remove_task(TASK_COUNTDOWN);
	remove_task(TASK_REFRESH);
	remove_task(TASK_APPLY);
	remove_task(TASK_HUD);

	CloseAllMenus();
	ResetVotes();
	rts_print(0, "%s", szReason);
}

ResetVotes() {
	arrayset(g_iVotes, 0, sizeof(g_iVotes));
	g_iAbstain = 0;
	g_iVoters = 0;
	for (new i = 1; i <= MaxClients; i++)
		g_iVoteChoice[i] = VOTE_NONE;
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
	set_hudmessage(255, 40, 40, -1.0, 0.28, 0, 0.0, 1.1, 0.0, 0.1, -1);
	show_hudmessage(0, "模式投票倒计时 %d", g_iPreLeft);
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

NeedVotes() {
	new n = CountHumans();
	new need = floatround(float(n) * float(RTS_NEED_PERCENT) / 100.0, floatround_ceil);
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

GetModeName(iMode, szOut[], iLen) {
	for (new i = 0; i < RTS_MODE_COUNT; i++) {
		if (g_iModeIds[i] == iMode) {
			copy(szOut, iLen, g_szModeNames[i]);
			return;
		}
	}
	copy(szOut, iLen, "未知模式");
}

rts_print(id, const szFmt[], any:...) {
	new szMsg[191];
	vformat(szMsg, charsmax(szMsg), szFmt, 3);

	if (id) {
		client_print_color(id, print_team_default, "^4%s^1 %s", g_szPrefix, szMsg);
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++)
		client_print_color(iPlayers[i], print_team_default, "^4%s^1 %s", g_szPrefix, szMsg);
}

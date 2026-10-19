#include <amxmodx>
#include <amxmisc>

#define DEMO_TASK 24000

new bool:g_bRecording;
new g_szDemo[48];
new g_pCvar;

public plugin_init() {
	register_plugin("HNS Match Demo", "1.0", "gtr");
	g_pCvar = register_cvar("hns_match_demo", "1");
}

public plugin_end() {
	demo_end(false);
}

public hns_match_started() {
	if (!get_pcvar_num(g_pCvar))
		return;

	demo_begin();
}

public hns_match_finished(iWinTeam) {
	#pragma unused iWinTeam
	demo_end(true);
}

public hns_match_canceled() {
	demo_end(true);
}

public client_putinserver(id) {
	if (!g_bRecording || !get_pcvar_num(g_pCvar))
		return;

	if (!demo_is_player(id))
		return;

	set_task(1.0, "task_record_one", DEMO_TASK + id);
}

public client_disconnected(id) {
	remove_task(DEMO_TASK + id);
}

stock demo_begin() {
	if (g_bRecording)
		demo_end(false);

	new szMap[20], szDate[16], szTime[8];
	get_mapname(szMap, charsmax(szMap));
	get_time("%Y%m%d", szDate, charsmax(szDate));
	get_time("%H%M%S", szTime, charsmax(szTime));
	formatex(g_szDemo, charsmax(g_szDemo), "hns_%s_%s_%s", szMap, szDate, szTime);
	replace_all(g_szDemo, charsmax(g_szDemo), " ", "_");

	g_bRecording = true;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		client_cmd(id, "stop");
		set_task(0.5, "task_record_one", DEMO_TASK + id);
	}

	client_print_color(0, print_team_red, "^4[HNS]^1 比赛Demo开始录制: ^3%s.dem^1 ，保存在你自己的cstrike目录", g_szDemo);
}

stock demo_end(bool:bNotify) {
	if (!g_bRecording)
		return;

	g_bRecording = false;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		remove_task(DEMO_TASK + id);
		client_cmd(id, "stop");
	}

	if (bNotify && g_szDemo[0])
		client_print_color(0, print_team_red, "^4[HNS]^1 比赛Demo已停止: ^3%s.dem", g_szDemo);
}

public task_record_one(id) {
	id -= DEMO_TASK;
	if (!g_bRecording || !demo_is_player(id))
		return;

	client_cmd(id, "record %s", g_szDemo);
}

stock bool:demo_is_player(id) {
	return is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id);
}

#include <amxmodx>
#include <amxmisc>
#include <sockets>

#define HLTV_TASK_POLL 24050
#define HLTV_TASK_RECORD 24051
#define HLTV_TASK_STOP 24052

new g_szDemo[48];
new g_pEnable;
new g_pIp;
new g_pPort;
new g_pRcon;
new g_pStopDelay;
new g_iSock;
new g_szCmd[64];
new g_iPolls;
new bool:g_bRecordNext;
new bool:g_bLive;

public plugin_init() {
	register_plugin("HNS Match HLTV Demo", "1.0", "gtr");

	g_pEnable = register_cvar("hns_hltv_demo", "1");
	g_pIp = register_cvar("hns_hltv_ip", "127.0.0.1");
	g_pPort = register_cvar("hns_hltv_port", "27020");
	g_pRcon = register_cvar("hns_hltv_rcon", "");
	g_pStopDelay = register_cvar("hns_hltv_stop_delay", "0");
}

public plugin_cfg() {
	new szPath[160];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/hns_hltv_demo.cfg");

	if (file_exists(szPath))
		server_cmd("exec %s", szPath);
}

public hns_match_started() {
	if (!get_pcvar_num(g_pEnable))
		return;

	if (!hltv_has_password()) {
		log_amx("[HNS Demo] HLTV public demo skipped. Set hns_hltv_rcon to the HLTV rcon_password.");
		return;
	}

	hltv_begin();
}

public hns_match_finished(iWinTeam) {
	#pragma unused iWinTeam
	hltv_end();
}

public hns_match_canceled() {
	hltv_end();
}

stock bool:hltv_has_password() {
	new szPass[64];
	get_pcvar_string(g_pRcon, szPass, charsmax(szPass));
	return szPass[0] != 0;
}

stock hltv_begin() {
	remove_task(HLTV_TASK_RECORD);
	remove_task(HLTV_TASK_STOP);

	new szMap[20], szDate[16], szTime[8];
	get_mapname(szMap, charsmax(szMap));
	get_time("%Y%m%d", szDate, charsmax(szDate));
	get_time("%H%M%S", szTime, charsmax(szTime));
	formatex(g_szDemo, charsmax(g_szDemo), "hns_%s_%s_%s", szMap, szDate, szTime);
	replace_all(g_szDemo, charsmax(g_szDemo), " ", "_");

	g_bLive = true;
	g_bRecordNext = true;
	hltv_send("stop");
}

stock hltv_end() {
	remove_task(HLTV_TASK_RECORD);
	g_bRecordNext = false;

	if (!g_bLive)
		return;

	g_bLive = false;

	new Float:fDelay = get_pcvar_float(g_pStopDelay);
	if (fDelay > 0.5)
		set_task(fDelay, "task_hltv_stop", HLTV_TASK_STOP);
	else
		hltv_send("stop");
}

public task_hltv_record() {
	if (!g_bLive)
		return;

	new szCmd[64];
	formatex(szCmd, charsmax(szCmd), "record %s", g_szDemo);
	hltv_send(szCmd);
}

public task_hltv_stop() {
	hltv_send("stop");
}

stock hltv_send(const szCmd[]) {
	if (g_iSock > 0) {
		socket_close(g_iSock);
		g_iSock = 0;
	}

	remove_task(HLTV_TASK_POLL);
	copy(g_szCmd, charsmax(g_szCmd), szCmd);

	new szIp[32], iErr;
	get_pcvar_string(g_pIp, szIp, charsmax(szIp));
	new iPort = get_pcvar_num(g_pPort);
	if (iPort <= 0)
		iPort = 27020;

	g_iSock = socket_open(szIp, iPort, SOCKET_UDP, iErr, SOCK_NON_BLOCKING);
	if (g_iSock <= 0) {
		log_amx("[HNS Demo] HLTV socket failed %s:%d (%d)", szIp, iPort, iErr);
		g_bRecordNext = false;
		return;
	}

	new szPkt[64];
	formatex(szPkt, charsmax(szPkt), "%c%c%c%cchallenge rcon^n", 255, 255, 255, 255);
	socket_send(g_iSock, szPkt, strlen(szPkt));

	g_iPolls = 0;
	set_task(0.1, "task_hltv_poll", HLTV_TASK_POLL);
}

public task_hltv_poll() {
	if (g_iSock <= 0)
		return;

	if (!socket_is_readable(g_iSock, 0)) {
		if (++g_iPolls < 20) {
			set_task(0.1, "task_hltv_poll", HLTV_TASK_POLL);
			return;
		}

		log_amx("[HNS Demo] HLTV did not answer. Check that HLTV is running, and hns_hltv_ip / hns_hltv_port.");
		socket_close(g_iSock);
		g_iSock = 0;
		g_bRecordNext = false;
		return;
	}

	new szData[256];
	new iLen = socket_recv(g_iSock, szData, charsmax(szData));
	if (iLen <= 0) {
		socket_close(g_iSock);
		g_iSock = 0;
		g_bRecordNext = false;
		return;
	}

	new iPos = strfind(szData, "rcon ");
	if (iPos < 0) {
		socket_close(g_iSock);
		g_iSock = 0;
		log_amx("[HNS Demo] HLTV challenge reply was not recognized.");
		g_bRecordNext = false;
		return;
	}

	new iChallenge = str_to_num(szData[iPos + 5]);
	new szPass[64], szPkt[192];
	get_pcvar_string(g_pRcon, szPass, charsmax(szPass));
	formatex(szPkt, charsmax(szPkt), "%c%c%c%crcon %d ^"%s^" %s^n", 255, 255, 255, 255, iChallenge, szPass, g_szCmd);
	socket_send(g_iSock, szPkt, strlen(szPkt));
	socket_close(g_iSock);
	g_iSock = 0;

	new bool:bThenRecord = g_bRecordNext;
	g_bRecordNext = false;

	if (g_szCmd[0] == 'r')
		client_print_color(0, print_team_red, "^4[HNS]^1 公共Demo已开始: ^3%s.dem^1 ，文件在HLTV运行目录", g_szDemo);
	else if (!bThenRecord && g_szDemo[0])
		client_print_color(0, print_team_red, "^4[HNS]^1 公共Demo已停止: ^3%s.dem", g_szDemo);

	if (bThenRecord)
		set_task(0.3, "task_hltv_record", HLTV_TASK_RECORD);
}

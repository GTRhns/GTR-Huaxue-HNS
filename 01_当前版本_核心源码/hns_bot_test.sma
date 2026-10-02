/* hns_bot_test.sma
 * 测试辅助插件: 创建假客户端(bot)模拟玩家进服, 触发HNS比赛流程
 * 用法: say /makebots  -> 创建4个bot (2 CT + 2 TT)
 */
#include <amxmodx>
#include <fakemeta>
#include <fakemeta_stocks>
#include <cstrike>
#include <reapi>
#include <hns_matchsystem>

#pragma semicolon 1

new g_iBots;
new g_iStep;
new g_szBotNames[4][] = {
	"BotAlpha", "BotBravo", "BotCharlie", "BotDelta"
};

public plugin_init() {
	register_plugin("HNS Bot Test", "1.0", "Test");
	register_clcmd("say /makebots", "cmdMakeBots");
	register_clcmd("say /killbots", "cmdKillBots");
	register_clcmd("say /botstatus", "cmdBotStatus");
	register_concmd("makebots", "cmdMakeBots");
	register_concmd("killbots", "cmdKillBots");
	register_concmd("botstatus", "cmdBotStatus");
	register_concmd("triggermatch", "cmdTriggerMatch");
	register_concmd("matchstatus", "cmdMatchStatus");
}

public cmdMakeBots(id) {
	log_amx("[BOTTEST] Creating 4 bots (triggered by id=%d)...", id);
	for (new i = 0; i < 4; i++) {
		new ent = EF_CreateFakeClient(g_szBotNames[i]);
		if (ent) {
			new player = get_user_index(g_szBotNames[i]);
			if (player) {
				// 让bot进入服务器
				dllfunc(DLLFunc_ClientPutInServer, player);
				// 分配队伍: 前2个CT, 后2个TT
				if (i < 2) {
					rg_set_user_team(player, TEAM_CT);
				} else {
					rg_set_user_team(player, TEAM_TERRORIST);
				}
				log_amx("[BOTTEST] Created bot %s (id=%d)", g_szBotNames[i], player);
			} else {
				log_amx("[BOTTEST] WARN: %s created but index not found", g_szBotNames[i]);
			}
		} else {
			log_amx("[BOTTEST] FAIL: cannot create fake client %s", g_szBotNames[i]);
		}
	}
	g_iBots = 4;
	log_amx("[BOTTEST] Done. Bots: %d", g_iBots);
	return PLUGIN_HANDLED;
}

public cmdKillBots(id) {
	new iCount = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i)) {
			// 踢掉bot (名字前缀是Bot的)
			new szName[32];
			get_user_name(i, szName, charsmax(szName));
			if (strncmp(szName, "Bot", 3) == 0) {
				server_cmd("kick #%d", get_user_userid(i));
				iCount++;
			}
		}
	}
	log_amx("[BOTTEST] Kicked %d bots", iCount);
	return PLUGIN_HANDLED;
}

public cmdTriggerMatch(id) {
	// 模拟玩家通过 say 触发 HNS 比赛命令 (clcmd 需要玩家身份)
	new iPlayer = 0;
	// 找第一个在线的 bot 当"管理员"
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i)) {
			iPlayer = i;
			break;
		}
	}
	if (!iPlayer) {
		log_amx("[BOTTEST] No players to trigger match!");
		return PLUGIN_HANDLED;
	}

	log_amx("[BOTTEST] === Triggering match via player %d ===", iPlayer);

	// 先确保处于训练模式 (vault 可能恢复为其他模式如 DM)
	hns_set_mode(MODE_TRAINING);
	log_amx("[BOTTEST] Switched to TRAINING mode");

	// 分步触发: 每步延迟2s
	client_cmd(iPlayer, "say /mr");
	set_task(2.0, "task_match_step", 1, _, _, "t", iPlayer);
	return PLUGIN_HANDLED;
}

public task_match_step(id) {
	switch (g_iStep++) {
		case 0: client_cmd(id, "say /kniferound");
		case 1: hns_begin_external_match(false, id);  // 开始正式比赛 (mix_start)
		case 2: client_cmd(id, "say /rr");
		case 3: client_cmd(id, "say /save");
		case 4: client_cmd(id, "say /score");
		case 5: client_cmd(id, "say /stop");
		case 6: {
			log_amx("[BOTTEST] === Match trigger sequence complete ===");
			g_iStep = 0;
			return;
		}
	}
	// 每步后记录 HNS 状态
	cmdMatchStatus(id);
	set_task(2.0, "task_match_step", _, _, _, "t", id);
}

public cmdBotStatus(id) {
	new iNum = 0;
	log_amx("[BOTTEST] ===== Player status =====");
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i)) {
			new szName[32], szTeam[16];
			get_user_name(i, szName, charsmax(szName));
			new iTeam = get_user_team(i);
			switch (iTeam) {
				case 1: szTeam = "TT";
				case 2: szTeam = "CT";
				case 3: szTeam = "SPEC";
				default: szTeam = "NONE";
			}
			log_amx("[BOTTEST]  #%d %s team=%s", i, szName, szTeam);
			iNum++;
		}
	}
	log_amx("[BOTTEST] Total connected: %d", iNum);
	return PLUGIN_HANDLED;
}

// 查询 HNS 比赛系统当前状态 (验证比赛命令是否真正生效)
public cmdMatchStatus(id) {
	new iMode = hns_get_mode();
	new iStatus = hns_get_status();
	new iState = hns_get_state();
	new iRules = hns_get_rules();

	new szMode[24], szStatus[24], szState[24], szRules[16];
	switch (iMode) {
		case MODE_TRAINING: szMode = "TRAINING";
		case MODE_LOBBY:    szMode = "LOBBY";
		case MODE_KNIFE:    szMode = "KNIFE";
		case MODE_PUB:      szMode = "PUB";
		case MODE_DM:       szMode = "DM";
		case MODE_ZM:       szMode = "ZM";
		case MODE_MIX:      szMode = "MIX";
		default:            szMode = "UNKNOWN";
	}
	switch (iStatus) {
		case MATCH_NONE:        szStatus = "NONE";
		case MATCH_CAPTAINPICK: szStatus = "CAPTAINPICK";
		case MATCH_CAPTAINKNIFE:szStatus = "CAPTAINKNIFE";
		case MATCH_TEAMPICK:    szStatus = "TEAMPICK";
		case MATCH_TEAMKNIFE:   szStatus = "TEAMKNIFE";
		case MATCH_MAPPICK:     szStatus = "MAPPICK";
		case MATCH_WAITCONNECT: szStatus = "WAITCONNECT";
		case MATCH_STARTED:     szStatus = "STARTED";
		default:                szStatus = "UNKNOWN";
	}
	switch (iState) {
		case STATE_DISABLED: szState = "DISABLED";
		case STATE_PREPARE:  szState = "PREPARE";
		case STATE_PAUSED:   szState = "PAUSED";
		case STATE_ENABLED:  szState = "ENABLED";
		default:             szState = "UNKNOWN";
	}
	switch (iRules) {
		case RULES_MR:    szRules = "MR";
		case RULES_TIMER: szRules = "TIMER";
		case RULES_DUEL:  szRules = "DUEL";
		default:          szRules = "UNKNOWN";
	}

	log_amx("[BOTTEST] HNS status => mode=%s(%d) status=%s(%d) state=%s(%d) rules=%s(%d)",
		szMode, iMode, szStatus, iStatus, szState, iState, szRules, iRules);
	return PLUGIN_HANDLED;
}

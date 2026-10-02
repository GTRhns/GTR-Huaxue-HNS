#include <amxmodx>
#include <amxmisc>
#include <hns_matchsystem>
#include <hns_matchsystem_maps>
#include <hns_language>

#define PLUGIN	"RockTheVote"
#define AUTHOR	"DA"
#define VERSION	"2.0"

#define MAX_MAPS 5
#define MAX_MAP_LENGTH 64
#define RTV_REQUIRED_PERCENT 70
#define TASK_RTV_MENU_COUNTDOWN 7201
#define TASK_RTV_SELECT 7202
#define TASK_RTV_COUNTDOWN 7203
#define TASK_RTV_CHANGELEVEL 7204

new rtv[33], keycount[MAX_MAPS], s_Maps[MAX_MAPS][MAX_MAP_LENGTH], count;
new presskeys, timevote;
new nextmap[MAX_MAP_LENGTH];
new g_iVoteMaps;
new g_iVotePlayers;
new bool:g_bMapChangePending = false;
new bool:g_bVoteMenuCountdown = false;
new g_iMapSeconds = 7200;
new bool:g_bTimeExtended = false;
new g_iChangeCountdown;
new g_iVoteMenuCountdown;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say", "rockthevote");
	register_clcmd("say_team", "rockthevote");
	register_menu("Chose your Map", 1023, "gonna_chose");
	timevote = register_cvar("amx_timevote", "10");

	register_logevent("RoundStart", 2, "1=Round_Start");

	for (new i = 0; i < 7; i++)
		presskeys = presskeys | (1 << i);
}

public client_disconnected(id)
{
	if (rtv[id - 1] == id)
	{
		rtv[id - 1] = 0;
		if (count > 0)
			count--;
	}
}

public RoundStart()
{
	return;
}

public rockthevote(id)
{
	new said[192];
	read_args(said, charsmax(said));
	remove_quotes(said);

	if (containi(said, "/rockthevote") == -1 && containi(said, "rockthevote") == -1 && !equali(said, "rtv") && !equali(said, "/rtv"))
		return PLUGIN_CONTINUE;

	if (rtv_match_blocked())
	{
		rtv_print_lang(id, "RTV_MATCH_BLOCK", "比赛进行中，禁止换图投票。");
		return PLUGIN_HANDLED;
	}

	if (get_gametime() < get_pcvar_float(timevote))
	{
		rtv_print_lang(id, "RTV_WAIT", "换图投票暂不可用，请再等 %d 秒。", floatround(get_pcvar_float(timevote) - get_gametime()));
		return PLUGIN_HANDLED;
	}

	if (rtv[id - 1] == id)
	{
		rtv_print_lang(id, "RTV_ALREADY", "你已经投过票了！");
		return PLUGIN_HANDLED;
	}

	if (g_bVoteMenuCountdown)
	{
		rtv_print_lang(id, "RTV_START_COUNTDOWN", "地图投票将在 %d 秒后开始。", g_iVoteMenuCountdown);
		return PLUGIN_HANDLED;
	}

	rtv[id - 1] = id;
	count++;

	new num = floatround(float(get_playersnum()) * float(RTV_REQUIRED_PERCENT) / 100.0, floatround_ceil);
	if (num < 1)
		num = 1;

	if (count >= num)
	{
		StartTheVote();
		return PLUGIN_HANDLED;
	}

	new name[32];
	get_user_name(id, name, charsmax(name));
	rtv_print_lang(0, "RTV_VOTED", "玩家 %s 的投票已计入。需要在线玩家的 %d%%。", name, RTV_REQUIRED_PERCENT);
	return PLUGIN_HANDLED;
}

public gonna_chose(id, key)
{
	if (key == 5)
	{
		if (g_bTimeExtended)
		{
			rtv_print_lang(id, "RTV_TIME_EXTENDED", "本张地图已经续过时间了。");
			return;
		}

		g_iMapSeconds += 1200;
		g_bTimeExtended = true;
		rtv_print_lang(0, "RTV_TIME_EXTENDED", "当前地图已延长 20 分钟。");
		rtv_print_time_remaining();
		return;
	}

	if (key == 6)
		return;

	if (key < g_iVoteMaps && !g_bMapChangePending)
	{
		keycount[key]++;
		new iVotePercent = rtv_vote_percent(key);
		new name[32];
		get_user_name(id, name, charsmax(name));
		rtv_print_lang(0, "RTV_X_CHOSE_X", "%s 选择了 %s [%d%%]", name, s_Maps[key], iVotePercent);
	}
}

StartTheVote()
{
	if (rtv_match_blocked())
	{
		rtv_print_lang(0, "RTV_MATCH_BLOCK", "比赛进行中，禁止换图投票。");
		return PLUGIN_CONTINUE;
	}

	if (!RetrieveMaps(s_Maps))
	{
		rtv_print_lang(0, "RTV_NO_MAPS", "地图池为空，无法开始换图投票。");
		return PLUGIN_CONTINUE;
	}

	count = 0;
	g_iVotePlayers = get_playersnum();
	if (g_iVotePlayers < 1)
		g_iVotePlayers = 1;

	for (new i = 0; i < MAX_MAPS; i++)
		keycount[i] = 0;

	client_cmd(0, "spk Gman/Gman_Choose2");
	g_bVoteMenuCountdown = true;
	g_iVoteMenuCountdown = 3;
	rtv_print_lang(0, "RTV_START_COUNTDOWN", "地图投票将在 %d 秒后开始。", g_iVoteMenuCountdown);
	remove_task(TASK_RTV_MENU_COUNTDOWN);
	set_task(1.0, "rtv_menu_countdown", TASK_RTV_MENU_COUNTDOWN, .flags = "b");
	remove_task(TASK_RTV_SELECT);
	return PLUGIN_CONTINUE;
}

public rtv_menu_countdown()
{
	if (!g_bVoteMenuCountdown)
	{
		remove_task(TASK_RTV_MENU_COUNTDOWN);
		return;
	}

	g_iVoteMenuCountdown--;
	if (g_iVoteMenuCountdown > 0)
	{
		rtv_print_lang(0, "RTV_START_COUNTDOWN", "地图投票将在 %d 秒后开始。", g_iVoteMenuCountdown);
		return;
	}

	remove_task(TASK_RTV_MENU_COUNTDOWN);
	g_bVoteMenuCountdown = false;
	rtv_print_lang(0, "RTV_TIME_CHOOSE", "请选择下一张地图。");
	rtv_show_vote_menu();
	remove_task(TASK_RTV_SELECT);
	set_task(10.0, "change_map", TASK_RTV_SELECT);
}

bool:RetrieveMaps(s_MapsFound[][])
{
	new s_CurrentMap[MAX_MAP_LENGTH];
	get_mapname(s_CurrentMap, charsmax(s_CurrentMap));

	new i_Cnt;
	new szMap[MAX_MAP_LENGTH];

	new iNominated = hnsmatch_maps_get_nominated_count();
	for (new i = 0; i < iNominated && i_Cnt < MAX_MAPS; i++)
	{
		if (!hnsmatch_maps_get_nominated(i, szMap, charsmax(szMap)))
			continue;
		if (equali(szMap, s_CurrentMap) || !is_map_valid(szMap))
			continue;
		if (rtv_list_contains(s_MapsFound, i_Cnt, szMap))
			continue;

		copy(s_MapsFound[i_Cnt], MAX_MAP_LENGTH - 1, szMap);
		i_Cnt++;
	}

	new Array:a_Maps = ArrayCreate(MAX_MAP_LENGTH);
	new iPool = hnsmatch_maps_get_pool_count();
	for (new i = 0; i < iPool; i++)
	{
		if (!hnsmatch_maps_get_pool(i, szMap, charsmax(szMap)))
			continue;
		if (equali(szMap, s_CurrentMap) || !is_map_valid(szMap))
			continue;
		if (rtv_list_contains(s_MapsFound, i_Cnt, szMap))
			continue;

		ArrayPushString(a_Maps, szMap);
	}

	while (i_Cnt < MAX_MAPS && ArraySize(a_Maps) > 0)
	{
		new i_Rand = random_num(0, ArraySize(a_Maps) - 1);
		ArrayGetString(a_Maps, i_Rand, szMap, charsmax(szMap));
		ArrayDeleteItem(a_Maps, i_Rand);

		if (equali(szMap, s_CurrentMap) || rtv_list_contains(s_MapsFound, i_Cnt, szMap))
			continue;

		copy(s_MapsFound[i_Cnt], MAX_MAP_LENGTH - 1, szMap);
		i_Cnt++;
	}

	ArrayDestroy(a_Maps);

	g_iVoteMaps = i_Cnt;
	return i_Cnt > 0;
}

public change_map()
{
	if (rtv_match_blocked())
	{
		g_bMapChangePending = false;
		rtv_print_lang(0, "RTV_MATCH_BLOCK", "比赛进行中，禁止换图投票。");
		return;
	}

	new keypuffer;
	for (new i = 0; i < g_iVoteMaps; i++)
	{
		if (keycount[i] > keycount[keypuffer])
			keypuffer = i;
	}

	if (g_iVoteMaps > 0)
		copy(nextmap, charsmax(nextmap), s_Maps[keypuffer]);

	if (!nextmap[0])
		return;

	log_amx("Map will be changed to %s.", nextmap);
	rtv_print_lang(0, "RTV_CHO_FIN_NEXT", "下一张地图: %s", nextmap);

	g_bMapChangePending = true;
	g_iChangeCountdown = 5;
	set_task(1.0, "rtv_countdown", TASK_RTV_COUNTDOWN, .flags = "b");
}

public rtv_countdown()
{
	if (!g_bMapChangePending || !nextmap[0])
	{
		remove_task(TASK_RTV_COUNTDOWN);
		return;
	}

	if (g_iChangeCountdown > 0)
	{
		new const szVoice[][] = { "", "one", "two", "three", "four", "five" };
		client_cmd(0, "spk ^"vox/%s^"", szVoice[g_iChangeCountdown]);
		client_print_color(0, print_team_default, "^4[RTV]^1 %d 秒后换图到 ^3%s^1", g_iChangeCountdown, nextmap);
		g_iChangeCountdown--;
		return;
	}

	remove_task(TASK_RTV_COUNTDOWN);
	execute_map_change();
}

public execute_map_change()
{
	if (!g_bMapChangePending || !nextmap[0])
		return;

	g_bMapChangePending = false;
	if (rtv_match_blocked())
	{
		rtv_print_lang(0, "RTV_MATCH_BLOCK", "比赛进行中，禁止换图投票。");
		return;
	}

	if (!is_map_valid(nextmap))
	{
		log_amx("RTV refused invalid map: %s", nextmap);
		rtv_print_lang(0, "RTV_NO_MAPS", "目标地图无效，取消换图。\");
		return;
	}

	remove_task(TASK_RTV_CHANGELEVEL);
	set_task(0.2, "rtv_do_changelevel", TASK_RTV_CHANGELEVEL);
}

public rtv_do_changelevel()
{
	if (rtv_match_blocked() || !nextmap[0] || !is_map_valid(nextmap))
	{
		g_bMapChangePending = false;
		return;
	}

	log_amx("RTV executing delayed changelevel to %s.", nextmap);
	server_cmd("changelevel %s", nextmap);
}

stock rtv_vote_percent(const iMap)
{
	if (g_iVotePlayers <= 0)
		return 0;

	return floatround(float(keycount[iMap]) * 100.0 / float(g_iVotePlayers));
}

stock bool:rtv_match_blocked()
{
	// MODE_MIX also covers the pre-match lobby. Only an active match blocks RTV.
	if (hns_get_status() != MATCH_NONE)
		return true;
	return false;
}

stock bool:rtv_list_contains(s_MapsFound[][], iCount, const szMap[])
{
	for (new i = 0; i < iCount; i++)
	{
		if (equali(s_MapsFound[i], szMap))
			return true;
	}
	return false;
}

stock rtv_unescape(szText[], iLen)
{
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^2", "^2");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock rtv_lang(id, const szKey[], szOut[], iLen, const szFallback[])
{
	if (id < 1)
		id = 0;

	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0] || equal(szOut, szKey))
		copy(szOut, iLen, szFallback);
	rtv_unescape(szOut, iLen);
}

stock rtv_print_send(const id, const msgFormated[])
{
	if (!is_user_connected(id))
		return;

	client_print_color(id, print_team_blue, "[^3RTV^1] %s", msgFormated);
}

stock rtv_print_lang(const id, const szKey[], const szFallback[], any:...)
{
	if (id == 0)
	{
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++)
		{
			new szFmt[191], szOut[191];
			rtv_lang(iPlayers[i], szKey, szFmt, charsmax(szFmt), szFallback);
			vformat(szOut, charsmax(szOut), szFmt, 4);
			rtv_print_send(iPlayers[i], szOut);
		}
		return;
	}

	new szFmt[191], szOut[191];
	rtv_lang(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, charsmax(szOut), szFmt, 4);
	rtv_print_send(id, szOut);
}

stock rtv_show_vote_menu()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new p = 0; p < iNum; p++)
	{
		new id = iPlayers[p];
		new szTitle[64], szNone[32], szMenu[256];
		rtv_lang(id, "RTV_CHOOSE_NEXT", szTitle, charsmax(szTitle), "选择下一张地图");
		rtv_lang(id, "RTV_NONE", szNone, charsmax(szNone), "不换图");

		formatex(szMenu, charsmax(szMenu), "\y%s:\w^n^n", szTitle);
		for (new i = 0; i < g_iVoteMaps; i++)
			formatex(szMenu, charsmax(szMenu), "%s%d. %s [%d%%]^n", szMenu, i + 1, s_Maps[i], rtv_vote_percent(i));

		formatex(szMenu, charsmax(szMenu), "%s^n6. 延迟地图: 当前地图 [%d%%] %s^n7. 下一张地图: %s", szMenu, g_bTimeExtended ? 100 : 0, g_bTimeExtended ? "(已延长)" : "", nextmap[0] ? nextmap : "待选择");
		show_menu(id, presskeys, szMenu, 15, "Chose your Map");
	}
}

stock rtv_print_time_remaining()
{
	new szMap[MAX_MAP_LENGTH], szTime[32];
	get_mapname(szMap, charsmax(szMap));
	formatex(szTime, charsmax(szTime), "%d分%d秒", g_iMapSeconds / 60, g_iMapSeconds % 60);
	client_print_color(0, print_team_default, "^4[HNS]^1 当前地图%s还有 %s 时间", szMap, szTime);
}


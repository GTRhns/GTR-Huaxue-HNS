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

new rtv[33], howmanyvotes, task_time, keycount[MAX_MAPS], s_Maps[MAX_MAPS][MAX_MAP_LENGTH], count;
new presskeys, howmanyvotesperc, timevote, directmapchange;
new bool:NextRoundChangeMap = false;
new nextmap[MAX_MAP_LENGTH];
new g_iVoteMaps;
new bool:g_bMapChangePending = false;
new g_iMapSeconds = 7200;
new bool:g_bTimeExtended = false;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say", "rockthevote");
	register_clcmd("say_team", "rockthevote");
	register_menu("Chose your Map", 1023, "gonna_chose");
	howmanyvotes = register_cvar("amx_howmanyvotes", "8");
	howmanyvotesperc = register_cvar("amx_howmanypercentage", "0.30");
	task_time = register_cvar("amx_rocktime", "5.0");
	timevote = register_cvar("amx_timevote", "10");
	directmapchange = register_cvar("amx_directmapchange", "0");

	register_logevent("RoundStart", 2, "1=Round_Start");
	set_task(1.0, "map_clock", 7201, .flags = "b");

	for (new i = 0; i < MAX_MAPS + 3; i++)
		presskeys = presskeys | (1 << i);
}

public map_clock()
{
	if (g_iMapSeconds > 0)
		g_iMapSeconds--;

	if (g_iMapSeconds > 0 && (g_iMapSeconds % 600) == 0)
		rtv_print_time_remaining();

	if (g_iMapSeconds > 0 || rtv_match_blocked() || g_bMapChangePending)
		return;

	if (!RetrieveMaps(s_Maps))
		return;

	copy(nextmap, charsmax(nextmap), s_Maps[random_num(0, g_iVoteMaps - 1)]);
	if (!nextmap[0])
		return;

	log_amx("Automatic random map change to %s.", nextmap);
	server_cmd("changelevel %s", nextmap);
	server_exec();
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

	rtv[id - 1] = id;
	count++;

	new num = get_playersnum();
	num = floatround(get_pcvar_float(howmanyvotesperc) * float(num));
	if (num < 1)
		num = 1;

	if (count >= num || count >= get_pcvar_num(howmanyvotes))
	{
		StartTheVote();
		return PLUGIN_HANDLED;
	}

	new name[32];
	get_user_name(id, name, charsmax(name));
	rtv_print_lang(0, "RTV_VOTED", "玩家 %s 的投票已计入。需要 %d 票，或达到在线人数的 %d%%。", name, get_pcvar_num(howmanyvotes), floatround(get_pcvar_float(howmanyvotesperc) * 100.0));
	return PLUGIN_HANDLED;
}

public gonna_chose(id, key)
{
	if (key == 7)
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

	if (key < g_iVoteMaps)
	{
		keycount[key]++;
		new name[32];
		get_user_name(id, name, charsmax(name));
		rtv_print_lang(0, "RTV_X_CHOSE_X", "%s 选择了 %s", name, s_Maps[key]);
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
	for (new i = 0; i < MAX_MAPS; i++)
		keycount[i] = 0;

	client_cmd(0, "spk Gman/Gman_Choose2");
	rtv_print_lang(0, "RTV_TIME_CHOOSE", "请选择下一张地图。");
	rtv_show_vote_menu();
	set_task(get_pcvar_float(task_time), "change_map", 0);
	return PLUGIN_CONTINUE;
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
		NextRoundChangeMap = false;
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

	rtv_show_last_round_hud();
	g_bMapChangePending = true;
	set_task(3.0, "execute_map_change");
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

	server_cmd("changelevel %s", nextmap);
	server_exec();
}

stock bool:rtv_match_blocked()
{
	if (hns_get_mode() == MODE_MIX)
		return true;
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
			formatex(szMenu, charsmax(szMenu), "%s%d. %s^n", szMenu, i + 1, s_Maps[i]);

		formatex(szMenu, charsmax(szMenu), "%s^n6. ^n7. 延迟地图: %s^n8. 续20分钟%s", szMenu, nextmap[0] ? nextmap : "-", g_bTimeExtended ? " (已续)" : "" );
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

stock rtv_show_last_round_hud()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++)
	{
		new id = iPlayers[i];
		new szText[64];
		rtv_lang(id, "RTV_LAST_ROUND", szText, charsmax(szText), "这是最后一回合");
		set_hudmessage(210, 0, 0, 0.05, 0.45, 1, 20.0, 10.0, 0.5, 0.15, 4);
		show_hudmessage(id, szText);
	}
}

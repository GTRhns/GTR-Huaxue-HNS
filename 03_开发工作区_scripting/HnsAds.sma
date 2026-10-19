/* ============================================================
   HnsAds  -  GTR 捉迷藏聊天栏轮播广告
   配置: configs/mixsystem/hns_ads.cfg
   按玩家 /lang 分别发送: cn / tw / en / ru
   颜色: {g}绿 {r}红 {b}蓝 {w}白 {y}灰
   变量: {players} {online} {maxplayers} {mode} {map} {hostname}
   ============================================================ */

#include <amxmodx>
#include <amxmisc>

native hns_get_mode();
native hns_get_rules();
native HnsLang_GetPlayer(id);

#define ADS_MAX 48
#define ADS_LEN 191
#define ADS_LANG 4
#define TASK_ADS 41001
#define TASK_JOIN 41100

#define LANG_CN 0
#define LANG_TW 1
#define LANG_EN 2
#define LANG_RU 3

#define MODE_TRAINING 0
#define MODE_LOBBY 1
#define MODE_KNIFE 2
#define MODE_PUB 3
#define MODE_DM 4
#define MODE_ZM 5
#define MODE_MIX 6

#define RULES_MR 0
#define RULES_TIMER 1
#define RULES_DUEL 2
#define RULES_ROUNDS 3

new g_szAds[ADS_LANG][ADS_MAX][ADS_LEN];
new g_iAds[ADS_LANG];
new g_iCur;
new g_szPrefix[64];
new Float:g_flInterval = 45.0;
new bool:g_bEnabled = true;
new g_pCvarInterval;
new g_pCvarEnabled;

public plugin_natives() {
	set_native_filter("NativeFilter");
}

public NativeFilter(const szName[], iIndex, iTrap) {
	if (equal(szName, "hns_get_mode") || equal(szName, "hns_get_rules") || equal(szName, "HnsLang_GetPlayer"))
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public plugin_init() {
	register_plugin("HNS Chat Ads", "1.1", "GTR");

	g_pCvarInterval = register_cvar("hns_ads_interval", "45");
	g_pCvarEnabled = register_cvar("hns_ads_enabled", "1");

	register_concmd("hns_ads_reload", "CmdReload", ADMIN_CFG, "重新读取 mixsystem/hns_ads.cfg");
	register_concmd("hns_ads_now", "CmdNow", ADMIN_CFG, "立刻播放下一条广告");
	register_clcmd("say /github", "CmdGithub");
	register_clcmd("say_team /github", "CmdGithub");
	register_clcmd("say /source", "CmdGithub");
	register_clcmd("say_team /source", "CmdGithub");
	register_clcmd("say /开源", "CmdGithub");
	register_clcmd("say_team /开源", "CmdGithub");

	LoadAds();
	remove_task(TASK_ADS);
	set_task(15.0, "TaskAds", TASK_ADS);
}

public plugin_cfg() {
	LoadAds();
}

public client_putinserver(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	set_task(8.0, "TaskJoinAd", id + TASK_JOIN);
}

public client_disconnected(id) {
	remove_task(id + TASK_JOIN);
}

public TaskJoinAd(taskid) {
	new id = taskid - TASK_JOIN;
	if (!is_user_connected(id) || is_user_bot(id))
		return;
	if (!g_bEnabled || !get_pcvar_num(g_pCvarEnabled) || AdCount() < 1)
		return;
	ShowAdTo(id, 0);
}

public TaskAds() {
	new Float:flNext = get_pcvar_float(g_pCvarInterval);
	if (flNext < 10.0)
		flNext = 10.0;
	set_task(flNext, "TaskAds", TASK_ADS);

	if (!g_bEnabled || !get_pcvar_num(g_pCvarEnabled) || AdCount() < 1)
		return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	if (iNum < 1)
		return;

	ShowAdTo(0, g_iCur);
	g_iCur++;
	if (g_iCur >= AdCount())
		g_iCur = 0;
}

public CmdReload(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	LoadAds();
	console_print(id, "[HNS Ads] 已重新读取 cn=%d tw=%d en=%d ru=%d, 间隔 %.0f 秒", g_iAds[LANG_CN], g_iAds[LANG_TW], g_iAds[LANG_EN], g_iAds[LANG_RU], g_flInterval);
	return PLUGIN_HANDLED;
}

public CmdNow(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	if (AdCount() < 1) {
		console_print(id, "[HNS Ads] 没有广告");
		return PLUGIN_HANDLED;
	}
	ShowAdTo(0, g_iCur);
	g_iCur++;
	if (g_iCur >= AdCount())
		g_iCur = 0;
	return PLUGIN_HANDLED;
}

public CmdGithub(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	show_motd(id, "https://github.com/GTRhns", "GTR HNS");
	new lang = PlayerLang(id);
	switch (lang) {
		case LANG_TW: client_print_color(id, print_team_blue, "^4[HNS]^1 本服源碼已經公開 ^3github.com/GTRhns");
		case LANG_EN: client_print_color(id, print_team_blue, "^4[HNS]^1 Source is public ^3github.com/GTRhns");
		case LANG_RU: client_print_color(id, print_team_blue, "^4[HNS]^1 Исходники открыты ^3github.com/GTRhns");
		default: client_print_color(id, print_team_blue, "^4[HNS]^1 本服源码已经公开 ^3github.com/GTRhns");
	}
	return PLUGIN_HANDLED;
}

AdCount() {
	new n = g_iAds[LANG_CN];
	if (g_iAds[LANG_TW] > n) n = g_iAds[LANG_TW];
	if (g_iAds[LANG_EN] > n) n = g_iAds[LANG_EN];
	if (g_iAds[LANG_RU] > n) n = g_iAds[LANG_RU];
	return n;
}

PlayerLang(id) {
	if (!is_user_connected(id))
		return LANG_CN;
	new lang = HnsLang_GetPlayer(id);
	if (lang < LANG_CN || lang >= ADS_LANG)
		return LANG_CN;
	return lang;
}

LoadAds() {
	for (new i = 0; i < ADS_LANG; i++)
		g_iAds[i] = 0;
	g_iCur = 0;
	g_bEnabled = true;
	g_flInterval = 45.0;
	copy(g_szPrefix, charsmax(g_szPrefix), "{g}[HNS]{w} ");

	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/hns_ads.cfg");

	new f = fopen(szPath, "rt");
	if (!f) {
		AddDefaultAds();
		ApplySettings();
		return;
	}

	new szLine[256], szCmd[32], szArg[220], lang = LANG_CN;
	while (!feof(f)) {
		szLine[0] = 0;
		fgets(f, szLine, charsmax(szLine));
		trim(szLine);
		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '#')
			continue;

		if (szLine[0] == '[' && szLine[strlen(szLine) - 1] == ']') {
			szLine[strlen(szLine) - 1] = 0;
			lang = LangFromName(szLine[1]);
			continue;
		}

		szCmd[0] = 0;
		szArg[0] = 0;
		argbreak(szLine, szCmd, charsmax(szCmd), szArg, charsmax(szArg));
		trim(szArg);

		if (equali(szCmd, "interval")) {
			g_flInterval = str_to_float(szArg);
			continue;
		}
		if (equali(szCmd, "prefix")) {
			copy(g_szPrefix, charsmax(g_szPrefix), szArg);
			continue;
		}
		if (equali(szCmd, "enabled")) {
			g_bEnabled = bool:(str_to_num(szArg) != 0);
			continue;
		}

		if (lang < 0 || lang >= ADS_LANG || g_iAds[lang] >= ADS_MAX)
			continue;
		copy(g_szAds[lang][g_iAds[lang]], charsmax(g_szAds[][]), szLine);
		g_iAds[lang]++;
	}
	fclose(f);

	if (g_iAds[LANG_CN] < 1)
		AddDefaultAds();
	ApplySettings();
}

LangFromName(const sz[]) {
	if (equali(sz, "cn") || equali(sz, "zh") || equali(sz, "zh_cn"))
		return LANG_CN;
	if (equali(sz, "tw") || equali(sz, "zh_tw") || equali(sz, "zh-tw"))
		return LANG_TW;
	if (equali(sz, "en") || equali(sz, "eng") || equali(sz, "english"))
		return LANG_EN;
	if (equali(sz, "ru") || equali(sz, "rus") || equali(sz, "russian"))
		return LANG_RU;
	return LANG_CN;
}

ApplySettings() {
	if (g_flInterval < 10.0)
		g_flInterval = 10.0;
	set_pcvar_float(g_pCvarInterval, g_flInterval);
	set_pcvar_num(g_pCvarEnabled, g_bEnabled ? 1 : 0);
}

AddDefaultAds() {
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "欢迎来到GTR捉迷藏，想要皮肤可以签到/打比赛领取{w}GBIC{n}点数购买");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "当前服务器人数 {b}{players}{w}");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "需要永久皮肤或者购买GBIC点数可以在QQ群找{r}LINNA{w}");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "当前模式 {g}{mode}{w}");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "QQ群 {b}1087208104{w}");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "本服无规则采用俄罗斯玩法可以挡人，警察最后一个可以获得飞行烟雾弹");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "服务器如果有bug请在群联系{r}LINNA{w}");
	copy(g_szAds[LANG_CN][g_iAds[LANG_CN]++], charsmax(g_szAds[][]), "本服源码已经公开 {b}github.com/GTRhns{w}  输入 {g}/github{w} 打开");
}

ShowAdTo(id, index) {
	if (id) {
		SendAd(id, index);
		return;
	}
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++)
		SendAd(iPlayers[i], index);
}

SendAd(id, index) {
	if (!is_user_connected(id) || is_user_bot(id))
		return;

	new lang = PlayerLang(id);
	new szMsg[ADS_LEN];
	if (!PickAd(lang, index, szMsg, charsmax(szMsg)))
		return;

	ExpandVars(id, lang, szMsg, charsmax(szMsg));

	new szFull[ADS_LEN];
	formatex(szFull, charsmax(szFull), "%s%s", g_szPrefix, szMsg);

	new iTeam = print_team_default;
	ApplyColors(szFull, charsmax(szFull), iTeam);
	client_print_color(id, iTeam, "%s", szFull);
}

bool:PickAd(lang, index, sz[], iLen) {
	if (lang >= 0 && lang < ADS_LANG && index >= 0 && index < g_iAds[lang] && g_szAds[lang][index][0]) {
		copy(sz, iLen, g_szAds[lang][index]);
		return true;
	}
	if (index >= 0 && index < g_iAds[LANG_CN] && g_szAds[LANG_CN][index][0]) {
		copy(sz, iLen, g_szAds[LANG_CN][index]);
		return true;
	}
	return false;
}

ExpandVars(id, lang, sz[], iLen) {
	new szTmp[48], iHumans, iOnline, iPlayers[MAX_PLAYERS];
	get_players(iPlayers, iHumans, "ch");
	get_players(iPlayers, iOnline, "h");

	num_to_str(iHumans, szTmp, charsmax(szTmp));
	replace_all(sz, iLen, "{players}", szTmp);

	num_to_str(iOnline, szTmp, charsmax(szTmp));
	replace_all(sz, iLen, "{online}", szTmp);

	num_to_str(get_maxplayers(), szTmp, charsmax(szTmp));
	replace_all(sz, iLen, "{maxplayers}", szTmp);

	GetModeName(lang, szTmp, charsmax(szTmp));
	replace_all(sz, iLen, "{mode}", szTmp);

	new szMap[32];
	get_mapname(szMap, charsmax(szMap));
	replace_all(sz, iLen, "{map}", szMap);

	new szHost[64];
	get_cvar_string("hostname", szHost, charsmax(szHost));
	replace_all(sz, iLen, "{hostname}", szHost);

	#pragma unused id
}

GetModeName(lang, sz[], iLen) {
	new iMode = hns_get_mode();
	new iRules = hns_get_rules();

	if (iMode == MODE_MIX) {
		new szRule[24];
		GetRuleName(lang, iRules, szRule, charsmax(szRule));
		formatex(sz, iLen, "mix %s", szRule);
		return;
	}

	switch (lang) {
		case LANG_TW: {
			switch (iMode) {
				case MODE_TRAINING: copy(sz, iLen, "訓練模式");
				case MODE_LOBBY: copy(sz, iLen, "大廳模式");
				case MODE_KNIFE: copy(sz, iLen, "刀局");
				case MODE_PUB: copy(sz, iLen, "娛樂模式");
				case MODE_DM: copy(sz, iLen, "死亡競賽");
				case MODE_ZM: copy(sz, iLen, "殭屍模式");
				default: copy(sz, iLen, "訓練模式");
			}
		}
		case LANG_EN: {
			switch (iMode) {
				case MODE_TRAINING: copy(sz, iLen, "Training");
				case MODE_LOBBY: copy(sz, iLen, "Lobby");
				case MODE_KNIFE: copy(sz, iLen, "Knife");
				case MODE_PUB: copy(sz, iLen, "Public");
				case MODE_DM: copy(sz, iLen, "Deathmatch");
				case MODE_ZM: copy(sz, iLen, "Zombie");
				default: copy(sz, iLen, "Training");
			}
		}
		case LANG_RU: {
			switch (iMode) {
				case MODE_TRAINING: copy(sz, iLen, "Тренировка");
				case MODE_LOBBY: copy(sz, iLen, "Лобби");
				case MODE_KNIFE: copy(sz, iLen, "Ножевой");
				case MODE_PUB: copy(sz, iLen, "Паблик");
				case MODE_DM: copy(sz, iLen, "Deathmatch");
				case MODE_ZM: copy(sz, iLen, "Зомби");
				default: copy(sz, iLen, "Тренировка");
			}
		}
		default: {
			switch (iMode) {
				case MODE_TRAINING: copy(sz, iLen, "训练模式");
				case MODE_LOBBY: copy(sz, iLen, "大厅模式");
				case MODE_KNIFE: copy(sz, iLen, "刀局");
				case MODE_PUB: copy(sz, iLen, "娱乐模式");
				case MODE_DM: copy(sz, iLen, "死亡竞赛");
				case MODE_ZM: copy(sz, iLen, "僵尸模式");
				default: copy(sz, iLen, "训练模式");
			}
		}
	}
}

GetRuleName(lang, iRules, sz[], iLen) {
	switch (lang) {
		case LANG_TW: {
			switch (iRules) {
				case RULES_MR: copy(sz, iLen, "MR");
				case RULES_TIMER: copy(sz, iLen, "Wintime");
				case RULES_DUEL: copy(sz, iLen, "Duel");
				default: copy(sz, iLen, "回合制");
			}
		}
		case LANG_EN: {
			switch (iRules) {
				case RULES_MR: copy(sz, iLen, "MR");
				case RULES_TIMER: copy(sz, iLen, "Wintime");
				case RULES_DUEL: copy(sz, iLen, "Duel");
				default: copy(sz, iLen, "Rounds");
			}
		}
		case LANG_RU: {
			switch (iRules) {
				case RULES_MR: copy(sz, iLen, "MR");
				case RULES_TIMER: copy(sz, iLen, "Wintime");
				case RULES_DUEL: copy(sz, iLen, "Duel");
				default: copy(sz, iLen, "Раунды");
			}
		}
		default: {
			switch (iRules) {
				case RULES_MR: copy(sz, iLen, "MR");
				case RULES_TIMER: copy(sz, iLen, "Wintime");
				case RULES_DUEL: copy(sz, iLen, "Duel");
				default: copy(sz, iLen, "回合制");
			}
		}
	}
}

ApplyColors(sz[], iLen, &iTeam) {
	iTeam = print_team_default;
	new iPosR = containi(sz, "{r}");
	new iPosB = containi(sz, "{b}");
	new iPosY = containi(sz, "{y}");
	new iFirst = 9999;
	new iPick = 0;

	if (iPosR != -1 && iPosR < iFirst) {
		iFirst = iPosR;
		iPick = 1;
	}
	if (iPosB != -1 && iPosB < iFirst) {
		iFirst = iPosB;
		iPick = 2;
	}
	if (iPosY != -1 && iPosY < iFirst) {
		iFirst = iPosY;
		iPick = 3;
	}

	if (iPick == 1)
		iTeam = print_team_red;
	else if (iPick == 2)
		iTeam = print_team_blue;
	else if (iPick == 3)
		iTeam = print_team_grey;

	replace_all(sz, iLen, "{g}", "^4");
	replace_all(sz, iLen, "{w}", "^1");
	replace_all(sz, iLen, "{n}", "^1");
	replace_all(sz, iLen, "{r}", "^3");
	replace_all(sz, iLen, "{b}", "^3");
	replace_all(sz, iLen, "{y}", "^3");
}

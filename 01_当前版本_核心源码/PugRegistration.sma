#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <fakemeta>
#include <PugCore>
#include <hns_matchsystem>
#include <hns_language>

#define PLUGIN_NAME       "PUG Registration System"
#define PLUGIN_VERSION    "1.5.0"
#define PLUGIN_AUTHOR     "LINNA"
#define TASK_REG_HUD      3100
#define TASK_NEXTMAP      3110
#define TASK_WAIT         3120
#define MAX_REG_PLAYERS   32
#define REQUIRED_PLAYERS  10
#define WAIT_TIME         300.0
#define MAP_NAME_LEN      64

#define DATA_MAX_PLAYERS  256
#define DATA_STEAM_LEN    35
#define DATA_NAME_LEN     32
#define DATA_IP_LEN       32

new bool:g_bRegistered[MAX_PLAYERS + 1];
new g_iRegisteredCount;
new bool:g_bLocked;
new g_szPendingSteamID[REQUIRED_PLAYERS][DATA_STEAM_LEN];
new g_szPendingIP[REQUIRED_PLAYERS][DATA_IP_LEN];
new g_iPendingCount;
new g_iWaitLeft;
new g_szSourceMap[32];
new g_szTargetMap[MAP_NAME_LEN];
new g_pUnlimited;
new g_pMaxPlayers;
new g_pMapPool;

// 当前比赛的10名玩家。比赛结束时用它们更新 TXT 数据。
new bool:g_bActiveMatch;
new g_szActiveSteamID[REQUIRED_PLAYERS][DATA_STEAM_LEN];
new g_szActiveIP[REQUIRED_PLAYERS][DATA_IP_LEN];
new g_szActiveName[REQUIRED_PLAYERS][DATA_NAME_LEN];
new g_iActiveTeam[REQUIRED_PLAYERS];

// TXT 玩家数据库缓存。
new g_iDataCount;
new g_szDataSteam[DATA_MAX_PLAYERS][DATA_STEAM_LEN];
new g_szDataIP[DATA_MAX_PLAYERS][DATA_IP_LEN];
new g_szDataName[DATA_MAX_PLAYERS][DATA_NAME_LEN];
new g_iDataMatches[DATA_MAX_PLAYERS];
new g_iDataWins[DATA_MAX_PLAYERS];
new g_iDataLosses[DATA_MAX_PLAYERS];
new g_iDataPoints[DATA_MAX_PLAYERS];
new g_szDataFile[PLATFORM_MAX_PATH];
new g_szTxtDir[PLATFORM_MAX_PATH];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_pUnlimited = create_cvar("pug_registration_unlimited", "0", FCVAR_NONE,
        "0 = max 12 players, 1 = max 32 players");
    g_pMaxPlayers = create_cvar("pug_registration_max", "12", FCVAR_NONE,
        "Normal registration maximum");
    g_pMapPool = create_cvar("pug_registration_map_pool", "skill", FCVAR_NONE,
        "Next map pool: skill or boost");

    PUG_RegCommand("register", "PUG_RegistrationMenu", ADMIN_ALL, "Open registration menu");
    PUG_RegCommand("regmenu", "PUG_RegistrationMenu", ADMIN_ALL, "Open registration menu");
    PUG_RegCommand("jos", "PUG_RegistrationMenu", ADMIN_ALL, "Open HNS registration UI");

    // /pts：查看当前玩家自己的 HNS 比赛数据。
    register_clcmd("say /pts", "PUG_ShowMyData");
    register_clcmd("say_team /pts", "PUG_ShowMyData");
    register_clcmd("say /points", "PUG_ShowMyData");
    register_clcmd("say_team /points", "PUG_ShowMyData");
    register_clcmd("say /stats", "PUG_ShowMyData");
    register_clcmd("say_team /stats", "PUG_ShowMyData");

    PUG_RegCommand("报名", "PUG_RegistrationMenu", ADMIN_ALL, "打开报名菜单");
    PUG_RegCommand("报名菜单", "PUG_RegistrationMenu", ADMIN_ALL, "打开报名菜单");
    PUG_RegCommand("unregister", "PUG_Unregister", ADMIN_ALL, "Cancel registration");
    PUG_RegCommand("取消报名", "PUG_Unregister", ADMIN_ALL, "取消报名");

    PUG_InitDataDirectory();
    PUG_LoadPlayerDatabase();

    set_task(1.0, "PUG_RegistrationHUD", TASK_REG_HUD, _, _, "b");
    set_task(2.0, "PUG_CheckNextMap", TASK_NEXTMAP);
}

public client_putinserver(id)
{
    g_bRegistered[id] = false;

    // 先用IP建立/寻找档案；如果SteamID稍后认证成功，会自动升级为SteamID身份。
    if (!is_user_bot(id))
        PUG_EnsurePlayerData(id);
}

public client_authorized(id, const authid[])
{
    // SteamID认证完成后重新绑定玩家身份，并刷新改名/最新IP。
    if (is_user_connected(id) && !is_user_bot(id))
        PUG_EnsurePlayerData(id);
}

public client_disconnected(id)
{
    if (g_bRegistered[id] && !g_bLocked)
    {
        g_bRegistered[id] = false;
        if (g_iRegisteredCount > 0)
            g_iRegisteredCount--;
    }
}

public PUG_RegistrationMenu(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    new title[128], text[160], info[8];
    PUG_Lang(id, "REG_MENU_TITLE", title, charsmax(title));

    new menu = menu_create(title, "PUG_RegistrationMenu_Handler");

    if (g_bLocked)
    {
        PUG_Lang(id, "REG_LOCKED", text, charsmax(text));
        num_to_str(0, info, charsmax(info));
        menu_additem(menu, text, info, 0);
    }
    else if (g_bRegistered[id])
    {
        PUG_Lang(id, "REG_CANCEL", text, charsmax(text));
        num_to_str(1, info, charsmax(info));
        menu_additem(menu, text, info);
    }
    else
    {
        PUG_Lang(id, "REG_SIGNUP", text, charsmax(text));
        num_to_str(1, info, charsmax(info));
        menu_additem(menu, text, info);
    }

    menu_addblank(menu, false);

    PUG_Lang(id, "REG_LIST", text, charsmax(text));
    num_to_str(2, info, charsmax(info));
    menu_additem(menu, text, info);

    PUG_Lang(id, "REG_MODE", text, charsmax(text));
    new modeValue[32];
    PUG_Lang(id, get_pcvar_num(g_pUnlimited) ? "REG_MODE_UNLIMITED" : "REG_MODE_STANDARD", modeValue, charsmax(modeValue));
    replace(text, charsmax(text), "%s", modeValue);
    num_to_str(3, info, charsmax(info));
    menu_additem(menu, text, info, 0);

    menu_addblank(menu, false);

    PUG_Lang(id, "REG_COUNT", text, charsmax(text));
    replace(text, charsmax(text), "%d", fmt("%d", g_iRegisteredCount));
    num_to_str(4, info, charsmax(info));
    menu_additem(menu, text, info, 0);

    PUG_Lang(id, "REG_RULES", text, charsmax(text));
    num_to_str(5, info, charsmax(info));
    menu_additem(menu, text, info, 0);

    PUG_Lang(id, "REG_MYDATA", text, charsmax(text));
    num_to_str(7, info, charsmax(info));
    menu_additem(menu, text, info);

    PUG_Lang(id, "REG_REFRESH", text, charsmax(text));
    num_to_str(6, info, charsmax(info));
    menu_additem(menu, text, info);

    PUG_Lang(id, "MENU_EXIT", text, charsmax(text));
    menu_setprop(menu, MPROP_EXITNAME, text);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public PUG_RegistrationMenu_Handler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);
    new choice = str_to_num(info);
    menu_destroy(menu);

    switch (choice)
    {
        case 1: g_bRegistered[id] ? PUG_Unregister(id) : PUG_Register(id);
        case 2: PUG_ShowRegistrationList(id);
        case 6: PUG_RegistrationMenu(id);
        case 5: PUG_ShowRules(id);
        case 7: PUG_ShowMyData(id);
        default: PUG_RegistrationMenu(id);
    }
    return PLUGIN_HANDLED;
}

public PUG_ShowRules(id)
{
    new title[96], rules[512], line[128];
    PUG_Lang(id, "REG_RULES", title, charsmax(title));
    PUG_Lang(id, "REG_RULES_TEXT", rules, charsmax(rules));

    new menu = menu_create(title, "PUG_Rules_Handler");
    menu_additem(menu, rules, "0", 0);
    PUG_Lang(id, "REG_BACK", line, charsmax(line));
    menu_setprop(menu, MPROP_EXITNAME, line);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public PUG_Rules_Handler(id, menu, item)
{
    menu_destroy(menu);
    PUG_RegistrationMenu(id);
    return PLUGIN_HANDLED;
}

public PUG_ShowRegistrationList(id)
{
    new title[64], text[128], info[8];
    PUG_Lang(id, "REG_LIST_TITLE", title, charsmax(title));
    new menu = menu_create(title, "PUG_RegistrationList_Handler");

    new players[MAX_PLAYERS], num, count;
    get_players(players, num, "ch");

    for (new i; i < num; i++)
    {
        new player = players[i];
        if (!g_bRegistered[player]) continue;
        count++;
        formatex(text, charsmax(text), "%d. %n", count, player);
        num_to_str(player, info, charsmax(info));
        menu_additem(menu, text, info, 0);
    }

    if (!count)
    {
        PUG_Lang(id, "REG_EMPTY", text, charsmax(text));
        menu_additem(menu, text, "0", 0);
    }

    PUG_Lang(id, "REG_BACK", text, charsmax(text));
    menu_setprop(menu, MPROP_EXITNAME, text);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public PUG_RegistrationList_Handler(id, menu, item)
{
    menu_destroy(menu);
    PUG_RegistrationMenu(id);
    return PLUGIN_HANDLED;
}

public PUG_ShowMyData(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    // 每次打开 /pts 都重新读取 TXT，确保看到的是最新数据。
    PUG_LoadPlayerDatabase();

    new steam[DATA_STEAM_LEN], ip[DATA_IP_LEN], name[DATA_NAME_LEN];
    PUG_GetIdentity(id, steam, charsmax(steam), ip, charsmax(ip));
    get_user_name(id, name, charsmax(name));

    new index = PUG_FindPlayerData(steam, ip);
    if (index == -1)
    {
        PUG_AddPlayerData(steam, ip, name);
        index = g_iDataCount - 1;
        PUG_SavePlayerDatabase();
    }
    else
    {
        copy(g_szDataName[index], charsmax(g_szDataName[]), name);
        copy(g_szDataSteam[index], charsmax(g_szDataSteam[]), steam);
        copy(g_szDataIP[index], charsmax(g_szDataIP[]), ip);
        PUG_SavePlayerDatabase();
    }

    new title[96], line[128], winrate[16], matches[16], wins[16], losses[16], points[16];
    PUG_Lang(id, "REG_MYDATA_TITLE", title, charsmax(title));
    new playerName[DATA_NAME_LEN];
    get_user_name(id, playerName, charsmax(playerName));
    replace(title, charsmax(title), "%s", playerName);
    new menu = menu_create(title, "PUG_MyData_Handler");

    PUG_GetWinRateString(index, winrate, charsmax(winrate));
    PUG_Lang(id, "REG_MYDATA_WINRATE", line, charsmax(line));
    replace(line, charsmax(line), "%s", winrate);
    menu_additem(menu, line, "0", 0);

    PUG_Lang(id, "REG_MYDATA_POINTS", line, charsmax(line));
    formatex(points, charsmax(points), "%d", g_iDataPoints[index]);
    replace(line, charsmax(line), "%d", points);
    menu_additem(menu, line, "0", 0);

    PUG_Lang(id, "REG_MYDATA_MATCHES", line, charsmax(line));
    formatex(matches, charsmax(matches), "%d", g_iDataMatches[index]);
    replace(line, charsmax(line), "%d", matches);
    menu_additem(menu, line, "0", 0);

    PUG_Lang(id, "REG_MYDATA_WINS", line, charsmax(line));
    formatex(wins, charsmax(wins), "%d", g_iDataWins[index]);
    replace(line, charsmax(line), "%d", wins);
    menu_additem(menu, line, "0", 0);

    PUG_Lang(id, "REG_MYDATA_LOSSES", line, charsmax(line));
    formatex(losses, charsmax(losses), "%d", g_iDataLosses[index]);
    replace(line, charsmax(line), "%d", losses);
    menu_additem(menu, line, "0", 0);

    PUG_Lang(id, "REG_BACK", line, charsmax(line));
    menu_setprop(menu, MPROP_EXITNAME, line);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public PUG_MyData_Handler(id, menu, item)
{
    menu_destroy(menu);
    PUG_RegistrationMenu(id);
    return PLUGIN_HANDLED;
}

public PUG_Register(id)
{
    if (!is_user_connected(id) || g_bLocked)
        return PLUGIN_HANDLED;

    if (g_bRegistered[id]) return PLUGIN_HANDLED;

    new iMax = PUG_GetRegistrationMax();
    if (g_iRegisteredCount >= iMax)
    {
        PUG_Print(id, "REG_FULL", iMax);
        return PLUGIN_HANDLED;
    }

    g_bRegistered[id] = true;
    g_iRegisteredCount++;
    PUG_EnsurePlayerData(id);
    PUG_Print(0, "REG_JOIN", g_iRegisteredCount);

    if (g_iRegisteredCount >= REQUIRED_PLAYERS)
    {
        g_bLocked = true;
        if (!PUG_SelectNextMap(g_szTargetMap, charsmax(g_szTargetMap)))
        {
            PUG_Print(0, "REG_READY_NEXTMAP");
            log_amx("[PUG Registration] No valid next map found; keeping current map");
            return PLUGIN_HANDLED;
        }

        PUG_SavePendingRoster();
        PUG_Print(0, "REG_READY_NEXTMAP");
        log_amx("[PUG Registration] Changing level immediately to %s", g_szTargetMap);
        engine_changelevel(g_szTargetMap);
    }
    return PLUGIN_HANDLED;
}

public PUG_Unregister(id)
{
    if (!is_user_connected(id) || g_bLocked)
        return PLUGIN_HANDLED;

    if (!g_bRegistered[id]) return PLUGIN_HANDLED;

    g_bRegistered[id] = false;
    if (g_iRegisteredCount > 0) g_iRegisteredCount--;
    PUG_Print(0, "REG_LEAVE", g_iRegisteredCount);
    return PLUGIN_HANDLED;
}

public PUG_RegistrationHUD()
{
    new players[MAX_PLAYERS], num;
    get_players(players, num, "ch");

    for (new i; i < num; i++)
    {
        new id = players[i];
        // 未报名玩家不显示 HUD，避免服务器画面一直刷。
        if (!g_bRegistered[id] && !g_bLocked)
            continue;

        new label[128], number[16];
        PUG_Lang(id, "REG_HUD", label, charsmax(label));
        formatex(number, charsmax(number), "%d", g_iRegisteredCount);

        set_hudmessage(255, 255, 255, 0.02, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 7);
        show_hudmessage(id, "%s", label);
        set_hudmessage(0, 255, 0, 0.205, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 8);
        show_hudmessage(id, "%s", number);
    }
}

public PUG_CheckNextMap()
{
    PUG_LoadPendingRoster();
    if (!g_bLocked || g_iPendingCount < REQUIRED_PLAYERS)
        return;

    new found = PUG_CountPendingConnected();
    if (found >= REQUIRED_PLAYERS)
    {
        PUG_StartPendingMatch();
        return;
    }

    g_iWaitLeft = floatround(WAIT_TIME);
    set_task(1.0, "PUG_WaitForPlayers", TASK_WAIT, _, _, "b");
    PUG_Print(0, "REG_WAIT", found, REQUIRED_PLAYERS, g_iWaitLeft);
}

public PUG_WaitForPlayers()
{
    if (!g_bLocked)
    {
        remove_task(TASK_WAIT);
        return;
    }

    new found = PUG_CountPendingConnected();
    if (found >= REQUIRED_PLAYERS)
    {
        remove_task(TASK_WAIT);
        PUG_StartPendingMatch();
        return;
    }

    g_iWaitLeft--;
    if (g_iWaitLeft <= 0)
    {
        remove_task(TASK_WAIT);
        PUG_Print(0, "REG_TIMEOUT");
        PUG_ClearPendingRoster();
    }
}

stock PUG_StartPendingMatch()
{
    remove_task(TASK_WAIT);

    new ids[REQUIRED_PLAYERS], count;
    PUG_GetPendingPlayers(ids, count);
    if (count < REQUIRED_PLAYERS)
        return;

    g_bActiveMatch = true;
    PUG_BuildBalancedTeams(ids, count);
    for (new i; i < REQUIRED_PLAYERS; i++)
    {
        PUG_GetIdentity(ids[i], g_szActiveSteamID[i], charsmax(g_szActiveSteamID[]), g_szActiveIP[i], charsmax(g_szActiveIP[]));
        get_user_name(ids[i], g_szActiveName[i], charsmax(g_szActiveName[]));
    }

    // 先全部送进观察者，再按胜率 + 积分平衡后的结果分成 5/5。
    for (new i; i < count; i++)
        rg_set_user_team(ids[i], TEAM_SPECTATOR);

    for (new i; i < count; i++)
    {
        rg_set_user_team(ids[i], g_iActiveTeam[i] == 1 ? TEAM_TERRORIST : TEAM_CT);
        dllfunc(DLLFunc_Spawn, ids[i]);
    }

    hns_set_mode(MODE_MIX);

    PUG_Print(0, "REG_STARTED");
    PUG_ClearPendingRoster();
}

// HnsMatchSystem 比赛结束时调用：更新10名参赛玩家的 TXT 数据。
public hns_match_finished(iWinTeam)
{
    if (!g_bActiveMatch)
        return;

    PUG_LoadPlayerDatabase();

    for (new i; i < REQUIRED_PLAYERS; i++)
    {
        if (!g_szActiveSteamID[i][0] && !g_szActiveIP[i][0]) continue;

        new index = PUG_FindPlayerData(g_szActiveSteamID[i], g_szActiveIP[i]);
        if (index == -1)
        {
            if (g_iDataCount >= DATA_MAX_PLAYERS) continue;
            index = g_iDataCount++;
            copy(g_szDataSteam[index], charsmax(g_szDataSteam[]), g_szActiveSteamID[i]);
            copy(g_szDataIP[index], charsmax(g_szDataIP[]), g_szActiveIP[i]);
            copy(g_szDataName[index], charsmax(g_szDataName[]), g_szActiveName[i]);
            g_iDataMatches[index] = 0;
            g_iDataWins[index] = 0;
            g_iDataLosses[index] = 0;
            g_iDataPoints[index] = 1000;
        }

        copy(g_szDataName[index], charsmax(g_szDataName[]), g_szActiveName[i]);
        if (g_szActiveSteamID[i][0])
            copy(g_szDataSteam[index], charsmax(g_szDataSteam[]), g_szActiveSteamID[i]);
        if (g_szActiveIP[i][0])
            copy(g_szDataIP[index], charsmax(g_szDataIP[]), g_szActiveIP[i]);

        g_iDataMatches[index]++;
        if (g_iActiveTeam[i] == iWinTeam)
        {
            g_iDataWins[index]++;
            g_iDataPoints[index] += 25;
        }
        else
        {
            g_iDataLosses[index]++;
            g_iDataPoints[index] -= 15;
            if (g_iDataPoints[index] < 0)
                g_iDataPoints[index] = 0;
        }
    }

    PUG_SavePlayerDatabase();
    g_bActiveMatch = false;
    for (new i; i < REQUIRED_PLAYERS; i++) {
        g_szActiveSteamID[i][0] = 0;
        g_szActiveIP[i][0] = 0;
        g_szActiveName[i][0] = 0;
        g_iActiveTeam[i] = 0;
    }
}

stock Float:PUG_GetPlayerRating(id)
{
    new steam[DATA_STEAM_LEN], ip[DATA_IP_LEN];
    PUG_GetIdentity(id, steam, charsmax(steam), ip, charsmax(ip));

    new index = PUG_FindPlayerData(steam, ip);
    if (index == -1)
    {
        PUG_EnsurePlayerData(id);
        index = PUG_FindPlayerData(steam, ip);
    }

    if (index == -1) return 1000.0;

    // 积分是主要权重，胜率用于修正实力。
    return float(g_iDataPoints[index]) + PUG_CalcWinRate(index) * 5.0;
}

stock PUG_BuildBalancedTeams(ids[], count)
{
    new used[REQUIRED_PLAYERS];
    new teamSize[3];
    new Float:teamRating[3];

    // 从高实力到低实力排列，然后每次把玩家放到当前总实力较低的一队。
    for (new i; i < count; i++)
    {
        new best = -1;
        new Float:bestRating = -1.0;

        for (new j; j < count; j++)
        {
            if (used[j]) continue;
            new Float:rating = PUG_GetPlayerRating(ids[j]);
            if (rating > bestRating)
            {
                bestRating = rating;
                best = j;
            }
        }

        if (best < 0) continue;
        used[best] = 1;

        new team;
        if (teamSize[1] >= 5)
            team = 2;
        else if (teamSize[2] >= 5)
            team = 1;
        else if (teamRating[1] <= teamRating[2])
            team = 1;
        else
            team = 2;

        g_iActiveTeam[best] = team;
        teamSize[team]++;
        teamRating[team] += bestRating;
    }
}

stock PUG_SavePendingRoster()
{
    g_iPendingCount = 0;
    for (new id = 1; id <= MAX_PLAYERS && g_iPendingCount < REQUIRED_PLAYERS; id++)
    {
        if (!is_user_connected(id) || !g_bRegistered[id]) continue;

        PUG_GetIdentity(id, g_szPendingSteamID[g_iPendingCount], charsmax(g_szPendingSteamID[]), g_szPendingIP[g_iPendingCount], charsmax(g_szPendingIP[]));
        g_iPendingCount++;
    }

    get_mapname(g_szSourceMap, charsmax(g_szSourceMap));

    new file[PLATFORM_MAX_PATH];
    copy(file, charsmax(file), g_szTxtDir);
    add(file, charsmax(file), "/registration.txt");

    new fp = fopen(file, "wt");
    if (!fp)
    {
        log_amx("[PUG Registration] Cannot write %s", file);
        return;
    }

    fprintf(fp, "[registration]^n");
    fprintf(fp, "status = locked^n");
    fprintf(fp, "source_map = %s^n", g_szSourceMap);
    fprintf(fp, "target_map = %s^n", g_szTargetMap);
    fprintf(fp, "max_players = %d^n^n", REQUIRED_PLAYERS);

    for (new i; i < g_iPendingCount; i++)
        fprintf(fp, "[player_%d]^nsteamid = %s^nip = %s^n^n", i + 1, g_szPendingSteamID[i], g_szPendingIP[i]);

    fclose(fp);
}

stock PUG_LoadPendingRoster()
{
    g_iPendingCount = 0;

    new file[PLATFORM_MAX_PATH];
    copy(file, charsmax(file), g_szTxtDir);
    add(file, charsmax(file), "/registration.txt");

    new fp = fopen(file, "rt");
    if (!fp) return;

    new line[256], section[64], key[64], value[192];
    new currentSlot;
    new sourceMap[32], targetMap[MAP_NAME_LEN], currentMap[MAP_NAME_LEN];
    get_mapname(currentMap, charsmax(currentMap));

    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';' || line[0] == '#') continue;

        if (line[0] == '[')
        {
            section[0] = 0;
            copyc(section, charsmax(section), line[1], ']');
            currentSlot = 0;
            if (containi(section, "player_") == 0)
                currentSlot = str_to_num(section[7]);
            continue;
        }

        if (!PUG_ParseLine(line, key, charsmax(key), value, charsmax(value))) continue;

        if (equali(section, "registration") && equali(key, "source_map"))
            copy(sourceMap, charsmax(sourceMap), value);
        else if (equali(section, "registration") && equali(key, "target_map"))
            copy(targetMap, charsmax(targetMap), value);
        else if (currentSlot >= 1 && currentSlot <= REQUIRED_PLAYERS && equali(key, "steamid"))
        {
            copy(g_szPendingSteamID[currentSlot - 1], charsmax(g_szPendingSteamID[]), value);
            if (currentSlot > g_iPendingCount) g_iPendingCount = currentSlot;
        }
        else if (currentSlot >= 1 && currentSlot <= REQUIRED_PLAYERS && equali(key, "ip"))
        {
            copy(g_szPendingIP[currentSlot - 1], charsmax(g_szPendingIP[]), value);
        }
    }

    fclose(fp);

    new bool:bTargetMatches = targetMap[0] ? equali(targetMap, currentMap) : (!equal(sourceMap, currentMap));
    if (!sourceMap[0] || !bTargetMatches || g_iPendingCount < REQUIRED_PLAYERS)
    {
        g_iPendingCount = 0;
        return;
    }

    copy(g_szSourceMap, charsmax(g_szSourceMap), sourceMap);
    copy(g_szTargetMap, charsmax(g_szTargetMap), targetMap);
    g_bLocked = true;
    g_iRegisteredCount = REQUIRED_PLAYERS;

    // 新地图载入后，把已经在线的报名玩家恢复为“已报名”状态，HUD/UI 才能继续显示。
    new steam[DATA_STEAM_LEN], ip[DATA_IP_LEN];
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id)) continue;
        PUG_GetIdentity(id, steam, charsmax(steam), ip, charsmax(ip));
        for (new i; i < g_iPendingCount; i++)
        {
            if (PUG_IdentityMatches(steam, ip, g_szPendingSteamID[i], g_szPendingIP[i]))
            {
                g_bRegistered[id] = true;
                break;
            }
        }
    }
}

stock bool:PUG_SelectNextMap(output[], len)
{
    output[0] = 0;

    new currentMap[MAP_NAME_LEN];
    get_mapname(currentMap, charsmax(currentMap));

    new pool[16];
    get_pcvar_string(g_pMapPool, pool, charsmax(pool));
    if (!equali(pool, "boost"))
        copy(pool, charsmax(pool), "skill");

    new path[PLATFORM_MAX_PATH];
    get_configsdir(path, charsmax(path));
    add(path, charsmax(path), "/mixsystem/hns-maps.ini");

    new fp = fopen(path, "rt");
    if (!fp) return false;

    new line[160], section[32], map[MAP_NAME_LEN];
    new validCount;
    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';') continue;

        if (line[0] == '[')
        {
            section[0] = 0;
            copyc(section, charsmax(section), line[1], ']');
            trim(section);
            continue;
        }

        if (!equali(section, pool)) continue;
        parse(line, map, charsmax(map));
        trim(map);
        if (!map[0] || equali(map, currentMap)) continue;
        if (containi(map, ".bsp") == strlen(map) - 4)
            map[strlen(map) - 4] = 0;
        if (!file_exists(fmt("maps/%s.bsp", map))) continue;

        validCount++;
        if (random_num(1, validCount) == 1)
            copy(output, len, map);
    }
    fclose(fp);
    return output[0] != 0;
}

stock PUG_ClearPendingRoster()
{
    g_bLocked = false;
    g_iPendingCount = 0;
    g_iRegisteredCount = 0;
    g_iWaitLeft = 0;
    for (new i; i < REQUIRED_PLAYERS; i++) {
        g_szPendingSteamID[i][0] = 0;
        g_szPendingIP[i][0] = 0;
    }

    for (new id = 1; id <= MAX_PLAYERS; id++)
        g_bRegistered[id] = false;

    new file[PLATFORM_MAX_PATH];
    copy(file, charsmax(file), g_szTxtDir);
    add(file, charsmax(file), "/registration.txt");
    delete_file(file);
}

stock PUG_CountPendingConnected()
{
    new count, steam[DATA_STEAM_LEN], ip[DATA_IP_LEN];
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id)) continue;
        PUG_GetIdentity(id, steam, charsmax(steam), ip, charsmax(ip));
        for (new i; i < g_iPendingCount; i++)
        {
            if (PUG_IdentityMatches(steam, ip, g_szPendingSteamID[i], g_szPendingIP[i])) { count++; break; }
        }
    }
    return count;
}

stock PUG_GetPendingPlayers(ids[], &count)
{
    count = 0;
    new steam[DATA_STEAM_LEN], ip[DATA_IP_LEN];
    for (new id = 1; id <= MAX_PLAYERS && count < REQUIRED_PLAYERS; id++)
    {
        if (!is_user_connected(id)) continue;
        PUG_GetIdentity(id, steam, charsmax(steam), ip, charsmax(ip));
        for (new i; i < g_iPendingCount; i++)
        {
            if (PUG_IdentityMatches(steam, ip, g_szPendingSteamID[i], g_szPendingIP[i]))
            {
                ids[count++] = id;
                break;
            }
        }
    }
}

stock PUG_GetRegistrationMax()
{
    if (get_pcvar_num(g_pUnlimited)) return MAX_REG_PLAYERS;
    new iMax = get_pcvar_num(g_pMaxPlayers);
    if (iMax < 2) iMax = 2;
    if (iMax > 12) iMax = 12;
    if (iMax & 1) iMax--;
    return iMax;
}

stock PUG_Lang(id, const key[], buffer[], len)
{
    if (!HnsLang_Get(id, key, buffer, len))
        formatex(buffer, len, "%s", key);
}

stock PUG_Print(id, const key[], any:...)
{
    if (id == 0)
    {
        new players[MAX_PLAYERS], num;
        get_players(players, num, "ch");
        for (new i; i < num; i++)
        {
            new msg[192];
            PUG_Lang(players[i], key, msg, charsmax(msg));
            vformat(msg, charsmax(msg), msg, 3);
            client_print_color(players[i], print_team_default, "^4[HNS]^1 %s", msg);
        }
        return;
    }

    new msg[192];
    PUG_Lang(id, key, msg, charsmax(msg));
    vformat(msg, charsmax(msg), msg, 3);
    client_print_color(id, print_team_default, "^4[HNS]^1 %s", msg);
}

stock bool:PUG_ParseLine(const line[], key[], keyLen, value[], valueLen)
{
    new eq = contain(line, "=");
    if (eq <= 0) return false;

    copy(key, keyLen, line);
    key[eq] = 0;
    trim(key);

    copy(value, valueLen, line[eq + 1]);
    trim(value);
    return key[0] != 0;
}

stock PUG_InitDataDirectory()
{
    new dir[PLATFORM_MAX_PATH];
    get_localinfo("amxx_configsdir", dir, charsmax(dir));
    add(dir, charsmax(dir), "/HNSgtr");
    mkdir(dir);
    add(dir, charsmax(dir), "/txt");
    mkdir(dir);

    copy(g_szTxtDir, charsmax(g_szTxtDir), dir);
    copy(g_szDataFile, charsmax(g_szDataFile), dir);
    add(g_szDataFile, charsmax(g_szDataFile), "/players.txt");
}

stock bool:PUG_IsValidSteamID(const steam[])
{
    if (!steam[0]) return false;
    if (equali(steam, "STEAM_ID_PENDING")) return false;
    if (equali(steam, "STEAM_ID_LAN")) return false;
    if (equali(steam, "VALVE_ID_LAN")) return false;
    if (equali(steam, "BOT")) return false;
    return true;
}

stock PUG_GetIdentity(id, steam[], steamLen, ip[], ipLen)
{
    steam[0] = 0;
    ip[0] = 0;
    if (!is_user_connected(id)) return;

    get_user_authid(id, steam, steamLen);
    get_user_ip(id, ip, ipLen, 1);

    if (!PUG_IsValidSteamID(steam))
        steam[0] = 0;
}

stock bool:PUG_IdentityMatches(const steam1[], const ip1[], const steam2[], const ip2[])
{
    // SteamID优先：只要双方都有有效SteamID，就只按SteamID认人。
    if (PUG_IsValidSteamID(steam1) && PUG_IsValidSteamID(steam2))
        return equal(steam1, steam2);

    // 没有有效SteamID时才使用IP作为后备认证。
    if (ip1[0] && ip2[0])
        return equal(ip1, ip2);

    return false;
}

stock PUG_LoadPlayerDatabase()
{
    g_iDataCount = 0;

    new fp = fopen(g_szDataFile, "rt");
    if (!fp) return;

    new line[256], section[64], key[64], value[192];
    new index = -1;

    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';' || line[0] == '#') continue;

        if (line[0] == '[')
        {
            section[0] = 0;
            copyc(section, charsmax(section), line[1], ']');
            index = -1;

            if (containi(section, "player_") == 0 && g_iDataCount < DATA_MAX_PLAYERS)
            {
                index = g_iDataCount++;
                g_szDataSteam[index][0] = 0;
            }
            continue;
        }

        if (index < 0) continue;

        // 使用人类可读的中文TXT格式。
        if (containi(line, "玩家：") == 0)
        {
            copy(value, charsmax(value), line[9]);
            trim(value);
            copy(g_szDataName[index], charsmax(g_szDataName[]), value);
        }
        else if (containi(line, "SteamID：") == 0)
        {
            copy(value, charsmax(value), line[10]);
            trim(value);
            copy(g_szDataSteam[index], charsmax(g_szDataSteam[]), value);
        }
        else if (containi(line, "IP：") == 0)
        {
            copy(value, charsmax(value), line[5]);
            trim(value);
            copy(g_szDataIP[index], charsmax(g_szDataIP[]), value);
        }
        else if (containi(line, "当前比赛积分：") == 0)
        {
            copy(value, charsmax(value), line[21]);
            trim(value);
            replace_all(value, charsmax(value), "PTS", "");
            trim(value);
            g_iDataPoints[index] = str_to_num(value);
        }
        else if (containi(line, "最近比赛数：") == 0)
        {
            copy(value, charsmax(value), line[18]);
            trim(value);
            g_iDataMatches[index] = str_to_num(value);
        }
        else if (containi(line, "胜：") == 0)
        {
            new sep = containi(line, " | 败：");
            if (sep > 0)
            {
                copy(value, charsmax(value), line[6]);
                value[sep - 6] = 0;
                g_iDataWins[index] = str_to_num(value);
                copy(value, charsmax(value), line[sep + 9]);
                trim(value);
                g_iDataLosses[index] = str_to_num(value);
            }
        }
        // 胜率是派生数据，读取时不使用TXT中的值，始终按胜场/比赛数重新计算。
    }

    fclose(fp);
}

stock PUG_SavePlayerDatabase()
{
    new fp = fopen(g_szDataFile, "wt");
    if (!fp)
    {
        log_amx("[PUG Registration] Cannot write player database: %s", g_szDataFile);
        return;
    }

    fprintf(fp, "; HNS GTR Player Statistics - TXT local database^n");
    fprintf(fp, "; 身份验证：有效SteamID优先；SteamID无效时使用IP后备认证。^n");
    fprintf(fp, "; 玩家改名不会产生新档案，数据会按SteamID/IP更新。^n^n");

    for (new i; i < g_iDataCount; i++)
    {
        if (!g_szDataSteam[i][0] && !g_szDataIP[i][0]) continue;

        new safeName[DATA_NAME_LEN];
        copy(safeName, charsmax(safeName), g_szDataName[i]);
        replace_all(safeName, charsmax(safeName), "=", "_");
        replace_all(safeName, charsmax(safeName), "^n", "_");
        replace_all(safeName, charsmax(safeName), "^r", "_");

        new winrate[16];
        PUG_GetWinRateString(i, winrate, charsmax(winrate));

        fprintf(fp, "[PLAYER_%03d]^n", i + 1);
        fprintf(fp, "玩家：%s^n", safeName);
        fprintf(fp, "SteamID：%s^n", g_szDataSteam[i]);
        fprintf(fp, "IP：%s^n", g_szDataIP[i]);
        fprintf(fp, "当前比赛积分：%d PTS^n", g_iDataPoints[i]);
        fprintf(fp, "最近比赛数：%d^n", g_iDataMatches[i]);
        fprintf(fp, "胜：%d | 败：%d^n", g_iDataWins[i], g_iDataLosses[i]);
        fprintf(fp, "胜率：%s^n^n", winrate);
    }

    fclose(fp);
}

stock PUG_EnsurePlayerData(id)
{
    new steam[DATA_STEAM_LEN], ip[DATA_IP_LEN], name[DATA_NAME_LEN];
    PUG_GetIdentity(id, steam, charsmax(steam), ip, charsmax(ip));
    get_user_name(id, name, charsmax(name));

    new index = PUG_FindPlayerData(steam, ip);
    if (index == -1)
    {
        if (g_iDataCount >= DATA_MAX_PLAYERS) return;
        PUG_AddPlayerData(steam, ip, name);
    }
    else
    {
        copy(g_szDataName[index], charsmax(g_szDataName[]), name);
        copy(g_szDataSteam[index], charsmax(g_szDataSteam[]), steam);
        copy(g_szDataIP[index], charsmax(g_szDataIP[]), ip);
    }

    PUG_SavePlayerDatabase();
}

stock PUG_AddPlayerData(const steam[], const ip[], const name[])
{
    if (g_iDataCount >= DATA_MAX_PLAYERS) return;

    new index = g_iDataCount++;
    copy(g_szDataSteam[index], charsmax(g_szDataSteam[]), steam);
    copy(g_szDataIP[index], charsmax(g_szDataIP[]), ip);
    copy(g_szDataName[index], charsmax(g_szDataName[]), name);
    g_iDataMatches[index] = 0;
    g_iDataWins[index] = 0;
    g_iDataLosses[index] = 0;
    g_iDataPoints[index] = 1000;
}

stock PUG_FindPlayerData(const steam[], const ip[])
{
    for (new i; i < g_iDataCount; i++)
    {
        if (PUG_IdentityMatches(steam, ip, g_szDataSteam[i], g_szDataIP[i]))
            return i;
    }
    return -1;
}

stock Float:PUG_CalcWinRate(index)
{
    if (g_iDataMatches[index] <= 0) return 0.0;
    return float(g_iDataWins[index]) * 100.0 / float(g_iDataMatches[index]);
}

stock PUG_GetWinRateString(index, output[], len)
{
    formatex(output, len, "%.2f%%", PUG_CalcWinRate(index));
}


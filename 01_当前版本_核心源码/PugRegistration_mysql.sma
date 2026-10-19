#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <sqlx>
#include <PugCore>
#include <hns_matchsystem>
#include <hns_matchsystem_sql>
#include <hns_language>

#define PLUGIN_NAME       "PUG Registration System"
#define PLUGIN_VERSION    "2.0.0-MYSQL"
#define PLUGIN_AUTHOR     "LINNA / OpenHNS"
#define TASK_REG_HUD      3100
#define TASK_NEXTMAP      3110
#define TASK_WAIT         3120
#define MAX_REG_PLAYERS   32
#define REQUIRED_PLAYERS  10
#define WAIT_TIME         300.0
#define REG_PAGE_SIZE    7
#define PUG_TABLE         "hns_pug_players"
#define REG_TABLE         "hns_pug_registration"

new Handle:g_hSqlTuple;
new bool:g_bSqlReady;
new bool:g_bRegistered[MAX_PLAYERS + 1];
new bool:g_bLocked;
new bool:g_bDataLoaded[MAX_PLAYERS + 1];
new g_iRegisteredCount;
new g_iWaitLeft;
new g_iPoints[MAX_PLAYERS + 1];
new g_iMatches[MAX_PLAYERS + 1];
new g_iWins[MAX_PLAYERS + 1];
new g_iLosses[MAX_PLAYERS + 1];
new g_szSteam[MAX_PLAYERS + 1][35];
new g_szIp[MAX_PLAYERS + 1][32];
new g_szPendingSteam[REQUIRED_PLAYERS][35];
new g_szPendingIp[REQUIRED_PLAYERS][32];
new g_szSourceMap[32];
new g_iPendingCount;
new g_pUnlimited;
new g_pMaxPlayers;

new bool:g_bActiveMatch;
new g_iActiveTeam[REQUIRED_PLAYERS];
new g_szActiveSteam[REQUIRED_PLAYERS][35];
new g_szActiveIp[REQUIRED_PLAYERS][32];
new g_szActiveName[REQUIRED_PLAYERS][32];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_pUnlimited = create_cvar("pug_registration_unlimited", "0");
    g_pMaxPlayers = create_cvar("pug_registration_max", "12");

    PUG_RegCommand("register", "PUG_RegistrationMenu", ADMIN_ALL);
    PUG_RegCommand("regmenu", "PUG_RegistrationMenu", ADMIN_ALL);
    PUG_RegCommand("jos", "PUG_RegistrationMenu", ADMIN_ALL);
    PUG_RegCommand("报名", "PUG_RegistrationMenu", ADMIN_ALL);
    PUG_RegCommand("报名菜单", "PUG_RegistrationMenu", ADMIN_ALL);
    PUG_RegCommand("unregister", "PUG_Unregister", ADMIN_ALL);
    PUG_RegCommand("取消报名", "PUG_Unregister", ADMIN_ALL);

    register_clcmd("say /pts", "PUG_ShowMyData");
    register_clcmd("say_team /pts", "PUG_ShowMyData");
    register_clcmd("say /points", "PUG_ShowMyData");
    register_clcmd("say_team /points", "PUG_ShowMyData");
    register_clcmd("say /stats", "PUG_ShowMyData");
    register_clcmd("say_team /stats", "PUG_ShowMyData");

    set_task(1.0, "PUG_RegistrationHUD", TASK_REG_HUD, _, _, "b");
    set_task(3.0, "PUG_LoadPendingRegistration", TASK_NEXTMAP);
}

public hns_sql_connection(Handle:hSqlTuple)
{
    g_hSqlTuple = hSqlTuple;
    g_bSqlReady = true;
    SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", "CREATE TABLE IF NOT EXISTS `hns_pug_players` (`steamid` VARCHAR(35) NOT NULL PRIMARY KEY, `name` VARCHAR(64) NOT NULL DEFAULT '', `ip` VARCHAR(32) NOT NULL DEFAULT '', `matches` INT NOT NULL DEFAULT 0, `wins` INT NOT NULL DEFAULT 0, `losses` INT NOT NULL DEFAULT 0, `points` INT NOT NULL DEFAULT 1000, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)");
    SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", "CREATE TABLE IF NOT EXISTS `hns_pug_registration` (`slot` INT NOT NULL PRIMARY KEY, `steamid` VARCHAR(35) NOT NULL, `ip` VARCHAR(32) NOT NULL DEFAULT '', `source_map` VARCHAR(32) NOT NULL DEFAULT '')");
}

public client_putinserver(id)
{
    g_bRegistered[id] = false;
    g_bDataLoaded[id] = false;
    if (!is_user_bot(id))
        set_task(1.0, "PUG_LoadPlayer", id);
}

public client_authorized(id, const authid[])
{
    if (is_user_connected(id) && !is_user_bot(id))
        set_task(0.5, "PUG_LoadPlayer", id);
}

public client_disconnected(id)
{
    if (g_bRegistered[id] && !g_bLocked && g_iRegisteredCount > 0)
        g_iRegisteredCount--;
    g_bRegistered[id] = false;
    g_bDataLoaded[id] = false;
}

public PUG_LoadPlayer(id)
{
    if (!g_bSqlReady || !is_user_connected(id) || is_user_bot(id)) return;

    get_user_authid(id, g_szSteam[id], charsmax(g_szSteam[]));
    get_user_ip(id, g_szIp[id], charsmax(g_szIp[]), 1);
    if (!PUG_IsValidSteam(g_szSteam[id])) return;

    new steam[70], query[512], data[2];
    SQL_QuoteString(Empty_Handle, steam, charsmax(steam), g_szSteam[id]);
    formatex(query, charsmax(query), "SELECT `name`,`ip`,`matches`,`wins`,`losses`,`points` FROM `hns_pug_players` WHERE `steamid`='%s' LIMIT 1", steam);
    data[0] = id;
    data[1] = 0;
    SQL_ThreadQuery(g_hSqlTuple, "PUG_PlayerLoaded", query, data, sizeof(data));
}

public PUG_PlayerLoaded(failstate, Handle:query, error[], errnum, data[], datasize, Float:queue)
{
    new id = data[0];
    if (failstate != TQUERY_SUCCESS) { log_amx("[PugRegistration] SQL load error #%d: %s", errnum, error); return; }
    if (!is_user_connected(id)) return;

    if (SQL_NumResults(query))
    {
        g_iMatches[id] = SQL_ReadResult(query, 2);
        g_iWins[id] = SQL_ReadResult(query, 3);
        g_iLosses[id] = SQL_ReadResult(query, 4);
        g_iPoints[id] = SQL_ReadResult(query, 5);
    }
    else
    {
        g_iMatches[id] = 0;
        g_iWins[id] = 0;
        g_iLosses[id] = 0;
        g_iPoints[id] = 1000;
        PUG_SavePlayer(id);
    }
    g_bDataLoaded[id] = true;
}

public PUG_SavePlayer(id)
{
    if (!g_bSqlReady || !is_user_connected(id) || !PUG_IsValidSteam(g_szSteam[id])) return;

    new name[128], steam[70], ip[70], query[768];
    get_user_name(id, name, charsmax(name));
    SQL_QuoteString(Empty_Handle, name, charsmax(name), name);
    SQL_QuoteString(Empty_Handle, steam, charsmax(steam), g_szSteam[id]);
    SQL_QuoteString(Empty_Handle, ip, charsmax(ip), g_szIp[id]);
    formatex(query, charsmax(query), "INSERT INTO `hns_pug_players` (`steamid`,`name`,`ip`,`matches`,`wins`,`losses`,`points`) VALUES ('%s','%s','%s',%d,%d,%d,%d) ON DUPLICATE KEY UPDATE `name`='%s',`ip`='%s',`matches`=%d,`wins`=%d,`losses`=%d,`points`=%d", steam, name, ip, g_iMatches[id], g_iWins[id], g_iLosses[id], g_iPoints[id], name, ip, g_iMatches[id], g_iWins[id], g_iLosses[id], g_iPoints[id]);
    SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", query);
}

public PUG_QueryIgnore(failstate, Handle:query, error[], errnum, data[], datasize, Float:queue)
{
    if (failstate != TQUERY_SUCCESS)
        log_amx("[PugRegistration] SQL error #%d: %s", errnum, error);
}

public PUG_RegistrationMenu(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    new menu = menu_create("^4[HNS]^1 PUG报名", "PUG_MenuHandler");
    menu_additem(menu, g_bRegistered[id] ? "取消报名" : "报名下一场比赛", "1");
    menu_additem(menu, "查看报名名单", "2");
    menu_additem(menu, "查看我的积分", "3");
    menu_additem(menu, "刷新", "4");
    menu_setprop(menu, MPROP_EXITNAME, "退出");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public PUG_MenuHandler(id, menu, item)
{
    if (item == MENU_EXIT) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new info[8], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);
    new choice = str_to_num(info);
    menu_destroy(menu);
    switch (choice)
    {
        case 1: g_bRegistered[id] ? PUG_Unregister(id) : PUG_Register(id);
        case 2: PUG_ShowRegistrationList(id, 0);
        case 3: PUG_ShowMyData(id);
        default: PUG_RegistrationMenu(id);
    }
    return PLUGIN_HANDLED;
}

public PUG_Register(id)
{
    if (!is_user_connected(id) || g_bLocked || g_bRegistered[id]) return PLUGIN_HANDLED;
    if (g_iRegisteredCount >= PUG_GetRegistrationMax()) { client_print_color(id, print_team_red, "[HNS] 报名人数已满"); return PLUGIN_HANDLED; }
    g_bRegistered[id] = true;
    g_iRegisteredCount++;
    client_print_color(0, print_team_blue, "[HNS] %n 已报名，当前 %d/%d", id, g_iRegisteredCount, REQUIRED_PLAYERS);
    if (g_iRegisteredCount >= REQUIRED_PLAYERS)
    {
        g_bLocked = true;
        PUG_SaveRegistration();
        client_print_color(0, print_team_blue, "[HNS] 报名完成，下一张地图开始比赛");
    }
    return PLUGIN_HANDLED;
}

public PUG_Unregister(id)
{
    if (!is_user_connected(id) || g_bLocked || !g_bRegistered[id]) return PLUGIN_HANDLED;
    g_bRegistered[id] = false;
    if (g_iRegisteredCount > 0) g_iRegisteredCount--;
    return PLUGIN_HANDLED;
}

public PUG_RegistrationHUD()
{
    if (!g_bLocked && g_iRegisteredCount <= 0) return;
    set_hudmessage(0, 255, 0, 0.02, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 8);
    show_hudmessage(0, "PUG报名: %d/%d", g_iRegisteredCount, REQUIRED_PLAYERS);
}

public PUG_SaveRegistration()
{
    if (!g_bSqlReady) return;
    new query[768], steam[70], ip[70], map[70];
    SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", "DELETE FROM `hns_pug_registration`");
    get_mapname(g_szSourceMap, charsmax(g_szSourceMap));
    SQL_QuoteString(Empty_Handle, map, charsmax(map), g_szSourceMap);
    new slot;
    for (new id = 1; id <= MAX_PLAYERS && slot < REQUIRED_PLAYERS; id++)
    {
        if (!g_bRegistered[id] || !is_user_connected(id)) continue;
        get_user_authid(id, g_szSteam[id], charsmax(g_szSteam[]));
        get_user_ip(id, g_szIp[id], charsmax(g_szIp[]), 1);
        SQL_QuoteString(Empty_Handle, steam, charsmax(steam), g_szSteam[id]);
        SQL_QuoteString(Empty_Handle, ip, charsmax(ip), g_szIp[id]);
        formatex(query, charsmax(query), "INSERT INTO `hns_pug_registration` (`slot`,`steamid`,`ip`,`source_map`) VALUES (%d,'%s','%s','%s')", slot + 1, steam, ip, map);
        SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", query);
        slot++;
    }
}

public PUG_LoadPendingRegistration()
{
    if (!g_bSqlReady) { set_task(3.0, "PUG_LoadPendingRegistration", TASK_NEXTMAP); return; }
    SQL_ThreadQuery(g_hSqlTuple, "PUG_PendingLoaded", "SELECT `slot`,`steamid`,`ip`,`source_map` FROM `hns_pug_registration` ORDER BY `slot`");
}

public PUG_PendingLoaded(failstate, Handle:query, error[], errnum, data[], datasize, Float:queue)
{
    if (failstate != TQUERY_SUCCESS) { log_amx("[PugRegistration] SQL registration load error #%d: %s", errnum, error); return; }
    g_iPendingCount = 0;
    new currentMap[32];
    get_mapname(currentMap, charsmax(currentMap));
    while (SQL_MoreResults(query))
    {
        new sourceMap[32];
        SQL_ReadResult(query, 1, g_szPendingSteam[g_iPendingCount], charsmax(g_szPendingSteam[]));
        SQL_ReadResult(query, 2, g_szPendingIp[g_iPendingCount], charsmax(g_szPendingIp[]));
        SQL_ReadResult(query, 3, sourceMap, charsmax(sourceMap));
        if (!equal(sourceMap, currentMap) && g_iPendingCount < REQUIRED_PLAYERS) g_iPendingCount++;
        if (!SQL_NextRow(query)) break;
    }
    if (g_iPendingCount < REQUIRED_PLAYERS) return;
    g_bLocked = true;
    g_iRegisteredCount = REQUIRED_PLAYERS;
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id)) continue;
        get_user_authid(id, g_szSteam[id], charsmax(g_szSteam[]));
        for (new i; i < g_iPendingCount; i++)
        {
            if (equal(g_szSteam[id], g_szPendingSteam[i]))
            {
                g_bRegistered[id] = true;
                break;
            }
        }
    }
    new found = PUG_CountPendingConnected();
    if (found >= REQUIRED_PLAYERS) PUG_StartPendingMatch();
    else { g_iWaitLeft = floatround(WAIT_TIME); set_task(1.0, "PUG_WaitForPlayers", TASK_WAIT, _, _, "b"); }
}

public PUG_WaitForPlayers()
{
    if (!g_bLocked) { remove_task(TASK_WAIT); return; }
    if (PUG_CountPendingConnected() >= REQUIRED_PLAYERS) { remove_task(TASK_WAIT); PUG_StartPendingMatch(); return; }
    if (--g_iWaitLeft <= 0) { remove_task(TASK_WAIT); g_bLocked = false; g_iPendingCount = 0; SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", "DELETE FROM `hns_pug_registration`"); }
}

public PUG_ShowRegistrationList(id, page)
{
    new menu = menu_create("^4[HNS]^1 已报名玩家", "PUG_RegistrationListHandler");
    new registered[MAX_PLAYERS], num, text[64], info[16], total, shown;
    get_players(registered, num, "ch");

    for (new i; i < num; i++)
        if (g_bRegistered[registered[i]]) registered[total++] = registered[i];

    new start = page * REG_PAGE_SIZE;
    for (new i = start; i < total && shown < REG_PAGE_SIZE; i++)
    {
        formatex(text, charsmax(text), "%d. %n", i + 1, registered[i]);
        menu_additem(menu, text, "0", 0);
        shown++;
    }

    if (!total)
        menu_additem(menu, "当前没有报名玩家", "0", 0);

    if (page > 0)
    {
        formatex(info, charsmax(info), "- %d", page - 1);
        menu_additem(menu, "上一页", info);
    }
    if (start + REG_PAGE_SIZE < total)
    {
        formatex(info, charsmax(info), "+ %d", page + 1);
        menu_additem(menu, "下一页", info);
    }
    menu_setprop(menu, MPROP_EXITNAME, "返回");
    menu_display(id, menu);
}

public PUG_RegistrationListHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        PUG_RegistrationMenu(id);
        return PLUGIN_HANDLED;
    }

    new info[16], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);
    menu_destroy(menu);

    if (info[0] == '+') PUG_ShowRegistrationList(id, str_to_num(info[2]));
    else if (info[0] == '-') PUG_ShowRegistrationList(id, str_to_num(info[2]));
    else PUG_ShowRegistrationList(id, 0);
    return PLUGIN_HANDLED;
}

public PUG_ShowMyData(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    new menu = menu_create("^4[HNS]^1 我的比赛数据", "PUG_BackHandler"), text[96], winrate[16];
    PUG_GetWinRate(id, winrate, charsmax(winrate));
    formatex(text, charsmax(text), "积分: %d", g_iPoints[id]); menu_additem(menu, text, "0", 0);
    formatex(text, charsmax(text), "比赛: %d", g_iMatches[id]); menu_additem(menu, text, "0", 0);
    formatex(text, charsmax(text), "胜: %d / 负: %d", g_iWins[id], g_iLosses[id]); menu_additem(menu, text, "0", 0);
    formatex(text, charsmax(text), "胜率: %s", winrate); menu_additem(menu, text, "0", 0);
    menu_setprop(menu, MPROP_EXITNAME, "返回");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public PUG_BackHandler(id, menu, item)
{
    menu_destroy(menu);
    PUG_RegistrationMenu(id);
    return PLUGIN_HANDLED;
}

stock PUG_StartPendingMatch()
{
    new ids[REQUIRED_PLAYERS], count;
    PUG_GetPendingPlayers(ids, count);
    if (count < REQUIRED_PLAYERS) return;
    g_bActiveMatch = true;
    PUG_BuildBalancedTeams(ids, count);
    for (new i; i < REQUIRED_PLAYERS; i++)
    {
        get_user_authid(ids[i], g_szActiveSteam[i], charsmax(g_szActiveSteam[]));
        get_user_ip(ids[i], g_szActiveIp[i], charsmax(g_szActiveIp[]), 1);
        get_user_name(ids[i], g_szActiveName[i], charsmax(g_szActiveName[]));
    }
    for (new i; i < count; i++) rg_set_user_team(ids[i], TEAM_SPECTATOR);
    for (new i; i < count; i++) { rg_set_user_team(ids[i], g_iActiveTeam[i] == 1 ? TEAM_TERRORIST : TEAM_CT); rg_round_respawn(ids[i]); }
    hns_set_mode(MODE_MIX);
    SQL_ThreadQuery(g_hSqlTuple, "PUG_QueryIgnore", "DELETE FROM `hns_pug_registration`");
    g_bLocked = false;
    g_iPendingCount = 0;
}

public hns_match_finished(iWinTeam)
{
    if (!g_bActiveMatch) return;
    for (new i; i < REQUIRED_PLAYERS; i++)
    {
        new id = PUG_FindConnectedBySteam(g_szActiveSteam[i]);
        if (id > 0)
        {
            g_iMatches[id]++;
            if (g_iActiveTeam[i] == iWinTeam) { g_iWins[id]++; g_iPoints[id] += 25; }
            else { g_iLosses[id]++; g_iPoints[id] = max(0, g_iPoints[id] - 15); }
            PUG_SavePlayer(id);
        }
    }
    g_bActiveMatch = false;
}

stock PUG_BuildBalancedTeams(ids[], count)
{
    new used[REQUIRED_PLAYERS], size[3], Float:rating[3];
    for (new i; i < count; i++)
    {
        new best = -1; new Float:bestRating = -1.0;
        for (new j; j < count; j++) if (!used[j]) { new Float:r = float(g_iPoints[ids[j]]); if (r > bestRating) { bestRating = r; best = j; } }
        if (best < 0) continue;
        used[best] = 1;
        new team = size[1] >= 5 ? 2 : (size[2] >= 5 ? 1 : (rating[1] <= rating[2] ? 1 : 2));
        g_iActiveTeam[best] = team; size[team]++; rating[team] += bestRating;
    }
}

stock PUG_GetPendingPlayers(ids[], &count)
{
    count = 0;
    for (new id = 1; id <= MAX_PLAYERS && count < REQUIRED_PLAYERS; id++)
    {
        if (!is_user_connected(id)) continue;
        get_user_authid(id, g_szSteam[id], charsmax(g_szSteam[]));
        for (new i; i < g_iPendingCount; i++) if (equal(g_szSteam[id], g_szPendingSteam[i])) { ids[count++] = id; break; }
    }
}

stock PUG_CountPendingConnected()
{
    new ids[REQUIRED_PLAYERS], count;
    PUG_GetPendingPlayers(ids, count);
    return count;
}

stock PUG_FindConnectedBySteam(const steam[])
{
    for (new id = 1; id <= MAX_PLAYERS; id++) if (is_user_connected(id)) { new current[35]; get_user_authid(id, current, charsmax(current)); if (equal(current, steam)) return id; }
    return 0;
}

stock PUG_GetRegistrationMax()
{
    if (get_pcvar_num(g_pUnlimited)) return MAX_REG_PLAYERS;
    new maxPlayers = clamp(get_pcvar_num(g_pMaxPlayers), 2, 12);
    if (maxPlayers & 1) maxPlayers--;
    return maxPlayers;
}

stock bool:PUG_IsValidSteam(const steam[])
{
    return steam[0] && !equali(steam, "STEAM_ID_PENDING") && !equali(steam, "STEAM_ID_LAN") && !equali(steam, "VALVE_ID_LAN") && !equali(steam, "BOT");
}

stock PUG_GetWinRate(id, output[], len)
{
    formatex(output, len, "%0.2f%%", g_iMatches[id] > 0 ? float(g_iWins[id]) * 100.0 / float(g_iMatches[id]) : 0.0);
}

public plugin_end()
{
    if (g_hSqlTuple) SQL_FreeHandle(g_hSqlTuple);
}

/* ============================================================
   HnsConnectInfo  -  进服提示
   ------------------------------------------------------------
   玩家进入服务器时，按每人 /lang 发送聊天提示:
     [HNS] 服主 LINNA 进入服务器
     [HNS] PTS / 段位 / 胜负 / GBIC
     [HNS] SteamID / 正版盗版

   依赖:
     - HnsLanguage.amxx   (/lang 简体/繁体/英语/俄语)
     - HnsMatchPts.amxx   (PTS, 可选; 未加载时显示默认 1000)
     - hns_gc             (GBIC, 可选)
     - Reunion            (正版/盗版, 可选)
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_language>
#include <hns_matchsystem_pts>
#include <hns_gc>

#define PLUGIN_NAME    "HNS Connect Info"
#define PLUGIN_VERSION "1.2.5"
#define PLUGIN_AUTHOR  "GTR"

#define TASK_ANNOUNCE  54000
#define ANNOUNCE_DELAY 1.80
#define ANNOUNCE_RETRY 1.20
#define ANNOUNCE_MAX   6.50

#define MSG_MAX 191
#define NAME_MAX 32
#define AUTH_MAX 35

new bool:g_bNeedAnnounce[MAX_PLAYERS + 1];
new bool:g_bAnnounced[MAX_PLAYERS + 1];
new Float:g_flJoinTime[MAX_PLAYERS + 1];
new g_pEnabled;
new g_pSound;
new bool:g_bHasReunion;

public plugin_natives() {
set_native_filter("NativeFilter");
}

public NativeFilter(const szName[], iIndex, iTrap) {
if (equal(szName, "HnsLang_Get")
|| equal(szName, "HnsLang_GetPlayer")
|| equal(szName, "hns_gc_sql_available")
|| equal(szName, "hns_gc_sql_get")
|| equal(szName, "hns_gc_sql_set")
|| equal(szName, "hns_gc_local_available")
|| equal(szName, "hns_gc_local_get")
|| equal(szName, "hns_gc_local_set")
|| equal(szName, "has_reunion")
|| equal(szName, "REU_GetAuthtype")) {
if (equal(szName, "has_reunion") || equal(szName, "REU_GetAuthtype"))
g_bHasReunion = false;
return PLUGIN_HANDLED;
}
return PLUGIN_CONTINUE;
}

public plugin_precache() {
precache_sound("buttons/blip1.wav");
}

public plugin_init() {
register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
g_pEnabled = register_cvar("hns_connect_info", "1");
g_pSound = register_cvar("hns_connect_sound", "1");
g_bHasReunion = has_reunion();
}

public client_connect(id) {
ClearPlayer(id);
g_bNeedAnnounce[id] = true;
}

public client_putinserver(id) {
if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
return;
if (g_bAnnounced[id])
return;

// ReHLDS/本地服经常不走 client_connect, 真正进服后补触发
g_bNeedAnnounce[id] = true;
g_flJoinTime[id] = get_gametime();
remove_task(id + TASK_ANNOUNCE);
set_task(ANNOUNCE_DELAY, "TaskAnnounce", id + TASK_ANNOUNCE);
}

public client_disconnected(id) {
remove_task(id + TASK_ANNOUNCE);
ClearPlayer(id);
}

ClearPlayer(id) {
g_bNeedAnnounce[id] = false;
g_bAnnounced[id] = false;
g_flJoinTime[id] = 0.0;
g_ePlayerPtsData[id][e_bInit] = false;
g_ePlayerPtsData[id][e_iPts] = 0;
g_ePlayerPtsData[id][e_iWins] = 0;
g_ePlayerPtsData[id][e_iLoss] = 0;
g_ePlayerPtsData[id][e_iTop] = 0;
g_ePlayerPtsData[id][e_szRank][0] = EOS;
}

public TaskAnnounce(taskid) {
new id = taskid - TASK_ANNOUNCE;
if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
return;
if (!g_bNeedAnnounce[id] || g_bAnnounced[id])
return;
if (!get_pcvar_num(g_pEnabled))
return;

new bool:bPtsReady = g_ePlayerPtsData[id][e_bInit];
new bool:bAuthReady = !IsAuthPending(id);
new Float:flWaited = get_gametime() - g_flJoinTime[id];
if ((!bPtsReady || !bAuthReady) && flWaited < ANNOUNCE_MAX) {
set_task(ANNOUNCE_RETRY, "TaskAnnounce", id + TASK_ANNOUNCE);
return;
}

AnnounceJoin(id);
}

AnnounceJoin(id) {
if (!is_user_connected(id) || g_bAnnounced[id])
return;

g_bAnnounced[id] = true;
g_bNeedAnnounce[id] = false;

new szName[NAME_MAX];
get_user_name(id, szName, charsmax(szName));

new iPts = g_ePlayerPtsData[id][e_iPts];
if (!g_ePlayerPtsData[id][e_bInit] && iPts <= 0)
iPts = 1000;

new szRank[10];
copy(szRank, charsmax(szRank), g_ePlayerPtsData[id][e_szRank]);
if (!szRank[0])
copy(szRank, charsmax(szRank), get_skill_player(iPts));

new iWins = g_ePlayerPtsData[id][e_iWins];
new iLoss = g_ePlayerPtsData[id][e_iLoss];
new iGold = hns_gc_available() ? hns_gc_get_player(id) : 0;

new szAuth[AUTH_MAX];
GetPlayerAuth(id, szAuth, charsmax(szAuth));

new iPlayers[MAX_PLAYERS], iNum;
get_players(iPlayers, iNum, "ch");
for (new i = 0; i < iNum; i++) {
new viewer = iPlayers[i];
if (!is_user_connected(viewer) || is_user_bot(viewer) || is_user_hltv(viewer))
continue;

new szRole[24], szShowName[NAME_MAX], szAccount[16];
GetJoinIdentity(id, viewer, szName, szRole, charsmax(szRole), szShowName, charsmax(szShowName));
GetAccountType(id, viewer, szAccount, charsmax(szAccount));

new szLine1[MSG_MAX], szLine2[MSG_MAX], szLine3[MSG_MAX];
LangFormat(viewer, "CONNECT_JOIN", "^4[HNS]^1 %s ^3%s^1 进入服务器",
szLine1, charsmax(szLine1), szRole, szShowName);
LangFormat(viewer, "CONNECT_INFO", "^4[HNS]^1 PTS: ^4%d^1 (^3%s^1)  胜/负: ^4%d^1/^3%d^1  GBIC: ^4%d",
szLine2, charsmax(szLine2), iPts, szRank, iWins, iLoss, iGold);
LangFormat(viewer, "CONNECT_DETAIL", "^4[HNS]^1 SteamID: ^3%s^1  账号: ^3%s",
szLine3, charsmax(szLine3), szAuth, szAccount);

client_print_color(viewer, print_team_default, "%s", szLine1);
client_print_color(viewer, print_team_default, "%s", szLine2);
client_print_color(viewer, print_team_default, "%s", szLine3);
}

if (get_pcvar_num(g_pSound))
client_cmd(0, "spk buttons/blip1");
}

GetJoinIdentity(id, viewer, const szName[], szRole[], iRoleLen, szShowName[], iNameLen) {
copy(szShowName, iNameLen, szName);

new iFlags = get_user_flags(id);
if (iFlags & ADMIN_IMMUNITY) {
LangGet(viewer, "CONNECT_ROLE_OWNER", szRole, iRoleLen, "服主");
LangGet(viewer, "CONNECT_OWNER_NAME", szShowName, iNameLen, "LINNA");
return;
}
if (iFlags & ADMIN_RESERVATION) {
LangGet(viewer, "CONNECT_ROLE_ADMIN", szRole, iRoleLen, "管理员");
return;
}
if (iFlags & ADMIN_BAN) {
LangGet(viewer, "CONNECT_ROLE_VIP", szRole, iRoleLen, "VIP");
return;
}
if (iFlags & (ADMIN_KICK | ADMIN_SLAY | ADMIN_MAP | ADMIN_CVAR | ADMIN_CFG | ADMIN_RCON | ADMIN_MENU)) {
LangGet(viewer, "CONNECT_ROLE_ADMIN", szRole, iRoleLen, "管理员");
return;
}

LangGet(viewer, "CONNECT_ROLE_PLAYER", szRole, iRoleLen, "玩家");
}

GetAccountType(id, viewer, szOut[], iLen) {
if (IsSteamAccount(id))
LangGet(viewer, "CONNECT_STEAM", szOut, iLen, "正版");
else
LangGet(viewer, "CONNECT_PIRATE", szOut, iLen, "盗版");
}

bool:IsSteamAccount(id) {
if (g_bHasReunion) {
return (REU_GetAuthtype(id) == CA_TYPE_STEAM);
}

new szAuth[AUTH_MAX];
get_user_authid(id, szAuth, charsmax(szAuth));
if (!szAuth[0] || containi(szAuth, "PENDING") != -1)
return false;
if (containi(szAuth, "STEAM_ID") != -1)
return false;
if (containi(szAuth, "VALVE") != -1)
return false;
if (equali(szAuth, "STEAM_0:0:0") || equali(szAuth, "STEAM_1:0:0"))
return false;
if (equali(szAuth, "BOT"))
return false;
return true;
}

GetPlayerAuth(id, szOut[], iLen) {
get_user_authid(id, szOut, iLen);
if (!szOut[0] || containi(szOut, "PENDING") != -1)
copy(szOut, iLen, "STEAM_ID_PENDING");
}

bool:IsAuthPending(id) {
new szAuth[AUTH_MAX];
get_user_authid(id, szAuth, charsmax(szAuth));
return (!szAuth[0] || containi(szAuth, "PENDING") != -1);
}

LangUnescape(szText[], iLen) {
replace_all(szText, iLen, "^^n", "^n");
replace_all(szText, iLen, "^^1", "^1");
replace_all(szText, iLen, "^^2", "^2");
replace_all(szText, iLen, "^^3", "^3");
replace_all(szText, iLen, "^^4", "^4");
}

LangGet(id, const szKey[], szOut[], iLen, const szFallback[]) {
szOut[0] = EOS;
HnsLang_Get(id, szKey, szOut, iLen);
if (!szOut[0] || equal(szOut, szKey))
copy(szOut, iLen, szFallback);
LangUnescape(szOut, iLen);
}

LangFormat(id, const szKey[], const szFallback[], szOut[], iLen, any:...) {
new szFmt[MSG_MAX];
LangGet(id, szKey, szFmt, charsmax(szFmt), szFallback);
vformat(szOut, iLen, szFmt, 6);
}

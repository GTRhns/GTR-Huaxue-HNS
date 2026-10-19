#include <amxmodx>
#include <reapi>
#include <sqlx>
#include <nvault>
#include <hns_matchsystem>
#include <hns_matchsystem_sql>
#include <hns_matchsystem_maps>
#include <hns_optional_sql>

new const g_szTablePts[] = "hns_pts";

#define OBC_BASE 50
#define OBC_WIN 15
#define OBC_LOSS 10

#define SQL_CREATE_TABLE \
"CREATE TABLE IF NOT EXISTS `%s` ( \
`id`INT(11) NOT NULL PRIMARY KEY, \
`wins`INT(11) NOT NULL DEFAULT 0, \
`loss`INT(11) NOT NULL DEFAULT 0, \
`pts`INT(11) NOT NULL DEFAULT 50, \
`boost_wins`INT(11) NOT NULL DEFAULT 0, \
`boost_loss`INT(11) NOT NULL DEFAULT 0, \
`boost_pts`INT(11) NOT NULL DEFAULT 50, \
`skill_wins`INT(11) NOT NULL DEFAULT 0, \
`skill_loss`INT(11) NOT NULL DEFAULT 0, \
`skill_pts`INT(11) NOT NULL DEFAULT 50, \
`obc_ready`TINYINT NOT NULL DEFAULT 1 \
);"

#define SQL_CREATE_DATA \
"INSERT INTO `%s` (id, pts, boost_pts, skill_pts, obc_ready) VALUES (%d, 50, 50, 50, 1)"

#define SQL_CREATE_DATA_BY_STEAM \
"INSERT INTO `%s` (id, pts, boost_pts, skill_pts, obc_ready) \
SELECT `id`, 50, 50, 50, 1 FROM `%s` WHERE `steamid` = '%s' LIMIT 1"

#define SQL_ENSURE_PTS \
"INSERT IGNORE INTO `%s` (id, pts, boost_pts, skill_pts, obc_ready) \
SELECT `id`, 50, 50, 50, 1 FROM `%s` WHERE `steamid` = '%s' LIMIT 1;"

#define SQL_SET_OBC \
"UPDATE `%s` SET \
`wins`=`wins`+%d, `loss`=`loss`+%d, `pts`=GREATEST(`pts`+%d,0), \
`boost_wins`=`boost_wins`+%d, `boost_loss`=`boost_loss`+%d, `boost_pts`=GREATEST(`boost_pts`+%d,0), \
`skill_wins`=`skill_wins`+%d, `skill_loss`=`skill_loss`+%d, `skill_pts`=GREATEST(`skill_pts`+%d,0) \
WHERE `id` IN (SELECT `id` FROM `%s` WHERE `steamid`='%s');"

#define SQL_SELECT_DATA \
"SELECT * \
FROM `%s` \
WHERE `id` = \
( \
SELECT `id` \
FROM   `hns_players` \
WHERE  `steamid` = '%s' \
);"

#define SQL_GET_TOP \
"SELECT COUNT(*) \
FROM `%s` \
WHERE `pts` >= %d"

#define SQL_SET_RANK \
"UPDATE `%s` SET \
`rank` = %d \
WHERE `id` IN \
( \
SELECT `id` \
FROM   `%s` \
WHERE  `steamid` = '%s' \
);"

enum _:SQL {
SQL_TABLE,
SQL_INSERT,
SQL_SELECT,
SQL_TOP,
SQL_WINNERS,
SQL_LOOSERS,
SQL_SCHEMA,
SQL_OBC_SAVE
};

new Handle:g_hSqlTuple;
new bool:g_bSqlReady;
new g_iVault = INVALID_HANDLE;
new g_sTablePlayers[32];

enum _:PTS_DATA {
e_iPts,
e_iWins,
e_iLoss,
e_iTop,
e_iBoostPts,
e_iBoostWins,
e_iBoostLoss,
e_iSkillPts,
e_iSkillWins,
e_iSkillLoss
};

new g_ePointsData[MAX_PLAYERS + 1][PTS_DATA];
new g_iKnifeKills[MAX_PLAYERS + 1];
new g_iKnifeBonus[MAX_PLAYERS + 1];

new const g_szLinkPts[] = "https://SITENAME/pts/pts.php";

new g_sPrefix[24];

new g_hFwdPlayerInit;
new g_hFwdObc;
new g_iSchemaStep;
new bool:g_bSchemaReady;
new bool:g_bSchemaStarted;
new g_iSavePending;

public plugin_natives() {
hns_register_optional_sql();
register_library("hns_obc");
register_native("hns_obc_knife_bonus", "NativeKnifeBonus");
}

public NativeKnifeBonus(iPlugin, iParams) {
new id = get_param(1);
if (id < 1 || id > MaxClients)
return 0;
return g_iKnifeBonus[id];
}

public plugin_init() {
register_plugin("Match: Pts", "1.3", "OpenHNS");

RegisterSayCmd("rank", "me", "CmdRank", 0, "Show rank");
RegisterSayCmd("pts", "ptstop", "CmdPts", 0, "Show top obs players");
RegisterSayCmd("obs", "obstop", "CmdPts", 0, "Show top obs players");
RegisterHookChain(RG_CBasePlayer_Killed, "OnPlayerKilled", true);

g_hFwdPlayerInit = CreateMultiForward("hns_pts_init_player", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
g_hFwdObc = CreateMultiForward("hns_obc_init_player", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);

register_dictionary("match_additons.txt");
}

public CmdRank(id) {
new szAll[16], szBoost[16], szSkill[16];
ObcRate(g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], szAll, charsmax(szAll));
ObcRate(g_ePointsData[id][e_iBoostWins], g_ePointsData[id][e_iBoostLoss], szBoost, charsmax(szBoost));
ObcRate(g_ePointsData[id][e_iSkillWins], g_ePointsData[id][e_iSkillLoss], szSkill, charsmax(szSkill));
client_print_color(id, print_team_default, "%L", id, "OBS_RANK_ALL", g_sPrefix, g_ePointsData[id][e_iPts], g_ePointsData[id][e_iTop], g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], szAll);
client_print_color(id, print_team_default, "%L", id, "OBS_RANK_BOOST", g_sPrefix, g_ePointsData[id][e_iBoostPts], g_ePointsData[id][e_iBoostWins] + g_ePointsData[id][e_iBoostLoss], szBoost);
client_print_color(id, print_team_default, "%L", id, "OBS_RANK_SKILL", g_sPrefix, g_ePointsData[id][e_iSkillPts], g_ePointsData[id][e_iSkillWins] + g_ePointsData[id][e_iSkillLoss], szSkill);
return PLUGIN_HANDLED;
}

public hns_match_started() {
arrayset(g_iKnifeKills, 0, sizeof g_iKnifeKills);
arrayset(g_iKnifeBonus, 0, sizeof g_iKnifeBonus);
}

public OnPlayerKilled(iVictim, iAttacker) {
if (iAttacker < 1 || iAttacker > MaxClients || iAttacker == iVictim)
return;
if (!is_user_connected(iAttacker) || !is_user_connected(iVictim))
return;
if (hns_get_state() != STATE_ENABLED && hns_get_state() != STATE_PAUSED)
return;
if (get_user_weapon(iAttacker) != CSW_KNIFE)
return;
if (rg_get_user_team(iAttacker) == rg_get_user_team(iVictim))
return;
g_iKnifeKills[iAttacker]++;
}

public CmdPts(id) {
new szMotd[MAX_MOTD_LENGTH];

formatex(szMotd, sizeof(szMotd) - 1,\
"<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body><p><center>LOADING...</center></p></body></html>",\
g_szLinkPts);

show_motd(id, szMotd);
}

public plugin_cfg() {
if (hns_sql_available())
hns_sql_get_table_name(g_sTablePlayers, charsmax(g_sTablePlayers));
else
copy(g_sTablePlayers, charsmax(g_sTablePlayers), "hns_players");

hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));

if (!g_bSqlReady)
Local_Init();
}

public plugin_end() {
if (g_iVault != INVALID_HANDLE) {
nvault_close(g_iVault);
g_iVault = INVALID_HANDLE;
}
}

public client_putinserver(id) {
if (!g_bSqlReady)
Local_Load(id);
}

public client_disconnected(id) {
if (!g_bSqlReady)
arrayset(g_ePointsData[id], 0, PTS_DATA);
}

public hns_match_finished(iWinTeam) {
if (get_num_players_in_match() < 2) {
arrayset(g_iKnifeBonus, 0, sizeof g_iKnifeBonus);
client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_NOT_PLR", g_sPrefix);
return;
}

new TeamName:winCsTeam = hns_get_match_team_cs(iWinTeam);
if (winCsTeam != TEAM_TERRORIST && winCsTeam != TEAM_CT)
return;

BuildKnifeBonus();
SetPts(winCsTeam);
}

public hns_sql_player_authorized(id) {
if (g_bSqlReady && g_bSchemaReady)
SQL_Select(id);
}

public hns_sql_connection(hSqlTuple) {
g_hSqlTuple = Handle:hSqlTuple;
g_bSqlReady = true;

if (g_iVault != INVALID_HANDLE) {
nvault_close(g_iVault);
g_iVault = INVALID_HANDLE;
}

new szQuery[512];
new cData[1] = SQL_TABLE;

formatex(szQuery, charsmax(szQuery), SQL_CREATE_TABLE, g_szTablePts);
SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
if (cData[0] == SQL_SCHEMA) {
SchemaNext();
return;
}

if (cData[0] == SQL_OBC_SAVE) {
if (iFailState != TQUERY_SUCCESS)
log_amx("SQL Error #%d - %s", iErrnum, szError);
if (g_iSavePending > 0)
g_iSavePending--;
if (g_iSavePending <= 0)
RefreshAllTops();
return;
}

if (iFailState != TQUERY_SUCCESS) {
log_amx("SQL Error #%d - %s", iErrnum, szError);
return;
}

switch(cData[0]) {
case SQL_TABLE: {
if (!g_bSchemaStarted) {
g_bSchemaStarted = true;
g_iSchemaStep = 0;
SchemaNext();
}
}
case SQL_SELECT: {
new id = cData[1];

if (SQL_NumResults(hQuery)) {
new index_wins = SQL_FieldNameToNum(hQuery, "wins");
new index_loss = SQL_FieldNameToNum(hQuery, "loss");
new index_pts = SQL_FieldNameToNum(hQuery, "pts");

g_ePointsData[id][e_iWins] = SQL_ReadResult(hQuery, index_wins);
g_ePointsData[id][e_iLoss] = SQL_ReadResult(hQuery, index_loss);
g_ePointsData[id][e_iPts] = SQL_ReadResult(hQuery, index_pts);
ReadModeColumn(hQuery, "boost_pts", "boost_wins", "boost_loss", g_ePointsData[id][e_iBoostPts], g_ePointsData[id][e_iBoostWins], g_ePointsData[id][e_iBoostLoss]);
ReadModeColumn(hQuery, "skill_pts", "skill_wins", "skill_loss", g_ePointsData[id][e_iSkillPts], g_ePointsData[id][e_iSkillWins], g_ePointsData[id][e_iSkillLoss]);

SQL_Top(id);
} else {
arrayset(g_ePointsData[id], 0, PTS_DATA);
SQL_Insert(id);
}
}
case SQL_INSERT: {
new id = cData[1];

if (!is_user_connected(id))
return;

SQL_Top(id);
}
case SQL_TOP: {
new id = cData[1];

if (!is_user_connected(id))
return;

if (SQL_NumResults(hQuery)) {
g_ePointsData[id][e_iTop] = SQL_ReadResult(hQuery, 0);
}

PushPts(id);
}
case SQL_WINNERS, SQL_LOOSERS: {
for(new i = 1; i <= MaxClients; i++) {
if (!is_user_connected(i))
continue;

if (get_member(i, m_iTeam) == TEAM_SPECTATOR)
continue;

SQL_Top(i);
}
}
}
}

SetPts(TeamName:team_winners) {
if (team_winners == TEAM_TERRORIST)
client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_SET_TT", g_sPrefix);
else
client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_SET_CT", g_sPrefix);

AnnounceMode();
AnnounceKnife();

if (!g_bSqlReady) {
Local_SetPts(team_winners);
return;
}

if (!g_bSchemaReady) {
log_amx("OBC schema not ready, this match was not saved");
ApplyMatchMemory(team_winners);
return;
}

SQL_SetPts(team_winners);
}

SQL_SetPts(TeamName:team_winners) {
new iMode = ObcMode();
g_iSavePending = 0;

new iPlayers[MAX_PLAYERS], iNum;
get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "TERRORIST" : "CT");
for (new i; i < iNum; i++) {
if (!IsPtsPlayer(iPlayers[i]))
continue;
new iDelta = ApplyObc(iPlayers[i], true, iMode);
SavePlayerSql(iPlayers[i], true, iDelta, iMode);
}

get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "CT" : "TERRORIST");
for (new i; i < iNum; i++) {
if (!IsPtsPlayer(iPlayers[i]))
continue;
new iDelta = ApplyObc(iPlayers[i], false, iMode);
SavePlayerSql(iPlayers[i], false, iDelta, iMode);
}

if (g_iSavePending <= 0)
RefreshAllTops();
}

public SQL_Select(id) {
if (!is_user_connected(id))
return;

new szQuery[512];
new cData[2];

cData[0] = SQL_SELECT;
cData[1] = id;

new szAuthId[MAX_AUTHID_LENGTH];
get_user_authid(id, szAuthId, charsmax(szAuthId));

formatex(szQuery, charsmax(szQuery), SQL_SELECT_DATA, g_szTablePts, szAuthId);
SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Insert(id) {
new szQuery[512];
new cData[2];

cData[0] = SQL_INSERT;
cData[1] = id;

g_ePointsData[id][e_iPts] = OBC_BASE;
g_ePointsData[id][e_iBoostPts] = OBC_BASE;
g_ePointsData[id][e_iSkillPts] = OBC_BASE;

new iPlayerId = hns_sql_available() ? hns_sql_get_player_id(id) : 0;
if (iPlayerId) {
formatex(szQuery, charsmax(szQuery), SQL_CREATE_DATA, g_szTablePts, iPlayerId);
} else {
new szAuthId[MAX_AUTHID_LENGTH];
get_user_authid(id, szAuthId, charsmax(szAuthId));
if (!szAuthId[0] || containi(szAuthId, "PENDING") != -1)
return;
formatex(szQuery, charsmax(szQuery), SQL_CREATE_DATA_BY_STEAM, g_szTablePts, g_sTablePlayers, szAuthId);
}

SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Top(id) {
new szQuery[512];
new cData[2];

cData[0] = SQL_TOP;
cData[1] = id;

new szAuthId[MAX_AUTHID_LENGTH];
get_user_authid(id, szAuthId, charsmax(szAuthId));

formatex(szQuery, charsmax(szQuery), SQL_GET_TOP, g_szTablePts, g_ePointsData[id][e_iPts]);
SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

Local_Init() {
if (g_iVault == INVALID_HANDLE)
g_iVault = nvault_open("hns_pts");
}

Local_Load(id) {
if (!is_user_connected(id))
return;

Local_Init();
arrayset(g_ePointsData[id], 0, PTS_DATA);
g_ePointsData[id][e_iPts] = OBC_BASE;
g_ePointsData[id][e_iBoostPts] = OBC_BASE;
g_ePointsData[id][e_iSkillPts] = OBC_BASE;

new szAuth[MAX_AUTHID_LENGTH], szData[96];
get_user_authid(id, szAuth, charsmax(szAuth));

new bool:bConverted = false;
if (nvault_get(g_iVault, szAuth, szData, charsmax(szData)) && szData[0])
bConverted = Local_Unpack(id, szData);

Local_RefreshTop();
PushPts(id);
if (bConverted)
Local_Save(id);
}

Local_Save(id) {
if (g_iVault == INVALID_HANDLE || !is_user_connected(id))
return;

new szAuth[MAX_AUTHID_LENGTH];
get_user_authid(id, szAuth, charsmax(szAuth));
nvault_set(g_iVault, szAuth, fmt("v2 %d %d %d %d %d %d %d %d %d", g_ePointsData[id][e_iPts], g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], g_ePointsData[id][e_iBoostPts], g_ePointsData[id][e_iBoostWins], g_ePointsData[id][e_iBoostLoss], g_ePointsData[id][e_iSkillPts], g_ePointsData[id][e_iSkillWins], g_ePointsData[id][e_iSkillLoss]));
}

Local_RefreshTop() {
for (new id = 1; id <= MaxClients; id++) {
if (!is_user_connected(id))
continue;

new iTop = 1;
for (new i = 1; i <= MaxClients; i++) {
if (!is_user_connected(i) || i == id)
continue;
if (g_ePointsData[i][e_iPts] > g_ePointsData[id][e_iPts])
iTop++;
}
g_ePointsData[id][e_iTop] = iTop;
}
}

Local_SetPts(TeamName:team_winners) {
new iMode = ObcMode();
new iPlayers[MAX_PLAYERS], iNum;
get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "TERRORIST" : "CT");

for (new i; i < iNum; i++) {
if (!IsPtsPlayer(iPlayers[i]))
continue;
ApplyObc(iPlayers[i], true, iMode);
Local_Save(iPlayers[i]);
}

get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "CT" : "TERRORIST");

for (new i; i < iNum; i++) {
if (!IsPtsPlayer(iPlayers[i]))
continue;
ApplyObc(iPlayers[i], false, iMode);
Local_Save(iPlayers[i]);
}

Local_RefreshTop();

for (new id = 1; id <= MaxClients; id++) {
if (!is_user_connected(id))
continue;
if (get_member(id, m_iTeam) == TEAM_SPECTATOR)
continue;
PushPts(id);
}
}

bool:IsPtsPlayer(id) {
if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
return false;
new TeamName:iTeam = rg_get_user_team(id);
return (iTeam == TEAM_TERRORIST || iTeam == TEAM_CT);
}

stock get_num_players_in_match() {
new iPlayers[MAX_PLAYERS], iNum;
get_players(iPlayers, iNum, "ch");
new numGameplr;
for (new i; i < iNum; i++) {
if (IsPtsPlayer(iPlayers[i]))
numGameplr++;
}
return numGameplr;
}

stock ObcRate(iWins, iLoss, szOut[], iLen) {
new iGames = iWins + iLoss;
if (iGames < 1) {
copy(szOut, iLen, "--");
return;
}
formatex(szOut, iLen, "%d%%", (iWins * 100) / iGames);
}

stock ObcMode() {
if (hnsmatch_maps_is_boost())
return 1;
if (hnsmatch_maps_is_skill())
return 2;
return 0;
}

stock ApplyMatchMemory(TeamName:team_winners) {
new iMode = ObcMode();
new iPlayers[MAX_PLAYERS], iNum;
get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "TERRORIST" : "CT");
for (new i; i < iNum; i++) {
if (IsPtsPlayer(iPlayers[i]))
ApplyObc(iPlayers[i], true, iMode);
}
get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "CT" : "TERRORIST");
for (new i; i < iNum; i++) {
if (IsPtsPlayer(iPlayers[i]))
ApplyObc(iPlayers[i], false, iMode);
}
Local_RefreshTop();
for (new id = 1; id <= MaxClients; id++) {
if (!is_user_connected(id) || get_member(id, m_iTeam) == TEAM_SPECTATOR)
continue;
PushPts(id);
}
}

stock ApplyObc(id, bool:bWin, iMode) {
new iDelta = (bWin ? OBC_WIN : -OBC_LOSS) + g_iKnifeBonus[id];
if (bWin)
g_ePointsData[id][e_iWins]++;
else
g_ePointsData[id][e_iLoss]++;
g_ePointsData[id][e_iPts] += iDelta;
if (g_ePointsData[id][e_iPts] < 0)
g_ePointsData[id][e_iPts] = 0;

if (iMode == 1) {
if (bWin)
g_ePointsData[id][e_iBoostWins]++;
else
g_ePointsData[id][e_iBoostLoss]++;
g_ePointsData[id][e_iBoostPts] += iDelta;
if (g_ePointsData[id][e_iBoostPts] < 0)
g_ePointsData[id][e_iBoostPts] = 0;
} else if (iMode == 2) {
if (bWin)
g_ePointsData[id][e_iSkillWins]++;
else
g_ePointsData[id][e_iSkillLoss]++;
g_ePointsData[id][e_iSkillPts] += iDelta;
if (g_ePointsData[id][e_iSkillPts] < 0)
g_ePointsData[id][e_iSkillPts] = 0;
}
return iDelta;
}

stock SavePlayerSql(id, bool:bWin, iDelta, iMode) {
new szAuth[MAX_AUTHID_LENGTH];
get_user_authid(id, szAuth, charsmax(szAuth));
if (!szAuth[0] || containi(szAuth, "PENDING") != -1)
return;

new iWin = bWin ? 1 : 0;
new iLoss = bWin ? 0 : 1;
new iBoostWin, iBoostLoss, iBoostDelta, iSkillWin, iSkillLoss, iSkillDelta;
if (iMode == 1) {
iBoostWin = iWin;
iBoostLoss = iLoss;
iBoostDelta = iDelta;
} else if (iMode == 2) {
iSkillWin = iWin;
iSkillLoss = iLoss;
iSkillDelta = iDelta;
}

new szQuery[512];
formatex(szQuery, charsmax(szQuery), SQL_SET_OBC, g_szTablePts, iWin, iLoss, iDelta, iBoostWin, iBoostLoss, iBoostDelta, iSkillWin, iSkillLoss, iSkillDelta, g_sTablePlayers, szAuth);

new cData[1];
cData[0] = SQL_OBC_SAVE;
g_iSavePending++;
SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof cData);
}

stock RefreshAllTops() {
for (new id = 1; id <= MaxClients; id++) {
if (!is_user_connected(id))
continue;
if (get_member(id, m_iTeam) == TEAM_SPECTATOR)
continue;
SQL_Top(id);
}
}

stock PushPts(id) {
if (!is_user_connected(id))
return;
ExecuteForward(g_hFwdPlayerInit, _, id, g_ePointsData[id][e_iPts], g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], g_ePointsData[id][e_iTop]);
ExecuteForward(g_hFwdObc, _, id, g_ePointsData[id][e_iBoostPts], g_ePointsData[id][e_iBoostWins], g_ePointsData[id][e_iBoostLoss], g_ePointsData[id][e_iSkillPts], g_ePointsData[id][e_iSkillWins], g_ePointsData[id][e_iSkillLoss]);
}

stock ReadModeColumn(Handle:hQuery, const szPts[], const szWins[], const szLoss[], &iPts, &iWins, &iLoss) {
new iField = SQL_FieldNameToNum(hQuery, szPts);
if (iField < 0) {
iPts = OBC_BASE;
iWins = 0;
iLoss = 0;
return;
}
iPts = SQL_ReadResult(hQuery, iField);
iWins = SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, szWins));
iLoss = SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, szLoss));
}

stock bool:Local_Unpack(id, const szData[]) {
new szA[16], szB[16], szC[16], szD[16], szE[16], szF[16], szG[16], szH[16], szI[16], szJ[16];
parse(szData, szA, charsmax(szA), szB, charsmax(szB), szC, charsmax(szC), szD, charsmax(szD), szE, charsmax(szE), szF, charsmax(szF), szG, charsmax(szG), szH, charsmax(szH), szI, charsmax(szI), szJ, charsmax(szJ));
if (equal(szA, "v2")) {
g_ePointsData[id][e_iPts] = str_to_num(szB);
g_ePointsData[id][e_iWins] = str_to_num(szC);
g_ePointsData[id][e_iLoss] = str_to_num(szD);
g_ePointsData[id][e_iBoostPts] = str_to_num(szE);
g_ePointsData[id][e_iBoostWins] = str_to_num(szF);
g_ePointsData[id][e_iBoostLoss] = str_to_num(szG);
g_ePointsData[id][e_iSkillPts] = str_to_num(szH);
g_ePointsData[id][e_iSkillWins] = str_to_num(szI);
g_ePointsData[id][e_iSkillLoss] = str_to_num(szJ);
return false;
}

new iWins = str_to_num(szB);
new iLoss = str_to_num(szC);
new iPts = OBC_BASE + iWins * OBC_WIN - iLoss * OBC_LOSS;
if (iPts < 0)
iPts = 0;
g_ePointsData[id][e_iPts] = iPts;
g_ePointsData[id][e_iWins] = iWins;
g_ePointsData[id][e_iLoss] = iLoss;
g_ePointsData[id][e_iBoostPts] = OBC_BASE;
g_ePointsData[id][e_iSkillPts] = OBC_BASE;
return true;
}

stock SchemaNext() {
new szQuery[512];
new iStep = g_iSchemaStep++;
switch (iStep) {
case 0: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `boost_wins` INT NOT NULL DEFAULT 0", g_szTablePts);
case 1: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `boost_loss` INT NOT NULL DEFAULT 0", g_szTablePts);
case 2: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `boost_pts` INT NOT NULL DEFAULT 50", g_szTablePts);
case 3: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `skill_wins` INT NOT NULL DEFAULT 0", g_szTablePts);
case 4: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `skill_loss` INT NOT NULL DEFAULT 0", g_szTablePts);
case 5: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `skill_pts` INT NOT NULL DEFAULT 50", g_szTablePts);
case 6: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ADD COLUMN `obc_ready` TINYINT NOT NULL DEFAULT 0", g_szTablePts);
case 7: formatex(szQuery, charsmax(szQuery), "ALTER TABLE `%s` ALTER COLUMN `pts` SET DEFAULT 50", g_szTablePts);
case 8: formatex(szQuery, charsmax(szQuery), "UPDATE `%s` SET `pts`=GREATEST(%d + `wins`*%d - `loss`*%d, 0), `obc_ready`=1 WHERE `obc_ready`=0", g_szTablePts, OBC_BASE, OBC_WIN, OBC_LOSS);
default: {
SchemaReady();
return;
}
}

new cData[1];
cData[0] = SQL_SCHEMA;
SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof cData);
}

stock SchemaReady() {
g_bSchemaReady = true;
for (new id = 1; id <= MaxClients; id++) {
if (is_user_connected(id))
SQL_Select(id);
}
}

stock BuildKnifeBonus() {
arrayset(g_iKnifeBonus, 0, sizeof g_iKnifeBonus);

new iIds[MAX_PLAYERS], iKills[MAX_PLAYERS], iCount;
for (new id = 1; id <= MaxClients; id++) {
if (!IsPtsPlayer(id) || g_iKnifeKills[id] < 1)
continue;
iIds[iCount] = id;
iKills[iCount] = g_iKnifeKills[id];
iCount++;
}

for (new i = 0; i < iCount; i++) {
for (new j = i + 1; j < iCount; j++) {
if (iKills[j] > iKills[i]) {
new iTmp = iKills[i];
iKills[i] = iKills[j];
iKills[j] = iTmp;
iTmp = iIds[i];
iIds[i] = iIds[j];
iIds[j] = iTmp;
}
}
}

new iRank = 1;
new iPos = 0;
while (iPos < iCount && iRank <= 3) {
new iBonus = 4 - iRank;
new iEnd = iPos;
while (iEnd < iCount && iKills[iEnd] == iKills[iPos])
iEnd++;
for (new k = iPos; k < iEnd; k++)
g_iKnifeBonus[iIds[k]] = iBonus;
iRank += (iEnd - iPos);
iPos = iEnd;
}
}

stock AnnounceMode() {
new iMode = ObcMode();
if (iMode == 1)
client_print_color(0, print_team_default, "%L", LANG_PLAYER, "OBS_MODE_BOOST", g_sPrefix);
else if (iMode == 2)
client_print_color(0, print_team_default, "%L", LANG_PLAYER, "OBS_MODE_SKILL", g_sPrefix);
else
client_print_color(0, print_team_default, "%L", LANG_PLAYER, "OBS_MODE_ALL", g_sPrefix);
}

stock AnnounceKnife() {
for (new id = 1; id <= MaxClients; id++) {
if (g_iKnifeBonus[id] < 1 || !is_user_connected(id))
continue;
new szName[32], szKey[16];
get_user_name(id, szName, charsmax(szName));
if (g_iKnifeBonus[id] >= 3)
copy(szKey, charsmax(szKey), "OBS_KNIFE_1");
else if (g_iKnifeBonus[id] == 2)
copy(szKey, charsmax(szKey), "OBS_KNIFE_2");
else
copy(szKey, charsmax(szKey), "OBS_KNIFE_3");
client_print_color(0, print_team_default, "%L", LANG_PLAYER, szKey, g_sPrefix, szName, g_iKnifeBonus[id]);
}
}

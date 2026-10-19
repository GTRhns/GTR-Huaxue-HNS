#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <PersistentDataStorage>
#include <hns_matchsystem>

#include <gtr-match/gtr_match_defs.inl>
#include <gtr-match/gtr_match_host.inl>

/*
 * GtrMatchMix ? GTR ?? mix ????
 *
 * ??:
 *   - ???/?/????
 *   - AI ???? API (hns_external_* / hns_begin_external_match)
 *   - ??????
 *
 * ??? (?? HnsMatchSystem ???):
 *   - ?? / HUD / cmds.inc / hnsmenu.inc
 *   - training.cfg / ChangeGameplay / ??????
 */

new bool:g_bLive;
new bool:g_bChangelevelReady = true;
new g_iMode = GTR_MODE_IDLE;
new g_iStatus = GTR_STATUS_NONE;
new g_iState = GTR_STATE_DISABLED;
new g_iRules = GTR_RULES_MR;

new g_iTeamSize;
new g_iTeamSizeTT;
new bool:g_bExternalTeamSize;

new g_szSponsorName[33];
new g_iSponsorGC;
new bool:g_bSponsorMatch;
new g_iSponsorPlayer;

new g_iFwdStarted;
new g_iFwdFinished;
new g_iFwdCanceled;

public plugin_natives() {
register_native("gtr_mix_available", "native_available");
register_native("gtr_mix_is_live", "native_is_live");
register_native("gtr_mix_changelevel_ready", "native_changelevel_ready");

register_native("hns_external_set_team_size", "native_external_set_team_size");
register_native("hns_external_set_match_mode", "native_external_set_match_mode");
register_native("hns_external_set_sponsor_name", "native_external_set_sponsor_name");
register_native("hns_external_set_sponsor_gc", "native_external_set_sponsor_gc");
register_native("hns_begin_external_match", "native_begin_external_match");
}

public plugin_init() {
register_plugin("GTR Match Mix", GTR_MIX_VERSION, "GTR");

g_iFwdStarted = CreateMultiForward("gtr_mix_started", ET_IGNORE);
g_iFwdFinished = CreateMultiForward("gtr_mix_finished", ET_IGNORE, FP_CELL);
g_iFwdCanceled = CreateMultiForward("gtr_mix_canceled", ET_IGNORE);

log_amx("[GtrMatchMix] %s loaded ? self-owned mix core (menus stay on HnsMatchSystem)", GTR_MIX_VERSION);
}

public plugin_cfg() {
g_bLive = false;
g_bChangelevelReady = true;
g_iMode = GTR_MODE_IDLE;
g_iStatus = GTR_STATUS_NONE;
g_iState = GTR_STATE_DISABLED;
}

public plugin_end() {
remove_task(TASK_GTR_SETTLE);
g_bLive = false;
g_bChangelevelReady = true;
}

public native_available(plugin, params) {
return true;
}

public native_is_live(plugin, params) {
return g_bLive;
}

public native_changelevel_ready(plugin, params) {
return g_bChangelevelReady;
}

public native_external_set_team_size(plugin, params) {
enum { argSize = 1, argSizeTT };
new iSize = get_param(argSize);
new iSizeTT = get_param(argSizeTT);

if (iSize < 0 || iSize > 32 || iSizeTT < 0 || iSizeTT > 32)
return 0;
if (iSize + iSizeTT < 1)
return 0;

g_iTeamSize = iSize + iSizeTT;
g_iTeamSizeTT = iSizeTT;
g_bExternalTeamSize = true;

gtr_host_call_2cell("GtrHost_SetExternalTeamSize", iSize, iSizeTT);
return 1;
}

public native_external_set_match_mode(plugin, params) {
enum { iMode = 1 };
new iMode = get_param(iMode);
if (iMode < GTR_RULES_MR || iMode > GTR_RULES_ROUNDS)
return 0;

g_iRules = iMode;
PDS_SetCell("match_rules", iMode);
PDS_SetCell("ai_match_rules", iMode);
gtr_host_call_cell("GtrHost_SetMatchRules", iMode);
return 1;
}

public native_external_set_sponsor_name(plugin, params) {
enum { argName = 1 };
new szName[33];
get_string(argName, szName, charsmax(szName));
trim(szName);
replace_all(szName, charsmax(szName), "%", "");
copy(g_szSponsorName, charsmax(g_szSponsorName), szName);
gtr_host_call_str("GtrHost_SetSponsorName", szName);
return 1;
}

public native_external_set_sponsor_gc(plugin, params) {
enum { argGC = 1 };
new iGC = get_param(argGC);
if (iGC < 5) iGC = 5;
if (iGC > 20) iGC = 20;
iGC = (iGC / 5) * 5;
if (iGC < 5) iGC = 5;
g_iSponsorGC = iGC;
gtr_host_call_cell("GtrHost_SetSponsorGC", iGC);
return 1;
}

public native_begin_external_match(plugin, params) {
enum { argbSponsor = 1, argiStarter };
new bool:bSponsor = bool:get_param(argbSponsor);
new iStarter = get_param(argiStarter);

g_bSponsorMatch = bSponsor;
g_iSponsorPlayer = iStarter;

new iAiRules;
if (PDS_GetCell("ai_match_rules", iAiRules) && iAiRules >= GTR_RULES_MR && iAiRules <= GTR_RULES_ROUNDS) {
g_iRules = iAiRules;
gtr_host_call_cell("GtrHost_SetMatchRules", iAiRules);
}

gtr_host_call_2cell("GtrHost_PrepareExternalMatch", _:bSponsor, iStarter);
return gtr_mix_start_internal(true);
}

public GtrMix_RequestStart() {
return gtr_mix_start_internal(false);
}

public GtrMix_RequestStop() {
return gtr_mix_stop_internal(true);
}

public GtrMix_RequestPause() {
if (!g_bLive)
return 0;
g_iState = GTR_STATE_PAUSED;
gtr_host_call("GtrHost_ApplyMixPause");
return 1;
}

public GtrMix_RequestUnpause() {
if (!g_bLive || g_iState != GTR_STATE_PAUSED)
return 0;
g_iState = GTR_STATE_PREPARE;
gtr_host_call("GtrHost_ApplyMixUnpause");
return 1;
}

public GtrMix_OnStart() {
return gtr_mix_mark_live();
}

public GtrMix_OnStop() {
return gtr_mix_mark_stopped();
}

public GtrMix_ShouldDelayChangelevel() {
if (g_bLive)
return 1;
if (!g_bChangelevelReady)
return 1;
return 0;
}

stock gtr_mix_start_internal(bool:bFromAi) {
#pragma unused bFromAi

if (g_bLive) {
log_amx("[GtrMatchMix] start ignored ? already live");
return 0;
}

if (gtr_host_plugin() == -1) {
log_amx("[GtrMatchMix] FATAL: HnsMatchSystem host missing");
return 0;
}

remove_task(TASK_GTR_SETTLE);
g_bChangelevelReady = false;

if (!gtr_host_call("GtrHost_ApplyMixStart")) {
log_amx("[GtrMatchMix] host ApplyMixStart failed");
g_bChangelevelReady = true;
return 0;
}

gtr_mix_mark_live();

if (g_iFwdStarted)
ExecuteForward(g_iFwdStarted, _);

log_amx("[GtrMatchMix] match started rules=%d", g_iRules);
return 1;
}

stock gtr_mix_stop_internal(bool:bApplyHost) {
if (bApplyHost) {
if (!gtr_host_call("GtrHost_ApplyMixStop")) {
log_amx("[GtrMatchMix] host ApplyMixStop failed");
}
}

gtr_mix_mark_stopped();

if (g_iFwdCanceled)
ExecuteForward(g_iFwdCanceled, _);

log_amx("[GtrMatchMix] match stopped ? settle 5.0s");
return 1;
}

stock gtr_mix_mark_live() {
remove_task(TASK_GTR_SETTLE);
g_bLive = true;
g_bChangelevelReady = false;
g_iMode = GTR_MODE_MIX;
g_iStatus = GTR_STATUS_STARTED;
g_iState = GTR_STATE_PREPARE;
return 1;
}

stock gtr_mix_mark_stopped() {
g_bLive = false;
g_bChangelevelReady = false;
g_iMode = GTR_MODE_IDLE;
g_iStatus = GTR_STATUS_NONE;
g_iState = GTR_STATE_DISABLED;

remove_task(TASK_GTR_SETTLE);
set_task(5.0, "taskSettleReady", TASK_GTR_SETTLE);
return 1;
}

public taskSettleReady() {
if (g_bLive)
return;

g_bChangelevelReady = true;
log_amx("[GtrMatchMix] settle done ? changelevel ready");
}


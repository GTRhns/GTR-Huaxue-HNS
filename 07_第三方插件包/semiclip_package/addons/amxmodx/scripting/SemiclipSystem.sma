/* ============================================================================
 *  SemiclipSystem v1.0.0
 *  ---------------------------------------------------------------------------
 *  独立 "半透明穿人 / 穿透" 插件 (由 HNSRU 内嵌 Semiclip 逻辑剥离而成)。
 *
 *  功能
 *  - 同队 / 全员半透明穿人: 每帧把其它可穿透玩家的实体短暂置为 SOLID_NOT,
 *    帧末 (PostThink) 恢复 SOLID_SLIDEBOX, 不破坏物理数值。
 *  - 通过实体包 (FM_AddToFullPack) 只对"接收者"隐藏同人碰撞。
 *  - 三个控制面: 控制台命令 / 独立 natives (semiclip_system.inc) / cvar。
 *  - 兼容旧 HNSRU 的 server_cmd("semiclip_option ...") 调用 (drop-in)。
 *
 *  接口 (详见 include/semiclip_system.inc)
 *    native semclip_set_mode(iMode)
 *    native SEMICLIP_MODE:semclip_get_mode()
 *
 *  模式
 *    SEMICLIP_OFF  = 0  关闭
 *    SEMICLIP_SAME = 1  仅同队可穿透 (半透明队友)
 *    SEMICLIP_ALL  = 2  全员可穿透
 * ========================================================================== */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <semiclip_system>

#define SEMICLIP_PREFIX  "^x04[Semclip]^x01"
#define TASK_AUTOOFF 85431

new g_iMode;                 // 当前生效模式 SEMICLIP_MODE
new g_iMaxPlayers;

new g_pcvarEnabled;          // semiclip_enabled 0/1
new g_pcvarTeam;             // semiclip_team    0=同队 3=全员
new g_pcvarTime;             // semiclip_time    自动恢复秒数

public plugin_init()
{
    register_plugin("SemiclipSystem", "1.0.0", "hnsru");
    register_dictionary("SemiclipSystem.txt");

    g_iMaxPlayers = get_maxplayers();

    g_pcvarEnabled = register_cvar("semiclip_enabled", "0");
    g_pcvarTeam    = register_cvar("semiclip_team",    "0");
    g_pcvarTime    = register_cvar("semiclip_time",    "0");

    /* 兼容旧 HNSRU: server_cmd("semiclip_option semiclip/team/time ...") */
    register_srvcmd("semiclip_option", "CmdSemiclipOption");

    /* 管理员聊天命令 */
    register_clcmd("say /semiclip",     "CmdToggleClient", ADMIN_CFG, "- toggle pass-through mode");
    register_clcmd("say .semiclip",     "CmdToggleClient", ADMIN_CFG, "- toggle pass-through mode");
    register_clcmd("say_team /semiclip","CmdToggleClient", ADMIN_CFG, "- toggle pass-through mode");
    register_clcmd("say_team .semiclip","CmdToggleClient", ADMIN_CFG, "- toggle pass-through mode");

    /* 服务器/管理员控制台命令: semclip_system_set <0|1|2> */
    register_srvcmd("semclip_system_set", "CmdSystemSet", ADMIN_CFG, "- <0|1|2> set pass-through mode");

    register_forward(FM_AddToFullPack, "FwdAddToFullPack");
    register_forward(FM_ShouldCollide, "FwdShouldCollide");
}

public plugin_natives()
{
    register_library("semiclip_system");
    register_native("semclip_set_mode", "SemclipSetModeNative");
    register_native("semclip_get_mode", "SemclipGetModeNative");
}

/* ============================ natives ============================ */

public SemclipGetModeNative(plugin, params)
    return g_iMode;

public SemclipSetModeNative(plugin, params)
{
    SetMode(get_param(1));
    return 1;
}

/* 供其它插件经 callfunc 调用的公有入口 (与接口 stock semclip_apply 配套) */
public SemiClipSetModeForward(iMode)
{
    SetMode(iMode);
    return 1;
}

/* ============================ 模式控制 ============================ */

SetMode(iMode)
{
    if (iMode < _:SEMICLIP_OFF || iMode > _:SEMICLIP_ALL)
        return;

    g_iMode = iMode;

    /* 同步到 cvar, 使服务端状态一致 */
    set_pcvar_num(g_pcvarEnabled, iMode ? 1 : 0);
    set_pcvar_num(g_pcvarTeam,    iMode == _:SEMICLIP_ALL ? 3 : 0);

    /* 自动恢复 (semiclip_time) */
    if (task_exists(TASK_AUTOOFF))
        remove_task(TASK_AUTOOFF);
    new Float:fTime = get_pcvar_float(g_pcvarTime);
    if (iMode && fTime > 0.0)
        set_task(fTime, "TaskAutoOff", TASK_AUTOOFF);
}

public TaskAutoOff()
    SetMode(_:SEMICLIP_OFF);

/* 从 cvar 读取并同步 mode (semiclip_option 兼容命令会先落盘到 cvar) */
SyncFromCvars()
{
    new iEnabled = get_pcvar_num(g_pcvarEnabled);
    new iTeam    = get_pcvar_num(g_pcvarTeam);
    new iMode = 0;

    if (iEnabled)
        iMode = (iTeam >= 3) ? 2 : 1;

    SetMode(iMode);
}

/* ============================ 命令 ============================ */

public CmdToggleClient(id)
{
    if (!(get_user_flags(id) & ADMIN_CFG))
    {
        client_print_color(id, print_team_blue, "%s %L", SEMICLIP_PREFIX, id, "SEMICLIP_MSG_ACCESS");
        return PLUGIN_HANDLED;
    }

    new iMode = (g_iMode + 1) % (SEMICLIP_ALL + 1);   // 关->同队->全员->关
    SetMode(iMode);

    new szMode[16];
    FormatModeName(iMode, id, szMode, charsmax(szMode));
    client_print_color(id, print_team_blue, "%s %L", SEMICLIP_PREFIX, id, "SEMICLIP_MSG_MODE", szMode);
    return PLUGIN_HANDLED;
}

public CmdSystemSet()
{
    SetMode(read_argv_int(1));
    return PLUGIN_HANDLED;
}

public CmdSemiclipOption()
{
    /* 兼容旧接口: semclip_option <semiclip|team|time> <value> */
    new szKey[16], szVal[16];
    read_argv(1, szKey, charsmax(szKey));
    read_argv(2, szVal, charsmax(szVal));

    if (equal(szKey, "semiclip"))
        set_pcvar_num(g_pcvarEnabled, str_to_num(szVal) ? 1 : 0);
    else if (equal(szKey, "team"))
        set_pcvar_num(g_pcvarTeam, str_to_num(szVal));
    else if (equal(szKey, "time"))
        set_pcvar_float(g_pcvarTime, floatstr(szVal));

    SyncFromCvars();
    return PLUGIN_HANDLED;
}

FormatModeName(iMode, id, szOut[], iLen)
{
    switch (iMode)
    {
        case SEMICLIP_OFF:  format(szOut, iLen, "%L", id, "SEMICLIP_MSG_OFF");
        case SEMICLIP_SAME: format(szOut, iLen, "%L", id, "SEMICLIP_MSG_SAME");
        case SEMICLIP_ALL:  format(szOut, iLen, "%L", id, "SEMICLIP_MSG_ALL");
        default:            formatex(szOut, iLen, "%d", iMode);
    }
}

/* ============================ 穿透核心 ============================ */

/* 只对"接收者"隐藏需要穿透的玩家碰撞 */
public FwdAddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
    if (!g_iMode || !player)
        return FMRES_IGNORED;

    if (!is_user_alive(host) || !is_user_alive(ent))
        return FMRES_IGNORED;

    if (g_iMode == _:SEMICLIP_SAME && get_user_team(host) != get_user_team(ent))
        return FMRES_IGNORED;

    set_es(es, ES_Solid, SOLID_NOT);
    return FMRES_IGNORED;
}

public FwdShouldCollide(ent1, ent2)
{
    if (!g_iMode)
        return FMRES_IGNORED;

    if (ent1 < 1 || ent1 > g_iMaxPlayers || ent2 < 1 || ent2 > g_iMaxPlayers)
        return FMRES_IGNORED;

    if (!is_user_alive(ent1) || !is_user_alive(ent2))
        return FMRES_IGNORED;

    if (ent1 == ent2)
        return FMRES_IGNORED;

    if (g_iMode == _:SEMICLIP_SAME && get_user_team(ent1) != get_user_team(ent2))
        return FMRES_IGNORED;

    forward_return(FMV_CELL, 0);
    return FMRES_SUPERCEDE;
}
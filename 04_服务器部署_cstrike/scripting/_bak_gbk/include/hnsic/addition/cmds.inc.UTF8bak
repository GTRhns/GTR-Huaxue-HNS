#if defined _hnsic_cmds_included
    #endinput
#endif
#define _hnsic_cmds_included

/* ============================================================
 *  HNSIC v3.10.0 - cmds.inc
 *  All chat commands registration
 * ============================================================ */

// ─── Command Registration ───────────────────────────────────
stock Cmds_Register()
{
    // ── Admin Commands ──
    register_clcmd("say /aigroup",    "Cmd_AiGroup");      // AI分组
    register_clcmd("say_team /aigroup", "Cmd_AiGroup");
    register_clcmd("say /startmatch", "Cmd_StartMatch");    // 开始比赛
    register_clcmd("say_team /startmatch", "Cmd_StartMatch");
    register_clcmd("say /stopmatch",  "Cmd_StopMatch");     // 停止比赛
    register_clcmd("say_team /stopmatch", "Cmd_StopMatch");
    register_clcmd("say /forcemode",  "Cmd_ForceMode");     // 强制切换模式
    register_clcmd("say_team /forcemode", "Cmd_ForceMode");
    register_clcmd("say /pause",       "Cmd_Pause");        // 暂停
    register_clcmd("say_team /pause",  "Cmd_Pause");
    register_clcmd("say /unpause",     "Cmd_Unpause");      // 取消暂停
    register_clcmd("say_team /unpause", "Cmd_Unpause");

    // ── Player Commands ──
    register_clcmd("say /menu",        "Cmd_Menu");         // N键菜单
    register_clcmd("say_team /menu",   "Cmd_Menu");
    register_clcmd("say /back",        "Cmd_Back");         // 返回游戏
    register_clcmd("say_team /back",   "Cmd_Back");
    register_clcmd("say /score",       "Cmd_Score");        // 查看比分
    register_clcmd("say_team /score",  "Cmd_Score");
    register_clcmd("say /pts",         "Cmd_Pts");          // 查看积分
    register_clcmd("say_team /pts",    "Cmd_Pts");
    register_clcmd("say /surrender",   "Cmd_Surrender");    // 投降
    register_clcmd("say_team /surrender", "Cmd_Surrender");
    register_clcmd("say /votemap",     "Cmd_VoteMap");      // 投票地图
    register_clcmd("say_team /votemap", "Cmd_VoteMap");

    // ── Captain Commands ──
    register_clcmd("say /pick",        "Cmd_Pick");         // 选人
    register_clcmd("say_team /pick",   "Cmd_Pick");
    register_clcmd("say /pickside",    "Cmd_PickSide");     // 选择阵营
    register_clcmd("say_team /pickside", "Cmd_PickSide");
    register_clcmd("say /pickmap",    "Cmd_PickMap");      // 选择地图类型
    register_clcmd("say_team /pickmap", "Cmd_PickMap");

    // ── Info Commands ──
    register_clcmd("say /help",        "Cmd_Help");         // 帮助
    register_clcmd("say_team /help",   "Cmd_Help");
    register_clcmd("say /rank",        "Cmd_Rank");         // 排名
    register_clcmd("say_team /rank",   "Cmd_Rank");
    register_clcmd("say /top",         "Cmd_Top");          // 排行榜
    register_clcmd("say_team /top",    "Cmd_Top");
    register_clcmd("say /stats",       "Cmd_Stats");        // 个人统计
    register_clcmd("say_team /stats",  "Cmd_Stats");

    // ── Console Commands ──
    register_srvcmd("hnsic_setmode",   "SrvCmd_SetMode");
    register_srvcmd("hnsic_setgameplay", "SrvCmd_SetGameplay");
    register_srvcmd("hnsic_reload",    "SrvCmd_Reload");
}

// ─── Admin Command Handlers ─────────────────────────────────

// AI分组
public Cmd_AiGroup(id)
{
    if (!Hnsic_IsAdmin(id))
    {
        Hnsic_PrintChat(id, "你没有权限执行此命令");
        return PLUGIN_HANDLED;
    }

    if (g_iCurrentMode != MODE_MIX)
    {
        Hnsic_PrintChat(id, "AI分组仅在比赛模式下可用");
        return PLUGIN_HANDLED;
    }

    Captain_StartAiGrouping();
    return PLUGIN_HANDLED;
}

// 开始比赛
public Cmd_StartMatch(id)
{
    if (!Hnsic_IsAdmin(id))
    {
        Hnsic_PrintChat(id, "你没有权限执行此命令");
        return PLUGIN_HANDLED;
    }

    if (g_iMatchState != STATE_IDLE)
    {
        Hnsic_PrintChat(id, "比赛已经在进行中");
        return PLUGIN_HANDLED;
    }

    // Switch to Mix mode if not already
    if (g_iCurrentMode != MODE_MIX)
    {
        set_pcvar_num(g_pCvar[CVAR_MODE], MODE_MIX);
    }

    Captain_StartAiGrouping();
    return PLUGIN_HANDLED;
}

// 停止比赛
public Cmd_StopMatch(id)
{
    if (!Hnsic_IsAdmin(id))
    {
        Hnsic_PrintChat(id, "你没有权限执行此命令");
        return PLUGIN_HANDLED;
    }

    if (g_iMatchState == STATE_IDLE)
    {
        Hnsic_PrintChat(id, "当前没有进行中的比赛");
        return PLUGIN_HANDLED;
    }

    Mix_EndMatch(TEAM_NONE);
    return PLUGIN_HANDLED;
}

// 强制切换模式
public Cmd_ForceMode(id)
{
    if (!Hnsic_IsAdmin(id))
    {
        Hnsic_PrintChat(id, "你没有权限执行此命令");
        return PLUGIN_HANDLED;
    }

    new arg[32];
    read_argv(1, arg, charsmax(arg));

    new mode = str_to_num(arg);
    if (mode < MODE_PUB || mode > MODE_MIX)
    {
        Hnsic_PrintChat(id, "无效模式编号 (1-6)");
        Hnsic_PrintChat(id, "1=公共 2=训练 3=刀战 4=混战 5=僵尸 6=比赛");
        return PLUGIN_HANDLED;
    }

    set_pcvar_num(g_pCvar[CVAR_MODE], mode);
    return PLUGIN_HANDLED;
}

// 暂停
public Cmd_Pause(id)
{
    if (g_iCurrentMode != MODE_MIX)
    {
        Hnsic_PrintChat(id, "暂停仅在比赛模式下可用");
        return PLUGIN_HANDLED;
    }

    if (g_iMatchState < STATE_FIRST_HALF || g_iMatchState > STATE_SECOND_HALF)
    {
        Hnsic_PrintChat(id, "当前阶段无法暂停");
        return PLUGIN_HANDLED;
    }

    if (g_bMatchPaused)
    {
        Hnsic_PrintChat(id, "比赛已经处于暂停状态");
        return PLUGIN_HANDLED;
    }

    Mix_RequestPause(id);
    return PLUGIN_HANDLED;
}

// 取消暂停
public Cmd_Unpause(id)
{
    if (!g_bMatchPaused)
    {
        Hnsic_PrintChat(id, "比赛未处于暂停状态");
        return PLUGIN_HANDLED;
    }

    Mix_ResumeFromPause();
    return PLUGIN_HANDLED;
}

// ─── Player Command Handlers ─────────────────────────────────

// N键菜单
public Cmd_Menu(id)
{
    HnsMenu_ShowMain(id);
    return PLUGIN_HANDLED;
}

// 返回游戏
public Cmd_Back(id)
{
    if (!Hnsic_IsPlayerValid(id))
        return PLUGIN_HANDLED;

    new team = get_member(id, m_iTeam);
    if (team == TEAM_SPEC)
    {
        // Auto-assign to team with fewer players
        new tt_count = Hnsic_GetTeamCount(TEAM_TT);
        new ct_count = Hnsic_GetTeamCount(TEAM_CT);

        if (tt_count <= ct_count)
            Hnsic_SwitchTeam(id, TEAM_TT);
        else
            Hnsic_SwitchTeam(id, TEAM_CT);

        Hnsic_PrintChat(id, "你已返回游戏");
    }
    return PLUGIN_HANDLED;
}

// 查看比分
public Cmd_Score(id)
{
    if (g_iCurrentMode == MODE_MIX)
    {
        new szMsg[128];
        formatex(szMsg, charsmax(szMsg), "当前比分: TT %d - %d CT | %s 第%d回合",
            g_iMatchScore[TEAM_TT], g_iMatchScore[TEAM_CT],
            (g_iCurrentHalf == 0) ? "上半场" : "下半场", g_iRoundNum);
        Hnsic_PrintChat(id, szMsg);
    }
    else
    {
        Hnsic_PrintChat(id, "当前非比赛模式, 无比分信息");
    }
    return PLUGIN_HANDLED;
}

// 查看积分
public Cmd_Pts(id)
{
    if (!Hnsic_IsPlayerValid(id))
        return PLUGIN_HANDLED;

    new szMsg[128];
    formatex(szMsg, charsmax(szMsg), "你的积分: %d PTS | 胜率: %.1f%% | 比赛: %d场",
        g_eUserData[id][UD_PTS],
        Hnsic_GetWinrate(id) * 100.0,
        g_eUserData[id][UD_MATCHES]);
    Hnsic_PrintChat(id, szMsg);
    return PLUGIN_HANDLED;
}

// 投降
public Cmd_Surrender(id)
{
    if (g_iCurrentMode != MODE_MIX)
    {
        Hnsic_PrintChat(id, "投降仅在比赛模式下可用");
        return PLUGIN_HANDLED;
    }

    if (g_iMatchState < STATE_FIRST_HALF || g_iMatchState > STATE_SECOND_HALF)
    {
        Hnsic_PrintChat(id, "当前阶段无法投降");
        return PLUGIN_HANDLED;
    }

    Surrender_StartVote(id);
    return PLUGIN_HANDLED;
}

// 投票地图
public Cmd_VoteMap(id)
{
    if (g_iCurrentMode != MODE_MIX || g_iMatchState != STATE_MAP_PICK)
    {
        Hnsic_PrintChat(id, "当前无法投票地图");
        return PLUGIN_HANDLED;
    }

    Captain_ShowMapPickMenu(id);
    return PLUGIN_HANDLED;
}

// ─── Captain Command Handlers ───────────────────────────────

// 选人
public Cmd_Pick(id)
{
    if (g_iMatchState != STATE_CAPTAIN_PICK)
    {
        Hnsic_PrintChat(id, "当前不是选人阶段");
        return PLUGIN_HANDLED;
    }

    if (!g_eUserData[id][UD_IS_CAPTAIN])
    {
        Hnsic_PrintChat(id, "只有队长可以选人");
        return PLUGIN_HANDLED;
    }

    Captain_ShowPickMenu(id);
    return PLUGIN_HANDLED;
}

// 选择阵营
public Cmd_PickSide(id)
{
    if (g_iMatchState != STATE_SIDE_PICK)
    {
        Hnsic_PrintChat(id, "当前不是选边阶段");
        return PLUGIN_HANDLED;
    }

    if (id != g_iCaptainDuelWinner)
    {
        Hnsic_PrintChat(id, "只有刀战胜者可以选边");
        return PLUGIN_HANDLED;
    }

    Captain_ShowSidePickMenu(id);
    return PLUGIN_HANDLED;
}

// 选择地图类型
public Cmd_PickMap(id)
{
    if (g_iMatchState != STATE_MAP_PICK)
    {
        Hnsic_PrintChat(id, "当前不是选图阶段");
        return PLUGIN_HANDLED;
    }

    if (id != g_iCaptainDuelWinner)
    {
        Hnsic_PrintChat(id, "只有刀战胜者可以选图");
        return PLUGIN_HANDLED;
    }

    Captain_ShowMapPickMenu(id);
    return PLUGIN_HANDLED;
}

// ─── Info Command Handlers ──────────────────────────────────

// 帮助
public Cmd_Help(id)
{
    Hnsic_PrintChat(id, "=== HNSIC v3.10.0 帮助 ===");
    Hnsic_PrintChat(id, "/menu - 打开主菜单 (N键)");
    Hnsic_PrintChat(id, "/back - 返回游戏");
    Hnsic_PrintChat(id, "/score - 查看比分");
    Hnsic_PrintChat(id, "/pts - 查看积分");
    Hnsic_PrintChat(id, "/stats - 个人统计");
    Hnsic_PrintChat(id, "/top - 排行榜");
    Hnsic_PrintChat(id, "/surrender - 投降 (比赛模式)");
    return PLUGIN_HANDLED;
}

// 排名
public Cmd_Rank(id)
{
    if (!Hnsic_IsPlayerValid(id))
        return PLUGIN_HANDLED;

    new szMsg[128];
    formatex(szMsg, charsmax(szMsg), "你的排名: %d PTS | 胜: %d 负: %d | K/D: %d/%d",
        g_eUserData[id][UD_PTS],
        g_eUserData[id][UD_WINS],
        g_eUserData[id][UD_LOSSES],
        g_eUserData[id][UD_KILLS],
        g_eUserData[id][UD_DEATHS]);
    Hnsic_PrintChat(id, szMsg);
    return PLUGIN_HANDLED;
}

// 排行榜
public Cmd_Top(id)
{
    // Collect and sort players by PTS
    new players[MAX_PLAYERS];
    new pts[MAX_PLAYERS];
    new count = 0;

    for (new i = 1; i <= g_iMaxPlayers; i++)
    {
        if (Hnsic_IsPlayerValid(i) && g_eUserData[i][UD_IS_CONNECTED])
        {
            players[count] = i;
            pts[count] = g_eUserData[i][UD_PTS];
            count++;
        }
    }

    // Sort descending
    for (new i = 0; i < count - 1; i++)
    {
        for (new j = 0; j < count - i - 1; j++)
        {
            if (pts[j] < pts[j + 1])
            {
                new temp_p = players[j]; players[j] = players[j + 1]; players[j + 1] = temp_p;
                new temp_s = pts[j]; pts[j] = pts[j + 1]; pts[j + 1] = temp_s;
            }
        }
    }

    Hnsic_PrintChat(id, "=== 积分排行榜 TOP 10 ===");
    new show = min(count, 10);
    for (new i = 0; i < show; i++)
    {
        new szMsg[128];
        formatex(szMsg, charsmax(szMsg), "%d. %s - %d PTS",
            i + 1, g_eUserData[players[i]][UD_NAME], pts[i]);
        Hnsic_PrintChat(id, szMsg);
    }
    return PLUGIN_HANDLED;
}

// 个人统计
public Cmd_Stats(id)
{
    if (!Hnsic_IsPlayerValid(id))
        return PLUGIN_HANDLED;

    new Float:winrate = Hnsic_GetWinrate(id);
    new Float:kdr = 0.0;
    if (g_eUserData[id][UD_DEATHS] > 0)
        kdr = float(g_eUserData[id][UD_KILLS]) / float(g_eUserData[id][UD_DEATHS]);

    Hnsic_PrintChat(id, "=== 个人统计 ===");
    Hnsic_PrintChat(id, "积分: %d | 胜率: %.1f%%", g_eUserData[id][UD_PTS], winrate * 100.0);
    Hnsic_PrintChat(id, "胜/负/总: %d/%d/%d", g_eUserData[id][UD_WINS],
        g_eUserData[id][UD_LOSSES], g_eUserData[id][UD_MATCHES]);
    Hnsic_PrintChat(id, "击杀/死亡: %d/%d (K/D: %.2f)",
        g_eUserData[id][UD_KILLS], g_eUserData[id][UD_DEATHS], kdr);
    return PLUGIN_HANDLED;
}

// ─── Server Commands ──────────────────────────────────────────

public SrvCmd_SetMode()
{
    new arg[32];
    read_argv(1, arg, charsmax(arg));
    new mode = str_to_num(arg);
    if (mode >= MODE_NONE && mode <= MODE_MIX)
    {
        set_pcvar_num(g_pCvar[CVAR_MODE], mode);
        server_print("[HNSIC] 模式已切换为: %d", mode);
    }
}

public SrvCmd_SetGameplay()
{
    new arg[32];
    read_argv(1, arg, charsmax(arg));
    new gp = str_to_num(arg);
    if (gp >= GAMEPLAY_NONE && gp <= GAMEPLAY_TRAINING)
    {
        set_pcvar_num(g_pCvar[CVAR_GAMEPLAY], gp);
        server_print("[HNSIC] Gameplay已切换为: %d", gp);
    }
}

public SrvCmd_Reload()
{
    Cvars_Register();
    server_print("[HNSIC] CVAR已重新加载");
}

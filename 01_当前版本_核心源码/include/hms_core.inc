// Server lifecycle, cvars and public chat commands.
public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    pcvar_enabled = register_cvar("hms_enabled", "1");
    pcvar_sql_enabled = register_cvar("hms_sql_enabled", "1");
    pcvar_sql_timeout = register_cvar("hms_sql_timeout", "8");

    pcvar_hud_interval = register_cvar("hms_hud_interval", "0.10");
    pcvar_low_speed = register_cvar("hms_low_speed_threshold", "180.0");
    pcvar_low_drop = register_cvar("hms_low_speed_drop", "45.0");
    pcvar_enable_jumpstats = register_cvar("hms_enable_jumpstats", "0");
    pcvar_sound_takeoff = register_cvar("hms_sound_takeoff", "1");
    pcvar_sound_landing = register_cvar("hms_sound_landing", "1");
    pcvar_sound_achievement = register_cvar("hms_sound_achievement", "1");
    pcvar_sound_distance = register_cvar("hms_sound_distance", "250.0");
    pcvar_show_landing = register_cvar("hms_show_landing", "0");
    pcvar_bhop_fog_frames = register_cvar("hms_bhop_fog_frames", "6");
    pcvar_sql_save_jump_events = register_cvar("hms_sql_save_jump_events", "0");
    pcvar_chat_broadcast = register_cvar("hms_chat_broadcast", "0");

    register_clcmd("say /hms", "HmsCmdMainMenu");
    register_clcmd("say_team /hms", "HmsCmdMainMenu");
    register_clcmd("say /hmsmenu", "HmsCmdMainMenu");
    register_clcmd("say_team /hmsmenu", "HmsCmdMainMenu");
    register_clcmd("say /hmstoggle", "HmsCmdToggle");
    register_clcmd("say_team /hmstoggle", "HmsCmdToggle");
    register_clcmd("say /hmsstats", "HmsCmdStats");
    register_clcmd("say_team /hmsstats", "HmsCmdStats");
    register_clcmd("say /hmshud", "HmsCmdHudMenu");
    register_clcmd("say_team /hmshud", "HmsCmdHudMenu");
    register_clcmd("say /hmslayout", "HmsCmdLayoutMenu");
    register_clcmd("say_team /hmslayout", "HmsCmdLayoutMenu");
    register_clcmd("say /hmssound", "HmsCmdSoundMenu");
    register_clcmd("say_team /hmssound", "HmsCmdSoundMenu");
    register_clcmd("say /hmssoundtoggle", "HmsCmdSoundToggle");
    register_clcmd("say_team /hmssoundtoggle", "HmsCmdSoundToggle");
    register_clcmd("say /hmsstatus", "HmsCmdStatus");
    register_clcmd("say_team /hmsstatus", "HmsCmdStatus");
    register_clcmd("say /hmsadmin", "HmsCmdAdminMenu");
    register_clcmd("say_team /hmsadmin", "HmsCmdAdminMenu");
    register_clcmd("say /hmssql", "HmsCmdSqlMenu");
    register_clcmd("say_team /hmssql", "HmsCmdSqlMenu");
    register_clcmd("say /hmsreset", "HmsCmdResetSession");
    register_clcmd("say_team /hmsreset", "HmsCmdResetSession");
    register_clcmd("say /hmsresetprefs", "HmsCmdResetPreferencesConfirm");
    register_clcmd("say_team /hmsresetprefs", "HmsCmdResetPreferencesConfirm");
    register_clcmd("say /speed", "HmsCmdSpeed");
    register_clcmd("say_team /speed", "HmsCmdSpeed");
    register_clcmd("say /hmsspeed", "HmsCmdKzMenu");
    register_clcmd("say_team /hmsspeed", "HmsCmdKzMenu");
    register_clcmd("say /speedt", "HmsCmdSpeedType");
    register_clcmd("say_team /speedt", "HmsCmdSpeedType");
    register_clcmd("say /fog", "HmsCmdFog");
    register_clcmd("say_team /fog", "HmsCmdFog");
    register_clcmd("say /showpre", "HmsCmdShowPre");
    register_clcmd("say_team /showpre", "HmsCmdShowPre");
    register_clcmd("say /pre", "HmsCmdShowPre");
    register_clcmd("say_team /pre", "HmsCmdShowPre");

    register_forward(FM_PlayerPreThink, "Hms_PlayerPreThink");
    register_event("DeathMsg", "Hms_EventDeath", "a");
    register_event("ResetHUD", "Hms_EventSpawn", "be");

    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
        g_HudSync[panel] = CreateHudSyncObj();

    // One repeating global HUD task replaces a repeating task for every connected player.
    set_task(0.10, "Hms_TaskHud", HMS_TASK_HUD_GLOBAL, "", 0, "b");

    g_ForwardJump = CreateMultiForward("hms_on_jump", ET_IGNORE, FP_CELL, FP_FLOAT);
    g_ForwardLand = CreateMultiForward("hms_on_land", ET_IGNORE, FP_CELL, FP_FLOAT, FP_FLOAT, FP_FLOAT);
    g_ForwardLowSpeed = CreateMultiForward("hms_on_low_speed", ET_IGNORE, FP_CELL, FP_FLOAT, FP_FLOAT);

    AutoExecConfig(false, "hms", "");
}

// mixsystem/hnsmatch-sql.cfg is read only after normal AMXX/server configs have run.
public OnConfigsExecuted()
{
    if (!g_DatabaseInitDone)
    {
        Hms_DatabaseInit();
        g_DatabaseInitDone = true;
    }
}

public plugin_end()
{
    Hms_DatabaseClose();
    if (g_ForwardJump != -1) DestroyForward(g_ForwardJump);
    if (g_ForwardLand != -1) DestroyForward(g_ForwardLand);
    if (g_ForwardLowSpeed != -1) DestroyForward(g_ForwardLowSpeed);
}

public client_putinserver(id)
{
    Hms_ResetPlayer(id);
    g_Player[id][pConnected] = true;
    g_LoadStarted[id] = false;
    g_SettingsTouchedMask[id] = 0;
    g_SettingsDirtyMask[id] = 0;
    g_AuthRetryCount[id] = 0;
    Hms_SettingsDefaults(id);

    if (!is_user_bot(id) && !is_user_hltv(id))
        set_task(1.0, "Hms_LoadPlayer", id);
}

public client_authorized(id, const authid[])
{
    if (is_user_bot(id) || is_user_hltv(id))
        return;

    copy(g_AuthId[id], charsmax(g_AuthId[]), authid);
    if (!g_LoadStarted[id] && g_Player[id][pConnected])
    {
        remove_task(id);
        set_task(0.25, "Hms_LoadPlayer", id);
    }
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    remove_task(id);
    remove_task(HMS_TASK_HUD + id);
    remove_task(HMS_TASK_PREFS + id);

    if (g_Player[id][pConnected])
        Hms_SavePlayer(id);

    g_Player[id][pConnected] = false;
    g_LoadStarted[id] = false;
    g_AuthId[id][0] = 0;
}

stock Hms_ResetPlayer(id)
{
    arrayset(g_Player[id], 0, sizeof g_Player[]);
    g_AuthId[id][0] = 0;
    g_LoadStarted[id] = false;
    g_SettingsTouchedMask[id] = 0;
    g_SettingsDirtyMask[id] = 0;
    g_SelectedHudField[id] = 0;
    g_SelectedHudPanel[id] = 0;
    g_SelectedAdminTarget[id] = 0;
    g_SelectedAdminTargetUserId[id] = 0;
}

public Hms_PlayerPreThink(id)
{
    if (!get_pcvar_num(pcvar_enabled))
        return FMRES_IGNORED;

    // PlayerPreThink fires for multiple players in one engine frame. Count each distinct
    // game-time stamp only once; this produces an observed, approximate server frame rate.
    new Float:now = get_gametime();
    Hms_TrackServerFrame(now);

    if (!is_user_alive(id) || is_user_bot(id) || is_user_hltv(id))
        return FMRES_IGNORED;

    // Read live movement state once and share it with every per-frame sampler.
    new Float:velocity[3], Float:origin[3], Float:viewAngles[3];
    pev(id, pev_velocity, velocity);
    pev(id, pev_origin, origin);
    pev(id, pev_v_angle, viewAngles);
    new flags = pev(id, pev_flags);
    new buttons = pev(id, pev_button);
    new Float:speed = floatsqroot(velocity[0] * velocity[0] + velocity[1] * velocity[1]);

    Hms_SampleVelocity(id, flags, speed);
    Hms_SampleJump(id, flags, buttons, velocity, origin, viewAngles, now);
    Hms_SampleStrafe(id, buttons, viewAngles);
    Hms_SampleDistance(id, origin);
    return FMRES_IGNORED;
}

stock Hms_TrackServerFrame(Float:now)
{
    if (g_FrameWindowStart <= 0.0)
    {
        g_FrameWindowStart = now;
        g_LastObservedFrameTime = now;
        g_FrameWindowCount = 0;
        return;
    }

    // Only a changed game-time stamp signals a new sampled engine frame.
    if (now > g_LastObservedFrameTime + 0.000001)
    {
        g_FrameWindowCount++;
        g_LastObservedFrameTime = now;
    }

    new Float:elapsed = now - g_FrameWindowStart;
    if (elapsed >= 1.0)
    {
        g_ServerObservedFps = float(g_FrameWindowCount) / elapsed;
        g_FrameWindowStart = now;
        g_FrameWindowCount = 0;
    }
}

stock Hms_ResetMovementState(id)
{
    g_Player[id][pInAir] = false;
    g_Player[id][pGrounded] = false;
    g_Player[id][pWasGrounded] = false;
    g_Player[id][pHasOriginSample] = false;
    g_Player[id][pHasAirSpeedSample] = false;
    g_Player[id][pHasYawSample] = false;
    g_Player[id][pHasHudSpeedSample] = false;
    g_Player[id][pHudLastSpeed] = 0.0;
    g_Player[id][pKzHudExpire] = 0.0;
    g_Player[id][pKzHudPre] = 0.0;
    g_Player[id][pKzHudDelta] = 0.0;
    g_Player[id][pGroundFrames] = 0;
    g_Player[id][pHasLandedBefore] = false;
    g_Player[id][pBhopChain] = 0;
    g_Player[id][pCurrentSpeed] = 0.0;
    g_Player[id][pPreviousSpeed] = 0.0;
    g_Player[id][pLastButtons] = 0;
    g_Player[id][pGroundDuckPresses] = 0;
    g_Player[id][pCurrentJumpType] = HMS_JUMP_UNKNOWN;
    g_Player[id][pCurrentJumpDirection] = HMS_DIR_FORWARD;
    g_Player[id][pLastJumpWasDrop] = false;
    g_Player[id][pLastJumpWasLadder] = false;
    g_Player[id][pOnLadderFromBridge] = false;
    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
        g_NextHudUpdate[id][panel] = 0.0;
}

public Hms_EventDeath()
{
    new id = read_data(2);
    if (id < 1 || id > HMS_MAX_PLAYERS || !g_Player[id][pConnected])
        return;

    Hms_ResetMovementState(id);
}

public Hms_EventSpawn(id)
{
    if (id < 1 || id > HMS_MAX_PLAYERS || !g_Player[id][pConnected])
        return;

    Hms_ResetMovementState(id);
}

public HmsCmdToggle(id)
{
    g_Player[id][pHudEnabled] = !g_Player[id][pHudEnabled];
    if (!g_Player[id][pHudEnabled]) Hms_ClearPlayerHud(id);
    client_print_color(id, print_team_default, "^4[HNS]^1 HUD %s", g_Player[id][pHudEnabled] ? "^3ON^1 (enabled)" : "^1OFF (disabled)");
    Hms_QueuePrefsSave(id, HMS_DIRTY_PREFS);
    return PLUGIN_HANDLED;
}

public HmsCmdStats(id)
{
    if (g_Player[id][pLandingCount] > 0)
    {
        new jumpName[48], directionName[20];
        Hms_GetJumpTypeName(id, jumpName, charsmax(jumpName));
        Hms_GetJumpDirectionName(id, directionName, charsmax(directionName));
        client_print_color(id, print_team_default,
            "^4[HNS]^1 Last %s (%s): ^3%.2f units^1 | Pre: %.2f | Maxspeed: %.2f | Gain: %.2f | Land: %.2f",
            jumpName, directionName, g_Player[id][pLastJumpDistance], g_Player[id][pCompletedPreSpeed],
            g_Player[id][pCompletedMaxSpeed], g_Player[id][pCompletedMaxSpeed] - g_Player[id][pCompletedPreSpeed],
            g_Player[id][pLastLandingSpeed]);
        client_print_color(id, print_team_default,
            "^4[HNS]^1 Strafes~ %d | Sync~ %.0f%% | FOG: %d frames | Ducks: %d | Air: %.2fs | Pre-land -> Land: %.2f -> %.2f",
            Hms_GetJumpStrafeCount(id), Hms_GetSyncPercent(id), g_Player[id][pCompletedFogFrames],
            g_Player[id][pCompletedDuckCount], g_Player[id][pLastAirTime],
            g_Player[id][pLastPreGroundSpeed], g_Player[id][pLastPostGroundSpeed]);
    }
    else
    {
        client_print_color(id, print_team_default, "^4[HNS]^1 No completed jump yet. Make one jump and land to collect stats.");
    }
    client_print_color(id, print_team_default,
        "^4[HNS]^1 Speed %.1f u/s | Session max %.1f | Jumps %d | Bhop chain %d (best %d) | observed FPS %.1f",
        g_Player[id][pCurrentSpeed], g_Player[id][pSessionMaxSpeed], g_Player[id][pJumpCount],
        g_Player[id][pBhopChain], g_Player[id][pSessionMaxBhopChain], g_ServerObservedFps);
    return PLUGIN_HANDLED;
}

stock Hms_ResetSessionCounters(id)
{
    g_Player[id][pSessionMaxSpeed] = 0.0;
    g_Player[id][pJumpCount] = 0;
    g_Player[id][pLandingCount] = 0;
    g_Player[id][pBhopChain] = 0;
    g_Player[id][pSessionMaxBhopChain] = 0;
    g_Player[id][pLowSpeedEvents] = 0;
    g_Player[id][pStrafeSamples] = 0;
    g_Player[id][pStrafeGood] = 0;
    g_Player[id][pAirTurnCount] = 0;
    g_Player[id][pSessionStrafeSamples] = 0;
    g_Player[id][pSessionStrafeGood] = 0;
    g_Player[id][pSessionAirTurnCount] = 0;
    g_Player[id][pGroundFrames] = 0;
    g_Player[id][pFogTotalFrames] = 0;
    g_Player[id][pFogSamples] = 0;
    g_Player[id][pLastStrafeGain] = 0.0;
    g_Player[id][pLastStrafeLoss] = 0.0;
    g_Player[id][pJumpStrafeGain] = 0.0;
    g_Player[id][pJumpStrafeLoss] = 0.0;
    g_Player[id][pDistance] = 0.0;
    g_Player[id][pLastJumpDistance] = 0.0;
    g_Player[id][pLastLandingSpeed] = 0.0;
    g_Player[id][pLastAirTime] = 0.0;
    g_Player[id][pLastPrePostValid] = false;
    g_Player[id][pCompletedPreSpeed] = 0.0;
    g_Player[id][pCompletedTakeoffSpeed] = 0.0;
    g_Player[id][pCompletedMaxSpeed] = 0.0;
    g_Player[id][pCompletedFogFrames] = 0;
    g_Player[id][pCompletedDuckCount] = 0;
    g_Player[id][pCompletedStrafeSamples] = 0;
    g_Player[id][pCompletedStrafeGood] = 0;
    g_Player[id][pCompletedTurnCount] = 0;
    g_Player[id][pLastJumpType] = HMS_JUMP_UNKNOWN;
    g_Player[id][pLastJumpDirection] = HMS_DIR_FORWARD;
    g_Player[id][pLastVerticalDelta] = 0.0;
}

public HmsCmdResetSession(id)
{
    Hms_ResetSessionCounters(id);
    client_print_color(id, print_team_default, "^4[HNS]^1 Session movement counters reset. Personal preferences were not changed.");
    return PLUGIN_HANDLED;
}

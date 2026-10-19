// Three grouped panels minimize the number of per-client HUD messages. One global timer
// visits connected players; each panel keeps its own adaptive refresh deadline.
stock Hms_ClearPlayerHud(id)
{
    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
    {
        if (g_HudPanelVisible[id][panel])
        {
            ClearSyncHud(id, g_HudSync[panel]);
            g_HudPanelVisible[id][panel] = false;
        }
        g_NextHudUpdate[id][panel] = 0.0;
    }
}

stock Float:Hms_GetHudUpdateInterval(panel)
{
    new Float:base = get_pcvar_float(pcvar_hud_interval);
    if (base < 0.10) base = 0.10;
    if (base > 0.35) base = 0.35;

    // Automatically reduce HUD traffic at lower observed server frame rates.
    if (g_ServerObservedFps > 0.0 && g_ServerObservedFps < 35.0)
    {
        if (base < 0.20) base = 0.20;
    }
    else if (g_ServerObservedFps > 0.0 && g_ServerObservedFps < 60.0)
    {
        if (base < 0.15) base = 0.15;
    }

    switch (panel)
    {
        case HMS_PANEL_SPEED: return base;
        case HMS_PANEL_JUMP: return base;
        case HMS_PANEL_STATUS:
        {
            if (g_ServerObservedFps > 0.0 && g_ServerObservedFps < 35.0)
                return 1.50;
            if (g_ServerObservedFps > 0.0 && g_ServerObservedFps < 60.0)
                return 1.00;
            return 0.75;
        }
    }
    return 0.25;
}

public Hms_TaskHud(taskid)
{
    new Float:now = get_gametime();
    new maxPlayers = get_maxplayers();

    for (new id = 1; id <= maxPlayers; id++)
    {
        if (!is_user_connected(id))
            continue;

        if (!is_user_alive(id) || !get_pcvar_num(pcvar_enabled) || !g_Player[id][pHudEnabled])
        {
            Hms_ClearPlayerHud(id);
            continue;
        }

        for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
        {
            if (!g_HudPanelEnabled[id][panel])
            {
                if (g_HudPanelVisible[id][panel])
                {
                    ClearSyncHud(id, g_HudSync[panel]);
                    g_HudPanelVisible[id][panel] = false;
                }
                continue;
            }

            if (now + 0.0001 < g_NextHudUpdate[id][panel])
                continue;

            new Float:interval = Hms_GetHudUpdateInterval(panel);
            g_NextHudUpdate[id][panel] = now + interval;

            new message[512];
            message[0] = 0;
            switch (panel)
            {
                case HMS_PANEL_STATUS: Hms_FormatStatusPanel(id, message, charsmax(message));
                case HMS_PANEL_SPEED: Hms_FormatSpeedPanel(id, message, charsmax(message));
                case HMS_PANEL_JUMP: Hms_FormatJumpPanel(id, message, charsmax(message));
            }

            if (!message[0])
            {
                if (g_HudPanelVisible[id][panel])
                {
                    ClearSyncHud(id, g_HudSync[panel]);
                    g_HudPanelVisible[id][panel] = false;
                }
                continue;
            }

            new color = g_HudPanelColor[id][panel];
            if (color < 0 || color >= HMS_COLOR_COUNT) color = 0;
            new r = g_ColorR[color];
            new g = g_ColorG[color];
            new b = g_ColorB[color];
            new hudChannel = panel + 1;
            new Float:holdTime = interval * 1.65;
            if (holdTime < 0.25) holdTime = 0.25;
            if (holdTime > 1.75) holdTime = 1.75;

            if (g_Player[id][pHudStyle] == 1 && panel == HMS_PANEL_JUMP)
            {
                Hms_KzCenterColor(id, r, g, b);
                holdTime = 1.0;
                hudChannel = 4;
                g_NextHudUpdate[id][panel] = now + 0.10;
            }
            else if (g_Player[id][pHudStyle] == 1 && panel == HMS_PANEL_SPEED)
            {
                r = 255; g = 255; b = 255;
            }
            else if (g_Player[id][pHudStyle] == 2 && panel == HMS_PANEL_SPEED)
            {
                Hms_PrefogNumColor(id, r, g, b);
                g_NextHudUpdate[id][panel] = now + 0.10;
            }
            else if (panel == HMS_PANEL_JUMP)
                Hms_LiveRowColor(id, r, g, b);

            new Float:x = float(g_HudPanelX[id][panel]) / 100.0;
            if (g_HudPanelX[id][panel] < 0) x = -1.0;
            new Float:y = float(g_HudPanelY[id][panel]) / 100.0;

            // Separate explicit channels keep HMS panels from overwriting each other.
            set_hudmessage(r, g, b, x, y,
                0, 0.0, holdTime, 0.0, 0.0, hudChannel);
            ShowSyncHudMsg(id, g_HudSync[panel], "%s", message);
            g_HudPanelVisible[id][panel] = true;
        }
    }
}

stock Hms_AppendHudLine(output[], maxlen, const line[])
{
    if (!line[0])
        return;
    if (output[0])
        add(output, maxlen, "^n");
    add(output, maxlen, line);
}

stock Hms_FormatSpeedPanel(id, output[], maxlen)
{
    new line[64];
    if (g_Player[id][pHudStyle] == 1)
    {
        if (g_HudFieldEnabled[id][HMS_HUD_SPEED])
            formatex(output, maxlen, "%.0f units/sec", g_Player[id][pCurrentSpeed]);
        return;
    }
    if (g_Player[id][pHudStyle] == 2)
    {
        Hms_FormatPrefogNumPanel(id, output, maxlen);
        return;
    }
    if (g_HudFieldEnabled[id][HMS_HUD_SPEED])
    {
        formatex(line, charsmax(line), "%.1f", g_Player[id][pCurrentSpeed]);
        Hms_AppendHudLine(output, maxlen, line);
    }
    if (g_HudFieldEnabled[id][HMS_HUD_MAXSPEED])
    {
        formatex(line, charsmax(line), "MAX %.0f", g_Player[id][pSessionMaxSpeed]);
        Hms_AppendHudLine(output, maxlen, line);
    }
    if (g_HudFieldEnabled[id][HMS_HUD_LOWSPEED])
    {
        formatex(line, charsmax(line), "LOW %d", g_Player[id][pLowSpeedEvents]);
        Hms_AppendHudLine(output, maxlen, line);
    }
}

stock bool:Hms_JumpResultFresh(id)
{
    if (g_Player[id][pLandingCount] <= 0 || g_Player[id][pLastLandTime] <= 0.0)
        return false;
    return (get_gametime() - g_Player[id][pLastLandTime]) <= 2.0;
}

stock Hms_LiveFogFrames(id)
{
    // No jump for 2 seconds: the old FOG is stale. Walking is not a new FOG sample.
    if (!Hms_JumpResultFresh(id))
        return 0;
    new fog = g_Player[id][pLastFogFrames];
    if (fog < 1 || fog > 10) fog = 0;
    return fog;
}

// PreFog grades: jump 1 perfect, 2 good, 3 bad, 4+ very bad.
// Duck grades shift one frame later, matching prefog.sma.
stock Hms_FogGrade(id, frames)
{
    if (frames <= 0)
        return 0;
    new duck = g_Player[id][pJumpDuckCount];
    if (duck > 0)
    {
        if (frames == 2) return 1;
        if (frames == 3) return 2;
        if (frames == 4) return 3;
        return 4;
    }
    if (frames == 1) return 1;
    if (frames == 2) return 2;
    if (frames == 3) return 3;
    return 4;
}

stock Hms_FogGradeName(id, grade, output[], maxlen)
{
    new key[16];
    formatex(key, charsmax(key), "HMS_GRADE_%d", grade);
    switch (grade)
    {
        case 1: Hms_L(id, key, output, maxlen, "PERFECT");
        case 2: Hms_L(id, key, output, maxlen, "GOOD");
        case 3: Hms_L(id, key, output, maxlen, "BAD");
        case 4: Hms_L(id, key, output, maxlen, "VERY BAD");
        default: Hms_L(id, "HMS_GRADE_0", output, maxlen, "WAIT");
    }
}

// One GoldSrc HUD channel is one RGB color, so the whole live row follows the FOG grade.
// Green / yellow / orange / red is the usual KZ prestrafe scale; white is idle.
stock Hms_LiveRowColor(id, &r, &g, &b)
{
    if (!g_HudFieldEnabled[id][HMS_HUD_FOG])
    {
        r = 235; g = 245; b = 255;
        return;
    }
    switch (Hms_FogGrade(id, Hms_LiveFogFrames(id)))
    {
        case 1: { r = 80;  g = 255; b = 90; }
        case 2: { r = 255; g = 230; b = 40; }
        case 3: { r = 255; g = 145; b = 30; }
        case 4: { r = 255; g = 55;  b = 55; }
        default:{ r = 235; g = 245; b = 255; }
    }
}

stock Hms_FormatJumpPanel(id, output[], maxlen)
{
    if (g_Player[id][pHudStyle] == 2)
        return;
    if (g_Player[id][pHudStyle] == 1)
    {
        Hms_FormatKzCenterPanel(id, output, maxlen);
        return;
    }

    new line[192], piece[48], gradeName[16];
    line[0] = 0;

    if (g_HudFieldEnabled[id][HMS_HUD_FOG])
    {
        new frames = Hms_LiveFogFrames(id);
        Hms_FogGradeName(id, Hms_FogGrade(id, frames), gradeName, charsmax(gradeName));
        formatex(piece, charsmax(piece), "FOG %02d  %s", frames, gradeName);
        add(line, charsmax(line), piece);
    }
    if (g_Player[id][pShowPre] && g_HudFieldEnabled[id][HMS_HUD_PRESPEED])
    {
        new Float:airSpeed = g_Player[id][pInAir] ? g_Player[id][pCurrentSpeed] : g_Player[id][pLastAirborneSpeed];
        // GND is the last takeoff pre-speed. Clear it when that jump is more than 2 seconds old.
        new Float:groundSpeed = Hms_JumpResultFresh(id) ? g_Player[id][pJumpStartSpeed] : 0.0;
        formatex(piece, charsmax(piece), "AIR %3.0f  GND %3.0f", airSpeed, groundSpeed);
        if (line[0]) add(line, charsmax(line), "   |   ");
        add(line, charsmax(line), piece);
    }
    if (g_HudFieldEnabled[id][HMS_HUD_SYNC] && g_Player[id][pLandingCount] > 0)
    {
        formatex(piece, charsmax(piece), "SYNC %.0f", Hms_GetSyncPercent(id));
        if (line[0]) add(line, charsmax(line), "   |   ");
        add(line, charsmax(line), piece);
    }
    if (g_HudFieldEnabled[id][HMS_HUD_STRAFE] && g_Player[id][pLandingCount] > 0)
    {
        formatex(piece, charsmax(piece), "STR +%.0f/-%.0f", g_Player[id][pLastStrafeGain], g_Player[id][pLastStrafeLoss]);
        if (line[0]) add(line, charsmax(line), "   |   ");
        add(line, charsmax(line), piece);
    }
    if (g_HudFieldEnabled[id][HMS_HUD_LASTJUMP] && g_Player[id][pLandingCount] > 0)
    {
        new jumpName[24];
        Hms_GetJumpTypeCode(id, jumpName, charsmax(jumpName));
        formatex(piece, charsmax(piece), "%s %.1f", jumpName, g_Player[id][pLastJumpDistance]);
        if (line[0]) add(line, charsmax(line), "   |   ");
        add(line, charsmax(line), piece);
    }
    if (line[0])
        Hms_AppendHudLine(output, maxlen, line);
}

#define HMS_KZ_PRESTRAFE_CAP 300.0
#define HMS_KZ_HUD_HOLD 1.0

stock Hms_ArmKzCenterHud(id)
{
    if (g_Player[id][pHudStyle] != 1 && g_Player[id][pHudStyle] != 2)
        return;

    new Float:pre = g_Player[id][pJumpStartSpeed];
    new Float:delta = g_Player[id][pCurrentSpeed] - pre;
    g_Player[id][pKzHudPre] = pre;
    g_Player[id][pKzHudDelta] = delta;
    g_Player[id][pKzHudExpire] = get_gametime() + HMS_KZ_HUD_HOLD;
    g_NextHudUpdate[id][HMS_PANEL_JUMP] = 0.0;
    g_NextHudUpdate[id][HMS_PANEL_SPEED] = 0.0;
}

stock bool:Hms_KzCenterActive(id)
{
    return g_Player[id][pKzHudExpire] > get_gametime();
}

stock Hms_KzCenterColor(id, &r, &g, &b)
{
    if (g_Player[id][pKzHudDelta] >= 0.0)
    {
        r = 0; g = 255; b = 0;
    }
    else
    {
        r = 255; g = 0; b = 0;
    }
}

// Takeoff-only English line. No live center speed, no language file.
stock Hms_FormatKzCenterPanel(id, output[], maxlen)
{
    if (!g_HudFieldEnabled[id][HMS_HUD_FOG] || !Hms_KzCenterActive(id))
        return;

    new Float:pre = g_Player[id][pKzHudPre];
    new Float:delta = g_Player[id][pKzHudDelta];
    if (pre > HMS_KZ_PRESTRAFE_CAP)
    {
        if (delta >= 0.0)
            formatex(output, maxlen, "Your prestrafe %.2f(+%.1f) is too high(%.1f)",
                pre, delta, HMS_KZ_PRESTRAFE_CAP);
        else
            formatex(output, maxlen, "Your prestrafe %.2f(%.1f) is too high(%.1f)",
                pre, delta, HMS_KZ_PRESTRAFE_CAP);
        return;
    }

    if (delta >= 0.0)
        formatex(output, maxlen, "%.2f(+%.1f)", pre, delta);
    else
        formatex(output, maxlen, "%.2f(%.1f)", pre, delta);
}

// PreFog ST_NUM: integer speed, optional takeoff overlay, white-to-green by speed.
stock Hms_PrefogFogTag(grade, output[], maxlen)
{
    switch (grade)
    {
        case 1: copy(output, maxlen, "[P]");
        case 2: copy(output, maxlen, "[G]");
        case 3: copy(output, maxlen, "[B]");
        default: copy(output, maxlen, "[VB]");
    }
}

stock Hms_PrefogNumColor(id, &r, &g, &b)
{
    if (Hms_KzCenterActive(id) && g_HudFieldEnabled[id][HMS_HUD_FOG])
    {
        new fog = g_Player[id][pLastFogFrames];
        if (fog >= 1 && Hms_FogGrade(id, fog) == 1 && g_Player[id][pKzHudPre] > 30.0)
        {
            r = 0; g = 250; b = 0;
            return;
        }
    }

    new Float:speed = g_Player[id][pCurrentSpeed];
    if (speed > 285.0) speed = 285.0;
    new Float:val = 0.0;
    if (speed > 40.0)
        val = (speed - 40.0) / 245.0;
    if (val < 0.0) val = 0.0;
    if (val > 1.0) val = 1.0;
    r = floatround((0.0 - 255.0) * val + 255.0);
    g = floatround((250.0 - 255.0) * val + 255.0);
    b = floatround((0.0 - 255.0) * val + 255.0);
}

stock Hms_FormatPrefogNumPanel(id, output[], maxlen)
{
    new szSpeed[24];
    szSpeed[0] = 0;
    if (g_HudFieldEnabled[id][HMS_HUD_SPEED])
        formatex(szSpeed, charsmax(szSpeed), "%.0f", g_Player[id][pCurrentSpeed]);

    if (!g_HudFieldEnabled[id][HMS_HUD_FOG] || !Hms_KzCenterActive(id))
    {
        copy(output, maxlen, szSpeed);
        return;
    }

    new Float:post = g_Player[id][pKzHudPre];
    if (post <= 30.0)
    {
        copy(output, maxlen, szSpeed);
        return;
    }

    new fog = g_Player[id][pLastFogFrames];
    if (fog >= 1)
    {
        new tag[8];
        Hms_PrefogFogTag(Hms_FogGrade(id, fog), tag, charsmax(tag));
        formatex(output, maxlen, "%s^n^n%d %s^n%.2f^n%.2f",
            szSpeed, fog, tag, g_Player[id][pLastAirborneSpeed], post);
        return;
    }

    if (g_Player[id][pHasLandedBefore])
    {
        new kind[16];
        if (g_Player[id][pLastJumpWasLadder])
            copy(kind, charsmax(kind), "[Ladder]");
        else if (g_Player[id][pJumpDuckCount] > 0)
            copy(kind, charsmax(kind), "[Duck]");
        else
            copy(kind, charsmax(kind), "[Jump]");
        formatex(output, maxlen, "%s^n^n%s^n%.2f", szSpeed, kind, post);
        return;
    }

    copy(output, maxlen, szSpeed);
}

stock Hms_FormatStatusPanel(id, output[], maxlen)
{
    #pragma unused id
    new mapName[64];
    get_mapname(mapName, charsmax(mapName));
    new Float:now = get_gametime();

    // One server-wide cache prevents every player's HUD task rescanning all player slots each refresh.
    if (g_StatusCacheTime <= 0.0 || now - g_StatusCacheTime >= 0.50 || !equal(mapName, g_StatusCacheMap))
        Hms_RefreshStatusCache(mapName, now);

    Hms_AppendHudLine(output, maxlen, g_StatusCacheLine1);
    Hms_AppendHudLine(output, maxlen, g_StatusCacheLine2);
    Hms_AppendHudLine(output, maxlen, g_StatusCacheLine3);
}

stock Hms_RefreshStatusCache(const mapName[], Float:now)
{

    new players[32], count, online, spectators, tTotal, tAlive, ctTotal, ctAlive;
    get_players(players, count);
    for (new i = 0; i < count; i++)
    {
        new target = players[i];
        if (!is_user_connected(target) || is_user_hltv(target))
            continue;
        online++;
        new CsTeams:team = cs_get_user_team(target);
        if (team == CS_TEAM_T)
        {
            tTotal++;
            if (is_user_alive(target)) tAlive++;
        }
        else if (team == CS_TEAM_CT)
        {
            ctTotal++;
            if (is_user_alive(target)) ctAlive++;
        }
        else
        {
            spectators++;
        }
    }

    new timeLeft = get_timeleft();
    new timeText[24];
    if (timeLeft < 0)
        copy(timeText, charsmax(timeText), "TIME --:--");
    else if (timeLeft >= 3600)
        formatex(timeText, charsmax(timeText), "%d:%02d:%02d", timeLeft / 3600, (timeLeft % 3600) / 60, timeLeft % 60);
    else
        formatex(timeText, charsmax(timeText), "%02d:%02d", timeLeft / 60, timeLeft % 60);

    formatex(g_StatusCacheLine1, charsmax(g_StatusCacheLine1), "MAP   %s   |   %d/%d   |   %s",
        mapName, online, get_maxplayers(), timeText);
    formatex(g_StatusCacheLine2, charsmax(g_StatusCacheLine2), "T   %d/%d alive   |   CT   %d/%d alive   |   SPEC   %d",
        tAlive, tTotal, ctAlive, ctTotal, spectators);

    new Float:age = now - g_HnsStatusUpdated;
    if (g_HnsStatusUpdated <= 0.0)
    {
        formatex(g_StatusCacheLine3, charsmax(g_StatusCacheLine3), "HNS CORE   WAITING FOR STATUS BRIDGE");
    }
    else if (age > 30.0)
    {
        formatex(g_StatusCacheLine3, charsmax(g_StatusCacheLine3), "HNS CORE   STATUS STALE  (%.0fs)", age);
    }
    else if (g_HnsCountdown >= 0.0)
    {
        new Float:remaining = g_HnsCountdown - age;
        if (remaining < 0.0) remaining = 0.0;
        formatex(g_StatusCacheLine3, charsmax(g_StatusCacheLine3), "HNS   %s   |   %s   |   T-%.0fs", g_HnsPhase, g_HnsDetail, remaining);
    }
    else
    {
        formatex(g_StatusCacheLine3, charsmax(g_StatusCacheLine3), "HNS   %s   |   %s", g_HnsPhase, g_HnsDetail);
    }

    copy(g_StatusCacheMap, charsmax(g_StatusCacheMap), mapName);
    g_StatusCacheTime = now;
}

stock Hms_ApplyHudPreset(id, preset)
{
    // Speed stays on the bottom edge. The live FOG row sits just above it, centered.
    switch (preset)
    {
        case 0:
        {
            g_HudPanelX[id][HMS_PANEL_STATUS] = 2; g_HudPanelY[id][HMS_PANEL_STATUS] = 3;
            g_HudPanelX[id][HMS_PANEL_SPEED] = -1; g_HudPanelY[id][HMS_PANEL_SPEED] = 90;
            g_HudPanelX[id][HMS_PANEL_JUMP] = -1; g_HudPanelY[id][HMS_PANEL_JUMP] = 82;
        }
        case 1:
        {
            g_HudPanelX[id][HMS_PANEL_STATUS] = 2; g_HudPanelY[id][HMS_PANEL_STATUS] = 3;
            g_HudPanelX[id][HMS_PANEL_SPEED] = -1; g_HudPanelY[id][HMS_PANEL_SPEED] = 86;
            g_HudPanelX[id][HMS_PANEL_JUMP] = -1; g_HudPanelY[id][HMS_PANEL_JUMP] = 78;
        }
        case 2:
        {
            g_HudPanelX[id][HMS_PANEL_STATUS] = 2; g_HudPanelY[id][HMS_PANEL_STATUS] = 3;
            g_HudPanelX[id][HMS_PANEL_SPEED] = -1; g_HudPanelY[id][HMS_PANEL_SPEED] = 90;
            g_HudPanelX[id][HMS_PANEL_JUMP] = -1; g_HudPanelY[id][HMS_PANEL_JUMP] = 84;
        }
    }
}

stock Hms_ResetPanelLayout(id, panel)
{
    if (panel < 0 || panel >= HMS_PANEL_COUNT) return;
    g_HudPanelEnabled[id][panel] = true;
    switch (panel)
    {
        case HMS_PANEL_STATUS: { g_HudPanelX[id][panel] = 2; g_HudPanelY[id][panel] = 3; g_HudPanelColor[id][panel] = 6; g_HudPanelEnabled[id][panel] = false; }
        case HMS_PANEL_SPEED: { g_HudPanelX[id][panel] = -1; g_HudPanelY[id][panel] = 90; g_HudPanelColor[id][panel] = 0; }
        case HMS_PANEL_JUMP: { g_HudPanelX[id][panel] = -1; g_HudPanelY[id][panel] = 82; g_HudPanelColor[id][panel] = 0; }
    }
}

new bool:g_HmsHudRev2[HMS_MAX_PLAYERS + 1];
// Set while a legacy classic default (hud_style 0, never picked) is being moved to KZ center.
// Layout callbacks must not copy the old bottom panels back over that preset.
new bool:g_HmsKeepCenter[HMS_MAX_PLAYERS + 1];

stock bool:Hms_HudNeedsRev(id)
{
    if (g_Player[id][pHudStyle] == 1 || g_Player[id][pHudStyle] == 2)
        return false;
    if (g_HudPanelY[id][HMS_PANEL_SPEED] < 80)
        return true;
    if (g_HudPanelX[id][HMS_PANEL_JUMP] >= 0)
        return true;
    if (g_HudPanelColor[id][HMS_PANEL_JUMP] == 7)
        return true;
    return false;
}

stock Hms_ApplyKzCenterHud(id)
{
    g_Player[id][pHudStyle] = 1;
    g_HudPanelEnabled[id][HMS_PANEL_SPEED] = true;
    g_HudPanelEnabled[id][HMS_PANEL_JUMP] = true;
    g_HudPanelX[id][HMS_PANEL_SPEED] = -1;
    g_HudPanelY[id][HMS_PANEL_SPEED] = 90;
    g_HudPanelX[id][HMS_PANEL_JUMP] = -1;
    g_HudPanelY[id][HMS_PANEL_JUMP] = 66;
    g_HudFieldEnabled[id][HMS_HUD_SPEED] = true;
    g_HudFieldEnabled[id][HMS_HUD_FOG] = true;
    g_Player[id][pHasHudSpeedSample] = false;
    g_Player[id][pKzHudExpire] = 0.0;
}

stock Hms_ApplyPrefogNumHud(id)
{
    g_Player[id][pHudStyle] = 2;
    g_HudPanelEnabled[id][HMS_PANEL_SPEED] = true;
    g_HudPanelEnabled[id][HMS_PANEL_JUMP] = false;
    g_HudPanelX[id][HMS_PANEL_SPEED] = -1;
    g_HudPanelY[id][HMS_PANEL_SPEED] = 55;
    g_HudFieldEnabled[id][HMS_HUD_SPEED] = true;
    g_HudFieldEnabled[id][HMS_HUD_FOG] = true;
    g_Player[id][pHasHudSpeedSample] = false;
    g_Player[id][pKzHudExpire] = 0.0;
}

stock Hms_ApplyBottomHud(id)
{
    g_HudPanelEnabled[id][HMS_PANEL_STATUS] = false;
    g_HudPanelEnabled[id][HMS_PANEL_SPEED] = true;
    g_HudPanelEnabled[id][HMS_PANEL_JUMP] = true;
    g_HudPanelX[id][HMS_PANEL_SPEED] = -1;
    g_HudPanelY[id][HMS_PANEL_SPEED] = 90;
    g_HudPanelColor[id][HMS_PANEL_SPEED] = 0;
    g_HudPanelX[id][HMS_PANEL_JUMP] = -1;
    g_HudPanelY[id][HMS_PANEL_JUMP] = 82;
    g_HudPanelColor[id][HMS_PANEL_JUMP] = 0;

    g_HudFieldEnabled[id][HMS_HUD_SPEED] = true;
    g_HudFieldEnabled[id][HMS_HUD_MAXSPEED] = false;
    g_HudFieldEnabled[id][HMS_HUD_JUMPS] = false;
    g_HudFieldEnabled[id][HMS_HUD_BHOP] = false;
    g_HudFieldEnabled[id][HMS_HUD_LASTJUMP] = false;
    g_HudFieldEnabled[id][HMS_HUD_SYNC] = false;
    g_HudFieldEnabled[id][HMS_HUD_LOWSPEED] = false;
    g_HudFieldEnabled[id][HMS_HUD_FOG] = true;
    g_HudFieldEnabled[id][HMS_HUD_STRAFE] = false;
    g_HudFieldEnabled[id][HMS_HUD_AIRTIME] = false;
    g_HudFieldEnabled[id][HMS_HUD_PRESPEED] = true;

    g_Player[id][pSoundsEnabled] = false;
    g_Player[id][pTakeoffSound] = false;
    g_Player[id][pSpeedHud] = false;
    g_Player[id][pSpeedBig] = false;
    g_Player[id][pFogPopup] = true;
    g_Player[id][pShowPre] = true;
    g_Player[id][pHudStyle] = 0;
    g_Player[id][pLandingSound] = false;
    g_Player[id][pAchievementSound] = false;
}

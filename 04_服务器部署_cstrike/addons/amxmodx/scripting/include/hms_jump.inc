// Event-based HNS movement sampler. Labels are conservative: this first-pass classifier
// identifies LJ/CJ/DCJ/MCJ/Bhop/Drop/Ladder contexts, but is not a drop-in UQ classifier.
stock Hms_SampleJump(id, flags, buttons, const Float:velocity[3], const Float:origin[3], const Float:viewAngles[3], Float:now)
{
    new bool:onGround = (flags & FL_ONGROUND) != 0;
    new bool:wasGrounded = g_Player[id][pGrounded];
    g_Player[id][pWasGrounded] = wasGrounded;
    g_Player[id][pGrounded] = onGround;

    // Preserve the last complete airborne velocity sample so PRE means speed before touchdown.
    if (!onGround && g_Player[id][pInAir])
        g_Player[id][pLastAirborneSpeed] = g_Player[id][pCurrentSpeed];

    if (onGround)
    {
        if (wasGrounded)
        {
            g_Player[id][pGroundFrames]++;
            // Count distinct Duck-button presses while grounded. This is a useful CJ heuristic,
            // not a complete duck-technique recognizer.
            if ((buttons & IN_DUCK) && !(g_Player[id][pLastButtons] & IN_DUCK))
                g_Player[id][pGroundDuckPresses]++;
        }
        else if (!g_Player[id][pInAir])
        {
            g_Player[id][pGroundFrames] = 1;
        }
    }

    // Ground-to-air transition: record one launch event only, never one event per airborne frame.
    if (wasGrounded && !onGround && !g_Player[id][pInAir])
    {
        g_Player[id][pInAir] = true;
        g_Player[id][pJumpCount]++;
        // KZ fog only counts a short ground touch. Walking, then jumping, is a long stand:
        // kz_fog.sma stops counting at 10 and prefog.sma ignores anything above 10.
        new fogFrames = g_Player[id][pGroundFrames];
        if (!g_Player[id][pHasLandedBefore] || fogFrames < 1 || fogFrames > 10)
            fogFrames = 0;
        g_Player[id][pLastFogFrames] = fogFrames;
        if (g_Player[id][pHasLandedBefore])
        {
            g_Player[id][pFogTotalFrames] += g_Player[id][pGroundFrames];
            g_Player[id][pFogSamples]++;
        }

        g_Player[id][pLastJumpWasDrop] = (velocity[2] <= 20.0 && !(buttons & IN_JUMP) && !(g_Player[id][pLastButtons] & IN_JUMP));
        g_Player[id][pJumpDuckCount] = g_Player[id][pGroundDuckPresses];
        g_Player[id][pLastJumpWasLadder] = g_Player[id][pOnLadderFromBridge] || Hms_DetectLadderAtLaunch(origin);
        g_Player[id][pCurrentJumpDirection] = Hms_ClassifyLaunchDirection(velocity, viewAngles, g_Player[id][pCurrentSpeed]);
        g_Player[id][pCurrentJumpType] = Hms_ClassifyJumpType(id);

        Hms_UpdateBhopChain(id);
        g_Player[id][pJumpOrigin][0] = origin[0];
        g_Player[id][pJumpOrigin][1] = origin[1];
        g_Player[id][pJumpOrigin][2] = origin[2];
        // Keep UQ-style Pre distinct from the first airborne/takeoff sample.
        g_Player[id][pJumpStartSpeed] = g_Player[id][pLastGroundedSpeed];
        g_Player[id][pJumpTakeoffSpeed] = g_Player[id][pCurrentSpeed];
        g_Player[id][pJumpMaxSpeed] = g_Player[id][pCurrentSpeed];
        g_Player[id][pAirStarted] = now;
        g_Player[id][pAirTurnCount] = 0;
        g_Player[id][pStrafeSamples] = 0;
        g_Player[id][pStrafeGood] = 0;
        g_Player[id][pJumpStrafeGain] = 0.0;
        g_Player[id][pJumpStrafeLoss] = 0.0;
        g_Player[id][pLastAirSpeed] = g_Player[id][pCurrentSpeed];
        g_Player[id][pHasAirSpeedSample] = true;
        g_Player[id][pHasYawSample] = false;
        g_Player[id][pGroundFrames] = 0;
        g_Player[id][pGroundDuckPresses] = 0;

        Hms_PlayTakeoffFeedback(id);
        Hms_NotifyJump(id, g_Player[id][pJumpStartSpeed]);
        Hms_ArmKzCenterHud(id);
    }
    else if (!wasGrounded && onGround && g_Player[id][pInAir])
    {
        new Float:dx = origin[0] - g_Player[id][pJumpOrigin][0];
        new Float:dy = origin[1] - g_Player[id][pJumpOrigin][1];
        new Float:distance = floatsqroot(dx * dx + dy * dy);
        new Float:airtime = now - g_Player[id][pAirStarted];

        g_Player[id][pLandingCount]++;
        g_Player[id][pInAir] = false;
        g_Player[id][pHasLandedBefore] = true;
        g_Player[id][pLastLandTime] = now;
        g_Player[id][pGroundFrames] = 0;
        g_Player[id][pGroundDuckPresses] = 0;
        g_Player[id][pLastJumpDistance] = distance;
        g_Player[id][pLastVerticalDelta] = origin[2] - g_Player[id][pJumpOrigin][2];
        // Only publish the new jump type/direction as the last completed result on landing.
        g_Player[id][pLastJumpType] = g_Player[id][pCurrentJumpType];
        g_Player[id][pLastJumpDirection] = g_Player[id][pCurrentJumpDirection];
        g_Player[id][pCompletedPreSpeed] = g_Player[id][pJumpStartSpeed];
        g_Player[id][pCompletedTakeoffSpeed] = g_Player[id][pJumpTakeoffSpeed];
        g_Player[id][pCompletedMaxSpeed] = g_Player[id][pJumpMaxSpeed];
        g_Player[id][pCompletedFogFrames] = g_Player[id][pLastFogFrames];
        g_Player[id][pCompletedDuckCount] = g_Player[id][pJumpDuckCount];
        g_Player[id][pCompletedStrafeSamples] = g_Player[id][pStrafeSamples];
        g_Player[id][pCompletedStrafeGood] = g_Player[id][pStrafeGood];
        g_Player[id][pCompletedTurnCount] = g_Player[id][pAirTurnCount];
        g_Player[id][pLastLandingSpeed] = g_Player[id][pCurrentSpeed];
        g_Player[id][pLastPreGroundSpeed] = g_Player[id][pLastAirborneSpeed];
        g_Player[id][pLastPostGroundSpeed] = g_Player[id][pCurrentSpeed];
        g_Player[id][pHasPreGroundSpeed] = true;
        g_Player[id][pLastPrePostValid] = true;
        g_Player[id][pLastGroundSpeedDelta] = g_Player[id][pLastPostGroundSpeed] - g_Player[id][pLastPreGroundSpeed];
        g_Player[id][pLastAirTime] = airtime;
        g_Player[id][pLastStrafeGain] = g_Player[id][pJumpStrafeGain];
        g_Player[id][pLastStrafeLoss] = g_Player[id][pJumpStrafeLoss];
        g_Player[id][pHasAirSpeedSample] = false;

        Hms_PlayLandingFeedback(id, distance);
        Hms_SaveJumpEvent(id, distance, airtime);
        Hms_NotifyLand(id, distance, airtime, g_Player[id][pJumpMaxSpeed]);
    }
}

stock Hms_ClassifyJumpType(id)
{
    if (g_Player[id][pLastJumpWasLadder])
    {
        new maxFogLadder = get_pcvar_num(pcvar_bhop_fog_frames);
        if (g_Player[id][pHasLandedBefore] && g_Player[id][pLastFogFrames] <= maxFogLadder)
            return HMS_JUMP_LADDER_BHOP;
        return HMS_JUMP_LADDER;
    }

    if (g_Player[id][pLastJumpWasDrop])
        return HMS_JUMP_DROP;

    new maxFog = get_pcvar_num(pcvar_bhop_fog_frames);
    if (maxFog < 0) maxFog = 0;
    new bool:isBhopWindow = g_Player[id][pHasLandedBefore] && g_Player[id][pLastFogFrames] <= maxFog;

    if (isBhopWindow && g_Player[id][pGroundDuckPresses] > 0)
        return HMS_JUMP_BHOP_DUCK;
    if (isBhopWindow)
        return HMS_JUMP_BHOP;

    if (g_Player[id][pGroundDuckPresses] >= 3)
        return HMS_JUMP_MCJ;
    if (g_Player[id][pGroundDuckPresses] == 2)
        return HMS_JUMP_DCJ;
    if (g_Player[id][pGroundDuckPresses] == 1)
        return HMS_JUMP_CJ;

    return HMS_JUMP_LJ;
}

stock Hms_ClassifyLaunchDirection(const Float:velocity[3], const Float:viewAngles[3], Float:speed)
{
    if (speed < 1.0)
        return HMS_DIR_FORWARD;

    new Float:yawOnly[3], Float:viewForward[3], Float:viewRight[3], Float:viewUp[3];
    yawOnly[0] = 0.0;
    yawOnly[1] = viewAngles[1];
    yawOnly[2] = 0.0;
    engfunc(EngFunc_AngleVectors, yawOnly, viewForward, viewRight, viewUp);
    new Float:forwardSpeed = velocity[0] * viewForward[0] + velocity[1] * viewForward[1];

    if (forwardSpeed < -(speed * 0.35))
        return HMS_DIR_BACKWARDS;
    if (forwardSpeed >= -(speed * 0.25) && forwardSpeed <= (speed * 0.25))
        return HMS_DIR_SIDEWAYS;
    return HMS_DIR_FORWARD;
}

// Conservative event-only ladder probe. This costs several point-content checks at launch,
// not every server frame. Ladder detection must still be verified on the target map set.
stock bool:Hms_DetectLadderAtLaunch(const Float:origin[3])
{
    new Float:probe[3];
    probe[2] = origin[2] + 24.0;

    probe[0] = origin[0] + 16.0; probe[1] = origin[1];
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;
    probe[0] = origin[0] - 16.0;
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;
    probe[0] = origin[0]; probe[1] = origin[1] + 16.0;
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;
    probe[1] = origin[1] - 16.0;
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;

    probe[2] = origin[2] + 42.0;
    probe[0] = origin[0] + 20.0; probe[1] = origin[1];
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;
    probe[0] = origin[0] - 20.0;
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;
    probe[0] = origin[0]; probe[1] = origin[1] + 20.0;
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;
    probe[1] = origin[1] - 20.0;
    if (engfunc(EngFunc_PointContents, probe) == CONTENTS_LADDER) return true;

    return false;
}

stock Hms_GetJumpTypeName(id, output[], maxlen)
{
    switch (g_Player[id][pLastJumpType])
    {
        case HMS_JUMP_LJ: copy(output, maxlen, "LJ");
        case HMS_JUMP_CJ: copy(output, maxlen, "CJ");
        case HMS_JUMP_DCJ: copy(output, maxlen, "DCJ");
        case HMS_JUMP_MCJ: copy(output, maxlen, "MCJ");
        case HMS_JUMP_BHOP: copy(output, maxlen, "BhopJump");
        case HMS_JUMP_BHOP_DUCK: copy(output, maxlen, "BhopJump in Duck");
        case HMS_JUMP_DROP: copy(output, maxlen, "DropJump");
        case HMS_JUMP_LADDER: copy(output, maxlen, "LadderJump");
        case HMS_JUMP_LADDER_BHOP: copy(output, maxlen, "Ladder Bhop");
        default: copy(output, maxlen, "Jump");
    }

    if (g_Player[id][pLastVerticalDelta] >= 18.0)
        add(output, maxlen, " UP");
    else if (g_Player[id][pLastVerticalDelta] <= -18.0)
        add(output, maxlen, " DOWN");

    if (g_Player[id][pLastJumpDirection] == HMS_DIR_SIDEWAYS)
        add(output, maxlen, " SIDEWAYS");
    else if (g_Player[id][pLastJumpDirection] == HMS_DIR_BACKWARDS)
        add(output, maxlen, " BACKWARDS");
}

stock Hms_GetJumpTypeCode(id, output[], maxlen)
{
    switch (g_Player[id][pLastJumpType])
    {
        case HMS_JUMP_LJ: copy(output, maxlen, "LJ");
        case HMS_JUMP_CJ: copy(output, maxlen, "CJ");
        case HMS_JUMP_DCJ: copy(output, maxlen, "DCJ");
        case HMS_JUMP_MCJ: copy(output, maxlen, "MCJ");
        case HMS_JUMP_BHOP: copy(output, maxlen, "BHOP");
        case HMS_JUMP_BHOP_DUCK: copy(output, maxlen, "BHOP_DUCK");
        case HMS_JUMP_DROP: copy(output, maxlen, "DROP");
        case HMS_JUMP_LADDER: copy(output, maxlen, "LADDER");
        case HMS_JUMP_LADDER_BHOP: copy(output, maxlen, "LADDER_BHOP");
        default: copy(output, maxlen, "JUMP");
    }
}

stock Hms_GetJumpDirectionName(id, output[], maxlen)
{
    switch (g_Player[id][pLastJumpDirection])
    {
        case HMS_DIR_SIDEWAYS: copy(output, maxlen, "SIDEWAYS");
        case HMS_DIR_BACKWARDS: copy(output, maxlen, "BACKWARDS");
        default: copy(output, maxlen, "FORWARD");
    }
    if (g_Player[id][pLastVerticalDelta] >= 18.0)
        add(output, maxlen, " / UP");
    else if (g_Player[id][pLastVerticalDelta] <= -18.0)
        add(output, maxlen, " / DOWN");
}

stock Hms_PrintJumpResult(id)
{
    #pragma unused id
    return;

    new bool:broadcast = get_pcvar_num(pcvar_chat_broadcast) != 0;
    if (!broadcast && !g_Player[id][pChatStatsEnabled])
        return;

    new typeName[64], playerName[32];
    Hms_GetJumpTypeName(id, typeName, charsmax(typeName));
    get_user_name(id, playerName, charsmax(playerName));

    new maxPlayers = get_maxplayers();
    new bool:detailed = get_pcvar_num(pcvar_show_landing) != 0;
    new Float:gain = g_Player[id][pCompletedMaxSpeed] - g_Player[id][pCompletedPreSpeed];
    new strafes = Hms_GetJumpStrafeCount(id);

    for (new recipient = 1; recipient <= maxPlayers; recipient++)
    {
        if (!is_user_connected(recipient) || is_user_bot(recipient) || is_user_hltv(recipient))
            continue;
        if (broadcast)
        {
            if (!g_Player[recipient][pChatStatsEnabled])
                continue;
        }
        else if (recipient != id)
        {
            continue;
        }

        if (broadcast)
        {
            client_print_color(recipient, print_team_default,
                "^4[HNS]^1 %s ^3%s:^1 ^3%.2f units^1 | Pre: %.2f | Maxspeed: %.2f | Gain: %.2f | Land: %.2f",
                playerName, typeName, g_Player[id][pLastJumpDistance], g_Player[id][pCompletedPreSpeed],
                g_Player[id][pCompletedMaxSpeed], gain, g_Player[id][pLastLandingSpeed]);
        }
        else
        {
            client_print_color(recipient, print_team_default,
                "^4[HNS]^1 ^3%s:^1 ^3%.2f units^1 | Pre: %.2f | Maxspeed: %.2f | Gain: %.2f | Land: %.2f",
                typeName, g_Player[id][pLastJumpDistance], g_Player[id][pCompletedPreSpeed],
                g_Player[id][pCompletedMaxSpeed], gain, g_Player[id][pLastLandingSpeed]);
        }

        if (detailed)
        {
            client_print_color(recipient, print_team_default,
                "^4[HNS]^1 Strafes~ %d | Sync~ %.0f%% | FOG: %df | Ducks: %d | Air: %.2fs | Pre-land -> Land: %.2f -> %.2f",
                strafes, Hms_GetSyncPercent(id), g_Player[id][pCompletedFogFrames],
                g_Player[id][pCompletedDuckCount], g_Player[id][pLastAirTime],
                g_Player[id][pLastPreGroundSpeed], g_Player[id][pLastPostGroundSpeed]);
        }
    }
}

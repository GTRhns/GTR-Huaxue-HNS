// Frame-sampled turning diagnostics. Gain/loss and sync remain approximate, not UQ-equivalent.
stock Hms_SampleStrafe(id, buttons, const Float:angles[3])
{
    new oldButtons = g_Player[id][pLastButtons];

    if (!g_Player[id][pInAir])
    {
        g_Player[id][pLastButtons] = buttons;
        g_Player[id][pHasYawSample] = false;
        g_Player[id][pHasAirSpeedSample] = false;
        return;
    }

    new bool:left = (buttons & IN_MOVELEFT) != 0;
    new bool:right = (buttons & IN_MOVERIGHT) != 0;
    new bool:turnInput = (left != right);

    new Float:yawDelta = 0.0;
    if (g_Player[id][pHasYawSample])
    {
        yawDelta = angles[1] - g_Player[id][pLastYaw];
        if (yawDelta > 180.0) yawDelta -= 360.0;
        else if (yawDelta < -180.0) yawDelta += 360.0;
    }

    if (turnInput)
    {
        g_Player[id][pStrafeSamples]++;
        g_Player[id][pSessionStrafeSamples]++;

        if ((left && (oldButtons & IN_MOVERIGHT)) || (right && (oldButtons & IN_MOVELEFT)))
        {
            g_Player[id][pAirTurnCount]++;
            g_Player[id][pSessionAirTurnCount]++;
        }

        if (g_Player[id][pHasAirSpeedSample])
        {
            new Float:delta = g_Player[id][pCurrentSpeed] - g_Player[id][pLastAirSpeed];
            if (delta > 0.0)
                g_Player[id][pJumpStrafeGain] += delta;
            else if (delta < 0.0)
                g_Player[id][pJumpStrafeLoss] += -delta;
        }

        // Directional yaw alignment is a rough proxy; dedicated JumpStats use more exact movement math.
        if ((left && yawDelta < -0.1) || (right && yawDelta > 0.1))
        {
            g_Player[id][pStrafeGood]++;
            g_Player[id][pSessionStrafeGood]++;
        }
    }

    g_Player[id][pLastAirSpeed] = g_Player[id][pCurrentSpeed];
    g_Player[id][pHasAirSpeedSample] = true;
    g_Player[id][pLastYaw] = angles[1];
    g_Player[id][pHasYawSample] = true;
    g_Player[id][pLastButtons] = buttons;
}

stock Float:Hms_GetSyncPercent(id)
{
    if (g_Player[id][pCompletedStrafeSamples] <= 0)
        return 0.0;
    return float(g_Player[id][pCompletedStrafeGood]) * 100.0 / float(g_Player[id][pCompletedStrafeSamples]);
}

stock Hms_GetJumpStrafeCount(id)
{
    if (g_Player[id][pCompletedStrafeSamples] <= 0)
        return 0;
    // Count one active strafe plus each detected left/right reversal. This is a display estimate.
    return g_Player[id][pCompletedTurnCount] + 1;
}

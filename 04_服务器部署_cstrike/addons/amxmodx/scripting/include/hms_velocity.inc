// Horizontal velocity is sampled once in PlayerPreThink and shared with jump/strafe/distance modules.
stock Hms_SampleVelocity(id, flags, Float:speed)
{
    g_Player[id][pCurrentSpeed] = speed;

    // UQ-style Pre is the final sampled horizontal speed while still grounded.
    if (flags & FL_ONGROUND)
        g_Player[id][pLastGroundedSpeed] = speed;

    if (speed > g_Player[id][pSessionMaxSpeed])
        g_Player[id][pSessionMaxSpeed] = speed;

    new bool:currentlyAirborne = (flags & FL_ONGROUND) == 0;
    // Exclude touchdown speed from the jump's airborne Max measurement.
    if (g_Player[id][pInAir] && currentlyAirborne && speed > g_Player[id][pJumpMaxSpeed])
        g_Player[id][pJumpMaxSpeed] = speed;

    new Float:threshold = get_pcvar_float(pcvar_low_speed);
    new Float:drop = get_pcvar_float(pcvar_low_drop);
    new Float:lastSpeed = g_Player[id][pPreviousSpeed];

    // Avoid counting the landing impact as an in-air speed-drop event.
    if (g_Player[id][pInAir] && currentlyAirborne && threshold > 0.0 && drop > 0.0 &&
        lastSpeed >= threshold && speed <= lastSpeed - drop)
    {
        g_Player[id][pLowSpeedEvents]++;
        Hms_NotifyLowSpeed(id, lastSpeed, speed);
    }

    g_Player[id][pPreviousSpeed] = speed;
}

// Track total horizontal movement using the shared origin sample, excluding large discontinuities.
stock Hms_SampleDistance(id, const Float:origin[3])
{
    if (g_Player[id][pHasOriginSample])
    {
        new Float:dx = origin[0] - g_Player[id][pLastOrigin][0];
        new Float:dy = origin[1] - g_Player[id][pLastOrigin][1];
        new Float:stepDistance = floatsqroot(dx * dx + dy * dy);

        if (stepDistance <= 128.0)
            g_Player[id][pDistance] += stepDistance;
    }

    g_Player[id][pLastOrigin][0] = origin[0];
    g_Player[id][pLastOrigin][1] = origin[1];
    g_Player[id][pLastOrigin][2] = origin[2];
    g_Player[id][pHasOriginSample] = true;
}

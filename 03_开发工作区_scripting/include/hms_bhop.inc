// A frame-sampled approximation. Exact FOG values may depend on server frame timing.
stock Hms_UpdateBhopChain(id)
{
    // Walking off an edge is a DROP, not a successful bhop-chain link.
    if (g_Player[id][pLastJumpWasDrop])
    {
        g_Player[id][pBhopChain] = 0;
        return;
    }

    if (!g_Player[id][pHasLandedBefore])
    {
        g_Player[id][pBhopChain] = 0;
        return;
    }

    new maxFog = get_pcvar_num(pcvar_bhop_fog_frames);
    if (maxFog < 0) maxFog = 0;

    if (g_Player[id][pLastFogFrames] <= maxFog)
    {
        if (g_Player[id][pBhopChain] < 1)
            g_Player[id][pBhopChain] = 1;
        else
            g_Player[id][pBhopChain]++;
    }
    else
    {
        g_Player[id][pBhopChain] = 0;
    }

    if (g_Player[id][pBhopChain] > g_Player[id][pSessionMaxBhopChain])
        g_Player[id][pSessionMaxBhopChain] = g_Player[id][pBhopChain];
}

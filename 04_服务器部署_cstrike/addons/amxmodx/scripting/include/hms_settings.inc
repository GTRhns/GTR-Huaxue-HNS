// Per-player defaults. Layout is panel-based while metric visibility is still independent.
stock Hms_SettingsDefaults(id)
{
    g_Player[id][pHudEnabled] = true;
    g_Player[id][pSoundsEnabled] = false;
    g_Player[id][pTakeoffSound] = false;
    g_Player[id][pLandingSound] = false;
    g_Player[id][pAchievementSound] = false;
    g_Player[id][pChatStatsEnabled] = false;
    g_Player[id][pSpeedHud] = false;
    g_Player[id][pSpeedBig] = false;
    g_Player[id][pFogPopup] = true;
    g_Player[id][pShowPre] = true;
    g_HmsHudRev2[id] = false;
    g_HmsKeepCenter[id] = false;

    for (new field = 0; field < HMS_HUD_COUNT; field++)
    {
        g_HudFieldEnabled[id][field] = false;
        g_HudFieldX[id][field] = 2;
        g_HudFieldY[id][field] = 10 + (field * 4); // legacy DB columns retained for upgrades
        g_HudFieldColor[id][field] = field % HMS_COLOR_COUNT;
    }
    g_HudFieldEnabled[id][HMS_HUD_SPEED] = true;
    g_HudFieldEnabled[id][HMS_HUD_LASTJUMP] = false;
    g_HudFieldEnabled[id][HMS_HUD_SYNC] = false;
    g_HudFieldEnabled[id][HMS_HUD_FOG] = true;
    g_HudFieldEnabled[id][HMS_HUD_PRESPEED] = true;

    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
        Hms_ResetPanelLayout(id, panel);

    // Join default is KZ center (中屏). A saved style_pick keeps Classic or Number.
    Hms_ApplyKzCenterHud(id);

    // Kept only as cleanup for a hot reload from older builds; beta4 uses one global scheduler.
    remove_task(HMS_TASK_HUD + id);
    Hms_ClearPlayerHud(id);
    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
        g_NextHudUpdate[id][panel] = 0.0;
}

// dirtyMask is a bitmask of HMS_DIRTY_PREFS / HMS_DIRTY_FIELDS / HMS_DIRTY_PANELS.
// Touched bits remain set for the session to prevent later SQL callbacks overwriting local edits.
stock Hms_QueuePrefsSave(id, dirtyMask)
{
    if (id < 1 || id > HMS_MAX_PLAYERS || !is_user_connected(id))
        return;

    g_SettingsTouchedMask[id] |= dirtyMask;
    g_SettingsDirtyMask[id] |= dirtyMask;

    if (!g_SqlEnabled || !g_AuthId[id][0])
        return; // Keep dirty bits so they can be flushed if SQL is enabled later.

    remove_task(HMS_TASK_PREFS + id);
    set_task(0.75, "Hms_SavePreferencesTask", HMS_TASK_PREFS + id);
}

// Original short cues shipped with this package. Files live under cstrike/sound/hms/.
public plugin_precache()
{
    precache_sound("hms/takeoff.wav");
    precache_sound("hms/landing.wav");
    precache_sound("hms/achievement.wav");
}

stock Hms_PlayTakeoffFeedback(id)
{
    if (g_Player[id][pSoundsEnabled] && g_Player[id][pTakeoffSound] && get_pcvar_num(pcvar_sound_takeoff))
        client_cmd(id, "spk hms/takeoff.wav");
}

stock Hms_PlayLandingFeedback(id, Float:distance)
{
    if (!g_Player[id][pSoundsEnabled])
        return;

    new Float:threshold = get_pcvar_float(pcvar_sound_distance);
    if (g_Player[id][pAchievementSound] && get_pcvar_num(pcvar_sound_achievement) && threshold >= 0.0 && distance >= threshold)
    {
        client_cmd(id, "spk hms/achievement.wav");
    }
    else if (g_Player[id][pLandingSound] && get_pcvar_num(pcvar_sound_landing))
    {
        client_cmd(id, "spk hms/landing.wav");
    }
}

stock Hms_PlayTestSound(id, cue)
{
    switch (cue)
    {
        case 0: client_cmd(id, "spk hms/takeoff.wav");
        case 1: client_cmd(id, "spk hms/landing.wav");
        case 2: client_cmd(id, "spk hms/achievement.wav");
    }
}

stock Hms_GetLandingContext(id, output[], maxlen)
{
    if (pev(id, pev_waterlevel) >= 2)
    {
        copy(output, maxlen, "WATER");
        return;
    }

    new groundEnt = pev(id, pev_groundentity);
    if (groundEnt <= 0)
    {
        copy(output, maxlen, "WORLD");
        return;
    }

    if (pev_valid(groundEnt))
    {
        new classname[32];
        pev(groundEnt, pev_classname, classname, charsmax(classname));
        if (classname[0])
        {
            copy(output, maxlen, classname);
            return;
        }
    }

    copy(output, maxlen, "ENTITY");
}

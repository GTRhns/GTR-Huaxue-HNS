// Pull one string from the HNS language plugin. Missing keys keep the English fallback.
stock Hms_L(id, const key[], output[], len, const fallback[])
{
    output[0] = 0;
    HnsLang_Get(id, key, output, len);
    if (!output[0])
        copy(output, len, fallback);
    replace_all(output, len, "^^n", "^n");
    replace_all(output, len, "^^1", "^1");
    replace_all(output, len, "^^3", "^3");
    replace_all(output, len, "^^4", "^4");
}

stock Hms_LF(id, const key[], const fallback[], output[], len, any:...)
{
    new fmt[192];
    Hms_L(id, key, fmt, charsmax(fmt), fallback);
    vformat(output, len, fmt, 6);
}

stock Hms_OnOff(id, on, output[], len)
{
    if (on) Hms_L(id, "HMS_ON", output, len, "ON");
    else Hms_L(id, "HMS_OFF", output, len, "OFF");
}

stock Hms_FieldName(id, field, output[], len)
{
    new key[16];
    formatex(key, charsmax(key), "HMS_FIELD_%d", field);
    Hms_L(id, key, output, len, g_HudFieldNames[field]);
}

stock Hms_PanelName(id, panel, output[], len)
{
    new key[16];
    formatex(key, charsmax(key), "HMS_PANEL_%d", panel);
    Hms_L(id, key, output, len, g_HudPanelNames[panel]);
}

stock Hms_ColorName(id, color, output[], len)
{
    new key[16];
    formatex(key, charsmax(key), "HMS_COLOR_%d", color);
    Hms_L(id, key, output, len, g_ColorNames[color]);
}
// CS-style keys: 1-7 items, 8 previous, 9 next or back, 0 exit.
#define HMS_NAV_PERPAGE 7
#define HMS_NAV_NONE 0
#define HMS_NAV_EXIT 1
#define HMS_NAV_BACK 2
#define HMS_NAV_PREV 3
#define HMS_NAV_NEXT 4
#define HMS_NAV_PAD 5

stock Hms_StyleMenu(id, menu)
{
    new exitName[32];
    Hms_L(id, "HMS_EXIT", exitName, charsmax(exitName), "Exit");
    menu_setprop(menu, MPROP_PERPAGE, 0);
    menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE);
    menu_setprop(menu, MPROP_EXITNAME, exitName);
    menu_setprop(menu, MPROP_SHOWPAGE, false);
    menu_setprop(menu, MPROP_NUMBER_COLOR, "\r");
}

stock Hms_MenuGap(menu)
{
    menu_addblank(menu, 0);
}

stock Hms_PageCount(total)
{
    if (total < 1) return 1;
    return (total + HMS_NAV_PERPAGE - 1) / HMS_NAV_PERPAGE;
}

stock bool:Hms_OnPage(index, page)
{
    return (index / HMS_NAV_PERPAGE) == page;
}

stock Hms_ClampPage(id, total)
{
    new pages = Hms_PageCount(total);
    new page = g_HmsMenuPage[id];
    if (page < 0) page = 0;
    if (page >= pages) page = pages - 1;
    g_HmsMenuPage[id] = page;
    return page;
}

stock Hms_AddNav(id, menu, added, total, bool:hasParent)
{
    new page = Hms_ClampPage(id, total);
    new pages = Hms_PageCount(total);
    while (added < HMS_NAV_PERPAGE)
    {
        menu_addblank2(menu);
        added++;
    }

    new vitem[32];
    if (page > 0)
    {
        Hms_L(id, "HMS_PREV", vitem, charsmax(vitem), "Previous");
        menu_additem(menu, vitem, "hms_prev");
    }
    else
        menu_addblank2(menu);

    if (page + 1 < pages)
    {
        Hms_L(id, "HMS_NEXT", vitem, charsmax(vitem), "Next");
        menu_additem(menu, vitem, "hms_next");
    }
    else if (hasParent)
    {
        Hms_L(id, "HMS_BACK", vitem, charsmax(vitem), "Back");
        menu_additem(menu, vitem, "hms_back");
    }
    else
        menu_addblank2(menu);
}

stock Hms_ReadNav(menu, item, vinfo[], vinfoLen)
{
    if (item < 0)
    {
        menu_destroy(menu);
        vinfo[0] = 0;
        return HMS_NAV_EXIT;
    }
    new access;
    new callback;
    menu_item_getinfo(menu, item, access, vinfo, vinfoLen, _, _, callback);
    menu_destroy(menu);
    if (equal(vinfo, "hms_back")) return HMS_NAV_BACK;
    if (equal(vinfo, "hms_prev")) return HMS_NAV_PREV;
    if (equal(vinfo, "hms_next")) return HMS_NAV_NEXT;
    if (!vinfo[0]) return HMS_NAV_PAD;
    return HMS_NAV_NONE;
}

stock bool:Hms_IsAdmin(id)
{
    return (get_user_flags(id) & ADMIN_CFG) != 0;
}

public HmsCmdMainMenu(id)
{
    return Hms_ShowMainMenu(id, 0);
}

stock Hms_ShowMainMenu(id, page)
{
    g_HmsMenuPage[id] = page;
    new vtitle[96];
    Hms_L(id, "HMS_MAIN_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Movement Suite^n\yPLAYER CONTROL / LIVE HUD");
    new menu = menu_create(vtitle, "Hms_MainMenuHandler");
    Hms_StyleMenu(id, menu);
    new vitem[96];
    new bool:isAdmin = Hms_IsAdmin(id);
    new total = isAdmin ? 8 : 7;
    page = Hms_ClampPage(id, total);
    new added = 0;
    if (Hms_OnPage(0, page)) { Hms_L(id, "HMS_MAIN_HUD", vitem, charsmax(vitem), "\wHUD & metric visibility"); menu_additem(menu, vitem, "hud"); added++; }
    if (Hms_OnPage(1, page)) { Hms_L(id, "HMS_MAIN_KZ", vitem, charsmax(vitem), "\wSpeed display settings"); menu_additem(menu, vitem, "kz"); added++; }
    if (Hms_OnPage(2, page)) { Hms_L(id, "HMS_MAIN_LAYOUT", vitem, charsmax(vitem), "\wPanel layout & position"); menu_additem(menu, vitem, "layout"); added++; }
    if (Hms_OnPage(3, page)) { Hms_L(id, "HMS_MAIN_THEMES", vitem, charsmax(vitem), "\wColor themes"); menu_additem(menu, vitem, "themes"); added++; }
    if (Hms_OnPage(4, page)) { Hms_L(id, "HMS_MAIN_STATS", vitem, charsmax(vitem), "\wJump / strafe options"); menu_additem(menu, vitem, "stats"); added++; }
    if (Hms_OnPage(5, page)) { Hms_L(id, "HMS_MAIN_SOUND", vitem, charsmax(vitem), "\wSound laboratory"); menu_additem(menu, vitem, "sounds"); added++; }
    if (Hms_OnPage(6, page)) { Hms_L(id, "HMS_MAIN_STATUS", vitem, charsmax(vitem), "\wMap & HNS live status"); menu_additem(menu, vitem, "status"); added++; }
    if (isAdmin && Hms_OnPage(7, page))
    {
        Hms_L(id, "HMS_MAIN_ADMIN", vitem, charsmax(vitem), "\rAdministrator control center");
        menu_additem(menu, vitem, "admin");
        added++;
    }
    Hms_AddNav(id, menu, added, total, false);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_MainMenuHandler(id, menu, item)
{
    new vinfo[32];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_PREV) return Hms_ShowMainMenu(id, g_HmsMenuPage[id] - 1);
    if (nav == HMS_NAV_NEXT) return Hms_ShowMainMenu(id, g_HmsMenuPage[id] + 1);
    if (equal(vinfo, "hud")) HmsCmdHudMenu(id);
    else if (equal(vinfo, "kz")) HmsCmdKzMenu(id);
    else if (equal(vinfo, "layout")) HmsCmdLayoutMenu(id);
    else if (equal(vinfo, "themes")) HmsCmdThemeMenu(id);
    else if (equal(vinfo, "stats")) HmsCmdStatsMenu(id);
    else if (equal(vinfo, "sounds")) HmsCmdSoundMenu(id);
    else if (equal(vinfo, "status")) HmsCmdStatus(id);
    else if (equal(vinfo, "admin")) HmsCmdAdminMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdKzMenu(id)
{
    return Hms_ShowKzMenu(id, 0);
}

stock Hms_ShowKzMenu(id, page)
{
    g_HmsMenuPage[id] = page;
    new vtitle[96];
    Hms_L(id, "HMS_KZ_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Speed display settings^n\yLIVE DISPLAY");
    new menu = menu_create(vtitle, "Hms_KzMenuHandler");
    Hms_StyleMenu(id, menu);
    new hmsItem[96];
    new hmsState[24];
    new hmsStyleName[24];
    new style = g_Player[id][pHudStyle];
    new bool:compact = (style == 1 || style == 2);
    new total = compact ? 3 : 8;
    page = Hms_ClampPage(id, total);
    new added = 0;
    if (style == 1)
        Hms_L(id, "HMS_STYLE_FENCE", hmsStyleName, charsmax(hmsStyleName), "KZ Center");
    else if (style == 2)
        Hms_L(id, "HMS_STYLE_NUM", hmsStyleName, charsmax(hmsStyleName), "Number");
    else
        Hms_L(id, "HMS_STYLE_CLASSIC", hmsStyleName, charsmax(hmsStyleName), "Classic");
    if (Hms_OnPage(0, page))
    {
        Hms_LF(id, "HMS_KZ_STYLE", "Display style: \y%s", hmsItem, charsmax(hmsItem), hmsStyleName);
        menu_additem(menu, hmsItem, "style");
        added++;
    }
    if (style == 1)
    {
        if (Hms_OnPage(1, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_SPEED], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_BOTTOM", "Bottom speed: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "speed");
            added++;
        }
        if (Hms_OnPage(2, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_FOG], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_CENTER", "Center KZ HUD: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "fog");
            added++;
        }
    }
    else if (style == 2)
    {
        if (Hms_OnPage(1, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_SPEED], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_SPEED", "Speed number: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "speed");
            added++;
        }
        if (Hms_OnPage(2, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_FOG], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_PREFOG", "Prefog: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "fog");
            added++;
        }
    }
    else
    {
        if (Hms_OnPage(1, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_SPEED], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_SPEED", "Speed number: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "speed");
            added++;
        }
        if (Hms_OnPage(2, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_MAXSPEED], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_MAX", "Session max speed: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "max");
            added++;
        }
        if (Hms_OnPage(3, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_FOG], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_FOG", "Live FOG row: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "fog");
            added++;
        }
        if (Hms_OnPage(4, page))
        {
            Hms_OnOff(id, g_Player[id][pShowPre], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_PRE", "Air / ground speed: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "pre");
            added++;
        }
        if (Hms_OnPage(5, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_LASTJUMP], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_JUMP", "Last jump on the row: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "jump");
            added++;
        }
        if (Hms_OnPage(6, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_SYNC], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_SYNC", "Turn sync on the row: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "sync");
            added++;
        }
        if (Hms_OnPage(7, page))
        {
            Hms_OnOff(id, g_HudFieldEnabled[id][HMS_HUD_STRAFE], hmsState, charsmax(hmsState));
            Hms_LF(id, "HMS_KZ_STRAFE", "Strafe gain / loss: \y%s", hmsItem, charsmax(hmsItem), hmsState);
            menu_additem(menu, hmsItem, "strafe");
            added++;
        }
    }
    Hms_AddNav(id, menu, added, total, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_KzMenuHandler(id, menu, item)
{
    new vinfo[16];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    if (nav == HMS_NAV_PREV) return Hms_ShowKzMenu(id, g_HmsMenuPage[id] - 1);
    if (nav == HMS_NAV_NEXT) return Hms_ShowKzMenu(id, g_HmsMenuPage[id] + 1);
    if (equal(vinfo, "style")) Hms_ToggleHudStyle(id);
    else if (equal(vinfo, "speed")) Hms_ToggleHudField(id, HMS_HUD_SPEED);
    else if (equal(vinfo, "max")) Hms_ToggleHudField(id, HMS_HUD_MAXSPEED);
    else if (equal(vinfo, "fog")) Hms_ToggleHudField(id, HMS_HUD_FOG);
    else if (equal(vinfo, "pre")) HmsCmdShowPre(id);
    else if (equal(vinfo, "jump")) Hms_ToggleHudField(id, HMS_HUD_LASTJUMP);
    else if (equal(vinfo, "sync")) Hms_ToggleHudField(id, HMS_HUD_SYNC);
    else if (equal(vinfo, "strafe")) Hms_ToggleHudField(id, HMS_HUD_STRAFE);
    return Hms_ShowKzMenu(id, g_HmsMenuPage[id]);
}

stock Hms_ToggleHudStyle(id)
{
    new styleLabel[24];
    new styleLine[96];
    if (g_Player[id][pHudStyle] == 0)
    {
        Hms_ApplyKzCenterHud(id);
        Hms_L(id, "HMS_STYLE_FENCE", styleLabel, charsmax(styleLabel), "KZ Center");
    }
    else if (g_Player[id][pHudStyle] == 1)
    {
        Hms_ApplyPrefogNumHud(id);
        Hms_L(id, "HMS_STYLE_NUM", styleLabel, charsmax(styleLabel), "Number");
    }
    else
    {
        g_Player[id][pHudStyle] = 0;
        g_HudPanelEnabled[id][HMS_PANEL_SPEED] = true;
        g_HudPanelEnabled[id][HMS_PANEL_JUMP] = true;
        g_HudPanelX[id][HMS_PANEL_SPEED] = -1;
        g_HudPanelY[id][HMS_PANEL_SPEED] = 90;
        g_HudPanelX[id][HMS_PANEL_JUMP] = -1;
        g_HudPanelY[id][HMS_PANEL_JUMP] = 82;
        Hms_L(id, "HMS_STYLE_CLASSIC", styleLabel, charsmax(styleLabel), "Classic");
    }
    Hms_LF(id, "HMS_KZ_STYLE", "Display style: %s", styleLine, charsmax(styleLine), styleLabel);
    replace_all(styleLine, charsmax(styleLine), "\y", "");
    client_print_color(id, print_team_default, "^4[HNS]^1 %s", styleLine);
    Hms_QueuePrefsSave(id, HMS_DIRTY_PREFS | HMS_DIRTY_FIELDS | HMS_DIRTY_PANELS);
}

stock Hms_ToggleHudField(id, field)
{
    if (field < 0 || field >= HMS_HUD_COUNT)
        return;
    g_HudFieldEnabled[id][field] = !g_HudFieldEnabled[id][field];
    new fieldLabel[48];
    new fieldState[24];
    new fieldLine[128];
    Hms_FieldName(id, field, fieldLabel, charsmax(fieldLabel));
    if (g_HudFieldEnabled[id][field]) Hms_L(id, "HMS_CHAT_ON", fieldState, charsmax(fieldState), "^3ON");
    else Hms_L(id, "HMS_CHAT_OFF", fieldState, charsmax(fieldState), "^1OFF");
    Hms_LF(id, "HMS_CHAT_SET", "^4[HNS]^1 %s: %s", fieldLine, charsmax(fieldLine), fieldLabel, fieldState);
    client_print_color(id, print_team_default, "%s", fieldLine);
    Hms_QueuePrefsSave(id, HMS_DIRTY_FIELDS);
}

public HmsCmdHudMenu(id)
{
    Hms_ShowHudMenu(id, 0);
    return PLUGIN_HANDLED;
}

stock Hms_ShowHudMenu(id, page)
{
    g_HmsMenuPage[id] = page;
    new vtitle[96];
    Hms_L(id, "HMS_HUD_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Metric Visibility");
    new menu = menu_create(vtitle, "Hms_HudMenuHandler");
    Hms_StyleMenu(id, menu);
    new vitem[128];
    new vinfo[16];
    new vstate[32];
    new vname[48];
    new total = 2 + HMS_HUD_COUNT;
    page = Hms_ClampPage(id, total);
    new added = 0;
    if (Hms_OnPage(0, page))
    {
        if (g_Player[id][pHudEnabled]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
        else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
        Hms_LF(id, "HMS_HUD_MASTER", "Master HUD: %s", vitem, charsmax(vitem), vstate);
        menu_additem(menu, vitem, "master");
        added++;
    }
    if (Hms_OnPage(1, page))
    {
        if (Hms_AllFieldsEnabled(id)) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
        else Hms_L(id, "HMS_HUD_MIXED", vstate, charsmax(vstate), "\rMIXED/OFF\w");
        Hms_LF(id, "HMS_HUD_ALL", "All movement metrics: %s", vitem, charsmax(vitem), vstate);
        menu_additem(menu, vitem, "all");
        added++;
    }
    for (new field = 0; field < HMS_HUD_COUNT; field++)
    {
        if (!Hms_OnPage(2 + field, page)) continue;
        Hms_FieldName(id, field, vname, charsmax(vname));
        if (g_HudFieldEnabled[id][field]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\r[ON]\w");
        else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\d[OFF]\w");
        Hms_LF(id, "HMS_HUD_FIELD", "%s  %s", vitem, charsmax(vitem), vname, vstate);
        num_to_str(field, vinfo, charsmax(vinfo));
        menu_additem(menu, vitem, vinfo);
        added++;
    }
    Hms_AddNav(id, menu, added, total, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

stock bool:Hms_AllFieldsEnabled(id)
{
    for (new field = 0; field < HMS_HUD_COUNT; field++)
        if (!g_HudFieldEnabled[id][field]) return false;
    return true;
}

public Hms_HudMenuHandler(id, menu, item)
{
    new vinfo[16];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    if (nav == HMS_NAV_PREV) return Hms_ShowHudMenu(id, g_HmsMenuPage[id] - 1);
    if (nav == HMS_NAV_NEXT) return Hms_ShowHudMenu(id, g_HmsMenuPage[id] + 1);

    new dirtyMask = HMS_DIRTY_PREFS;
    if (equal(vinfo, "master"))
    {
        g_Player[id][pHudEnabled] = !g_Player[id][pHudEnabled];
        if (!g_Player[id][pHudEnabled]) Hms_ClearPlayerHud(id);
        new vstate[24];
        new vline[128];
        if (g_Player[id][pHudEnabled]) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
        else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
        Hms_LF(id, "HMS_CHAT_HUD", "^4[HNS]^1 HUD display: %s", vline, charsmax(vline), vstate);
        client_print_color(id, print_team_default, "%s", vline);
    }
    else if (equal(vinfo, "all"))
    {
        dirtyMask = HMS_DIRTY_FIELDS;
        new bool:enable = !Hms_AllFieldsEnabled(id);
        for (new field = 0; field < HMS_HUD_COUNT; field++) g_HudFieldEnabled[id][field] = enable;
        new vstate[24];
        new vline[128];
        if (enable) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
        else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
        Hms_LF(id, "HMS_CHAT_ALL", "^4[HNS]^1 All movement metrics: %s", vline, charsmax(vline), vstate);
        client_print_color(id, print_team_default, "%s", vline);
    }
    else
    {
        dirtyMask = HMS_DIRTY_FIELDS;
        new field = str_to_num(vinfo);
        if (field >= 0 && field < HMS_HUD_COUNT)
        {
            g_HudFieldEnabled[id][field] = !g_HudFieldEnabled[id][field];
            new vname[48];
            new vstate[24];
            new vline[128];
            Hms_FieldName(id, field, vname, charsmax(vname));
            if (g_HudFieldEnabled[id][field]) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
            else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
            Hms_LF(id, "HMS_CHAT_SET", "^4[HNS]^1 %s: %s", vline, charsmax(vline), vname, vstate);
            client_print_color(id, print_team_default, "%s", vline);
        }
    }
    Hms_QueuePrefsSave(id, dirtyMask);
    return Hms_ShowHudMenu(id, g_HmsMenuPage[id]);
}

public HmsCmdStatsMenu(id)
{
    new vtitle[96];
    Hms_L(id, "HMS_STATS_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Jump & Strafe Options");
    new menu = menu_create(vtitle, "Hms_StatsMenuHandler");
    Hms_StyleMenu(id, menu);
    new vitem[128];
    new vstate[32];
    if (g_Player[id][pChatStatsEnabled]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_STATS_CHAT", "Green [HNS] jump chat: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "chat");
    if (g_HudPanelEnabled[id][HMS_PANEL_STATUS]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_STATS_STATUS", "Status panel: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "status");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_STATS_FIELDS", vitem, charsmax(vitem), "\wConfigure individual metric fields");
    menu_additem(menu, vitem, "fields");
    Hms_L(id, "HMS_STATS_LAYOUT", vitem, charsmax(vitem), "\wOpen panel positions / colors");
    menu_additem(menu, vitem, "layout");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_STATS_REPORT", vitem, charsmax(vitem), "\wView detailed session report");
    menu_additem(menu, vitem, "stats");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_STATS_RESET", vitem, charsmax(vitem), "\rReset personal preferences");
    menu_additem(menu, vitem, "resetprefs");
    Hms_AddNav(id, menu, 6, 6, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_StatsMenuHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    new dirtyMask = HMS_DIRTY_PREFS;
    if (equal(vinfo, "chat"))
    {
        g_Player[id][pChatStatsEnabled] = !g_Player[id][pChatStatsEnabled];
        new vstate[24];
        new vline[128];
        if (g_Player[id][pChatStatsEnabled]) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
        else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
        Hms_LF(id, "HMS_CHAT_JUMPCHAT", "^4[HNS]^1 Personal jump-result chat: %s", vline, charsmax(vline), vstate);
        client_print_color(id, print_team_default, "%s", vline);
    }
    else if (equal(vinfo, "status"))
    {
        dirtyMask = HMS_DIRTY_PANELS;
        g_HudPanelEnabled[id][HMS_PANEL_STATUS] = !g_HudPanelEnabled[id][HMS_PANEL_STATUS];
        new vstate[24];
        new vline[128];
        if (g_HudPanelEnabled[id][HMS_PANEL_STATUS]) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
        else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
        Hms_LF(id, "HMS_CHAT_STATUS", "^4[HNS]^1 Server status panel: %s", vline, charsmax(vline), vstate);
        client_print_color(id, print_team_default, "%s", vline);
    }
    else if (equal(vinfo, "fields")) { HmsCmdHudMenu(id); return PLUGIN_HANDLED; }
    else if (equal(vinfo, "layout")) { HmsCmdLayoutMenu(id); return PLUGIN_HANDLED; }
    else if (equal(vinfo, "stats")) { HmsCmdStats(id); HmsCmdStatsMenu(id); return PLUGIN_HANDLED; }
    else if (equal(vinfo, "resetprefs")) { HmsCmdResetPreferencesConfirm(id); return PLUGIN_HANDLED; }
    Hms_QueuePrefsSave(id, dirtyMask);
    HmsCmdStatsMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdLayoutMenu(id)
{
    new vtitle[96];
    Hms_L(id, "HMS_LAYOUT_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Panel Layout^n\yPOSITION / SPACING / COLOR");
    new menu = menu_create(vtitle, "Hms_LayoutMenuHandler");
    Hms_StyleMenu(id, menu);
    new vitem[128];
    new vinfo[8];
    new vname[32];
    new vstate[16];
    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
    {
        Hms_PanelName(id, panel, vname, charsmax(vname));
        Hms_OnOff(id, g_HudPanelEnabled[id][panel], vstate, charsmax(vstate));
        Hms_LF(id, "HMS_LAYOUT_ROW", "%s  %s  \dX %d  Y %d", vitem, charsmax(vitem), vname, vstate, g_HudPanelX[id][panel], g_HudPanelY[id][panel]);
        num_to_str(panel, vinfo, charsmax(vinfo));
        menu_additem(menu, vitem, vinfo);
        if (panel == 1) Hms_MenuGap(menu);
    }
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_LAYOUT_PRESET", vitem, charsmax(vitem), "\wApply layout preset");
    menu_additem(menu, vitem, "preset");
    Hms_L(id, "HMS_LAYOUT_RESET", vitem, charsmax(vitem), "\wRestore all panel layouts");
    menu_additem(menu, vitem, "resetall");
    Hms_AddNav(id, menu, 5, 5, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_LayoutMenuHandler(id, menu, item)
{
    new vinfo[16];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    if (equal(vinfo, "preset")) { HmsCmdPresetMenu(id); return PLUGIN_HANDLED; }
    if (equal(vinfo, "resetall"))
    {
        Hms_ApplyHudPreset(id, 0);
        for (new p = 0; p < HMS_PANEL_COUNT; p++) Hms_ResetPanelLayout(id, p);
        Hms_QueuePrefsSave(id, HMS_DIRTY_PANELS);
        HmsCmdLayoutMenu(id);
        return PLUGIN_HANDLED;
    }
    new panel = str_to_num(vinfo);
    if (panel >= 0 && panel < HMS_PANEL_COUNT)
    {
        g_SelectedHudPanel[id] = panel;
        HmsCmdPanelEditor(id);
    }
    return PLUGIN_HANDLED;
}

public HmsCmdPanelEditor(id)
{
    new panel = g_SelectedHudPanel[id];
    if (panel < 0 || panel >= HMS_PANEL_COUNT) { HmsCmdLayoutMenu(id); return PLUGIN_HANDLED; }
    new vtitle[128];
    new vitem[128];
    new vname[32];
    new vstate[32];
    new vcolorName[32];
    Hms_PanelName(id, panel, vname, charsmax(vname));
    Hms_LF(id, "HMS_PANEL_TITLE", "\rHMS \w| %s", vtitle, charsmax(vtitle), vname);
    new menu = menu_create(vtitle, "Hms_PanelEditorHandler");
    Hms_StyleMenu(id, menu);
    if (g_HudPanelEnabled[id][panel]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_PANEL_VIS", "Panel visibility: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "toggle");
    Hms_ColorName(id, g_HudPanelColor[id][panel], vcolorName, charsmax(vcolorName));
    Hms_LF(id, "HMS_PANEL_COLOR", "Color: %s  (choose)", vitem, charsmax(vitem), vcolorName);
    menu_additem(menu, vitem, "color");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_PANEL_POS", vitem, charsmax(vitem), "\wPosition & fine spacing");
    menu_additem(menu, vitem, "position");
    Hms_L(id, "HMS_PANEL_RESET", vitem, charsmax(vitem), "\wReset this panel");
    menu_additem(menu, vitem, "reset");
    Hms_AddNav(id, menu, 4, 4, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_PanelEditorHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdLayoutMenu(id);
    new panel = g_SelectedHudPanel[id];
    if (panel < 0 || panel >= HMS_PANEL_COUNT) return PLUGIN_HANDLED;
    if (equal(vinfo, "toggle"))
    {
        g_HudPanelEnabled[id][panel] = !g_HudPanelEnabled[id][panel];
        new vname[32];
        new vstate[24];
        new vline[128];
        Hms_PanelName(id, panel, vname, charsmax(vname));
        if (g_HudPanelEnabled[id][panel]) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
        else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
        Hms_LF(id, "HMS_CHAT_PANEL", "^4[HNS]^1 %s panel: %s", vline, charsmax(vline), vname, vstate);
        client_print_color(id, print_team_default, "%s", vline);
    }
    else if (equal(vinfo, "color")) { HmsCmdColorPicker(id, 0); return PLUGIN_HANDLED; }
    else if (equal(vinfo, "position")) { HmsCmdPanelPositionMenu(id); return PLUGIN_HANDLED; }
    else if (equal(vinfo, "reset")) Hms_ResetPanelLayout(id, panel);
    else if (equal(vinfo, "back")) { HmsCmdLayoutMenu(id); return PLUGIN_HANDLED; }
    Hms_QueuePrefsSave(id, HMS_DIRTY_PANELS);
    HmsCmdPanelEditor(id);
    return PLUGIN_HANDLED;
}
// Explicit 16-color picker: players select the exact RGB color instead of cycling blindly.
public HmsCmdColorPicker(id, page)
{
    new panel = g_SelectedHudPanel[id];
    if (panel < 0 || panel >= HMS_PANEL_COUNT) { HmsCmdLayoutMenu(id); return PLUGIN_HANDLED; }

    g_HmsMenuPage[id] = page;
    new vtitle[128];
    new vitem[96];
    new vinfo[8];
    new vcolorName[32];
    new vcurrent[24];
    Hms_L(id, "HMS_COLOR_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| HUD Color Palette^n\ySELECT RGB COLOR / 16 OPTIONS");
    new menu = menu_create(vtitle, "Hms_ColorPickerHandler");
    Hms_StyleMenu(id, menu);
    Hms_L(id, "HMS_COLOR_CURRENT", vcurrent, charsmax(vcurrent), "\r[CURRENT] \w%s");
    page = Hms_ClampPage(id, HMS_COLOR_COUNT);
    new added = 0;
    for (new color = 0; color < HMS_COLOR_COUNT; color++)
    {
        if (!Hms_OnPage(color, page)) continue;
        Hms_ColorName(id, color, vcolorName, charsmax(vcolorName));
        if (color == g_HudPanelColor[id][panel])
            formatex(vitem, charsmax(vitem), vcurrent, vcolorName);
        else
            formatex(vitem, charsmax(vitem), "\w%s", vcolorName);
        num_to_str(color, vinfo, charsmax(vinfo));
        menu_additem(menu, vitem, vinfo);
        added++;
    }
    Hms_AddNav(id, menu, added, HMS_COLOR_COUNT, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_ColorPickerHandler(id, menu, item)
{
    new vinfo[8];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdPanelEditor(id);
    if (nav == HMS_NAV_PREV) return HmsCmdColorPicker(id, g_HmsMenuPage[id] - 1);
    if (nav == HMS_NAV_NEXT) return HmsCmdColorPicker(id, g_HmsMenuPage[id] + 1);

    new color = str_to_num(vinfo);
    new panel = g_SelectedHudPanel[id];
    if (panel >= 0 && panel < HMS_PANEL_COUNT && color >= 0 && color < HMS_COLOR_COUNT)
    {
        g_HudPanelColor[id][panel] = color;
        Hms_QueuePrefsSave(id, HMS_DIRTY_PANELS);
        new vname[32];
        new vcolorName[32];
        new vline[160];
        Hms_PanelName(id, panel, vname, charsmax(vname));
        Hms_ColorName(id, color, vcolorName, charsmax(vcolorName));
        Hms_LF(id, "HMS_CHAT_COLOR", "[HMS] %s HUD color set to %s.", vline, charsmax(vline), vname, vcolorName);
        client_print(id, print_chat, "%s", vline);
    }
    return HmsCmdColorPicker(id, g_HmsMenuPage[id]);
}

public HmsCmdPanelPositionMenu(id)
{
    new vtitle[128];
    new vitem[64];
    Hms_L(id, "HMS_POS_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Fine Position Tools^n\ySTEP: 2 PERCENT PER PRESS");
    new menu = menu_create(vtitle, "Hms_PanelPositionHandler");
    Hms_StyleMenu(id, menu);
    Hms_L(id, "HMS_POS_LEFT", vitem, charsmax(vitem), "Move left  (-2%)");
    menu_additem(menu, vitem, "left");
    Hms_L(id, "HMS_POS_RIGHT", vitem, charsmax(vitem), "Move right (+2%)");
    menu_additem(menu, vitem, "right");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_POS_UP", vitem, charsmax(vitem), "Move up    (-2%)");
    menu_additem(menu, vitem, "up");
    Hms_L(id, "HMS_POS_DOWN", vitem, charsmax(vitem), "Move down  (+2%)");
    menu_additem(menu, vitem, "down");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_POS_ALIGN_L", vitem, charsmax(vitem), "Align left");
    menu_additem(menu, vitem, "alignleft");
    Hms_L(id, "HMS_POS_CENTER", vitem, charsmax(vitem), "Center horizontally");
    menu_additem(menu, vitem, "center");
    Hms_L(id, "HMS_POS_ALIGN_R", vitem, charsmax(vitem), "Align right");
    menu_additem(menu, vitem, "alignright");
    Hms_AddNav(id, menu, 7, 7, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_PanelPositionHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdPanelEditor(id);
    new panel = g_SelectedHudPanel[id];
    if (panel < 0 || panel >= HMS_PANEL_COUNT) return PLUGIN_HANDLED;
    if (equal(vinfo, "left")) { if (g_HudPanelX[id][panel] < 0) g_HudPanelX[id][panel] = 48; else g_HudPanelX[id][panel] -= 2; if (g_HudPanelX[id][panel] < 0) g_HudPanelX[id][panel] = 0; }
    else if (equal(vinfo, "right")) { if (g_HudPanelX[id][panel] < 0) g_HudPanelX[id][panel] = 52; else g_HudPanelX[id][panel] += 2; if (g_HudPanelX[id][panel] > 90) g_HudPanelX[id][panel] = 90; }
    else if (equal(vinfo, "up")) { g_HudPanelY[id][panel] -= 2; if (g_HudPanelY[id][panel] < 0) g_HudPanelY[id][panel] = 0; }
    else if (equal(vinfo, "down")) { g_HudPanelY[id][panel] += 2; if (g_HudPanelY[id][panel] > 90) g_HudPanelY[id][panel] = 90; }
    else if (equal(vinfo, "alignleft")) g_HudPanelX[id][panel] = 2;
    else if (equal(vinfo, "center")) g_HudPanelX[id][panel] = -1;
    else if (equal(vinfo, "alignright")) g_HudPanelX[id][panel] = 68;
    Hms_QueuePrefsSave(id, HMS_DIRTY_PANELS);
    HmsCmdPanelPositionMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdPresetMenu(id)
{
    new vtitle[96];
    new vitem[96];
    Hms_L(id, "HMS_PRESET_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Layout Presets");
    new menu = menu_create(vtitle, "Hms_PresetMenuHandler");
    Hms_StyleMenu(id, menu);
    Hms_L(id, "HMS_PRESET_0", vitem, charsmax(vitem), "Default - speed bottom / stats above health");
    menu_additem(menu, vitem, "0");
    Hms_L(id, "HMS_PRESET_1", vitem, charsmax(vitem), "Raised - more room above the health bar");
    menu_additem(menu, vitem, "1");
    Hms_L(id, "HMS_PRESET_2", vitem, charsmax(vitem), "Low - stats closer to the health bar");
    menu_additem(menu, vitem, "2");
    Hms_AddNav(id, menu, 3, 3, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_PresetMenuHandler(id, menu, item)
{
    new vinfo[8];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdLayoutMenu(id);
    new preset = str_to_num(vinfo);
    if (preset < 0 || preset > 2) preset = 0;
    Hms_ApplyHudPreset(id, preset);
    Hms_QueuePrefsSave(id, HMS_DIRTY_PANELS);
    new vline[160];
    Hms_L(id, "HMS_CHAT_PRESET", vline, charsmax(vline), "[HMS] Layout preset applied. Panel colors and field visibility are unchanged.");
    client_print(id, print_chat, "%s", vline);
    HmsCmdLayoutMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdThemeMenu(id)
{
    new vtitle[128];
    new vitem[96];
    Hms_L(id, "HMS_THEME_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Color Themes^n\yHUD RGB PALETTE / PANEL COLOR");
    new menu = menu_create(vtitle, "Hms_ThemeMenuHandler");
    Hms_StyleMenu(id, menu);
    Hms_L(id, "HMS_THEME_0", vitem, charsmax(vitem), "Arctic  - cyan / blue / white");
    menu_additem(menu, vitem, "0");
    Hms_L(id, "HMS_THEME_1", vitem, charsmax(vitem), "Classic HNS - green / yellow");
    menu_additem(menu, vitem, "1");
    Hms_L(id, "HMS_THEME_2", vitem, charsmax(vitem), "Neon Pink - pink / purple");
    menu_additem(menu, vitem, "2");
    Hms_MenuGap(menu);
    Hms_L(id, "HMS_THEME_3", vitem, charsmax(vitem), "Sunset - orange / red / yellow");
    menu_additem(menu, vitem, "3");
    Hms_L(id, "HMS_THEME_4", vitem, charsmax(vitem), "Purple Dream - purple / pink / blue");
    menu_additem(menu, vitem, "4");
    Hms_L(id, "HMS_THEME_5", vitem, charsmax(vitem), "High Contrast - white / lime / cyan");
    menu_additem(menu, vitem, "5");
    Hms_AddNav(id, menu, 6, 6, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_ThemeMenuHandler(id, menu, item)
{
    new vinfo[8];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    if (equal(vinfo, "palette")) { HmsCmdLayoutMenu(id); return PLUGIN_HANDLED; }
    new theme = str_to_num(vinfo);
    switch (theme)
    {
        case 0: { g_HudPanelColor[id][HMS_PANEL_STATUS] = 6; g_HudPanelColor[id][HMS_PANEL_SPEED] = 0; g_HudPanelColor[id][HMS_PANEL_JUMP] = 8; }
        case 1: { g_HudPanelColor[id][HMS_PANEL_STATUS] = 5; g_HudPanelColor[id][HMS_PANEL_SPEED] = 2; g_HudPanelColor[id][HMS_PANEL_JUMP] = 0; }
        case 2: { g_HudPanelColor[id][HMS_PANEL_STATUS] = 4; g_HudPanelColor[id][HMS_PANEL_SPEED] = 7; g_HudPanelColor[id][HMS_PANEL_JUMP] = 4; }
        case 3: { g_HudPanelColor[id][HMS_PANEL_STATUS] = 5; g_HudPanelColor[id][HMS_PANEL_SPEED] = 3; g_HudPanelColor[id][HMS_PANEL_JUMP] = 1; }
        case 4: { g_HudPanelColor[id][HMS_PANEL_STATUS] = 7; g_HudPanelColor[id][HMS_PANEL_SPEED] = 4; g_HudPanelColor[id][HMS_PANEL_JUMP] = 6; }
        case 5: { g_HudPanelColor[id][HMS_PANEL_STATUS] = 8; g_HudPanelColor[id][HMS_PANEL_SPEED] = 9; g_HudPanelColor[id][HMS_PANEL_JUMP] = 0; }
        default: { HmsCmdThemeMenu(id); return PLUGIN_HANDLED; }
    }
    Hms_QueuePrefsSave(id, HMS_DIRTY_PANELS);
    new vline[160];
    Hms_L(id, "HMS_CHAT_THEME", vline, charsmax(vline), "[HMS] RGB panel theme applied. Colors can be refined panel by panel.");
    client_print(id, print_chat, "%s", vline);
    HmsCmdThemeMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdSoundMenu(id)
{
    new vtitle[96];
    Hms_L(id, "HMS_SOUND_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Sound Laboratory");
    new menu = menu_create(vtitle, "Hms_SoundMenuHandler");
    Hms_StyleMenu(id, menu);
    new vitem[96];
    new vstate[32];
    if (g_Player[id][pSoundsEnabled]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_SOUND_MASTER", "Sound master: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "master");
    if (g_Player[id][pTakeoffSound]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_SOUND_TAKEOFF", "Takeoff cue: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "takeoff");
    if (g_Player[id][pLandingSound]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_SOUND_LAND", "Landing cue: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "landing");
    Hms_MenuGap(menu);
    if (g_Player[id][pAchievementSound]) Hms_L(id, "HMS_MARK_ON", vstate, charsmax(vstate), "\yON\w");
    else Hms_L(id, "HMS_MARK_OFF", vstate, charsmax(vstate), "\rOFF\w");
    Hms_LF(id, "HMS_SOUND_ACH", "Achievement cue: %s", vitem, charsmax(vitem), vstate);
    menu_additem(menu, vitem, "achievement");
    Hms_L(id, "HMS_SOUND_TEST0", vitem, charsmax(vitem), "\wTest takeoff cue");
    menu_additem(menu, vitem, "test0");
    Hms_L(id, "HMS_SOUND_TEST1", vitem, charsmax(vitem), "\wTest landing cue");
    menu_additem(menu, vitem, "test1");
    Hms_L(id, "HMS_SOUND_TEST2", vitem, charsmax(vitem), "\wTest achievement cue");
    menu_additem(menu, vitem, "test2");
    Hms_AddNav(id, menu, 7, 7, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_SoundMenuHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    new bool:savePrefs = true;
    if (equal(vinfo, "master")) g_Player[id][pSoundsEnabled] = !g_Player[id][pSoundsEnabled];
    else if (equal(vinfo, "takeoff")) g_Player[id][pTakeoffSound] = !g_Player[id][pTakeoffSound];
    else if (equal(vinfo, "landing")) g_Player[id][pLandingSound] = !g_Player[id][pLandingSound];
    else if (equal(vinfo, "achievement")) g_Player[id][pAchievementSound] = !g_Player[id][pAchievementSound];
    else if (equal(vinfo, "test0")) { Hms_PlayTestSound(id, 0); savePrefs = false; }
    else if (equal(vinfo, "test1")) { Hms_PlayTestSound(id, 1); savePrefs = false; }
    else if (equal(vinfo, "test2")) { Hms_PlayTestSound(id, 2); savePrefs = false; }
    if (savePrefs)
    {
        Hms_QueuePrefsSave(id, HMS_DIRTY_PREFS);
        new soundState[24], soundLine[128], soundKey[32];
        if (equal(vinfo, "master"))
        {
            copy(soundKey, charsmax(soundKey), "HMS_CHAT_SOUND");
            if (g_Player[id][pSoundsEnabled]) Hms_L(id, "HMS_CHAT_ON", soundState, charsmax(soundState), "^3ON");
            else Hms_L(id, "HMS_CHAT_OFF", soundState, charsmax(soundState), "^1OFF");
        }
        else if (equal(vinfo, "takeoff"))
        {
            copy(soundKey, charsmax(soundKey), "HMS_CHAT_TAKEOFF");
            if (g_Player[id][pTakeoffSound]) Hms_L(id, "HMS_CHAT_ON", soundState, charsmax(soundState), "^3ON");
            else Hms_L(id, "HMS_CHAT_OFF", soundState, charsmax(soundState), "^1OFF");
        }
        else if (equal(vinfo, "landing"))
        {
            copy(soundKey, charsmax(soundKey), "HMS_CHAT_LAND");
            if (g_Player[id][pLandingSound]) Hms_L(id, "HMS_CHAT_ON", soundState, charsmax(soundState), "^3ON");
            else Hms_L(id, "HMS_CHAT_OFF", soundState, charsmax(soundState), "^1OFF");
        }
        else if (equal(vinfo, "achievement"))
        {
            copy(soundKey, charsmax(soundKey), "HMS_CHAT_ACH");
            if (g_Player[id][pAchievementSound]) Hms_L(id, "HMS_CHAT_ON", soundState, charsmax(soundState), "^3ON");
            else Hms_L(id, "HMS_CHAT_OFF", soundState, charsmax(soundState), "^1OFF");
        }
        if (soundKey[0])
        {
            Hms_LF(id, soundKey, "^4[HNS]^1 %s", soundLine, charsmax(soundLine), soundState);
            client_print_color(id, print_team_default, "%s", soundLine);
        }
    }
    HmsCmdSoundMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdResetPreferencesConfirm(id)
{
    new vtitle[160];
    new vitem[64];
    Hms_L(id, "HMS_RESET_TITLE", vtitle, charsmax(vtitle), "\rHMS \w| Reset Confirmation^n\yReset only your HMS preferences.^n\ySession counters are not touched.");
    new menu = menu_create(vtitle, "Hms_ResetPreferencesHandler");
    Hms_StyleMenu(id, menu);
    Hms_L(id, "HMS_RESET_YES", vitem, charsmax(vitem), "\rYes - restore all defaults");
    menu_additem(menu, vitem, "yes");
    Hms_L(id, "HMS_RESET_NO", vitem, charsmax(vitem), "No - keep my settings");
    menu_additem(menu, vitem, "no");
    Hms_AddNav(id, menu, 2, 2, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_ResetPreferencesHandler(id, menu, item)
{
    new vinfo[8];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    if (equal(vinfo, "yes"))
    {
        Hms_SettingsDefaults(id);
        Hms_QueuePrefsSave(id, HMS_DIRTY_ALL);
        new vline[128];
        Hms_L(id, "HMS_CHAT_RESET", vline, charsmax(vline), "[HMS] Your personal preferences have been restored.");
        client_print(id, print_chat, "%s", vline);
    }
    HmsCmdMainMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdAdminMenu(id)
{
    if (!Hms_IsAdmin(id))
    {
        client_print(id, print_chat, "[HMS] Access denied. Requires ADMIN_CFG.");
        return PLUGIN_HANDLED;
    }

    new menu = menu_create("\rHMS \w| Administrator Center^n\ySERVER-WIDE ACTIONS", "Hms_AdminMenuHandler");
    Hms_StyleMenu(id, menu);
    menu_additem(menu, "\wRuntime status & diagnostics", "status");
    menu_additem(menu, "\wGlobal runtime switches", "global");
    menu_additem(menu, "\wSQL management center", "sql");
    Hms_MenuGap(menu);
    menu_additem(menu, "\wMovement thresholds & tuning", "thresholds");
    menu_additem(menu, "\wHNS bridge / integration status", "bridge");
    menu_additem(menu, "\wManage connected player", "players");
    Hms_AddNav(id, menu, 6, 6, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_AdminMenuHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdMainMenu(id);
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    if (equal(vinfo, "status")) { HmsCmdStatus(id); HmsCmdAdminMenu(id); }
    else if (equal(vinfo, "global")) HmsCmdAdminGlobalMenu(id);
    else if (equal(vinfo, "sql")) HmsCmdSqlMenu(id);
    else if (equal(vinfo, "thresholds")) HmsCmdAdminThresholdMenu(id);
    else if (equal(vinfo, "bridge")) { Hms_ShowBridgeDiagnostics(id); HmsCmdAdminMenu(id); }
    else if (equal(vinfo, "players")) HmsCmdAdminPlayerList(id);
    return PLUGIN_HANDLED;
}

public HmsCmdAdminGlobalMenu(id)
{
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    new menu = menu_create("\rHMS \w| Global Runtime Settings", "Hms_AdminGlobalHandler");
    Hms_StyleMenu(id, menu);
    new vitem[128];
    formatex(vitem, charsmax(vitem), "Plugin runtime: %s", get_pcvar_num(pcvar_enabled) ? "\rENABLED\w" : "\dDISABLED\w"); menu_additem(menu, vitem, "plugin");
    formatex(vitem, charsmax(vitem), "Takeoff sounds: %s", get_pcvar_num(pcvar_sound_takeoff) ? "\yON\w" : "\rOFF\w"); menu_additem(menu, vitem, "takeoff");
    formatex(vitem, charsmax(vitem), "Landing sounds: %s", get_pcvar_num(pcvar_sound_landing) ? "\yON\w" : "\rOFF\w"); menu_additem(menu, vitem, "landing");
    formatex(vitem, charsmax(vitem), "Achievement sounds: %s", get_pcvar_num(pcvar_sound_achievement) ? "\yON\w" : "\rOFF\w"); menu_additem(menu, vitem, "achievement");
    Hms_MenuGap(menu);
    formatex(vitem, charsmax(vitem), "Jump-result chat: %s", get_pcvar_num(pcvar_enable_jumpstats) ? "\yON\w" : "\rOFF\w"); menu_additem(menu, vitem, "reports");
    formatex(vitem, charsmax(vitem), "HUD base refresh: %.2f sec", get_pcvar_float(pcvar_hud_interval)); menu_additem(menu, vitem, "refresh");
    formatex(vitem, charsmax(vitem), "Observed server FPS: %.1f", g_ServerObservedFps); menu_additem(menu, vitem, "fpsinfo");
    Hms_AddNav(id, menu, 7, 7, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_AdminGlobalHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdAdminMenu(id);
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    if (equal(vinfo, "plugin")) set_pcvar_num(pcvar_enabled, !get_pcvar_num(pcvar_enabled));
    else if (equal(vinfo, "takeoff")) set_pcvar_num(pcvar_sound_takeoff, !get_pcvar_num(pcvar_sound_takeoff));
    else if (equal(vinfo, "landing")) set_pcvar_num(pcvar_sound_landing, !get_pcvar_num(pcvar_sound_landing));
    else if (equal(vinfo, "achievement")) set_pcvar_num(pcvar_sound_achievement, !get_pcvar_num(pcvar_sound_achievement));
    else if (equal(vinfo, "reports")) set_pcvar_num(pcvar_enable_jumpstats, !get_pcvar_num(pcvar_enable_jumpstats));
    else if (equal(vinfo, "refresh"))
    {
        new Float:interval = get_pcvar_float(pcvar_hud_interval);
        if (interval < 0.145) interval = 0.15;
        else if (interval < 0.195) interval = 0.20;
        else if (interval < 0.295) interval = 0.30;
        else interval = 0.10;
        set_pcvar_float(pcvar_hud_interval, interval);
        for (new target = 1; target <= HMS_MAX_PLAYERS; target++)
            for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
                g_NextHudUpdate[target][panel] = 0.0;
    }
    else if (equal(vinfo, "fpsinfo"))
    {
        client_print_color(id, print_team_default, "^4[HNS]^1 Observed active-player FPS %.1f; base HUD interval %.2fs.", g_ServerObservedFps, get_pcvar_float(pcvar_hud_interval));
    }
    HmsCmdAdminGlobalMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdAdminThresholdMenu(id)
{
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    new menu = menu_create("\rHMS \w| Movement Thresholds", "Hms_AdminThresholdHandler");
    Hms_StyleMenu(id, menu);
    new vitem[128];
    formatex(vitem, charsmax(vitem), "Low-speed threshold: %.0f u/s", get_pcvar_float(pcvar_low_speed)); menu_additem(menu, vitem, "low");
    formatex(vitem, charsmax(vitem), "Speed-drop trigger: %.0f u/s", get_pcvar_float(pcvar_low_drop)); menu_additem(menu, vitem, "drop");
    Hms_MenuGap(menu);
    formatex(vitem, charsmax(vitem), "Bhop FOG tolerance: %d frames", get_pcvar_num(pcvar_bhop_fog_frames)); menu_additem(menu, vitem, "fog");
    formatex(vitem, charsmax(vitem), "Achievement sound: %.0f units", get_pcvar_float(pcvar_sound_distance)); menu_additem(menu, vitem, "distance");
    menu_addtext(menu, "\yRuntime changes only; edit hms.cfg to persist.", 0);
    Hms_AddNav(id, menu, 4, 4, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_AdminThresholdHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdAdminMenu(id);
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    if (equal(vinfo, "low"))
    {
        new Float:value = get_pcvar_float(pcvar_low_speed);
        if (value < 135.0) value = 150.0;
        else if (value < 165.0) value = 180.0;
        else if (value < 195.0) value = 210.0;
        else if (value < 225.0) value = 240.0;
        else value = 120.0;
        set_pcvar_float(pcvar_low_speed, value);
    }
    else if (equal(vinfo, "drop"))
    {
        new Float:value = get_pcvar_float(pcvar_low_drop);
        if (value < 25.0) value = 30.0;
        else if (value < 37.0) value = 45.0;
        else if (value < 52.0) value = 60.0;
        else if (value < 70.0) value = 80.0;
        else value = 20.0;
        set_pcvar_float(pcvar_low_drop, value);
    }
    else if (equal(vinfo, "fog"))
    {
        new value = get_pcvar_num(pcvar_bhop_fog_frames);
        if (value < 0) value = 0;
        else if (value < 2) value = 2;
        else if (value < 4) value = 4;
        else if (value < 6) value = 6;
        else if (value < 8) value = 8;
        else if (value < 10) value = 10;
        else value = 0;
        set_pcvar_num(pcvar_bhop_fog_frames, value);
    }
    else if (equal(vinfo, "distance"))
    {
        new Float:value = get_pcvar_float(pcvar_sound_distance);
        if (value < 125.0) value = 150.0;
        else if (value < 175.0) value = 200.0;
        else if (value < 225.0) value = 250.0;
        else if (value < 275.0) value = 300.0;
        else if (value < 350.0) value = 400.0;
        else if (value < 450.0) value = 500.0;
        else value = 100.0;
        set_pcvar_float(pcvar_sound_distance, value);
    }
    HmsCmdAdminThresholdMenu(id);
    return PLUGIN_HANDLED;
}

stock Hms_ShowBridgeDiagnostics(id)
{
    new Float:age = g_HnsStatusUpdated > 0.0 ? get_gametime() - g_HnsStatusUpdated : -1.0;
    if (age < 0.0)
        client_print(id, print_chat, "[HMS] HNS bridge: NOT SEEN. Native is available; HNS core must call hms_bridge_set_status().");
    else
        client_print(id, print_chat, "[HMS] HNS bridge phase=%s detail=%s age=%.1fs timer=%.1f", g_HnsPhase, g_HnsDetail, age, g_HnsCountdown);
    client_print(id, print_chat, "[HMS] Integration include: scripting/include/hms_api.inc; sample: examples/hns_core_bridge.sma");
}

public HmsCmdAdminPlayerList(id)
{
    return Hms_ShowAdminPlayerList(id, 0);
}

stock Hms_ShowAdminPlayerList(id, page)
{
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    g_HmsMenuPage[id] = page;
    new menu = menu_create("\rHMS \w| Player Management", "Hms_AdminPlayerListHandler");
    Hms_StyleMenu(id, menu);
    new vplayers[32];
    new count;
    get_players(vplayers, count, "ch");
    new total = count ? count : 1;
    page = Hms_ClampPage(id, total);
    new added = 0;
    if (!count)
    {
        if (Hms_OnPage(0, page))
        {
            menu_additem(menu, "\dNo connected human vplayers.", "none");
            added++;
        }
    }
    else
    {
        for (new i = 0; i < count; i++)
        {
            if (!Hms_OnPage(i, page)) continue;
            new target = vplayers[i];
            new vname[32];
            new vinfo[24];
            new label[96];
            get_user_name(target, vname, charsmax(vname));
            formatex(label, charsmax(label), "%s  (slot %d)", vname, target);
            formatex(vinfo, charsmax(vinfo), "%d %d", target, get_user_userid(target));
            menu_additem(menu, label, vinfo);
            added++;
        }
    }
    Hms_AddNav(id, menu, added, total, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_AdminPlayerListHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdAdminMenu(id);
    if (nav == HMS_NAV_PREV) return Hms_ShowAdminPlayerList(id, g_HmsMenuPage[id] - 1);
    if (nav == HMS_NAV_NEXT) return Hms_ShowAdminPlayerList(id, g_HmsMenuPage[id] + 1);
    new vslotText[8];
    new vuserIdText[8];
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    if (equal(vinfo, "none")) { HmsCmdAdminMenu(id); return PLUGIN_HANDLED; }
    parse(vinfo, vslotText, charsmax(vslotText), vuserIdText, charsmax(vuserIdText));
    new target = str_to_num(vslotText);
    new userId = str_to_num(vuserIdText);
    if (target < 1 || target > HMS_MAX_PLAYERS || !is_user_connected(target) || get_user_userid(target) != userId)
    {
        client_print(id, print_chat, "[HMS] That player left or the slot was reused; reopen the list.");
        return Hms_ShowAdminPlayerList(id, g_HmsMenuPage[id]);
    }
    g_SelectedAdminTarget[id] = target;
    g_SelectedAdminTargetUserId[id] = userId;
    HmsCmdAdminTargetMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdAdminTargetMenu(id)
{
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    new target = g_SelectedAdminTarget[id];
    new userId = g_SelectedAdminTargetUserId[id];
    new vname[32];
    new vtitle[96];
    new vitem[96];
    if (target < 1 || target > HMS_MAX_PLAYERS || !is_user_connected(target) || get_user_userid(target) != userId)
    {
        client_print(id, print_chat, "[HMS] Target disconnected; returning to player list.");
        HmsCmdAdminPlayerList(id);
        return PLUGIN_HANDLED;
    }
    get_user_name(target, vname, charsmax(vname));
    formatex(vtitle, charsmax(vtitle), "\rHMS \w| Player: %s", vname);
    new menu = menu_create(vtitle, "Hms_AdminTargetHandler");
    Hms_StyleMenu(id, menu);
    formatex(vitem, charsmax(vitem), "View live stats (%.1f u/s)", g_Player[target][pCurrentSpeed]); menu_additem(menu, vitem, "stats");
    menu_additem(menu, "Reset target session counters", "resetstats");
    menu_additem(menu, "Reset target personal preferences", "resetprefs");
    Hms_AddNav(id, menu, 3, 3, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_AdminTargetHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdAdminPlayerList(id);
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    new target = g_SelectedAdminTarget[id];
    new userId = g_SelectedAdminTargetUserId[id];
    if (target < 1 || target > HMS_MAX_PLAYERS || !is_user_connected(target) || get_user_userid(target) != userId)
    {
        client_print(id, print_chat, "[HMS] Target disconnected or slot reused.");
        HmsCmdAdminPlayerList(id);
        return PLUGIN_HANDLED;
    }
    if (equal(vinfo, "stats"))
    {
        new vname[32];
        get_user_name(target, vname, charsmax(vname));
        client_print(id, print_chat, "[HMS] %s: speed %.1f max %.1f jumps %d landings %d", vname, g_Player[target][pCurrentSpeed], g_Player[target][pSessionMaxSpeed], g_Player[target][pJumpCount], g_Player[target][pLandingCount]);
        client_print(id, print_chat, "[HMS] last jump %.1f air %.2fs FOG %d gain +%.1f / loss -%.1f", g_Player[target][pLastJumpDistance], g_Player[target][pLastAirTime], g_Player[target][pLastFogFrames], g_Player[target][pLastStrafeGain], g_Player[target][pLastStrafeLoss]);
    }
    else if (equal(vinfo, "resetstats"))
    {
        Hms_ResetSessionCounters(target);
        client_print(id, print_chat, "[HMS] Target session counters reset.");
    }
    else if (equal(vinfo, "resetprefs"))
    {
        Hms_SettingsDefaults(target);
        Hms_QueuePrefsSave(target, HMS_DIRTY_ALL);
        client_print(id, print_chat, "[HMS] Target personal preferences reset.");
    }
    HmsCmdAdminTargetMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdSqlMenu(id)
{
    if (!Hms_IsAdmin(id)) { client_print(id, print_chat, "[HMS] SQL diagnostics require ADMIN_CFG."); return PLUGIN_HANDLED; }
    new vtitle[128];
    formatex(vtitle, charsmax(vtitle), "\rHMS \w| SQL Center - %s", g_SqlEnabled ? "CONFIGURED" : "LOCAL MODE");
    new menu = menu_create(vtitle, "Hms_SqlMenuHandler");
    Hms_StyleMenu(id, menu);
    new vline[192];
    new vprobeState[24];
    if (g_SqlProbePending) copy(vprobeState, charsmax(vprobeState), "PENDING");
    else if (!g_SqlProbeCompleted) copy(vprobeState, charsmax(vprobeState), "NOT TESTED");
    else copy(vprobeState, charsmax(vprobeState), g_SqlConnected ? "PASSED" : "FAILED");
    menu_additem(menu, "\wRun SELECT 1 connection test", "test");
    menu_additem(menu, "\wVerify all six HMS tables", "schema");
    menu_additem(menu, "\wReload credentials from hnsmatch-sql.cfg", "reload");
    formatex(vline, charsmax(vline), "Runtime SQL storage: %s", get_pcvar_num(pcvar_sql_enabled) ? "\yON\w" : "\rOFF\w"); menu_additem(menu, vline, "toggle");
    Hms_MenuGap(menu);
    formatex(vline, charsmax(vline), "\yLast SELECT 1: \w%s", vprobeState); menu_addtext(menu, vline, 0);
    formatex(vline, charsmax(vline), "\yQuery OK: \w%d   \yFailures: \w%d", g_SqlSuccessCount, g_SqlFailureCount); menu_addtext(menu, vline, 0);
    formatex(vline, charsmax(vline), "\yLast queue time: \w%.3fs", g_SqlLastQueueTime); menu_addtext(menu, vline, 0);
    new verrorDisplay[72];
    copy(verrorDisplay, charsmax(verrorDisplay), g_SqlLastError);
    formatex(vline, charsmax(vline), "\yLatest query status: \w%s", verrorDisplay); menu_addtext(menu, vline, 0);
    formatex(vline, charsmax(vline), "\yHMS schema: \w%s", g_SqlSchemaCheckPending ? "CHECK PENDING" : (g_SqlSchemaCheckCompleted ? (g_SqlSchemaValid ? "VALID" : "INVALID") : "NOT CHECKED")); menu_addtext(menu, vline, 0);
    formatex(vline, charsmax(vline), "\ySchema detail: \w%s", g_SqlSchemaMessage); menu_addtext(menu, vline, 0);
    Hms_AddNav(id, menu, 4, 4, true);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public Hms_SqlMenuHandler(id, menu, item)
{
    new vinfo[24];
    new nav = Hms_ReadNav(menu, item, vinfo, charsmax(vinfo));
    if (nav == HMS_NAV_EXIT || nav == HMS_NAV_PAD) return PLUGIN_HANDLED;
    if (nav == HMS_NAV_BACK) return HmsCmdAdminMenu(id);
    if (!Hms_IsAdmin(id)) return PLUGIN_HANDLED;
    if (equal(vinfo, "test")) Hms_AdminSqlTest(id);
    else if (equal(vinfo, "schema")) Hms_StartSqlSchemaCheck(id);
    else if (equal(vinfo, "reload"))
    {
        Hms_DatabaseReload();
        client_print(id, print_chat, "[HMS] SQL config reload requested. Check this menu again for live test status.");
    }
    else if (equal(vinfo, "toggle"))
    {
        set_pcvar_num(pcvar_sql_enabled, !get_pcvar_num(pcvar_sql_enabled));
        Hms_DatabaseReload();
        client_print(id, print_chat, "[HMS] Runtime SQL setting changed. Edit configs/hms.cfg to persist across restart.");
    }
    HmsCmdSqlMenu(id);
    return PLUGIN_HANDLED;
}

public HmsCmdStatus(id)
{
    new mapName[64];
    get_mapname(mapName, charsmax(mapName));
    new Float:age = g_HnsStatusUpdated > 0.0 ? get_gametime() - g_HnsStatusUpdated : -1.0;
    client_print_color(id, print_team_default, "^4[HNS]^1 MAP %s | timeleft %d sec | players %d/%d", mapName, get_timeleft(), get_playersnum(), get_maxplayers());
    client_print_color(id, print_team_default, "^4[HNS]^1 Observed server FPS %.1f (estimate from active-player frames)", g_ServerObservedFps);
    if (age < 0.0) client_print_color(id, print_team_default, "^4[HNS]^1 HNS status: waiting for core bridge; phase/countdown are not guessed.");
    else client_print_color(id, print_team_default, "^4[HNS]^1 HNS %s | %s | status age %.1fs", g_HnsPhase, g_HnsDetail, age);
    new sqlProbeText[32];
    if (!g_SqlEnabled) copy(sqlProbeText, charsmax(sqlProbeText), "disabled/local mode");
    else if (g_SqlProbePending) copy(sqlProbeText, charsmax(sqlProbeText), "test pending");
    else if (!g_SqlProbeCompleted) copy(sqlProbeText, charsmax(sqlProbeText), "not tested");
    else copy(sqlProbeText, charsmax(sqlProbeText), g_SqlConnected ? "SELECT 1 passed" : "SELECT 1 failed");
    client_print_color(id, print_team_default, "^4[HNS]^1 SQL storage %s | %s | use /hmsmenu for settings", g_SqlEnabled ? "configured" : "local-only", sqlProbeText);
    return PLUGIN_HANDLED;
}

public HmsCmdSoundToggle(id)
{
    g_Player[id][pSoundsEnabled] = !g_Player[id][pSoundsEnabled];
    client_print(id, print_chat, "[HMS] Personal movement sounds %s", g_Player[id][pSoundsEnabled] ? "ON" : "OFF");
    Hms_QueuePrefsSave(id, HMS_DIRTY_PREFS);
    return PLUGIN_HANDLED;
}

public HmsCmdSpeed(id)
{
    Hms_ToggleHudField(id, HMS_HUD_SPEED);
    return PLUGIN_HANDLED;
}

public HmsCmdSpeedType(id)
{
    Hms_ToggleHudField(id, HMS_HUD_MAXSPEED);
    return PLUGIN_HANDLED;
}

public HmsCmdFog(id)
{
    Hms_ToggleHudField(id, HMS_HUD_FOG);
    return PLUGIN_HANDLED;
}

public HmsCmdShowPre(id)
{
    g_Player[id][pShowPre] = !g_Player[id][pShowPre];
    g_HudFieldEnabled[id][HMS_HUD_PRESPEED] = g_Player[id][pShowPre];
    new vstate[24];
    new vline[128];
    if (g_Player[id][pShowPre]) Hms_L(id, "HMS_CHAT_ON", vstate, charsmax(vstate), "^3ON");
    else Hms_L(id, "HMS_CHAT_OFF", vstate, charsmax(vstate), "^1OFF");
    Hms_LF(id, "HMS_KZ_PRE", "Air / ground speed: \y%s", vline, charsmax(vline), vstate);
    client_print_color(id, print_team_default, "^4[HNS]^1 %s", vline);
    Hms_QueuePrefsSave(id, HMS_DIRTY_FIELDS);
    return PLUGIN_HANDLED;
}

#include <amxmodx>
#include <reapi>

enum _:PCVAR
{
    FLAGS[64],
    COLOR[12],
    COORD[11],
    START[6],
    END[6]
}
new bool:bModeNight = false, bool:bPlayers[MAX_PLAYERS + 1], g_pCvar[PCVAR];

public plugin_init()
{
    register_plugin("[GM] Night VIP","1.1.1","[GM] NWC");
    register_dictionary("gm_night_vips.txt");

    bind_pcvar_string(create_cvar("nightvip_flags", "t", FCVAR_NOEXTRAWHITEPACE, "Night Vip flags"), g_pCvar[FLAGS], charsmax(g_pCvar[FLAGS]));
    bind_pcvar_string(create_cvar("nightvip_start", "23:00", FCVAR_NOEXTRAWHITEPACE, "Start time of the night VIP"), g_pCvar[START], charsmax(g_pCvar[START]));
    bind_pcvar_string(create_cvar("nightvip_end", "8:00", FCVAR_NOEXTRAWHITEPACE, "End time of the night VIP"), g_pCvar[END], charsmax(g_pCvar[END]));
    bind_pcvar_string(create_cvar("nightvip_dhud_color", "0 255 0", FCVAR_NOEXTRAWHITEPACE, "Dhud color"), g_pCvar[COLOR], charsmax(g_pCvar[COLOR]));
    bind_pcvar_string(create_cvar("nightvip_dhud_coord","-1.0 0.1", FCVAR_NOEXTRAWHITEPACE, "Dhud coordinates"), g_pCvar[COORD], charsmax(g_pCvar[COORD]));

    AutoExecConfig(true, "nightvips", "gm_plugins");

    RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Pre", false);
}
public client_putinserver(id)
{
    if(!is_user_ign(id) && bModeNight && ~get_user_flags(id) & read_flags(g_pCvar[FLAGS]))
    {
        set_task_ex(5.0, "vip_info", id+2077);
    }
}
public client_disconnected(id)
{
    if(bPlayers[id])
    {
        bPlayers[id] = false;
    }
}
public RG_RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
    new Hour, Min, hStart, hEnd, mStart, mEnd;

    get_int_time(g_pCvar[START], hStart, mStart);
    get_int_time(g_pCvar[END], hEnd, mEnd);
    time(Hour,Min);

    if(hStart == hEnd && mEnd == mStart || hStart >= 24 || hEnd >= 24 || hStart < 0 || hEnd < 0)
    {
        for(new id; id <= MaxClients; id++)
        {
            if(get_user_flags(id) & ADMIN_CVAR)
            {
                client_print_color(id, -2,"%L %L", -1, "GM_NIGTVIPS_PREFIX", -1, "GM_NIGHTVIPS_ERROR");
            }
        }
        server_print("[GM Night VIP] Error! Sets cvar nightvip_end is 8:00 and nightvip_start is 23:00!", g_pCvar[START], g_pCvar[END]);
        log_amx("[GM Night VIP] Error! Sets cvar nightvip_end is 8:00 and nightvip_start is 23:00!", g_pCvar[START], g_pCvar[END]);
        set_pcvar_string(g_pCvar[START], "23:00");
        set_pcvar_string(g_pCvar[END], "8:00");
    }

    new bool:bModeNightP = bModeNight;

    if(hStart == hEnd && hStart == Hour && mStart <= Min <= mEnd)
    {
        bModeNight = true;
    }
    else if(Hour == hEnd && Min < mEnd)
    {
        bModeNight = true;
    }
    else if(Hour == hStart && Min >= mStart)
    {
        bModeNight = true;
    }
    else if(hStart > hEnd && (Hour > hStart > hEnd || hStart > hEnd > Hour))
    {
        bModeNight = true;
    }
    else if(hEnd > hStart && hEnd > Hour > hStart)
    {
        bModeNight = true;
    }
    else
    {
        bModeNight = false;
    }

    if(bModeNight && !bModeNightP)
    {
        for(new id; id <= MaxClients; id++)
        {
            if(is_user_ign(id))
            {   
                continue;
            }
    
            if(get_user_flags(id) & read_flags(g_pCvar[FLAGS]))
            {
                vip_info(id, 2)
            }
            else
            {
                vip_info(id, 0)
            }
        }
    }
    if(bModeNightP && !bModeNight)
    {
        for(new id; id <= MaxClients; id++)
        {
            if(is_user_ign(id)) 
            {   
                continue;
            }

            vip_info(id, 1)
        }
    }
}
public vip_info(id, sc)
{
    new szChat[128], szDhud[64];

    if(id > 2077)
    {
        id-=2077;
        sc = 0;
    }

    switch(sc)
    {
        case 0:
        {
            bPlayers[id] = true;
            set_user_flags(id, read_flags(g_pCvar[FLAGS]));
            formatex(szChat, charsmax(szChat), "%L %L", id, "GM_NIGTVIPS_PREFIX", id, "GM_NIGTVIPS_CHAT_START")
            formatex(szDhud, charsmax(szDhud), "%L", id, "GM_NIGTVIPS_DHUD_START")
        }
        case 1:
        {
            if(bPlayers[id])
            {
                bPlayers[id]=false;
                remove_user_flags(id, read_flags(g_pCvar[FLAGS]));
            }
            formatex(szChat, charsmax(szChat), "%L %L", id, "GM_NIGTVIPS_PREFIX", id, "GM_NIGTVIPS_CHAT_END")
            formatex(szDhud, charsmax(szDhud), "%L", id, "GM_NIGTVIPS_DHUD_END")
        }
        case 2:
        {
            formatex(szChat, charsmax(szChat), "%L %L", id, "GM_NIGTVIPS_PREFIX", id, "GM_NIGTVIPS_CHAT_IGN");
            formatex(szDhud, charsmax(szDhud), "%L", id, "GM_NIGTVIPS_DHUD_START")
        }
    }

    new red[4], green[4], blue[4], coord_x[5], coord_y[5];

    parse(g_pCvar[COLOR], red, 3, green, 3, blue, 3);
    parse(g_pCvar[COORD], coord_x, 4, coord_y, 4);
    set_dhudmessage(str_to_num(red), str_to_num(green), str_to_num(blue), str_to_float(coord_x), str_to_float(coord_y), 0, 0.0, 5.0, 0.05, 1.5);
    show_dhudmessage(id, "%s", szDhud);
    client_print_color(id, print_team_blue, "%s", szChat);

    return PLUGIN_HANDLED;
}

stock get_int_time(const string[], &hour, &minutes)
{
    new left[4],right[4];
    strtok2(string,left,charsmax(left),right,charsmax(right),':');
    hour = str_to_num(left);
    minutes = str_to_num(right);
}

stock set_task_ex(Float:time, const function[], id = 0, const any:parameter[] = "", len = 0, SetTaskFlags:flags = SetTask_Once, repeat = 0)
{
	new strFlags[2];
	get_flags(_:flags, strFlags, charsmax(strFlags));
	set_task(time, function, id, parameter, len, strFlags, repeat);
}

stock is_user_ign(const id)
{
    return (is_user_bot(id) || is_user_hltv(id) || is_user_connecting(id) || !is_user_connected(id));
}
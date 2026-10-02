/*
 * 点位模式核心逻辑
 */

#define CHECK_INTERVAL 0.5

new Float:g_PointScore[3] = {0.5, 1.0, 2.0};
new g_RequiredPlayers[3] = {3, 4, 5};

// 点位数据 [zone][level]  zone:0-11(A-L)  level:0-2(3人/4人/5人)
new Float:g_PointOrigin[MAX_ZONES][3][3];
new bool:g_PointSet[MAX_ZONES][3];
new Float:g_PointRadius[MAX_ZONES][3];

// 比赛状态
new bool:g_bPointActive = false;
new Float:g_RoundScore = 0.0;
new Float:g_CounterTimeLeft[MAX_ZONES];
new bool:g_ZoneCountered[MAX_ZONES];
new g_Capturers[MAX_ZONES][MAX_PLAYERS];
new g_CapturerCount[MAX_ZONES];
new bool:g_ZoneClosedThisRound[MAX_ZONES];

new g_PointCheckTask = -1;
new g_PointCounterTask = -1;

// 启动点位模式
point_start()
{
    if(g_bPointActive) return;
    
    g_bPointActive = true;
    g_RoundScore = 0.0;
    
    load_points_for_current_map();
    
    chat_print(0, "[点位模式] 比赛开始！目标分数: %d 分", g_iSettings[POINT_TARGET_SCORE]);
    server_cmd("sv_restartround 1");
}

// 停止点位模式
point_stop()
{
    g_bPointActive = false;
    if(g_PointCheckTask != -1) remove_task(g_PointCheckTask);
    if(g_PointCounterTask != -1) remove_task(g_PointCounterTask);
}

// 回合开始
public point_round_start()
{
    if(!g_bPointActive) return;
    
    for(new i = 0; i < MAX_ZONES; i++)
    {
        g_ZoneClosedThisRound[i] = false;
        g_CapturerCount[i] = 0;
        g_ZoneCountered[i] = false;
        g_CounterTimeLeft[i] = float(g_iSettings[POINT_COUNTER_TIME]);
    }
    
    if(g_PointCheckTask != -1) remove_task(g_PointCheckTask);
    g_PointCheckTask = set_task(CHECK_INTERVAL, "point_check_capture", _, _, _, "b");
    
    if(g_PointCounterTask != -1) remove_task(g_PointCounterTask);
    g_PointCounterTask = set_task(1.0, "point_counter_timer", _, _, _, "b");
}

// 回合结束
public point_round_end(bool:win_ct)
{
    if(!g_bPointActive) return;
    
    if(g_PointCheckTask != -1) remove_task(g_PointCheckTask);
    if(g_PointCounterTask != -1) remove_task(g_PointCounterTask);
    
    g_RoundScore = 0.0;
}

// 占点检测
public point_check_capture()
{
    if(!g_bPointActive) return;
    if(get_member_game(m_bFreezePeriod)) return;
    
    for(new zone = 0; zone < MAX_ZONES; zone++)
    {
        if(g_ZoneClosedThisRound[zone]) continue;
        
        for(new level = 2; level >= 0; level--)
        {
            if(!g_PointSet[zone][level]) continue;
            
            new players = 0;
            new Float:radius = g_PointRadius[zone][level];
            new Float:origin[3];
            origin = g_PointOrigin[zone][level];
            
            for(new id = 1; id <= MaxClients; id++)
            {
                if(!is_user_alive(id)) continue;
                if(get_member(id, m_iTeam) != TEAM_TERRORIST) continue;
                
                new Float:player_origin[3];
                get_entvar(id, var_origin, player_origin);
                
                if(get_distance_f(origin, player_origin) <= radius)
                    players++;
            }
            
            if(players >= g_RequiredPlayers[level])
            {
                // 占领成功
                g_RoundScore += g_PointScore[level];
                g_ZoneClosedThisRound[zone] = true;
                
                // 记录占领者
                g_CapturerCount[zone] = 0;
                for(new id = 1; id <= MaxClients; id++)
                {
                    if(!is_user_alive(id)) continue;
                    if(get_member(id, m_iTeam) != TEAM_TERRORIST) continue;
                    
                    new Float:player_origin[3];
                    get_entvar(id, var_origin, player_origin);
                    
                    if(get_distance_f(origin, player_origin) <= radius)
                    {
                        g_Capturers[zone][g_CapturerCount[zone]++] = id;
                    }
                }
                
                new zone_name[4];
                new zones[12][4] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"};
                copy(zone_name, 3, zones[zone]);
                
                new level_name[16];
                switch(level)
                {
                    case 0: formatex(level_name, 15, "3人点");
                    case 1: formatex(level_name, 15, "4人点");
                    case 2: formatex(level_name, 15, "5人点");
                }
                
                chat_print(0, "[点位] T占领 %s区%s 获得 %.1f 分！当前回合总分: %.1f", 
                    zone_name, level_name, g_PointScore[level], g_RoundScore);
                
                if(g_RoundScore >= float(g_iSettings[POINT_TARGET_SCORE]))
                {
                    chat_print(0, "[点位] TT 本回合获得足够分数，TT获胜！");
                    rg_round_end(0.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, "TT Win", "TT Win");
                }
                break;
            }
        }
    }
}

// CT反制计时器
public point_counter_timer()
{
    if(!g_bPointActive) return;
    
    for(new zone = 0; zone < MAX_ZONES; zone++)
    {
        if(g_ZoneCountered[zone]) continue;
        if(g_CapturerCount[zone] == 0) continue;
        
        g_CounterTimeLeft[zone] -= 1.0;
        
        if(g_CounterTimeLeft[zone] <= 0.0)
        {
            g_CapturerCount[zone] = 0;
        }
    }
}

// 加载当前地图点位配置
load_points_for_current_map()
{
    new mapname[32];
    get_mapname(mapname, 31);
    
    new filepath[128];
    formatex(filepath, 127, "addons/amxmodx/configs/hnsic/%s.ini", mapname);
    
    if(!file_exists(filepath))
    {
        log_amx("[点位模式] 未找到配置文件: %s", filepath);
        return;
    }
    
    new file = fopen(filepath, "rt");
    if(!file) return;
    
    // 初始化所有点位为未设置
    for(new zone = 0; zone < MAX_ZONES; zone++)
        for(new level = 0; level < 3; level++)
            g_PointSet[zone][level] = false;
    
    new line[256];
    while(!feof(file))
    {
        fgets(file, line, 255);
        if(line[0] == ';' || line[0] == '/' || line[0] == '\n') continue;
        
        new zone_name[4], level, Float:x, Float:y, Float:z, Float:radius;
        if(parse(line, zone_name, 3, "", 0, "", 0) >= 2)
        {
            new zone = -1;
            new zones[12][4] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"};
            for(new i = 0; i < 12; i++)
            {
                if(equal(zone_name, zones[i]))
                {
                    zone = i;
                    break;
                }
            }
            if(zone == -1) continue;
            
            new level_str[4], x_str[16], y_str[16], z_str[16], r_str[16];
            parse(line, zone_name, 3, level_str, 3, x_str, 15, y_str, 15, z_str, 15, r_str, 15);
            level = str_to_num(level_str);
            x = str_to_float(x_str);
            y = str_to_float(y_str);
            z = str_to_float(z_str);
            radius = str_to_float(r_str);
            
            if(level >= 0 && level <= 2)
            {
                g_PointSet[zone][level] = true;
                g_PointOrigin[zone][level][0] = x;
                g_PointOrigin[zone][level][1] = y;
                g_PointOrigin[zone][level][2] = z;
                g_PointRadius[zone][level] = radius > 0 ? radius : 150.0;
            }
        }
    }
    fclose(file);
    
    log_amx("[点位模式] 已加载 %s 的点位配置", mapname);
}
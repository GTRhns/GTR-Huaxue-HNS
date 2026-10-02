#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>

// 插件信息
#define PLUGIN "Match System"
#define VERSION "1.1"
#define AUTHOR "test"

// 常量定义
#define MAX_PLAYERS 32
#define MAX_TEAM_NAME 32
#define MAX_MAPS 20
#define MAX_WEAPONS 30
#define MAX_OP_PASSWORDS 10

// 任务ID
#define TASK_RESTART_ROUND 54321
#define TASK_CHANGE_MAP 54325  // 新增地图切换任务ID



// 比赛状态枚举
enum _:MatchState {
    MATCH_IDLE = 0,       // 空闲状态
    MATCH_BP,             // BP阶段
    MATCH_RUNNING,        // 比赛进行中
    MATCH_PAUSED,         // 比赛暂停
    MATCH_SUPER_PAUSED    // 超级暂停
}

// 菜单页面枚举
enum _:MenuPage {
    MENU_MAIN_BP = 0,     // BP主菜单
    MENU_MAIN_MATCH,      // 比赛主菜单
    MENU_MATCH_SETTINGS, // 比赛设置页
    MENU_MAIN_ADMIN      // 管理菜单
}

// 全局变量
new g_iMatchState;                // 当前比赛状态
new g_szCTTeamName[MAX_TEAM_NAME];// CT队伍名称
new g_szTTeamName[MAX_TEAM_NAME]; // T队伍名称
new g_iMatchSize;                 // 比赛人数 (3=3v3, 4=4v4, 5=5v5)
new g_iRoundTime;                 // 回合时间(秒)
new g_iFreezeTime;                // 冻结时间(秒)
new g_iBuyTime;                   // 购买时间(秒)
new g_iWinCondition;              // 胜利条件(7=抢7, 10=抢10, 15=抢15)
new g_bFriendlyFire;              // 友军伤害
new g_iStartMoney;                // 初始金额
new g_bDeadTalk;                  // 死亡语音
new g_iDeathCamera;               // 死亡视角 (0=主视角, 1=全部视角)
new bool:g_bDemoRecording;      // 是否正在录制demo
new g_szDemoFileName[64];       // demo文件名
new g_bMatchPlayers[MAX_PLAYERS+1];  // 记录参与比赛的玩家
new g_iDisconnectedPlayer;           // 记录掉线的玩家ID
new bool:g_bShouldPause;            // 标记是否需要在回合结束后暂停
new g_bOvertimeEnabled;           // 加时赛开关
new g_iMapTimeLimit;              // 地图时间限制(分钟)
new g_iC4Timer;                   // C4爆破时间(秒)
new g_szOpPassword[32];          // 存储OP密码
new Array:g_aOpAdmins;           // 存储已通过OP密码验证的玩家SteamID
new bool:g_bBunnyHopDisabled = false; // 禁止狗跳状态
new g_iCTVotes;                   // CT阵营投票数
new g_iTVotes;                    // T阵营投票数
new bool:g_bHasVoted[MAX_PLAYERS+1]; // 记录玩家是否已投票
new g_iMapVotes[MAX_MAPS];              // 每个地图的投票数
new bool:g_bHasMapVoted[MAX_PLAYERS+1]; // 记录玩家是否已投票选择地图

// 武器禁用
new g_bWeaponBanned[MAX_WEAPONS];  // 武器禁用状态

// BP相关变量
new g_iKnifeDuelWinner;           // 拼刀胜利者

// 地图相关
new g_szMapList[MAX_MAPS][64];    // 地图列表
new g_iMapCount;                  // 地图数量
new g_szSelectedMap[64];          // 选择的地图

// 比分相关
new g_iCTScore;                   // CT得分
new g_iTScore;                    // T得分
new bool:g_bMatchPointPlayed;     // 赛点局音乐是否已播放

// 菜单句柄
new g_iMenus[10];                 // 存储各菜单句柄

new pausable;
new Float:g_pausAble
new bool:g_Paused
new bool:g_PauseAllowed = false

// 插件初始化
public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    // 注册命令
    register_clcmd("say /bp", "StartKnifeDuel");
    register_clcmd("say /match", "Cmd_Match");
    register_clcmd("say /ct", "Cmd_JoinCT");
    register_clcmd("say /tt", "Cmd_JoinT");
    register_clcmd("say /ob", "Cmd_Joinob");
    register_clcmd("say /stopdemo", "Cmd_StopDemo"); // 添加停止录制命令
    register_clcmd("say /admin", "Cmd_Admin"); // 添加管理菜单命令
    register_clcmd("pauseAck", "cmdPauseAck")
    
    register_clcmd("输入CT队伍名称", "Cmd_SetCTTeamName");
    register_clcmd("输入T队伍名称", "Cmd_SetTTeamName");
    register_clcmd("say /op", "Cmd_Op"); // 添加OP命令
    register_clcmd("输入OP密码", "Cmd_EnterOpPassword"); // 添加输入OP密码命令
    
    // 注册事件
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    register_event("TeamScore", "Event_TeamScore", "a");
    register_logevent("Event_RoundEnd", 2, "1=Round_End");
    register_event("SendAudio","slaylosers_ct","a","2=%!MRAD_terwin")
    register_event("SendAudio","slaylosers_t","a","2=%!MRAD_ctwin")
    // 注册前置过滤器
    register_forward(FM_ClientCommand, "Forward_ClientCommand");

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", 1)
    
    pausable=get_cvar_pointer("pausable");
    // 初始化菜单
    InitMenus();
    
    // 初始化设置
    InitSettings();
    
    // 读取地图列表
    LoadMapList();
    
    // 初始化OP密码系统
    InitOpPasswordSystem();
}

// 插件预缓存
public plugin_precache() {
    // 预缓存赛点音乐
    precache_sound("sound/match_system/match_point.wav");
}

// 初始化菜单
InitMenus() {
    // 比赛主菜单
    g_iMenus[MENU_MAIN_MATCH] = menu_create("\r[比赛系统] \w主菜单", "HandleMainMatchMenu");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w开始比赛", "1");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w热身回合", "2");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w拼刀bp", "3");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w加时赛", "4");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w强制结束比赛", "5");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w比赛设置", "6");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w回合暂停", "7");
    menu_additem(g_iMenus[MENU_MAIN_MATCH], "\w管理菜单", "8");
    menu_setprop(g_iMenus[MENU_MAIN_MATCH], MPROP_BACKNAME, "上一页")
    menu_setprop(g_iMenus[MENU_MAIN_MATCH], MPROP_NEXTNAME, "下一页")
    menu_setprop(g_iMenus[MENU_MAIN_MATCH], MPROP_EXITNAME, "\r关闭")
    menu_setprop(g_iMenus[MENU_MAIN_MATCH], MPROP_EXIT, MEXIT_ALL)
    
    // 比赛设置菜单1
    g_iMenus[MENU_MATCH_SETTINGS] = menu_create("\r[比赛系统] \w设置 - 页数：\r", "HandleMatchSettings1Menu");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w队伍名称", "1");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w比赛人数", "2");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w回合时间", "3");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w冻结时间", "4");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w购买时间", "5");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\wC4爆破时间", "6");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w地图时间", "7");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w加时赛选项", "8");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w胜利条件", "9");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w友军伤害", "10");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w禁用武器", "11");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w初始金额", "12");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w团队语音控制", "13");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w死亡视角", "14");
    menu_additem(g_iMenus[MENU_MATCH_SETTINGS], "\w禁止狗跳", "15");
    // 移除了奖金金额、奖金来源和赞助者选项
    menu_setprop(g_iMenus[MENU_MATCH_SETTINGS], MPROP_BACKNAME, "上一页")
    menu_setprop(g_iMenus[MENU_MATCH_SETTINGS], MPROP_NEXTNAME, "下一页")
    menu_setprop(g_iMenus[MENU_MATCH_SETTINGS], MPROP_EXITNAME, "\r关闭")
    menu_setprop(g_iMenus[MENU_MATCH_SETTINGS], MPROP_EXIT, MEXIT_ALL)

    // 管理主菜单
    g_iMenus[MENU_MAIN_ADMIN] = menu_create("\r[管理系统] \w主菜单", "HandleMainAdminMenu");
    menu_additem(g_iMenus[MENU_MAIN_ADMIN], "\w踢人菜单", "1");
    menu_additem(g_iMenus[MENU_MAIN_ADMIN], "\w处死菜单", "2");
    menu_additem(g_iMenus[MENU_MAIN_ADMIN], "\w团队控制", "3");
    menu_additem(g_iMenus[MENU_MAIN_ADMIN], "\w换图菜单", "4");
    menu_setprop(g_iMenus[MENU_MAIN_ADMIN], MPROP_BACKNAME, "上一页")
    menu_setprop(g_iMenus[MENU_MAIN_ADMIN], MPROP_NEXTNAME, "下一页")
    menu_setprop(g_iMenus[MENU_MAIN_ADMIN], MPROP_EXITNAME, "\r关闭")
    menu_setprop(g_iMenus[MENU_MAIN_ADMIN], MPROP_EXIT, MEXIT_ALL)
}

// 初始化设置
InitSettings() {
    // 设置默认值
    copy(g_szCTTeamName, charsmax(g_szCTTeamName), "CT队");
    copy(g_szTTeamName, charsmax(g_szTTeamName), "T队");
    g_iMatchSize = 5;          // 默认5v5
    g_iRoundTime = 105;         // 默认1分45秒
    g_iFreezeTime = 10;         // 默认10秒
    g_iBuyTime = 10;            // 默认10秒
    g_iWinCondition = 15;       // 默认抢15
    g_bFriendlyFire = 1;        // 默认开启友伤
    g_iStartMoney = 800;        // 默认800起始金钱
    g_bDeadTalk = 1;            // 默认开启死亡语音
    g_iDeathCamera = 0;         // 默认主视角
    g_bOvertimeEnabled = 0;     // 默认关闭加时赛
    g_iMapTimeLimit = 45;       // 默认45分钟
    g_iC4Timer = 35;            // 默认35秒
    g_bBunnyHopDisabled = false; // 默认不禁止狗跳
    // 重置比赛状态
    g_iMatchState = MATCH_IDLE;
    g_iCTScore = 0;
    g_iTScore = 0;
    g_bMatchPointPlayed = false;
    
    // 重置demo录制状态
    g_bDemoRecording = false;
    g_szDemoFileName[0] = 0;
    
    // 重置BP状态
    g_iKnifeDuelWinner = 0;
    
    // 重置投票状态
    g_iCTVotes = 0;
    g_iTVotes = 0;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_bHasVoted[i] = false;
    }
    
    // 重置武器禁用状态
    for (new i = 0; i < MAX_WEAPONS; i++) {
        g_bWeaponBanned[i] = false;
    }
}

// 初始化OP密码系统
InitOpPasswordSystem() {
    // 创建动态数组存储已验证的管理员SteamID
    g_aOpAdmins = ArrayCreate(35); // SteamID最长为35个字符
    
    // 读取OP密码
    new szFilePath[128];
    get_configsdir(szFilePath, charsmax(szFilePath));
    format(szFilePath, charsmax(szFilePath), "%s/op_password.ini", szFilePath);
    
    // 打开文件
    new hFile = fopen(szFilePath, "rt");
    if (!hFile) {
        server_print("[Match System] 无法打开OP密码文件: %s", szFilePath);
        return;
    }
    
    // 读取OP密码
    new szBuffer[64];


    while (!feof(hFile)) 
    {
        fgets(hFile, szBuffer, charsmax(szBuffer));
        
        // 移除换行符
        trim(szBuffer);
        
        // 跳过空行和注释
        if (szBuffer[0] == 0 || szBuffer[0] == ';' || szBuffer[0] == '/' && szBuffer[1] == '/') {
            continue;
        }
        // 添加到OP密码列表
        copy(g_szOpPassword, charsmax(g_szOpPassword), szBuffer);
    }
    // 关闭文件
    fclose(hFile);
    
    server_print("[Match System] 已加载OP密码 %s", g_szOpPassword);
    
}


// 加载地图列表
LoadMapList() {
    // 从mapcycle.txt读取地图列表
    new szFilePath[128];
    get_configsdir(szFilePath, charsmax(szFilePath));
    format(szFilePath, charsmax(szFilePath), "%s/maps.ini", szFilePath);
    
    // 打开文件
    new hFile = fopen(szFilePath, "rt");
    if (!hFile) {
        server_print("[Match System] 无法打开地图列表文件: %s", szFilePath);
        return;
    }
    
    // 读取地图
    new szBuffer[64];
    g_iMapCount = 0;
    
    while (!feof(hFile) && g_iMapCount < MAX_MAPS) {
        fgets(hFile, szBuffer, charsmax(szBuffer));
        
        // 移除换行符
        trim(szBuffer);
        
        // 跳过空行和注释
        if (szBuffer[0] == 0 || szBuffer[0] == ';' || szBuffer[0] == '/' && szBuffer[1] == '/') {
            continue;
        }
        
        // 添加到地图列表
        copy(g_szMapList[g_iMapCount], charsmax(g_szMapList[]), szBuffer);
        g_iMapCount++;
    }
    
    // 关闭文件
    fclose(hFile);
    
    server_print("[Match System] 已加载 %d 张地图", g_iMapCount);
}

public OnPlayerSpawn(id)
{
// Not alive or didn't join a team yet
if (!is_user_alive(id))
return HAM_IGNORED

if (g_iMatchState == MATCH_BP) 
{
cs_set_user_money(id, 0);
cs_set_user_armor(id, 0, CS_ARMOR_NONE);
fm_strip_user_weapons(id); 
give_item(id,"weapon_knife");      
}
return HAM_IGNORED
}

// 比赛命令处理
public Cmd_Match(id) {
    // 检查权限
    if (!access(id, ADMIN_KICK)) {
        client_color(id, print_chat, "^x04[Match System] ^x01你没有权限使用此命令!");
        return PLUGIN_HANDLED;
    }
    // 显示比赛主菜单
    menu_display(id, g_iMenus[MENU_MAIN_MATCH]);
    
    return PLUGIN_HANDLED;
}

// 加入CT命令
public Cmd_JoinCT(id) {
    // 检查是否在BP阶段或空闲状态
    if (g_iMatchState != MATCH_BP && g_iMatchState != MATCH_IDLE) {
        client_color(id, print_chat, "^x04[Match System] ^x01当前不在BP阶段或空闲状态!");
        return PLUGIN_HANDLED;
    }
    
    
    // 设置为CT队长
    cs_set_user_team(id, CS_TEAM_CT);
    
    // 检查是否可以开始拼刀
    CheckKnifeDuel();
    
    return PLUGIN_HANDLED;
}

// 加入观察者命令
public Cmd_Joinob(id) {
    // 检查是否在BP阶段或空闲状态
    if (g_iMatchState != MATCH_BP && g_iMatchState != MATCH_IDLE) {
        client_color(id, print_chat, "^x04[Match System] ^x01当前不在BP阶段或空闲状态!");
        return PLUGIN_HANDLED;
    }
    
    if (cs_get_user_team(id) == CS_TEAM_SPECTATOR || cs_get_user_team(id) == CS_TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE;
    
    cs_set_user_team(id, CS_TEAM_SPECTATOR);

    // 确保玩家处于死亡状态
    if (is_user_alive(id)) {
        user_silentkill(id, 1);  // 1表示不计入死亡次数
    }

    new name[32];
    get_user_name(id, name, 31);
    client_color(0, print_chat, "^x04[Match System] ^x01 %s 已加入观察者!", name); 
    
    return PLUGIN_HANDLED;
}

// 加入T命令
public Cmd_JoinT(id) {
    // 检查是否在BP阶段或空闲状态
    if (g_iMatchState != MATCH_BP && g_iMatchState != MATCH_IDLE) {
        client_color(id, print_chat, "^x04[Match System] ^x01当前不在BP阶段或空闲状态!");
        return PLUGIN_HANDLED;
    }
    
    // 设置为T队长
    cs_set_user_team(id, CS_TEAM_T);
    
    // 检查是否可以开始拼刀
    CheckKnifeDuel();
    
    return PLUGIN_HANDLED;
}

CheckKnifeDuel() {
    // 检查双方是否有人
    new bool:hasCT = false;
    new bool:hasT = false;
    
    // 遍历所有玩家检查是否有CT和T
    for (new i = 1; i <= MaxClients; i++) {
        if (is_user_connected(i)) {
            new CsTeams:team = cs_get_user_team(i);
            if (team == CS_TEAM_CT) {
                hasCT = true;
            } else if (team == CS_TEAM_T) {
                hasT = true;
            }
            
            // 如果双方都有人，可以提前结束循环
            if (hasCT && hasT) {
                break;
            }
        }
    }
    
    // 如果双方都有人，就开始拼刀
    if (hasCT && hasT) {
        // 刷新回合准备拼刀
        client_color(0, print_chat, "^x04[Match System] ^x01CT和T都已就位，准备拼刀!");

        g_iMatchState = MATCH_BP;
    
        // 重置拼刀胜利者和拼刀次数
        g_iKnifeDuelWinner = 0;
        
        // 提示拼刀
        client_color(0, print_chat, "^x04[Match System] ^x01准备拼刀!");

        server_cmd("sv_restartround 1");
    }
}

// 开始拼刀
public StartKnifeDuel(id) {
    // 移除队长检查
    
    // 设置比赛状态为BP
    g_iMatchState = MATCH_BP;
    
    // 重置拼刀胜利者和拼刀次数
    g_iKnifeDuelWinner = 0;
    
    // 提示拼刀
    client_color(0, print_chat, "^x04[Match System] ^x01准备拼刀!");
    
    server_cmd("sv_restartround 1");
    
    return PLUGIN_HANDLED;
}

// 比赛主菜单处理
public HandleMainMatchMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id,name,31);

    switch (iChoice) {
        case 1: { // 开始比赛
            StartMatch(id);
        }
        case 2: { // 热身回合
            // 设置热身回合参数
            server_cmd("mp_startmoney 10000"); // 设置初始金额为10000
            server_cmd("mp_freezetime 0");    // 设置无冻结时间
            
            // 执行三次回合刷新
            set_task(1.0, "RestartRound", TASK_RESTART_ROUND, "1", 1);
            set_task(2.0, "RestartRound", TASK_RESTART_ROUND+1, "2", 1);
            set_task(3.0, "RestartRound", TASK_RESTART_ROUND+2, "3", 1);
            
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 执行了热身回合，初始金额设为10000", name);
        }
        case 3: { // 拼刀bp
            StartKnifeDuel(id);
        }
        case 4: { // 加时赛
           // 检查是否已开启加时赛
            if (g_bOvertimeEnabled) {
                client_color(id, print_chat, "^x04[Match System] ^x01加时赛已经开启!");
                return PLUGIN_HANDLED;
            }
            
            // 检查比分是否为15:15
            if (g_iCTScore != 15 || g_iTScore != 15) {
                client_color(id, print_chat, "^x04[Match System] ^x01只有在比分15:15时才能开启加时赛!");
                return PLUGIN_HANDLED;
            }
            
            // 开启加时赛
            g_bOvertimeEnabled = 1;
            StartOvertime();
            
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 开启了加时赛!", name);
        }
        case 5: { 
            // 强制结束比赛
            
            EndMatch(id, true);
        }
        case 6: { // 
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        }
        case 7: { // 
            SuperPauseMatch(id);
        }
        case 8: { // 管理菜单
            menu_display(id, g_iMenus[MENU_MAIN_ADMIN]);
        }
    }
    
    return PLUGIN_HANDLED;
}

// 比赛设置菜单1处理
public HandleMatchSettings1Menu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    
    switch (iChoice) {
        case 1: { // 队伍名称
            ShowTeamNameMenu(id);
        }
        case 2: { // 比赛人数
            ShowMatchSizeMenu(id);
        }
        case 3: { // 回合时间
            ShowRoundTimeMenu(id);
        }
        case 4: { // 冻结时间
            ShowFreezeTimeMenu(id);
        }
        case 5: { // 购买时间
            ShowBuyTimeMenu(id);
        }
         case 6: { // C4爆破时间
            ShowC4TimerMenu(id);
        }
        case 7: { // 地图时间
            ShowMapTimeMenu(id);
        }
        case 8: { // 加时赛选项
            ShowOvertimeMenu(id);
        }
        case 9: { // 胜利条件
            ShowWinConditionMenu(id);
        }
        case 10: { // 友军伤害
            ShowFriendlyFireMenu(id);
        }
        case 11: { // 禁用武器
            ShowWeaponBanMenu(id);
        }
        case 12: { // 初始金额
            ShowStartMoneyMenu(id);
        }
        case 13: { // 团队语音控制
            ShowDeadTalkMenu(id);
        }
        case 14: { // 死亡视角
            ShowDeathCameraMenu(id);
        }
        case 15: { // 禁止狗跳
            ShowBunnyHopMenu(id);
        }
    }
    
    return PLUGIN_HANDLED;
}


// 开始比赛
StartMatch(id) {
    // 检查设置是否完善
    if (!IsMatchSettingsComplete()) {
        client_color(id, print_chat, "^x04[Match System] ^x01当前比赛设置内容未完善，无法开启比赛!");
        return;
    }
    
    // 设置比赛状态
    g_iMatchState = MATCH_RUNNING;
    
    // 记录参与比赛的玩家
    for (new i = 1; i <= MaxClients; i++) {
        if (is_user_connected(i)) {
            new CsTeams:team = cs_get_user_team(i);
            if (team == CS_TEAM_CT || team == CS_TEAM_T) {
                g_bMatchPlayers[i] = true;
            } else {
                g_bMatchPlayers[i] = false;
            }
        } else {
            g_bMatchPlayers[i] = false;
        }
    }
    
    // 重置掉线玩家和暂停标记
    g_iDisconnectedPlayer = 0;
    g_bShouldPause = false;
    
    // 重置比分
    g_iCTScore = 0;
    g_iTScore = 0;
    g_bMatchPointPlayed = false;
    
    // 应用比赛设置
    ApplyMatchSettings();
    
    // 显示比赛开始信息
    new szMessage[256];
    format(szMessage, charsmax(szMessage), "【%s】vs【%s】^n比赛开启中！", g_szCTTeamName, g_szTTeamName);
    
    // 显示中央消息 - 增大字体并延长显示时间至5秒
    set_dhudmessage(0, 255, 0, -1.0, 0.35, 0, 6.0, 5.0, 0.1, 0.1);
    show_dhudmessage(0, szMessage);
    
    // 添加醒目的队伍对阵信息（屏幕中间）- 增大字体并延长显示时间至5秒
    set_dhudmessage(0, 255, 0, -1.0, 0.25, 2, 0.1, 5.0, 0.2, 0.2);
    show_dhudmessage(0, "【%s】vs【%s】", g_szCTTeamName, g_szTTeamName);
    
    // 构建比赛参数信息
    new szRoundTime[16]
    new iMinutes = g_iRoundTime / 60;
    new iSeconds = g_iRoundTime % 60;
    
    if (iSeconds > 0) {
        format(szRoundTime, charsmax(szRoundTime), "%dm%ds", iMinutes, iSeconds);
    } else {
        format(szRoundTime, charsmax(szRoundTime), "%dm", iMinutes);
    }
    
    // 显示比赛参数信息
    client_color(0, print_chat, "^x04[Match System] ^x01【^x04%s^x01】vs【^x04%s^x01】，抢^x04 %d ^x01，初始^x04 %d ^x01，冻结^x04 %d s^x01，回合时间^x04 %s ^x01",
        g_szCTTeamName, g_szTTeamName, g_iWinCondition, g_iStartMoney, g_iFreezeTime, szRoundTime);
    
    // 添加HUD显示（左下角长期显示）- 增大字体
    set_dhudmessage(0, 255, 0, 0.02, 0.9, 0, 0.0, 999999.0, 0.0, 0.0);
    show_dhudmessage(0, "【%s】vs【%s】 抢%d 回合时间%s", 
        g_szCTTeamName, g_szTTeamName, g_iWinCondition, szRoundTime);
    
    
    // 开始录制demo
    StartDemoRecording();
    
    // 多次刷新
    client_color(0, print_chat, "^x04[Match System] ^x01比赛即将开始，将进行3次刷新...");
    
    // 1秒后第一次刷新
    set_task(1.0, "RestartRound", TASK_RESTART_ROUND, "1", 1);
    
    // 3秒后第二次刷新
    set_task(3.0, "RestartRound", TASK_RESTART_ROUND+1, "2", 1);
    
    // 6秒后第三次刷新
    set_task(6.0, "RestartRound", TASK_RESTART_ROUND+2, "3", 1);
}

// 超级暂停
SuperPauseMatch(id) {
    // 检查权限
    if (!access(id, ADMIN_KICK)) {
        client_color(id, print_chat, "^x04[Match System] ^x01你没有权限暂停比赛!");
        return PLUGIN_HANDLED;
    }
    
    // 检查比赛状态
    if (g_iMatchState != MATCH_RUNNING && g_iMatchState != MATCH_SUPER_PAUSED) {
        client_color(id, print_chat, "^x04[Match System] ^x01当前没有进行中的比赛!");
        return PLUGIN_HANDLED;
    }

    if (pausable!=0)
	{
		g_pausAble = get_pcvar_float(pausable)
	}

    // 设置比赛状态
    if (g_iMatchState == MATCH_SUPER_PAUSED) 
    {
        // 恢复比赛
        g_iMatchState = MATCH_RUNNING;
        
        set_pcvar_float(pausable, 1.0)

        g_PauseAllowed = false
        // 找一个活着的玩家执行暂停命令
        new slayer = find_player("h");
        if (slayer) {
            client_cmd(slayer, "pause;pauseAck");
        } 
        // 显示消息
        client_color(0, print_chat, "^x04[Match System] ^x01『超级暂停』结束，比赛恢复!");
    } 
    else 
    {
        // 暂停比赛
        g_iMatchState = MATCH_SUPER_PAUSED;

        set_pcvar_float(pausable, 1.0)

        g_PauseAllowed = true

        // 找一个活着的玩家执行暂停命令
        new slayer = find_player("h");
        if (slayer) {
            client_cmd(slayer, "pause;pauseAck");
        } 
        client_color(0, print_chat, "^x04[Match System] ^x01当前比赛已开启『超级暂停』");
    }
    
    return PLUGIN_HANDLED;
}

// 结束比赛
EndMatch(id, bool:is_forced = false) {
    // 检查权限
    if (!access(id, ADMIN_KICK)) {
        client_color(id, print_chat, "^x04[Match System] ^x01你没有权限结束比赛!");
        return;
    }
    
    // 检查比赛状态
    if (g_iMatchState != MATCH_RUNNING && g_iMatchState != MATCH_PAUSED && g_iMatchState != MATCH_SUPER_PAUSED) {
        client_color(id, print_chat, "^x04[Match System] ^x01当前没有进行中的比赛!");
        return;
    }
    
    // 确定获胜队伍
    new szWinnerTeam[MAX_TEAM_NAME];
    new bool:is_draw = false;
    if (g_iCTScore > g_iTScore) {
        copy(szWinnerTeam, charsmax(szWinnerTeam), g_szCTTeamName);
    } else if (g_iTScore > g_iCTScore) {
        copy(szWinnerTeam, charsmax(szWinnerTeam), g_szTTeamName);
    } else {
        is_draw = true;
    }
    // 显示比赛结束信息
    if (is_forced) {
        client_color(0, print_chat, "^x04[Match System] ^x01当前比赛已被管理员强制结束!");
    } else if (is_draw) {
        client_color(0, print_chat, "^x04[Match System] ^x01当前比赛已结束，结果是【平局】!");
    } else {
        client_color(0, print_chat, "^x04[Match System] ^x01当前比赛已结束，让我们恭喜【%s】获得胜利，【%s】%d：%d【%s】!", szWinnerTeam, g_szCTTeamName, g_iCTScore, g_iTScore, g_szTTeamName);
    }
    

    // 停止录制demo
    StopDemoRecording();
    
    // 重置比赛状态
    g_iMatchState = MATCH_IDLE;
    
    // 重置参与比赛的玩家记录
    for (new i = 1; i <= MaxClients; i++) {
        g_bMatchPlayers[i] = false;
    }
    
    // 重置掉线玩家和暂停标记
    g_iDisconnectedPlayer = 0;
    g_bShouldPause = false;
    
    // 恢复默认设置
    RestoreDefaultSettings();
    
    // 刷新回合
    server_cmd("sv_restartround 1");
}

// 检查比赛设置是否完善
bool:IsMatchSettingsComplete() {
    // 检查必要设置
    if (g_szCTTeamName[0] == 0 || g_szTTeamName[0] == 0) {
        return false;
    }
    
    return true;
}

// 应用比赛设置
ApplyMatchSettings() {
    // 设置回合时间 - 修复为使用浮点数支持秒数
    server_cmd("mp_roundtime %.1f", float(g_iRoundTime) / 60.0);
    
    // 设置冻结时间
    server_cmd("mp_freezetime %d", g_iFreezeTime);
    
    // 设置购买时间
    server_cmd("mp_buytime %d", g_iBuyTime);
    
    // 设置友军伤害
    server_cmd("mp_friendlyfire %d", g_bFriendlyFire);
    
    // 设置初始金额
    server_cmd("mp_startmoney %d", g_iStartMoney);
    
    // 设置死亡语音
    server_cmd("sv_deadtalk %d", g_bDeadTalk);
    
    // 设置死亡视角
    server_cmd("mp_forcecamera %d", g_iDeathCamera);
    
    // 设置C4爆破时间
    server_cmd("mp_c4timer %d", g_iC4Timer);
    
    // 设置地图时间限制
    if (g_iMapTimeLimit > 0) {
        server_cmd("mp_timelimit %d", g_iMapTimeLimit);
    } else {
        server_cmd("mp_timelimit 0");
    }
    
    // 设置禁止狗跳
    if (g_bBunnyHopDisabled) {
        server_cmd("sv_airaccelerate 0");
        server_cmd("sv_maxspeed 320");
    } else {
        server_cmd("sv_airaccelerate 10");
        server_cmd("sv_maxspeed 320");
    }
}

// 恢复默认设置
RestoreDefaultSettings() {
    // 恢复默认设置
    server_cmd("exec server.cfg");
}


// 新回合事件
public Event_NewRound() {
    // 在比赛进行中时显示当前比分
    if (g_iMatchState == MATCH_RUNNING) {
        // 显示当前比分
        client_color(0, print_chat, "^x04[Match System] ^x01当前比分: 【%s】%d : %d【%s】", g_szCTTeamName, g_iCTScore, g_iTScore, g_szTTeamName);
        
        // 在HUD上也显示比分
        set_dhudmessage(0, 255, 0, -1.0, 0.2, 0, 6.0, 5.0, 0.1, 0.1);
        show_dhudmessage(0, "当前比分\n【%s】%d : %d【%s】", g_szCTTeamName, g_iCTScore, g_iTScore, g_szTTeamName);
    }
    
    // 检查是否为赛点局
    if (g_iMatchState == MATCH_RUNNING && !g_bMatchPointPlayed) {
        // 检查是否达到赛点
        if ((g_iCTScore == g_iWinCondition - 1 && g_iTScore == g_iWinCondition - 1) ||
            g_iCTScore == g_iWinCondition - 1 || g_iTScore == g_iWinCondition - 1) {
            // 播放赛点音乐
            client_cmd(0, "spk sound/match_system/match_point.wav");
            
            // 显示赛点提示
            set_dhudmessage(255, 255, 0, -1.0, 0.35, 0, 6.0, 5.0);
            show_dhudmessage(0, "当前已到【赛点局】，祝您和队友旗开得胜！");
            
            // 标记已播放赛点音乐
            g_bMatchPointPlayed = true;
        }
    }
    
    // 加时赛第4回合换边
    if (g_iMatchState == MATCH_RUNNING && g_bOvertimeEnabled && g_iWinCondition == 6) {
        // 计算当前回合数（CT得分+T得分+1）
        new iCurrentRound = g_iCTScore + g_iTScore + 1;
        
        // 如果是第4回合，执行换边
        if (iCurrentRound == 4) {
            client_color(0, print_chat, "^x04[Match System] ^x01加时赛第4回合，双方交换阵营！");
            SwapTeams();
        }
    }
    
    // 如果比赛处于暂停状态，确保显示暂停消息
    if (g_iMatchState == MATCH_PAUSED) {
        client_color(0, print_chat, "^x04[Match System] ^x01当前比赛处于『暂停』状态");
    }
    else if (g_iMatchState == MATCH_SUPER_PAUSED) {
        client_color(0, print_chat, "^x04[Match System] ^x01当前比赛处于『超级暂停』状态");
    }
}

// 队伍得分事件
public Event_TeamScore() {
    // 获取队伍和分数
    new szTeam[32], iScore;
    read_data(1, szTeam, charsmax(szTeam));
    iScore = read_data(2);
    
    // 更新比分
    if (equal(szTeam, "CT")) {
        g_iCTScore = iScore;
    } else if (equal(szTeam, "TERRORIST")) {
        g_iTScore = iScore;
    }
    
    // 检查是否达到胜利条件
    if (g_iMatchState == MATCH_RUNNING) {
        // 检查是否需要加时赛
        if (g_iCTScore == g_iWinCondition && g_iTScore == g_iWinCondition && g_bOvertimeEnabled) {
            // 启动加时赛
            StartOvertime();
            return;
        }
        
        if (g_iCTScore >= g_iWinCondition || g_iTScore >= g_iWinCondition) {
            // 自动结束比赛
            new id = find_player("h", 1);  // 找一个有ADMIN_KICK权限的玩家
            if (id) {
                EndMatch(id, false); // 使用默认参数 is_forced = false
            }
        }
    }
}

// 开始加时赛
StartOvertime() {
    // 显示加时赛开始消息
    client_color(0, print_chat, "^x04[Match System] ^x01比分15:15，进入加时赛！");
    
    // 设置初始金额为10000
    server_cmd("mp_startmoney 10000");
    
    // 重置比分为0:0
    g_iCTScore = 0;
    g_iTScore = 0;
    
    // 设置胜利条件为6
    g_iWinCondition = 6;
    
    // 显示加时赛信息
    set_dhudmessage(255, 255, 0, -1.0, 0.35, 0, 6.0, 5.0);
    show_dhudmessage(0, "加时赛开始！\n先得6分获胜，第4回合换边");
    
    // 多次刷新
    client_color(0, print_chat, "^x04[Match System] ^x01加时赛即将开始，将进行3次刷新...");
    
    // 1秒后第一次刷新
    set_task(1.0, "RestartRound", TASK_RESTART_ROUND, "1", 1);
    
    // 2秒后第二次刷新
    set_task(2.0, "RestartRound", TASK_RESTART_ROUND+1, "2", 1);
    
    // 3秒后第三次刷新
    set_task(3.0, "RestartRound", TASK_RESTART_ROUND+2, "3", 1);
}

// 回合结束事件
public Event_RoundEnd() {
    // 在比赛状态下更新比分
    if (g_iMatchState == MATCH_RUNNING) {
        // 比分更新逻辑在Event_TeamScore中处理
        
        // 检查是否需要暂停比赛
        if (g_bShouldPause) {
            // 重置标记
            g_bShouldPause = false;
            
            // 自动暂停比赛
            new id = find_player("h", 1);  // 找一个有ADMIN_KICK权限的玩家
            if (id) {
                // 设置比赛状态为暂停
                
                // 获取掉线玩家名称
                new szName[MAX_NAME_LENGTH];
                get_user_name(g_iDisconnectedPlayer, szName, charsmax(szName));
                
                // 显示消息
                client_color(0, print_chat, "^x04[Match System] ^x01由于玩家 %s 掉线，比赛已自动暂停", szName);
                SuperPauseMatch(id)
                // 刷新回合
                //server_cmd("sv_restartround 1");
            }
        }
    }
}

public slaylosers_ct()
{
if (g_iMatchState != MATCH_BP) return;
client_color(0, print_chat, "^x04[Match System] ^x01 T阵营拼刀获胜，开始地图投票!");

new players[32], playersnum
static CsTeams:team
g_iKnifeDuelWinner = 1
get_players(players,playersnum)
for(new a = 0; a < playersnum; ++a)
{
team = cs_get_user_team(players[a])
if (team == CS_TEAM_T && !is_user_bot(players[a]))
{
StartMapVote();
}
}
}

public slaylosers_t()
{
if (g_iMatchState != MATCH_BP) return;
client_color(0, print_chat, "^x04[Match System] ^x01 CT阵营拼刀获胜，开始地图投票!");
new players[32], playersnum
static CsTeams:team
g_iKnifeDuelWinner = 2
get_players(players,playersnum)

for(new a = 0; a < playersnum; ++a)
{
team = cs_get_user_team(players[a])
if (team == CS_TEAM_CT && !is_user_bot(players[a]))
{
StartMapVote();
}
}
}

// 客户端命令前置过滤器
public Forward_ClientCommand(id) {
    // 如果比赛进行中，禁止使用/bp命令
    if (g_iMatchState == MATCH_RUNNING || g_iMatchState == MATCH_PAUSED || g_iMatchState == MATCH_SUPER_PAUSED) {
        new szCommand[32];
        read_argv(0, szCommand, charsmax(szCommand));
        
        if (equal(szCommand, "say")) {
            new szArg[32];
            read_argv(1, szArg, charsmax(szArg));
            
            if (equal(szArg, "/bp")) {
                client_color(id, print_chat, "^x04[Match System] ^x01比赛进行中，无法使用BP功能!");
                return FMRES_SUPERCEDE;
            }
        }
    }
    
    return FMRES_IGNORED;
}

// 显示队伍名称菜单
ShowTeamNameMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置队伍名称", "HandleTeamNameMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "\wCT队伍名称: %s", g_szCTTeamName);
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "\wT队伍名称: %s", g_szTTeamName);
    menu_additem(menu, szItem, "2");

    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    // 显示菜单
    menu_display(id, menu);
}

// 处理队伍名称菜单
public HandleTeamNameMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    
    switch (iChoice) {
        case 1: { // CT队伍名称
            client_cmd(id, "messagemode 输入CT队伍名称");
            client_color(id, print_chat, "^x04[Match System] ^x01请输入CT队伍名称");
        }
        case 2: { // T队伍名称
            client_cmd(id, "messagemode 输入T队伍名称");
            client_color(id, print_chat, "^x04[Match System] ^x01请输入T队伍名称");
        }
        case 0: { // 返回
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        }
    }
    
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

// 显示比赛人数菜单
ShowMatchSizeMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置比赛人数", "HandleMatchSizeMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s3V3", g_iMatchSize == 3 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s4V4", g_iMatchSize == 4 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s5V5", g_iMatchSize == 5 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理比赛人数菜单
public HandleMatchSizeMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    
    switch (iChoice) {
        case 1: { // 3V3
            g_iMatchSize = 3;
            client_color(0, print_chat, "^x04[Match System] ^x01比赛人数已设置为3V3");
        }
        case 2: { // 4V4
            g_iMatchSize = 4;
            client_color(0, print_chat, "^x04[Match System] ^x01比赛人数已设置为4V4");
        }
        case 3: { // 5V5
            g_iMatchSize = 5;
            client_color(0, print_chat, "^x04[Match System] ^x01比赛人数已设置为5V5");
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowMatchSizeMenu(id);
    return PLUGIN_HANDLED;
}

// 显示回合时间菜单
ShowRoundTimeMenu(id) {
    new menu = menu_create("\r[比赛系统] \w设置回合时间", "HandleRoundTimeMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s1分35秒", g_iRoundTime == 95 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s1分40秒", g_iRoundTime == 100 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s1分45秒", g_iRoundTime == 105 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理回合时间菜单
public HandleRoundTimeMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    new szRoundTime[16];
    
    switch (iChoice) {
        case 1: { // 1分35秒
            g_iRoundTime = 95;
            format(szRoundTime, charsmax(szRoundTime), "1m35s");
        }
        case 2: { // 1分40秒
            g_iRoundTime = 100;
            format(szRoundTime, charsmax(szRoundTime), "1m40s");
        }
        case 3: { // 1分45秒
            g_iRoundTime = 105;
            format(szRoundTime, charsmax(szRoundTime), "1m45s");
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    // 向所有玩家发送通知
    client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将回合时间设置为^x04 %s", szPlayerName, szRoundTime);
    
    menu_destroy(menu);
    ShowRoundTimeMenu(id);
    return PLUGIN_HANDLED;
}

// 显示冻结时间菜单
ShowFreezeTimeMenu(id) {
    new menu = menu_create("\r[比赛系统] \w设置冻结时间", "HandleFreezeTimeMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s8秒", g_iFreezeTime == 8 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s10秒", g_iFreezeTime == 10 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理冻结时间菜单
public HandleFreezeTimeMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 8秒
            g_iFreezeTime = 8;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将冻结时间设置为^x04 8秒", szPlayerName);
        }
        case 2: { // 10秒
            g_iFreezeTime = 10;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将冻结时间设置为^x04 10秒", szPlayerName);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowFreezeTimeMenu(id);
    return PLUGIN_HANDLED;
}

// 显示购买时间菜单
ShowBuyTimeMenu(id) {
    new menu = menu_create("\r[比赛系统] \w设置购买时间", "HandleBuyTimeMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s8秒", g_iBuyTime == 8 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s10秒", g_iBuyTime == 10 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s15秒", g_iBuyTime == 15 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 显示C4爆破时间菜单
ShowC4TimerMenu(id) {
    new menu = menu_create("\r[比赛系统] \w设置C4爆破时间", "HandleC4TimerMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s30秒", g_iC4Timer == 30 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s35秒", g_iC4Timer == 35 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s40秒", g_iC4Timer == 40 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理C4爆破时间菜单
public HandleC4TimerMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 30秒
            g_iC4Timer = 30;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将C4爆破时间设置为^x04 30秒", szPlayerName);
        }
        case 2: { // 35秒
            g_iC4Timer = 35;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将C4爆破时间设置为^x04 35秒", szPlayerName);
        }
        case 3: { // 40秒
            g_iC4Timer = 40;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将C4爆破时间设置为^x04 40秒", szPlayerName);
        }
    }
    
    menu_destroy(menu);
    ShowC4TimerMenu(id);
    return PLUGIN_HANDLED;
}

// 显示地图时间菜单
ShowMapTimeMenu(id) {
    new menu = menu_create("\r[比赛系统] \w设置地图时间限制", "HandleMapTimeMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s无限制", g_iMapTimeLimit == 0 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s45分钟", g_iMapTimeLimit == 45 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s60分钟", g_iMapTimeLimit == 60 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理地图时间菜单
public HandleMapTimeMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 无限制
            g_iMapTimeLimit = 0;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将地图时间设置为^x04 无限制", szPlayerName);
        }
        case 2: { // 45分钟
            g_iMapTimeLimit = 45;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将地图时间设置为^x04 45分钟", szPlayerName);
        }
        case 3: { // 60分钟
            g_iMapTimeLimit = 60;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将地图时间设置为^x04 60分钟", szPlayerName);
        }
    }
    
    menu_destroy(menu);
    ShowMapTimeMenu(id);
    return PLUGIN_HANDLED;
}

// 显示加时赛选项菜单
ShowOvertimeMenu(id) {
    new menu = menu_create("\r[比赛系统] \w设置加时赛选项", "HandleOvertimeMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s开启加时赛", g_bOvertimeEnabled ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s关闭加时赛", !g_bOvertimeEnabled ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理加时赛选项菜单
public HandleOvertimeMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 开启
            g_bOvertimeEnabled = 1;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 已^x04开启^x01加时赛", szPlayerName);
        }
        case 2: { // 关闭
            g_bOvertimeEnabled = 0;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 已^x04关闭^x01加时赛", szPlayerName);
        }
    }
    
    menu_destroy(menu);
    ShowOvertimeMenu(id);
    return PLUGIN_HANDLED;
}

// 处理购买时间菜单
public HandleBuyTimeMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id,name,31);

    switch (iChoice) {
        case 1: { // 5秒
            g_iBuyTime = 5;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将购买时间已设置为5秒", name);
        }
        case 2: { // 10秒
            g_iBuyTime = 10;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将购买时间已设置为10秒", name);
        }
        case 3: { // 15秒
            g_iBuyTime = 15;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将购买时间已设置为15秒", name);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowBuyTimeMenu(id);
    return PLUGIN_HANDLED;
}

// 显示胜利条件菜单
ShowWinConditionMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置胜利条件", "HandleWinConditionMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s抢7", g_iWinCondition == 7 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s抢10", g_iWinCondition == 10 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s抢15", g_iWinCondition == 15 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理胜利条件菜单
public HandleWinConditionMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 抢7
            g_iWinCondition = 7;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将胜利条件设置为抢^x04 7 ^x01局", szPlayerName);
        }
        case 2: { // 抢10
            g_iWinCondition = 10;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将胜利条件设置为抢^x04 10 ^x01局", szPlayerName);
        }
        case 3: { // 抢15
            g_iWinCondition = 15;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将胜利条件设置为抢^x04 15 ^x01局", szPlayerName);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowWinConditionMenu(id);
    return PLUGIN_HANDLED;
}

// 显示友军伤害菜单
ShowFriendlyFireMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置友军伤害", "HandleFriendlyFireMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s开启", g_bFriendlyFire ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s关闭", g_bFriendlyFire ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理友军伤害菜单
public HandleFriendlyFireMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 开启
            g_bFriendlyFire = 1;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将友军伤害设置为^x04 开启", szPlayerName);
        }
        case 2: { // 关闭
            g_bFriendlyFire = 0;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将友军伤害设置为^x04 关闭", szPlayerName);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowFriendlyFireMenu(id);
    return PLUGIN_HANDLED;
}

// 显示武器禁用菜单
ShowWeaponBanMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w禁用武器", "HandleWeaponBanMenu");
    
    // 添加菜单项
    new szItem[64];
    
    // 主武器
    format(szItem, charsmax(szItem), "%sAK-47", g_bWeaponBanned[CSW_AK47] ? "\d" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%sM4A1", g_bWeaponBanned[CSW_M4A1] ? "\d" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%sAWP", g_bWeaponBanned[CSW_AWP] ? "\d" : "\w");
    menu_additem(menu, szItem, "3");
    
    format(szItem, charsmax(szItem), "%sScout", g_bWeaponBanned[CSW_SCOUT] ? "\d" : "\w");
    menu_additem(menu, szItem, "4");
    
    format(szItem, charsmax(szItem), "%s连狙", (g_bWeaponBanned[CSW_G3SG1] || g_bWeaponBanned[CSW_SG550]) ? "\d" : "\w");
    menu_additem(menu, szItem, "5");
    
    // 手枪
    format(szItem, charsmax(szItem), "%sDeagle", g_bWeaponBanned[CSW_DEAGLE] ? "\d" : "\w");
    menu_additem(menu, szItem, "6");
    
    // 其他
    format(szItem, charsmax(szItem), "%s手雷", g_bWeaponBanned[CSW_HEGRENADE] ? "\d" : "\w");
    menu_additem(menu, szItem, "7");
    
    format(szItem, charsmax(szItem), "%s闪光弹", g_bWeaponBanned[CSW_FLASHBANG] ? "\d" : "\w");
    menu_additem(menu, szItem, "8");
    
    format(szItem, charsmax(szItem), "%s烟雾弹", g_bWeaponBanned[CSW_SMOKEGRENADE] ? "\d" : "\w");
    menu_additem(menu, szItem, "9");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理武器禁用菜单
public HandleWeaponBanMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    new name[32];
    get_user_name(id,name,31);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    
    switch (iChoice) {
        case 1: { // AK-47
            new bCurrentState = g_bWeaponBanned[CSW_AK47];
            g_bWeaponBanned[CSW_AK47] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将AK-47 已%s", name, g_bWeaponBanned[CSW_AK47] ? "禁用" : "启用");
        }
        case 2: { // M4A1
            new bCurrentState = g_bWeaponBanned[CSW_M4A1];
            g_bWeaponBanned[CSW_M4A1] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将M4A1 已%s", name, g_bWeaponBanned[CSW_M4A1] ? "禁用" : "启用");
        }
        case 3: { // AWP
            new bCurrentState = g_bWeaponBanned[CSW_AWP];
            g_bWeaponBanned[CSW_AWP] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将AWP 已%s", name, g_bWeaponBanned[CSW_AWP] ? "禁用" : "启用");
        }
        case 4: { // Scout
            new bCurrentState = g_bWeaponBanned[CSW_SCOUT];
            g_bWeaponBanned[CSW_SCOUT] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将Scout 已%s", name, g_bWeaponBanned[CSW_SCOUT] ? "禁用" : "启用");
        }
        case 5: { // Auto-Sniper
            new bCurrentState = g_bWeaponBanned[CSW_G3SG1];
            g_bWeaponBanned[CSW_G3SG1] = !bCurrentState;
            g_bWeaponBanned[CSW_SG550] = bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将自动狙击枪 已%s", name, g_bWeaponBanned[CSW_G3SG1] ? "禁用" : "启用");
        }
        case 6: { // Deagle
            new bCurrentState = g_bWeaponBanned[CSW_DEAGLE];
            g_bWeaponBanned[CSW_DEAGLE] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将沙漠之鹰 已%s", name, g_bWeaponBanned[CSW_DEAGLE] ? "禁用" : "启用");
        }
        case 7: { // 手雷
            new bCurrentState = g_bWeaponBanned[CSW_HEGRENADE];
            g_bWeaponBanned[CSW_HEGRENADE] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将手雷 已%s", name, g_bWeaponBanned[CSW_HEGRENADE] ? "禁用" : "启用");
        }
        case 8: { // 闪光弹
            new bCurrentState = g_bWeaponBanned[CSW_FLASHBANG];
            g_bWeaponBanned[CSW_FLASHBANG] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将闪光弹 已%s", name, g_bWeaponBanned[CSW_FLASHBANG] ? "禁用" : "启用");
        }
        case 9: { // 烟雾弹
            new bCurrentState = g_bWeaponBanned[CSW_SMOKEGRENADE];
            g_bWeaponBanned[CSW_SMOKEGRENADE] = !bCurrentState;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将烟雾弹 已%s", name, g_bWeaponBanned[CSW_SMOKEGRENADE] ? "禁用" : "启用");
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowWeaponBanMenu(id);
    return PLUGIN_HANDLED;
}

// 显示初始金额菜单
ShowStartMoneyMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置初始金额", "HandleStartMoneyMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s$800", g_iStartMoney == 800 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s$1000", g_iStartMoney == 1000 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    format(szItem, charsmax(szItem), "%s$3000", g_iStartMoney == 3000 ? "\r" : "\w");
    menu_additem(menu, szItem, "3");
    
    format(szItem, charsmax(szItem), "%s$5000", g_iStartMoney == 5000 ? "\r" : "\w");
    menu_additem(menu, szItem, "4");
    
    format(szItem, charsmax(szItem), "%s$10000", g_iStartMoney == 10000 ? "\r" : "\w");
    menu_additem(menu, szItem, "5");
    
    format(szItem, charsmax(szItem), "%s$16000", g_iStartMoney == 16000 ? "\r" : "\w");
    menu_additem(menu, szItem, "6");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理初始金额菜单
public HandleStartMoneyMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id,name,31);
    
    switch (iChoice) {
        case 1: { // $800
            g_iStartMoney = 800;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将初始金额已设置为^x04$800", name);
        }
        case 2: { // $1000
            g_iStartMoney = 1000;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将初始金额已设置为^x04$1000", name);
        }
        case 3: { // $3000
            g_iStartMoney = 3000;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将初始金额已设置为^x04$3000", name);
        }
        case 4: { // $5000
            g_iStartMoney = 5000;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将初始金额已设置为^x04$5000", name);
        }
        case 5: { // $10000
            g_iStartMoney = 10000;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将初始金额已设置为^x04$10000", name);
        }
        case 6: { // $16000
            g_iStartMoney = 16000;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将初始金额已设置为^x04$16000", name);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowStartMoneyMenu(id);
    return PLUGIN_HANDLED;
}

// 显示团队语音控制菜单
ShowDeadTalkMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置团队语音控制", "HandleDeadTalkMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s开启(死后可与队友通话)", g_bDeadTalk ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s关闭(死后不可与队友通话)", !g_bDeadTalk ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理团队语音控制菜单
public HandleDeadTalkMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id,name,31);
    
    switch (iChoice) {
        case 1: { // 开启
            g_bDeadTalk = 1;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将团队语音控制已开启(死后可与队友通话)", name);
        }
        case 2: { // 关闭
            g_bDeadTalk = 0;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将团队语音控制已关闭(死后不可与队友通话)", name);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowDeadTalkMenu(id);
    return PLUGIN_HANDLED;
}

// 显示死亡视角菜单
ShowDeathCameraMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置死亡视角", "HandleDeathCameraMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s队友主视角", g_iDeathCamera == 0 ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s队友全部视角", g_iDeathCamera == 1 ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 显示禁止狗跳菜单
ShowBunnyHopMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[比赛系统] \w设置禁止狗跳", "HandleBunnyHopMenu");
    
    // 添加菜单项
    new szItem[64];
    format(szItem, charsmax(szItem), "%s开启禁止", g_bBunnyHopDisabled ? "\r" : "\w");
    menu_additem(menu, szItem, "1");
    
    format(szItem, charsmax(szItem), "%s关闭禁止", !g_bBunnyHopDisabled ? "\r" : "\w");
    menu_additem(menu, szItem, "2");
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页")
    menu_setprop(menu, MPROP_NEXTNAME, "下一页")
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭")
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理死亡视角菜单
public HandleDeathCameraMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id,name,31);
    
    switch (iChoice) {
        case 1: { // 队友主视角
            g_iDeathCamera = 0;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将死亡视角已设置为队友主视角", name);
        }
        case 2: { // 队友全部视角
            g_iDeathCamera = 1;
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 将死亡视角已设置为队友全部视角", name);
        }
        case 0: { // 返回
            menu_destroy(menu);
            menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
            return PLUGIN_HANDLED;
        }
    }
    
    menu_destroy(menu);
    ShowDeathCameraMenu(id);
    return PLUGIN_HANDLED;
}

// 处理禁止狗跳菜单
public HandleBunnyHopMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        menu_display(id, g_iMenus[MENU_MATCH_SETTINGS]);
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new szPlayerName[MAX_NAME_LENGTH];
    get_user_name(id, szPlayerName, charsmax(szPlayerName));
    
    switch (iChoice) {
        case 1: { // 开启禁止
            g_bBunnyHopDisabled = true;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 已^x04开启^x01禁止狗跳", szPlayerName);
            // 如果比赛正在进行，立即应用设置
            if (g_iMatchState == MATCH_RUNNING) {
                server_cmd("sv_airaccelerate 0");
                server_cmd("sv_maxspeed 320");
            }
        }
        case 2: { // 关闭禁止
            g_bBunnyHopDisabled = false;
            // 向所有玩家发送通知
            client_color(0, print_chat, "^x04[Match System] ^x01管理员 %s 已^x04关闭^x01禁止狗跳", szPlayerName);
            // 如果比赛正在进行，立即应用设置
            if (g_iMatchState == MATCH_RUNNING) {
                server_cmd("sv_airaccelerate 10");
                server_cmd("sv_maxspeed 320");
            }
        }
    }
    
    menu_destroy(menu);
    ShowBunnyHopMenu(id);
    return PLUGIN_HANDLED;
}

// 开始地图投票
StartMapVote() {
    // 重置投票状态
    for (new i = 0; i < g_iMapCount; i++) {
        g_iMapVotes[i] = 0;
    }
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_bHasMapVoted[i] = false;
    }

    // 向所有获胜方玩家显示投票菜单
    for (new i = 1; i <= MaxClients; i++) {
        if (is_user_connected(i) && cs_get_user_team(i) == CsTeams:g_iKnifeDuelWinner) {
            ShowMapVoteMenu(i);
        }
    }
    
    // 通知所有玩家
    client_color(0, print_chat, "^x04[Match System] ^x01获胜方玩家正在投票选择地图...");
}

// 显示地图投票菜单
ShowMapVoteMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[BP系统] \w请投票选择比赛地图", "HandleMapVoteMenu");
    
    // 添加地图到菜单
    for (new i = 0; i < g_iMapCount; i++) {
        new szItem[10];
        num_to_str(i, szItem, charsmax(szItem));
        menu_additem(menu, g_szMapList[i], szItem);
    }
    
    menu_setprop(menu, MPROP_BACKNAME, "上一页");
    menu_setprop(menu, MPROP_NEXTNAME, "下一页");
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭");
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理地图投票菜单
public HandleMapVoteMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id, name, 31);

    // 如果玩家已经投过票，不再计票
    if (g_bHasMapVoted[id]) {
        client_color(id, print_chat, "^x04[Match System] ^x01您已经投过票了!");
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    // 记录玩家已投票
    g_bHasMapVoted[id] = true;
    
    // 增加对应地图的票数
    g_iMapVotes[iChoice]++;
    
    // 显示投票信息
    client_color(0, print_chat, "^x04[Match System] ^x01 %s 投票选择地图: %s!", name, g_szMapList[iChoice]);
    
    // 检查是否所有玩家都已投票
    new bool:allVoted = true;
    new playerCount = 0;

    for (new i = 1; i <= MaxClients; i++) {
        if (is_user_connected(i) && cs_get_user_team(i) == CsTeams:g_iKnifeDuelWinner) {
            playerCount++;
            if (!g_bHasMapVoted[i]) {
                allVoted = false;
                break;
            }
        }
    }
    
    // 如果所有玩家都已投票，或者已经有超过半数的票，确定最终地图
    new maxVotes = 0;
    new selectedMap = 0;
    
    if (allVoted || playerCount > 0 && playerCount / 2 < GetMaxVotedMap(maxVotes, selectedMap)) {
        // 根据投票结果确定地图
        copy(g_szSelectedMap, charsmax(g_szSelectedMap), g_szMapList[selectedMap]);
        
        // 显示投票结果
        client_color(0, print_chat, "^x04[Match System] ^x01投票结果：选择了地图 %s! (得票数: %d)", g_szSelectedMap, maxVotes);
        
        // 显示阵营选择菜单给拼刀胜利者
        ShowSideVoteMenu(id)
        
    }
    
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

// 获取得票最多的地图
GetMaxVotedMap(&maxVotes, &selectedMap) {
    maxVotes = 0;
    selectedMap = 0;
    
    for (new i = 0; i < g_iMapCount; i++) {
        if (g_iMapVotes[i] > maxVotes) {
            maxVotes = g_iMapVotes[i];
            selectedMap = i;
        }
    }
    
    return maxVotes;
}



// 处理阵营选择菜单
public HandleSideSelectMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id, name, 31);
    // 移除未使用的变量 team

    switch (iChoice) {
        case 1: { // CT
            // 简化队伍选择逻辑
            cs_set_user_team(id, CS_TEAM_CT);
            client_color(0, print_chat, "^x04[Match System] ^x01 %s 选择了CT阵营!", name);
            
            // 开始阵营投票
            StartSideVote();
        }
        case 2: { // T
            // 简化队伍选择逻辑
            cs_set_user_team(id, CS_TEAM_T);
            client_color(0, print_chat, "^x04[Match System] ^x01 %s 选择了T阵营!", name);
            
            // 开始阵营投票
            StartSideVote();
        }
    }
    
    // 刷新回合
    server_cmd("sv_restartround 1");
    
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

// 开始阵营投票
StartSideVote() {
    // 重置投票状态
    g_iCTVotes = 0;
    g_iTVotes = 0;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_bHasVoted[i] = false;
    }

    // 向所有拼刀获胜方玩家显示投票菜单
    for (new i = 1; i <= MaxClients; i++) {
        if (is_user_connected(i) && cs_get_user_team(i) == CsTeams:g_iKnifeDuelWinner) {
            ShowSideVoteMenu(i);
        }
    }
    
    // 通知所有玩家
    client_color(0, print_chat, "^x04[Match System] ^x01玩家正在投票选择初始阵营...");
}

// 显示阵营投票菜单
ShowSideVoteMenu(id) {
    // 创建菜单
    new menu = menu_create("\r[BP系统] \w请投票选择初始阵营", "HandleSideVoteMenu");
    
    // 添加菜单项
    menu_additem(menu, "\wCT", "1");
    menu_additem(menu, "\wTT", "2");
    menu_setprop(menu, MPROP_BACKNAME, "上一页");
    menu_setprop(menu, MPROP_NEXTNAME, "下一页");
    menu_setprop(menu, MPROP_EXITNAME, "\r关闭");
    
    // 显示菜单
    menu_display(id, menu);
}

// 处理阵营投票菜单
public HandleSideVoteMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    new name[32];
    get_user_name(id, name, 31);

    // 如果玩家已经投过票，不再计票
    if (g_bHasVoted[id]) {
        client_color(id, print_chat, "^x04[Match System] ^x01您已经投过票了!");
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    // 记录玩家已投票
    g_bHasVoted[id] = true;
    
    switch (iChoice) {
        case 1: { // CT
            g_iCTVotes++;
            client_color(0, print_chat, "^x04[Match System] ^x01 %s 投票选择CT阵营!", name);
        }
        case 2: { // T
            g_iTVotes++;
            client_color(0, print_chat, "^x04[Match System] ^x01 %s 投票选择T阵营!", name);
        }
    }
    
    // 检查是否拼刀获胜方和他的队友都已投票
    new bool:allVoted = true;
    new teamCount = 0;

    
    for (new i = 1; i <= MaxClients; i++) {
        if (is_user_connected(i) && cs_get_user_team(i) == CsTeams:g_iKnifeDuelWinner) {

            teamCount++;
            if (!g_bHasVoted[i]) {
                allVoted = false;
                break;
            }
        }
    }
    
    // 如果拼刀获胜方和他的队友都已投票，或者已经有超过半数的票，确定最终阵营
    if (allVoted || g_iCTVotes > teamCount/2 || g_iTVotes > teamCount/2) {
        // 根据投票结果确定阵营
        if (g_iCTVotes >= g_iTVotes) {
            // CT方选择CT阵营
            client_color(0, print_chat, "^x04[Match System] ^x01投票结果：拼刀获胜方选择了CT阵营! (CT票数: %d, T票数: %d)", g_iCTVotes, g_iTVotes);
        } else {
            // CT方选择T阵营
            client_color(0, print_chat, "^x04[Match System] ^x01投票结果：拼刀获胜方选择了T阵营! (CT票数: %d, T票数: %d)", g_iCTVotes, g_iTVotes);
            
            // 交换所有玩家的阵营
            for (new i = 1; i <= MaxClients; i++) {
                if (is_user_connected(i)) {
                    if (cs_get_user_team(i) == CS_TEAM_CT) {
                        cs_set_user_team(i, CS_TEAM_T);
                    } else if (cs_get_user_team(i) == CS_TEAM_T) {
                        cs_set_user_team(i, CS_TEAM_CT);
                    }
                }
            }
        }
        
        // 刷新回合
        //server_cmd("sv_restartround 1");
        
        // 通知玩家10秒后切换地图
        client_color(0, print_chat, "^x04[Match System] ^x01将在10秒后切换到地图: %s", g_szSelectedMap);
        
        // 设置10秒后切换地图
        set_task(10.0, "ChangeToSelectedMap", TASK_CHANGE_MAP);
    }
    
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

// 交换两个队伍的所有成员
SwapTeams() {
    // 遍历所有玩家
    new tempScore = g_iCTScore;
    g_iCTScore = g_iTScore;
    g_iTScore = tempScore;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        // 检查玩家是否在线
        if (is_user_connected(i)) {
            // 获取玩家当前队伍
            new CsTeams:team = cs_get_user_team(i);
            
            // 交换队伍
            if (team == CS_TEAM_CT) {
                cs_set_user_team(i, CS_TEAM_T);
            } else if (team == CS_TEAM_T) {
                cs_set_user_team(i, CS_TEAM_CT);
            }
        }
    }
}

// 切换到选择的地图
public ChangeToSelectedMap() {
    if (g_szSelectedMap[0]) {
        server_cmd("changelevel %s", g_szSelectedMap);
    }
}

// 设置CT队伍名称
public Cmd_SetCTTeamName(id) {
    new szName[MAX_TEAM_NAME];
    read_args(szName, charsmax(szName));
    remove_quotes(szName);
    trim(szName);
    
    if (szName[0]) {
        copy(g_szCTTeamName, charsmax(g_szCTTeamName), szName);
        client_color(id, print_chat, "^x04[Match System] ^x01 CT队伍名称已设置为: %s", g_szCTTeamName);
    }
    
    return PLUGIN_HANDLED;
}

// 设置T队伍名称
public Cmd_SetTTeamName(id) {
    new szName[MAX_TEAM_NAME];
    read_args(szName, charsmax(szName));
    remove_quotes(szName);
    trim(szName);
    
    if (szName[0]) {
        copy(g_szTTeamName, charsmax(g_szTTeamName), szName);
        client_color(id, print_chat, "^x04[Match System] ^x01 T队伍名称已设置为: %s", g_szTTeamName);
    }
    
    return PLUGIN_HANDLED;
}

// 停止录制命令处理
public Cmd_StopDemo(id) {
    // 检查权限
    if (!access(id, ADMIN_KICK)) {
        client_color(id, print_chat, "^x04[Match System] ^x01 你没有权限停止demo录制!");
        return PLUGIN_HANDLED;
    }
    
    // 检查是否正在录制
    if (!g_bDemoRecording) {
        client_color(id, print_chat, "^x04[Match System] ^x01 当前没有正在录制的demo!");
        return PLUGIN_HANDLED;
    }
    
    // 停止录制
    StopDemoRecording();
    
    return PLUGIN_HANDLED;
}

// 管理菜单命令处理
public Cmd_Admin(id) {
    // 检查权限
    if (!access(id, ADMIN_KICK)) {
        client_color(id, print_chat, "^x04[Match System] ^x01你没有权限使用此命令!");
        return PLUGIN_HANDLED;
    }
    
    // 显示管理主菜单
    menu_display(id, g_iMenus[MENU_MAIN_ADMIN]);
    
    return PLUGIN_HANDLED;
}

// 管理主菜单处理
public HandleMainAdminMenu(id, menu, item) {
    // 菜单被关闭
    if (item == MENU_EXIT) {
        return PLUGIN_HANDLED;
    }
    
    // 获取菜单项信息
    new szData[6], szName[64];
    new _access, callback;
    menu_item_getinfo(menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), callback);
    
    // 处理菜单选择
    new iChoice = str_to_num(szData);
    
    switch (iChoice) {
        case 1: { // 踢人菜单
            client_cmd(id, "amx_kickmenu")
        }
        case 2: { // 处死菜单
            client_cmd(id, "amx_slapmenu")
        }
        case 3: { // 团队控制
            client_cmd(id, "amx_teammenu")
        }
        case 4: { // 换图菜单
            client_cmd(id, "amx_mapmenu")
        }
    }
    
    return PLUGIN_HANDLED;
}

// 开始录制demo
StartDemoRecording() {
    // 如果已经在录制，先停止
    if (g_bDemoRecording) {
        StopDemoRecording();
    }
    
    // 生成demo文件名（使用队伍名称和日期时间）
    new szMapName[32], szDate[32], szTime[32];
    get_mapname(szMapName, charsmax(szMapName));
    get_time("%Y%m%d", szDate, charsmax(szDate));
    get_time("%H%M%S", szTime, charsmax(szTime));
    
    // 格式化文件名
    format(g_szDemoFileName, charsmax(g_szDemoFileName), "%s_%s_%s", 
        szMapName, szDate, szTime);
    
    // 替换文件名中的非法字符
    replace_all(g_szDemoFileName, charsmax(g_szDemoFileName), " ", "_");
    replace_all(g_szDemoFileName, charsmax(g_szDemoFileName), "/", "-");
    replace_all(g_szDemoFileName, charsmax(g_szDemoFileName), "\\", "-");
    replace_all(g_szDemoFileName, charsmax(g_szDemoFileName), ":", "-");
    replace_all(g_szDemoFileName, charsmax(g_szDemoFileName), "*", "-");
    replace_all(g_szDemoFileName, charsmax(g_szDemoFileName), "?", "-");
    
    // 开始录制
    server_cmd("record %s", g_szDemoFileName);
    
    // 设置录制状态
    g_bDemoRecording = true;
    
    // 通知所有玩家
    client_color(0, print_chat, "^x04[Match System] ^x01 比赛demo录制已开始: %s.dem", g_szDemoFileName);
    client_color(0, print_chat, "^x04[Match System] ^x01 比赛队伍: 【%s】vs【%s】", g_szCTTeamName, g_szTTeamName);
}

// 停止录制demo
StopDemoRecording() {
    // 检查是否正在录制
    if (!g_bDemoRecording) {
        return;
    }
    
    // 停止录制
    server_cmd("stop");
    
    // 设置录制状态
    g_bDemoRecording = false;
    
    // 通知所有玩家
    client_color(0, print_chat, "^x04[Match System] ^x01 比赛demo录制已停止: %s.dem", g_szDemoFileName);
}

// 插件结束
public plugin_end() {
    
    // 释放动态数组
    if (g_aOpAdmins) {
        ArrayDestroy(g_aOpAdmins);
    }
}

// 玩家连接事件
public client_putinserver(id) {
    // 如果比赛正在进行中，新加入的玩家自动转为观察者
    if (g_iMatchState == MATCH_RUNNING || g_iMatchState == MATCH_PAUSED || g_iMatchState == MATCH_SUPER_PAUSED) {
        // 检查是否是之前断线的比赛玩家
        if (id == g_iDisconnectedPlayer) {
            // 获取玩家名称
            new szName[MAX_NAME_LENGTH];
            get_user_name(id, szName, charsmax(szName));
            
            // 重置断线玩家ID
            g_iDisconnectedPlayer = 0;
            
            // 如果当前是暂停状态，找一个管理员取消暂停
            if (g_iMatchState == MATCH_SUPER_PAUSED) {
                g_bShouldPause = false
                new admin = find_player("h", 1);  // 找一个有ADMIN_KICK权限的玩家
                if (admin) {
                    // 延迟一秒取消暂停，确保玩家完全加载
                    set_task(3.0, "SuperPauseMatch", admin);
                    client_color(0, print_chat, "^x04[Match System] ^x01比赛玩家 %s 已重新连接，比赛将在3秒后恢复", szName);
                }
            }
        } else {
            // 设置为观察者
            set_task(1.0, "SetPlayerToSpectator", id);
            
            // 通知玩家
            client_color(id, print_chat, "^x04[Match System] ^x01当前有比赛正在进行，您已被自动设置为观察者");
        }
    }
}

// 添加新函数确保玩家被设置为观察者
public SetPlayerToSpectator(id) {
    if (is_user_connected(id)) {
        cs_set_user_team(id, CS_TEAM_SPECTATOR);
        // 确保玩家处于死亡状态
        if (is_user_alive(id)) {
            user_silentkill(id, 1);  // 1表示不计入死亡次数
        }
    }
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
    // 如果比赛正在进行中，且断开连接的玩家是参与比赛的玩家
    if ((g_iMatchState == MATCH_RUNNING) && g_bMatchPlayers[id]) {
        // 记录断开连接的玩家
        g_iDisconnectedPlayer = id;
        
        // 获取玩家名称
        new szName[MAX_NAME_LENGTH];
        get_user_name(id, szName, charsmax(szName));
        
        // 通知所有玩家
        client_color(0, print_chat, "^x04[Match System] ^x01比赛玩家 %s 已断开连接，回合结束后将自动暂停比赛", szName);
        
        // 标记需要在回合结束后暂停
        g_bShouldPause = true;
    }
}

public client_color(playerid, colorid, const msg[], any:...)
{
static buffer[512]
vformat(buffer, charsmax(buffer), msg, 4)
message_begin(playerid?MSG_ONE:MSG_ALL,get_user_msgid("SayText"),{0,0,0},playerid)
write_byte(colorid)
write_string(buffer)
message_end()
}

// OP命令处理
public Cmd_Op(id) {
    // 检查玩家是否已经是OP
    if (IsPlayerOp(id)) {
        client_color(id, print_chat, "^x04[Match System] ^x01你已经是OP了!");
        return PLUGIN_HANDLED;
    }
    
    // 提示输入密码
    client_cmd(id, "messagemode 输入OP密码");
    client_color(id, print_chat, "^x04[Match System] ^x01请输入OP密码");
    
    return PLUGIN_HANDLED;
}

// 输入OP密码处理
public Cmd_EnterOpPassword(id) {
    // 读取输入的密码
    new szPassword[32];
    read_args(szPassword, charsmax(szPassword));
    remove_quotes(szPassword);
    trim(szPassword);
    
    // 检查密码是否正确
    if (equal(szPassword, g_szOpPassword)) {
        // 获取玩家SteamID
        new szAuthID[35];
        get_user_authid(id, szAuthID, charsmax(szAuthID));
        
        // 将玩家添加到OP列表
        ArrayPushString(g_aOpAdmins, szAuthID);
        
        // 授予管理员权限
        //set_user_flags(id, get_user_flags(id) | ADMIN_RCON);
        set_user_flags(id, read_flags("bcdefghijklmnopqrstu"))
        
        // 通知玩家
        client_color(id, print_chat, "^x04[Match System] ^x01密码正确，你现在是OP了!");
        
        // 记录日志
        new szName[32];
        get_user_name(id, szName, charsmax(szName));
        log_amx("[Match System] 玩家 %s (%s) 已通过OP密码验证", szName, szAuthID);
    } else {
        new szAuthID[35];
        new szName[32];
        get_user_name(id, szName, charsmax(szName));
        get_user_authid(id, szAuthID, charsmax(szAuthID));
        // 密码错误
        client_color(id, print_chat, "^x04[Match System] ^x01密码错误!");
        // 记录日志
        log_amx("[Match System] 玩家 %s (%s) 输入错误的OP密码 %s 正确密码为 %s", szName, szAuthID, szPassword, g_szOpPassword);


    }
    
    return PLUGIN_HANDLED;
}

// 检查玩家是否是OP
bool:IsPlayerOp(id) {
    // 检查玩家是否有ADMIN_RCON权限
    if (get_user_flags(id) & ADMIN_RCON) {
        return true;
    }
    
    // 获取玩家SteamID
    new szAuthID[35];
    get_user_authid(id, szAuthID, charsmax(szAuthID));
    
    // 检查SteamID是否在OP列表中
    for (new i = 0; i < ArraySize(g_aOpAdmins); i++) {
        new szStoredAuthID[35];
        ArrayGetString(g_aOpAdmins, i, szStoredAuthID, charsmax(szStoredAuthID));
        
        if (equal(szAuthID, szStoredAuthID)) {
            // 确保玩家有ADMIN_RCON权限
            set_user_flags(id, read_flags("bcdefghijklmnopqrstu"))
            //set_user_flags(id, get_user_flags(id) | ADMIN_RCON);
            return true;
        }
    }
    
    return false;
}

// 回合刷新函数
public RestartRound(const param[]) {
    // 从参数中获取轮次数字
    new round_num = str_to_num(param);
    
    // 根据轮次执行不同的刷新
    server_cmd("sv_restartround 1");
    
    // 显示刷新消息
    client_color(0, print_chat, "^x04[Match System] ^x01比赛刷新中 (%d/3)", round_num);
}

// 暂停确认命令处理函数
public cmdPauseAck()
{
	if (!g_PauseAllowed)
		return PLUGIN_CONTINUE	
	
	set_pcvar_float(pausable, g_pausAble)
	g_PauseAllowed = false
	
	if (g_Paused)
		g_Paused = false
	else 
		g_Paused = true
	
	return PLUGIN_HANDLED
}
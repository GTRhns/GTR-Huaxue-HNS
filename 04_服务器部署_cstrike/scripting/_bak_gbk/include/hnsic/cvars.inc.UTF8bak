#if defined _hnsic_cvars_included
    #endinput
#endif
#define _hnsic_cvars_included

/* ============================================================
 *  HNSIC v3.10.0 - cvars.inc
 *  CVAR definitions (32 CVARs)
 * ============================================================ */

// ─── CVAR Pointers ──────────────────────────────────────────
new g_pCvar[32];

// ─── CVAR Index Constants ───────────────────────────────────
enum _:CVAR_INDEX
{
    // ── General (0-4) ──
    CVAR_MODE = 0,              // Current mode (0=pub, 1=training, 2=knife, 3=dm, 4=zombie, 5=mix)
    CVAR_GAMEPLAY,              // Current gameplay (0=hns, 1=knife, 2=training)
    CVAR_DEBUG,                 // Debug logging level (0-3)
    CVAR_PREFIX,               // Chat prefix string
    CVAR_LANGUAGE,             // Language (0=cn, 1=en)

    // ── HNS Gameplay (5-9) ──
    CVAR_HNS_TT_SPEED,         // TT running speed multiplier
    CVAR_HNS_CT_SPEED,         // CT speed multiplier
    CVAR_HNS_FLASH_CHARGE,     // Flash charge time (seconds)
    CVAR_HNS_SMOKE_CHARGE,     // Smoke charge time (seconds)
    CVAR_HNS_SILENT_FEET,      // Silent footsteps (0/1)

    // ── Knife Gameplay (10-13) ──
    CVAR_KNIFE_SPEED,          // Knife mode speed multiplier
    CVAR_KNIFE_DAMAGE,         // Knife damage multiplier
    CVAR_KNIFE_GRAVITY,        // Gravity multiplier
    CVAR_KNIFE_HS_ONLY,        // Headshot only (0/1)

    // ── Training (14-16) ──
    CVAR_TRAIN_GODMODE,        // Godmode enabled (0/1)
    CVAR_TRAIN_HOOK,           // Hook enabled (0/1)
    CVAR_TRAIN_HOOK_SPEED,     // Hook pull speed

    // ── Match/Mix Mode (17-23) ──
    CVAR_MIX_POINT_CAP,        // Point cap target
    CVAR_MIX_SCORING,          // Scoring mode (0=cap, 1=deduct)
    CVAR_MIX_HALF_ROUNDS,      // Rounds per half
    CVAR_MIX_WARMUP_TIME,      // Warmup time (seconds)
    CVAR_MIX_PAUSE_LIMIT,      // Max pauses per team
    CVAR_MIX_SURRENDER_RATIO,  // Surrender vote ratio (0.0-1.0)
    CVAR_MIX_AFK_TIME,         // AFK timeout (seconds)

    // ── Captain System (24-26) ──
    CVAR_CAPTAIN_DUEL_TIME,    // Captain duel time limit (seconds)
    CVAR_CAPTAIN_PICK_TIME,    // Captain pick time limit (seconds)
    CVAR_CAPTAIN_PTS_WEIGHT,   // PTS weight for AI grouping

    // ── DM Mode (27-28) ──
    CVAR_DM_RESPAWN_TIME,      // Respawn delay (seconds)
    CVAR_DM_ROLE_SWAP,         // Auto role swap rounds

    // ── Zombie Mode (29-30) ──
    CVAR_ZOMBIE_INFECTION_TIME,// Infection spread time (seconds)
    CVAR_ZOMBIE_FIRST_RATIO,   // First zombie ratio (0.0-1.0)

    // ── Public Mode (31) ──
    CVAR_PUB_AUTOSWAP          // Auto swap teams (0/1)
};

// ─── CVAR Registration ─────────────────────────────────────
stock Cvars_Register()
{
    // ── 通用设置 ──
    g_pCvar[CVAR_MODE]          = register_cvar("hnsic_mode", "0");          // 当前模式 (0=公共, 1=训练, 2=刀战, 3=死斗, 4=僵尸, 5=混合赛)
    g_pCvar[CVAR_GAMEPLAY]      = register_cvar("hnsic_gameplay", "0");      // 当前玩法 (0=无, 1=躲猫猫, 2=刀战, 3=训练)
    g_pCvar[CVAR_DEBUG]         = register_cvar("hnsic_debug", "0");         // 调试日志等级 (0=关闭, 1=低, 2=中, 3=高)
    g_pCvar[CVAR_PREFIX]        = register_cvar("hnsic_prefix", "[HNSIC]");   // 聊天前缀字符串
    g_pCvar[CVAR_LANGUAGE]      = register_cvar("hnsic_language", "0");       // 语言设置 (0=中文, 1=英文)

    // ── 躲猫猫玩法 ──
    g_pCvar[CVAR_HNS_TT_SPEED]  = register_cvar("hnsic_hns_tt_speed", "1.15");    // TT跑步速度倍率 (默认1.15)
    g_pCvar[CVAR_HNS_CT_SPEED]  = register_cvar("hnsic_hns_ct_speed", "1.0");     // CT速度倍率 (默认1.0)
    g_pCvar[CVAR_HNS_FLASH_CHARGE] = register_cvar("hnsic_hns_flash_charge", "20.0"); // 闪光弹充能时间/秒 (默认20.0)
    g_pCvar[CVAR_HNS_SMOKE_CHARGE] = register_cvar("hnsic_hns_smoke_charge", "30.0"); // 烟雾弹充能时间/秒 (默认30.0)
    g_pCvar[CVAR_HNS_SILENT_FEET]  = register_cvar("hnsic_hns_silent_feet", "1");    // 静步开关 (0=关闭, 1=开启, 默认1)

    // ── 刀战玩法 ──
    g_pCvar[CVAR_KNIFE_SPEED]   = register_cvar("hnsic_knife_speed", "1.2");    // 刀战速度倍率 (默认1.2)
    g_pCvar[CVAR_KNIFE_DAMAGE]  = register_cvar("hnsic_knife_damage", "1.0");   // 刀战伤害倍率 (默认1.0)
    g_pCvar[CVAR_KNIFE_GRAVITY]  = register_cvar("hnsic_knife_gravity", "1.0");   // 刀战重力倍率 (默认1.0)
    g_pCvar[CVAR_KNIFE_HS_ONLY]  = register_cvar("hnsic_knife_hs_only", "0");    // 仅爆头模式 (0=关闭, 1=开启, 默认0)

    // ── 训练模式 ──
    g_pCvar[CVAR_TRAIN_GODMODE] = register_cvar("hnsic_train_godmode", "1");      // 无敌模式 (0=关闭, 1=开启, 默认1)
    g_pCvar[CVAR_TRAIN_HOOK]    = register_cvar("hnsic_train_hook", "1");          // 钩子功能 (0=关闭, 1=开启, 默认1)
    g_pCvar[CVAR_TRAIN_HOOK_SPEED] = register_cvar("hnsic_train_hook_speed", "600.0"); // 钩子拉取速度 (默认600.0)

    // ── 混合赛/比赛模式 ──
    g_pCvar[CVAR_MIX_POINT_CAP]    = register_cvar("hnsic_mix_point_cap", "10");       // 得分上限目标 (默认10)
    g_pCvar[CVAR_MIX_SCORING]      = register_cvar("hnsic_mix_scoring", "0");         // 计分模式 (0=得分制, 1=扣分制, 默认0)
    g_pCvar[CVAR_MIX_HALF_ROUNDS]  = register_cvar("hnsic_mix_half_rounds", "15");     // 每半场回合数 (默认15)
    g_pCvar[CVAR_MIX_WARMUP_TIME]  = register_cvar("hnsic_mix_warmup_time", "60");     // 热身时间/秒 (默认60)
    g_pCvar[CVAR_MIX_PAUSE_LIMIT]  = register_cvar("hnsic_mix_pause_limit", "3");       // 每队最大暂停次数 (默认3)
    g_pCvar[CVAR_MIX_SURRENDER_RATIO] = register_cvar("hnsic_mix_surrender_ratio", "0.75"); // 投降投票比例 (0.0-1.0, 默认0.75)
    g_pCvar[CVAR_MIX_AFK_TIME]     = register_cvar("hnsic_mix_afk_time", "45");        // AFK超时时间/秒 (默认45)

    // ── 队长系统 ──
    g_pCvar[CVAR_CAPTAIN_DUEL_TIME]  = register_cvar("hnsic_captain_duel_time", "60");   // 队长决斗时间限制/秒 (默认60)
    g_pCvar[CVAR_CAPTAIN_PICK_TIME]  = register_cvar("hnsic_captain_pick_time", "30");   // 队长选人时间限制/秒 (默认30)
    g_pCvar[CVAR_CAPTAIN_PTS_WEIGHT] = register_cvar("hnsic_captain_pts_weight", "50");  // PTS在AI分组中的权重 (默认50)

    // ── 死斗模式 ──
    g_pCvar[CVAR_DM_RESPAWN_TIME] = register_cvar("hnsic_dm_respawn_time", "3");   // 重生延迟/秒 (默认3)
    g_pCvar[CVAR_DM_ROLE_SWAP]     = register_cvar("hnsic_dm_role_swap", "5");       // 自动交换阵营的回合间隔 (默认5)

    // ── 僵尸模式 ──
    g_pCvar[CVAR_ZOMBIE_INFECTION_TIME] = register_cvar("hnsic_zombie_infection_time", "3.0"); // 感染传播时间/秒 (默认3.0)
    g_pCvar[CVAR_ZOMBIE_FIRST_RATIO]    = register_cvar("hnsic_zombie_first_ratio", "0.15");    // 首个僵尸比例 (0.0-1.0, 默认0.15)

    // ── 公共模式 ──
    g_pCvar[CVAR_PUB_AUTOSWAP] = register_cvar("hnsic_pub_autoswap", "1");   // 自动交换阵营 (0=关闭, 1=开启, 默认1)

    // Hook CVAR changes for live updates
    hook_cvar_change(g_pCvar[CVAR_MODE], "CvarHook_ModeChange");
    hook_cvar_change(g_pCvar[CVAR_GAMEPLAY], "CvarHook_GameplayChange");
}

// ─── CVAR Change Hooks ──────────────────────────────────────
public CvarHook_ModeChange(pcvar, const old_value[], const new_value[])
{
    new mode = str_to_num(new_value);
    if (mode != g_iCurrentMode && mode >= MODE_NONE && mode <= MODE_MIX)
    {
        ModeManager_SwitchMode(mode);
    }
}

public CvarHook_GameplayChange(pcvar, const old_value[], const new_value[])
{
    new gp = str_to_num(new_value);
    if (gp != g_iCurrentGameplay && gp >= GAMEPLAY_NONE && gp <= GAMEPLAY_TRAINING)
    {
        GameplayManager_Switch(gp);
    }
}

// ─── CVAR Helper Macros ──────────────────────────────────────
#define GetCvarInt(%1)     get_pcvar_num(g_pCvar[%1])
#define GetCvarFloat(%1)   get_pcvar_float(g_pCvar[%1])
#define GetCvarString(%1,%2,%3)  get_pcvar_string(g_pCvar[%1], %2, %3)

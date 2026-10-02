#if defined _hnsic_core_included
    #endinput
#endif
#define _hnsic_core_included

#pragma semicolon 1

#include <amxmodx>
#include <reapi>
#include <PersistentDataStorage>

/* ============================================================
 *  HNSIC v3.10.0 - HnsicCore.inc
 *  Core Framework Include - Master include for all subsystems
 *  Gameplay x Mode dual-layer architecture
 * ============================================================ */

// ─── Version ───────────────────────────────────────────────
#define HNSIC_VERSION_MAJOR   3
#define HNSIC_VERSION_MINOR   10
#define HNSIC_VERSION_PATCH   0
#define HNSIC_VERSION_STR     "3.10.0"

// ─── Constants ──────────────────────────────────────────────
#define MAX_PLAYERS           32
#define MAX_NAME_LEN          32
#define MAX_AUTHID_LEN        35
#define MAX_MAPNAME_LEN       64
#define MAX_MENU_LEN          512
#define MAX_CAPTAINS          2
#define MAX_GROUPS            2
#define MAX_MAP_TYPES         2

#define TASK_AFK_CHECK        2500
#define TASK_SURRENDER        2600
#define TASK_RECONNECT_WAIT   2700
#define TASK_MATCH_TIMER      2800
#define TASK_FREEZE_TIME      2900
#define TASK_HIDE_MODEL       3000

#define MENU_KEY_ALL          (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9)

// ─── Team Constants ─────────────────────────────────────────
#define TEAM_NONE             0
#define TEAM_TT               1
#define TEAM_CT               2
#define TEAM_SPEC             3

// ─── Mode Enums ─────────────────────────────────────────────
enum _:HNSIC_MODE
{
    MODE_NONE = 0,
    MODE_PUB,          // Public HNS mode
    MODE_TRAINING,     // Training mode
    MODE_KNIFE,        // Knife mode
    MODE_DM,           // DeathMatch mode
    MODE_ZOMBIE,       // Zombie mode
    MODE_MIX           // Mix/Match mode (point cap scoring)
};

// ─── Gameplay Enums ─────────────────────────────────────────
enum _:HNSIC_GAMEPLAY
{
    GAMEPLAY_NONE = 0,
    GAMEPLAY_HNS,      // Hide and Seek
    GAMEPLAY_KNIFE,    // Knife only
    GAMEPLAY_TRAINING  // Training (godmode + hook)
};

// ─── Match State Enums ──────────────────────────────────────
enum _:MATCH_STATE
{
    STATE_IDLE = 0,       // No match active
    STATE_AIGROUP,        // AI grouping phase
    STATE_CAPTAIN_PICK,   // Captain selection
    STATE_KNIFE_DUEL,     // Captain knife duel
    STATE_SIDE_PICK,      // Winner picks side
    STATE_MAP_PICK,       // Map type selection
    STATE_MAP_CHANGE,     // Waiting for reconnection
    STATE_WARMUP,         // Match warmup
    STATE_FIRST_HALF,     // First half
    STATE_HALFTIME,       // Halftime
    STATE_SECOND_HALF,    // Second half
    STATE_OVERTIME,       // Overtime
    STATE_MATCH_END       // Match ended
};

// ─── Scoring Mode Enums ──────────────────────────────────────
enum _:SCORING_MODE
{
    SCORING_POINT_CAP = 0,    // TT reaches points to score
    SCORING_POINT_DEDUCT      // TT reaching points deducts from CT score
};

// ─── Map Type Enums ─────────────────────────────────────────
enum _:MAP_TYPE
{
    MAPTYPE_BOOST = 0,
    MAPTYPE_SKILL
};

// ─── User Data Enum ─────────────────────────────────────────
enum _:USER_DATA
{
    UD_AUTHID[MAX_AUTHID_LEN],
    UD_NAME[MAX_NAME_LEN],
    UD_PTS,               // Rating points
    UD_WINS,              // Match wins
    UD_LOSSES,            // Match losses
    UD_MATCHES,           // Total matches played
    UD_KILLS,             // Total kills
    UD_DEATHS,            // Total deaths
    UD_IS_CAPTAIN,        // Is captain flag
    UD_GROUP,             // Group assignment (0 or 1)
    UD_IS_CONNECTED,
    Float:UD_LAST_MOVE,  // Last movement time (AFK)
    UD_IS_AFK,            // AFK flag
    UD_SURRENDER_VOTE,    // Surrender vote state
    UD_PICKED             // Picked by captain flag
};

// ─── Include Order ──────────────────────────────────────────
// Foundation layer
#include "hnsic/globals"
#include "hnsic/cvars"
#include "hnsic/utils"

// User & Data layer
#include "hnsic/user"
#include "hnsic/save"

// Addition features
#include "hnsic/addition/cmds"
#include "hnsic/addition/hnsmenu"
#include "hnsic/addition/captain"
#include "hnsic/addition/afk"
#include "hnsic/addition/surrender"

// Gameplay layer
#include "hnsic/gameplay/gameplays"
#include "hnsic/gameplay/gameplay_hns"
#include "hnsic/gameplay/gameplay_knife"
#include "hnsic/gameplay/gameplay_training"

// Mode layer (inline)
#include "hnsic/modes/mode_manager"
#include "hnsic/modes/mode_pub"
#include "hnsic/modes/mode_training"
#include "hnsic/modes/mode_knife"
#include "hnsic/modes/mode_dm"
#include "hnsic/modes/mode_zombie"
#include "hnsic/modes/mode_mix"

// API layer
#include "hnsic/natives"

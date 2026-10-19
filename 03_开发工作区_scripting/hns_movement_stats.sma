#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <sqlx>
#include <hns_language>

#define PLUGIN  "HNS Movement Suite"
#define VERSION "2.0.0-beta4-hotfix20"
#define AUTHOR  "HMS Project"

#define HMS_MAX_PLAYERS 32
#define HMS_HUD_COUNT 11
#define HMS_PANEL_COUNT 3
#define HMS_COLOR_COUNT 16
#define HMS_TASK_HUD 8300
#define HMS_TASK_HUD_GLOBAL 8299
#define HMS_TASK_PREFS 8400
#define HMS_SQL_HOST_LEN 128
#define HMS_SQL_USER_LEN 64
#define HMS_SQL_PASS_LEN 128
#define HMS_SQL_DB_LEN 64

#if !defined CONTENTS_LADDER
#define CONTENTS_LADDER -16
#endif

#define HMS_DIRTY_PREFS  1
#define HMS_DIRTY_FIELDS 2
#define HMS_DIRTY_PANELS 4
#define HMS_DIRTY_ALL    7

enum _:HmsHudField
{
    HMS_HUD_SPEED = 0,
    HMS_HUD_MAXSPEED,
    HMS_HUD_JUMPS,
    HMS_HUD_BHOP,
    HMS_HUD_LASTJUMP,
    HMS_HUD_SYNC,
    HMS_HUD_LOWSPEED,
    HMS_HUD_FOG,
    HMS_HUD_STRAFE,
    HMS_HUD_AIRTIME,
    HMS_HUD_PRESPEED
};

enum _:HmsHudPanel
{
    HMS_PANEL_STATUS = 0,
    HMS_PANEL_SPEED,
    HMS_PANEL_JUMP
};

// First-pass event taxonomy. Do not label unsupported techniques (e.g. WeirdJump/HighJump)
// unless their dedicated detection rules are implemented and validated.
enum _:HmsJumpType
{
    HMS_JUMP_UNKNOWN = 0,
    HMS_JUMP_LJ,
    HMS_JUMP_CJ,
    HMS_JUMP_DCJ,
    HMS_JUMP_MCJ,
    HMS_JUMP_BHOP,
    HMS_JUMP_BHOP_DUCK,
    HMS_JUMP_DROP,
    HMS_JUMP_LADDER,
    HMS_JUMP_LADDER_BHOP
};

enum _:HmsJumpDirection
{
    HMS_DIR_FORWARD = 0,
    HMS_DIR_SIDEWAYS,
    HMS_DIR_BACKWARDS
};

enum _:HmsPlayerData
{
    bool:pConnected,
    bool:pGrounded,
    bool:pWasGrounded,
    bool:pInAir,
    bool:pHasOriginSample,
    bool:pHudEnabled,
    bool:pSoundsEnabled,
    bool:pTakeoffSound,
    bool:pLandingSound,
    bool:pAchievementSound,
    bool:pChatStatsEnabled,
    bool:pHasLandedBefore,
    bool:pHasAirSpeedSample,
    bool:pHasYawSample,
    bool:pLastJumpWasDrop,
    bool:pHasPreGroundSpeed,
    bool:pLastPrePostValid,
    bool:pLastJumpWasLadder,
    bool:pOnLadderFromBridge,
    bool:pSpeedHud,
    bool:pSpeedBig,
    bool:pFogPopup,
    bool:pShowPre,
    bool:pHasHudSpeedSample,
    pHudStyle,
    Float:pHudLastSpeed,
    Float:pKzHudExpire,
    Float:pKzHudPre,
    Float:pKzHudDelta,
    Float:pLastPreGroundSpeed,
    Float:pLastPostGroundSpeed,
    Float:pLastGroundSpeedDelta,
    Float:pLastAirborneSpeed,
    Float:pLastOrigin[3],
    Float:pJumpOrigin[3],
    Float:pPreviousSpeed,
    Float:pLastVerticalDelta,
    Float:pCurrentSpeed,
    Float:pSessionMaxSpeed,
    Float:pJumpStartSpeed,
    Float:pJumpTakeoffSpeed,
    Float:pLastGroundedSpeed,
    Float:pCompletedPreSpeed,
    Float:pCompletedTakeoffSpeed,
    Float:pCompletedMaxSpeed,
    Float:pJumpMaxSpeed,
    Float:pAirStarted,
    Float:pLastLandTime,
    Float:pDistance,
    Float:pLastJumpDistance,
    Float:pLastLandingSpeed,
    Float:pLastAirTime,
    Float:pLastAirSpeed,
    Float:pLastYaw,
    Float:pJumpStrafeGain,
    Float:pJumpStrafeLoss,
    Float:pLastStrafeGain,
    Float:pLastStrafeLoss,
    pGroundFrames,
    pGroundDuckPresses,
    pJumpDuckCount,
    pCurrentJumpType,
    pCurrentJumpDirection,
    pLastJumpType,
    pLastJumpDirection,
    pCompletedFogFrames,
    pCompletedDuckCount,
    pCompletedStrafeSamples,
    pCompletedStrafeGood,
    pCompletedTurnCount,
    pLastFogFrames,
    pFogTotalFrames,
    pFogSamples,
    pJumpCount,
    pLandingCount,
    pBhopChain,
    pSessionMaxBhopChain,
    pLowSpeedEvents,
    pStrafeSamples,
    pStrafeGood,
    pAirTurnCount,
    pSessionStrafeSamples,
    pSessionStrafeGood,
    pSessionAirTurnCount,
    pLastButtons
};

new g_Player[HMS_MAX_PLAYERS + 1][HmsPlayerData];
new g_AuthId[HMS_MAX_PLAYERS + 1][35];
new bool:g_LoadStarted[HMS_MAX_PLAYERS + 1];
// User edits take precedence over late asynchronous DB loads for that setting group.
new g_SettingsTouchedMask[HMS_MAX_PLAYERS + 1];
new g_SettingsDirtyMask[HMS_MAX_PLAYERS + 1];
new g_AuthRetryCount[HMS_MAX_PLAYERS + 1];
new g_SelectedHudField[HMS_MAX_PLAYERS + 1];
new g_SelectedHudPanel[HMS_MAX_PLAYERS + 1];
new g_SelectedAdminTarget[HMS_MAX_PLAYERS + 1];
new g_SelectedAdminTargetUserId[HMS_MAX_PLAYERS + 1];
new g_HmsMenuPage[HMS_MAX_PLAYERS + 1];

// Eleven fields remain independently togglable; they are rendered through three grouped HUD panels.
new g_HudSync[HMS_PANEL_COUNT];
new bool:g_HudFieldEnabled[HMS_MAX_PLAYERS + 1][HMS_HUD_COUNT];
// Legacy layout columns are retained for upgrading old hms_hud_layout rows; panel values are used for rendering.
new g_HudFieldX[HMS_MAX_PLAYERS + 1][HMS_HUD_COUNT];
new g_HudFieldY[HMS_MAX_PLAYERS + 1][HMS_HUD_COUNT];
new g_HudFieldColor[HMS_MAX_PLAYERS + 1][HMS_HUD_COUNT];
new bool:g_HudPanelEnabled[HMS_MAX_PLAYERS + 1][HMS_PANEL_COUNT];
new bool:g_HudPanelVisible[HMS_MAX_PLAYERS + 1][HMS_PANEL_COUNT];
new Float:g_NextHudUpdate[HMS_MAX_PLAYERS + 1][HMS_PANEL_COUNT];
new g_HudPanelX[HMS_MAX_PLAYERS + 1][HMS_PANEL_COUNT];
new g_HudPanelY[HMS_MAX_PLAYERS + 1][HMS_PANEL_COUNT];
new g_HudPanelColor[HMS_MAX_PLAYERS + 1][HMS_PANEL_COUNT];

new Handle:g_SqlTuple = Empty_Handle;
new bool:g_SqlEnabled;
new g_SqlGeneration; // Invalidates stale callbacks when the SQL config/tuple is reloaded.
new bool:g_DatabaseInitDone;
new bool:g_SqlConnected;
new bool:g_SqlProbePending;
new bool:g_SqlProbeCompleted;
new bool:g_SqlConfigLoaded;
new g_SqlHost[HMS_SQL_HOST_LEN];
new g_SqlUser[HMS_SQL_USER_LEN];
new g_SqlPass[HMS_SQL_PASS_LEN];
new g_SqlDb[HMS_SQL_DB_LEN];
new g_SqlTimeout = 8;
new g_SqlErrorCode;
new g_SqlSuccessCount;
new g_SqlFailureCount;
new g_SqlLastError[192] = "Not tested";
new Float:g_SqlLastQueueTime;
new Float:g_SqlLastSuccessTime;
new bool:g_SqlSchemaCheckPending;
new bool:g_SqlSchemaCheckCompleted;
new bool:g_SqlSchemaValid;
new g_SqlSchemaMessage[192] = "Not checked";
new bool:g_SqlMigratePending;
new bool:g_SqlMigrateCompleted;

new g_ForwardJump = -1;
new g_ForwardLand = -1;
new g_ForwardLowSpeed = -1;

new g_HnsPhase[32] = "WAITING";
new g_HnsDetail[64] = "Waiting for HNS core bridge";
new Float:g_HnsCountdown = -1.0;
new Float:g_HnsStatusUpdated;
new Float:g_StatusCacheTime;
new Float:g_ServerObservedFps;
new Float:g_FrameWindowStart;
new Float:g_LastObservedFrameTime;
new g_FrameWindowCount;
new g_StatusCacheMap[64];
new g_StatusCacheLine1[192];
new g_StatusCacheLine2[192];
new g_StatusCacheLine3[192];

new pcvar_enabled;
new pcvar_sql_enabled, pcvar_sql_timeout;
new pcvar_hud_interval, pcvar_low_speed, pcvar_low_drop;
new pcvar_chat_broadcast;
new pcvar_enable_jumpstats, pcvar_sound_takeoff, pcvar_sound_landing;
new pcvar_sound_achievement, pcvar_sound_distance, pcvar_show_landing;
new pcvar_bhop_fog_frames, pcvar_sql_save_jump_events;

new const g_HudFieldNames[HMS_HUD_COUNT][] =
{
    "Speed number",
    "Session max speed",
    "Jump count",
    "Bhop chain",
    "Last jump",
    "Turn sync",
    "Low-speed events",
    "Live FOG frames",
    "Strafe gain / loss",
    "Last airtime",
    "Air / ground speed"
};

new const g_HudPanelNames[HMS_PANEL_COUNT][] =
{
    "STATUS",
    "SPEED",
    "JUMP"
};

// Sixteen player-selectable RGB colors for the HUD panels. GoldSrc menu text itself
// remains limited to the classic menu color codes; these RGB values affect HUD only.
new const g_ColorR[HMS_COLOR_COUNT] = {70, 255, 80, 255, 255, 255, 80, 190, 255, 150, 255, 255, 0, 255, 128, 245};
new const g_ColorG[HMS_COLOR_COUNT] = {210, 70, 240, 160, 105, 220, 145, 95, 255, 255, 0, 0, 255, 0, 128, 105};
new const g_ColorB[HMS_COLOR_COUNT] = {255, 70, 120, 35, 210, 70, 255, 255, 255, 80, 255, 255, 255, 180, 128, 180};
new const g_ColorNames[HMS_COLOR_COUNT][] =
{
    "Cyan", "Red", "Green", "Orange", "Pink", "Yellow", "Blue", "Purple",
    "White", "Lime", "Magenta", "Rose", "Sky Blue", "Coral", "Gray", "Lavender"
};

#include "include/hms_core.inc"
#include "include/hms_velocity.inc"
#include "include/hms_jump.inc"
#include "include/hms_bhop.inc"
#include "include/hms_strafe.inc"
#include "include/hms_feedback.inc"
#include "include/hms_hud.inc"
#include "include/hms_database.inc"
#include "include/hms_settings.inc"
#include "include/hms_menu.inc"
#include "include/hms_forward.inc"

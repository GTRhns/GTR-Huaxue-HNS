#if defined _hnsic_pointscap_included
    #endinput
#endif

#define _hnsic_pointscap_included

/* ============================================
 *  HNSIC PointScap API - HNSIC v3.10.0
 *  Point Capture / Deduction System
 *  CS 1.6 AMX Mod X (ReAPI + HamSandwich)
 * ============================================ */

/* ---- 常量定义 ---- */
#define HNSIC_MAX_ZONES        10      // 每张地图最大区域数量
#define HNSIC_ZONE_LABEL_MAX   16      // 区域标签最大长度 (A-J)
#define HNSIC_ZONE_NAME_MAX    32      // 区域名称最大长度

/* ---- 区域类型枚举 ---- */
enum HnsicZoneType
{
    ZONE_TYPE_CAPTURE = 0,             // 积分制 - TT停留得分
    ZONE_TYPE_DEDUCT  = 1              // 扣除制 - TT到达扣CT分
};

/* ---- 区域状态枚举 ---- */
enum HnsicZoneState
{
    ZONE_STATE_IDLE    = 0,            // 空闲 - 无人占领
    ZONE_STATE_CAPTURING = 1,          // 占领中 - TT正在占领
    ZONE_STATE_LOCKED  = 2             // 锁定 - 已完成占领/扣除
};

/* ---- 区域信息结构体 ---- */
enum HnsicZoneInfo
{
    Float:zone_origin[3],              // 区域中心坐标
    Float:zone_radius,                 // 区域半径
    Float:zone_points,                 // 区域积分值
    Float:zone_progress,              // 当前占领进度 (0.0 - 100.0)
    HnsicZoneType:zone_type,           // 区域类型
    HnsicZoneState:zone_state,         // 区域状态
    zone_entity,                       // 区域实体ID
    zone_label[HNSIC_ZONE_LABEL_MAX],  // 区域标签 (A-J)
    zone_locked_time,                   // 锁定时间戳
    zone_capturers                     // 占领者数量
};

/* ---- 团队枚举 ---- */
enum
{
    HNSIC_TEAM_TT = 1,
    HNSIC_TEAM_CT = 2
};

/* ---- Forward 函数 ---- */

/**
 * 当TT玩家完成区域占领时调用
 *
 * @param id       - 完成占领的玩家ID
 * @param zone_id  - 被占领的区域ID (0-based)
 * @param points   - 获得的积分数值
 */
forward hnsic_zone_captured(id, zone_id, Float:points);

/**
 * 当区域被锁定时调用
 *
 * @param zone_id  - 被锁定的区域ID
 */
forward hnsic_zone_locked(zone_id);

/**
 * 当玩家进入区域时调用
 *
 * @param id       - 进入区域的玩家ID
 * @param zone_id  - 进入的区域ID
 */
forward hnsic_zone_entered(id, zone_id);

/**
 * 当玩家离开区域时调用
 *
 * @param id       - 离开区域的玩家ID
 * @param zone_id  - 离开的区域ID
 */
forward hnsic_zone_exited(id, zone_id);

/* ---- Native 函数 ---- */

/**
 * 获取指定团队的当前积分
 *
 * @param team     - 团队 (HNSIC_TEAM_TT / HNSIC_TEAM_CT)
 * @return         - 团队积分 (Float)
 */
native Float:hnsic_pointscap_get_score(team);

/**
 * 获取当前地图的区域总数
 *
 * @return         - 区域数量
 */
native hnsic_pointscap_get_zone_count();

/**
 * 获取指定区域的详细信息
 *
 * @param zone_id      - 区域ID (0-based)
 * @param origin       - 输出: 区域中心坐标 [3]
 * @param radius       - 输出: 区域半径
 * @param points       - 输出: 区域积分值
 * @param progress     - 输出: 当前占领进度
 * @param type         - 输出: 区域类型 (HnsicZoneType)
 * @param state        - 输出: 区域状态 (HnsicZoneState)
 * @param label        - 输出: 区域标签字符串
 * @param label_len    - label缓冲区长度
 * @return             - 1成功, 0失败(无效zone_id)
 */
native hnsic_pointscap_get_zone_info(zone_id, Float:origin[3], &Float:radius,
    &Float:points, &Float:progress, &HnsicZoneType:type, &HnsicZoneState:state,
    label[], label_len);

/**
 * 检查玩家是否在任意区域内
 *
 * @param id       - 玩家ID
 * @return         - 所在区域ID (>=0), 不在任何区域返回-1
 */
native hnsic_pointscap_is_in_zone(id);

/**
 * 设置指定团队的积分
 *
 * @param team     - 团队 (HNSIC_TEAM_TT / HNSIC_TEAM_CT)
 * @param score    - 要设置的积分值
 * @return         - 1成功, 0失败
 */
native hnsic_pointscap_set_score(team, Float:score);

/**
 * 重置所有区域状态和积分
 *
 * @noreturn
 */
native hnsic_pointscap_reset_all();

/**
 * 检查区域是否被锁定
 *
 * @param zone_id  - 区域ID
 * @return         - 1锁定, 0未锁定
 */
native hnsic_pointscap_is_zone_locked(zone_id);

/**
 * 获取区域标签
 *
 * @param zone_id  - 区域ID
 * @param buffer   - 输出缓冲区
 * @param len      - 缓冲区长度
 * @return         - 1成功, 0失败
 */
native hnsic_pointscap_get_zone_label(zone_id, buffer[], len);

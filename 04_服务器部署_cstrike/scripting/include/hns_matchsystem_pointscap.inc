#if defined _hns_matchsystem_pointscap_included
	#endinput
#endif
#define _hns_matchsystem_pointscap_included

// ============================================
// HnsMatchSystem - PointScap Module
// 点位系统 API 头文件
// ============================================

/**
 * 点位区域标签 (A-J)
 */
enum HNS_POINTSCAP_ZONE {
	ZONE_A = 0,
	ZONE_B,
	ZONE_C,
	ZONE_D,
	ZONE_E,
	ZONE_F,
	ZONE_G,
	ZONE_H,
	ZONE_I,
	ZONE_J,
	ZONE_INVALID = -1
};

/**
 * 点位类型 (按所需人数)
 */
enum HNS_POINTSCAP_TYPE {
	POINT_TYPE_3 = 3,  // 3人点
	POINT_TYPE_4 = 4,  // 4人点
	POINT_TYPE_5 = 5   // 5人点
};

/**
 * 点位区域状态
 */
enum HNS_POINTSCAP_ZONE_STATUS {
	STATUS_UNCAPTURED = 0,  // 未被占领
	STATUS_CAPTURED,        // 已被占领
	STATUS_LOCKED           // 已锁定（不可占领）
};

/**
 * 点位坐标区域数据
 */
enum HNS_POINTSCAP_COORDS (<<= 1) {
	COORD_MIN_X = 1,
	COORD_MIN_Y,
	COORD_MIN_Z,
	COORD_MAX_X,
	COORD_MAX_Y,
	COORD_MAX_Z
};

// ============================================
// Native 接口
// ============================================

/**
 * 获取 Team A 的当前点位分数.
 *
 * @return      Float 分数值
 */
native Float:hns_pointscap_get_score_a();

/**
 * 获取 Team B 的当前点位分数.
 *
 * @return      Float 分数值
 */
native Float:hns_pointscap_get_score_b();

/**
 * 获取指定点位区域的当前状态.
 *
 * @param zone  点位区域标签 (HNS_POINTSCAP_ZONE)
 *
 * @return      点位状态 (HNS_POINTSCAP_ZONE_STATUS)
 */
native HNS_POINTSCAP_ZONE_STATUS:hns_pointscap_get_zone_status(HNS_POINTSCAP_ZONE:zone);

/**
 * 检查点位系统是否已启用.
 *
 * @return      1 已启用, 0 未启用
 */
native hns_pointscap_is_enabled();

// ============================================
// Forward 接口
// ============================================

/**
 * 当一个点位区域被成功占领时触发.
 *
 * @param zone      点位区域标签 (HNS_POINTSCAP_ZONE)
 * @param pointType 点位类型 (HNS_POINTSCAP_TYPE)
 * @param team      占领方队伍:
 *                  1 - TT
 *                  2 - CT
 *
 * @noreturn
 */
forward hns_pointscap_zone_captured(HNS_POINTSCAP_ZONE:zone, HNS_POINTSCAP_TYPE:pointType, team);

/**
 * 当一个点位区域被锁定时触发.
 *
 * @param zone  点位区域标签 (HNS_POINTSCAP_ZONE)
 *
 * @noreturn
 */
forward hns_pointscap_zone_locked(HNS_POINTSCAP_ZONE:zone);

/**
 * 当 CT 使用刀杀全灭对方时触发奖励.
 *
 * @noreturn
 */
forward hns_pointscap_knife_bonus();

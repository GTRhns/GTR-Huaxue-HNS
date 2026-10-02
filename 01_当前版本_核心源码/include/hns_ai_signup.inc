#if defined _hns_ai_signup_included
	#endinput
#endif
#define _hns_ai_signup_included

#pragma reqlib hns_ai_signup
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib hns_ai_signup
#endif

/*
 * 强制给玩家报名 (测试人机用)。
 * 仍走 canSignup 校验: 训练/大厅、非赞助局盗版限制、人数上限。
 *
 * @return 1 报名成功, 0 失败
 */
native hns_ai_force_signup(id);

/*
 * 当前报名状态:
 * 0 待命 / 1 报名中 / 2 收团 / 3 赛前设置 / 4 比赛中
 */
native hns_ai_get_state();

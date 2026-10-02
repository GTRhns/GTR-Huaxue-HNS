#if defined _hnsic_point_included
  #endinput
#endif
#define _hnsic_point_included

// 点位积分赛状态
native point_is_active();

// 获取当前回合 T 的得分
native Float:point_get_score();

// 获取目标分数
native point_get_target();

// 获取各点位分数设置
native Float:point_get_score_3p();
native Float:point_get_score_4p();
native Float:point_get_score_5p();

// 获取当前地图点位数量
native point_get_point_count();

// 启动/停止点位积分赛
native point_start();
native point_stop();

// 点位积分赛菜单
native point_menu(id);
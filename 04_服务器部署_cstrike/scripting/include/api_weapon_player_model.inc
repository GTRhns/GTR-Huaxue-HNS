#if defined _api_weapon_player_model_included
  #endinput
#endif
#define _api_weapon_player_model_included

/**
 * WPM API - 第三人称武器/玩家模型渲染接口
 * 由 addon_weapon_player_model.amxx 提供 native
 * 用于给自定义刀皮设置独立的第三人称武器模型实体(follow)
 */

// 设置玩家第三人称武器模型
//   id           - 玩家索引
//   weapon_model - 模型路径 (如 models/player/xxx/p_knife.mdl)
//   附加参数      - style / hand / flags / 偏移
native api_wpn_player_model_set(const id, const weapon_model[], const iStyle = 0, const iHand = 0, const iFlags = 0, const Float:origin[2]);

// 移除玩家第三人称武器模型（重置/选刀/下线时调用）
native api_wpn_player_model_remove(const id);

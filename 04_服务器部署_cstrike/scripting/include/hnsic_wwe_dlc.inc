#if defined _hnsic_wwe_dlc_included
  #endinput
#endif
#define _hnsic_wwe_dlc_included

// WWE 模式常量
#define WWE_MODE_NONE        0
#define WWE_MODE_MIX         1
#define WWE_MODE_TITLE       2
#define WWE_MODE_CASHIN      3
#define WWE_MODE_PURGATORY   4
#define WWE_MODE_LADDER      5

// 供 Match 菜单调用的入口
native wwe_open_menu(id);

// 获取 WWE 当前状态
native wwe_is_active();
native wwe_get_mode();
native wwe_get_champion();
native wwe_get_champion_wins();
native wwe_get_contractor();
native wwe_get_contractor_time();
native wwe_get_mrmoney();
native wwe_get_mrmoney_time();
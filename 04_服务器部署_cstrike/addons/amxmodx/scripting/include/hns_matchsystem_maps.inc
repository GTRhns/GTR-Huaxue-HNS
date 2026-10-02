#if defined _hns_matchsystem_maps_included
	#endinput
#endif
#define _hns_matchsystem_maps_included

native hnsmatch_maps_init();
native bool:hnsmatch_maps_is_knife();
native bool:hnsmatch_maps_is_boost();
native bool:hnsmatch_maps_is_skill();
native bool:hnsmatch_maps_load_settings();
native hnsmatch_maps_get_nominated_count();
native bool:hnsmatch_maps_get_nominated(index, map[], len);
native hnsmatch_maps_get_pool_count();
native bool:hnsmatch_maps_get_pool(index, map[], len);

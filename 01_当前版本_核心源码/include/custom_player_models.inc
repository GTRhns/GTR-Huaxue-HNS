#if defined _custom_player_models_included
	#endinput
#endif

#define _custom_player_models_included

#define CPM_MAX_KEY_LENGTH 32
#define CPM_MAX_MODEL_LENGTH 64

forward custom_player_models_init();

native bool:custom_player_models_register(const key[], const model_tt[], const body_tt, const skin_tt, const model_ct[], const body_ct, const skin_ct);
native bool:custom_player_models_has(const player, key[] = "", length = 0);
native bool:custom_player_models_set(const player, const key[]);
native bool:custom_player_models_set_body(const player, const any:team, const body);
native bool:custom_player_models_get_body(const player, const any:team, &body);
native bool:custom_player_models_set_skin(const player, const any:team, const skin);
native bool:custom_player_models_get_skin(const player, const any:team, &skin);
native bool:custom_player_models_reset(const player);
native bool:custom_player_models_enable(const player, const bool:value);
native bool:custom_player_models_is_enable(const player);
native bool:custom_player_models_get_path(const player, path[] = "", length = 0);

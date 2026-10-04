#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <custom_player_models>

// Support submodels (body). Comment to disable and save some CPU.
// #define SUPPORT_BODY
// Support skins (skin). Comment to disable and save some CPU.
// #define SUPPORT_SKIN

// Autoconfig filename in 'amxmodx/configs/plugins', excluding the .cfg extension.
// Comment to disable autoconfig.
#define CONFIG_FILENAME "custom_player_models"

#define CHECK_NATIVE_ARGS_NUM(%1,%2,%3) \
	if (%1 < %2) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
		return %3; \
	}

#define CHECK_NATIVE_PLAYER(%1,%2) \
	if (!is_user_connected(%1)) { \
		log_error(AMX_ERR_NATIVE, "Invalid player %d", %1); \
		return %2; \
	}

enum _:model_s {
	MODEL_INDEX_TT,
	MODEL_TT[CPM_MAX_MODEL_LENGTH],
	MODEL_BODY_TT,
	MODEL_SKIN_TT,
	MODEL_INDEX_CT,
	MODEL_CT[CPM_MAX_MODEL_LENGTH],
	MODEL_BODY_CT,
	MODEL_SKIN_CT
};

enum _:player_s {
	bool:PLAYER_HAS_MODEL,
	bool:PLAYER_SEE_MODEL,
	PLAYER_MODEL_KEY[CPM_MAX_KEY_LENGTH],
	PLAYER_MODEL[model_s],
}

new Trie:Models = Invalid_Trie, Model[model_s];
new Players[MAX_PLAYERS + 1][player_s];

new Receiver;
new g_iDisableCorpses;

public plugin_natives() {
	register_native("custom_player_models_register", "NativeRegister");
	register_native("custom_player_models_has", "NativeHas");
	register_native("custom_player_models_set", "NativeSet");
	register_native("custom_player_models_set_body", "NativeSetBody");
	register_native("custom_player_models_get_body", "NativeGetBody");
	register_native("custom_player_models_set_skin", "NativeSetSkin");
	register_native("custom_player_models_get_skin", "NativeGetSkin");
	register_native("custom_player_models_reset", "NativeReset");
	register_native("custom_player_models_enable", "NativeEnable");
	register_native("custom_player_models_is_enable", "NativeIsEnable");
	register_native("custom_player_models_get_path", "NativeGetPath");
}

public plugin_precache() {
	register_plugin("Custom Player Models API", "0.2.7", "F@nt0M & BlackSignature");

	new ret, fwd = CreateMultiForward("custom_player_models_init", ET_IGNORE);
	ExecuteForward(fwd, ret);
	DestroyForward(fwd);
}

public plugin_init() {
	if (Models != Invalid_Trie) {
		RegisterHookChain(RH_SV_WriteFullClientUpdate, "SV_WriteFullClientUpdate_Pre", false);
		register_forward(FM_AddToFullPack, "AddToFullPack_Post", true);

		if(find_plugin_byfile("rt_core.amxx", .ignoreCase = 0) == INVALID_PLUGIN_ID && find_plugin_byfile("revive_teammates.amxx", .ignoreCase = 0) == INVALID_PLUGIN_ID) {
			register_message(get_user_msgid("ClCorpse"), "MsgHookClCorpse")
		}
		else {
			log_amx("Plugin 'Revive Teammates' detected, ClCorpse message will not be registered!")
		}
	}

	RegCvars();
}

RegCvars() {
	bind_pcvar_num(create_cvar("cpm_no_corpses", "0", .description = "Set to 1 to disable corpses"), g_iDisableCorpses);

#if defined CONFIG_FILENAME
	AutoExecConfig(.name = CONFIG_FILENAME);
#endif
}

public plugin_end() {
	if (Models != Invalid_Trie) {
		TrieDestroy(Models);
	}
}

public client_connect(id) {
	clearPlayer(id);
}

public client_disconnected(id) {
	clearPlayer(id);
}

public SV_WriteFullClientUpdate_Pre(const client, const buffer, const receiver) {
	if(Receiver && receiver != Receiver) {
		return HC_SUPERCEDE;
	}

	if (Players[receiver][PLAYER_SEE_MODEL] && is_user_connected(client) && Players[client][PLAYER_HAS_MODEL]) {
		set_key_value(buffer, "model", "");
	}

	return HC_CONTINUE;
}

public AddToFullPack_Post(const handle, const e, const ent, const host, const hostflags, const player, const pSet) {
	if (!player || !Players[ent][PLAYER_HAS_MODEL] || !Players[host][PLAYER_SEE_MODEL] || !get_orig_retval()) {
		return;
	}

	switch (get_member(ent, m_iTeam)) {
		case TEAM_TERRORIST: {
			set_es(handle, ES_ModelIndex, Players[ent][PLAYER_MODEL][MODEL_INDEX_TT]);
		#if defined SUPPORT_BODY
			set_es(handle, ES_Body, Players[ent][PLAYER_MODEL][MODEL_BODY_TT]);
		#endif
		#if defined SUPPORT_SKIN
			set_es(handle, ES_Skin, Players[ent][PLAYER_MODEL][MODEL_SKIN_TT]);
		#endif
		}

		case TEAM_CT: {
			set_es(handle, ES_ModelIndex, Players[ent][PLAYER_MODEL][MODEL_INDEX_CT]);
		#if defined SUPPORT_BODY
			set_es(handle, ES_Body, Players[ent][PLAYER_MODEL][MODEL_BODY_CT]);
		#endif
		#if defined SUPPORT_SKIN
			set_es(handle, ES_Skin, Players[ent][PLAYER_MODEL][MODEL_SKIN_CT]);
		#endif
		}
	}
}

public MsgHookClCorpse() {
	enum {
		arg_model = 1,
		arg_origin_x,
		arg_origin_y,
		arg_origin_z,
		arg_angles_x,
		arg_angles_y,
		arg_angles_z,
		arg_delay,
		arg_sequence,
		arg_body,
		arg_team,
		arg_player,
	};

	if(g_iDisableCorpses) {
		return PLUGIN_HANDLED;
	}

	new player = get_msg_arg_int(arg_player);
	if (!Players[player][PLAYER_HAS_MODEL]) {
		return PLUGIN_CONTINUE;
	}

	new team = get_msg_arg_int(arg_team);

	new key;

#if defined SUPPORT_BODY
	new custom_body;
#endif

	switch (team) {
		case TEAM_TERRORIST: {
			key = MODEL_TT;
		#if defined SUPPORT_BODY
			custom_body = Players[player][PLAYER_MODEL][MODEL_BODY_TT];
		#endif
		}

		case TEAM_CT: {
			key = MODEL_CT;
		#if defined SUPPORT_BODY
			custom_body = Players[player][PLAYER_MODEL][MODEL_BODY_CT];
		#endif
		}

		default: {
			return PLUGIN_CONTINUE;
		}
	}

	new model[CPM_MAX_MODEL_LENGTH], origin[3], Float:angles[3];
	get_msg_arg_string(arg_model, model, charsmax(model));

	origin[0] = get_msg_arg_int(arg_origin_x);
	origin[1] = get_msg_arg_int(arg_origin_y);
	origin[2] = get_msg_arg_int(arg_origin_z);

	angles[0] = get_msg_arg_float(arg_angles_x);
	angles[1] = get_msg_arg_float(arg_angles_y);
	angles[2] = get_msg_arg_float(arg_angles_z);

	new delay = get_msg_arg_int(arg_delay);
	new sequence = get_msg_arg_int(arg_sequence);

	new default_body = get_msg_arg_int(arg_body);

	static msgClCorpse;

	if(!msgClCorpse) {
		msgClCorpse = get_user_msgid("ClCorpse");
	}

	for (new id = 1; id <= MaxClients; id++) {
		if (!is_user_connected(id)) {
			continue;
		}

		message_begin(MSG_ONE, msgClCorpse, .player = id);
		if (Players[id][PLAYER_SEE_MODEL]) {
			write_string(Players[player][PLAYER_MODEL][key]);
		} else {
			write_string(model);
		}
		write_long(origin[0]);
		write_long(origin[1]);
		write_long(origin[2]);
		write_coord_f(angles[0]);
		write_coord_f(angles[1]);
		write_coord_f(angles[2]);
		write_long(delay);
		write_byte(sequence);
	#if defined SUPPORT_BODY
		if (Players[id][PLAYER_SEE_MODEL]) {
			write_byte(custom_body);
		} else {
			write_byte(default_body);
		}
	#else
		write_byte(default_body);
	#endif
		write_byte(team);
		write_byte(player);
		message_end();
	}

	return PLUGIN_HANDLED;
}

public bool:NativeRegister(const plugin, const argc) {
	enum { arg_key = 1, arg_model_tt, arg_body_tt, arg_skin_tt, arg_model_ct, arg_body_ct, arg_skin_ct };
	CHECK_NATIVE_ARGS_NUM(argc, arg_skin_ct, false)

	new key[CPM_MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (Models != Invalid_Trie && TrieKeyExists(Models, key)) {
		return true;
	}

	new model[CPM_MAX_MODEL_LENGTH];
	get_string(arg_model_tt, model, charsmax(model));

	if (!loadModel(model, MODEL_INDEX_TT, MODEL_TT)) {
		log_error(AMX_ERR_NATIVE, "Error precache %s", model);
		return false;
	}

	get_string(arg_model_ct, model, charsmax(model));

	if (!loadModel(model, MODEL_INDEX_CT, MODEL_CT)) {
		log_error(AMX_ERR_NATIVE, "Error precache %s", model);
		return false;
	}

	if (Models == Invalid_Trie) {
		Models = TrieCreate();
	}

	Model[MODEL_BODY_TT] = get_param(arg_body_tt);
	Model[MODEL_BODY_CT] = get_param(arg_body_ct);
	Model[MODEL_SKIN_TT] = get_param(arg_skin_tt);
	Model[MODEL_SKIN_CT] = get_param(arg_skin_ct);

	TrieSetArray(Models, key, Model, sizeof Model);
	return true;
}

public bool:NativeHas(const plugin, const argc) {
	enum { arg_player = 1, arg_key, arg_length };
	CHECK_NATIVE_ARGS_NUM(argc, arg_length, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	if (!Players[player][PLAYER_HAS_MODEL]) {
		return false;
	}

	set_string(arg_key, Players[player][PLAYER_MODEL_KEY], get_param(arg_length));
	return true;
}

public bool:NativeGetPath(const plugin, const argc) {
	enum { arg_player = 1, arg_path, arg_length };
	CHECK_NATIVE_ARGS_NUM(argc, arg_length, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	if (!Players[player][PLAYER_HAS_MODEL]) {
		return false;
	}

	switch (get_member(player, m_iTeam)) {
		case TEAM_TERRORIST: {
			set_string(arg_path, Players[player][PLAYER_MODEL][MODEL_TT], get_param(arg_length));
			return true;
		}

		case TEAM_CT: {
			set_string(arg_path, Players[player][PLAYER_MODEL][MODEL_CT], get_param(arg_length));
			return true;
		}
	}

	return false;
}

public bool:NativeSet(const plugin, const argc) {
	enum { arg_player = 1, arg_key };
	CHECK_NATIVE_ARGS_NUM(argc, arg_key, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new key[CPM_MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));
	if (!TrieGetArray(Models, key, Model, sizeof Model)) {
		log_error(AMX_ERR_NATIVE, "Invalid key %s", key);
		return false;
	}

	Players[player][PLAYER_HAS_MODEL] = true;
	copy(Players[player][PLAYER_MODEL_KEY], CPM_MAX_KEY_LENGTH - 1, key);
	Players[player][PLAYER_MODEL] = Model;
	rh_update_user_info(player);
	return true;
}

public bool:NativeSetBody(const plugin, const argc) {
	enum { arg_player = 1, arg_team, arg_body };
	CHECK_NATIVE_ARGS_NUM(argc, arg_body, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new any:iTeam = get_param(arg_team);

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		log_error(AMX_ERR_NATIVE, "Invalid team %d", iTeam);
		return false;
	}

	new body = get_param(arg_body);

	new iSetTo = (iTeam == TEAM_TERRORIST) ? MODEL_BODY_TT : MODEL_BODY_CT;

	Players[player][PLAYER_MODEL][iSetTo] = body;
	return true;
}

public bool:NativeGetBody(const plugin, const argc) {
	enum { arg_player = 1, arg_team, arg_body };
	CHECK_NATIVE_ARGS_NUM(argc, arg_body, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new any:iTeam = get_param(arg_team);

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		log_error(AMX_ERR_NATIVE, "Invalid team %d", iTeam);
		return false;
	}

	if(!Players[player][PLAYER_HAS_MODEL]) {
		return false;
	}

	new iGetFrom = (iTeam == TEAM_TERRORIST) ? MODEL_BODY_TT : MODEL_BODY_CT;

	set_param_byref(arg_body, Players[player][PLAYER_MODEL][iGetFrom]);

	return true;
}

public bool:NativeSetSkin(const plugin, const argc) {
	enum { arg_player = 1, arg_team, arg_skin };
	CHECK_NATIVE_ARGS_NUM(argc, arg_skin, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new any:iTeam = get_param(arg_team);

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		log_error(AMX_ERR_NATIVE, "Invalid team %d", iTeam);
		return false;
	}

	new skin = get_param(arg_skin);

	new iSetTo = (iTeam == TEAM_TERRORIST) ? MODEL_SKIN_TT : MODEL_SKIN_CT;

	Players[player][PLAYER_MODEL][iSetTo] = skin;
	return true;
}

public bool:NativeGetSkin(const plugin, const argc) {
	enum { arg_player = 1, arg_team, arg_skin };
	CHECK_NATIVE_ARGS_NUM(argc, arg_skin, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	new any:iTeam = get_param(arg_team);

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		log_error(AMX_ERR_NATIVE, "Invalid team %d", iTeam);
		return false;
	}

	if(!Players[player][PLAYER_HAS_MODEL]) {
		return false;
	}

	new iGetFrom = (iTeam == TEAM_TERRORIST) ? MODEL_SKIN_TT : MODEL_SKIN_CT;

	set_param_byref(arg_skin, Players[player][PLAYER_MODEL][iGetFrom]);

	return true;
}

public bool:NativeReset(const plugin, const argc) {
	enum { arg_player = 1 };
	CHECK_NATIVE_ARGS_NUM(argc, arg_player, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	Players[player][PLAYER_HAS_MODEL] = false;
	rh_update_user_info(player);
	return true;
}

public bool:NativeEnable(const plugin, const argc) {
	enum { arg_player = 1, arg_value };
	CHECK_NATIVE_ARGS_NUM(argc, arg_value, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	Players[player][PLAYER_SEE_MODEL] = bool:get_param(arg_value);

	Receiver = player;

	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id) && Players[id][PLAYER_HAS_MODEL] && is_entity(id)) { // is_entity() as botfix
			rh_update_user_info(id);
		}
	}

	Receiver = 0;

	return true;
}

public bool:NativeIsEnable(const plugin, const argc) {
	enum { arg_player = 1 };
	CHECK_NATIVE_ARGS_NUM(argc, arg_player, false)

	new player = get_param(arg_player);
	CHECK_NATIVE_PLAYER(player, false)

	return Players[player][PLAYER_SEE_MODEL];
}

bool:loadModel(const model[], const key_index, const key_model) {
	if (!file_exists(model, true)) {
		return false;
	}
	Model[key_index] = precache_model(model);
	copy(Model[key_model], CPM_MAX_MODEL_LENGTH - 1, model);
	return true;
}

clearPlayer(const id) {
	Players[id][PLAYER_HAS_MODEL] = false;
	Players[id][PLAYER_SEE_MODEL] = true;
	arrayset(Players[id][PLAYER_MODEL_KEY], 0, CPM_MAX_KEY_LENGTH - 1);
}

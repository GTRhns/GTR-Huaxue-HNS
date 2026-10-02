#include <amxmodx>
#include <hns_matchsystem>

public plugin_init() {
	register_plugin("HNS Match Pause", "1.0", "GTR");

	new iWatcherAccess = hns_get_flag_watcher();
	RegisterSayCmd("pause", "ps", "cmdMatchPause", iWatcherAccess, "Pause match");
	RegisterSayCmd("live", "unpause", "cmdMatchUnpause", iWatcherAccess, "Unpause match");
}

public cmdMatchPause(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	hns_match_pause(id);
	return PLUGIN_HANDLED;
}

public cmdMatchUnpause(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	hns_match_unpause(id);
	return PLUGIN_HANDLED;
}

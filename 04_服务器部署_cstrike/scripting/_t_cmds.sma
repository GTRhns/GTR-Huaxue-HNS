#include <amxmodx>
#include <hns-match/addition/cmds>
public plugin_init() {
	register_plugin("tcmds", "1.0", "x");
	cmdShowTimers(0);
	return PLUGIN_CONTINUE;
}

#include <amxmodx>
#include <hns-match/globals>
#include <hns-match/addition/cmds>
forward cmdShowTimers(id1);
public plugin_init() {
	register_plugin("tc", "1.0", "x");
	cmdShowTimers(0);
	return PLUGIN_CONTINUE;
}

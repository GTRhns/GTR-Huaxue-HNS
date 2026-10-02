#include <amxmodx>
#include <_p1>
#include <_p2>
public plugin_init() {
	register_plugin("t4", "1.0", "x");
	plain_fw();
	pub_fw();
	return PLUGIN_CONTINUE;
}

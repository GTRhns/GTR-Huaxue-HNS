#include <amxmodx>
#include <_f1>
#include <_f2>
public plugin_init() {
	register_plugin("test3", "1.0", "test");
	test_forwarded();
	return PLUGIN_CONTINUE;
}

#include <amxmodx>
public plugin_init() {
	register_plugin("test", "1.0", "test");
	myfunc();
	return PLUGIN_CONTINUE;
}
public myfunc() {
	return 0;
}

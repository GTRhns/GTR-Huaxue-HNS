#include <amxmodx>
#include <hns-match/globals>
#include <hns-match/modes/mode_knife.inl>
public plugin_init() {
	register_plugin("tknife", "1.0", "x");
	kniferound_init();
	return PLUGIN_CONTINUE;
}

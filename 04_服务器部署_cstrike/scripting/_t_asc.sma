#include <amxmodx>
#include <hns-match/globals>
#include <hns-match/forwards>
#include <hns-match/modes/modes.inc>
#include <hns-match/modes/mode_ascension.inl>
public plugin_init() {
	register_plugin("tasc", "1.0", "x");
	InitGameModes();
	ascension_start();
	return PLUGIN_CONTINUE;
}

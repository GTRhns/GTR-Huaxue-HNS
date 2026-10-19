#if defined _gtr_match_host_included
	#endinput
#endif
#define _gtr_match_host_included

/*
 * callfunc bridge → HnsMatchSystem host helpers.
 * Menus/HUD/world cfg still live in the shell plugin.
 */

stock gtr_host_plugin() {
	static iPlugin = -2;
	if (iPlugin == -2)
		iPlugin = find_plugin_byfile(GTR_HOST_PLUGIN);
	return iPlugin;
}

stock bool:gtr_host_call(const szFunc[]) {
	new iPlugin = gtr_host_plugin();
	if (iPlugin == -1)
		return false;

	new iFunc = get_func_id(szFunc, iPlugin);
	if (iFunc == -1)
		return false;

	callfunc_begin_i(iFunc, iPlugin);
	callfunc_end();
	return true;
}

stock bool:gtr_host_call_cell(const szFunc[], iValue) {
	new iPlugin = gtr_host_plugin();
	if (iPlugin == -1)
		return false;

	new iFunc = get_func_id(szFunc, iPlugin);
	if (iFunc == -1)
		return false;

	callfunc_begin_i(iFunc, iPlugin);
	callfunc_push_int(iValue);
	callfunc_end();
	return true;
}

stock bool:gtr_host_call_2cell(const szFunc[], iA, iB) {
	new iPlugin = gtr_host_plugin();
	if (iPlugin == -1)
		return false;

	new iFunc = get_func_id(szFunc, iPlugin);
	if (iFunc == -1)
		return false;

	callfunc_begin_i(iFunc, iPlugin);
	callfunc_push_int(iA);
	callfunc_push_int(iB);
	callfunc_end();
	return true;
}

stock bool:gtr_host_call_str(const szFunc[], const szValue[]) {
	new iPlugin = gtr_host_plugin();
	if (iPlugin == -1)
		return false;

	new iFunc = get_func_id(szFunc, iPlugin);
	if (iFunc == -1)
		return false;

	callfunc_begin_i(iFunc, iPlugin);
	callfunc_push_str(szValue);
	callfunc_end();
	return true;
}

stock gtr_host_call_ret(const szFunc[]) {
	new iPlugin = gtr_host_plugin();
	if (iPlugin == -1)
		return 0;

	new iFunc = get_func_id(szFunc, iPlugin);
	if (iFunc == -1)
		return 0;

	callfunc_begin_i(iFunc, iPlugin);
	return callfunc_end();
}

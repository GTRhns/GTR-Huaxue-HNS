/*
 * HnsSponsorLocal.sma
 * 赞助局 ICGB 金币 本地存储插件 (nvault 兜底)
 *
 * 作用:
 *   - 当没有 MySQL / HnsMatchSql 未连接成功时, 用 nvault 本地文件
 *     存储赞助玩家的 ICGB 金币余额。
 *   - 提供 hns_gc_local_* natives, 与 HnsMatchSql 的 hns_gc_sql_*
 *     构成同一接口的两个提供方, 由 hns_gc.inc 自动选择(优先 SQL)。
 *
 * 存储键: hns_gc_<steamid>
 */

#include <amxmodx>
#include <nvault>

#define VAULT_NAME "hns_gc"
#define VAULT_PREFIX "hns_gc_"

new g_iVault;

public plugin_init() {
	register_plugin("Match: Sponsor Local (ICGB)", "1.0", "OpenHNS");
	register_library("hns_gc_local"); // 供 hns_gc.inc 的 library_exists 检测

	g_iVault = nvault_open(VAULT_NAME);
}

public plugin_end() {
	nvault_close(g_iVault);
}

public plugin_natives() {
	register_native("hns_gc_local_available", "native_gc_local_available");
	register_native("hns_gc_local_get", "native_gc_local_get");
	register_native("hns_gc_local_set", "native_gc_local_set");
}

public native_gc_local_available(amxx, params) {
	return 1;
}

public native_gc_local_get(amxx, params) {
	enum { id = 1 };

	new szKey[48];
	gc_build_key(get_param(id), szKey, charsmax(szKey));

	return nvault_get(g_iVault, szKey);
}

public native_gc_local_set(amxx, params) {
	enum { id = 1, iAmount };

	new szKey[48];
	gc_build_key(get_param(id), szKey, charsmax(szKey));

	nvault_set(g_iVault, szKey, fmt("%d", get_param(iAmount)));

	return 1;
}

stock gc_build_key(id, szKey[], iLen) {
	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szKey, iLen, "%s%s", VAULT_PREFIX, szAuthId);
}

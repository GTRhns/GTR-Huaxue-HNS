#if defined _hns_optional_sql_included
	#endinput
#endif
#define _hns_optional_sql_included

/*
 * 让 SQL / ICGB 提供方变成可选依赖。
 * 必须在 plugin_natives() 里调用 hns_register_optional_sql()。
 *
 * 无 HnsMatchSql / HnsSponsorLocal / mysql 模块时插件仍可加载,
 * 运行时走 nvault 本地存储。
 */

stock hns_register_optional_sql() {
	set_native_filter("hns_optional_native_filter");
	set_module_filter("hns_optional_module_filter");
}

stock bool:hns_sql_available() {
	return bool:LibraryExists("hns_match_sql", LibType_Library);
}

public hns_optional_native_filter(const szName[], index, trap) {
	if (trap)
		return PLUGIN_CONTINUE;

	if (contain(szName, "hns_sql_") == 0)
		return PLUGIN_HANDLED;
	if (contain(szName, "hns_gc_") == 0)
		return PLUGIN_HANDLED;
	if (contain(szName, "HnsLang_") == 0)
		return PLUGIN_HANDLED;
	if (contain(szName, "SQL_") == 0)
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public hns_optional_module_filter(const szName[], LibType:type) {
	#pragma unused type

	if (equal(szName, "sqlx")
		|| equal(szName, "mysql")
		|| equal(szName, "hns_gc_sql")
		|| equal(szName, "hns_gc_local")
		|| equal(szName, "hns_match_sql"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

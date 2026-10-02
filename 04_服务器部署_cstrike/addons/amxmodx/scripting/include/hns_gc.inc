#if defined _hns_gc_included
  #endinput
#endif
#define _hns_gc_included

/**
 * ============================================================
 *  ICGB 金币存储接口 (赞助局专用)
 * ------------------------------------------------------------
 *  提供方(二选一, 自动探测, 优先 SQL):
 *    HnsMatchSql.sma     -> hns_gc_sql_*    (MySQL 连接成功才注册)
 *    HnsSponsorLocal.sma -> hns_gc_local_*  (vault 本地文件兜底)
 *
 *  比赛插件只需调用 hns_gc_get_player / hns_gc_set_player,
 *  底层自动选择可用的提供方, 两个插件互不冲突。
 * ============================================================
 */

// ---- SQL 提供方 natives (可选, 由 HnsMatchSql 提供) ----
// 不再 #pragma reqlib: 无 SQL 时比赛核心必须能加载, 走本地 vault。
native hns_gc_sql_available();
native hns_gc_sql_get(id);
native hns_gc_sql_set(id, iAmount);

// ---- 本地提供方 natives (可选, 由 HnsSponsorLocal 提供) ----
native hns_gc_local_available();
native hns_gc_local_get(id);
native hns_gc_local_set(id, iAmount);

/* 当前是否走 SQL 存储 (SQL 真正可用 -> true, 否则 false 走本地)
 * 注意: 必须用 LibraryExists 检测库是否加载, get_func_id 只能
 *       找到本插件的 public 函数, 检测不到其他插件注册的 native,
 *       否则 SQL 未连接时兜底逻辑会永远失效。 */
stock bool:hns_gc_is_sql() {
	if (LibraryExists("hns_gc_sql", LibType_Library))
		return bool:hns_gc_sql_available();
	return false;
}

/* 当前是否有任一提供方可用 */
stock bool:hns_gc_available() {
	return (LibraryExists("hns_gc_sql", LibType_Library) || LibraryExists("hns_gc_local", LibType_Library));
}

/* 读取玩家 ICGB 余额 (无提供方时返回 0)
 * 先判断 SQL 是否真正可用(hns_gc_is_sql), 不可用时回退本地,
 * SQL 未连接成功时不会错误地走 SQL 提供方。 */
stock hns_gc_get_player(id) {
	if (hns_gc_is_sql())
		return hns_gc_sql_get(id);
	if (LibraryExists("hns_gc_local", LibType_Library))
		return hns_gc_local_get(id);
	return 0;
}

/* 写入玩家 ICGB 余额 */
stock hns_gc_set_player(id, iAmount) {
	if (iAmount < 0)
		iAmount = 0;
	if (hns_gc_is_sql())
		hns_gc_sql_set(id, iAmount);
	else if (LibraryExists("hns_gc_local", LibType_Library))
		hns_gc_local_set(id, iAmount);
}

/* 给玩家加/减 ICGB (负数为扣) */
stock hns_gc_add_player(id, iDelta) {
	if (!iDelta)
		return hns_gc_get_player(id);
	new iNew = hns_gc_get_player(id) + iDelta;
	if (iNew < 0)
		iNew = 0;
	hns_gc_set_player(id, iNew);
	return iNew;
}

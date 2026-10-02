#if defined _hns_matchsystem_sql_included
	#endinput
#endif
#define _hns_matchsystem_sql_included

/*
 * SQL natives 由 HnsMatchSql 提供, 为可选依赖。
 * 调用方必须在 plugin_natives() 里 hns_register_optional_sql(),
 * 否则无 SQL 插件时会 bad load (unknown function hns_sql_get_player_id)。
 */

/*
* Gets players table name.
*
* @param szTabiLename Buffer to copy prefix to
* @param iLen Maximum buffer size
*
* @noreturn
*/
native hns_sql_get_table_name(szTableName[], iLen);

/*
* Gets players id (`id`).
*
* @param id Client index
*
* @return player id
*/
native hns_sql_get_player_id(id);

/*
* Called when it connects to the data base
*
* @param Handle:hSqlTuple Handle to be connected
*
* @noreturn
*/
forward hns_sql_connection(hSqlTuple);

/*
* Called when we get player data
*
* @param id Client index
*
* @noreturn
*/
forward hns_sql_player_authorized(id);

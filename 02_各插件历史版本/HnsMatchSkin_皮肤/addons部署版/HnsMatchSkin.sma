/* ============================================================
   HNS Match Skin  -  玩家自定义皮肤系统
   与你的 HNS 比赛库(HnsMatchSql) 共用同一个 MySQL 库, 分表前缀 cpm_
   货币: 复用 ICGB 金币 (hns_gc_get_player / hns_gc_set_player)
   显示引擎: 依赖 CustomPlayerModelsApi.sma (模型 precache / 客户端显示)
   ------------------------------------------------------------
   模型 / 音效策略:
     - TT 款 (恐怖分子) 和 CT 款 (反恐精英) 是两条独立记录, 一行=一款
     - 每一款 = 一套模型 + 一个死亡音效, 音效可以随意复用(同音效给多款)
     - 玩家分别单独购买 TT 款 / CT 款
     - 玩家当前是 T 就只显示/使用/购买 TT 款; 当前是 C 就只显示/使用/购买 CT 款
     - 没买当前阵营的款时显示默认模型
   租期 / 永久机制:
     - 金币购买默认获得 30 天租期 (可配置), 到期自动失效, 可再次购买
     - 已购的限时皮肤可花"升级永久价格"(可配置, 默认 2000 金币)升级为永久
     - 管理员发放 = 直接永久 (expire_at=0)
   配置(在 skins.cfg 顶部 [SETTINGS] 区块):
     - rent_days        租期天数, 默认 30, 填 0 = 直接永久
     - upgrade_price    升级永久价格, 默认 2000
   玩家菜单: /skin      选已拥有/购买当前阵营的皮肤 / 升级永久
   管理菜单: /cpm       查看皮肤池 / 查看玩家拥有 / 发放(永久) / 移除
   依赖:
     - CustomPlayerModelsApi.amxx  (须在 plugins.ini 中排在本插件之前)
     - HnsMatchSql.amxx 的 SQL 连接与 ICGB 金币接口
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <fakemeta>
#include <reapi>
#include <newmenus>
#include <string>
#include <hns_optional_sql>
#include <hns_gc>
#include <custom_player_models>

// ---- 表名 (与你的 hns 库同库, cpm_ 前缀分表) ----
#define SKINS_TABLE   "cpm_skins"
#define OWNS_TABLE    "cpm_player_skins"
#define CUR_TABLE     "cpm_player_current"

// ---- 数据库连接: 直接读取你 HnsMatchSql 共用的那个 cfg ----
#define DB_CFG_FILE   "mixsystem/hnsmatch-sql.cfg"
#define DEFAULT_HOST  "127.0.0.1"
#define DEFAULT_USER  "root"
#define DEFAULT_PASS  "root"
#define DEFAULT_DB    "hns"

// ---- 死亡音效长度 ----
#define DEATH_SND_MAX 80

// ---- 皮肤数据源配置文件 (一行=一款, 启动自动导入 MySQL) ----
#define SKINS_CFG_FILE "mixsystem/skins.cfg"

#define SKIN_KEY_MAX   32
#define SKIN_MODEL_MAX 64

#define ADMIN_FLAG ADMIN_RCON

// 阵营字符
#define TEAM_CHAR_T 'T'
#define TEAM_CHAR_C 'C'

// ---- 可配置项 (在 skins.cfg 的 [SETTINGS] 区块里改, 这里只是默认值) ----
new g_iRentDays = 30;       // 金币购买获得的租期天数, 0 = 直接永久
new g_iUpgradePrice = 2000; // 限时皮肤升级为永久的价格 (ICGB金币)

static const g_szClcmds[][] = {
	"say /skin",
	"say_team /skin",
	"say /cpm",
	"say_team /cpm"
};

// 皮肤池记录 (一行 = 一个阵营款式)
enum _:pool_e {
	pool_key[SKIN_KEY_MAX],      // 唯一名字(识别/菜单/拥有都靠它, 如 hunan_t / hunan_c)
	pool_model[SKIN_MODEL_MAX],  // 模型路径 (相对 models/)
	pool_flags[16],              // 权限要求, 空=所有人
	pool_snd[DEATH_SND_MAX],     // 死亡音效 (相对 sound/, 空=不播; 可多个款复用同一个)
	pool_price,                  // 价格(ICGB金币) 0=免费
	pool_body,                   // 子模型
	pool_skin,                   // 皮肤序号
	pool_team                    // 'T' 或 'C' (该款式属于哪个阵营)
};

enum _:db_e { db_host[48], db_user[32], db_pass[32], db_db[32] };

enum _:qtype_e {
	QT_LOAD_OWNED = 1,
	QT_LOAD_CURRENT,
	QT_SAVE_CURRENT,
	QT_BUY_SKIN,
	QT_REMOVE_SKIN,
	QT_UPGRADE_SKIN
};

new g_eDb[db_e];
new Handle:g_hSqlTuple;

new Array:g_pPool;          // Array of pool_e
new Trie:g_pPoolIndex;      // key -> 池下标
new g_iPoolSize;

// 每个阵营各自的"当前选用款" key
new g_CurT[MAX_PLAYERS + 1][SKIN_KEY_MAX];   // 恐怖分子款
new g_CurC[MAX_PLAYERS + 1][SKIN_KEY_MAX];   // 反恐精英款
new Array:g_Owned[MAX_PLAYERS + 1];
new Trie:g_OwnedExpire[MAX_PLAYERS + 1];   // key -> 到期时间戳(UNIX秒), 0 = 永久
new g_szAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];
new g_iLoadGen[MAX_PLAYERS + 1];
new g_iLastTeam[MAX_PLAYERS + 1];

new Float:g_fDeathTick; // 防止同帧死亡重复播放

// 多级菜单传参暂存
new g_pendingTarget;
new g_pendingAdmin;
new g_pendingMode[8];       // "view" / "give" / "remove"

/* ============================================================
   纯工具函数
   ============================================================ */
bool:HasSkin(id, const key[]) {
	if (!g_Owned[id])
		return false;
	for (new i = 0; i < ArraySize(g_Owned[id]); i++) {
		new k[SKIN_KEY_MAX];
		ArrayGetString(g_Owned[id], i, k, charsmax(k));
		if (equal(k, key))
			return true;
	}
	return false;
}

// 返回某皮肤的到期时间戳: 0=永久,  >0=租期到期时刻,  -1=未拥有
SkinExpire(id, const key[]) {
	if (!g_OwnedExpire[id])
		return -1;
	new exp;
	if (!TrieGetCell(g_OwnedExpire[id], key, exp))
		return -1;
	return exp;
}

// 该皮肤当前是否仍然有效 (拥有 且 未过期)
bool:IsSkinValid(id, const key[]) {
	if (!HasSkin(id, key))
		return false;
	new exp = SkinExpire(id, key);
	return exp == 0 || exp > get_systime();
}

// 剩余天数 (永久返回 0)
DaysLeft(id, const key[]) {
	new exp = SkinExpire(id, key);
	if (exp <= 0)
		return 0;
	new d = (exp - get_systime()) / 86400;
	return d < 0 ? 0 : d;
}

PoolIndexOf(const key[]) {
	new idx;
	if (TrieGetCell(g_pPoolIndex, key, idx))
		return idx;
	return -1;
}

// 玩家 id 的当前阵营字符 'T' / 'C'
CharOfTeam(team) {
	if (team == TEAM_TERRORIST)
		return TEAM_CHAR_T;
	return TEAM_CHAR_C;
}

bool:IsAllowed(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	if (!row[pool_flags][0])
		return true;
	return bool:(get_user_flags(id) & read_flags(row[pool_flags]));
}

/* ============================================================
   SQL 写/读封装 (使用全局共享 tuple, 不另搞连接)
   ============================================================ */
ClearOwned(id) {
	if (g_Owned[id]) {
		ArrayDestroy(g_Owned[id]);
		g_Owned[id] = Empty_Handle;
	}
	if (g_OwnedExpire[id]) {
		TrieDestroy(g_OwnedExpire[id]);
		g_OwnedExpire[id] = Invalid_Trie;
	}
}

EscapeSql(const src[], dest[], len) {
	copy(dest, len, src);
	replace_all(dest, len, "\\", "\\\\");
	replace_all(dest, len, "'", "\\'");
}

bool:SameAuth(id, const authid[]) {
	return is_user_connected(id) && g_szAuth[id][0] && equal(g_szAuth[id], authid);
}

PackQueryData(cData[], type, id, extra = 0) {
	cData[0] = type;
	cData[1] = id;
	cData[2] = extra;
	cData[3] = g_iLoadGen[id];
	copy(cData[4], MAX_AUTHID_LENGTH - 1, g_szAuth[id]);
}

Db_LoadOwned(id, const authid[]) {
	ClearOwned(id);

	new szAuth[MAX_AUTHID_LENGTH * 2];
	EscapeSql(authid, szAuth, charsmax(szAuth));

	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_LOAD_OWNED, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("SELECT model_key, expire_at FROM %s WHERE authid='%s'", OWNS_TABLE, szAuth),
		cData, sizeof(cData));
}

Db_LoadCurrent(id, const authid[]) {
	new szAuth[MAX_AUTHID_LENGTH * 2];
	EscapeSql(authid, szAuth, charsmax(szAuth));

	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_LOAD_CURRENT, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("SELECT team, model_key FROM %s WHERE authid='%s'", CUR_TABLE, szAuth),
		cData, sizeof(cData));
}

Db_SaveCurrent(id, const authid[], const key[], teamChar) {
	new szTeam[2]; szTeam[0] = teamChar; szTeam[1] = EOS;
	new szAuth[MAX_AUTHID_LENGTH * 2], szKey[SKIN_KEY_MAX * 2];
	EscapeSql(authid, szAuth, charsmax(szAuth));
	EscapeSql(key, szKey, charsmax(szKey));

	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_SAVE_CURRENT, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("INSERT INTO %s (authid, team, model_key, updated) VALUES ('%s','%s','%s',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE model_key='%s', updated=UNIX_TIMESTAMP()",
			CUR_TABLE, szAuth, szTeam, szKey, szKey), cData, sizeof(cData));
}

// 购买/发放/重购: expireAt 为到期时间戳, 0=永久
Db_InsertOwned(id, const authid[], const key[], expireAt, iPaid = 0) {
	new szAuth[MAX_AUTHID_LENGTH * 2], szKey[SKIN_KEY_MAX * 2];
	EscapeSql(authid, szAuth, charsmax(szAuth));
	EscapeSql(key, szKey, charsmax(szKey));

	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_BUY_SKIN, id, iPaid);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("INSERT INTO %s (authid, model_key, bought_at, expire_at) VALUES ('%s','%s',UNIX_TIMESTAMP(),%d) ON DUPLICATE KEY UPDATE bought_at=UNIX_TIMESTAMP(), expire_at=%d",
			OWNS_TABLE, szAuth, szKey, expireAt, expireAt), cData, sizeof(cData));
}

// 限时皮肤升级为永久 (expire_at 置 0)
Db_SetPermanent(id, const authid[], const key[], iPaid = 0) {
	new szAuth[MAX_AUTHID_LENGTH * 2], szKey[SKIN_KEY_MAX * 2];
	EscapeSql(authid, szAuth, charsmax(szAuth));
	EscapeSql(key, szKey, charsmax(szKey));

	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_UPGRADE_SKIN, id, iPaid);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("UPDATE %s SET expire_at=0 WHERE authid='%s' AND model_key='%s'", OWNS_TABLE, szAuth, szKey),
		cData, sizeof(cData));
}

Db_RemoveOwned(id, const authid[], const key[]) {
	new szAuth[MAX_AUTHID_LENGTH * 2], szKey[SKIN_KEY_MAX * 2];
	EscapeSql(authid, szAuth, charsmax(szAuth));
	EscapeSql(key, szKey, charsmax(szKey));

	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_REMOVE_SKIN, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("DELETE FROM %s WHERE authid='%s' AND model_key='%s'", OWNS_TABLE, szAuth, szKey),
		cData, sizeof(cData));
}

/* 同步执行单条查询(预缓存阶段用)并释放, 支持 %s 等格式化 */
SQL_ExecSync(Handle:conn, const szQuery[], any:...) {
	new szQ[1024];
	vformat(szQ, charsmax(szQ), szQuery, 3);
	new Handle:q = SQL_PrepareQuery(conn, szQ);
	if (q == Empty_Handle)
		return;
	SQL_Execute(q);
	SQL_FreeHandle(q);
}

/* ============================================================
   启动: 读取连接 cfg -> 同步连接 -> 建表 -> 加载皮肤池
   ============================================================ */
bool:LoadDbCfg() {
	copy(g_eDb[db_host], charsmax(g_eDb[db_host]), DEFAULT_HOST);
	copy(g_eDb[db_user], charsmax(g_eDb[db_user]), DEFAULT_USER);
	copy(g_eDb[db_pass], charsmax(g_eDb[db_pass]), DEFAULT_PASS);
	copy(g_eDb[db_db],   charsmax(g_eDb[db_db]),   DEFAULT_DB);

	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, DB_CFG_FILE);

	if (!file_exists(szCfg))
		return false;

	new file = fopen(szCfg, "rt");
	if (!file)
		return false;

	new szLine[256], szKey[32], szVal[64];
	while (!feof(file)) {
		fgets(file, szLine, charsmax(szLine));
		if (!szLine[0] || szLine[0] == ';')
			continue;

		parse(szLine, szKey, charsmax(szKey), szVal, charsmax(szVal));
		trim(szKey); trim(szVal);

		// 去掉两端可能带的引号
		new iLen = strlen(szVal);
		if (iLen >= 2 && szVal[0] == '"' && szVal[iLen - 1] == '"') {
			szVal[iLen - 1] = EOS;
			for (new j = 0; szVal[j] && j < iLen; j++) szVal[j] = szVal[j + 1];
		}

		if (equali(szKey, "hns_host")) copy(g_eDb[db_host], charsmax(g_eDb[db_host]), szVal);
		else if (equali(szKey, "hns_user")) copy(g_eDb[db_user], charsmax(g_eDb[db_user]), szVal);
		else if (equali(szKey, "hns_pass")) copy(g_eDb[db_pass], charsmax(g_eDb[db_pass]), szVal);
		else if (equali(szKey, "hns_db"))   copy(g_eDb[db_db],   charsmax(g_eDb[db_db]),   szVal);
	}
	fclose(file);

	return true;
}

/* 从 skins.cfg 导入皮肤到 MySQL cpm_skins (两行式, 无限添加)。
 * 用区块分隔:  [TT] 下面的行都是 T 款, [CT] 下面的都是 C 款
 *             [SETTINGS] 下面配置 rent_days / upgrade_price
 * 皮肤行格式:  名字  模型路径  价格
 * 下一行(可选): wav 音效路径 (属于上一款, 可多个款复用同一个)
 * 名字即识别 key(菜单/拥有都靠它, 中文也可以, 全服唯一不能重复)
 * 用 upsert: 名字已存在则覆盖该款, 否则插入。 */
ImportSkinsToDb(Handle:conn, const szCfg[]) {
	new file = fopen(szCfg, "rt");
	if (!file) {
		log_amx("[Skin] 皮肤配置文件不存在: %s", szCfg);
		return;
	}

	new szLine[512], szHead[32], szRestA[384], szRestB[384];
	new szKey[SKIN_KEY_MAX], szModel[SKIN_MODEL_MAX];
	new sTeam[2], sPrice[16], sWav[DEATH_SND_MAX];
	new iImported;
	new bool:bPending;
	new bool:bSettings;

	while (!feof(file)) {
		fgets(file, szLine, charsmax(szLine));
		trim(szLine);
		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue;

		// 区块头: [TT]/[T] / [CT] / [SETTINGS]
		if (szLine[0] == '[') {
			if (bPending) {
				CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav);
				iImported++;
			}
			parse(szLine, szHead, charsmax(szHead), szRestA, charsmax(szRestA));
			TrimBracket(szHead);
			if (equali(szHead, "settings")) {
				bSettings = true;
			} else if (equali(szHead, "tt") || equali(szHead, "t")) {
				sTeam[0] = TEAM_CHAR_T;
				bSettings = false;
			} else if (equali(szHead, "ct")) {
				sTeam[0] = TEAM_CHAR_C;
				bSettings = false;
			} else {
				sTeam[0] = EOS;
				bSettings = false;
			}
			bPending = false;
			continue;
		}

		parse(szLine, szHead, charsmax(szHead), szRestA, charsmax(szRestA));
		trim(szHead);

		// [SETTINGS] 区块:  key value
		if (bSettings) {
			new szVal[16];
			copy(szVal, charsmax(szVal), szRestA);
			trim(szVal);
			StripQuotes(szVal);
			if (equali(szHead, "rent_days"))
				g_iRentDays = str_to_num(szVal);
			else if (equali(szHead, "upgrade_price"))
				g_iUpgradePrice = str_to_num(szVal);
			continue;
		}

		// 裸区块头 tt / t / ct (单独一行, 不带方括号)
		if ((equali(szHead, "tt") || equali(szHead, "t") || equali(szHead, "ct")) && !szRestA[0]) {
			if (bPending) {
				CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav);
				iImported++;
			}
			if (equali(szHead, "tt") || equali(szHead, "t")) sTeam[0] = TEAM_CHAR_T;
			else sTeam[0] = TEAM_CHAR_C;
			bPending = false;
			continue;
		}

		// 音效行: 以 wav 开头, 属于上一款
		if (equali(szHead, "wav")) {
			copy(sWav, charsmax(sWav), szRestA);
			trim(sWav);
			StripQuotes(sWav);
			continue;
		}

		// 新皮肤行: 先提交上一款
		if (bPending) {
			CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav);
			iImported++;
		}

		// 名字 模型 价格 (阵营来自当前区块)
		copy(szKey, charsmax(szKey), szHead);
		StripQuotes(szKey);
		strtok(szRestA, szModel, charsmax(szModel), szRestB, charsmax(szRestB));
		copy(sPrice, charsmax(sPrice), szRestB);
		trim(szModel); trim(sPrice);
		StripQuotes(szModel); StripQuotes(sPrice);

		if (!szKey[0] || (sTeam[0] != TEAM_CHAR_T && sTeam[0] != TEAM_CHAR_C) || !szModel[0]) {
			bPending = false;
			continue;
		}
		sWav[0] = EOS;
		bPending = true;
	}
	if (bPending) {
		CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav);
		iImported++;
	}

	fclose(file);
	log_amx("[Skin] 从 %s 导入/更新皮肤 %d 条", szCfg, iImported);
}

/* 把 "[TT]" / "[ct]  " 这类区块头清洗成 "tt" / "ct" */
TrimBracket(sz[]) {
	new i;
	while (sz[i] == '[' || sz[i] == ' ')
		i++;
	new j = 0;
	while (sz[i] && sz[i] != ']' && sz[i] != ' ') {
		sz[j++] = sz[i++];
	}
	sz[j] = EOS;
}

/* 把一款皮肤 upsert 到 cpm_skins (名字唯一, 重复则覆盖该款) */
CommitSkinRow(Handle:conn, const szKey[], const sTeam[], const szModel[], const sPrice[], const sWav[]) {
	SQL_ExecSync(conn, fmt(
		"INSERT INTO %s (model_key, team, model, body, skin, price, flags, death_sound, created, updated) VALUES ('%s','%s','%s',0,0,%s,'','%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE team=VALUES(team), model=VALUES(model), price=VALUES(price), death_sound=VALUES(death_sound), active=1, updated=UNIX_TIMESTAMP()",
		SKINS_TABLE, szKey, sTeam, szModel, sPrice, sWav));
}

StripQuotes(sz[]) {
	new iLen = strlen(sz);
	if (iLen >= 2 && sz[0] == '"' && sz[iLen - 1] == '"') {
		sz[iLen - 1] = EOS;
		for (new j = 0; sz[j] && j < iLen; j++) sz[j] = sz[j + 1];
	}
}

CreateTablesSync(Handle:conn) {
	SQL_ExecSync(conn, fmt("CREATE TABLE IF NOT EXISTS %s (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, model_key VARCHAR(32) NOT NULL, team CHAR(1) NOT NULL DEFAULT '', model VARCHAR(64) NOT NULL, body TINYINT NOT NULL DEFAULT 0, skin TINYINT NOT NULL DEFAULT 0, price INT NOT NULL DEFAULT 0, flags VARCHAR(16) NOT NULL DEFAULT '', death_sound VARCHAR(80) NOT NULL DEFAULT '', active TINYINT NOT NULL DEFAULT 1, created INT NOT NULL DEFAULT 0, updated INT NOT NULL DEFAULT 0, UNIQUE KEY uk_key (model_key))", SKINS_TABLE));

	SQL_ExecSync(conn, fmt("CREATE TABLE IF NOT EXISTS %s (authid VARCHAR(64) NOT NULL, model_key VARCHAR(32) NOT NULL, bought_at INT NOT NULL DEFAULT 0, expire_at INT NOT NULL DEFAULT 0, PRIMARY KEY (authid, model_key), KEY idx_authid (authid))", OWNS_TABLE));

	// 老库升级: 补 expire_at 列 (已存在则自动忽略错误)
	SQL_ExecSync(conn, fmt("ALTER TABLE %s ADD COLUMN expire_at INT NOT NULL DEFAULT 0", OWNS_TABLE));

	SQL_ExecSync(conn, fmt("CREATE TABLE IF NOT EXISTS %s (authid VARCHAR(64) NOT NULL, team CHAR(1) NOT NULL DEFAULT '', model_key VARCHAR(32) NOT NULL DEFAULT '', updated INT NOT NULL DEFAULT 0, PRIMARY KEY (authid, team))", CUR_TABLE));
}

LoadPoolSync(Handle:conn) {
	new Handle:q = SQL_PrepareQuery(conn,
		fmt("SELECT model_key, team, model, body, skin, price, flags, death_sound FROM %s WHERE active=1", SKINS_TABLE));
	if (q == Empty_Handle)
		return;

	SQL_Execute(q);

	if (SQL_MoreResults(q)) {
		new iKey  = SQL_FieldNameToNum(q, "model_key");
		new iTeam = SQL_FieldNameToNum(q, "team");
		new iM    = SQL_FieldNameToNum(q, "model");
		new iB    = SQL_FieldNameToNum(q, "body");
		new iS    = SQL_FieldNameToNum(q, "skin");
		new iP    = SQL_FieldNameToNum(q, "price");
		new iF    = SQL_FieldNameToNum(q, "flags");
		new iSnd  = SQL_FieldNameToNum(q, "death_sound");

		while (SQL_MoreResults(q)) {
			new row[pool_e];
			new szTeam[2];
			SQL_ReadResult(q, iKey,  row[pool_key],  charsmax(row[pool_key]));
			SQL_ReadResult(q, iTeam, szTeam, charsmax(szTeam));
			row[pool_team] = szTeam[0];
			SQL_ReadResult(q, iM,    row[pool_model], charsmax(row[pool_model]));
			row[pool_body] = SQL_ReadResult(q, iB);
			row[pool_skin] = SQL_ReadResult(q, iS);
			row[pool_price] = SQL_ReadResult(q, iP);
			SQL_ReadResult(q, iF,    row[pool_flags], charsmax(row[pool_flags]));
			SQL_ReadResult(q, iSnd,  row[pool_snd],   charsmax(row[pool_snd]));

			// 预缓存死亡音效 (若配置了)
			if (row[pool_snd][0])
				precache_sound(row[pool_snd]);

			// 注册给显示引擎: 该款式两边都登记为同一个模型
			if (custom_player_models_register(row[pool_key], row[pool_model],
				row[pool_body], row[pool_skin],
				row[pool_model], row[pool_body], row[pool_skin])) {
				ArrayPushArray(g_pPool, row, sizeof row);
				TrieSetCell(g_pPoolIndex, row[pool_key], g_iPoolSize);
				g_iPoolSize++;
			} else {
				log_amx("[Skin] 预缓存失败(模型文件缺失?): %s", row[pool_model]);
			}

			SQL_NextRow(q);
		}
	}

	SQL_FreeHandle(q);
	log_amx("[Skin] 皮肤池加载完成, 共 %d 个皮肤", g_iPoolSize);
}

DbPrecachePool() {
	new szErr[160], iErr;
	new Handle:conn = SQL_Connect(g_hSqlTuple, iErr, szErr, charsmax(szErr));
	if (conn == Empty_Handle) {
		log_amx("[Skin] 数据库连接失败(%d): %s, 本次启动未预缓存皮肤池", iErr, szErr);
		return;
	}

	CreateTablesSync(conn);

	// 皮肤配置文件(skins.cfg) -> MySQL 导入/更新
	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, SKINS_CFG_FILE);
	ImportSkinsToDb(conn, szCfg);

	LoadPoolSync(conn);

	SQL_FreeHandle(conn);
}

/* ============================================================
   选用 / 购买 逻辑
   ============================================================ */
// 取玩家当前阵营槽里存的名字
CurSlot(id, dest[], len, teamChar) {
	if (teamChar == TEAM_CHAR_T)
		copy(dest, len, g_CurT[id]);
	else
		copy(dest, len, g_CurC[id]);
}

// 应用当前阵营的皮肤: 有则 set, 无则 reset
ApplyCurrentSkin(id) {
	new teamChar = CharOfTeam(get_member(id, m_iTeam));
	new key[SKIN_KEY_MAX];
	CurSlot(id, key, charsmax(key), teamChar);

	if (key[0] && PoolIndexOf(key) != -1 && IsSkinValid(id, key)) {
		custom_player_models_set(id, key);
		client_print_color(id, print_team_default, "^4[皮肤]^1 已应用皮肤: ^3%s", key);
	} else {
		custom_player_models_reset(id);
	}
}

SelectSkin(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	custom_player_models_set(id, row[pool_key]);
	// 写入对应阵营槽
	if (row[pool_team] == TEAM_CHAR_T)
		copy(g_CurT[id], charsmax(g_CurT[]), row[pool_key]);
	else
		copy(g_CurC[id], charsmax(g_CurC[]), row[pool_key]);

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));
	Db_SaveCurrent(id, authid, row[pool_key], row[pool_team]);

	client_print_color(id, print_team_blue, "^4[皮肤]^1 你已选用%s阵营皮肤: ^3%s",
		row[pool_team] == TEAM_CHAR_T ? " T(恐怖分子)" : " CT(反恐精英)", row[pool_key]);
}

DoBuy(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	// 已永久拥有: 不能再买
	new exp = SkinExpire(id, row[pool_key]);
	if (exp == 0) {
		client_print_color(id, print_team_blue, "^4[皮肤]^1 你已永久拥有该皮肤");
		return;
	}
	// 租期还有效: 无需重复购买
	if (exp > 0 && exp > get_systime()) {
		client_print_color(id, print_team_blue, "^4[皮肤]^1 你已拥有该皮肤(剩 ^3%d^1 天), 无需重复购买", DaysLeft(id, row[pool_key]));
		return;
	}

	new iGold = hns_gc_get_player(id);
	if (iGold < row[pool_price]) {
		client_print_color(id, print_team_red, "^4[皮肤]^1 金币不足! 需要 %d, 你有 %d", row[pool_price], iGold);
		return;
	}

	hns_gc_set_player(id, iGold - row[pool_price]);

	if (!g_Owned[id])
		g_Owned[id] = ArrayCreate(SKIN_KEY_MAX);
	if (!g_OwnedExpire[id])
		g_OwnedExpire[id] = TrieCreate();
	if (!HasSkin(id, row[pool_key]))
		ArrayPushString(g_Owned[id], row[pool_key]);

	// 到期时间戳: 0 = 永久
	new iExpire = (g_iRentDays > 0) ? get_systime() + g_iRentDays * 86400 : 0;
	TrieSetCell(g_OwnedExpire[id], row[pool_key], iExpire);

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));
	Db_InsertOwned(id, authid, row[pool_key], iExpire, row[pool_price]);

	SelectSkin(id, idx);
	if (iExpire == 0)
		client_print_color(id, print_team_blue, "^4[皮肤]^1 购买成功(永久)! 剩余金币 %d", iGold - row[pool_price]);
	else
		client_print_color(id, print_team_blue, "^4[皮肤]^1 购买成功! 租期 %d 天, 剩余金币 %d", g_iRentDays, iGold - row[pool_price]);
}

// 花费 upgrade_price 把已购限时皮肤升级为永久
DoUpgrade(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	new exp = SkinExpire(id, row[pool_key]);
	if (exp == 0) {
		client_print_color(id, print_team_blue, "^4[皮肤]^1 该皮肤已经是永久了");
		return;
	}
	if (exp < 0 || (exp > 0 && exp <= get_systime())) {
		client_print_color(id, print_team_red, "^4[皮肤]^1 你还没有有效的 %s, 先购买后再升级", row[pool_key]);
		return;
	}

	new iGold = hns_gc_get_player(id);
	if (iGold < g_iUpgradePrice) {
		client_print_color(id, print_team_red, "^4[皮肤]^1 金币不足! 升级永久需要 %d, 你有 %d", g_iUpgradePrice, iGold);
		return;
	}

	hns_gc_set_player(id, iGold - g_iUpgradePrice);

	TrieSetCell(g_OwnedExpire[id], row[pool_key], 0);

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));
	Db_SetPermanent(id, authid, row[pool_key], g_iUpgradePrice);

	client_print_color(id, print_team_blue, "^4[皮肤]^1 升级永久成功! 皮肤 ^3%s^1 现在永久有效, 剩余金币 %d", row[pool_key], iGold - g_iUpgradePrice);
}

OnSkinChosen(id, idx) {
	if (idx < 0 || idx >= g_iPoolSize)
		return;

	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	if (IsSkinValid(id, row[pool_key]))
		SelectSkin(id, idx);
	else
		MenuConfirmBuy(id, idx);
}

/* ============================================================
   管理操作
   ============================================================ */
GiveSkinTo(target, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	if (!g_Owned[target])
		g_Owned[target] = ArrayCreate(SKIN_KEY_MAX);
	if (!g_OwnedExpire[target])
		g_OwnedExpire[target] = TrieCreate();

	// 已拥有则直接升级为永久, 未拥有则新增
	if (!HasSkin(target, row[pool_key]))
		ArrayPushString(g_Owned[target], row[pool_key]);
	TrieSetCell(g_OwnedExpire[target], row[pool_key], 0);  // 管理员发放 = 永久

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(target, authid, charsmax(authid));
	Db_InsertOwned(target, authid, row[pool_key], 0);

	client_print_color(g_pendingAdmin, print_team_default, "^4[皮肤]^1 已向 %n 发放永久皮肤 ^3%s", target, row[pool_key]);
	client_print_color(target, print_team_default, "^4[皮肤]^1 管理员为你发放了永久皮肤 ^3%s", row[pool_key]);
}

RemoveSkinFrom(target, const key[]) {
	if (!g_Owned[target])
		return;

	new count = ArraySize(g_Owned[target]);
	for (new i = 0; i < count; i++) {
		new k[SKIN_KEY_MAX];
		ArrayGetString(g_Owned[target], i, k, charsmax(k));
		if (equal(k, key)) {
			ArrayDeleteItem(g_Owned[target], i);
			break;
		}
	}
	if (g_OwnedExpire[target])
		TrieDeleteKey(g_OwnedExpire[target], key);

	// 若移除的是当前阵营正在用的, 重置对应槽
	new idx = PoolIndexOf(key);
	if (idx != -1) {
		new row[pool_e];
		ArrayGetArray(g_pPool, idx, row, sizeof row);
		new teamChar = row[pool_team];
		new cur[SKIN_KEY_MAX];
		CurSlot(target, cur, charsmax(cur), teamChar);
		if (cur[0] && equal(cur, key)) {
			// 清掉该营地槽
			if (teamChar == TEAM_CHAR_T)
				g_CurT[target][0] = EOS;
			else
				g_CurC[target][0] = EOS;
			ApplyCurrentSkin(target);
		}
	}

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(target, authid, charsmax(authid));
	Db_RemoveOwned(target, authid, key);

	client_print_color(g_pendingAdmin, print_team_default, "^4[皮肤]^1 已移除 %n 的皮肤 ^3%s", target, key);
}

/* ============================================================
   菜单构建 (非 public, 直接调用)
   ============================================================ */
MenuSkin(id) {
	if (g_iPoolSize == 0) {
		client_print_color(id, print_team_red, "^4[皮肤]^1 皮肤池为空");
		return;
	}

	new teamChar = CharOfTeam(get_member(id, m_iTeam));

	new menu = menu_create(fmt(" 选择皮肤 (当前%s)  (可翻页)",
		teamChar == TEAM_CHAR_T ? "T-恐怖分子" : "CT-反恐精英"), "SkinHandler");
	new szInfo[12], szTxt[160];
	menu_addtext(menu, fmt(" 我的金币: ^4%d", hns_gc_get_player(id)), _);
	menu_additem(menu, fmt("升级已购皮肤为永久 (%d金币)", g_iUpgradePrice), "up");

	new added;
	for (new i = 0; i < g_iPoolSize; i++) {
		if (!IsAllowed(id, i))
			continue;

		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);

		// 只显示当前阵营的款式
		if (row[pool_team] != teamChar)
			continue;

		new cur[SKIN_KEY_MAX];
		CurSlot(id, cur, charsmax(cur), teamChar);

		new exp = SkinExpire(id, row[pool_key]);
		if (HasSkin(id, row[pool_key]) && exp != 0 && exp <= get_systime()) {
			// 已过期: 点击 = 重新购买
			if (row[pool_price] == 0)
				format(szTxt, charsmax(szTxt), "\y%s\w  [已过期] [免费重取]", row[pool_key]);
			else
				format(szTxt, charsmax(szTxt), "\y%s\w  [已过期] [%d金币重购]", row[pool_key], row[pool_price]);
		} else if (HasSkin(id, row[pool_key])) {
			new szStat[24];
			if (exp == 0)
				copy(szStat, charsmax(szStat), "  [永久]");
			else
				format(szStat, charsmax(szStat), "  [剩%d天]", DaysLeft(id, row[pool_key]));
			format(szTxt, charsmax(szTxt), "\y%s\w %s[%s]",
				row[pool_key], szStat,
				cur[0] && equal(cur, row[pool_key]) ? "当前使用" : "点击使用");
		} else if (row[pool_price] == 0) {
			format(szTxt, charsmax(szTxt), "\y%s\w   [免费获取%s]", row[pool_key],
				g_iRentDays > 0 ? fmt("·%d天", g_iRentDays) : "(永久)");
		} else {
			format(szTxt, charsmax(szTxt), "\y%s\w   [%d金币%s]", row[pool_key], row[pool_price],
				g_iRentDays > 0 ? fmt("·%d天", g_iRentDays) : "·永久");
		}

		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}

	if (!added)
		menu_addtext(menu, "  (当前阵营没有可用皮肤)", _);

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

MenuConfirmBuy(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	if (row[pool_price] == 0) {  // 免费皮肤直接获取
		DoBuy(id, idx);
		return;
	}

	new menu = menu_create(" 确定购买?", "ConfirmHandler");
	new szInfo[12], szTxt[128];
	num_to_str(idx, szInfo, charsmax(szInfo));
	format(szTxt, charsmax(szTxt), "\y%s\w   %d 金币%s",
		row[pool_key], row[pool_price],
		g_iRentDays > 0 ? fmt("(租期%d天)", g_iRentDays) : "(永久)");
	menu_additem(menu, szTxt, szInfo);
	menu_additem(menu, "取消", "cancel");
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

MenuUpgrade(id) {
	new menu = menu_create(fmt(" 升级永久皮肤 (每款 %d 金币)", g_iUpgradePrice), "UpgradeHandler");
	new szInfo[12], szTxt[160], added;
	menu_addtext(menu, fmt(" 我的金币: ^4%d", hns_gc_get_player(id)), _);
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		new exp = SkinExpire(id, row[pool_key]);
		// 只列"正在租期中的款": 未拥有/已永久/已过期 都不列
		if (exp <= 0 || exp <= get_systime())
			continue;
		format(szTxt, charsmax(szTxt), "\y%s\w   [剩%d天]  -> 升级为永久", row[pool_key], DaysLeft(id, row[pool_key]));
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}
	if (!added)
		menu_addtext(menu, " (没有正在租期中的皮肤)", _);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

MenuConfirmUpgrade(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	new menu = menu_create(" 升级为永久?", "UpgradeConfirmHandler");
	new szInfo[12], szTxt[128];
	num_to_str(idx, szInfo, charsmax(szInfo));
	format(szTxt, charsmax(szTxt), "\y%s\w   花费 %d 金币升级为永久", row[pool_key], g_iUpgradePrice);
	menu_additem(menu, szTxt, szInfo);
	menu_additem(menu, "取消", "cancel");
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

MenuAdmin(id) {
	new menu = menu_create(" 皮肤管理(管理员)", "AdminHandler");
	menu_additem(menu, "查看皮肤池", "1");
	menu_additem(menu, "查看玩家已拥有皮肤", "2");
	menu_additem(menu, "给玩家发放皮肤", "3");
	menu_additem(menu, "移除玩家皮肤", "4");
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

MenuPoolList(id) {
	if (g_iPoolSize == 0) {
		client_print_color(id, print_team_red, "^4[皮肤]^1 皮肤池为空");
		return;
	}

	new menu = menu_create(" 皮肤池  (可翻页)", "PoolListHandler");
	new szInfo[12], szTxt[160], szFlags[16];
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (row[pool_flags][0]) copy(szFlags, charsmax(szFlags), row[pool_flags]);
		else copy(szFlags, charsmax(szFlags), "*");
		format(szTxt, charsmax(szTxt), "\y[%s]\w %s  价格%d   权限%s",
			row[pool_team] == TEAM_CHAR_T ? "T" : "CT",
			row[pool_key], row[pool_price], szFlags);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

MenuPickPlayer(const mode[], id) {
	copy(g_pendingMode, charsmax(g_pendingMode), mode);
	g_pendingAdmin = id;

	new szTitle[48];
	if (g_pendingMode[0] == 'v') copy(szTitle, charsmax(szTitle), " 选择玩家 - 查看拥有");
	else if (g_pendingMode[0] == 'g') copy(szTitle, charsmax(szTitle), " 选择玩家 - 发放");
	else copy(szTitle, charsmax(szTitle), " 选择玩家 - 移除");

	new menu = menu_create(szTitle, "PickPlayerHandler");
	new szTxt[64];
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i))
			continue;
		get_user_name(i, szTxt, charsmax(szTxt));
		menu_additem(menu, szTxt, fmt("%d", i));
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

MenuViewOwned(id, target) {
	g_pendingTarget = target;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new teamChar = CharOfTeam(get_member(target, m_iTeam));
	new menu = menu_create(fmt(" %s 拥有的皮肤 (当前%s)",
		szName, teamChar == TEAM_CHAR_T ? "T" : "CT"), "ViewOwnedHandler");
	new szTxt[128];
	if (g_Owned[target] && ArraySize(g_Owned[target]) > 0) {
		for (new i = 0; i < ArraySize(g_Owned[target]); i++) {
			new key[SKIN_KEY_MAX];
			ArrayGetString(g_Owned[target], i, key, charsmax(key));
			new idx = PoolIndexOf(key);
			new exp = SkinExpire(target, key);
			new szStat[24];
			if (exp == 0)
				copy(szStat, charsmax(szStat), "  [永久]");
			else if (exp > get_systime())
				format(szStat, charsmax(szStat), "  [剩%d天]", DaysLeft(target, key));
			else
				copy(szStat, charsmax(szStat), "  [已过期]");
			format(szTxt, charsmax(szTxt), "\y[%s]\w %s%s%s",
				(idx != -1) ? (PoolTeamChar(idx) == TEAM_CHAR_T ? "T" : "CT") : "?",
				key, szStat,
				(cur_match(target, key, teamChar)) ? "  [当前使用]" : "");
			menu_additem(menu, szTxt);
		}
	} else {
		menu_additem(menu, "(该玩家没有皮肤)");
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

// 辅助: 判断 key 是否等于 target 当前阵营正在用的款
bool:cur_match(target, const key[], teamChar) {
	new cur[SKIN_KEY_MAX];
	CurSlot(target, cur, charsmax(cur), teamChar);
	return cur[0] && equal(cur, key);
}

MenuGiveSkin(id, target) {
	g_pendingTarget = target;
	g_pendingAdmin = id;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new teamChar = CharOfTeam(get_member(target, m_iTeam));
	new menu = menu_create(fmt(" 给 %s 发放皮肤 (当前%s)",
		szName, teamChar == TEAM_CHAR_T ? "T" : "CT"), "GiveSkinHandler");
	new szInfo[12], szTxt[160];
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (row[pool_team] != teamChar)
			continue;
		format(szTxt, charsmax(szTxt), "\y[%s]\w %s%s   [%d金币]",
			row[pool_team] == TEAM_CHAR_T ? "T" : "CT", row[pool_key],
			HasSkin(target, row[pool_key]) ? "  (已拥有)" : "", row[pool_price]);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

MenuRemoveSkin(id, target) {
	g_pendingTarget = target;
	g_pendingAdmin = id;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new menu = menu_create(fmt(" 移除 %s 的皮肤", szName), "RemoveSkinHandler");
	new szTxt[128];
	if (g_Owned[target] && ArraySize(g_Owned[target]) > 0) {
		for (new i = 0; i < ArraySize(g_Owned[target]); i++) {
			new key[SKIN_KEY_MAX];
			ArrayGetString(g_Owned[target], i, key, charsmax(key));
			new idx = PoolIndexOf(key);
			format(szTxt, charsmax(szTxt), "[%s] %s",
				(idx != -1) ? (PoolTeamChar(idx) == TEAM_CHAR_T ? "T" : "CT") : "?",
				key);
			menu_additem(menu, szTxt, key);
		}
	} else {
		menu_additem(menu, "(该玩家没有皮肤)");
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

PoolTeamChar(idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	return row[pool_team];
}

/* ============================================================
   事件 / 菜单回调 (public)
   ============================================================ */
public plugin_natives() {
	hns_register_optional_sql();
}

public plugin_precache() {
	if (!LoadDbCfg())
		return;

	g_hSqlTuple = SQL_MakeDbTuple(g_eDb[db_host], g_eDb[db_user], g_eDb[db_pass], g_eDb[db_db]);
	SQL_SetCharset(g_hSqlTuple, "utf8");

	g_pPool = ArrayCreate(pool_e);
	g_pPoolIndex = TrieCreate();

	// 建表 -> 从 skins.cfg 导入皮肤 -> 加载皮肤池(含预缓存模型与死亡音效)
	DbPrecachePool();
}

public plugin_init() {
	register_plugin("HNS Match Skin", "1.0.0", "OpenHNS");

	for (new i = 0; i < sizeof(g_szClcmds); i++)
		register_clcmd(g_szClcmds[i], "Cl_Cmd");

	// 换队/进服时按当前阵营自动应用对应款式
	register_forward(FM_PlayerPreThink, "fwd_PlayerPreThink");

	RegisterHookChain(RG_CBasePlayer_Killed, "PlayerKilled", true);
}

public plugin_end() {
	if (g_pPool) { ArrayDestroy(g_pPool); g_pPool = Empty_Handle; }
	if (g_pPoolIndex) { TrieDestroy(g_pPoolIndex); g_pPoolIndex = Invalid_Trie; }
	for (new i = 1; i <= MaxClients; i++) {
		if (g_Owned[i])
			ArrayDestroy(g_Owned[i]);
		if (g_OwnedExpire[i])
			TrieDestroy(g_OwnedExpire[i]);
	}
	if (g_hSqlTuple) {
		SQL_FreeHandle(g_hSqlTuple);
		g_hSqlTuple = Empty_Handle;
	}
}

/* 玩家死亡: 若当前阵营款配了死亡音效, 全场广播播放 */
public PlayerKilled(victim, attacker) {
	if (!is_user_connected(victim))
		return;

	new teamChar = CharOfTeam(get_member(victim, m_iTeam));
	new key[SKIN_KEY_MAX];
	CurSlot(victim, key, charsmax(key), teamChar);
	if (!key[0])
		return;

	new idx = PoolIndexOf(key);
	if (idx == -1)
		return;

	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	if (!row[pool_snd][0])
		return;

	// 防止同帧死亡重复触发
	if (get_gametime() <= g_fDeathTick)
		return;
	g_fDeathTick = get_gametime();

	// 全场广播: 给每个在线玩家 spk
	for (new i = 1; i <= MaxClients; i++)
		if (is_user_connected(i))
			client_cmd(i, "spk %s", row[pool_snd]);
}

/* 检测队伍变化(含进场), 自动把当前阵营的款应用上去 */
public fwd_PlayerPreThink(id) {
	if (!is_user_alive(id))
		return FMRES_IGNORED;

	new team = get_member(id, m_iTeam);
	if (team != TEAM_TERRORIST && team != TEAM_CT)
		return FMRES_IGNORED;

	new t = CharOfTeam(team);
	if (g_iLastTeam[id] == t)
		return FMRES_IGNORED;
	g_iLastTeam[id] = t;

	new key[SKIN_KEY_MAX];
	CurSlot(id, key, charsmax(key), t);
	if (key[0] && PoolIndexOf(key) != -1 && IsSkinValid(id, key))
		custom_player_models_set(id, key);
	else
		custom_player_models_reset(id);

	return FMRES_IGNORED;
}

public client_authorized(id) {
	if (!g_hSqlTuple || is_user_bot(id) || is_user_hltv(id))
		return;

	g_iLoadGen[id]++;
	get_user_authid(id, g_szAuth[id], charsmax(g_szAuth[]));
	Db_LoadOwned(id, g_szAuth[id]);
}

public client_disconnected(id) {
	g_iLoadGen[id]++;
	g_szAuth[id][0] = EOS;
	ClearOwned(id);
	g_iLastTeam[id] = 0;
	g_CurT[id][0] = EOS;
	g_CurC[id][0] = EOS;
}

RefundGold(id, iPaid) {
	if (iPaid <= 0 || !is_user_connected(id))
		return;
	hns_gc_set_player(id, hns_gc_get_player(id) + iPaid);
	client_print_color(id, print_team_red, "^4[皮肤]^1 数据库写入失败, 已退回 ^3%d^1 金币", iPaid);
}

public SqlHandler(failstate, Handle:query, error[], errnum, data[], size, Float:queueTime) {
	new id = data[1];
	new iPaid = data[2];
	new iGen = data[3];
	new szAuth[MAX_AUTHID_LENGTH];
	copy(szAuth, charsmax(szAuth), data[4]);

	if (failstate != TQUERY_SUCCESS) {
		log_amx("[Skin] SQL错误(%d): %s", errnum, error);
		if ((data[0] == QT_BUY_SKIN || data[0] == QT_UPGRADE_SKIN) && SameAuth(id, szAuth) && iGen == g_iLoadGen[id])
			RefundGold(id, iPaid);
		return PLUGIN_HANDLED;
	}

	if (!SameAuth(id, szAuth) || iGen != g_iLoadGen[id])
		return PLUGIN_HANDLED;

	switch (data[0]) {
		case QT_LOAD_OWNED: {
			ClearOwned(id);
			g_Owned[id] = ArrayCreate(SKIN_KEY_MAX);
			g_OwnedExpire[id] = TrieCreate();
			new now = get_systime();
			while (SQL_MoreResults(query)) {
				new key[SKIN_KEY_MAX];
				SQL_ReadResult(query, 0, key, charsmax(key));
				new exp = SQL_ReadResult(query, 1);
				// 已过期的租期记录: 不算拥有, 顺手清掉库里的
				if (exp != 0 && exp <= now) {
					Db_RemoveOwned(id, szAuth, key);
					SQL_NextRow(query);
					continue;
				}
				ArrayPushString(g_Owned[id], key);
				TrieSetCell(g_OwnedExpire[id], key, exp);
				SQL_NextRow(query);
			}
			Db_LoadCurrent(id, szAuth);
		}
		case QT_LOAD_CURRENT: {
			g_CurT[id][0] = EOS;
			g_CurC[id][0] = EOS;
			new iTeam = SQL_FieldNameToNum(query, "team");
			new iKey  = SQL_FieldNameToNum(query, "model_key");
			while (SQL_MoreResults(query)) {
				new szTeam[2];
				SQL_ReadResult(query, iTeam, szTeam, charsmax(szTeam));
				if (szTeam[0] == TEAM_CHAR_T)
					SQL_ReadResult(query, iKey, g_CurT[id], charsmax(g_CurT[]));
				else
					SQL_ReadResult(query, iKey, g_CurC[id], charsmax(g_CurC[]));
				SQL_NextRow(query);
			}
			ApplyCurrentSkin(id);
		}
	}

	return PLUGIN_HANDLED;
}

public Cl_Cmd(id) {
	new szArg[64];
	read_argv(0, szArg, charsmax(szArg));

	if (containi(szArg, "/cpm") != -1) {
		if (get_user_flags(id) & ADMIN_FLAG)
			MenuAdmin(id);
		else
			client_print_color(id, print_team_red, "^4[皮肤]^1 你没有管理权限");
	} else {
		MenuSkin(id);
	}
	return PLUGIN_HANDLED;
}

public SkinHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		if (equal(szInfo, "up"))
			MenuUpgrade(id);
		else
			OnSkinChosen(id, str_to_num(szInfo));
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public ConfirmHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		if (str_to_num(szInfo) >= 0 && !equal(szInfo, "cancel"))
			DoBuy(id, str_to_num(szInfo));
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public UpgradeHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		MenuConfirmUpgrade(id, str_to_num(szInfo));
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public UpgradeConfirmHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		if (str_to_num(szInfo) >= 0 && !equal(szInfo, "cancel"))
			DoUpgrade(id, str_to_num(szInfo));
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public AdminHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		switch (str_to_num(szInfo)) {
			case 1: MenuPoolList(id);
			case 2: MenuPickPlayer("view", id);
			case 3: MenuPickPlayer("give", id);
			case 4: MenuPickPlayer("remove", id);
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public PoolListHandler(id, menu, item) {
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public PickPlayerHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		new target = str_to_num(szInfo);
		if (is_user_connected(target)) {
			if (g_pendingMode[0] == 'v') MenuViewOwned(id, target);
			else if (g_pendingMode[0] == 'g') MenuGiveSkin(id, target);
			else MenuRemoveSkin(id, target);
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public ViewOwnedHandler(id, menu, item) {
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public GiveSkinHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[12], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		GiveSkinTo(g_pendingTarget, str_to_num(szInfo));
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public RemoveSkinHandler(id, menu, item) {
	if (item != MENU_EXIT) {
		new szInfo[SKIN_KEY_MAX], access, callback;
		menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
		RemoveSkinFrom(g_pendingTarget, szInfo);
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
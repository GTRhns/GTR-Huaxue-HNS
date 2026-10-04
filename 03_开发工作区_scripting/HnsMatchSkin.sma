/* ============================================================
   HNS Match Skin  -  玩家自定义皮肤系统
   与你的 HNS 比赛库(HnsMatchSql) 共用同一个 MySQL 库, 分表前缀 cpm_
   货币: 复用 ICGB 金币 (hns_gc_get_player / hns_gc_set_player)
   显示引擎: 依赖 CustomPlayerModelsApi.sma (模型 precache / 客户端显示)
   ------------------------------------------------------------
   模型 / 音效策略:
     - TT 款 (恐怖分子) 和 CT 款 (反恐精英) 是两条独立记录, 一行=一款
     - 每一款 = 一套模型 + 一个或多个死亡音效, 死亡时从该款音效里随机一条; 音效可复用
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
   玩家菜单: /skin
     1.人物皮肤商店 [总数红] -> CT皮肤 / TT皮肤
     2.刀模商店 [数量红]
     3.投掷物商店 [数量红]
     (空行)
     4.GBIC点数 [余额红]
     5.购买点数
     (空行)
     6.MySQL管理 (黄, 需管理员 A/B)
     7.管理员设置 (红, 需 A)
   投掷物菜单: 先进分类页(烟雾弹/闪光弹), 再进对应列表
   管理菜单: /cpm 或主菜单第7项 (A权限)
   本地/盗版: 与金币一样用 get_user_authid() 写 MySQL
     盗版模拟器通常也会给 STEAM_0:x:x, 买皮肤能跨图保留
     真 LAN / PENDING 才退回 LAN:IP (不绑名字, 改名不丢皮肤)
   换图: plugin_precache 只读 skins.cfg 并预缓存模型;
         建表/导入 MySQL 放到 plugin_init 后台, 避免卡住 changelevel
   死亡音效: 拦截原版 player/die* / death* , 换成当前皮肤音效, 不再叠原声
   依赖:
     - CustomPlayerModelsApi.amxx  (须在 plugins.ini 中排在本插件之前)
     - HnsLanguage.amxx  (须排在本插件之前, /lang 统一简体/繁体/英语/俄语)
     - HnsMatchSql.amxx 的 SQL 连接与 ICGB 金币接口
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <nvault>
#include <fakemeta>
#include <reapi>
#include <newmenus>
#include <string>
#include <hns_optional_sql>
#include <hns_gc>
#include <custom_player_models>
#include <hns_language>
#include <crxknives>

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

// ---- 死亡音效 ----
#define DEATH_SND_PATH 80
#define DEATH_SND_MAX  320

// ---- 皮肤数据源配置文件 (一行=一款, 启动自动导入 MySQL) ----
#define SKINS_CFG_FILE "mixsystem/skins.cfg"

#define SKIN_KEY_MAX   32
#define SKIN_MODEL_MAX 64

// newmenus 默认每页 7 项, 用于从 item 反推所在页 (item / SKIN_PER_PAGE)
#define SKIN_PER_PAGE  7

// ---- 投掷物皮肤 (烟雾/闪光) ----
#define NADE_CFG_FILE  "mixsystem/nade_skins.cfg"
#define NADE_KEY_MAX   32
#define NADE_KIND_SMOKE 0   // 烟雾弹
#define NADE_KIND_FLASH 1   // 闪光弹

// ---- 刀皮商店 ----
// 刀模型本体仍由 crxknives 引擎的 KnifeModels.ini 提供,
// 但商店显示的价格/免费规则改由这个 cfg 控制, 方便单独管理 (不影响引擎的刀定义)。
#define KNIFE_CFG_FILE "mixsystem/knife_skins.cfg"

#define ADMIN_FLAG ADMIN_BAN
#define TASK_REAPPLY_KNIFE 26000
#define TASK_AUTH_RETRY 27000
#define TASK_PLAYTIME 28000
#define TASK_APPLY_NADE 29000
#define TASK_MENU_SHOP 30000
#define PLAYTIME_TICK 60.0

#define SHOP_MENU_SKIN 1
#define SHOP_MENU_NADE_CAT 2
#define SHOP_MENU_NADE_KIND 3
#define SHOP_MENU_KNIFE 4

// 阵营字符
#define TEAM_CHAR_T 'T'
#define TEAM_CHAR_C 'C'

// ---- 可配置项 (在 skins.cfg 的 [SETTINGS] 区块里改, 这里只是默认值) ----
new g_iRentDays = 30;       // 金币购买获得的租期天数, 0 = 直接永久
new g_iUpgradePrice = 2000; // 限时皮肤升级为永久的价格 (ICGB金币)
new g_iKnifeFree = 1;       // 刀皮前 N 把免费, 其余按 KnifeModels.ini 的 PRICE 花 GBIC 购买
new g_iNadeFree = 1;        // 烟雾/闪光弹皮肤前 N 个免费, 其余按 GBIC 购买
new g_iCheckinBonus = 10;   // 每日签到奖励 GBIC
new g_iPlaytimeBonus = 5;   // 在线满 1 小时奖励 GBIC
new g_iPlaytimeNeed = 3600; // 在线奖励所需秒数
new g_szBuyGoldText[160] = "请联系管理员购买 GBIC 点数";
new g_szBuyGoldUrl[128];

// CS1.6 引擎模型预缓存池 (MAX_MODELS) 只有 512 个, 且和地图自身的 *刷子模型共享。
// 重型 HNS 地图本身可能吃掉 290+ 个名额; 本插件若不限量预缓存全部皮肤模型,
// 极易触发 ED_ParseEdict: Model '*N' failed to precache because the item count is over the 512 limit 崩服。
// 这里的上限限制"本插件每张地图最多预缓存多少个皮肤模型"(刀皮/投掷物皮单独计, 数量很少)。
//   0  = 不限制 (旧行为, 危险)
//   >0 = 超出上限的皮肤仍然进商店目录, 但不预缓存、因此本图不可用(不会崩服)
//   默认 24: 重型 HNS 地图大约占用 290 个 *刷子模型名额, 留出余量给引擎/其它插件。
//   某张图崩服 -> 调小; 有富余 -> 调大, 一次 4~8 地试。
new g_iPrecacheMax = 0;
new g_iPrecacheUsed = 0;    // 本图已经成功预缓存了多少个皮肤模型

// 刀皮商店价格覆盖表: 刀名(NAME) -> 价格. 来自 knife_skins.cfg,
// 有记录时优先于 KnifeModels.ini 的 PRICE; 没有则回退到引擎 PRICE。
new Trie:g_tKnifePrice = Invalid_Trie;

static const g_szClcmds[][] = {
	"say /skin",
	"say_team /skin",
	"say /cpm",
	"say_team /cpm",
	"say /giveskin",
	"say_team /giveskin",
	"say /giveskinmenu",
	"say_team /giveskinmenu"
};

// 皮肤池记录 (一行 = 一个阵营款式)
enum _:pool_e {
	pool_key[SKIN_KEY_MAX],      // 唯一名字(识别/菜单/拥有都靠它, 如 hunan_t / hunan_c)
	pool_model[SKIN_MODEL_MAX],  // 模型路径 (相对 models/)
	pool_flags[16],              // 权限要求, 空=所有人
	pool_snd[DEATH_SND_MAX],     // 死亡音效列表, 逗号分隔 (相对 sound/, 空=不播; 死亡随机一条)
	pool_price,                  // 价格(ICGB金币) 0=免费
	pool_body,                   // 子模型
	pool_skin,                   // 皮肤序号
	pool_team,                   // 'T' 或 'C' (该款式属于哪个阵营)
	pool_precache                // 1 = 本图已成功预缓存模型; 0 = 因上限被跳过(本图不可用)
};

enum _:db_e { db_host[48], db_user[32], db_pass[32], db_db[32] };

enum _:qtype_e {
	QT_LOAD_OWNED = 1,
	QT_LOAD_CURRENT,
	QT_SAVE_CURRENT,
	QT_BUY_SKIN,
	QT_REMOVE_SKIN,
	QT_UPGRADE_SKIN,
	QT_SQL_PING,
	QT_SQL_COUNT
};

new g_eDb[db_e];
new Handle:g_hSqlTuple;

new Array:g_pPool;          // Array of pool_e
new Trie:g_pPoolIndex;      // key -> 池下标
new g_iPoolSize;

// 每个阵营各自的"当前选用款" key
new g_CurT[MAX_PLAYERS + 1][SKIN_KEY_MAX];   // 恐怖分子款
new g_CurC[MAX_PLAYERS + 1][SKIN_KEY_MAX];   // 反恐精英款
new g_iCurKnife[MAX_PLAYERS + 1];             // 当前刀皮编号, 0 = 默认 kf
new g_iKnifeRetry[MAX_PLAYERS + 1];           // 换图后覆盖 crxknives nVault 的重试次数
new g_iAuthRetry[MAX_PLAYERS + 1];            // 等 SteamID 就绪再读皮肤, 避免 LAN:IP 把拥有列表冲空
new bool:g_bApplyingKnife[MAX_PLAYERS + 1];   // 正在强制套刀, 避免 knife_updated 递归重置
new Array:g_Owned[MAX_PLAYERS + 1];
new Trie:g_OwnedExpire[MAX_PLAYERS + 1];   // key -> 到期时间戳(UNIX秒), 0 = 永久
new g_szAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];
new Trie:g_tAuthByIp = Invalid_Trie;        // 换图瞬间 PENDING 时用 IP 找回上次 SteamID
new g_iLoadGen[MAX_PLAYERS + 1];
new bool:g_bOwnedLoaded[MAX_PLAYERS + 1];   // 该玩家的拥有列表是否已从MySQL加载完毕
new g_iLastTeam[MAX_PLAYERS + 1];
// 上一次真正应用到模型上的阵营+款, 用于每帧对比当前槽, 换图/复活/异步加载晚了都能补上
new g_szAppliedTeam[MAX_PLAYERS + 1];
new g_szAppliedKey[MAX_PLAYERS + 1][SKIN_KEY_MAX];

new bool:g_bPlayingDeathSnd; // emit_sound 替换死亡音效时防递归

new g_pendingGiveTeam[MAX_PLAYERS + 1]; // 0=全部  TEAM_CHAR_T / TEAM_CHAR_C
new bool:g_bSqlReady;
new g_szSqlStatus[96];
new g_iSqlLastErr;
new g_szSqlLastErr[128];
new g_iSqlOwnedCount;
new g_iSqlCurrentCount;
new g_iBrowseTeam[MAX_PLAYERS + 1]; // 玩家浏览的阵营 'T'/'C'
// 多级菜单传参暂存
new g_pendingTarget[MAX_PLAYERS + 1];
new g_pendingAdmin[MAX_PLAYERS + 1];
new g_pendingMode[MAX_PLAYERS + 1][8]; // "view" / "give" / "remove"
new g_legacyPendingAdmin[MAX_PLAYERS + 1]; // 兼容旧 callfunc 接口：按目标玩家隔离管理员状态

// 各菜单当前页 (选中/翻页后重建时停在同一页, 不再跳回第一页)
new g_iKnifePage[MAX_PLAYERS + 1];
new g_iBrowsePage[MAX_PLAYERS + 1];

// 每日签到 / 在线时长奖励 (nVault 跨图保存)
new g_iVaultReward = INVALID_HANDLE;
new g_iLastCheckin[MAX_PLAYERS + 1];
new g_iPlayRemain[MAX_PLAYERS + 1];
new Float:g_flPlayStart[MAX_PLAYERS + 1];
new bool:g_bRewardLoaded[MAX_PLAYERS + 1];
new g_iNadePage[MAX_PLAYERS + 1];
// 投掷物皮肤: 当前停留的分类 (-1 = 分类选择页; 0 = 烟雾; 1 = 闪光)
new g_iNadeKindPage[MAX_PLAYERS + 1];
new g_iShopMenu[MAX_PLAYERS + 1];
new g_iShopPage[MAX_PLAYERS + 1];
new g_iShopKind[MAX_PLAYERS + 1];
new Float:g_flShopKeep[MAX_PLAYERS + 1];

// ---- 投掷物皮肤池 ----
enum _:nade_e {
	nade_key[NADE_KEY_MAX],      // 唯一名字
	nade_name[NADE_KEY_MAX],     // 显示名
	nade_model[SKIN_MODEL_MAX],  // 模型路径 (相对 models/, 不含 .mdl 也可)
	nade_kind,                   // NADE_KIND_SMOKE / NADE_KIND_FLASH
	nade_price                   // 价格(GBIC), 0 = 免费
};

new Array:g_pNade;              // Array of nade_e
new g_iNadeSize;

// 每个玩家当前选用的投掷物皮肤 key (空 = 默认模型)
new g_NadeSmoke[MAX_PLAYERS + 1][NADE_KEY_MAX];
new g_NadeFlash[MAX_PLAYERS + 1][NADE_KEY_MAX];

/* ============================================================
   纯工具函数
   ============================================================ */
bool:IsSkinAdmin(id) {
	// 管理员设置：仅 A (ADMIN_IMMUNITY)。
	return (get_user_flags(id) & ADMIN_IMMUNITY) != 0;
}

bool:IsSkinSqlAdmin(id) {
	// SQL 调试：A 或 B 任一即可。
	return (get_user_flags(id) & (ADMIN_IMMUNITY | ADMIN_RESERVATION)) != 0;
}

bool:IsSkinOwner(id) {
	return (get_user_flags(id) & ADMIN_IMMUNITY) != 0;
}

bool:CanSkinTarget(admin, target) {
	return IsSkinOwner(admin) || admin == target;
}

bool:IsPendingAuth(const szAuth[]) {
	if (!szAuth[0])
		return true;
	return equal(szAuth, "STEAM_ID_PENDING")
		|| equal(szAuth, "VALVE_ID_PENDING")
		|| equal(szAuth, "STEAM_ID_LAN")
		|| equal(szAuth, "VALVE_ID_LAN")
		|| equal(szAuth, "BOT")
		|| equali(szAuth, "LAN:", 4);
}

bool:IsSteamAuth(const szAuth[]) {
	return !IsPendingAuth(szAuth);
}

RememberAuthByIp(id, const szAuth[]) {
	if (!g_tAuthByIp || !IsSteamAuth(szAuth))
		return;
	new szIp[32];
	get_user_ip(id, szIp, charsmax(szIp), 1);
	if (szIp[0])
		TrieSetString(g_tAuthByIp, szIp, szAuth);
}

LookupAuthByIp(id, dest[], len) {
	dest[0] = EOS;
	if (!g_tAuthByIp)
		return;
	new szIp[32];
	get_user_ip(id, szIp, charsmax(szIp), 1);
	if (szIp[0])
		TrieGetString(g_tAuthByIp, szIp, dest, len);
}

GetPlayerAuth(id, dest[], len) {
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));

	// 正版 Steam / 盗版模拟器的 STEAM_0:x:x / VALVE_x:x:x, 与金币 SQL 同一把钥
	if (!IsPendingAuth(szAuth)) {
		copy(dest, len, szAuth);
		copy(g_szAuth[id], charsmax(g_szAuth[]), szAuth);
		RememberAuthByIp(id, szAuth);
		return;
	}

	// 换图时常先拿到 PENDING, 不要用 LAN:IP 覆盖已经拿到的 SteamID
	if (IsSteamAuth(g_szAuth[id])) {
		copy(dest, len, g_szAuth[id]);
		return;
	}

	new szCached[MAX_AUTHID_LENGTH];
	LookupAuthByIp(id, szCached, charsmax(szCached));
	if (IsSteamAuth(szCached)) {
		copy(dest, len, szCached);
		copy(g_szAuth[id], charsmax(g_szAuth[]), szCached);
		return;
	}

	// 真 LAN / 还没拿到 ID: 只绑 IP, 不绑名字, 改名不丢已买皮肤
	new szIp[32];
	get_user_ip(id, szIp, charsmax(szIp), 1);
	if (!szIp[0])
		copy(szIp, charsmax(szIp), "0.0.0.0");

	formatex(dest, len, "LAN:%s", szIp);
	if (!g_szAuth[id][0])
		copy(g_szAuth[id], charsmax(g_szAuth[]), dest);
}

TodayYmd() {
	new szDay[12];
	get_time("%Y%m%d", szDay, charsmax(szDay));
	return str_to_num(szDay);
}

LoadRewardState(id) {
	if (g_bRewardLoaded[id])
		return;

	g_iLastCheckin[id] = 0;
	g_iPlayRemain[id] = g_iPlaytimeNeed;
	g_flPlayStart[id] = get_gametime();
	if (g_iVaultReward == INVALID_HANDLE)
		return;

	new szAuth[MAX_AUTHID_LENGTH], szKey[64], szVal[32];
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	if (!szAuth[0])
		return;

	formatex(szKey, charsmax(szKey), "chk_%s", szAuth);
	if (nvault_get(g_iVaultReward, szKey, szVal, charsmax(szVal)))
		g_iLastCheckin[id] = str_to_num(szVal);

	formatex(szKey, charsmax(szKey), "play_%s", szAuth);
	if (nvault_get(g_iVaultReward, szKey, szVal, charsmax(szVal))) {
		new iRemain = str_to_num(szVal);
		if (iRemain > 0)
			g_iPlayRemain[id] = iRemain;
	}
	g_bRewardLoaded[id] = true;
}

SaveRewardState(id) {
	if (g_iVaultReward == INVALID_HANDLE)
		return;

	new szAuth[MAX_AUTHID_LENGTH], szKey[64], szVal[32];
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	if (!szAuth[0])
		return;

	formatex(szKey, charsmax(szKey), "chk_%s", szAuth);
	num_to_str(g_iLastCheckin[id], szVal, charsmax(szVal));
	nvault_set(g_iVaultReward, szKey, szVal);

	formatex(szKey, charsmax(szKey), "play_%s", szAuth);
	num_to_str(GetPlayRemain(id), szVal, charsmax(szVal));
	nvault_set(g_iVaultReward, szKey, szVal);
}

HasCheckedInToday(id) {
	LoadRewardState(id);
	return g_iLastCheckin[id] == TodayYmd();
}

GetPlayRemain(id) {
	LoadRewardState(id);
	new iRemain = g_iPlayRemain[id] - floatround(get_gametime() - g_flPlayStart[id], floatround_floor);
	if (iRemain < 0)
		iRemain = 0;
	return iRemain;
}

FlushPlaytime(id) {
	LoadRewardState(id);
	new Float:flNow = get_gametime();
	new iElapsed = floatround(flNow - g_flPlayStart[id], floatround_floor);
	if (iElapsed < 0)
		iElapsed = 0;
	g_iPlayRemain[id] -= iElapsed;
	g_flPlayStart[id] = flNow;
}

GivePlaytimeRewards(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;

	FlushPlaytime(id);
	if (!g_bRewardLoaded[id])
		return;

	new iNeed = g_iPlaytimeNeed;
	if (iNeed < 60)
		iNeed = 3600;

	new bool:bGave = false;
	while (g_iPlayRemain[id] <= 0) {
		new iBal = hns_gc_add_player(id, g_iPlaytimeBonus);
		g_iPlayRemain[id] += iNeed;
		bGave = true;
		SkinChat(id, print_team_default, "SKIN_CHAT_PLAYTIME_OK", "在线满1小时, 获得 ^3%d^1 GBIC, 余额 ^3%d", g_iPlaytimeBonus, iBal);
	}
	if (bGave)
		SaveRewardState(id);
}

StartPlaytimeTrack(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	LoadRewardState(id);
	g_flPlayStart[id] = get_gametime();
	remove_task(id + TASK_PLAYTIME);
	set_task(PLAYTIME_TICK, "TaskPlaytimeTick", id + TASK_PLAYTIME, _, _, "b");
}

StopPlaytimeTrack(id, bool:bSave) {
	remove_task(id + TASK_PLAYTIME);
	if (!bSave || !g_bRewardLoaded[id])
		return;
	GivePlaytimeRewards(id);
	SaveRewardState(id);
}

public TaskPlaytimeTick(taskid) {
	new id = taskid - TASK_PLAYTIME;
	if (!is_user_connected(id)) {
		remove_task(taskid);
		return;
	}
	GivePlaytimeRewards(id);
	SaveRewardState(id);
}

DoDailyCheckin(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	LoadRewardState(id);
	if (HasCheckedInToday(id)) {
		SkinChat(id, print_team_red, "SKIN_CHAT_CHECKIN_DONE", "今天已经签到过了");
		return;
	}
	g_iLastCheckin[id] = TodayYmd();
	new iBal = hns_gc_add_player(id, g_iCheckinBonus);
	SaveRewardState(id);
	SkinChat(id, print_team_default, "SKIN_CHAT_CHECKIN_OK", "签到成功, 获得 ^3%d^1 GBIC, 余额 ^3%d", g_iCheckinBonus, iBal);
}

public CmdCheckin(id) {
	DoDailyCheckin(id);
	return PLUGIN_HANDLED;
}

/* ---- HnsLanguage: /lang 简体/繁体/英语/俄语 ---- */
stock SkinLangUnescape(szText[], iLen) {
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^2", "^2");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock SkinLang(id, const szKey[], szOut[], iLen, const szFallback[]) {
	szOut[0] = EOS;
	HnsLang_Get(id, szKey, szOut, iLen);
	if (!szOut[0] || equal(szOut, szKey))
		copy(szOut, iLen, szFallback);
	SkinLangUnescape(szOut, iLen);
}

stock SkinLangF(id, const szKey[], const szFallback[], szOut[], iLen, any:...) {
	new szFmt[256];
	SkinLang(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szOut, iLen, szFmt, 6);
}

stock SkinChat(id, team, const szKey[], const szFallback[], any:...) {
	if (!is_user_connected(id))
		return;
	new szPrefix[32], szFmt[191], szBody[191], szMsg[191];
	SkinLang(id, "SKIN_CHAT_PREFIX", szPrefix, charsmax(szPrefix), "^4[皮肤]^1");
	SkinLang(id, szKey, szFmt, charsmax(szFmt), szFallback);
	vformat(szBody, charsmax(szBody), szFmt, 5);
	formatex(szMsg, charsmax(szMsg), "%s %s", szPrefix, szBody);
	client_print_color(id, team, "%s", szMsg);
}

stock SkinTeamName(id, teamChar, dest[], len) {
	if (teamChar == TEAM_CHAR_T)
		SkinLang(id, "SKIN_TEAM_TT", dest, len, "TT");
	else if (teamChar == TEAM_CHAR_C)
		SkinLang(id, "SKIN_TEAM_CT", dest, len, "CT");
	else
		SkinLang(id, "SKIN_TEAM_ALL", dest, len, "全部");
}

stock SkinTeamShort(id, teamChar, dest[], len) {
	if (teamChar == TEAM_CHAR_T)
		SkinLang(id, "SKIN_TEAM_T", dest, len, "T");
	else if (teamChar == TEAM_CHAR_C)
		SkinLang(id, "SKIN_TEAM_CT", dest, len, "CT");
	else
		SkinLang(id, "SKIN_TEAM_ALL", dest, len, "全部");
}

stock SkinTeamLong(id, teamChar, dest[], len) {
	if (teamChar == TEAM_CHAR_T)
		SkinLang(id, "SKIN_TEAM_T_LONG", dest, len, " T(恐怖分子)");
	else
		SkinLang(id, "SKIN_TEAM_CT_LONG", dest, len, " CT(反恐精英)");
}

stock SkinSqlStatusText(id, dest[], len) {
	if (equal(g_szSqlStatus, "none"))
		SkinLang(id, "SKIN_SQL_NONE", dest, len, "未配置数据库");
	else if (equal(g_szSqlStatus, "fail"))
		SkinLang(id, "SKIN_SQL_FAIL", dest, len, "连接失败");
	else if (equal(g_szSqlStatus, "ok"))
		SkinLang(id, "SKIN_SQL_OK", dest, len, "已连接");
	else if (equal(g_szSqlStatus, "reconnect"))
		SkinLang(id, "SKIN_SQL_RECONNECT", dest, len, "正在重连");
	else if (equal(g_szSqlStatus, "query"))
		SkinLang(id, "SKIN_SQL_QUERY_FAIL", dest, len, "查询失败");
	else
		SkinLang(id, "SKIN_SQL_UNKNOWN", dest, len, "未知");
}

SkinMenuStyle(id, menu) {
	new szBack[32], szNext[32], szExit[32];
	SkinLang(id, "SKIN_MENU_BACK", szBack, charsmax(szBack), "上一页");
	SkinLang(id, "SKIN_MENU_NEXT", szNext, charsmax(szNext), "下一页");
	SkinLang(id, "SKIN_MENU_CLOSE", szExit, charsmax(szExit), "关闭");
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_BACKNAME, szBack);
	menu_setprop(menu, MPROP_NEXTNAME, szNext);
	menu_setprop(menu, MPROP_EXITNAME, szExit);
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\r");
	menu_setprop(menu, MPROP_NOCOLORS, 0);
}

FormatShopItem(id, dest[], len, const name[], bool:owned, price, bool:selected = false) {
	if (selected) {
		new szSel[32];
		SkinLang(id, "SKIN_TAG_SELECTED", szSel, charsmax(szSel), "  \r[已选择]");
		formatex(dest, len, "\w%s%s", name, szSel);
	} else if (owned)
		formatex(dest, len, "\w%s", name);
	else
		formatex(dest, len, "\d%s  [%d]", name, price);
}

SkinMenuReturn(id, menu) {
	new szBack[32];
	SkinLang(id, "SKIN_MENU_RETURN", szBack, charsmax(szBack), "返回");
	menu_setprop(menu, MPROP_EXITNAME, szBack);
}

MarkShopKeep(id) {
	g_flShopKeep[id] = get_gametime() + 0.40;
}

bool:KeepShopMenu(id) {
	return get_gametime() < g_flShopKeep[id];
}

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

// 该池内款式本张地图是否已成功预缓存模型 (未预缓存的不能应用, 否则会拉不到模型)
bool:IsPoolPrecached(idx) {
	if (idx < 0 || idx >= g_iPoolSize)
		return false;
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	return bool:row[pool_precache];
}

// key 是否本图可用 (存在 且 已预缓存)
bool:IsSkinPrecached(const key[]) {
	new idx = PoolIndexOf(key);
	return idx != -1 && IsPoolPrecached(idx);
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

KnifeOwnedKey(knife, dest[], len) {
	formatex(dest, len, "knife:%d", knife);
}

bool:IsKnifeOwned(id, knife) {
	// 前 N 把免费: 直接可用, 不需要购买也不需要数据库记录
	if (knife >= 0 && knife < g_iKnifeFree)
		return true;

	new name[MAX_NAME_LENGTH], price;
	KnifeInfo(knife, name, charsmax(name), price);
	if (price <= 0)
		return true;
	new key[SKIN_KEY_MAX];
	KnifeOwnedKey(knife, key, charsmax(key));
	return IsSkinValid(id, key);
}

bool:IsKnifeShopItemValid(knife) {
	return knife >= 0 && knife < crxknives_get_knives_num();
}

/* ============================================================
   投掷物皮肤 (烟雾弹 / 闪光弹)
   ============================================================ */
NadeKindChar(kind) {
	return (kind == NADE_KIND_FLASH) ? 'F' : 'S';
}

NadeOwnedKey(const key[], dest[], len) {
	formatex(dest, len, "nade:%s", key);
}

// 玩家当前某类投掷物皮肤的槽 (烟雾='S' / 闪光='F')
NadeCurSlot(id, kind, dest[], len) {
	if (kind == NADE_KIND_FLASH)
		copy(dest, len, g_NadeFlash[id]);
	else
		copy(dest, len, g_NadeSmoke[id]);
}

SetNadeCurSlot(id, kind, const key[]) {
	if (kind == NADE_KIND_FLASH)
		copy(g_NadeFlash[id], charsmax(g_NadeFlash[]), key);
	else
		copy(g_NadeSmoke[id], charsmax(g_NadeSmoke[]), key);
}

// 前 N 个免费 (按配置出现顺序), 其余需要购买
bool:IsNadeFree(idx) {
	return idx >= 0 && idx < g_iNadeFree;
}

bool:IsNadeOwned(id, idx) {
	if (idx < 0 || idx >= g_iNadeSize)
		return false;
	if (IsNadeFree(idx))
		return true;

	new row[nade_e];
	ArrayGetArray(g_pNade, idx, row, sizeof row);
	if (row[nade_price] <= 0)
		return true;
	new key[SKIN_KEY_MAX];
	NadeOwnedKey(row[nade_key], key, charsmax(key));
	return IsSkinValid(id, key);
}

NadeFullPath(const model[], dest[], len) {
	if (equali(model, "models/", 7)) {
		copy(dest, len, model);
		return;
	}
	new iLen = strlen(model);
	if (iLen > 4 && equali(model[iLen - 4], ".mdl"))
		formatex(dest, len, "models/%s", model);
	else
		formatex(dest, len, "models/%s.mdl", model);
}

NadeFileName(const path[], dest[], len) {
	new i = strlen(path);
	while (i > 0 && path[i - 1] != '/' && path[i - 1] != 92)
		i--;
	copy(dest, len, path[i]);
}

bool:NadeResolvePath(const model[], dest[], len) {
	new szTry[PLATFORM_MAX_PATH], szFile[64];
	NadeFullPath(model, szTry, charsmax(szTry));
	if (file_exists(szTry)) {
		copy(dest, len, szTry);
		return true;
	}
	NadeFileName(szTry, szFile, charsmax(szFile));
	if (szFile[0]) {
		formatex(szTry, charsmax(szTry), "models/%s", szFile);
		if (file_exists(szTry)) {
			copy(dest, len, szTry);
			return true;
		}
	}
	NadeFullPath(model, dest, len);
	return false;
}

bool:NadeWorldPath(const view[], dest[], len) {
	copy(dest, len, view);
	if (contain(dest, "/v_") != -1)
		replace(dest, len, "/v_", "/w_");
	else if (contain(dest, "v_") != -1)
		replace(dest, len, "v_", "w_");
	else
		return false;
	return dest[0] && !equal(dest, view) && file_exists(dest);
}

bool:NadePlayerPath(const view[], dest[], len) {
	copy(dest, len, view);
	if (contain(dest, "/v_") != -1)
		replace(dest, len, "/v_", "/p_");
	else if (contain(dest, "v_") != -1)
		replace(dest, len, "v_", "p_");
	else
		return false;
	return dest[0] && !equal(dest, view) && file_exists(dest);
}

NadeKindOfWeapon(weapon) {
	if (is_nullent(weapon))
		return -1;
	new WeaponIdType:wid = WeaponIdType:get_member(weapon, m_iId);
	if (wid == WEAPON_SMOKEGRENADE)
		return NADE_KIND_SMOKE;
	if (wid == WEAPON_FLASHBANG)
		return NADE_KIND_FLASH;
	return -1;
}

ApplyNadeViewTo(id, weapon, const szView[]) {
	if (!is_user_connected(id) || !szView[0])
		return;
	set_entvar(id, var_viewmodel, szView);
	if (!is_nullent(weapon)) {
		set_entvar(weapon, var_viewmodel, szView);
		new szP[PLATFORM_MAX_PATH];
		if (NadePlayerPath(szView, szP, charsmax(szP)))
			set_entvar(weapon, var_weaponmodel, szP);
	}
}

bool:SkinMenuBusy(id) {
	if (!is_user_connected(id))
		return false;
	if (task_exists(id + TASK_MENU_SHOP))
		return true;
	new iOld, iNew;
	player_menu_info(id, iOld, iNew);
	return iNew != -1 || iOld > 0;
}

ApplyHeldNadeSkin(id) {
	if (!is_user_alive(id))
		return;
	if (SkinMenuBusy(id)) {
		remove_task(id + TASK_APPLY_NADE);
		set_task(0.20, "TaskApplyHeldNade", id + TASK_APPLY_NADE);
		return;
	}
	new weapon = get_member(id, m_pActiveItem);
	new kind = NadeKindOfWeapon(weapon);
	if (kind < 0)
		return;
	new szPath[PLATFORM_MAX_PATH];
	if (!GetNadeCurrentModel(id, kind, szPath, charsmax(szPath)))
		return;
	ApplyNadeViewTo(id, weapon, szPath);
}

public TaskApplyHeldNade(taskid) {
	ApplyHeldNadeSkin(taskid - TASK_APPLY_NADE);
}

ScheduleHeldNadeApply(id) {
	if (!is_user_connected(id))
		return;
	remove_task(id + TASK_APPLY_NADE);
	set_task(0.05, "TaskApplyHeldNade", id + TASK_APPLY_NADE);
}

public OnNadeDeployPre(const weapon) {
	new kind = NadeKindOfWeapon(weapon);
	if (kind < 0)
		return HC_CONTINUE;
	new id = get_member(weapon, m_pPlayer);
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return HC_CONTINUE;
	new szPath[PLATFORM_MAX_PATH];
	if (!GetNadeCurrentModel(id, kind, szPath, charsmax(szPath)))
		return HC_CONTINUE;
	SetHookChainArg(2, ATYPE_STRING, szPath);
	new szP[PLATFORM_MAX_PATH];
	if (NadePlayerPath(szPath, szP, charsmax(szP)))
		SetHookChainArg(3, ATYPE_STRING, szP);
	return HC_CONTINUE;
}

public OnNadeDeployPost(const weapon) {
	new kind = NadeKindOfWeapon(weapon);
	if (kind < 0)
		return HC_CONTINUE;
	new id = get_member(weapon, m_pPlayer);
	if (id < 1 || id > MaxClients)
		return HC_CONTINUE;
	ScheduleHeldNadeApply(id);
	return HC_CONTINUE;
}

OpenShopLater(id, which, page = 0, kind = -1) {
	if (!is_user_connected(id))
		return;
	g_iShopMenu[id] = which;
	g_iShopPage[id] = page;
	g_iShopKind[id] = kind;
	MarkShopKeep(id);
	remove_task(id + TASK_MENU_SHOP);
	set_task(0.05, "TaskOpenShop", id + TASK_MENU_SHOP);
}

public TaskOpenShop(taskid) {
	new id = taskid - TASK_MENU_SHOP;
	if (!is_user_connected(id))
		return;
	switch (g_iShopMenu[id]) {
		case SHOP_MENU_SKIN: MenuSkin(id, g_iShopPage[id]);
		case SHOP_MENU_NADE_CAT: MenuNades(id);
		case SHOP_MENU_NADE_KIND: MenuNadeKind(id, g_iShopKind[id], g_iShopPage[id]);
		case SHOP_MENU_KNIFE: MenuKnives(id, g_iShopPage[id]);
	}
}

// 读取 nade_skins.cfg 并预缓存模型: 名字 模型 价格 类型
LoadNadeCfg() {
	if (!g_pNade)
		g_pNade = ArrayCreate(nade_e);
	ArrayClear(g_pNade);
	g_iNadeSize = 0;

	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, NADE_CFG_FILE);
	if (!file_exists(szCfg))
		return;

	new file = fopen(szCfg, "rt");
	if (!file)
		return;

	new szLine[256], szKey[NADE_KEY_MAX], szModel[SKIN_MODEL_MAX], szPrice[16], szKind[16];
	while (!feof(file)) {
		fgets(file, szLine, charsmax(szLine));
		trim(szLine);
		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue;

		szKey[0] = EOS;
		parse(szLine, szKey, charsmax(szKey), szModel, charsmax(szModel), szPrice, charsmax(szPrice), szKind, charsmax(szKind));
		trim(szKey); trim(szModel); trim(szPrice); trim(szKind);
		if (!szKey[0] || !szModel[0])
			continue;

		new row[nade_e];
		copy(row[nade_key], charsmax(row[nade_key]), szKey);
		copy(row[nade_name], charsmax(row[nade_name]), szKey);
		copy(row[nade_model], charsmax(row[nade_model]), szModel);
		row[nade_price] = str_to_num(szPrice);
		if (row[nade_price] < 0)
			row[nade_price] = 0;
		row[nade_kind] = equali(szKind, "flash") ? NADE_KIND_FLASH : NADE_KIND_SMOKE;

		new szPath[PLATFORM_MAX_PATH], szExtra[PLATFORM_MAX_PATH];
		NadeResolvePath(row[nade_model], szPath, charsmax(szPath));
		precache_model(szPath);
		if (NadeWorldPath(szPath, szExtra, charsmax(szExtra)))
			precache_model(szExtra);
		if (NadePlayerPath(szPath, szExtra, charsmax(szExtra)))
			precache_model(szExtra);

		ArrayPushArray(g_pNade, row, sizeof row);
		g_iNadeSize++;
	}
	fclose(file);
}

// 读取 knife_skins.cfg: 每行 "刀名 价格" (刀名要和 KnifeModels.ini 里的段名一致)
// 只覆盖"商店价格", 不影响 crxknives 引擎自己的刀定义/音效。
// 价格 0 = 免费; 前 g_iKnifeFree 把仍然无条件免费 (见 IsKnifeOwned)。
bool:IsBlankChar(ch) {
	return ch == ' ' || ch == 9;
}

LoadKnifeCfg() {
	if (g_tKnifePrice == Invalid_Trie)
		g_tKnifePrice = TrieCreate();
	else
		TrieClear(g_tKnifePrice);

	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, KNIFE_CFG_FILE);
	if (!file_exists(szCfg))
		return;

	new file = fopen(szCfg, "rt");
	if (!file)
		return;

	new szLine[256], szName[MAX_NAME_LENGTH], szPrice[16];
	while (!feof(file)) {
		fgets(file, szLine, charsmax(szLine));
		trim(szLine);
		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '[')
			continue;

		// 价格取最后一个空白分隔的字段, 前面整段当刀名 (允许刀名里带空格)
		new iLen = strlen(szLine);
		new iPos = iLen;
		while (iPos > 0 && IsBlankChar(szLine[iPos - 1]))
			iPos--;
		while (iPos > 0 && !IsBlankChar(szLine[iPos - 1]))
			iPos--;

		copy(szPrice, charsmax(szPrice), szLine[iPos]);
		copy(szName, charsmax(szName), szLine);
		szName[iPos] = EOS;
		trim(szName); trim(szPrice);
		StripQuotes(szName);
		StripQuotes(szPrice);
		if (!szName[0] || !szPrice[0])
			continue;

		new iPrice = str_to_num(szPrice);
		if (iPrice < 0)
			iPrice = 0;
		TrieSetCell(g_tKnifePrice, szName, iPrice);
	}
	fclose(file);
}

NadePoolIndex(const key[], kind = -1) {
	for (new i = 0; i < g_iNadeSize; i++) {
		new row[nade_e];
		ArrayGetArray(g_pNade, i, row, sizeof row);
		if (equal(row[nade_key], key) && (kind < 0 || row[nade_kind] == kind))
			return i;
	}
	return -1;
}

// 找到当前玩家某类投掷物应当使用的模型路径; 返回 false 表示用默认
bool:GetNadeCurrentModel(id, kind, dest[], len) {
	dest[0] = EOS;
	new key[NADE_KEY_MAX];
	NadeCurSlot(id, kind, key, charsmax(key));
	if (!key[0])
		return false;
	new idx = NadePoolIndex(key, kind);
	if (idx == -1)
		return false;
	new row[nade_e];
	ArrayGetArray(g_pNade, idx, row, sizeof row);
	NadeResolvePath(row[nade_model], dest, len);
	return dest[0] != EOS;
}

DoBuyNade(id, idx) {
	if (idx < 0 || idx >= g_iNadeSize)
		return;

	new row[nade_e];
	ArrayGetArray(g_pNade, idx, row, sizeof row);

	new key[SKIN_KEY_MAX];
	NadeOwnedKey(row[nade_key], key, charsmax(key));

	new exp = SkinExpire(id, key);
	if (exp == 0) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_OWNED_PERM", "你已永久拥有该投掷物皮肤");
		return;
	}
	if (exp > 0 && exp > get_systime()) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_OWNED_RENT", "你已拥有该投掷物皮肤(剩 ^3%d^1 天), 无需重复购买", DaysLeft(id, key));
		return;
	}
	if (g_hSqlTuple == Empty_Handle) {
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_BUY", "MySQL 未就绪, 暂不能购买");
		return;
	}

	new price = row[nade_price];
	new iGold = hns_gc_get_player(id);
	if (iGold < price) {
		SkinChat(id, print_team_red, "SKIN_CHAT_GOLD_NEED", "金币不足! 需要 %d, 你有 %d", price, iGold);
		return;
	}

	hns_gc_set_player(id, iGold - price);
	if (!g_Owned[id])
		g_Owned[id] = ArrayCreate(SKIN_KEY_MAX);
	if (!g_OwnedExpire[id])
		g_OwnedExpire[id] = TrieCreate();
	if (!HasSkin(id, key))
		ArrayPushString(g_Owned[id], key);
	TrieSetCell(g_OwnedExpire[id], key, 0); // 投掷物皮肤永久拥有

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_InsertOwned(id, authid, key, 0, price);

	SelectNade(id, idx);
	SkinChat(id, print_team_blue, "SKIN_CHAT_BUY_PERM", "投掷物皮肤购买成功! 剩余金币 %d", iGold - price);
}

SelectNade(id, idx) {
	new row[nade_e];
	ArrayGetArray(g_pNade, idx, row, sizeof row);

	SetNadeCurSlot(id, row[nade_kind], row[nade_key]);

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_SaveCurrent(id, authid, row[nade_key], NadeKindChar(row[nade_kind]));

	SkinChat(id, print_team_blue, "SKIN_CHAT_SELECTED", "你已选用投掷物皮肤: ^3%s", row[nade_key]);
}

MenuNades(id) {
	g_iNadeKindPage[id] = -1;
	// 分类选择页: 先进这里, 再选 烟雾弹 / 闪光弹
	new szTitle[160], szItem[160];
	SkinLangF(id, "SKIN_NADE_TITLE", "\y投掷物皮肤^n\w金币: \y%d  \w免费名额: \y%d",
		szTitle, charsmax(szTitle), hns_gc_get_player(id), g_iNadeFree);
	new menu = menu_create(szTitle, "NadeHandler");

	new szCat[96];
	SkinLangF(id, "SKIN_NADE_CAT_SMOKE", "烟雾弹皮肤  [%d款]", szCat, charsmax(szCat), CountNadesOfKind(NADE_KIND_SMOKE));
	formatex(szItem, charsmax(szItem), "\y%s", szCat);
	menu_additem(menu, szItem, "catS");
	SkinLangF(id, "SKIN_NADE_CAT_FLASH", "闪光弹皮肤  [%d款]", szCat, charsmax(szCat), CountNadesOfKind(NADE_KIND_FLASH));
	formatex(szItem, charsmax(szItem), "\y%s", szCat);
	menu_additem(menu, szItem, "catF");

	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

// 某一类投掷物皮肤的数量 (0=烟雾 1=闪光)
CountNadesOfKind(kind) {
	new n;
	for (new i = 0; i < g_iNadeSize; i++) {
		new row[nade_e];
		ArrayGetArray(g_pNade, i, row, sizeof row);
		if (row[nade_kind] == kind)
			n++;
	}
	return n;
}

// 单类投掷物皮肤列表 (只显示 kind 这一类), -1 = 全部分类
MenuNadeKind(id, kind, page = 0) {
	g_iNadeKindPage[id] = kind;
	g_iNadePage[id] = page;
	new szTitle[160], szItem[160], szInfo[12];
	new szKindName[16];
	SkinLang(id, kind == NADE_KIND_FLASH ? "SKIN_NADE_KIND_FLASH" : "SKIN_NADE_KIND_SMOKE",
		szKindName, charsmax(szKindName), kind == NADE_KIND_FLASH ? "闪光弹" : "烟雾弹");
	SkinLangF(id, "SKIN_NADE_KIND_TITLE", "\y%s皮肤^n\w金币: \y%d  \w免费名额: \y%d",
		szTitle, charsmax(szTitle), szKindName, hns_gc_get_player(id), g_iNadeFree);
	new menu = menu_create(szTitle, "NadeHandler");

	new added, curNade[SKIN_KEY_MAX];
	NadeCurSlot(id, kind, curNade, charsmax(curNade));
	for (new i = 0; i < g_iNadeSize; i++) {
		new row[nade_e];
		ArrayGetArray(g_pNade, i, row, sizeof row);
		if (row[nade_kind] != kind)
			continue;

		FormatShopItem(id, szItem, charsmax(szItem), row[nade_key], IsNadeOwned(id, i), row[nade_price], equal(curNade, row[nade_key]) != 0);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szItem, szInfo);
		added++;
	}

	if (!added)
		menu_additem(menu, "\d(该分类暂无投掷物皮肤)", "none");

	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, page);
}

MenuConfirmNadeBuy(id, idx, kind = -1, page = 0) {
	new row[nade_e];
	ArrayGetArray(g_pNade, idx, row, sizeof row);

	g_iNadePage[id] = page;
	if (row[nade_price] == 0 || IsNadeFree(idx)) {
		DoBuyNade(id, idx);
		OpenShopLater(id, SHOP_MENU_NADE_KIND, page, kind >= 0 ? kind : row[nade_kind]);
		return;
	}

	new szTitle[160], szItem[96], szInfo[12], szRent[32];
	SkinLang(id, "SKIN_PERM", szRent, charsmax(szRent), "永久");
	SkinLangF(id, "SKIN_NADE_BUY_TITLE", "\y确认购买投掷物皮肤^n\w名称: %s^n\w价格: \y%d 金币  \w租期: %s",
		szTitle, charsmax(szTitle), row[nade_key], row[nade_price], szRent);
	new menu = menu_create(szTitle, "NadeConfirmHandler");
	num_to_str(idx, szInfo, charsmax(szInfo));
	SkinLangF(id, "SKIN_BUY_OK", "确认购买  \r-%d", szItem, charsmax(szItem), row[nade_price]);
	menu_additem(menu, szItem, szInfo);
	SkinLang(id, "SKIN_CANCEL", szItem, charsmax(szItem), "取消");
	menu_additem(menu, szItem, "cancel");
	SkinMenuStyle(id, menu);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

RefreshNadeKindNames(id, menu, kind) {
	new szItem[160], curNade[SKIN_KEY_MAX], szInfo[12], access, callback, name[2];
	NadeCurSlot(id, kind, curNade, charsmax(curNade));
	new count = menu_items(menu);
	for (new i = 0; i < count; i++) {
		menu_item_getinfo(menu, i, access, szInfo, charsmax(szInfo), name, charsmax(name), callback);
		if (!szInfo[0] || equal(szInfo, "none") || equal(szInfo, "catS") || equal(szInfo, "catF"))
			continue;
		new idx = str_to_num(szInfo);
		if (idx < 0 || idx >= g_iNadeSize)
			continue;
		new row[nade_e];
		ArrayGetArray(g_pNade, idx, row, sizeof row);
		FormatShopItem(id, szItem, charsmax(szItem), row[nade_key], IsNadeOwned(id, idx), row[nade_price], equal(curNade, row[nade_key]) != 0);
		menu_item_setname(menu, i, szItem);
	}
}

public NadeHandler(id, menu, item) {
	new kind = g_iNadeKindPage[id];
	new page = g_iNadePage[id];
	if (item == MENU_EXIT) {
		if (KeepShopMenu(id) && (kind == NADE_KIND_SMOKE || kind == NADE_KIND_FLASH)) {
			menu_display(id, menu, page);
			return PLUGIN_HANDLED;
		}
		menu_destroy(menu);
		if (kind == NADE_KIND_SMOKE || kind == NADE_KIND_FLASH)
			OpenShopLater(id, SHOP_MENU_NADE_CAT);
		else {
			OpenShopLater(id, SHOP_MENU_SKIN);
			ScheduleHeldNadeApply(id);
		}
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	page = item / SKIN_PER_PAGE;
	g_iNadePage[id] = page;

	if (equal(szInfo, "catS")) {
		menu_destroy(menu);
		OpenShopLater(id, SHOP_MENU_NADE_KIND, 0, NADE_KIND_SMOKE);
		return PLUGIN_HANDLED;
	}
	if (equal(szInfo, "catF")) {
		menu_destroy(menu);
		OpenShopLater(id, SHOP_MENU_NADE_KIND, 0, NADE_KIND_FLASH);
		return PLUGIN_HANDLED;
	}

	if (equal(szInfo, "none")) {
		MarkShopKeep(id);
		menu_display(id, menu, 0);
		return PLUGIN_HANDLED;
	}
	new idx = str_to_num(szInfo);
	if (idx >= 0 && idx < g_iNadeSize) {
		if (IsNadeOwned(id, idx)) {
			SelectNade(id, idx);
			MarkShopKeep(id);
			RefreshNadeKindNames(id, menu, kind);
			menu_display(id, menu, page);
		} else {
			menu_destroy(menu);
			MenuConfirmNadeBuy(id, idx, kind, page);
		}
	} else {
		MarkShopKeep(id);
		menu_display(id, menu, page);
	}
	return PLUGIN_HANDLED;
}

public NadeConfirmHandler(id, menu, item) {
	new kind = g_iNadeKindPage[id];
	if (item == MENU_EXIT) {
		if (KeepShopMenu(id)) {
			menu_display(id, menu, 0);
			return PLUGIN_HANDLED;
		}
		menu_destroy(menu);
		OpenShopLater(id, SHOP_MENU_NADE_KIND, g_iNadePage[id], kind);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (!equal(szInfo, "cancel"))
		DoBuyNade(id, str_to_num(szInfo));
	OpenShopLater(id, SHOP_MENU_NADE_KIND, g_iNadePage[id], kind);
	return PLUGIN_HANDLED;
}

/* 把玩家选用的投掷物皮肤应用到刚生成的 grenade 实体上。
 * CS1.6 世界里 grenade 实体的模型是 models/w_smokegrenade.mdl / w_flashbang.mdl,
 * 用 pev_owner 找到投掷者, 再按其当前选用换模型。 */
public fw_SetModel(ent, const model[]) {
	if (!pev_valid(ent))
		return FMRES_IGNORED;

	new szClass[32];
	pev(ent, pev_classname, szClass, charsmax(szClass));

	new kind;
	if (equali(szClass, "grenade")) {
		if (containi(model, "w_smokegrenade") != -1 || containi(model, "smokegrenade") != -1)
			kind = NADE_KIND_SMOKE;
		else if (containi(model, "w_flashbang") != -1 || containi(model, "flashbang") != -1)
			kind = NADE_KIND_FLASH;
		else
			return FMRES_IGNORED;
	} else {
		return FMRES_IGNORED;
	}

	new owner = pev(ent, pev_owner);
	if (owner < 1 || owner > MaxClients || !is_user_connected(owner))
		return FMRES_IGNORED;

	new szView[PLATFORM_MAX_PATH], szWorld[PLATFORM_MAX_PATH];
	if (!GetNadeCurrentModel(owner, kind, szView, charsmax(szView)))
		return FMRES_IGNORED;
	if (!NadeWorldPath(szView, szWorld, charsmax(szWorld)))
		return FMRES_IGNORED;

	engfunc(EngFunc_SetModel, ent, szWorld);
	return FMRES_SUPERCEDE;
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

Db_SaveKnifeCurrent(id, const authid[], knife) {
	new key[SKIN_KEY_MAX];
	formatex(key, charsmax(key), "knife:%d", knife);
	Db_SaveCurrent(id, authid, key, 'K');
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

/* 同步执行单条查询(预缓存阶段用)并释放, 支持 %s 等格式化。
 * 不要外包 fmt(): fmt() 只有 256 字节, 建表/INSERT 会被截断。 */
SQL_ExecSync(Handle:conn, const szQuery[], any:...) {
	new szQ[2048];
	vformat(szQ, charsmax(szQ), szQuery, 3);
	new Handle:q = SQL_PrepareQuery(conn, "%s", szQ);
	if (q == Empty_Handle) {
		log_amx("[Skin] SQL 预处理失败: %s", szQ);
		return;
	}
	if (!SQL_Execute(q)) {
		new szErr[160];
		SQL_QueryError(q, szErr, charsmax(szErr));
		// 老库补列时列已存在, 不算故障
		if (containi(szErr, "Duplicate column") == -1)
			log_amx("[Skin] SQL 执行失败: %s | %s", szErr, szQ);
	}
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
		return true;

	new file = fopen(szCfg, "rt");
	if (!file)
		return true;

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
 * 下一行(可选, 可多行): wav 音效路径 (属于上一款; 多条则死亡时随机; 也可一款复用)
 * 名字即识别 key(菜单/拥有都靠它, 中文也可以, 全服唯一不能重复)
 * 用 upsert: 名字已存在则覆盖该款, 否则插入。
 * conn 为空时只解析并直接进内存池, 不写库。 */
ImportSkinsToDb(Handle:conn, const szCfg[]) {
	new file = fopen(szCfg, "rt");
	if (!file) {
		log_amx("[Skin] 皮肤配置文件不存在: %s", szCfg);
		return;
	}

	new szLine[512], szHead[32], szRestA[384];
	new szKey[SKIN_KEY_MAX], szModel[SKIN_MODEL_MAX];
	new sTeam[2], sPrice[16], sWav[DEATH_SND_MAX];
	new iImported, iSkipped;
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
				if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))
					iImported++;
				else
					iSkipped++;
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
			else if (equali(szHead, "knife_free"))
				g_iKnifeFree = str_to_num(szVal);
			else if (equali(szHead, "nade_free"))
				g_iNadeFree = str_to_num(szVal);
			else if (equali(szHead, "buy_gold_text") || equali(szHead, "buy_gold_url")) {
				new iPos = strlen(szHead);
				while (szLine[iPos] == ' ' || szLine[iPos] == '^t')
					iPos++;
				if (equali(szHead, "buy_gold_text"))
					copy(g_szBuyGoldText, charsmax(g_szBuyGoldText), szLine[iPos]);
				else
					copy(g_szBuyGoldUrl, charsmax(g_szBuyGoldUrl), szLine[iPos]);
				StripQuotes(g_szBuyGoldText);
				StripQuotes(g_szBuyGoldUrl);
			}
			else if (equali(szHead, "precache_max"))
				g_iPrecacheMax = str_to_num(szVal);
			else if (equali(szHead, "checkin_bonus"))
				g_iCheckinBonus = str_to_num(szVal);
			else if (equali(szHead, "playtime_bonus"))
				g_iPlaytimeBonus = str_to_num(szVal);
			else if (equali(szHead, "playtime_seconds")) {
				g_iPlaytimeNeed = str_to_num(szVal);
				if (g_iPlaytimeNeed < 60)
					g_iPlaytimeNeed = 3600;
			}
			continue;
		}

		// 裸区块头 tt / t / ct (单独一行, 不带方括号)
		if ((equali(szHead, "tt") || equali(szHead, "t") || equali(szHead, "ct")) && !szRestA[0]) {
			if (bPending) {
				if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))
					iImported++;
				else
					iSkipped++;
			}
			if (equali(szHead, "tt") || equali(szHead, "t")) sTeam[0] = TEAM_CHAR_T;
			else sTeam[0] = TEAM_CHAR_C;
			bPending = false;
			continue;
		}

		// 音效行: 以 wav 开头, 属于上一款; 可写多行, 死亡时随机
		if (equali(szHead, "wav")) {
			new szOne[DEATH_SND_MAX];
			copy(szOne, charsmax(szOne), szRestA);
			trim(szOne);
			StripQuotes(szOne);
			AppendDeathSound(sWav, charsmax(sWav), szOne);
			continue;
		}

		// 新皮肤行: 先提交上一款
		if (bPending) {
			if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))
				iImported++;
			else
				iSkipped++;
		}

		// 名字 模型 价格 (阵营来自当前区块)
		copy(szKey, charsmax(szKey), szHead);
		StripQuotes(szKey);
		parse(szLine, szHead, charsmax(szHead), szModel, charsmax(szModel), sPrice, charsmax(sPrice));
		trim(szModel); trim(sPrice);
		StripQuotes(szModel); StripQuotes(sPrice);
		if (!sPrice[0])
			ParseSkinFields(szRestA, szModel, charsmax(szModel), sPrice, charsmax(sPrice));

		if (!szKey[0] || (sTeam[0] != TEAM_CHAR_T && sTeam[0] != TEAM_CHAR_C) || !szModel[0]) {
			log_amx("[Skin] 跳过无效行: %s", szLine);
			bPending = false;
			iSkipped++;
			continue;
		}
		sWav[0] = EOS;
		bPending = true;
	}
	if (bPending) {
		if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))
			iImported++;
		else
			iSkipped++;
	}

	fclose(file);
	log_amx("[Skin] 从 %s 导入/更新皮肤 %d 条, 跳过 %d 条", szCfg, iImported, iSkipped);
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

/* 把 "模型路径 价格" 拆开。价格必须是最后一个纯数字, 避免 strtok 把价格丢掉。 */
ParseSkinFields(const src[], szModel[], iModelLen, sPrice[], iPriceLen) {
	new szWork[384];
	copy(szWork, charsmax(szWork), src);
	trim(szWork);

	sPrice[0] = EOS;
	szModel[0] = EOS;

	new iLen = strlen(szWork);
	new i = iLen - 1;
	while (i >= 0 && (szWork[i] == ' ' || szWork[i] == 9))
		i--;
	new iEnd = i;
	while (i >= 0 && szWork[i] >= '0' && szWork[i] <= '9')
		i--;

	if (iEnd > i && i >= 0 && (szWork[i] == ' ' || szWork[i] == 9)) {
		copy(sPrice, iPriceLen, szWork[i + 1]);
		szWork[i] = EOS;
		trim(szWork);
	}

	copy(szModel, iModelLen, szWork);
	trim(szModel);
	StripQuotes(szModel);
	StripQuotes(sPrice);
	if (!sPrice[0])
		copy(sPrice, iPriceLen, "0");
}

/* 把一条或多条音效追加到逗号列表, 去重。支持 "a.wav,b.wav" 或多次 wav 行。 */
AppendDeathSound(dest[], iLen, const szOne[]) {
	if (!szOne[0])
		return;

	new szWork[DEATH_SND_MAX];
	copy(szWork, charsmax(szWork), szOne);
	trim(szWork);

	while (szWork[0]) {
		new szPart[DEATH_SND_PATH], szRest[DEATH_SND_MAX];
		strtok2(szWork, szPart, charsmax(szPart), szRest, charsmax(szRest), ',', 1);
		trim(szPart);
		StripQuotes(szPart);
		if (szPart[0] && !DeathSoundInList(dest, szPart)) {
			if (!dest[0]) {
				copy(dest, iLen, szPart);
			} else if (strlen(dest) + 1 + strlen(szPart) <= iLen) {
				format(dest, iLen, "%s,%s", dest, szPart);
			} else {
				log_amx("[Skin] 死亡音效列表过长, 跳过: %s", szPart);
			}
		}
		copy(szWork, charsmax(szWork), szRest);
		trim(szWork);
	}
}

bool:DeathSoundInList(const list[], const szOne[]) {
	if (!list[0] || !szOne[0])
		return false;

	new szWork[DEATH_SND_MAX];
	copy(szWork, charsmax(szWork), list);
	while (szWork[0]) {
		new szPart[DEATH_SND_PATH], szRest[DEATH_SND_MAX];
		strtok2(szWork, szPart, charsmax(szPart), szRest, charsmax(szRest), ',', 1);
		trim(szPart);
		if (equal(szPart, szOne))
			return true;
		copy(szWork, charsmax(szWork), szRest);
		trim(szWork);
	}
	return false;
}

PrecacheDeathSounds(const list[]) {
	new szWork[DEATH_SND_MAX];
	copy(szWork, charsmax(szWork), list);
	while (szWork[0]) {
		new szPart[DEATH_SND_PATH], szRest[DEATH_SND_MAX];
		strtok2(szWork, szPart, charsmax(szPart), szRest, charsmax(szRest), ',', 1);
		trim(szPart);
		if (szPart[0])
			precache_sound(szPart);
		copy(szWork, charsmax(szWork), szRest);
		trim(szWork);
	}
}

/* 从逗号列表里随机抽一条。 */
PickDeathSound(const list[], dest[], iLen) {
	dest[0] = EOS;
	if (!list[0])
		return;

	new szParts[8][DEATH_SND_PATH];
	new iCount;
	new szWork[DEATH_SND_MAX];
	copy(szWork, charsmax(szWork), list);
	while (szWork[0] && iCount < sizeof szParts) {
		new szRest[DEATH_SND_MAX];
		strtok2(szWork, szParts[iCount], charsmax(szParts[]), szRest, charsmax(szRest), ',', 1);
		trim(szParts[iCount]);
		if (szParts[iCount][0])
			iCount++;
		copy(szWork, charsmax(szWork), szRest);
		trim(szWork);
	}
	if (!iCount)
		return;
	copy(dest, iLen, szParts[random_num(0, iCount - 1)]);
}

/* 把一款皮肤 upsert 到 cpm_skins (名字唯一, 重复则覆盖该款)。
 * 无数据库时直接进内存池。
 * bPrecache=false: 只写库, 不重复预缓存 (换图阶段已从 cfg 进池)。 */
bool:CommitSkinRow(Handle:conn, const szKey[], const sTeam[], const szModel[], const sPrice[], const sWav[], bool:bPrecache = true) {
	new iPrice = str_to_num(sPrice);
	if (conn != Empty_Handle) {
		new szEscKey[SKIN_KEY_MAX * 2], szEscModel[SKIN_MODEL_MAX * 2], szEscWav[DEATH_SND_MAX * 2];
		EscapeSql(szKey, szEscKey, charsmax(szEscKey));
		EscapeSql(szModel, szEscModel, charsmax(szEscModel));
		EscapeSql(sWav, szEscWav, charsmax(szEscWav));
		SQL_ExecSync(conn,
			"INSERT INTO %s (model_key, team, model, body, skin, price, flags, death_sound, created, updated) VALUES ('%s','%s','%s',0,0,%d,'','%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE team=VALUES(team), model=VALUES(model), price=VALUES(price), death_sound=VALUES(death_sound), active=1, updated=UNIX_TIMESTAMP()",
			SKINS_TABLE, szEscKey, sTeam, szEscModel, iPrice, szEscWav);
	}

	if (!bPrecache)
		return true;

	new row[pool_e];
	copy(row[pool_key], charsmax(row[pool_key]), szKey);
	copy(row[pool_model], charsmax(row[pool_model]), szModel);
	copy(row[pool_snd], charsmax(row[pool_snd]), sWav);
	row[pool_price] = iPrice;
	row[pool_team] = sTeam[0];
	return AddSkinToPool(row);
}

StripQuotes(sz[]) {
	new iLen = strlen(sz);
	if (iLen >= 2 && sz[0] == '"' && sz[iLen - 1] == '"') {
		sz[iLen - 1] = EOS;
		for (new j = 0; sz[j] && j < iLen; j++) sz[j] = sz[j + 1];
	}
}

CreateTablesSync(Handle:conn) {
	SQL_ExecSync(conn, "CREATE TABLE IF NOT EXISTS %s (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, model_key VARCHAR(32) NOT NULL, team CHAR(1) NOT NULL DEFAULT '', model VARCHAR(64) NOT NULL, body TINYINT NOT NULL DEFAULT 0, skin TINYINT NOT NULL DEFAULT 0, price INT NOT NULL DEFAULT 0, flags VARCHAR(16) NOT NULL DEFAULT '', death_sound VARCHAR(320) NOT NULL DEFAULT '', active TINYINT NOT NULL DEFAULT 1, created INT NOT NULL DEFAULT 0, updated INT NOT NULL DEFAULT 0, UNIQUE KEY uk_key (model_key))", SKINS_TABLE);

	SQL_ExecSync(conn, "CREATE TABLE IF NOT EXISTS %s (authid VARCHAR(64) NOT NULL, model_key VARCHAR(32) NOT NULL, bought_at INT NOT NULL DEFAULT 0, expire_at INT NOT NULL DEFAULT 0, PRIMARY KEY (authid, model_key), KEY idx_authid (authid))", OWNS_TABLE);

	// 老库升级: 补 expire_at 列 (已存在则自动忽略错误)
	SQL_ExecSync(conn, "ALTER TABLE %s ADD COLUMN expire_at INT NOT NULL DEFAULT 0", OWNS_TABLE);

	SQL_ExecSync(conn, "CREATE TABLE IF NOT EXISTS %s (authid VARCHAR(64) NOT NULL, team CHAR(1) NOT NULL DEFAULT '', model_key VARCHAR(32) NOT NULL DEFAULT '', updated INT NOT NULL DEFAULT 0, PRIMARY KEY (authid, team))", CUR_TABLE);
}

bool:AddSkinToPool(row[pool_e]) {
	if (!row[pool_key][0] || !row[pool_model][0])
		return false;
	if (PoolIndexOf(row[pool_key]) != -1)
		return true;

	if (row[pool_snd][0])
		PrecacheDeathSounds(row[pool_snd]);

	// 预缓存上限: 超过则跳过模型预缓存(本图不可用), 仍然保留皮肤目录/商店, 避免撞 512 模型池崩服
	if (g_iPrecacheMax > 0 && g_iPrecacheUsed >= g_iPrecacheMax) {
		row[pool_precache] = 0;
		ArrayPushArray(g_pPool, row, sizeof row);
		TrieSetCell(g_pPoolIndex, row[pool_key], g_iPoolSize);
		g_iPoolSize++;
		return true;
	}

	if (!custom_player_models_register(row[pool_key], row[pool_model],
		row[pool_body], row[pool_skin],
		row[pool_model], row[pool_body], row[pool_skin])) {
		log_amx("[Skin] 预缓存失败(模型文件缺失?): %s -> %s", row[pool_key], row[pool_model]);
		return false;
	}

	row[pool_precache] = 1;
	g_iPrecacheUsed++;
	ArrayPushArray(g_pPool, row, sizeof row);
	TrieSetCell(g_pPoolIndex, row[pool_key], g_iPoolSize);
	g_iPoolSize++;
	return true;
}

LoadPoolSync(Handle:conn) {
	new Handle:q = SQL_PrepareQuery(conn,
		"SELECT model_key, team, model, body, skin, price, flags, death_sound FROM %s WHERE active=1", SKINS_TABLE);
	if (q == Empty_Handle)
		return;

	if (!SQL_Execute(q)) {
		new szErr[160];
		SQL_QueryError(q, szErr, charsmax(szErr));
		log_amx("[Skin] 读取皮肤池失败: %s", szErr);
		SQL_FreeHandle(q);
		return;
	}

	// 0 model_key, 1 team, 2 model, 3 body, 4 skin, 5 price, 6 flags, 7 death_sound
	if (SQL_MoreResults(q) && SQL_NumColumns(q) >= 8) {
		while (SQL_MoreResults(q)) {
			new row[pool_e];
			new szTeam[2];
			SQL_ReadResult(q, 0, row[pool_key],  charsmax(row[pool_key]));
			SQL_ReadResult(q, 1, szTeam, charsmax(szTeam));
			row[pool_team] = szTeam[0];
			SQL_ReadResult(q, 2, row[pool_model], charsmax(row[pool_model]));
			row[pool_body] = SQL_ReadResult(q, 3);
			row[pool_skin] = SQL_ReadResult(q, 4);
			row[pool_price] = SQL_ReadResult(q, 5);
			SQL_ReadResult(q, 6, row[pool_flags], charsmax(row[pool_flags]));
			SQL_ReadResult(q, 7, row[pool_snd],   charsmax(row[pool_snd]));
			AddSkinToPool(row);
			SQL_NextRow(q);
		}
	}

	SQL_FreeHandle(q);
	log_amx("[Skin] 皮肤池加载完成, 共 %d 个皮肤", g_iPoolSize);
}

LoadSkinsCfgDirect() {
	new szCfg[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
	format(szCfg, charsmax(szCfg), "%s/%s", szCfg, SKINS_CFG_FILE);
	ImportSkinsToDb(Empty_Handle, szCfg);
	log_amx("[Skin] 已从配置文件直接加载皮肤池, 共 %d 个皮肤 (已预缓存模型 %d 个, 上限 precache_max=%d)",
		g_iPoolSize, g_iPrecacheUsed, g_iPrecacheMax);
}

/* 换图阶段: 只读 skins.cfg 进内存并预缓存模型, 不连 MySQL。
 * 建表/导入放到 plugin_init 后台, 避免 changelevel 卡 5-6 秒。 */
DbPrecachePool() {
	LoadSkinsCfgDirect();
}

DbSyncCatalog(bool:bImportCfg = true) {
	if (g_hSqlTuple == Empty_Handle) {
		g_bSqlReady = false;
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		return;
	}

	new szErr[160], iErr;
	new Handle:conn = SQL_Connect(g_hSqlTuple, iErr, szErr, charsmax(szErr));
	if (conn == Empty_Handle) {
		g_bSqlReady = false;
		g_iSqlLastErr = iErr;
		copy(g_szSqlLastErr, charsmax(g_szSqlLastErr), szErr);
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "fail");
		log_amx("[Skin] 后台同步皮肤目录失败(%d): %s", iErr, szErr);
		return;
	}

	CreateTablesSync(conn);

	// 换图只建表, 不把 skins.cfg 全量 upsert; 改配置后用管理菜单「同步」
	if (bImportCfg) {
		new szCfg[PLATFORM_MAX_PATH];
		get_localinfo("amxx_configsdir", szCfg, charsmax(szCfg));
		format(szCfg, charsmax(szCfg), "%s/%s", szCfg, SKINS_CFG_FILE);
		ImportSkinsCatalogOnly(conn, szCfg);
	}

	g_bSqlReady = true;
	g_iSqlLastErr = 0;
	g_szSqlLastErr[0] = EOS;
	copy(g_szSqlStatus, charsmax(g_szSqlStatus), "ok");
	SQL_FreeHandle(conn);
}

/* 只把 skins.cfg 写进 MySQL, 不再预缓存 (换图时已经进池)。 */
ImportSkinsCatalogOnly(Handle:conn, const szCfg[]) {
	new file = fopen(szCfg, "rt");
	if (!file)
		return;

	new szLine[512], szHead[32], szRestA[384];
	new szKey[SKIN_KEY_MAX], szModel[SKIN_MODEL_MAX];
	new sTeam[2], sPrice[16], sWav[DEATH_SND_MAX];
	new iImported, iSkipped;
	new bool:bPending;
	new bool:bSettings;

	while (!feof(file)) {
		fgets(file, szLine, charsmax(szLine));
		trim(szLine);
		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue;

		if (szLine[0] == '[') {
			if (bPending) {
				if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav, false))
					iImported++;
				else
					iSkipped++;
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

		if (bSettings) {
			continue;
		}

		if ((equali(szHead, "tt") || equali(szHead, "t") || equali(szHead, "ct")) && !szRestA[0]) {
			if (bPending) {
				if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav, false))
					iImported++;
				else
					iSkipped++;
			}
			if (equali(szHead, "tt") || equali(szHead, "t")) sTeam[0] = TEAM_CHAR_T;
			else sTeam[0] = TEAM_CHAR_C;
			bPending = false;
			continue;
		}

		if (equali(szHead, "wav")) {
			new szOne[DEATH_SND_MAX];
			copy(szOne, charsmax(szOne), szRestA);
			trim(szOne);
			StripQuotes(szOne);
			AppendDeathSound(sWav, charsmax(sWav), szOne);
			continue;
		}

		if (bPending) {
			if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav, false))
				iImported++;
			else
				iSkipped++;
		}

		copy(szKey, charsmax(szKey), szHead);
		StripQuotes(szKey);
		parse(szLine, szHead, charsmax(szHead), szModel, charsmax(szModel), sPrice, charsmax(sPrice));
		trim(szModel); trim(sPrice);
		StripQuotes(szModel); StripQuotes(sPrice);
		if (!sPrice[0])
			ParseSkinFields(szRestA, szModel, charsmax(szModel), sPrice, charsmax(sPrice));

		if (!szKey[0] || (sTeam[0] != TEAM_CHAR_T && sTeam[0] != TEAM_CHAR_C) || !szModel[0]) {
			bPending = false;
			iSkipped++;
			continue;
		}
		sWav[0] = EOS;
		bPending = true;
	}
	if (bPending) {
		if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav, false))
			iImported++;
		else
			iSkipped++;
	}

	fclose(file);
	log_amx("[Skin] 后台同步皮肤目录 %d 条, 跳过 %d 条", iImported, iSkipped);
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

	if (key[0] && PoolIndexOf(key) != -1 && IsSkinValid(id, key) && IsSkinPrecached(key)) {
		custom_player_models_set(id, key);
		SkinChat(id, print_team_default, "SKIN_CHAT_APPLIED", "已应用皮肤: ^3%s", key);
		MarkAppliedSkin(id, teamChar, key);
	} else {
		custom_player_models_reset(id);
		MarkAppliedSkin(id, teamChar, "");
	}
}

// 记录已经写到模型上的阵营+款, 避免每帧重复 set
MarkAppliedSkin(id, teamChar, const key[]) {
	g_szAppliedTeam[id] = teamChar;
	copy(g_szAppliedKey[id], charsmax(g_szAppliedKey[]), key);
}

SelectSkin(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	new teamChar = CharOfTeam(get_member(id, m_iTeam));
	// 只允许应用当前阵营的皮肤；购买另一阵营只保存所有权，不立即换模型
	// 本图因预缓存上限被跳过的款式不能应用 (模型没进池会拉不到)
	if (row[pool_team] == teamChar && row[pool_precache])
		custom_player_models_set(id, row[pool_key]);
	// 写入对应阵营槽
	if (row[pool_team] == TEAM_CHAR_T)
		copy(g_CurT[id], charsmax(g_CurT[]), row[pool_key]);
	else
		copy(g_CurC[id], charsmax(g_CurC[]), row[pool_key]);

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_SaveCurrent(id, authid, row[pool_key], row[pool_team]);

	new szTeam[48];
	SkinTeamLong(id, row[pool_team], szTeam, charsmax(szTeam));
	SkinChat(id, print_team_blue, "SKIN_CHAT_SELECTED", "你已选用%s阵营皮肤: ^3%s", szTeam, row[pool_key]);
}

DoBuy(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	// 本图未预缓存(超过 precache_max)的不能购买, 换图后再买
	if (!row[pool_precache]) {
		SkinChat(id, print_team_default, "SKIN_CHAT_MAP_NA", "皮肤 ^3%s^1 本图未加载(模型预缓存上限), 换图后再试", row[pool_key]);
		return;
	}

	// 已永久拥有: 不能再买
	new exp = SkinExpire(id, row[pool_key]);
	if (exp == 0) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_OWNED_PERM", "你已永久拥有该皮肤");
		return;
	}
	// 租期还有效: 无需重复购买
	if (exp > 0 && exp > get_systime()) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_OWNED_RENT", "你已拥有该皮肤(剩 ^3%d^1 天), 无需重复购买", DaysLeft(id, row[pool_key]));
		return;
	}

	if (g_hSqlTuple == Empty_Handle) {
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_BUY", "MySQL 未就绪, 暂不能购买");
		return;
	}

	new iGold = hns_gc_get_player(id);
	if (iGold < row[pool_price]) {
		SkinChat(id, print_team_red, "SKIN_CHAT_GOLD_NEED", "金币不足! 需要 %d, 你有 %d", row[pool_price], iGold);
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
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_InsertOwned(id, authid, row[pool_key], iExpire, row[pool_price]);

	SelectSkin(id, idx);
	if (row[pool_team] != CharOfTeam(get_member(id, m_iTeam)))
		SkinChat(id, print_team_default, "SKIN_CHAT_SELECTED_OTHER_TEAM", "皮肤 ^3%s^1 已保存, 切换阵营后生效", row[pool_key]);
	if (iExpire == 0)
		SkinChat(id, print_team_blue, "SKIN_CHAT_BUY_PERM", "购买成功(永久)! 剩余金币 %d", iGold - row[pool_price]);
	else
		SkinChat(id, print_team_blue, "SKIN_CHAT_BUY_RENT", "购买成功! 租期 %d 天, 剩余金币 %d", g_iRentDays, iGold - row[pool_price]);
}

KnifeInfo(knife, name[], nameLen, &price) {
	name[0] = EOS;
	price = 0;
	crxknives_get_attribute_str(knife, "NAME", name, nameLen, false);
	if (!name[0])
		formatex(name, nameLen, "Knife %d", knife);
	crxknives_get_attribute_int(knife, "PRICE", price, false);
	if (price < 0)
		price = 0;

	// knife_skins.cfg 里有该刀(按名字)就覆盖商店价格, 方便单独管理
	if (g_tKnifePrice != Invalid_Trie && name[0]) {
		new iOverride;
		if (TrieGetCell(g_tKnifePrice, name, iOverride))
			price = iOverride;
	}
}

DoBuyKnife(id, knife) {
	if (!IsKnifeShopItemValid(knife))
		return;

	new key[SKIN_KEY_MAX], name[MAX_NAME_LENGTH], price;
	KnifeOwnedKey(knife, key, charsmax(key));
	KnifeInfo(knife, name, charsmax(name), price);

	new exp = SkinExpire(id, key);
	if (exp == 0) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_OWNED_PERM", "你已永久拥有该刀皮");
		return;
	}
	if (exp > 0 && exp > get_systime()) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_OWNED_RENT", "你已拥有该刀皮(剩 ^3%d^1 天), 无需重复购买", DaysLeft(id, key));
		return;
	}
	if (g_hSqlTuple == Empty_Handle) {
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_BUY", "MySQL 未就绪, 暂不能购买");
		return;
	}

	new iGold = hns_gc_get_player(id);
	if (iGold < price) {
		SkinChat(id, print_team_red, "SKIN_CHAT_GOLD_NEED", "金币不足! 需要 %d, 你有 %d", price, iGold);
		return;
	}

	hns_gc_set_player(id, iGold - price);
	if (!g_Owned[id])
		g_Owned[id] = ArrayCreate(SKIN_KEY_MAX);
	if (!g_OwnedExpire[id])
		g_OwnedExpire[id] = TrieCreate();
	if (!HasSkin(id, key))
		ArrayPushString(g_Owned[id], key);

	new iExpire = (g_iRentDays > 0) ? get_systime() + g_iRentDays * 86400 : 0;
	TrieSetCell(g_OwnedExpire[id], key, iExpire);

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_InsertOwned(id, authid, key, iExpire, price);
	SelectKnife(id, knife);

	if (iExpire == 0)
		SkinChat(id, print_team_blue, "SKIN_CHAT_BUY_PERM", "刀皮购买成功(永久)! 剩余金币 %d", iGold - price);
	else
		SkinChat(id, print_team_blue, "SKIN_CHAT_BUY_RENT", "刀皮购买成功! 租期 %d 天, 剩余金币 %d", g_iRentDays, iGold - price);
}

MenuKnives(id, page = 0) {
	new szTitle[160], szItem[160], szName[MAX_NAME_LENGTH], szInfo[12], curKnife;
	curKnife = crxknives_get_user_knife(id);
	SkinLangF(id, "SKIN_KNIFE_TITLE", "\y刀皮商店^n\w金币: \y%d  \w当前: \y%d  \w免费名额: \y%d",
		szTitle, charsmax(szTitle), hns_gc_get_player(id), curKnife, g_iKnifeFree);
	new menu = menu_create(szTitle, "KnifeHandler");

	new selectedKnife = g_iCurKnife[id] ? g_iCurKnife[id] : curKnife;
	for (new knife = 0; knife < crxknives_get_knives_num(); knife++) {
		new price;
		KnifeInfo(knife, szName, charsmax(szName), price);
		FormatShopItem(id, szItem, charsmax(szItem), szName, (knife < g_iKnifeFree || IsKnifeOwned(id, knife)), price, knife == selectedKnife);
		num_to_str(knife, szInfo, charsmax(szInfo));
		menu_additem(menu, szItem, szInfo);
	}

	if (!crxknives_get_knives_num())
		menu_additem(menu, "\d(暂无刀皮)", "none");

	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, page);
}

MenuConfirmKnifeBuy(id, knife, page = 0) {
	new name[MAX_NAME_LENGTH], price, szTitle[160], szItem[96], szInfo[12];
	KnifeInfo(knife, name, charsmax(name), price);
	g_iKnifePage[id] = page;
	if (price == 0 || knife < g_iKnifeFree) {
		DoBuyKnife(id, knife);
		OpenShopLater(id, SHOP_MENU_KNIFE, page);
		return;
	}
	new szRent[32];
	if (g_iRentDays > 0)
		SkinLangF(id, "SKIN_DAYS", "%d天", szRent, charsmax(szRent), g_iRentDays);
	else
		SkinLang(id, "SKIN_PERM", szRent, charsmax(szRent), "永久");
	SkinLangF(id, "SKIN_KNIFE_BUY_TITLE", "\y确认购买刀皮^n\w名称: %s^n\w价格: \y%d 金币  \w租期: %s",
		szTitle, charsmax(szTitle), name, price, szRent);
	new menu = menu_create(szTitle, "KnifeConfirmHandler");
	num_to_str(knife, szInfo, charsmax(szInfo));
	SkinLangF(id, "SKIN_BUY_OK", "确认购买  \r-%d", szItem, charsmax(szItem), price);
	menu_additem(menu, szItem, szInfo);
	SkinLang(id, "SKIN_CANCEL", szItem, charsmax(szItem), "取消");
	menu_additem(menu, szItem, "cancel");
	SkinMenuStyle(id, menu);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

// 花费 upgrade_price 把已购限时皮肤升级为永久
DoUpgrade(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	new exp = SkinExpire(id, row[pool_key]);
	if (exp == 0) {
		SkinChat(id, print_team_blue, "SKIN_CHAT_ALREADY_PERM", "该皮肤已经是永久了");
		return;
	}
	if (exp < 0 || (exp > 0 && exp <= get_systime())) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NEED_OWN", "你还没有有效的 %s, 先购买后再升级", row[pool_key]);
		return;
	}

	if (g_hSqlTuple == Empty_Handle) {
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_UP", "MySQL 未就绪, 暂不能升级");
		return;
	}

	new iGold = hns_gc_get_player(id);
	if (iGold < g_iUpgradePrice) {
		SkinChat(id, print_team_red, "SKIN_CHAT_GOLD_UP", "金币不足! 升级永久需要 %d, 你有 %d", g_iUpgradePrice, iGold);
		return;
	}

	hns_gc_set_player(id, iGold - g_iUpgradePrice);

	TrieSetCell(g_OwnedExpire[id], row[pool_key], 0);

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_SetPermanent(id, authid, row[pool_key], g_iUpgradePrice);

	MenuGold(id);
	SkinChat(id, print_team_blue, "SKIN_CHAT_UP_OK", "升级永久成功! 皮肤 ^3%s^1 现在永久有效, 剩余金币 %d", row[pool_key], iGold - g_iUpgradePrice);
}

OnSkinChosen(id, idx, page = 0) {
	if (idx < 0 || idx >= g_iPoolSize)
		return;

	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	// 本图因预缓存上限未加载该模型, 不能购买/应用 (换一张地图即可用)
	if (!row[pool_precache]) {
		SkinChat(id, print_team_default, "SKIN_CHAT_MAP_NA", "皮肤 ^3%s^1 本图未加载(模型预缓存上限), 换图后再试", row[pool_key]);
		MenuBrowseSkins(id, g_iBrowseTeam[id], page);
		return;
	}

	if (IsSkinValid(id, row[pool_key])) {
		SelectSkin(id, idx);
		MenuBrowseSkins(id, g_iBrowseTeam[id], page);
	} else
		MenuConfirmBuy(id, idx, page);
}

/* ============================================================
   管理操作
   ============================================================ */
GiveSkinTo(target, idx, bool:silent = false) {
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
	GetPlayerAuth(target, authid, charsmax(authid));
	Db_InsertOwned(target, authid, row[pool_key], 0);

	// 该阵营还没选用时, 发放即写入当前槽, 换图后才能从 cpm_player_current 还原
	new cur[SKIN_KEY_MAX];
	CurSlot(target, cur, charsmax(cur), row[pool_team]);
	if (!cur[0] || equal(cur, row[pool_key])) {
		if (row[pool_team] == TEAM_CHAR_T)
			copy(g_CurT[target], charsmax(g_CurT[]), row[pool_key]);
		else
			copy(g_CurC[target], charsmax(g_CurC[]), row[pool_key]);
		Db_SaveCurrent(target, authid, row[pool_key], row[pool_team]);
		if (is_user_connected(target) && CharOfTeam(get_member(target, m_iTeam)) == row[pool_team] && row[pool_precache])
			custom_player_models_set(target, row[pool_key]);
	}

	if (silent)
		return;

	if (g_pendingAdmin[target] && is_user_connected(g_pendingAdmin[target]))
		SkinChat(g_pendingAdmin[target], print_team_default, "SKIN_CHAT_GIVE_ADMIN", "已向 %n 发放永久皮肤 ^3%s", target, row[pool_key]);
	if (is_user_connected(target))
		SkinChat(target, print_team_default, "SKIN_CHAT_GIVE_PLAYER", "管理员为你发放了永久皮肤 ^3%s", row[pool_key]);
}

GiveAllSkinsTo(target, teamChar) {
	new given;
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (teamChar && row[pool_team] != teamChar)
			continue;
		GiveSkinTo(target, i, true);
		given++;
	}
	return given;
}

// 管理员给玩家发放单把刀皮 (永久)
GiveKnifeTo(target, knife) {
	if (!IsKnifeShopItemValid(knife))
		return;
	new key[SKIN_KEY_MAX];
	KnifeOwnedKey(knife, key, charsmax(key));
	if (HasSkin(target, key))
		return;

	if (!g_Owned[target])
		g_Owned[target] = ArrayCreate(SKIN_KEY_MAX);
	if (!g_OwnedExpire[target])
		g_OwnedExpire[target] = TrieCreate();

	ArrayPushString(g_Owned[target], key);
	TrieSetCell(g_OwnedExpire[target], key, 0);

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(target, authid, charsmax(authid));
	Db_InsertOwned(target, authid, key, 0);
}

// 管理员给玩家发放单个投掷物皮肤 (永久)
GiveNadeTo(target, idx) {
	if (idx < 0 || idx >= g_iNadeSize)
		return;
	new row[nade_e];
	ArrayGetArray(g_pNade, idx, row, sizeof row);
	new key[SKIN_KEY_MAX];
	NadeOwnedKey(row[nade_key], key, charsmax(key));
	if (HasSkin(target, key))
		return;

	if (!g_Owned[target])
		g_Owned[target] = ArrayCreate(SKIN_KEY_MAX);
	if (!g_OwnedExpire[target])
		g_OwnedExpire[target] = TrieCreate();

	ArrayPushString(g_Owned[target], key);
	TrieSetCell(g_OwnedExpire[target], key, 0);

	new authid[MAX_AUTHID_LENGTH];
	GetPlayerAuth(target, authid, charsmax(authid));
	Db_InsertOwned(target, authid, key, 0);
}

// 管理员给玩家发放全部刀皮 (永久)
GiveAllKnivesTo(target) {
	new given, key[SKIN_KEY_MAX];
	for (new knife = 0; knife < crxknives_get_knives_num(); knife++) {
		KnifeOwnedKey(knife, key, charsmax(key));
		if (HasSkin(target, key))
			continue;

		if (!g_Owned[target])
			g_Owned[target] = ArrayCreate(SKIN_KEY_MAX);
		if (!g_OwnedExpire[target])
			g_OwnedExpire[target] = TrieCreate();

		ArrayPushString(g_Owned[target], key);
		TrieSetCell(g_OwnedExpire[target], key, 0);

		new authid[MAX_AUTHID_LENGTH];
		GetPlayerAuth(target, authid, charsmax(authid));
		Db_InsertOwned(target, authid, key, 0);
		given++;
	}
	return given;
}

// 管理员给玩家发放全部投掷物皮肤 (永久)
GiveAllNadesTo(target) {
	new given, key[SKIN_KEY_MAX];
	for (new i = 0; i < g_iNadeSize; i++) {
		new row[nade_e];
		ArrayGetArray(g_pNade, i, row, sizeof row);
		NadeOwnedKey(row[nade_key], key, charsmax(key));
		if (HasSkin(target, key))
			continue;

		if (!g_Owned[target])
			g_Owned[target] = ArrayCreate(SKIN_KEY_MAX);
		if (!g_OwnedExpire[target])
			g_OwnedExpire[target] = TrieCreate();

		ArrayPushString(g_Owned[target], key);
		TrieSetCell(g_OwnedExpire[target], key, 0);

		new authid[MAX_AUTHID_LENGTH];
		GetPlayerAuth(target, authid, charsmax(authid));
		Db_InsertOwned(target, authid, key, 0);
		given++;
	}
	return given;
}

ClearAllSkinsFrom(target) {
	if (!g_Owned[target] || ArraySize(g_Owned[target]) <= 0)
		return 0;

	new Array:tmp = ArrayCreate(SKIN_KEY_MAX);
	new count = ArraySize(g_Owned[target]);
	for (new i = 0; i < count; i++) {
		new key[SKIN_KEY_MAX];
		ArrayGetString(g_Owned[target], i, key, charsmax(key));
		ArrayPushString(tmp, key);
	}

	new removed = ArraySize(tmp);
	for (new i = 0; i < removed; i++) {
		new key[SKIN_KEY_MAX];
		ArrayGetString(tmp, i, key, charsmax(key));
		RemoveSkinFrom(target, key);
	}
	ArrayDestroy(tmp);
	return removed;
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
	GetPlayerAuth(target, authid, charsmax(authid));
	Db_RemoveOwned(target, authid, key);

	if (g_pendingAdmin[target] && is_user_connected(g_pendingAdmin[target]))
		SkinChat(g_pendingAdmin[target], print_team_default, "SKIN_CHAT_REMOVED", "已移除 %n 的皮肤 ^3%s", target, key);
}

/* ============================================================
   菜单构建 (非 public, 直接调用)
   ============================================================ */
CountTeamSkins(teamChar) {
	new n;
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (row[pool_team] == teamChar)
			n++;
	}
	return n;
}

CountKnifeSkins() {
	return crxknives_get_knives_num();
}

CountNadeSkins() {
	return g_iNadeSize;
}

MenuSkin(id, page = 0) {
	if (!is_user_connected(id))
		return;

	new iGold = hns_gc_get_player(id);
	new iCt = CountTeamSkins(TEAM_CHAR_C);
	new iTt = CountTeamSkins(TEAM_CHAR_T);
	new iChar = iCt + iTt;
	new iKnife = CountKnifeSkins();
	new iNade = CountNadeSkins();
	new szTitle[160], szItem[96];
	SkinLangF(id, "SKIN_MENU_TITLE", "\y皮肤商店^n\w金币: \y%d",
		szTitle, charsmax(szTitle), iGold);
	new menu = menu_create(szTitle, "SkinHandler");

	SkinLangF(id, "SKIN_MENU_CHAR", "人物皮肤商店  \r[%d]", szItem, charsmax(szItem), iChar);
	menu_additem(menu, szItem, "char");
	SkinLangF(id, "SKIN_MENU_KNIFE", "刀模商店  \r[%d]", szItem, charsmax(szItem), iKnife);
	menu_additem(menu, szItem, "knife");
	SkinLangF(id, "SKIN_MENU_NADE", "投掷物商店  \r[%d]", szItem, charsmax(szItem), iNade);
	menu_additem(menu, szItem, "nade");
	menu_addblank(menu, 0);
	SkinLangF(id, "SKIN_MENU_GOLD", "GBIC点数  \r[%d]", szItem, charsmax(szItem), iGold);
	menu_additem(menu, szItem, "gold");
	if (HasCheckedInToday(id))
		SkinLangF(id, "SKIN_MENU_CHECKIN_DONE", "每日签到  \d[已签到 +%d]", szItem, charsmax(szItem), g_iCheckinBonus);
	else
		SkinLangF(id, "SKIN_MENU_CHECKIN", "每日签到  \y[+%d GBIC]", szItem, charsmax(szItem), g_iCheckinBonus);
	menu_additem(menu, szItem, "checkin");
	SkinLang(id, "SKIN_MENU_BUY", szItem, charsmax(szItem), "购买点数");
	menu_additem(menu, szItem, "buy");
	menu_addblank(menu, 0);
	SkinLang(id, "SKIN_MENU_SQL", szItem, charsmax(szItem), "\yMySQL管理");
	menu_additem(menu, szItem, "sql");
	SkinLang(id, "SKIN_MENU_ADMIN", szItem, charsmax(szItem), "\r管理员设置");
	menu_additem(menu, szItem, "admin");

	SkinMenuStyle(id, menu);
	menu_display(id, menu, page);
}

MenuCharShop(id) {
	new szTitle[128], szItem[96];
	new iCt = CountTeamSkins(TEAM_CHAR_C);
	new iTt = CountTeamSkins(TEAM_CHAR_T);
	SkinLangF(id, "SKIN_CHAR_TITLE", "\y人物皮肤商店  \r[%d]",
		szTitle, charsmax(szTitle), iCt + iTt);
	new menu = menu_create(szTitle, "CharShopHandler");
	SkinLangF(id, "SKIN_MENU_CT", "CT皮肤  \r[%d]", szItem, charsmax(szItem), iCt);
	menu_additem(menu, szItem, "ct");
	SkinLangF(id, "SKIN_MENU_TT", "TT皮肤  \r[%d]", szItem, charsmax(szItem), iTt);
	menu_additem(menu, szItem, "tt");
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuBrowseSkins(id, teamChar, page = 0) {
	if (!is_user_connected(id))
		return;

	g_iBrowseTeam[id] = teamChar;
	g_iBrowsePage[id] = page;

	new szTeam[32], szNone[32], szTitle[160];
	SkinTeamName(id, teamChar, szTeam, charsmax(szTeam));
	SkinLang(id, "SKIN_NONE", szNone, charsmax(szNone), "无");
	new cur[SKIN_KEY_MAX];
	CurSlot(id, cur, charsmax(cur), teamChar);
	SkinLangF(id, "SKIN_BROWSE_TITLE", "\y%s皮肤^n\w金币: \y%d  \w当前: \y%s",
		szTitle, charsmax(szTitle), szTeam, hns_gc_get_player(id), cur[0] ? cur : szNone);
	new menu = menu_create(szTitle, "BrowseHandler");

	new szInfo[12], szTxt[160], added;
	for (new i = 0; i < g_iPoolSize; i++) {
		if (!IsAllowed(id, i))
			continue;

		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (row[pool_team] != teamChar)
			continue;

		FormatShopItem(id, szTxt, charsmax(szTxt), row[pool_key], IsSkinValid(id, row[pool_key]), row[pool_price], equal(cur, row[pool_key]) != 0);
		if (!row[pool_precache])
			format(szTxt, charsmax(szTxt), "%s  \r[当前不可用]", szTxt);

		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}

	if (!added) {
		SkinLang(id, "SKIN_BROWSE_EMPTY", szTxt, charsmax(szTxt), "  (当前阵营没有可用皮肤)");
		menu_additem(menu, szTxt, "none");
	}

	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, page);
}

MenuBuyGold(id) {
	new szTitle[64], szItem[160];
	SkinLang(id, "SKIN_BUY_GOLD_TITLE", szTitle, charsmax(szTitle), "\y购买点数");
	new menu = menu_create(szTitle, "BuyGoldHandler");
	if (g_szBuyGoldText[0])
		copy(szItem, charsmax(szItem), g_szBuyGoldText);
	else
		SkinLang(id, "SKIN_BUY_GOLD_TEXT", szItem, charsmax(szItem), "请联系管理员购买 GBIC 点数");
	menu_additem(menu, szItem, "info");
	if (g_szBuyGoldUrl[0]) {
		SkinLang(id, "SKIN_BUY_GOLD_OPEN", szItem, charsmax(szItem), "打开购买页面");
		menu_additem(menu, szItem, "open");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuGold(id) {
	new iGold = hns_gc_get_player(id);
	new szTitle[192], szItem[96];
	new iRemain = GetPlayRemain(id);
	if (iRemain < 0)
		iRemain = 0;
	new iMin = iRemain / 60;
	new iSec = iRemain % 60;
	SkinLangF(id, "SKIN_GOLD_TITLE", "\yGBIC金币 \w· \y账户^n\w余额: \y%d  \w租期: \y%d天^n\w升级永久: \y%d 金币^n\w在线奖励: \y%d分%d秒 \w后 +%d",
		szTitle, charsmax(szTitle), iGold, g_iRentDays, g_iUpgradePrice, iMin, iSec, g_iPlaytimeBonus);
	new menu = menu_create(szTitle, "GoldHandler");
	if (HasCheckedInToday(id))
		SkinLangF(id, "SKIN_GOLD_CHECKIN_DONE", "每日签到  \d[今天已领 +%d]", szItem, charsmax(szItem), g_iCheckinBonus);
	else
		SkinLangF(id, "SKIN_GOLD_CHECKIN", "每日签到  \y[+%d GBIC]", szItem, charsmax(szItem), g_iCheckinBonus);
	menu_additem(menu, szItem, "checkin");
	SkinLangF(id, "SKIN_GOLD_UP", "升级已购皮肤为永久 (%d金币)", szItem, charsmax(szItem), g_iUpgradePrice);
	menu_additem(menu, szItem, "up");
	SkinLang(id, "SKIN_GOLD_REFRESH", szItem, charsmax(szItem), "刷新余额");
	menu_additem(menu, szItem, "refresh");
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuSqlDebug(id) {
	if (!IsSkinSqlAdmin(id)) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有 SQL 调试权限");
		MenuSkin(id);
		return;
	}
	new szHost[64], szAuth[MAX_AUTHID_LENGTH], szStatus[64], szTitle[256], szItem[160];
	copy(szHost, charsmax(szHost), g_eDb[db_host]);
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	SkinSqlStatusText(id, szStatus, charsmax(szStatus));
	SkinLangF(id, "SKIN_SQL_TITLE", "\yMySQL连接与调试^n\w状态: %s%s^n\w主机: \y%s  \w库: \y%s^n\w你的账号: \y%s^n\w皮肤池: \y%d  \w拥有记录: \y%d  \w当前选用: \y%d",
		szTitle, charsmax(szTitle),
		g_bSqlReady ? "\y" : "\r", szStatus,
		szHost, g_eDb[db_db], szAuth,
		g_iPoolSize, g_iSqlOwnedCount, g_iSqlCurrentCount);
	new menu = menu_create(szTitle, "SqlMenuHandler");

	SkinLang(id, "SKIN_SQL_PING", szItem, charsmax(szItem), "测试连接");
	menu_additem(menu, szItem, "ping");
	SkinLang(id, "SKIN_SQL_COUNT", szItem, charsmax(szItem), "查询我的皮肤记录");
	menu_additem(menu, szItem, "count");
	SkinLang(id, "SKIN_SQL_SYNC", szItem, charsmax(szItem), "重新同步皮肤目录");
	menu_additem(menu, szItem, "sync");
	SkinLang(id, "SKIN_SQL_RELOAD", szItem, charsmax(szItem), "重新读取配置并重连");
	menu_additem(menu, szItem, "reload");
	if (g_szSqlLastErr[0]) {
		SkinLangF(id, "SKIN_SQL_ERR", "\r最近错误(%d): %s", szItem, charsmax(szItem), g_iSqlLastErr, g_szSqlLastErr);
		menu_additem(menu, szItem, "err");
	} else {
		SkinLang(id, "SKIN_SQL_ERR_NONE", szItem, charsmax(szItem), "\d最近错误: 无");
		menu_additem(menu, szItem, "err");
	}

	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

SqlPing(id) {
	if (g_hSqlTuple == Empty_Handle) {
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_NONE", "未配置 MySQL");
		MenuSqlDebug(id);
		return;
	}
	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_SQL_PING, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler", "SELECT 1", cData, sizeof(cData));
	SkinChat(id, print_team_default, "SKIN_CHAT_SQL_PING", "正在测试 MySQL 连接...");
}

SqlCountMine(id) {
	if (g_hSqlTuple == Empty_Handle) {
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "none");
		SkinChat(id, print_team_red, "SKIN_CHAT_SQL_NONE", "未配置 MySQL");
		MenuSqlDebug(id);
		return;
	}
	new szAuth[MAX_AUTHID_LENGTH], szEsc[MAX_AUTHID_LENGTH * 2];
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	EscapeSql(szAuth, szEsc, charsmax(szEsc));
	new cData[4 + MAX_AUTHID_LENGTH];
	PackQueryData(cData, QT_SQL_COUNT, id);
	SQL_ThreadQuery(g_hSqlTuple, "SqlHandler",
		fmt("SELECT (SELECT COUNT(*) FROM %s WHERE authid='%s'), (SELECT COUNT(*) FROM %s WHERE authid='%s')",
			OWNS_TABLE, szEsc, CUR_TABLE, szEsc),
		cData, sizeof(cData));
	SkinChat(id, print_team_default, "SKIN_CHAT_SQL_COUNTING", "正在查询记录  账号: ^3%s", szAuth);
}

SqlReload(id) {
	if (g_hSqlTuple) {
		SQL_FreeHandle(g_hSqlTuple);
		g_hSqlTuple = Empty_Handle;
	}
	LoadDbCfg();
	g_hSqlTuple = SQL_MakeDbTuple(g_eDb[db_host], g_eDb[db_user], g_eDb[db_pass], g_eDb[db_db]);
	SQL_SetCharset(g_hSqlTuple, "utf8");
	copy(g_szSqlStatus, charsmax(g_szSqlStatus), "reconnect");
	DbSyncCatalog();
	new szStatus[64];
	SkinSqlStatusText(id, szStatus, charsmax(szStatus));
	SkinChat(id, print_team_default, "SKIN_CHAT_SQL_RELOADED", "已重新读取配置并同步  状态: %s", szStatus);
	MenuSqlDebug(id);
}

MenuConfirmBuy(id, idx, page = 0) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);

	g_iBrowsePage[id] = page;
	if (row[pool_price] == 0) {
		DoBuy(id, idx);
		return;
	}

	new szRent[32], szTitle[160], szItem[96];
	if (g_iRentDays > 0)
		SkinLangF(id, "SKIN_DAYS", "%d天", szRent, charsmax(szRent), g_iRentDays);
	else
		SkinLang(id, "SKIN_PERM", szRent, charsmax(szRent), "永久");
	SkinLangF(id, "SKIN_BUY_TITLE", "\y确认购买^n\w皮肤: \y%s^n\w价格: \y%d 金币  \w租期: \y%s",
		szTitle, charsmax(szTitle), row[pool_key], row[pool_price], szRent);
	new menu = menu_create(szTitle, "ConfirmHandler");
	new szInfo[12];
	num_to_str(idx, szInfo, charsmax(szInfo));
	SkinLangF(id, "SKIN_BUY_OK", "确认购买  \r-%d", szItem, charsmax(szItem), row[pool_price]);
	menu_additem(menu, szItem, szInfo);
	SkinLang(id, "SKIN_CANCEL", szItem, charsmax(szItem), "取消");
	menu_additem(menu, szItem, "cancel");
	SkinMenuStyle(id, menu);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

MenuUpgrade(id) {
	new szTitle[128], szLeft[48];
	SkinLangF(id, "SKIN_UP_TITLE", "\y升级永久皮肤^n\w每款 \y%d 金币  \w余额: \y%d",
		szTitle, charsmax(szTitle), g_iUpgradePrice, hns_gc_get_player(id));
	new menu = menu_create(szTitle, "UpgradeHandler");
	new szInfo[12], szTxt[160], added;
	SkinLang(id, "SKIN_ITEM_LEFT", szLeft, charsmax(szLeft), "%s  \y[剩%d天]");
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		new exp = SkinExpire(id, row[pool_key]);
		if (exp <= 0 || exp <= get_systime())
			continue;
		format(szTxt, charsmax(szTxt), szLeft, row[pool_key], DaysLeft(id, row[pool_key]));
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}
	if (!added) {
		SkinLang(id, "SKIN_UP_EMPTY", szTxt, charsmax(szTxt), "\d(没有正在租期中的皮肤)");
		menu_additem(menu, szTxt, "none");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuConfirmUpgrade(id, idx) {
	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	new szTitle[160], szItem[96];
	SkinLangF(id, "SKIN_UP_CONFIRM", "\y升级为永久?^n\w皮肤: \y%s^n\w花费: \y%d 金币",
		szTitle, charsmax(szTitle), row[pool_key], g_iUpgradePrice);
	new menu = menu_create(szTitle, "UpgradeConfirmHandler");
	new szInfo[12];
	num_to_str(idx, szInfo, charsmax(szInfo));
	SkinLangF(id, "SKIN_UP_OK", "确认升级  \r-%d", szItem, charsmax(szItem), g_iUpgradePrice);
	menu_additem(menu, szItem, szInfo);
	SkinLang(id, "SKIN_CANCEL", szItem, charsmax(szItem), "取消");
	menu_additem(menu, szItem, "cancel");
	SkinMenuStyle(id, menu);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, 0);
}

MenuAdmin(id) {
	if (!IsSkinAdmin(id)) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有管理权限");
		MenuSkin(id);
		return;
	}

	new szTitle[64], szItem[64];
	SkinLang(id, "SKIN_ADMIN_TITLE", szTitle, charsmax(szTitle), "\y管理员设置 \w· \r皮肤");
	new menu = menu_create(szTitle, "AdminHandler");
	// 发放与批量发放放在最前面, 其余管理功能保持可用。
	if (IsSkinOwner(id)) {
		SkinLang(id, "SKIN_ADMIN_GIVE", szItem, charsmax(szItem), "给玩家发放皮肤");
		menu_additem(menu, szItem, "1");
		SkinLang(id, "SKIN_ADMIN_GIVEALL", szItem, charsmax(szItem), "发放全部皮肤给玩家");
		menu_additem(menu, szItem, "2");
		SkinLang(id, "SKIN_ADMIN_REMOVE", szItem, charsmax(szItem), "移除玩家皮肤");
		menu_additem(menu, szItem, "3");
		SkinLang(id, "SKIN_ADMIN_POOL", szItem, charsmax(szItem), "查看皮肤池");
		menu_additem(menu, szItem, "4");
		SkinLang(id, "SKIN_ADMIN_OWNED", szItem, charsmax(szItem), "查看玩家已拥有皮肤");
		menu_additem(menu, szItem, "5");
		SkinLang(id, "SKIN_ADMIN_GIVEALL_KNIFE", szItem, charsmax(szItem), "发放全部刀皮给玩家");
		menu_additem(menu, szItem, "6");
		SkinLang(id, "SKIN_ADMIN_GIVEALL_NADE", szItem, charsmax(szItem), "发放全部投掷物皮肤给玩家");
		menu_additem(menu, szItem, "7");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuPoolList(id) {
	if (g_iPoolSize == 0) {
		SkinChat(id, print_team_red, "SKIN_CHAT_POOL_EMPTY", "皮肤池为空");
		return;
	}

	new szTitle[64], szTeam[16];
	SkinLangF(id, "SKIN_POOL_TITLE", "\y皮肤池  \w共 \r%d \w款", szTitle, charsmax(szTitle), g_iPoolSize);
	new menu = menu_create(szTitle, "PoolListHandler");
	new szInfo[12], szTxt[160];
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		SkinTeamName(id, row[pool_team], szTeam, charsmax(szTeam));
		format(szTxt, charsmax(szTxt), "\y[%s]\w %s  \y[%d]", szTeam, row[pool_key], row[pool_price]);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuPickPlayer(const mode[], id) {
	copy(g_pendingMode[id], 7, mode);
	g_pendingAdmin[id] = id;
	if (!IsSkinOwner(id)) {
		if (g_pendingMode[id][0] == 'v')
			MenuViewOwned(id, id);
		else if (g_pendingMode[id][0] == 'g')
			MenuGiveSkin(id, id);
		else if (g_pendingMode[id][0] == 'a')
			GiveAllSkinsTo(id, 0);
		else if (g_pendingMode[id][0] == 'k') {
			GiveAllKnivesTo(id);
			MenuAdmin(id);
		} else if (g_pendingMode[id][0] == 'n') {
			GiveAllNadesTo(id);
			MenuAdmin(id);
		} else
			MenuRemoveSkin(id, id);
		return;
	}

	new szTitle[64];
	if (g_pendingMode[id][0] == 'v')
		SkinLang(id, "SKIN_PICK_VIEW", szTitle, charsmax(szTitle), "\y选择玩家 \w· 查看拥有");
	else if (g_pendingMode[id][0] == 'g')
		SkinLang(id, "SKIN_PICK_GIVE", szTitle, charsmax(szTitle), "\y选择玩家 \w· 发放皮肤");
	else if (g_pendingMode[id][0] == 'a')
		SkinLang(id, "SKIN_PICK_ALL", szTitle, charsmax(szTitle), "\y选择玩家 \w· 发放全部");
	else if (g_pendingMode[id][0] == 'k')
		SkinLang(id, "SKIN_PICK_KNIVES", szTitle, charsmax(szTitle), "\y选择玩家 \w· 发放全部刀皮");
	else if (g_pendingMode[id][0] == 'n')
		SkinLang(id, "SKIN_PICK_NADES", szTitle, charsmax(szTitle), "\y选择玩家 \w· 发放全部投掷物皮肤");
	else
		SkinLang(id, "SKIN_PICK_REMOVE", szTitle, charsmax(szTitle), "\y选择玩家 \w· 移除皮肤");

	new menu = menu_create(szTitle, "PickPlayerHandler");
	new szTxt[80], added;
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i) || is_user_hltv(i))
			continue;
		new szName[32], szAuth[MAX_AUTHID_LENGTH];
		get_user_name(i, szName, charsmax(szName));
		GetPlayerAuth(i, szAuth, charsmax(szAuth));
		format(szTxt, charsmax(szTxt), "%s  \y[%s]", szName, szAuth);
		menu_additem(menu, szTxt, fmt("%d", i));
		added++;
	}
	if (!added) {
		SkinLang(id, "SKIN_PICK_EMPTY", szTxt, charsmax(szTxt), "\d(当前没有在线玩家)");
		menu_additem(menu, szTxt, "none");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuViewOwned(id, target) {
	g_pendingTarget[id] = target;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new teamChar = CharOfTeam(get_member(target, m_iTeam));
	new szTeam[16], szTitle[96], szTxt[128], szSel[32], szPerm[24], szExp[24], szLeft[32];
	SkinTeamShort(id, teamChar, szTeam, charsmax(szTeam));
	SkinLangF(id, "SKIN_VIEW_TITLE", " %s 拥有的皮肤 (当前%s)", szTitle, charsmax(szTitle), szName, szTeam);
	new menu = menu_create(szTitle, "ViewOwnedHandler");
	SkinLang(id, "SKIN_TAG_SELECTED", szSel, charsmax(szSel), "  \r[已选择]");
	SkinLang(id, "SKIN_TAG_PERM", szPerm, charsmax(szPerm), "  [永久]");
	SkinLang(id, "SKIN_TAG_EXPIRED", szExp, charsmax(szExp), "  [已过期]");
	SkinLang(id, "SKIN_TAG_LEFT", szLeft, charsmax(szLeft), "  [剩%d天]");
	if (g_Owned[target] && ArraySize(g_Owned[target]) > 0) {
		for (new i = 0; i < ArraySize(g_Owned[target]); i++) {
			new key[SKIN_KEY_MAX];
			ArrayGetString(g_Owned[target], i, key, charsmax(key));
			new idx = PoolIndexOf(key);
			new exp = SkinExpire(target, key);
			new szStat[24], szTeamTag[16];
			if (exp == 0)
				copy(szStat, charsmax(szStat), szPerm);
			else if (exp > get_systime())
				format(szStat, charsmax(szStat), szLeft, DaysLeft(target, key));
			else
				copy(szStat, charsmax(szStat), szExp);
			if (idx != -1)
				SkinTeamName(id, PoolTeamChar(idx), szTeamTag, charsmax(szTeamTag));
			else
				copy(szTeamTag, charsmax(szTeamTag), "?");
			format(szTxt, charsmax(szTxt), "\y[%s]\w %s%s%s",
				szTeamTag, key, szStat,
				cur_match(target, key, teamChar) ? szSel : "");
			menu_additem(menu, szTxt);
		}
	} else {
		SkinLang(id, "SKIN_VIEW_EMPTY", szTxt, charsmax(szTxt), "\d(该玩家没有皮肤)");
		menu_additem(menu, szTxt);
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

bool:cur_match(target, const key[], teamChar) {
	new cur[SKIN_KEY_MAX];
	CurSlot(target, cur, charsmax(cur), teamChar);
	return cur[0] && equal(cur, key);
}

MenuGiveSkin(id, target) {
	g_pendingTarget[id] = target;
	g_pendingAdmin[id] = id;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new szTeam[16], szTitle[96];
	SkinTeamShort(id, g_pendingGiveTeam[id], szTeam, charsmax(szTeam));
	SkinLangF(id, "SKIN_GIVE_TITLE", "\y发放皮肤 \w· %s^n\w范围: \y%s", szTitle, charsmax(szTitle), szName, szTeam);
	new menu = menu_create(szTitle, "GiveSkinHandler");
	new szInfo[12], szTxt[160], added;

	// 1. 阵营角色皮肤 (info = 纯索引数字)
	for (new i = 0; i < g_iPoolSize; i++) {
		new row[pool_e];
		ArrayGetArray(g_pPool, i, row, sizeof row);
		if (g_pendingGiveTeam[id] && row[pool_team] != g_pendingGiveTeam[id])
			continue;
		format(szTxt, charsmax(szTxt), "\w%s", row[pool_key]);
		num_to_str(i, szInfo, charsmax(szInfo));
		menu_additem(menu, szTxt, szInfo);
		added++;
	}

	// 2. 刀皮模型 (info 前缀 "k", 永不受阵营/范围限制)
	for (new knife = 0; knife < crxknives_get_knives_num(); knife++) {
		new kname[MAX_NAME_LENGTH], kprice;
		KnifeInfo(knife, kname, charsmax(kname), kprice);
		SkinLangF(id, "SKIN_GIVE_TAG_KNIFE", "\w[刀] %s", szTxt, charsmax(szTxt), kname);
		formatex(szInfo, charsmax(szInfo), "k%d", knife);
		menu_additem(menu, szTxt, szInfo);
		added++;
	}

	// 3. 投掷物皮肤 (info 前缀 "n")
	for (new i = 0; i < g_iNadeSize; i++) {
		new row[nade_e];
		ArrayGetArray(g_pNade, i, row, sizeof row);
		SkinLangF(id, "SKIN_GIVE_TAG_NADE", "\w[投掷物] %s", szTxt, charsmax(szTxt), row[nade_key]);
		formatex(szInfo, charsmax(szInfo), "n%d", i);
		menu_additem(menu, szTxt, szInfo);
		added++;
	}

	if (!added) {
		SkinLang(id, "SKIN_GIVE_EMPTY", szTxt, charsmax(szTxt), "\d(没有可发放的皮肤)");
		menu_additem(menu, szTxt, "none");
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
	menu_display(id, menu, 0);
}

MenuRemoveSkin(id, target) {
	g_pendingTarget[id] = target;
	g_pendingAdmin[id] = id;
	new szName[33]; get_user_name(target, szName, charsmax(szName));
	new szTitle[96], szTxt[128], szTeamTag[16];
	SkinLangF(id, "SKIN_REMOVE_TITLE", " 移除 %s 的皮肤", szTitle, charsmax(szTitle), szName);
	new menu = menu_create(szTitle, "RemoveSkinHandler");
	if (g_Owned[target] && ArraySize(g_Owned[target]) > 0) {
		for (new i = 0; i < ArraySize(g_Owned[target]); i++) {
			new key[SKIN_KEY_MAX];
			ArrayGetString(g_Owned[target], i, key, charsmax(key));
			new idx = PoolIndexOf(key);
			if (idx != -1)
				SkinTeamShort(id, PoolTeamChar(idx), szTeamTag, charsmax(szTeamTag));
			else
				copy(szTeamTag, charsmax(szTeamTag), "?");
			format(szTxt, charsmax(szTxt), "[%s] %s", szTeamTag, key);
			menu_additem(menu, szTxt, key);
		}
	} else {
		SkinLang(id, "SKIN_VIEW_EMPTY", szTxt, charsmax(szTxt), "\d(该玩家没有皮肤)");
		menu_additem(menu, szTxt);
	}
	SkinMenuStyle(id, menu);
	SkinMenuReturn(id, menu);
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
	g_pPool = ArrayCreate(pool_e);
	g_pPoolIndex = TrieCreate();
	g_pNade = ArrayCreate(nade_e);

	// 换图只读 skins.cfg / nade_skins.cfg / knife_skins.cfg 并预缓存模型, 不连 MySQL, 避免卡住 changelevel
	DbPrecachePool();
	LoadNadeCfg();
	LoadKnifeCfg();
}

public plugin_init() {
	register_plugin("HNS Match Skin", "1.0.0", "OpenHNS");

	// crx 在 plugin_cfg 里缓存 km_select_message, 必须在它之前关掉英文选刀提示
	MuteCrxKnifeSelectMessage();

	for (new i = 0; i < sizeof(g_szClcmds); i++)
		register_clcmd(g_szClcmds[i], "Cl_Cmd");
	register_clcmd("say /sign", "CmdCheckin");
	register_clcmd("say_team /sign", "CmdCheckin");
	register_clcmd("say /qd", "CmdCheckin");
	register_clcmd("say_team /qd", "CmdCheckin");
	register_clcmd("say /checkin", "CmdCheckin");
	register_clcmd("say_team /checkin", "CmdCheckin");
	register_clcmd("say /签到", "CmdCheckin");
	register_clcmd("say_team /签到", "CmdCheckin");

	LoadDbCfg();
	g_tAuthByIp = TrieCreate();
	g_hSqlTuple = SQL_MakeDbTuple(g_eDb[db_host], g_eDb[db_user], g_eDb[db_pass], g_eDb[db_db]);
	SQL_SetCharset(g_hSqlTuple, "utf8");

	// 建表/导入目录放到后台, 不卡住 changelevel
	set_task(0.1, "TaskSyncCatalog");

	// 换队/进服时按当前阵营自动应用对应款式
	register_forward(FM_PlayerPreThink, "fwd_PlayerPreThink");

	// 拦截原版死亡音效, 换成皮肤音效 (否则会叠在一起)
	register_forward(FM_EmitSound, "fwdEmitSoundDeath", 0);

	// 投掷物皮肤: 换掉出厂的烟雾/闪光模型
	register_forward(FM_SetModel, "fw_SetModel", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "OnNadeDeployPre", false);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "OnNadeDeployPost", true);
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawnPost", true);
	if (g_iVaultReward == INVALID_HANDLE)
		g_iVaultReward = nvault_open("hns_skin_reward");
}

public TaskSyncCatalog() {
	DbSyncCatalog(false);
}

public plugin_cfg() {
	MuteCrxKnifeSelectMessage();
	if (g_iVaultReward == INVALID_HANDLE)
		g_iVaultReward = nvault_open("hns_skin_reward");
}

MuteCrxKnifeSelectMessage() {
	set_cvar_num("km_select_message", 0);
	new pCvar = get_cvar_pointer("km_select_message");
	if (pCvar)
		set_pcvar_num(pCvar, 0);
}

public plugin_end() {
	if (g_pPool) { ArrayDestroy(g_pPool); g_pPool = Empty_Handle; }
	if (g_pPoolIndex) { TrieDestroy(g_pPoolIndex); g_pPoolIndex = Invalid_Trie; }
	if (g_tAuthByIp) { TrieDestroy(g_tAuthByIp); g_tAuthByIp = Invalid_Trie; }
	if (g_pNade) { ArrayDestroy(g_pNade); g_pNade = Empty_Handle; }
	if (g_iVaultReward != INVALID_HANDLE) {
		nvault_close(g_iVaultReward);
		g_iVaultReward = INVALID_HANDLE;
	}
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

bool:IsDefaultDeathSound(const sample[]) {
	if (!sample[0])
		return false;
	if (equali(sample, "player/die1.wav")
		|| equali(sample, "player/die2.wav")
		|| equali(sample, "player/die3.wav")
		|| equali(sample, "player/death6.wav")
		|| equali(sample, "player/pl_die1.wav"))
		return true;
	if (containi(sample, "player/die") == 0)
		return true;
	if (containi(sample, "player/death") == 0)
		return true;
	return false;
}

bool:GetSkinDeathSound(id, dest[], iLen) {
	dest[0] = EOS;
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return false;

	new teamChar = CharOfTeam(get_member(id, m_iTeam));
	new key[SKIN_KEY_MAX];
	CurSlot(id, key, charsmax(key), teamChar);
	if (!key[0])
		return false;

	new idx = PoolIndexOf(key);
	if (idx == -1)
		return false;

	new row[pool_e];
	ArrayGetArray(g_pPool, idx, row, sizeof row);
	PickDeathSound(row[pool_snd], dest, iLen);
	return dest[0] != EOS;
}

/* 玩家死亡: 挡住原版 die/death 音效, 改播当前皮肤音效 */
public fwdEmitSoundDeath(id, iChannel, szSample[], Float:volume, Float:attenuation, fFlags, pitch) {
	if (g_bPlayingDeathSnd)
		return FMRES_IGNORED;
	if (id < 1 || id > MaxClients)
		return FMRES_IGNORED;
	if (!IsDefaultDeathSound(szSample))
		return FMRES_IGNORED;

	new szSnd[DEATH_SND_PATH];
	if (!GetSkinDeathSound(id, szSnd, charsmax(szSnd)))
		return FMRES_IGNORED;

	g_bPlayingDeathSnd = true;
	emit_sound(id, iChannel, szSnd, volume, attenuation, fFlags, pitch);
	g_bPlayingDeathSnd = false;
	return FMRES_SUPERCEDE;
}

/* 检测队伍变化(含进场), 自动把当前阵营的款应用上去 */
public fwd_PlayerPreThink(id) {
	if (!is_user_alive(id))
		return FMRES_IGNORED;

	new team = get_member(id, m_iTeam);
	if (team != TEAM_TERRORIST && team != TEAM_CT)
		return FMRES_IGNORED;

	new t = CharOfTeam(team);
	new key[SKIN_KEY_MAX];
	CurSlot(id, key, charsmax(key), t);

	// 当前槽里想要显示的款: 有效的皮肤才应用, 否则视为空(原皮)
	// 本图未预缓存的款式 (超过上限被跳过) 也不应用
	new bool:bWantCustom = (key[0] && PoolIndexOf(key) != -1 && IsSkinValid(id, key) && IsSkinPrecached(key));
	if (!bWantCustom)
		key[0] = EOS;

	// 队伍没变 且 已应用的款和当前槽一致 => 无需重复动作
	// (异步DB加载晚了 / 换图 / 复活都会因为这里的差集被补上)
	if (g_iLastTeam[id] == t && g_szAppliedTeam[id] == t && equal(g_szAppliedKey[id], key))
		return FMRES_IGNORED;

	g_iLastTeam[id] = t;

	if (bWantCustom)
		custom_player_models_set(id, key);
	else
		custom_player_models_reset(id);
	MarkAppliedSkin(id, t, key);

	return FMRES_IGNORED;
}

public client_authorized(id) {
	if (!g_hSqlTuple || is_user_bot(id) || is_user_hltv(id))
		return;
	TryLoadOwned(id);
}

public client_putinserver(id) {
	// 进服/换图: 清掉上一次的"已应用"记录, 保证稍后按DB里的当前槽重新贴模型
	g_iLastTeam[id] = 0;
	g_szAppliedTeam[id] = 0;
	g_szAppliedKey[id][0] = EOS;
	StartPlaytimeTrack(id);

	if (!g_hSqlTuple || is_user_bot(id) || is_user_hltv(id))
		return;
	TryLoadOwned(id);
}

TryLoadOwned(id) {
	if (!is_user_connected(id) || !g_hSqlTuple || is_user_bot(id) || is_user_hltv(id))
		return;

	new szLive[MAX_AUTHID_LENGTH], szCached[MAX_AUTHID_LENGTH];
	get_user_authid(id, szLive, charsmax(szLive));
	LookupAuthByIp(id, szCached, charsmax(szCached));
	if (IsPendingAuth(szLive) && !IsSteamAuth(g_szAuth[id]) && !IsSteamAuth(szCached) && g_iAuthRetry[id] < 15) {
		ScheduleAuthRetry(id);
		return;
	}

	new szOld[MAX_AUTHID_LENGTH], szAuth[MAX_AUTHID_LENGTH];
	copy(szOld, charsmax(szOld), g_szAuth[id]);
	GetPlayerAuth(id, szAuth, charsmax(szAuth));
	if (!szAuth[0]) {
		ScheduleAuthRetry(id);
		return;
	}

	// SteamID 没变且已经读过库: 只重新贴模型, 不要 ClearOwned
	if (equal(szOld, szAuth) && g_Owned[id] && g_bOwnedLoaded[id]) {
		ApplyCurrentSkin(id);
		ScheduleKnifeReapply(id);
		return;
	}

	remove_task(id + TASK_AUTH_RETRY);
	g_iAuthRetry[id] = 0;
	g_bOwnedLoaded[id] = false;
	g_iLoadGen[id]++;
	copy(g_szAuth[id], charsmax(g_szAuth[]), szAuth);
	Db_LoadOwned(id, szAuth);
}

ScheduleAuthRetry(id) {
	if (!is_user_connected(id))
		return;
	remove_task(id + TASK_AUTH_RETRY);
	if (g_iAuthRetry[id] >= 15)
		return;
	set_task(0.5, "TaskAuthRetry", id + TASK_AUTH_RETRY);
}

public TaskAuthRetry(taskid) {
	new id = taskid - TASK_AUTH_RETRY;
	if (!is_user_connected(id))
		return;

	new szLive[MAX_AUTHID_LENGTH];
	get_user_authid(id, szLive, charsmax(szLive));
	if (IsSteamAuth(szLive)) {
		g_iAuthRetry[id] = 0;
		TryLoadOwned(id);
		return;
	}

	g_iAuthRetry[id]++;
	if (g_iAuthRetry[id] < 15) {
		set_task(0.5, "TaskAuthRetry", taskid);
		return;
	}

	// 一直拿不到 SteamID 才退回 LAN:IP, 避免换图瞬间用空账号把皮肤冲掉
	TryLoadOwned(id);
}

public client_disconnected(id) {
	g_pendingGiveTeam[id] = 0;
	g_pendingTarget[id] = 0;
	g_pendingAdmin[id] = 0;
	g_pendingMode[id][0] = 0;
	g_iBrowseTeam[id] = 0;
	g_legacyPendingAdmin[id] = 0;
	g_iLoadGen[id]++;
	StopPlaytimeTrack(id, true);
	RememberAuthByIp(id, g_szAuth[id]);
	g_szAuth[id][0] = EOS;
	ClearOwned(id);
	g_bOwnedLoaded[id] = false;
	g_iLastTeam[id] = 0;
	g_szAppliedTeam[id] = 0;
	g_szAppliedKey[id][0] = EOS;
	g_CurT[id][0] = EOS;
	g_CurC[id][0] = EOS;
	g_iCurKnife[id] = 0;
	g_NadeSmoke[id][0] = EOS;
	g_NadeFlash[id][0] = EOS;
	g_iKnifePage[id] = 0;
	g_iKnifeRetry[id] = 0;
	g_iAuthRetry[id] = 0;
	g_bApplyingKnife[id] = false;
	g_flShopKeep[id] = 0.0;
	remove_task(id + TASK_REAPPLY_KNIFE);
	remove_task(id + TASK_AUTH_RETRY);
	g_iBrowsePage[id] = 0;
	g_iNadePage[id] = 0;
	g_iNadeKindPage[id] = -1;
	g_iShopMenu[id] = 0;
	g_iShopPage[id] = 0;
	g_iShopKind[id] = -1;
	remove_task(id + TASK_APPLY_NADE);
	remove_task(id + TASK_MENU_SHOP);
	g_iLastCheckin[id] = 0;
	g_iPlayRemain[id] = 0;
	g_flPlayStart[id] = 0.0;
	g_bRewardLoaded[id] = false;
}

RefundGold(id, iPaid) {
	if (iPaid <= 0 || !is_user_connected(id))
		return;
	hns_gc_set_player(id, hns_gc_get_player(id) + iPaid);
	SkinChat(id, print_team_red, "SKIN_CHAT_REFUND", "数据库写入失败, 已退回 ^3%d^1 金币", iPaid);
}

public SqlHandler(failstate, Handle:query, error[], errnum, data[], size, Float:queueTime) {
	new id = data[1];
	new iPaid = data[2];
	new iGen = data[3];
	new szAuth[MAX_AUTHID_LENGTH];
	copy(szAuth, charsmax(szAuth), data[4]);

	if (failstate != TQUERY_SUCCESS) {
		log_amx("[Skin] SQL错误(%d): %s", errnum, error);
		g_bSqlReady = false;
		g_iSqlLastErr = errnum;
		copy(g_szSqlLastErr, charsmax(g_szSqlLastErr), error);
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "query");
		if ((data[0] == QT_BUY_SKIN || data[0] == QT_UPGRADE_SKIN) && SameAuth(id, szAuth) && iGen == g_iLoadGen[id])
			RefundGold(id, iPaid);
		if ((data[0] == QT_SQL_PING || data[0] == QT_SQL_COUNT) && is_user_connected(id)) {
			SkinChat(id, print_team_red, "SKIN_CHAT_SQL_ERR", "MySQL失败(%d): %s", errnum, error);
			MenuSqlDebug(id);
		}
		return PLUGIN_HANDLED;
	}

	if (data[0] == QT_SQL_PING) {
		g_bSqlReady = true;
		g_iSqlLastErr = 0;
		g_szSqlLastErr[0] = EOS;
		copy(g_szSqlStatus, charsmax(g_szSqlStatus), "ok");
		if (is_user_connected(id)) {
			SkinChat(id, print_team_blue, "SKIN_CHAT_SQL_OK", "MySQL 连接正常");
			MenuSqlDebug(id);
		}
		return PLUGIN_HANDLED;
	}

	if (data[0] == QT_SQL_COUNT) {
		g_bSqlReady = true;
		g_iSqlOwnedCount = SQL_ReadResult(query, 0);
		g_iSqlCurrentCount = SQL_ReadResult(query, 1);
		if (is_user_connected(id)) {
			SkinChat(id, print_team_blue, "SKIN_CHAT_SQL_COUNTED", "拥有 %d 条, 当前选用 %d 条", g_iSqlOwnedCount, g_iSqlCurrentCount);
			MenuSqlDebug(id);
		}
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
			g_bOwnedLoaded[id] = true;
			Db_LoadCurrent(id, szAuth);
		}
		case QT_LOAD_CURRENT: {
			g_CurT[id][0] = EOS;
			g_CurC[id][0] = EOS;
			g_NadeSmoke[id][0] = EOS;
			g_NadeFlash[id][0] = EOS;
			g_iCurKnife[id] = 0;
			// 线程查询 FieldNameToNum 常返回 -1, 按 SELECT team, model_key 列序读
			if (SQL_NumColumns(query) >= 2) {
				while (SQL_MoreResults(query)) {
					new szTeam[2];
					SQL_ReadResult(query, 0, szTeam, charsmax(szTeam));
					if (szTeam[0] == TEAM_CHAR_T)
						SQL_ReadResult(query, 1, g_CurT[id], charsmax(g_CurT[]));
					else if (szTeam[0] == TEAM_CHAR_C)
						SQL_ReadResult(query, 1, g_CurC[id], charsmax(g_CurC[]));
					else if (szTeam[0] == 'S')
						SQL_ReadResult(query, 1, g_NadeSmoke[id], charsmax(g_NadeSmoke[]));
					else if (szTeam[0] == 'F')
						SQL_ReadResult(query, 1, g_NadeFlash[id], charsmax(g_NadeFlash[]));
					else if (szTeam[0] == 'K') {
						new szKnifeKey[SKIN_KEY_MAX];
						SQL_ReadResult(query, 1, szKnifeKey, charsmax(szKnifeKey));
						if (containi(szKnifeKey, "knife:") == 0)
							g_iCurKnife[id] = str_to_num(szKnifeKey[6]);
					}
					SQL_NextRow(query);
				}
			}
			ApplyCurrentSkin(id);
			ReapplyKnife(id);
			ScheduleKnifeReapply(id);
			ScheduleHeldNadeApply(id);
		}
	}

	return PLUGIN_HANDLED;
}

public Cl_Cmd(id) {
	new szArg[64];
	read_argv(0, szArg, charsmax(szArg));

	if (containi(szArg, "/cpm") != -1 || containi(szArg, "/giveskin") != -1) {
		if (IsSkinAdmin(id))
			MenuAdmin(id);
		else
			SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有管理权限");
	} else {
		MenuSkin(id);
	}
	return PLUGIN_HANDLED;
}

public SkinHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);

	if (equal(szInfo, "char"))
		MenuCharShop(id);
	else if (equal(szInfo, "knife"))
		MenuKnives(id);
	else if (equal(szInfo, "nade"))
		MenuNades(id);
	else if (equal(szInfo, "gold"))
		MenuGold(id);
	else if (equal(szInfo, "checkin")) {
		DoDailyCheckin(id);
		MenuSkin(id);
	}
	else if (equal(szInfo, "buy"))
		MenuBuyGold(id);
	else if (equal(szInfo, "sql")) {
		if (IsSkinSqlAdmin(id))
			MenuSqlDebug(id);
		else {
			SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有 SQL 调试权限");
			MenuSkin(id);
		}
	} else if (equal(szInfo, "admin")) {
		if (IsSkinAdmin(id))
			MenuAdmin(id);
		else {
			SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有管理权限");
			MenuSkin(id);
		}
	} else
		MenuSkin(id);
	return PLUGIN_HANDLED;
}

public CharShopHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuSkin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (equal(szInfo, "ct"))
		MenuBrowseSkins(id, TEAM_CHAR_C);
	else if (equal(szInfo, "tt"))
		MenuBrowseSkins(id, TEAM_CHAR_T);
	else
		MenuCharShop(id);
	return PLUGIN_HANDLED;
}

public BuyGoldHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuSkin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (equal(szInfo, "open") && g_szBuyGoldUrl[0])
		show_motd(id, g_szBuyGoldUrl, "GBIC");
	else if (g_szBuyGoldText[0])
		SkinChat(id, print_team_default, "SKIN_CHAT_BUY_GOLD", "%s", g_szBuyGoldText);
	else
		SkinChat(id, print_team_default, "SKIN_CHAT_BUY_GOLD", "请联系管理员购买 GBIC 点数");
	MenuBuyGold(id);
	return PLUGIN_HANDLED;
}

RefreshKnifeNames(id, menu) {
	new szItem[160], szName[MAX_NAME_LENGTH], szInfo[12], access, callback, name[2], price;
	new selectedKnife = g_iCurKnife[id] ? g_iCurKnife[id] : crxknives_get_user_knife(id);
	new count = menu_items(menu);
	for (new i = 0; i < count; i++) {
		menu_item_getinfo(menu, i, access, szInfo, charsmax(szInfo), name, charsmax(name), callback);
		if (!szInfo[0] || equal(szInfo, "none"))
			continue;
		new knife = str_to_num(szInfo);
		if (!IsKnifeShopItemValid(knife))
			continue;
		KnifeInfo(knife, szName, charsmax(szName), price);
		FormatShopItem(id, szItem, charsmax(szItem), szName, (knife < g_iKnifeFree || IsKnifeOwned(id, knife)), price, knife == selectedKnife);
		menu_item_setname(menu, i, szItem);
	}
}

public KnifeHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		if (KeepShopMenu(id)) {
			menu_display(id, menu, g_iKnifePage[id]);
			return PLUGIN_HANDLED;
		}
		menu_destroy(menu);
		OpenShopLater(id, SHOP_MENU_SKIN);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	new page = item / SKIN_PER_PAGE;
	g_iKnifePage[id] = page;
	if (!equal(szInfo, "none")) {
		new knife = str_to_num(szInfo);
		if (IsKnifeOwned(id, knife)) {
			SelectKnife(id, knife);
			MarkShopKeep(id);
			RefreshKnifeNames(id, menu);
			menu_display(id, menu, page);
		} else {
			menu_destroy(menu);
			MenuConfirmKnifeBuy(id, knife, page);
		}
	} else {
		MarkShopKeep(id);
		menu_display(id, menu, 0);
	}
	return PLUGIN_HANDLED;
}

public KnifeConfirmHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		OpenShopLater(id, SHOP_MENU_KNIFE, g_iKnifePage[id]);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (!equal(szInfo, "cancel"))
		DoBuyKnife(id, str_to_num(szInfo));
	OpenShopLater(id, SHOP_MENU_KNIFE, g_iKnifePage[id]);
	return PLUGIN_HANDLED;
}

public crxknives_attempt_change(id, knife) {
	if (!IsKnifeShopItemValid(knife))
		return PLUGIN_HANDLED;
	if (!IsKnifeOwned(id, knife)) {
		new name[MAX_NAME_LENGTH], price;
		KnifeInfo(knife, name, charsmax(name), price);
		SkinChat(id, print_team_red, "SKIN_CHAT_KNIFE_NEED", "刀皮 ^3%s^1 尚未购买", name);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public crxknives_knife_updated(id, knife, bool:onconnect) {
	if (!is_user_connected(id) || g_bApplyingKnife[id])
		return;
	if (!g_bOwnedLoaded[id])
		return;

	new saved = g_iCurKnife[id];
	if (saved > 0 && IsKnifeShopItemValid(saved) && IsKnifeOwned(id, saved)) {
		if (knife != saved)
			ForceSelectKnife(id, saved);
		return;
	}

	if (!IsKnifeShopItemValid(knife) || !IsKnifeOwned(id, knife)) {
		if (knife != 0)
			ForceSelectKnife(id, 0);
	}
}

SelectKnife(id, knife) {
	if (!IsKnifeShopItemValid(knife) || !IsKnifeOwned(id, knife))
		return;

	g_iCurKnife[id] = knife;
	ForceSelectKnife(id, knife);

	new authid[MAX_AUTHID_LENGTH], szName[MAX_NAME_LENGTH], price;
	GetPlayerAuth(id, authid, charsmax(authid));
	Db_SaveKnifeCurrent(id, authid, knife);
	KnifeInfo(knife, szName, charsmax(szName), price);
	SkinChat(id, print_team_blue, "SKIN_CHAT_KNIFE_SELECTED", "你已选用刀皮: ^3%s", szName);
	ScheduleKnifeReapply(id);
}

ForceSelectKnife(id, knife) {
	if (!is_user_connected(id))
		return;
	g_bApplyingKnife[id] = true;
	crxknives_select_knife(id, knife);
	g_bApplyingKnife[id] = false;
}

ScheduleKnifeReapply(id) {
	if (!is_user_connected(id))
		return;
	remove_task(id + TASK_REAPPLY_KNIFE);
	g_iKnifeRetry[id] = 0;
	set_task(1.0, "TaskReapplyKnife", id + TASK_REAPPLY_KNIFE);
}

public TaskReapplyKnife(taskid) {
	new id = taskid - TASK_REAPPLY_KNIFE;
	ReapplyKnife(id);
	if (!is_user_connected(id))
		return;
	g_iKnifeRetry[id]++;
	if (g_iKnifeRetry[id] < 5)
		set_task(1.2, "TaskReapplyKnife", taskid);
}

public OnPlayerSpawnPost(id) {
	if (is_user_alive(id)) {
		ReapplyKnife(id);
		ScheduleHeldNadeApply(id);
	}
}

ReapplyKnife(id) {
	if (!g_bOwnedLoaded[id] || !is_user_connected(id))
		return;

	new knife = g_iCurKnife[id];
	if (knife <= 0)
		return;
	if (!IsKnifeShopItemValid(knife) || !IsKnifeOwned(id, knife)) {
		g_iCurKnife[id] = 0;
		ForceSelectKnife(id, 0);
		return;
	}
	if (crxknives_get_user_knife(id) != knife)
		ForceSelectKnife(id, knife);
}

public BrowseHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuCharShop(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	new page = item / SKIN_PER_PAGE;
	menu_destroy(menu);
	if (!equal(szInfo, "none"))
		OnSkinChosen(id, str_to_num(szInfo), page);
	else
		MenuBrowseSkins(id, g_iBrowseTeam[id], page);
	return PLUGIN_HANDLED;
}

public GoldHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuSkin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (equal(szInfo, "checkin")) {
		DoDailyCheckin(id);
		MenuGold(id);
	}
	else if (equal(szInfo, "up"))
		MenuUpgrade(id);
	else
		MenuGold(id);
	return PLUGIN_HANDLED;
}

public SqlMenuHandler(id, menu, item) {
	if (!IsSkinSqlAdmin(id)) {
		menu_destroy(menu);
		MenuSkin(id);
		return PLUGIN_HANDLED;
	}
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuSkin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (equal(szInfo, "ping"))
		SqlPing(id);
	else if (equal(szInfo, "count"))
		SqlCountMine(id);
	else if (equal(szInfo, "sync")) {
		DbSyncCatalog();
		new szStatus[64];
		SkinSqlStatusText(id, szStatus, charsmax(szStatus));
		SkinChat(id, print_team_default, "SKIN_CHAT_SQL_SYNCED", "已同步皮肤目录  状态: %s", szStatus);
		MenuSqlDebug(id);
	} else if (equal(szInfo, "reload"))
		SqlReload(id);
	else
		MenuSqlDebug(id);
	return PLUGIN_HANDLED;
}

public ConfirmHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuBrowseSkins(id, g_iBrowseTeam[id], g_iBrowsePage[id]);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (str_to_num(szInfo) >= 0 && !equal(szInfo, "cancel"))
		DoBuy(id, str_to_num(szInfo));
	MenuBrowseSkins(id, g_iBrowseTeam[id], g_iBrowsePage[id]);
	return PLUGIN_HANDLED;
}

public UpgradeHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuGold(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (!equal(szInfo, "none"))
		MenuConfirmUpgrade(id, str_to_num(szInfo));
	else
		MenuGold(id);
	return PLUGIN_HANDLED;
}

public UpgradeConfirmHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuUpgrade(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (str_to_num(szInfo) >= 0 && !equal(szInfo, "cancel"))
		DoUpgrade(id, str_to_num(szInfo));
	else
		MenuUpgrade(id);
	return PLUGIN_HANDLED;
}

public AdminHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuSkin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	switch (str_to_num(szInfo)) {
		case 1: {
			if (!IsSkinOwner(id)) {
				SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有发放皮肤权限");
				MenuAdmin(id);
				return PLUGIN_HANDLED;
			}
			g_pendingGiveTeam[id] = 0;
			MenuPickPlayer("give", id);
		}
		case 2: {
			if (!IsSkinOwner(id)) {
				SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有发放皮肤权限");
				MenuAdmin(id);
				return PLUGIN_HANDLED;
			}
			g_pendingGiveTeam[id] = 0;
			MenuPickPlayer("all", id);
		}
		case 3: {
			if (!IsSkinOwner(id)) {
				SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有移除皮肤权限");
				MenuAdmin(id);
				return PLUGIN_HANDLED;
			}
			MenuPickPlayer("remove", id);
		}
		case 4: MenuPoolList(id);
		case 5: MenuPickPlayer("view", id);
		case 6: {
			if (!IsSkinOwner(id)) {
				SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有发放皮肤权限");
				MenuAdmin(id);
				return PLUGIN_HANDLED;
			}
			MenuPickPlayer("knives", id);
		}
		case 7: {
			if (!IsSkinOwner(id)) {
				SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有发放皮肤权限");
				MenuAdmin(id);
				return PLUGIN_HANDLED;
			}
			MenuPickPlayer("nades", id);
		}
	}
	return PLUGIN_HANDLED;
}

public PoolListHandler(id, menu, item) {
	menu_destroy(menu);
	if (item == MENU_EXIT)
		MenuAdmin(id);
	return PLUGIN_HANDLED;
}

public PickPlayerHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (equal(szInfo, "none")) {
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	new target = str_to_num(szInfo);
	if (!is_user_connected(target)) {
		SkinChat(id, print_team_red, "SKIN_CHAT_TARGET_GONE", "目标玩家已离开");
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	if (!CanSkinTarget(id, target)) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "管理员只能操作自己的皮肤");
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	if (g_pendingMode[id][0] == 'v')
		MenuViewOwned(id, target);
	else if (g_pendingMode[id][0] == 'g')
		MenuGiveSkin(id, target);
	else if (g_pendingMode[id][0] == 'a') {
		new given = GiveAllSkinsTo(target, 0);
		SkinChat(id, print_team_default, "SKIN_CHAT_GIVE_ALL", "已向 %n 发放全部皮肤 (%d款)", target, given);
		MenuAdmin(id);
	} else if (g_pendingMode[id][0] == 'k') {
		new given = GiveAllKnivesTo(target);
		SkinChat(id, print_team_default, "SKIN_CHAT_GIVE_ALL_KNIFE", "已向 %n 发放全部刀皮 (%d款)", target, given);
		MenuAdmin(id);
	} else if (g_pendingMode[id][0] == 'n') {
		new given = GiveAllNadesTo(target);
		SkinChat(id, print_team_default, "SKIN_CHAT_GIVE_ALL_NADE", "已向 %n 发放全部投掷物皮肤 (%d款)", target, given);
		MenuAdmin(id);
	} else
		MenuRemoveSkin(id, target);
	return PLUGIN_HANDLED;
}

public ViewOwnedHandler(id, menu, item) {
	menu_destroy(menu);
	MenuAdmin(id);
	return PLUGIN_HANDLED;
}

public GiveSkinHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[12], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (!CanSkinTarget(id, g_pendingTarget[id])) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "管理员只能操作自己的皮肤");
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	if (!equal(szInfo, "none") && is_user_connected(g_pendingTarget[id])) {
		// info 形如 "<idx>"(角色皮肤) / "k<idx>"(刀皮) / "n<idx>"(投掷物皮肤)
		if (szInfo[0] == 'k')
			GiveKnifeTo(g_pendingTarget[id], str_to_num(szInfo[1]));
		else if (szInfo[0] == 'n')
			GiveNadeTo(g_pendingTarget[id], str_to_num(szInfo[1]));
		else
			GiveSkinTo(g_pendingTarget[id], str_to_num(szInfo));
	}
	MenuAdmin(id);
	return PLUGIN_HANDLED;
}

public RemoveSkinHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	new szInfo[SKIN_KEY_MAX], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), _, _, callback);
	menu_destroy(menu);
	if (!CanSkinTarget(id, g_pendingTarget[id])) {
		SkinChat(id, print_team_red, "SKIN_CHAT_NO_ADMIN", "管理员只能操作自己的皮肤");
		MenuAdmin(id);
		return PLUGIN_HANDLED;
	}
	RemoveSkinFrom(g_pendingTarget[id], szInfo);
	MenuAdmin(id);
	return PLUGIN_HANDLED;
}

/* 旧比赛个人菜单 / 发放菜单 callfunc 入口 */
public hns_give_skin_menu_public(admin, target, type) {
	g_legacyPendingAdmin[target] = admin;
	if (!is_user_connected(admin) || !IsSkinOwner(admin)) {
		if (is_user_connected(admin))
			SkinChat(admin, print_team_red, "SKIN_CHAT_NO_ADMIN", "你没有发放皮肤权限");
		return PLUGIN_HANDLED;
	}
	if (!is_user_connected(target)) {
		SkinChat(admin, print_team_red, "SKIN_CHAT_TARGET_GONE", "目标玩家已离开");
		return PLUGIN_HANDLED;
	}
	if (!CanSkinTarget(admin, target)) {
		SkinChat(admin, print_team_red, "SKIN_CHAT_NO_ADMIN", "管理员只能操作自己的皮肤");
		return PLUGIN_HANDLED;
	}
	if (type == 3) {
		new given = GiveAllKnivesTo(target);
		SkinChat(admin, print_team_default, "SKIN_CHAT_GIVE_ALL_KNIFE", "已向 %n 发放全部刀皮 (%d款)", target, given);
		return PLUGIN_HANDLED;
	}
	if (type == 4) {
		new given = GiveAllNadesTo(target);
		SkinChat(admin, print_team_default, "SKIN_CHAT_GIVE_ALL_NADE", "已向 %n 发放全部投掷物皮肤 (%d款)", target, given);
		return PLUGIN_HANDLED;
	}
	g_pendingGiveTeam[admin] = (type == 1) ? TEAM_CHAR_T : TEAM_CHAR_C;
	MenuGiveSkin(admin, target);
	return PLUGIN_HANDLED;
}

public hns_give_all_skins_public(target, type) {
	if (!is_user_connected(target))
		return PLUGIN_HANDLED;
	if (!g_legacyPendingAdmin[target] || !is_user_connected(g_legacyPendingAdmin[target]) || !CanSkinTarget(g_legacyPendingAdmin[target], target))
		return PLUGIN_HANDLED;
	if (type == 3) {
		new given = GiveAllKnivesTo(target);
		if (g_legacyPendingAdmin[target] && is_user_connected(g_legacyPendingAdmin[target]))
			SkinChat(g_legacyPendingAdmin[target], print_team_default, "SKIN_CHAT_GIVE_ALL_KNIFE", "已向 %n 发放全部刀皮 (%d款)", target, given);
		return PLUGIN_HANDLED;
	}
	if (type == 4) {
		new given = GiveAllNadesTo(target);
		if (g_legacyPendingAdmin[target] && is_user_connected(g_legacyPendingAdmin[target]))
			SkinChat(g_legacyPendingAdmin[target], print_team_default, "SKIN_CHAT_GIVE_ALL_NADE", "已向 %n 发放全部投掷物皮肤 (%d款)", target, given);
		return PLUGIN_HANDLED;
	}
	new teamChar = (type == 1) ? TEAM_CHAR_T : TEAM_CHAR_C;
	new given = GiveAllSkinsTo(target, teamChar);
	if (g_legacyPendingAdmin[target] && is_user_connected(g_legacyPendingAdmin[target])) {
		new szTeam[16];
		SkinTeamShort(g_legacyPendingAdmin[target], teamChar, szTeam, charsmax(szTeam));
		SkinChat(g_legacyPendingAdmin[target], print_team_default, "SKIN_CHAT_GIVE_ALL_TEAM", "已向 %n 发放全部%s皮肤 (%d款)", target, szTeam, given);
	}
	return PLUGIN_HANDLED;
}

public hns_clear_skins_public(target) {
	if (!is_user_connected(target))
		return PLUGIN_HANDLED;
	new removed = ClearAllSkinsFrom(target);
	if (g_legacyPendingAdmin[target] && is_user_connected(g_legacyPendingAdmin[target]))
		SkinChat(g_legacyPendingAdmin[target], print_team_default, "SKIN_CHAT_CLEARED", "已清除 %n 的全部皮肤 (%d款)", target, removed);
	return PLUGIN_HANDLED;
}

// ============================================================================
//  hns_semiclip.sma
//  ---------------------------------------------------------------------------
//  HNS 队友穿透「比赛调度」插件 —— 替代 HnsMatch 自带的 semiclip 逻辑。
//
//  功能
//    - 只在比赛进行中生效(只跟比赛走)，pub/热身不动。
//    - 比赛开始后按当前地图判定：
//          [skill] 图  -> 开启队友穿透
//          [boost] 图  -> 关闭穿透(默认)，管理员可强制开启
//          [knife]/其他 -> 关闭穿透
//    - 图池来自 configs/mixsystem/hns-maps.ini (与 HnsMatchMaps 同源)。
//    - 比赛状态来自 HnsMatch 写入的 PersistentDataStorage("match_status")，
//      MATCH_STARTED(=7) 视为比赛进行中。
//    - 强制命令仅当回合生效，下一回合回到自动。
//
//  依赖
//    - Rulzy semiclip_mm 模块(已装)
//    - PersistentDataStorage 插件(HnsMatch 自带)
//    - 停用 HnsMatch 原 `utils.inc` 中的 set_semiclip()，见末尾说明。
//
//  管理员命令 (使用 hns_admin_flag)
//    amx_sc_on / amx_sc_off / amx_sc_toggle  : 强制穿透 开/关/切换(仅当回合)
//    amx_sc_status                            : 查看当前状态
// ============================================================================

#include <amxmodx>
#include <amxmisc>
#include <PersistentDataStorage>

#define PREFIX  "^4[Semiclip]^1"

// HnsMatch globals.inc 里的 MATCH_STATUS 枚举值
#define MATCH_NONE       0
#define MATCH_STARTED    7

#define STATE_AUTO  0      // 自动(按图+比赛)
#define STATE_FORCE_ON  1  // 强制开启(本回合)
#define STATE_FORCE_OFF 2  // 强制关闭(本回合)

#define MENU_MODE_AUTO 0
#define MENU_MODE_ON   1
#define MENU_MODE_OFF  2

new g_iForce = STATE_AUTO;                 // 当前强制状态
new g_szConfigFile[160];
new g_szCurrentMap[32];

// 当前地图类型(由 hns-maps.ini 判定)
new bool:g_bSkill;
new bool:g_bBoost;
new bool:g_bKnife;

public plugin_init() {
	register_plugin("HNS Semiclip", "1.0", "AI");

	// 配置文件路径(与 HnsMatchMaps 一致)
	new szDir[128];
	get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
	formatex(g_szConfigFile, charsmax(g_szConfigFile), "%s/mixsystem/hns-maps.ini", szDir);

	// 管理员命令
	new szAdminFlag[16];
	get_cvar_string("hns_admin_flag", szAdminFlag, charsmax(szAdminFlag));
	new iAccess = read_flags(szAdminFlag[0] ? szAdminFlag : "a");
	register_concmd("amx_sc_on",     "CmdForceOn",   iAccess, "- force semiclip ON this round");
	register_concmd("amx_sc_off",    "CmdForceOff",  iAccess, "- force semiclip OFF this round");
	register_concmd("amx_sc_toggle", "CmdForceTog",  iAccess, "- force semiclip toggle this round");
	register_concmd("amx_sc_status", "CmdStatus",    iAccess, "- show semiclip state");

	// 每回合开始应用一次(比赛状态随回合走)
	register_logevent("EventRoundStart", 2, "1=Round_Start");
}

// 换图进入后判定当前地图类型
public plugin_cfg() {
	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
	LoadCurrentMapType();
	ApplyAuto();
}

stock LoadCurrentMapType() {
	// 默认全部 false
	g_bSkill = false;
	g_bBoost = false;
	g_bKnife = false;

	if (!file_exists(g_szConfigFile))
		return;

	new fp = fopen(g_szConfigFile, "rt");
	if (!fp)
		return;

	new szLine[128], szMap[32];
	new szSection[32];
	new bool:bInSection;
	new currentSection[24];

	currentSection[0] = EOS;

	while (!feof(fp)) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue;

		if (szLine[0] == '[') {
			if (extract_section_name(szLine, szSection, charsmax(szSection))) {
				copy(currentSection, charsmax(currentSection), szSection);
				bInSection = true;
			} else {
				bInSection = false;
			}
			continue;
		}

		if (!bInSection || !currentSection[0])
			continue;

		// 取每行第一个字段(地图名)
		parse(szLine, szMap, charsmax(szMap));

		if (!szMap[0])
			continue;

		if (!equali(szMap, g_szCurrentMap))
			continue;

		// 命中当前图
		if (equali(currentSection, "skill")) {
			g_bSkill = true;
		} else if (equali(currentSection, "boost")) {
			g_bBoost = true;
		} else if (equali(currentSection, "knife")) {
			g_bKnife = true;
		}
	}

	fclose(fp);
}

// 比赛进行中?
stock bool:IsMatchStarted() {
	new iStatus = MATCH_NONE;
	PDS_GetCell("match_status", iStatus);
	return (iStatus == MATCH_STARTED);
}

// 计算本回合应开还是关
stock bool:ShouldEnable() {
	if (g_iForce == STATE_FORCE_ON)  return true;
	if (g_iForce == STATE_FORCE_OFF) return false;

	// Skill maps use teammate-only clipping; boost, knife and unknown maps stay off.
	return g_bSkill;
}

// 应用到模块
stock ApplyAuto() {
	SetSemiclip(ShouldEnable());
}

stock SetSemiclip(bool:bOn) {
	if (bOn) {
		server_cmd("semiclip_option semiclip 1");
		server_cmd("semiclip_option team 3");   // 仅队友
	} else {
		server_cmd("semiclip_option semiclip 0");
		server_cmd("semiclip_option team 0");
	}
	server_cmd("semiclip_option time 0");
}

public HnsSemiclipMenuGetMode() {
	if (g_iForce == STATE_FORCE_ON)
		return MENU_MODE_ON;
	if (g_iForce == STATE_FORCE_OFF)
		return MENU_MODE_OFF;
	return MENU_MODE_AUTO;
}

public HnsSemiclipMenuGetEnabled() {
	return ShouldEnable();
}

// HNS 菜单通过 callfunc 调用，避免对本插件建立 required native 依赖。
public HnsSemiclipMenuSet(iMode) {
	switch (iMode) {
		case MENU_MODE_ON: {
			g_iForce = STATE_FORCE_ON;
			SetSemiclip(true);
			PrintModeStatus(MENU_MODE_ON);
		}
		case MENU_MODE_OFF: {
			g_iForce = STATE_FORCE_OFF;
			SetSemiclip(false);
			PrintModeStatus(MENU_MODE_OFF);
		}
		default: {
			g_iForce = STATE_AUTO;
			ApplyAuto();
			PrintModeStatus(MENU_MODE_AUTO);
		}
	}
	return 1;
}

stock PrintModeStatus(iMode) {
	switch (iMode) {
		case MENU_MODE_ON:
			client_print_color(0, print_team_blue, "^4[HNS]^1当前穿透模式: ^3开启");
		case MENU_MODE_OFF:
			client_print_color(0, print_team_red, "^4[HNS]^1当前穿透模式: ^3关闭");
		default:
			client_print_color(0, print_team_default, "^4[HNS]^1当前穿透模式: 自动");
	}
}

// 每回合：上一回合的强制状态过期，本回合先清除强制再按自动应用
public EventRoundStart() {
	if (g_iForce != STATE_AUTO) {
		// 清除上回合强制，回到自动
		g_iForce = STATE_AUTO;
		server_print("[Semiclip] Round start: forced override cleared, back to auto.");
	}
	ApplyAuto();
}

// ==================== 命令(仅当回合) ====================
public CmdForceOn(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED;
	g_iForce = STATE_FORCE_ON;
	SetSemiclip(true);
	client_print(id, print_console, "%s Forced ON this round.", PREFIX);
	log_amx("Semiclip forced ON (this round) by %n", id);
	return PLUGIN_HANDLED;
}

public CmdForceOff(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED;
	g_iForce = STATE_FORCE_OFF;
	SetSemiclip(false);
	client_print(id, print_console, "%s Forced OFF this round.", PREFIX);
	log_amx("Semiclip forced OFF (this round) by %n", id);
	return PLUGIN_HANDLED;
}

public CmdForceTog(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED;
	g_iForce = (ShouldEnable() ? STATE_FORCE_OFF : STATE_FORCE_ON);
	SetSemiclip(g_iForce == STATE_FORCE_ON);
	client_print(id, print_console, "%s Forced %s this round.", PREFIX, g_iForce == STATE_FORCE_ON ? "ON" : "OFF");
	return PLUGIN_HANDLED;
}

public CmdStatus(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED;

	new szType[16];
	if (g_bSkill)      copy(szType, charsmax(szType), "skill");
	else if (g_bBoost) copy(szType, charsmax(szType), "boost");
	else if (g_bKnife) copy(szType, charsmax(szType), "knife");
	else               copy(szType, charsmax(szType), "none");

	new bool:bMatch = IsMatchStarted();
	client_print(id, print_console, "%s Map=%s type=%s matchStarted=%s force=%d => semiclip=%s",
		PREFIX, g_szCurrentMap, szType, bMatch ? "YES" : "NO", g_iForce,
		(ShouldEnable() ? "ON" : "OFF"));
	return PLUGIN_HANDLED;
}

// ==================== 工具 ====================
stock bool:extract_section_name(const szLine[], szSection[], len) {
	if (szLine[0] != '[') return false;

	new i = 1, j = 0;
	while (szLine[i] && szLine[i] != ']' && j < len) {
		szSection[j++] = szLine[i++];
	}

	if (szLine[i] != ']') return false;

	szSection[j] = EOS;
	trim(szSection);
	return szSection[0] != EOS;
}
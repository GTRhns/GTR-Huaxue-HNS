#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1

#define MENU_MODE_AUTO 0
#define MENU_MODE_ON   1
#define MENU_MODE_OFF  2

new g_iCvar[2];
new bool:g_bApplying;

new g_iMenuMode = MENU_MODE_AUTO;
new g_szConfigFile[160];
new g_szCurrentMap[32];
new bool:g_bSkill;
new bool:g_bBoost;
new bool:g_bKnife;

public plugin_init()
{
	register_plugin("Team-Semiclip", "2.1", "SchlumPF*/HNS");

	g_iCvar[0] = register_cvar("semiclip_enabled", "0");
	g_iCvar[1] = register_cvar("semiclip_teamclip", "1");

	new szAdminFlag[16];
	get_cvar_string("hns_admin_flag", szAdminFlag, charsmax(szAdminFlag));
	new iAccess = read_flags(szAdminFlag[0] ? szAdminFlag : "a");
	register_concmd("amx_sc_on", "CmdForceOn", iAccess, "- force teammate semiclip ON");
	register_concmd("amx_sc_off", "CmdForceOff", iAccess, "- force teammate semiclip OFF");
	register_concmd("amx_sc_toggle", "CmdForceTog", iAccess, "- cycle auto/on/off");
	register_concmd("amx_sc_status", "CmdStatus", iAccess, "- show teammate semiclip state");

	register_logevent("EventRoundStart", 2, "1=Round_Start");
	hook_cvar_change(g_iCvar[0], "OnEnabledCvarChange");

}

public plugin_cfg()
{
	new szDir[128];
	get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
	formatex(g_szConfigFile, charsmax(g_szConfigFile), "%s/mixsystem/hns-maps.ini", szDir);

	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
	LoadCurrentMapType();
	ApplyState();
}

public EventRoundStart()
{
	ApplyState();
}

public HnsSemiclipMenuGetMode()
{
	return g_iMenuMode;
}

public HnsSemiclipMenuGetEnabled()
{
	return ShouldEnable() ? 1 : 0;
}

public HnsSemiclipMenuSet(iMode)
{
	SetMenuMode(iMode);
	ApplyState();
	return 1;
}

public HnsSemiclipApply(iOn)
{
	SetEnabled(iOn != 0);
	return 1;
}

public CmdForceOn(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	SetMenuMode(MENU_MODE_ON);
	ApplyState();
	PrintModeStatus();
	return PLUGIN_HANDLED;
}

public CmdForceOff(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	SetMenuMode(MENU_MODE_OFF);
	ApplyState();
	PrintModeStatus();
	return PLUGIN_HANDLED;
}

public CmdForceTog(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	if (g_iMenuMode == MENU_MODE_AUTO)
		SetMenuMode(MENU_MODE_ON);
	else if (g_iMenuMode == MENU_MODE_ON)
		SetMenuMode(MENU_MODE_OFF);
	else
		SetMenuMode(MENU_MODE_AUTO);

	ApplyState();
	PrintModeStatus();
	return PLUGIN_HANDLED;
}

public CmdStatus(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new szType[16];
	if (g_bSkill)
		copy(szType, charsmax(szType), "skill");
	else if (g_bBoost)
		copy(szType, charsmax(szType), "boost");
	else if (g_bKnife)
		copy(szType, charsmax(szType), "knife");
	else
		copy(szType, charsmax(szType), "none");

	client_print(id, print_console, "[Team-Semiclip] map=%s type=%s mode=%s enabled=%s team=3",
		g_szCurrentMap,
		szType,
		g_iMenuMode == MENU_MODE_ON ? "on" : (g_iMenuMode == MENU_MODE_OFF ? "off" : "auto"),
		ShouldEnable() ? "YES" : "NO");
	return PLUGIN_HANDLED;
}

public OnEnabledCvarChange(pCvar, const szOldValue[], const szNewValue[])
{
	if (g_bApplying)
		return;

	SetEnabled(str_to_num(szNewValue) != 0);
}

stock SetMenuMode(iMode)
{
	switch (iMode)
	{
		case MENU_MODE_ON: g_iMenuMode = MENU_MODE_ON;
		case MENU_MODE_OFF: g_iMenuMode = MENU_MODE_OFF;
		default: g_iMenuMode = MENU_MODE_AUTO;
	}
}

stock bool:ShouldEnable()
{
	if (g_iMenuMode == MENU_MODE_ON)
		return true;
	if (g_iMenuMode == MENU_MODE_OFF)
		return false;

	if (g_bBoost || g_bKnife || !g_bSkill)
		return false;

	new pBoost = get_cvar_pointer("hns_boost");
	if (pBoost && get_pcvar_num(pBoost))
		return false;

	return true;
}

stock ApplyState()
{
	SetEnabled(ShouldEnable());
}

stock SetEnabled(bool:bOn)
{
	g_bApplying = true;
	set_pcvar_num(g_iCvar[0], bOn ? 1 : 0);
	set_pcvar_num(g_iCvar[1], 1);
	g_bApplying = false;

	server_cmd("semiclip_option semiclip %d", bOn ? 1 : 0);
	server_cmd("semiclip_option team 3");
	server_cmd("semiclip_option time 0");
	server_exec();
}

stock PrintModeStatus()
{
	switch (g_iMenuMode)
	{
		case MENU_MODE_ON:
			client_print_color(0, print_team_blue, "^4[HNS]^1 穿透模式: ^3开^1 (仅队友)");
		case MENU_MODE_OFF:
			client_print_color(0, print_team_red, "^4[HNS]^1 穿透模式: ^3关");
		default:
			client_print_color(0, print_team_default, "^4[HNS]^1 穿透模式: 自动 (%s)", ShouldEnable() ? "skill队友开" : "关");
	}
}

stock LoadCurrentMapType()
{
	g_bSkill = false;
	g_bBoost = false;
	g_bKnife = false;

	if (!file_exists(g_szConfigFile))
		return;

	new fp = fopen(g_szConfigFile, "rt");
	if (!fp)
		return;

	new szLine[128], szMap[32], szSection[32];
	new bool:bInSection;
	new currentSection[24];
	currentSection[0] = EOS;

	while (!feof(fp))
	{
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '/')
			continue;

		if (szLine[0] == '[')
		{
			if (extract_section_name(szLine, szSection, charsmax(szSection)))
			{
				copy(currentSection, charsmax(currentSection), szSection);
				bInSection = true;
			}
			else
			{
				bInSection = false;
			}
			continue;
		}

		if (!bInSection || !currentSection[0])
			continue;

		parse(szLine, szMap, charsmax(szMap));
		if (!szMap[0] || !equali(szMap, g_szCurrentMap))
			continue;

		if (equali(currentSection, "skill"))
			g_bSkill = true;
		else if (equali(currentSection, "boost"))
			g_bBoost = true;
		else if (equali(currentSection, "knife"))
			g_bKnife = true;
	}

	fclose(fp);
}

stock bool:extract_section_name(const szLine[], szSection[], len)
{
	if (szLine[0] != '[')
		return false;

	new i = 1, j = 0;
	while (szLine[i] && szLine[i] != ']' && j < len)
	{
		szSection[j++] = szLine[i++];
	}

	if (szLine[i] != ']')
		return false;

	szSection[j] = EOS;
	trim(szSection);
	return szSection[0] != EOS;
}

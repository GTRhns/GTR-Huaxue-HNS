#include <amxmodx>
#include <reapi>

enum rgb { Float:red, Float:green, Float:blue };
new Float:g_Color[ rgb ];

public plugin_init()
{
	register_plugin("[ReAPI] Colored Flash", "1.0", "ReHLDS Team");
	RegisterHookChain(RG_PlayerBlind, "PlayerBlind");

	register_cvar("amx_flash_rgb", "51 0 102");

	new color_rgb[12];
	new szRed[4], szGreen[4], szBlue[4];

	get_cvar_string("amx_flash_rgb", color_rgb, charsmax(color_rgb));
	parse(color_rgb, szRed, charsmax(szRed), szGreen, charsmax(szGreen), szBlue, charsmax(szBlue));

	g_Color[red]   = str_to_float(szRed);
	g_Color[green] = str_to_float(szGreen);
	g_Color[blue]  = str_to_float(szBlue);
}

public PlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha, Float:color[3])
{
	color = g_Color;
	return HC_CONTINUE;
}
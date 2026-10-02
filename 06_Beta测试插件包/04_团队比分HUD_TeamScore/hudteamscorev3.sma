#include <amxmodx>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

new g_iTScore, g_iCTScore, g_iRounds

public plugin_init()
{
	register_plugin("Score & Round", "1.0", "OciXCrom")
	register_event("HLTV", "OnRoundStart", "a", "1=0", "2=0")
	register_event("TextMsg", "OnRoundRestart", "a", "2&#Game_C", "2&#Game_w")
	register_event("SendAudio", "OnTerroristWin", "a", "2&%!MRAD_terwin")
	register_event("SendAudio", "OnCTWin", "a", "2&%!MRAD_ctwin" )
	set_task(1.0, "ShowInfo", .flags = "b")
}

public OnRoundStart()
	g_iRounds++

public OnRoundRestart()
{
	g_iRounds = 0
	g_iTScore = 0
	g_iCTScore = 0
}

public OnTerroristWin()
	g_iTScore++

public OnCTWin()
	g_iCTScore++

public ShowInfo()
{
	set_dhudmessage(0, 255, 255, 0.39, 0.05, _, _, 1.0)
	show_dhudmessage(0, "CT [%i]", g_iCTScore)

	set_dhudmessage(255, 0, 0, 0.55, 0.05, _, _, 1.0)
	show_dhudmessage(0, "[%i] T", g_iTScore)

	set_dhudmessage(255, 255, 255, -1.0, 0.05, _, _, 1.0)
	show_dhudmessage(0, "vs^nRound %i", g_iRounds)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0\\ deflang1033{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ f0\\ fs16 \n\\ par }
*/

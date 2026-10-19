/* ============================================================
   HNS FPS Limit
   进服强制 fps_max 99.5 / fps_override 0。
   查询 cvar 或实测帧超过 99.5 直接踢。

   默认先不进 plugins.ini，测好多闪光再开。
   ============================================================ */

#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define PLUGIN  "HNS FPS Limit"
#define VERSION "0.1.0"
#define AUTHOR  "GTR"

#define TASK_FORCE   74001
#define TASK_QUERY   75001
#define TASK_MEASURE 76001

new g_pCvarLimit;
new g_pCvarKickFps;
new g_pCvarWarn;
new g_pCvarGrace;
new g_pCvarImmune;

new g_iFrames[MAX_PLAYERS + 1];
new g_iMsecSum[MAX_PLAYERS + 1];
new g_iOverCount[MAX_PLAYERS + 1];
new Float:g_flJoinTime[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_pCvarLimit = create_cvar("hns_fps_limit", "99.5", FCVAR_NONE, "Forced fps_max");
	g_pCvarKickFps = create_cvar("hns_fps_kick", "100.5", FCVAR_NONE, "Measured FPS kick threshold");
	g_pCvarWarn = create_cvar("hns_fps_warn", "0", FCVAR_NONE, "1=warn once before kick, 0=kick now");
	g_pCvarGrace = create_cvar("hns_fps_grace", "8.0", FCVAR_NONE, "Seconds after join before kick");
	g_pCvarImmune = create_cvar("hns_fps_immune", "0", FCVAR_NONE, "1=ADMIN_IMMUNITY bypass");

	register_forward(FM_CmdStart, "OnCmdStart");
	set_task(1.0, "TaskMeasure", TASK_MEASURE, .flags = "b");
}

public client_putinserver(id)
{
	if (is_user_bot(id) || is_user_hltv(id))
		return;

	g_iFrames[id] = 0;
	g_iMsecSum[id] = 0;
	g_iOverCount[id] = 0;
	g_flJoinTime[id] = get_gametime();

	set_task(0.5, "TaskForceFps", TASK_FORCE + id);
	set_task(2.0, "TaskQueryFps", TASK_QUERY + id, .flags = "b");
}

public client_disconnected(id)
{
	remove_task(TASK_FORCE + id);
	remove_task(TASK_QUERY + id);
	g_iFrames[id] = 0;
	g_iMsecSum[id] = 0;
	g_iOverCount[id] = 0;
}

public TaskForceFps(taskid)
{
	new id = taskid - TASK_FORCE;
	if (!is_user_connected(id) || is_user_bot(id))
		return;

	new Float:limit = get_pcvar_float(g_pCvarLimit);
	client_cmd(id, "fps_max %.1f;fps_override 0;developer 0", limit);
}

public TaskQueryFps(taskid)
{
	new id = taskid - TASK_QUERY;
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
	{
		remove_task(taskid);
		return;
	}

	query_client_cvar(id, "fps_max", "CvarFpsMax");
	query_client_cvar(id, "fps_override", "CvarFpsOverride");
}

public CvarFpsMax(id, const cvar[], const value[])
{
	if (!is_user_connected(id) || is_user_bot(id))
		return;
	if (!InGrace(id))
		return;

	new Float:fps = str_to_float(value);
	new Float:limit = get_pcvar_float(g_pCvarLimit);
	if (fps > limit + 0.05)
		KickFps(id, "fps_max %.1f > %.1f", fps, limit);
}

public CvarFpsOverride(id, const cvar[], const value[])
{
	if (!is_user_connected(id) || is_user_bot(id))
		return;
	if (!InGrace(id))
		return;

	if (str_to_num(value) != 0)
		KickFps(id, "fps_override %s", value);
}

public OnCmdStart(id, uc, seed)
{
	if (id < 1 || id > MaxClients)
		return FMRES_IGNORED;
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return FMRES_IGNORED;

	new msec = get_uc(uc, UC_Msec);
	if (msec <= 0)
		return FMRES_IGNORED;

	g_iFrames[id]++;
	g_iMsecSum[id] += msec;
	return FMRES_IGNORED;
}

public TaskMeasure()
{
	new Float:kickAt = get_pcvar_float(g_pCvarKickFps);
	for (new id = 1; id <= MaxClients; id++)
	{
		if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
			continue;

		new frames = g_iFrames[id];
		new msecSum = g_iMsecSum[id];
		g_iFrames[id] = 0;
		g_iMsecSum[id] = 0;

		if (!InGrace(id) || frames < 20 || msecSum <= 0)
			continue;

		new Float:avgMsec = float(msecSum) / float(frames);
		if (avgMsec < 1.0)
			continue;

		new Float:fps = 1000.0 / avgMsec;
		if (fps > kickAt)
		{
			g_iOverCount[id]++;
			if (g_iOverCount[id] >= 3)
				KickFps(id, "measured %.1f fps", fps);
		}
		else
			g_iOverCount[id] = 0;
	}
}

stock bool:InGrace(id)
{
	return (get_gametime() - g_flJoinTime[id]) >= get_pcvar_float(g_pCvarGrace);
}

stock bool:IsImmune(id)
{
	return get_pcvar_num(g_pCvarImmune) && (get_user_flags(id) & ADMIN_IMMUNITY) != 0;
}

stock KickFps(id, const fmt[], any:...)
{
	if (!is_user_connected(id) || IsImmune(id))
		return;

	new reason[64];
	vformat(reason, charsmax(reason), fmt, 3);

	if (get_pcvar_num(g_pCvarWarn) && g_iOverCount[id] < 4)
	{
		client_print_color(id, print_team_red, "^4[HNS]^1 FPS 超限（%s）。请设 fps_max 99.5。", reason);
		return;
	}

	new name[32];
	get_user_name(id, name, charsmax(name));
	log_amx("[HNS] Kick %s for FPS: %s", name, reason);
	server_cmd("kick #%d ^"FPS limit 99.5 (%s)^"", get_user_userid(id), reason);
}

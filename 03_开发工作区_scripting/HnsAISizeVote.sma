#include <amxmodx>
#include <amxmisc>

#define PLUGIN_VERSION "1.0.0"
#define TASK_CHECK 94010
#define TASK_VOTE 94020
#define VOTE_SECONDS 20

native hns_ai_get_team_size()
native hns_ai_set_team_size(size)

new bool:g_bReady
new bool:g_bVoting
new g_iSeconds
new g_iTarget
new g_iYes
new g_iNo
new bool:g_bVoted[MAX_PLAYERS + 1]
new g_iMenu

public plugin_init()
{
	register_plugin("AI Size Vote", PLUGIN_VERSION, "GTR")
	g_iMenu = register_menuid("AISizeVote")
	register_menucmd(g_iMenu, 1023, "MenuVote")
	set_task(5.0, "TaskCheck", TASK_CHECK, .flags = "b")
}

public plugin_natives()
{
	set_task(1.0, "TaskBind")
}

public TaskBind()
{
	g_bReady = bool:LibraryExists("hns_ai_signup", LibType_Library)
	if (!g_bReady)
		log_amx("[HnsAISizeVote] HnsAISignup 没加载, 人数投票不会开始")
}

public client_disconnected(id)
{
	g_bVoted[id] = false
}

public TaskCheck()
{
	if (!g_bReady || g_bVoting)
		return

	new online = CountHumans()
	new want = 0
	if (online >= 6 && online <= 12)
		want = online / 2

	new current = hns_ai_get_team_size()
	if (want == current)
		return
	if (want == 0 && current == 0)
		return

	StartVote(want)
}

stock StartVote(size)
{
	g_bVoting = true
	g_iTarget = size
	g_iSeconds = VOTE_SECONDS
	g_iYes = 0
	g_iNo = 0

	for (new i = 1; i <= MaxClients; i++)
		g_bVoted[i] = false

	if (size == 0)
		client_print_color(0, print_team_default, "^4[HNSai]^1 在线不足 6 人, 投票是否恢复自动人数")
	else
		client_print_color(0, print_team_default, "^4[HNSai]^1 在线 %d 人, 投票是否改成 ^3%d v %d", size * 2, size, size)

	ShowAll()
	set_task(1.0, "TaskVote", TASK_VOTE, .flags = "b")
}

public TaskVote()
{
	if (!g_bVoting)
	{
		remove_task(TASK_VOTE)
		return
	}

	g_iSeconds--
	if (g_iSeconds > 0 && g_iSeconds % 5 == 0)
		ShowAll()

	if (g_iSeconds > 0)
		return

	remove_task(TASK_VOTE)
	FinishVote()
}

stock FinishVote()
{
	new size = g_iTarget
	g_bVoting = false

	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_connected(i))
			show_menu(i, 0, "", 1)
	}

	if (g_iYes == 0 || g_iYes <= g_iNo)
	{
		client_print_color(0, print_team_default, "^4[HNSai]^1 人数投票未通过 (同意 %d / 反对 %d), 保持不变", g_iYes, g_iNo)
		return
	}

	if (!hns_ai_set_team_size(size))
	{
		client_print_color(0, print_team_default, "^4[HNSai]^1 比赛进行中, 人数没有改")
		return
	}

	if (size == 0)
		client_print_color(0, print_team_default, "^4[HNSai]^1 投票通过 (同意 %d / 反对 %d), 人数恢复自动", g_iYes, g_iNo)
	else
		client_print_color(0, print_team_default, "^4[HNSai]^1 投票通过 (同意 %d / 反对 %d), 报名改为 ^3%d v %d", g_iYes, g_iNo, size, size)
}

stock ShowAll()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || g_bVoted[i])
			continue
		ShowOne(i)
	}
}

stock ShowOne(id)
{
	new text[192], title[96]
	if (g_iTarget == 0)
		formatex(title, charsmax(title), "\y人数投票 \r[%d秒]\w^n在线不足 6 人, 恢复自动?", g_iSeconds)
	else
		formatex(title, charsmax(title), "\y人数投票 \r[%d秒]\w^n在线 %d 人, 改成 %d v %d?", g_iSeconds, g_iTarget * 2, g_iTarget, g_iTarget)

	formatex(text, charsmax(text), "%s^n^n\r1. \w同意 \y[%d]^n\r2. \w反对 \y[%d]", title, g_iYes, g_iNo)
	show_menu(id, (1<<0)|(1<<1), text, 5, "AISizeVote")
}

public MenuVote(id, key)
{
	if (!g_bVoting || g_bVoted[id])
		return PLUGIN_HANDLED

	g_bVoted[id] = true
	if (key == 0)
		g_iYes++
	else if (key == 1)
		g_iNo++

	return PLUGIN_HANDLED
}

stock CountHumans()
{
	new players[MAX_PLAYERS], num
	get_players(players, num, "ch")
	return num
}

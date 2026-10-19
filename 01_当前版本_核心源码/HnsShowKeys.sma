/* ============================================================
   HnsShowKeys  -  KZ 按键 HUD
   个人设置第2页第7项开关, 也可用 /kzhud /keys
   显示 WASD / 跳 / 蹲 + 水平速度
   不录像, 不额外 precache 模型
   ============================================================ */

#include <amxmodx>
#include <fakemeta>
#include <hns_language>

#define PLUGIN "HNS Show Keys"
#define VERSION "1.0.0"
#define AUTHOR "GTR"

new g_pChannel;
new bool:g_bShow[MAX_PLAYERS + 1];
new bool:g_bSpeed[MAX_PLAYERS + 1];

#define TASK_KEYS_UPDATE 48120
#define KEYS_UPDATE_INTERVAL 0.05

public plugin_natives() {
	register_library("hns_showkeys");
	register_native("hns_showkeys_get", "native_get");
	register_native("hns_showkeys_toggle", "native_toggle");
}

public native_get(plugin, params) {
	new id = get_param(1);
	if (id < 1 || id > MaxClients)
		return 0;
	return g_bShow[id] ? 1 : 0;
}

public native_toggle(plugin, params) {
	new id = get_param(1);
	if (id < 1 || id > MaxClients || !is_user_connected(id))
		return 0;
	ToggleKeys(id);
	return g_bShow[id] ? 1 : 0;
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	g_pChannel = register_cvar("hns_keys_channel", "4");

	register_clcmd("say /kzhud", "CmdToggle");
	register_clcmd("say_team /kzhud", "CmdToggle");
	register_clcmd("say /keys", "CmdToggle");
	register_clcmd("say_team /keys", "CmdToggle");
	register_clcmd("say /klawisz", "CmdToggle");
	register_clcmd("say_team /klawisz", "CmdToggle");

}

public client_putinserver(id) {
	g_bShow[id] = false;
	g_bSpeed[id] = true;
}

public client_disconnected(id) {
	remove_task(id + TASK_KEYS_UPDATE);
	g_bShow[id] = false;
	g_bSpeed[id] = true;
}

public CmdToggle(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	ToggleKeys(id);
	return PLUGIN_HANDLED;
}

stock KeysUnescape(szText[], iLen) {
	replace_all(szText, iLen, "^^n", "^n");
	replace_all(szText, iLen, "^^1", "^1");
	replace_all(szText, iLen, "^^3", "^3");
	replace_all(szText, iLen, "^^4", "^4");
}

stock ToggleKeys(id) {
	g_bShow[id] = !g_bShow[id];

	if (g_bShow[id]) {
		remove_task(id + TASK_KEYS_UPDATE);
		set_task(KEYS_UPDATE_INTERVAL, "TaskUpdateKeys", id + TASK_KEYS_UPDATE, .flags = "b");
	} else {
		remove_task(id + TASK_KEYS_UPDATE);
	}
	new szText[96];
	HnsLang_Get(id, g_bShow[id] ? "KZHUD_ON" : "KZHUD_OFF", szText, charsmax(szText));
	if (!szText[0])
		copy(szText, charsmax(szText), g_bShow[id] ? "^4[HNS]^1 KZ按键HUD: ^3开" : "^4[HNS]^1 KZ按键HUD: ^1关");
	KeysUnescape(szText, charsmax(szText));
	client_print_color(id, print_team_red, "%s", szText);
}

public TaskUpdateKeys(taskid) {
	new id = taskid - TASK_KEYS_UPDATE;
	if (id < 1 || id > MaxClients || !is_user_connected(id) || !g_bShow[id]) {
		if (id >= 1 && id <= MaxClients)
			remove_task(taskid);
		return;
	}

	// Keep the task alive while dead so the HUD automatically resumes after respawn.
	if (!is_user_alive(id))
		return;

	new buttons = pev(id, pev_button);
	new szW[6], szA[6], szS[6], szD[6], szJump[12], szDuck[12];
	new szJumpOn[12], szJumpOff[12], szDuckOn[12], szDuckOff[12];

	copy(szW, charsmax(szW), (buttons & IN_FORWARD) ? "[W]" : "[-]");
	copy(szA, charsmax(szA), (buttons & IN_MOVELEFT) ? "[A]" : "[-]");
	copy(szS, charsmax(szS), (buttons & IN_BACK) ? "[S]" : "[-]");
	copy(szD, charsmax(szD), (buttons & IN_MOVERIGHT) ? "[D]" : "[-]");

	HnsLang_Get(id, "KZHUD_JUMP", szJumpOn, charsmax(szJumpOn));
	HnsLang_Get(id, "KZHUD_JUMP_OFF", szJumpOff, charsmax(szJumpOff));
	HnsLang_Get(id, "KZHUD_DUCK", szDuckOn, charsmax(szDuckOn));
	HnsLang_Get(id, "KZHUD_DUCK_OFF", szDuckOff, charsmax(szDuckOff));
	if (!szJumpOn[0]) copy(szJumpOn, charsmax(szJumpOn), "[跳]");
	if (!szJumpOff[0]) copy(szJumpOff, charsmax(szJumpOff), "[--]");
	if (!szDuckOn[0]) copy(szDuckOn, charsmax(szDuckOn), "[蹲]");
	if (!szDuckOff[0]) copy(szDuckOff, charsmax(szDuckOff), "[--]");

	copy(szJump, charsmax(szJump), (buttons & IN_JUMP) ? szJumpOn : szJumpOff);
	copy(szDuck, charsmax(szDuck), (buttons & IN_DUCK) ? szDuckOn : szDuckOff);

	new channel = get_pcvar_num(g_pChannel);
	if (channel < 1 || channel > 4)
		channel = 4;

	set_hudmessage(180, 40, 40, 0.80, 0.02, 0, 0.0, 0.15, 0.0, 0.0, channel);

	if (g_bSpeed[id]) {
		new Float:velocity[3];
		pev(id, pev_velocity, velocity);
		new iSpeed = floatround(floatsqroot(velocity[0] * velocity[0] + velocity[1] * velocity[1]));
		new szSpeed[16];
		HnsLang_Get(id, "KZHUD_SPEED", szSpeed, charsmax(szSpeed));
		if (!szSpeed[0])
			copy(szSpeed, charsmax(szSpeed), "速度");
		show_hudmessage(id, "   %s^n%s %s %s^n%s  %s^n^n%s: %d", szW, szA, szS, szD, szDuck, szJump, szSpeed, iSpeed);
	} else {
		show_hudmessage(id, "   %s^n%s %s %s^n%s  %s", szW, szA, szS, szD, szDuck, szJump);
	}
}

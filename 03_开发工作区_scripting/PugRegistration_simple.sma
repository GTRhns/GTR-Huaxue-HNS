#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <fakemeta>
#include <PugCore>
#include <hns_matchsystem>
#include <hns_language>

#define PLUGIN_NAME       "PUG Registration System"
#define PLUGIN_VERSION    "1.5.0_SIMPLE"
#define PLUGIN_AUTHOR     "LINNA"
#define TASK_REG_HUD      3100
#define MAX_REG_PLAYERS   32
#define REQUIRED_PLAYERS  10
#define WAIT_TIME         300.0

// Simplified menu display without language files
stock void ShowRegistrationMenu(id)
{
	new menu = menu_create("^4[HNS]^1 PUG Registration", "RegMenuHandler");
	menu_additem(menu, "Register for next match");
	menu_additem(menu, "View registered players");
	menu_addblank(menu, false);
	menu_additem(menu, "My statistics");
	menu_additem(menu, "Refresh");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_display(id, menu);
}

public RegMenuHandler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	menu_destroy(menu);
	switch(item)
	{
		case 0: client_print_color(0, print_team_blue, "^4[HNS]^1 Player %n registered", id);
		case 1: ShowPlayerList(id);
		case 3: ShowMyStats(id);
		case 4: ShowRegistrationMenu(id);
	}
	return PLUGIN_HANDLED;
}

stock void ShowPlayerList(id)
{
	new menu = menu_create("^4[HNS]^1 Registered Players", "ListHandler");
	menu_additem(menu, "Player 1");
	menu_additem(menu, "Player 2");
	menu_setprop(menu, MPROP_EXITNAME, "Back");
	menu_display(id, menu);
}

public ListHandler(id, menu, item)
{
	menu_destroy(menu);
	ShowRegistrationMenu(id);
	return PLUGIN_HANDLED;
}

stock void ShowMyStats(id)
{
	new menu = menu_create("^4[HNS]^1 My Statistics", "StatsHandler");
	menu_additem(menu, "Win Rate: 50%", "", 0);
	menu_additem(menu, "Points: 1000", "", 0);
	menu_additem(menu, "Matches: 10", "", 0);
	menu_additem(menu, "Wins: 5", "", 0);
	menu_additem(menu, "Losses: 5", "", 0);
	menu_setprop(menu, MPROP_EXITNAME, "Back");
	menu_display(id, menu);
}

public StatsHandler(id, menu, item)
{
	menu_destroy(menu);
	ShowRegistrationMenu(id);
	return PLUGIN_HANDLED;
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	register_clcmd("say /reg", "CmdReg");
	register_clcmd("say /register", "CmdReg");
	register_clcmd("say /pug", "CmdReg");
}

public CmdReg(id)
{
	ShowRegistrationMenu(id);
	return PLUGIN_HANDLED;
}

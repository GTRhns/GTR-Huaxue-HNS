/*
 * PugCore.inc - PUG System Core Include
 * Stub implementation for PugRegistration.sma
 */

#if defined _pugcore_included
	#endinput
#endif
#define _pugcore_included

#include <amxmodx>

/**
 * PUG_RegCommand - Register a PUG command
 * @param cmd - Command name
 * @param func - Function to call
 * @param flags - Admin flags required
 * @param desc - Command description
 */
stock PUG_RegCommand(const cmd[], const func[], flags = ADMIN_ALL, const desc[] = "")
{
	// Suppress unused parameter warning
	#pragma unused desc
	
	// Register as say command
	new full_cmd[64];
	formatex(full_cmd, charsmax(full_cmd), "say /%s", cmd);
	register_clcmd(full_cmd, func, flags);
	
	// Also register as say_team command
	formatex(full_cmd, charsmax(full_cmd), "say_team /%s", cmd);
	register_clcmd(full_cmd, func, flags);
}

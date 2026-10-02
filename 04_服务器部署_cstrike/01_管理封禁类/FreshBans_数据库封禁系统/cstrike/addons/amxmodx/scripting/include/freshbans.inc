/*
 * FreshBans API
 *   This API provide methods for work with FreshBans ban system.
 *
 * Copyright (C) The AMX Mod X Development Team.
 *
 *
 *    This program is free software; you can redistribute it and/or modify it
 *    under the terms of the GNU General Public License as published by the
 *    Free Software Foundation; either version 3 of the License, or (at
 *    your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful, but
 *    WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *    General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software Foundation,
 *    Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *    In addition, as a special exception, the author gives permission to
 *    link the code of this program with the Half-Life Game Engine ("HL
 *    Engine") and Modified Game Libraries ("MODs") developed by Valve,
 *    L.L.C ("Valve").  You must obey the GNU General Public License in all
 *    respects for all of the code used other than the HL Engine and MODs
 *    from Valve.  If you modify this file, you may extend this exception
 *    to your version of the file, but you are not obligated to do so.  If
 *    you do not wish to do so, delete this exception statement from your
 *    version.
 *
 */

#if defined _freshbans_core_included
    #endinput
#endif

#define _freshbans_core_included

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib freshbans_core
    #if !defined AMXMODX_NOAUTOLOAD
        #pragma loadlib freshbans_core
    #endif
#else
    #pragma library freshbans_core
#endif


/**
 * @section Shared forwards
 */

/**
 * Called when FreshBans connected to database.
 *
 * @param db    A newly created tuple handle to be used in connection routines.  
 *
 * @return      This forward ignores the returned value.
 */
forward fbans_sql_connected(const Handle: db);

/**
 * Called when the connected player passed the ban check.
 * 
 * @note Will only be called if the client don't have a ban.
 *
 * @param id        Client index
 * @param userid    Client userid
 *
 * @return          This forward ignores the returned value.
 */
forward fbans_player_checked(const id, const userid);

/**
 * Called after the ban when client displays the MOTD window.
 *
 * @param id        Client index
 * @param userid    Client userid
 * @param banid     Client banid
 *
 * @return          This forward ignores the returned value.
 */
forward fbans_ban_motdopen(const id, const userid, const banid);

/**
 * Called when DopBan request to check the banid which does not exists. Needed to inform DopBan.
 *
 * @param id        Client index
 * @param userid    Client userid
 * @param banid     Client banid
 *
 * @return          This forward ignores the returned value.
 */
forward fbans_ban_not_found(const id, const userid, const banid);

/**
 * Called before the client is banned.
 *
 * @param id             Client index
 * @param userid         Client userid
 * 
 * @return               This forward ignores the returned value.
 *
 */
forward fbans_player_banned_pre(const id, const userid);

/**
 * Called before the client is banned.
 *
 * @note For backward compatibility.
 *
 * @param id       Client index
 * @param banid    Client banid
 *
 * @return         This forward ignores the returned value.
 */
forward amxbans_player_banned(const id, const banid);

/**
 * Called after the client is banned.
 *
 * @param id        Client index
 * @param userid    Client userid
 * @param banid     Client banid
 *
 * @return          This forward ignores the returned value.
 */
forward fbans_player_banned_post(const id, const userid, const banid);

/**
 * Called if requested from external ban is active and player gets kicked
 * created (and used) for DopBan
 *
 * @param id        Client index
 * @param userid    Client userid
 * @param banid     Client banid
 *
 * @return          This forward ignores the returned value.
 */
forward db_reqp_kicked(const id, const userid, const banid);

/**
 * Called when when active ban for player is checked.
 * !Important! Called only when cvar fb_kick_check is not 0.
 *
 * @param id                Client index
 * @param userid            Client userid
 * @param banid             Client banid
 * @param ban_created       Ban creation time (unix timestamp)
 * @param ban_length_int    Ban duration in seconds
 * @param ban_reason        Ban reason
 * @param admin_name        Admin name
 * @param admin_steamid     Admin steamid
 * @param player_name       Client name
 * @param player_steamid    Client steamid
 * @param player_ip         Client IP
 * @param ban_type          Ban type
 *
 * @return          PLUGIN_CONTINUE to let the command continue
 *                  PLUGIN_HANDLED to cancel the player's kick.
 */
forward fbans_active_ban_check(
    const id, const userid, const banid,
    const ban_created, const ban_length_int, const ban_reason[],
    const admin_name[], const admin_steamid[], const player_name[],
    const player_steamid[], const player_ip[], const ban_type[]);

/**
 * Called before ban is insrted in the ban table
 *
 * @param id                Client index - is not always valid (e.g. is not valid for offline ban, or when user is disconnected )
 * @param userid            Client userid - is not always valid ( is not valid for offline ban )
 * @param player_steamid    Client steamid
 * @param player_ip         Client IP
 * @param player_name       Client name
 * @param ban_created       Ban creation time (unix timestamp)
 * @param admin_ip        	Admin IP
 * @param admin_steamid     Admin steamid
 * @param admin_name        Admin name
 * @param ban_type          Ban type
 * @param ban_reason        Ban reason
 * @param bantime    Ban duration in seconds
 *
 * @return          This forward ignores the returned value.
 */
forward fbans_player_banned_pre_f(
	const id, const uid, 
	const player_steamid[], const player_ip[], const player_name[], 
	const admin_ip[], const admin_steamid[], const admin_name[], 
	const ban_type[], const ban_reason[], const bantime);

/**
 * @endsection Shared forwards
 */



/**
 * This is the callback from the main plugin that gives major/minor versions
 * for verifying compatibility for FreshBans versions.
 * If an AMXX plugin gets a failure, then you do need to upgrade to the latest
 * version of the FreshBans plugins or update the files included for AMXX plugins.
 * Do not modify this!
 */

/**
 * FreshBans version
 */
#define FB_VERSION_MAJOR		"1"
#define FB_VERSION_MINOR		"4"
#define FB_VERSION_PATCH		"8b"
#define FB_VERSION_STR		FB_VERSION_MAJOR + "." + FB_VERSION_MINOR + "." + FB_VERSION_PATCH
public __fb_version_check(const majorVersion[], const minorVersion[])
{
	if (strcmp(majorVersion, FB_VERSION_MAJOR) != 0) {
		set_fail_state("[FreshBans]: Api major version mismatch; expected %s, real %s",
			FB_VERSION_MAJOR, majorVersion);
		return;
	}

	if (strcmp(minorVersion, FB_VERSION_MINOR) != 0) {
		set_fail_state("[FreshBans]: Api minor version mismatch; expected at least %s, real %s",
			FB_VERSION_MINOR, minorVersion);
		return;
	}
}

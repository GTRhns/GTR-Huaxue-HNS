#include <amxmodx>
#include <fakemeta>

#define PLUGIN  "HPP_BLOCK"
#define AUTHOR  "Karaulov"
#define VERSION "1.2"

#define BLOCK_ONLY_HPP6
#define BLOCK_ONLY_HPP5

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	create_cvar(PLUGIN, VERSION, (FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED));
}

public client_putinserver(id)
{
#if defined(BLOCK_ONLY_HPP5)
	engfunc(EngFunc_SetPhysicsKeyValue, id, "pi", "xvi");
#elseif defined(BLOCK_ONLY_HPP6)
	engfunc(EngFunc_SetPhysicsKeyValue, id, "pi", "aye");
#else
	set_task(5.0, "set_hpp_blocker", id);
	engfunc(EngFunc_SetPhysicsKeyValue, id, "pi", "xvi");
#endif
}

new iBlockVersion[MAX_PLAYERS + 1] = {0,...};

public set_hpp_blocker(id)
{
	if (is_user_connected(id))
	{
		engfunc(EngFunc_SetPhysicsKeyValue, id, "pi", iBlockVersion[id] == 0 ? "xvi" : "aye");
		iBlockVersion[id] = iBlockVersion[id] == 0 ? 1 : 0;
		set_task(5.0, "set_hpp_blocker", id);
	}
}
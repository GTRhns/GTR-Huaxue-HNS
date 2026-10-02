/*
* 
*
*    AmxModX
*   Vampire plugin
*    by Shalfey
*
*   CVars
*   amx_vampire_hp - hp add for kill
*   amx_vampire_hp_hs - hp add for kill in head
*   amx_vampire_hp_vip - hp add for kill (VIP)
*   amx_vampire_hp_hs_vip - hp add for kill in head (VIP)
*   amx_vampire_max_hp - max player hp
*
*   Players gets HP for kills.
*/
#include <amxmodx>
#include <fun>

#define PLUGIN_VERSION "1.0 amxx-bg.info/forum"
#define ADMIN_LEVEL_VIP ADMIN_LEVEL_H

new health_add
new health_hs_add

new health_add_vip
new health_hs_add_vip

new health_max

new nKiller
new nKiller_hp
new nHp_add
new nHp_max

public plugin_init()
{
   register_plugin("Vampire", PLUGIN_VERSION, "Shalfey")

   health_add = register_cvar("amx_vampire_hp", "2")
   health_hs_add = register_cvar("amx_vampire_hp_hs", "3")
   health_add_vip = register_cvar("amx_vampire_hp_vip", "3")
   health_hs_add_vip = register_cvar("amx_vampire_hp_hs_vip", "5")
   health_max = register_cvar("amx_vampire_max_hp", "100")

   register_event("DeathMsg", "hook_death", "a", "1>0")     
}

public hook_death()
{
   // Killer id
   nKiller = read_data(1)

   if ( (read_data(3) == 1) && (read_data(5) == 0) )
   {
      nHp_add = is_user_vip(nKiller) ? get_pcvar_num(health_hs_add_vip) : get_pcvar_num (health_hs_add)
   }
   else
      nHp_add = is_user_vip(nKiller) ? get_pcvar_num(health_add_vip) : get_pcvar_num (health_add)

   nHp_max = get_pcvar_num (health_max)

   // Updating Killer HP
   nKiller_hp = get_user_health(nKiller)
   nKiller_hp += nHp_add

   // Maximum HP check
   if (nKiller_hp > nHp_max) nKiller_hp = nHp_max

   set_user_health(nKiller, nKiller_hp)

   // Hud message "Healed +15/+40 hp"
   set_hudmessage(0, 255, 0, -1.0, 0.15, 0, 1.0, 1.0, 0.1, 0.1, -1)
   show_hudmessage(nKiller, "Healed +%d hp", nHp_add)

   // Screen fading
   message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, nKiller)
   write_short(1<<10)
   write_short(1<<10)
   write_short(0x0000)
   write_byte(153)
   write_byte(0)
   write_byte(0)
   write_byte(100)
   message_end()
   
}  

bool:is_user_vip(id)
    return bool:(get_user_flags(id) & ADMIN_LEVEL_VIP)
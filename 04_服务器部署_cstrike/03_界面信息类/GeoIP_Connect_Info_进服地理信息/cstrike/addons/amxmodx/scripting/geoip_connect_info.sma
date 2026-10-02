#include <amxmodx>
#include <geoip>

#pragma semicolon 1

new const PREFIX[]        = "^4[GeoIP]";         // Префикс в чате для оповещения.
new const CONNECT_SOUND[] = "buttons/blip1.wav"; // Звук при входе игрока. Закомментировать, если не нужен.

public plugin_init() {
    register_plugin("[GeoIP] Connect Info", "1.0.0", "Nordic Warrior");
    register_dictionary("geoip_connect_info.txt");
}

#if defined CONNECT_SOUND
public plugin_precache() {
    precache_sound(CONNECT_SOUND);
}
#endif

public client_putinserver(id) {
    if(is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    new szIP[MAX_IP_LENGTH];
    get_user_ip(id, szIP, charsmax(szIP), 0);

    new szCountry[64], szRegion[64], szCity[64];

    new bool:bCountryFound = bool:geoip_country_ex  (szIP, szCountry,   charsmax(szCountry),    LANG_SERVER);
    new bool:bRegionFound  = bool:geoip_region_name (szIP, szRegion,    charsmax(szRegion),     LANG_SERVER);
    new bool:bCityFound    = bool:geoip_city        (szIP, szCity,      charsmax(szCity),       LANG_SERVER);

    if (bCountryFound && bCityFound && bRegionFound) {
        client_print_color(0, print_team_default, "%s %L %L^3 %s ^4(%s, %s)", PREFIX, LANG_SERVER, "CINFO_JOINED", id, LANG_SERVER, "CINFO_FROM", szCity, szRegion, szCountry);
    } else if (bCountryFound && bRegionFound) {
        client_print_color(0, print_team_default, "%s %L %L^3 %s ^4(%s)", PREFIX, LANG_SERVER, "CINFO_JOINED", id, LANG_SERVER, "CINFO_FROM", szRegion, szCountry);
    } else if (bCountryFound) {
        client_print_color(0, print_team_default, "%s %L %L^4 %s", PREFIX, LANG_SERVER, "CINFO_JOINED", id, LANG_SERVER, "CINFO_FROM", szCountry);
    } else {
        client_print_color(0, print_team_default, "%s %L^4 ...", PREFIX, LANG_SERVER, "CINFO_JOINED", id);
    }

#if defined CONNECT_SOUND
    client_cmd(0, "spk %s", CONNECT_SOUND);
#endif
}

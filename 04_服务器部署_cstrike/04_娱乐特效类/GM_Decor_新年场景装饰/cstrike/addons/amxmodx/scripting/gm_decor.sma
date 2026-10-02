#include <amxmodx>
#include <reapi>
#include <engine>
#include <fakemeta>
#include <json>


#define Plugin_Name "[GM] Decor"
#define Plugin_Version "1.1.0"
#define Plugin_Author "[GM] NWC"

#define CLASSNAME "env_decor"

enum structDecor
{
    decor_szName[32],
    decor_iOrigin[3],
    decor_iAngle,
    decor_iSolid
}

new Array: g_aDecor, Trie:g_tDecorModel, Array:g_aDecorEnt;

new g_szDecorSpawns[128] = "addons/amxmodx/configs/plugins/gm_plugins/decor/spawns/";
new g_szSelectDecor[MAX_PLAYERS + 1][32];
new g_iSelectDecor[MAX_PLAYERS + 1];
new g_iSolidDecor[MAX_PLAYERS + 1];

const KEYS = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

new g_szSprite[] = "sprites/laserbeam.spr";
new g_iSprite;

public plugin_precache()
{
    g_aDecor = ArrayCreate(structDecor);
    g_tDecorModel = TrieCreate();
    g_aDecorEnt = ArrayCreate();

    g_iSprite = precache_model(g_szSprite);

    new szMap[16];
    rh_get_mapname(szMap, charsmax(szMap));
    add(g_szDecorSpawns, charsmax(g_szDecorSpawns), fmt("%s.json", szMap));

    @LoadModels();
}

@LoadModels()
{
    new JSON: models = json_parse("addons/amxmodx/configs/plugins/gm_plugins/decor/models.json", true);

    if (models == Invalid_JSON)
    {
        log_error(AMX_ERR_NOTFOUND, "Not found Json File: ^"addons/amxmodx/configs/plugins/gm_plugins/decor/models.json^"");
        return PLUGIN_HANDLED;
    }

    new iSize = json_object_get_count(models);
    new szName[32], szModels[128];

    for (new i; i < iSize; i++)
    {   
        json_object_get_name(models, i, szName, charsmax(szName));
        json_object_get_string(models, szName, szModels, charsmax(szModels));

        if (!file_exists(szModels))
        {
            log_amx("Could not find model file: %s", szModels);
            continue;
        }
        
        precache_model(szModels);
        TrieSetString(g_tDecorModel, szName, szModels);
    }

    json_free(models);
    return PLUGIN_HANDLED;
}

@ReadSpawns()
{
    new JSON: spawns = json_parse(g_szDecorSpawns, true);

    if (spawns == Invalid_JSON)
    {
        log_amx("Could not find spawns file: %s", g_szDecorSpawns);
        log_amx("Could Not find spawns for this map");
        return PLUGIN_HANDLED;
    }

    new iSize = json_object_get_count(spawns);
    new temp[structDecor];

    for (new i; i < iSize; i++)
    {
        json_object_get_name(spawns, i, temp[decor_szName], charsmax(temp[decor_szName]));

        if (!TrieKeyExists(g_tDecorModel, temp[decor_szName]))
        {
            log_amx("Could not loaded models (%s) skip spawns", temp[decor_szName]);
            continue;
        }

        new JSON: arrays = json_object_get_value_at(spawns, i);
        new size = json_array_get_count(arrays);

        for (new j; j < size; j++)
        {
            new JSON: array = json_array_get_value(arrays, j);

            temp[decor_iOrigin][0] = json_array_get_number(array, 0);
            temp[decor_iOrigin][1] = json_array_get_number(array, 1);
            temp[decor_iOrigin][2] = json_array_get_number(array, 2);
            temp[decor_iAngle] = json_array_get_number(array, 3);
            temp[decor_iSolid] = json_array_get_number(array, 4);
            SpawnDecor(temp[decor_szName], temp[decor_iOrigin], temp[decor_iAngle], temp[decor_iSolid]);
        }
    }

    json_free(spawns);
    return PLUGIN_HANDLED;
}

public plugin_init()
{
    register_plugin(Plugin_Name, Plugin_Version, Plugin_Author);
    register_dictionary("gm_decor.txt");

    register_clcmd("say /decor", "CmdDecorMenu", ADMIN_RCON);
    register_clcmd("say_team /decor", "CmdDecorMenu", ADMIN_RCON);
    register_clcmd("decor_menu", "CmdDecorMenu", ADMIN_RCON);
    register_menucmd(register_menuid("Decor Menu", 0), KEYS, "Handle_Decor");
    register_menucmd(register_menuid("Rotate Menu", 0), KEYS, "Handle_Rotate");

    @ReadSpawns();
}

public client_connect(pPlayer)
{
    g_iSelectDecor[pPlayer] = -1;
    g_iSolidDecor[pPlayer] = 0;
    formatex(g_szSelectDecor[pPlayer], charsmax(g_szSelectDecor[]), "%l", "DECOR_NONE");
}

public CmdDecorMenu(pPlayer)
{
    static szMenu[MAX_MENU_LENGTH], iLen;
    iLen = 0;

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n^n", "DECOR_TITLE");
    
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ADD");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_MOVE", g_iSelectDecor[pPlayer] == -1 ? "DECOR_NOT_SELECTED" : "DECOR_SELECTED");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_DELETE");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_SAVE");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_DELETE_ALL");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_SELECT", g_szSelectDecor[pPlayer]);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n^n", "DECOR_SOLID", g_iSolidDecor[pPlayer] ? "DECOR_SOLID_YES" : "DECOR_SOLID_NO");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n^n", "DECOR_INFO", ArraySize(g_aDecor), 
        g_szSelectDecor[pPlayer], GetSelectDecorSize(g_szSelectDecor[pPlayer]));

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l", "DECOR_EXIT");

    show_menu(pPlayer, KEYS, szMenu, -1, "Decor Menu");
}

public Handle_Decor(pPlayer, iKey)
{
    switch (iKey)
    {
        case 0: { SpawnDecorPre(pPlayer); }
        case 1: { MoveDecor(pPlayer); }
        case 2: { 
            RotateDecor(pPlayer);
            return;
            }
        case 3: { DeletedAimedDecor(pPlayer); }
        case 4: { 
            SaveDecor();
            client_print_color(pPlayer, print_team_blue, "%l", "DECOR_SAVED");
            }
        case 5: { 
            DeleteAllDecor(); 
            client_print_color(pPlayer, print_team_blue, "%l", "DECOR_DELETED_ALL");
            }
        case 6: { SelectDecor(pPlayer); }
        case 7: { g_iSolidDecor[pPlayer] = !g_iSolidDecor[pPlayer]; }
        case 9: { return; }
    }

    CmdDecorMenu(pPlayer);
}

public SpawnDecorPre(pPlayer)
{
    if (!strcmp(g_szSelectDecor[pPlayer], fmt("%l", "DECOR_NONE")))
    {
        return PLUGIN_HANDLED;
    }

    new iOrigin[3];
    get_user_origin(pPlayer, iOrigin, Origin_AimEndEyes);
    if (SpawnDecor(g_szSelectDecor[pPlayer], iOrigin, 0, g_iSolidDecor[pPlayer]))
    {
        client_print_color(pPlayer, print_team_blue, "%l", "DECOR_SPAWNED");
    }
    else
    {
        client_print_color(pPlayer, print_team_red, "%l", "DECOR_NOT_SPAWNED");
    }

    return PLUGIN_HANDLED;
}

public bool: SpawnDecor(szName[], iOrigin[], iAngle, iSolid)
{
    new pEnt = rg_create_entity("info_target");

    if (!pEnt)
    {
        log_amx("Error create %s!", szName);
        return false;
    }

    new Float:fOrigin[3], Float:fAngles[3];
    fOrigin[0] = float(iOrigin[0]);
    fOrigin[1] = float(iOrigin[1]);
    fOrigin[2] = float(iOrigin[2]);
    fAngles[1] = float(iAngle);

    set_entvar(pEnt, var_classname, CLASSNAME);
    set_entvar(pEnt, var_movetype, MOVETYPE_NONE);

    new szModel[128];
    TrieGetString(g_tDecorModel, szName, szModel, charsmax(szModel));
    set_entvar(pEnt, var_model, szModel);
    set_entvar(pEnt, var_modelindex, engfunc(EngFunc_ModelIndex, szModel));

    set_entvar(pEnt, var_origin, fOrigin);
    set_entvar(pEnt, var_angles, fAngles);
    
    if (iSolid)
    {
        set_entvar(pEnt, var_solid, SOLID_BBOX);
    }
    else
    {
        set_entvar(pEnt, var_solid, SOLID_TRIGGER);
    }

    new Float:fMaxs[3], Float:fMins[3], Float:fSize[3];
    UTIL_GetModelHitBox(szModel, fMaxs, fMins, fSize);

    engfunc(EngFunc_SetSize, pEnt, fMins, fMaxs);
    drop_to_floor(pEnt);

    new temp[structDecor];
    copy(temp[decor_szName], charsmax(temp[decor_szName]), szName);
    temp[decor_iOrigin][0] = iOrigin[0];
    temp[decor_iOrigin][1] = iOrigin[1];
    temp[decor_iOrigin][2] = iOrigin[2];
    temp[decor_iAngle] = iAngle;
    temp[decor_iSolid] = iSolid;

    ArrayPushArray(g_aDecor, temp);
    ArrayPushCell(g_aDecorEnt, pEnt);
    return true;
}

stock MoveDecor(pPlayer)
{

    if (is_entity(g_iSelectDecor[pPlayer]))
    {
        new iOrigin[3];
        get_user_origin(pPlayer, iOrigin, Origin_AimEndEyes);

        new Float:fOrigin[3];
        IVecFVec(iOrigin, fOrigin);

        new Float:fMaxs[3], Float:fMins[3];
        get_entvar(g_iSelectDecor[pPlayer], var_maxs, fMaxs);
        get_entvar(g_iSelectDecor[pPlayer], var_mins, fMins);

        for (new i; i < 3; i++)
        {
            fMaxs[i] += fOrigin[i];
            fMins[i] += fOrigin[i];
        }

        
        set_entvar(g_iSelectDecor[pPlayer], var_origin, fOrigin);
        set_entvar(g_iSelectDecor[pPlayer], var_absmax, fMaxs);
        set_entvar(g_iSelectDecor[pPlayer], var_absmin, fMins);

        client_print_color(pPlayer, print_team_blue, "%l", "DECOR_MOVED");

        set_entvar(g_iSelectDecor[pPlayer], var_rendermode, kRenderNormal);
        set_entvar(g_iSelectDecor[pPlayer], var_renderamt, 0.0);
        UpdateDecor(g_iSelectDecor[pPlayer]);
        g_iSelectDecor[pPlayer] = -1;
        return;
    }


    g_iSelectDecor[pPlayer] = GetEntAimedDecor(pPlayer);
    
    if (g_iSelectDecor[pPlayer] == -1)
    {
        client_print_color(pPlayer, print_team_red, "%l", "DECOR_NOT_FOUND");
        return;
    }

    set_entvar(g_iSelectDecor[pPlayer], var_rendermode, kRenderTransAdd);
    set_entvar(g_iSelectDecor[pPlayer], var_renderamt, 50.0);
    client_print_color(pPlayer, print_team_blue, "%l", "DECOR_MOVE_SELECTED");
    return;
}

stock RotateDecor(pPlayer)
{

    if (is_entity(g_iSelectDecor[pPlayer]))
    {
        RotateDecorMenu(pPlayer);
        return;
    }

    g_iSelectDecor[pPlayer] = GetEntAimedDecor(pPlayer);
    
    if (g_iSelectDecor[pPlayer] == -1)
    {
        client_print_color(pPlayer, print_team_red, "%l", "DECOR_NOT_FOUND");
        CmdDecorMenu(pPlayer);
        return;
    }

    set_entvar(g_iSelectDecor[pPlayer], var_renderfx, kRenderFxGlowShell);
    set_entvar(g_iSelectDecor[pPlayer], var_rendercolor, {150.0, 0.0, 0.0});
    RotateDecorMenu(pPlayer);
}

public RotateDecorMenu(pPlayer)
{
    static szMenu[MAX_MENU_LENGTH], iLen;
    iLen = 0;

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_TITLE");

    new Float:fAngles[3];
    get_entvar(g_iSelectDecor[pPlayer], var_angles, fAngles);

    new iAngles[3];
    FVecIVec(fAngles, iAngles);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n^n", "DECOR_ROTATE_INFO", iAngles[1]);
    
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_LEFT", 1, 15);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_RIGHT", 2, 15);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_LEFT", 3, 60);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_RIGHT", 4, 60);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_LEFT", 5, 90);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "DECOR_ROTATE_RIGHT", 6, 90);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n^n", "DECOR_ROTATE_180");

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l", "DECOR_BACK");
    show_menu(pPlayer, KEYS, szMenu, -1, "Rotate Menu");
}

public Handle_Rotate(pPlayer, iKey)
{
    if (iKey == 9)
    {
        UpdateDecor(g_iSelectDecor[pPlayer]);
        set_entvar(g_iSelectDecor[pPlayer], var_renderfx, kRenderFxNone);
        set_entvar(g_iSelectDecor[pPlayer], var_rendercolor, 0.0);
        g_iSelectDecor[pPlayer] = -1;
        CmdDecorMenu(pPlayer);
        return;
    }

    new Float:fAngles[3];
    get_entvar(g_iSelectDecor[pPlayer], var_angles, fAngles);
    
    switch (iKey)
    {
        case 0: { fAngles[1] -= 15; }
        case 1: { fAngles[1] += 15; }
        case 2: { fAngles[1] -= 60; }
        case 3: { fAngles[1] += 60; }
        case 4: { fAngles[1] -= 90; }
        case 5: { fAngles[1] += 90; }
        case 9: { fAngles[1] += 180; }
    }

    if (fAngles[1] > 180.0)
    {
        fAngles[1]  -= 360.0
    }
    else
    if (fAngles[1] < -180.0)
    {
        fAngles[1] += 360.0
    }

    set_entvar(g_iSelectDecor[pPlayer], var_angles, fAngles);

    RotateDecorMenu(pPlayer);
    return;
}

stock DeletedAimedDecor(pPlayer)
{
    new pEnt = GetEntAimedDecor(pPlayer);
    
    if (pEnt != -1)
    {
        rg_remove_entity(pEnt);
        new i = ArrayFindValue(g_aDecorEnt, pEnt);
        ArrayDeleteItem(g_aDecor, i);
        ArrayDeleteItem(g_aDecorEnt, i);
        
        SaveDecor();
    }
}


stock SaveDecor()
{
    new iSize = ArraySize(g_aDecor);
    delete_file(g_szDecorSpawns);

    if (!iSize)
    {
        return;
    }

    new temp[structDecor];
    new JSON: file = json_init_object();
    
    for (new i = 0; i < iSize; i++)
    {
        ArrayGetArray(g_aDecor, i, temp, structDecor);

        new JSON:arrays;
        
        if ((arrays = json_object_get_value(file, temp[decor_szName])) == Invalid_JSON)
        {
            arrays = json_init_array();
            json_object_set_value(file, temp[decor_szName], arrays);
        } 

        new JSON:array = json_init_array();
        json_array_append_number(array, temp[decor_iOrigin][0]);
        json_array_append_number(array, temp[decor_iOrigin][1]);
        json_array_append_number(array, temp[decor_iOrigin][2]);
        json_array_append_number(array, temp[decor_iAngle]);
        json_array_append_number(array, temp[decor_iSolid]);
        json_array_append_value(arrays, array);
        json_free(array);
    }

    json_serial_to_file(file, g_szDecorSpawns, true);
    json_free(file);
}

stock DeleteAllDecor()
{
    if (g_aDecor)
    {
        ArrayClear(g_aDecor);
        ArrayClear(g_aDecorEnt);
    }

    delete_file(g_szDecorSpawns);
    
    new pEnt;
    while ((pEnt = rg_find_ent_by_class(pEnt, CLASSNAME)))
    {
        if (pEnt) rg_remove_entity(pEnt);
    }
}

stock SelectDecor(pPlayer)
{
    if (TrieGetSize(g_tDecorModel) < 2) 
    {
        return;
    }

    new szName[32], count;
    new TrieIter: iter = TrieIterCreate(g_tDecorModel);
    new iSize = TrieIterGetSize(iter);

    while (!TrieIterEnded(iter))
    {
        TrieIterGetKey(iter, szName, charsmax(szName));

        if (!strcmp(szName, g_szSelectDecor[pPlayer]))
        {
            if (++count != iSize)
            {
                TrieIterNext(iter);
                TrieIterGetKey(iter, g_szSelectDecor[pPlayer], charsmax(g_szSelectDecor[]));
                TrieIterDestroy(iter);
                return;
            }
        }

        ++count;
        TrieIterNext(iter);
    }

    TrieIterDestroy(iter);
    iter = TrieIterCreate(g_tDecorModel);
    TrieIterGetKey(iter, g_szSelectDecor[pPlayer], charsmax(g_szSelectDecor[]));
    return;
}

stock GetSelectDecorSize(szDecor[])
{
    new iSize = ArraySize(g_aDecor);
    new iCount;

    for (new i; i < iSize; i++)
    {
        static szName[32];
        ArrayGetString(g_aDecor, i, szName, charsmax(szName));
        
        if (!strcmp(szName, szDecor))
        {
            ++iCount;
        }
    }

    return iCount;
}

stock GetEntAimedDecor(pPlayer)
{
    new iOrigin[3];
    get_user_origin(pPlayer, iOrigin, Origin_AimEndEyes);

    set_trail(pPlayer, iOrigin);
    new Float:fOrigin[3];
    IVecFVec(iOrigin, fOrigin);

    new pEnt;
    while ((pEnt = find_ent_in_sphere(pEnt, fOrigin, 40.0)))
    {
        static szClassName[12];
        get_entvar(pEnt, var_classname, szClassName, charsmax(szClassName));

        if (!strcmp(CLASSNAME, szClassName))
        {
            return pEnt;
        }
    }

    return -1;
}

#if REAPI_VERSION < 524300  

stock rg_remove_entity(pEnt)
{
	set_entvar(pEnt, var_flags, FL_KILLME);
	set_entvar(pEnt, var_nextthink, -1.0);
}

#endif

/**
 * Получает размеры хитбоксов у модели
 * 
 * @param szModel  Путь до модели (Пр. "models/bag.mdl")
 * @param flMaxs   Local BB max.
 * @param flMins   Local BB min.
 * @param flSize   max - min
 * 
 * @return         true/false
 */

stock bool:UTIL_GetModelHitBox(const szModel[], Float: flMaxs[3], Float: flMins[3], Float: flSize[3])
{
    new hFile = fopen(szModel, "rb");

    if (!hFile)
    {
        server_print("Can`t open %s", szModel);
        return false;
    }

    fseek(hFile, 160, SEEK_SET);

    new iBlock;
    fread(hFile, iBlock, BLOCK_INT);
    fseek(hFile, iBlock + 8, SEEK_SET);
    
    new Float: flVec[6];
    fread_blocks(hFile, _:flVec, 6, BLOCK_INT);
    fclose(hFile);

    flMins[0] = flVec[0];
    flMins[1] = flVec[1];
    flMins[2] = flVec[2];
    flMaxs[0] = flVec[3];
    flMaxs[1] = flVec[4];
    flMaxs[2] = flVec[5];
    flSize[0] = flVec[3] - flVec[0];
    flSize[1] = flVec[4] - flVec[1];
    flSize[2] = flVec[5] - flVec[2];

    return true;
}

stock set_trail(const iEnt, origin[])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMENTPOINT)
    write_short(iEnt)
    write_coord(origin[0])
    write_coord(origin[1])
    write_coord(origin[2])
    write_short(g_iSprite)
    write_byte(0)
    write_byte(0)
    write_byte(10) 
    write_byte(15) 
    write_byte(0)
    write_byte(255) 
    write_byte(255) 
    write_byte(255) 
    write_byte(150) 
    write_byte(0)
    message_end()
}

stock UpdateDecor(pEnt)
{
    new index = ArrayFindValue(g_aDecorEnt, pEnt);

    new temp[structDecor];
    ArrayGetArray(g_aDecor, index, temp, structDecor);

    new Float:fOrigin[3], Float:fAngles[3], iOrigin[3];

    get_entvar(pEnt, var_origin, fOrigin);
    get_entvar(pEnt, var_angles, fAngles);

    FVecIVec(fOrigin, iOrigin);
    temp[decor_iOrigin][0] = iOrigin[0];
    temp[decor_iOrigin][1] = iOrigin[1];
    temp[decor_iOrigin][2] = iOrigin[2];
    temp[decor_iAngle] = floatround(fAngles[1]);

    ArraySetArray(g_aDecor, index, temp, structDecor);
}
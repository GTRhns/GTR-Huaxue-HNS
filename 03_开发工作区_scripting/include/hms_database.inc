// Credentials come from the same mixsystem/hnsmatch-sql.cfg used by match/skin SQL.
stock bool:Hms_LoadSqlConfig()
{
    new configsDir[192], path[256], line[256], key[64], value[160];
    get_configsdir(configsDir, charsmax(configsDir));
    formatex(path, charsmax(path), "%s/mixsystem/hnsmatch-sql.cfg", configsDir);

    g_SqlHost[0] = 0;
    g_SqlUser[0] = 0;
    g_SqlPass[0] = 0;
    g_SqlDb[0] = 0;

    new file = fopen(path, "rt");
    if (!file)
    {
        g_SqlConfigLoaded = false;
        copy(g_SqlLastError, charsmax(g_SqlLastError), "Cannot open mixsystem/hnsmatch-sql.cfg");
        log_amx("[HMS] SQL config missing: %s. SQL stays unavailable; local movement stats continue.", path);
        return false;
    }

    while (!feof(file))
    {
        line[0] = 0;
        fgets(file, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';' || line[0] == '#' || line[0] == '/')
            continue;
        key[0] = 0;
        value[0] = 0;
        parse(line, key, charsmax(key), value, charsmax(value));
        if (equali(key, "hns_host") || equali(key, "host")) copy(g_SqlHost, charsmax(g_SqlHost), value);
        else if (equali(key, "hns_user") || equali(key, "user")) copy(g_SqlUser, charsmax(g_SqlUser), value);
        else if (equali(key, "hns_pass") || equali(key, "pass")) copy(g_SqlPass, charsmax(g_SqlPass), value);
        else if (equali(key, "hns_db") || equali(key, "database") || equali(key, "db")) copy(g_SqlDb, charsmax(g_SqlDb), value);
        else if (equali(key, "timeout")) g_SqlTimeout = str_to_num(value);
    }
    fclose(file);

    if (equal(g_SqlPass, "CHANGE_ME"))
    {
        g_SqlConfigLoaded = false;
        copy(g_SqlLastError, charsmax(g_SqlLastError), "Change the sample SQL password in mixsystem/hnsmatch-sql.cfg");
        log_amx("[HMS] SQL password is still the sample placeholder. Set it in configs/mixsystem/hnsmatch-sql.cfg before enabling SQL.");
        return false;
    }

    if (!g_SqlHost[0] || !g_SqlUser[0] || !g_SqlDb[0])
    {
        g_SqlConfigLoaded = false;
        copy(g_SqlLastError, charsmax(g_SqlLastError), "SQL config incomplete: hns_host/hns_user/hns_db required");
        log_amx("[HMS] SQL config incomplete (hns_host/hns_user/hns_db required). SQL stays unavailable.");
        return false;
    }

    if (g_SqlTimeout < 1) g_SqlTimeout = 8;
    if (g_SqlTimeout > 30) g_SqlTimeout = 30;
    g_SqlConfigLoaded = true;
    return true;
}

stock Hms_DatabaseInit()
{
    if (!get_pcvar_num(pcvar_sql_enabled))
    {
        Hms_DatabaseClose();
        g_SqlEnabled = false;
        g_SqlConnected = false;
        g_SqlProbePending = false;
        g_SqlProbeCompleted = false;
        g_SqlSchemaCheckPending = false;
        g_SqlSchemaCheckCompleted = false;
        g_SqlSchemaValid = false;
        g_SqlMigratePending = false;
        g_SqlMigrateCompleted = false;
        copy(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "Not checked");
        copy(g_SqlLastError, charsmax(g_SqlLastError), "SQL disabled by hms_sql_enabled; using local mode");
        return;
    }

    if (!Hms_LoadSqlConfig())
    {
        Hms_DatabaseClose();
        g_SqlEnabled = false;
        g_SqlConnected = false;
        g_SqlProbePending = false;
        g_SqlProbeCompleted = false;
        g_SqlSchemaCheckPending = false;
        g_SqlSchemaCheckCompleted = false;
        g_SqlSchemaValid = false;
        g_SqlMigratePending = false;
        g_SqlMigrateCompleted = false;
        copy(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "SQL config not loaded");
        return;
    }

    Hms_DatabaseClose();
    new timeout = get_pcvar_num(pcvar_sql_timeout);
    if (timeout < 1) timeout = g_SqlTimeout;
    if (timeout > 30) timeout = 30;

    g_SqlTuple = SQL_MakeDbTuple(g_SqlHost, g_SqlUser, g_SqlPass, g_SqlDb, timeout);
    g_SqlEnabled = (g_SqlTuple != Empty_Handle);
    g_SqlConnected = false;
    g_SqlProbeCompleted = false;
    g_SqlSchemaCheckPending = false;
    g_SqlSchemaCheckCompleted = false;
    g_SqlSchemaValid = false;
    g_SqlMigratePending = false;
    g_SqlMigrateCompleted = false;
    copy(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "Not checked");
    if (g_SqlEnabled)
    {
        SQL_SetCharset(g_SqlTuple, "utf8mb4");
        copy(g_SqlLastError, charsmax(g_SqlLastError), "Tuple ready; live SELECT 1 test pending");
        log_amx("[HMS] SQL tuple initialized from mixsystem/hnsmatch-sql.cfg. Live connectivity is being tested (credentials are not logged).");
        Hms_StartSqlProbe(0);
        Hms_StartSchemaEnsure();
    }
    else
    {
        copy(g_SqlLastError, charsmax(g_SqlLastError), "Failed to create SQL tuple");
        log_amx("[HMS] Failed to create SQL tuple; local movement stats remain available.");
    }
}

stock Hms_DatabaseClose()
{
    if (g_SqlTuple != Empty_Handle)
    {
        SQL_FreeHandle(g_SqlTuple);
        g_SqlTuple = Empty_Handle;
    }
}

stock Hms_DatabaseReload()
{
    g_SqlGeneration++;
    Hms_DatabaseClose();
    g_SqlEnabled = false;
    g_SqlConnected = false;
    g_SqlProbePending = false;
    g_SqlProbeCompleted = false;
    g_SqlMigratePending = false;
    g_SqlMigrateCompleted = false;
    g_SqlSchemaCheckPending = false;
    g_SqlSchemaCheckCompleted = false;
    g_SqlSchemaValid = false;
    copy(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "Not checked");
    Hms_DatabaseInit();
    g_DatabaseInitDone = true;

    // A runtime SQL reload rehydrates already-connected human players too.
    // Dirty local choices retain priority over the asynchronous load callbacks.
    if (g_SqlEnabled)
    {
        for (new id = 1; id <= HMS_MAX_PLAYERS; id++)
        {
            if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
                continue;
            g_LoadStarted[id] = false;
            Hms_LoadPlayer(id);
        }
    }
}

stock Hms_StartSqlProbe(requester)
{
    if (!g_SqlEnabled || g_SqlTuple == Empty_Handle)
    {
        if (requester > 0 && is_user_connected(requester))
            client_print(requester, print_chat, "[HMS] SQL test unavailable. Check hms_sql_enabled and configs/mixsystem/hnsmatch-sql.cfg.");
        return;
    }
    if (g_SqlProbePending)
    {
        if (requester > 0 && is_user_connected(requester))
            client_print(requester, print_chat, "[HMS] An SQL connectivity test is already pending.");
        return;
    }
    new data[3];
    data[0] = requester;
    data[1] = requester > 0 && is_user_connected(requester) ? get_user_userid(requester) : 0;
    data[2] = g_SqlGeneration;
    g_SqlProbePending = true;
    SQL_ThreadQuery(g_SqlTuple, "Hms_AdminSqlProbeCallback", "SELECT 1", data, sizeof data);
}

public Hms_AdminSqlTest(id)
{
    Hms_StartSqlProbe(id);
}

stock Hms_StartHudStyleMigrate()
{
    Hms_StartSchemaEnsure();
}

stock Hms_StartSchemaEnsure()
{
    if (!g_SqlEnabled || g_SqlTuple == Empty_Handle || g_SqlMigratePending)
        return;

    new data[4];
    data[0] = 0;
    data[1] = 0;
    data[2] = g_SqlGeneration;
    data[3] = 0;
    g_SqlMigratePending = true;
    g_SqlMigrateCompleted = false;
    Hms_RunSchemaStep(data, sizeof data);
}

stock Hms_RunSchemaStep(data[], datasize)
{
    if (datasize < 4)
        return;

    new query[1536];
    switch (data[3])
    {
        case 0:
            copy(query, charsmax(query), "CREATE TABLE IF NOT EXISTS hms_players (authid VARCHAR(64) NOT NULL,last_name VARCHAR(64) NOT NULL DEFAULT '',first_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,last_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (authid)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        case 1:
            copy(query, charsmax(query), "CREATE TABLE IF NOT EXISTS hms_player_settings (authid VARCHAR(64) NOT NULL,hud_enabled TINYINT NOT NULL DEFAULT 1,sounds_enabled TINYINT NOT NULL DEFAULT 0,takeoff_enabled TINYINT NOT NULL DEFAULT 0,landing_enabled TINYINT NOT NULL DEFAULT 0,achievement_enabled TINYINT NOT NULL DEFAULT 0,chatstats_enabled TINYINT NOT NULL DEFAULT 0,hud_style TINYINT NOT NULL DEFAULT 1,style_pick TINYINT NOT NULL DEFAULT 0,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (authid)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        case 2:
            copy(query, charsmax(query), "CREATE TABLE IF NOT EXISTS hms_hud_layout (authid VARCHAR(64) NOT NULL,field_id TINYINT NOT NULL,enabled TINYINT NOT NULL DEFAULT 0,hud_x INT NOT NULL DEFAULT 0,hud_y INT NOT NULL DEFAULT 0,color_id TINYINT NOT NULL DEFAULT 0,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (authid,field_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        case 3:
            copy(query, charsmax(query), "CREATE TABLE IF NOT EXISTS hms_hud_panels (authid VARCHAR(64) NOT NULL,panel_id TINYINT NOT NULL,enabled TINYINT NOT NULL DEFAULT 0,hud_x INT NOT NULL DEFAULT 0,hud_y INT NOT NULL DEFAULT 0,color_id TINYINT NOT NULL DEFAULT 0,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (authid,panel_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        case 4:
            copy(query, charsmax(query), "CREATE TABLE IF NOT EXISTS hms_movement_totals (authid VARCHAR(64) NOT NULL,session_max_speed FLOAT NOT NULL DEFAULT 0,max_bhop_chain INT NOT NULL DEFAULT 0,jumps INT NOT NULL DEFAULT 0,landings INT NOT NULL DEFAULT 0,low_speed_events INT NOT NULL DEFAULT 0,strafe_samples INT NOT NULL DEFAULT 0,strafe_good INT NOT NULL DEFAULT 0,air_turns INT NOT NULL DEFAULT 0,fog_total_frames INT NOT NULL DEFAULT 0,fog_samples INT NOT NULL DEFAULT 0,distance_units FLOAT NOT NULL DEFAULT 0,sessions INT NOT NULL DEFAULT 0,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (authid)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        case 5:
            copy(query, charsmax(query), "CREATE TABLE IF NOT EXISTS hms_jump_events (id INT NOT NULL AUTO_INCREMENT,authid VARCHAR(64) NOT NULL,map_name VARCHAR(64) NOT NULL DEFAULT '',jump_type VARCHAR(16) NOT NULL DEFAULT '',distance_units FLOAT NOT NULL DEFAULT 0,takeoff_speed FLOAT NOT NULL DEFAULT 0,max_air_speed FLOAT NOT NULL DEFAULT 0,landing_speed FLOAT NOT NULL DEFAULT 0,air_time FLOAT NOT NULL DEFAULT 0,fog_frames INT NOT NULL DEFAULT 0,strafe_gain FLOAT NOT NULL DEFAULT 0,strafe_loss FLOAT NOT NULL DEFAULT 0,turn_sync FLOAT NOT NULL DEFAULT 0,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (id),KEY idx_authid (authid)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        default:
        {
            Hms_StartHudStyleColumnCheck(data, datasize);
            return;
        }
    }

    SQL_ThreadQuery(g_SqlTuple, "Hms_SchemaEnsureCallback", query, data, datasize);
}

public Hms_SchemaEnsureCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
        log_amx("[HMS] Schema CREATE TABLE step %d failed (%d): %s", datasize >= 4 ? data[3] : -1, errcode, error);
    else if (datasize >= 4)
        log_amx("[HMS] Schema CREATE TABLE step %d completed.", data[3]);

    if (datasize >= 4)
        data[3]++;
    Hms_RunSchemaStep(data, datasize);
}

stock Hms_StartHudStyleColumnCheck(data[], datasize)
{
    new cbData[3], query[384];
    cbData[0] = datasize > 0 ? data[0] : 0;
    cbData[1] = datasize > 1 ? data[1] : 0;
    cbData[2] = datasize > 2 ? data[2] : g_SqlGeneration;
    copy(query, charsmax(query), "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='hms_player_settings' AND COLUMN_NAME='hud_style'");
    SQL_ThreadQuery(g_SqlTuple, "Hms_HudStyleColumnCallback", query, cbData, sizeof cbData);
}

public Hms_HudStyleColumnCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("[HMS] HUD style column check failed (%d): %s. Trying ALTER anyway.", errcode, error);
        new failData[3];
        failData[0] = data[0];
        failData[1] = data[1];
        failData[2] = data[2];
        SQL_ThreadQuery(g_SqlTuple, "Hms_HudStyleAlterCallback",
            "ALTER TABLE hms_player_settings ADD COLUMN hud_style TINYINT NOT NULL DEFAULT 1",
            failData, sizeof failData);
        return;
    }

    new exists = SQL_ReadResult(query, 0);
    if (exists > 0)
    {
        Hms_StartStylePickColumnCheck(data, datasize);
        return;
    }

    new cbData[3];
    cbData[0] = data[0];
    cbData[1] = data[1];
    cbData[2] = data[2];
    SQL_ThreadQuery(g_SqlTuple, "Hms_HudStyleAlterCallback",
        "ALTER TABLE hms_player_settings ADD COLUMN hud_style TINYINT NOT NULL DEFAULT 1",
        cbData, sizeof cbData);
}

public Hms_HudStyleAlterCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate == TQUERY_SUCCESS)
        log_amx("[HMS] Added hud_style to hms_player_settings on the match SQL database.");
    else
        log_amx("[HMS] hud_style ALTER failed (%d): %s", errcode, error);
    Hms_StartStylePickColumnCheck(data, datasize);
}

stock Hms_StartStylePickColumnCheck(data[], datasize)
{
    new cbData[3], query[384];
    cbData[0] = datasize > 0 ? data[0] : 0;
    cbData[1] = datasize > 1 ? data[1] : 0;
    cbData[2] = datasize > 2 ? data[2] : g_SqlGeneration;
    copy(query, charsmax(query), "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='hms_player_settings' AND COLUMN_NAME='style_pick'");
    SQL_ThreadQuery(g_SqlTuple, "Hms_StylePickColumnCallback", query, cbData, sizeof cbData);
}

public Hms_StylePickColumnCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("[HMS] style_pick column check failed (%d): %s. Trying ALTER anyway.", errcode, error);
        new failData[3];
        failData[0] = data[0];
        failData[1] = data[1];
        failData[2] = data[2];
        SQL_ThreadQuery(g_SqlTuple, "Hms_StylePickAlterCallback",
            "ALTER TABLE hms_player_settings ADD COLUMN style_pick TINYINT NOT NULL DEFAULT 0",
            failData, sizeof failData);
        return;
    }

    if (SQL_ReadResult(query, 0) > 0)
    {
        g_SqlMigratePending = false;
        g_SqlMigrateCompleted = true;
        return;
    }

    new cbData[3];
    cbData[0] = data[0];
    cbData[1] = data[1];
    cbData[2] = data[2];
    SQL_ThreadQuery(g_SqlTuple, "Hms_StylePickAlterCallback",
        "ALTER TABLE hms_player_settings ADD COLUMN style_pick TINYINT NOT NULL DEFAULT 0",
        cbData, sizeof cbData);
}

public Hms_StylePickAlterCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    g_SqlMigratePending = false;
    g_SqlMigrateCompleted = true;
    if (failstate == TQUERY_SUCCESS)
        log_amx("[HMS] Added style_pick to hms_player_settings. Unpicked classic defaults become KZ center.");
    else
        log_amx("[HMS] style_pick ALTER failed (%d): %s", errcode, error);
}

public Hms_AdminSqlProbeCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    g_SqlProbePending = false;
    g_SqlProbeCompleted = true;
    g_SqlConnected = (failstate == TQUERY_SUCCESS);
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (datasize >= 2 && data[0] > 0 && is_user_connected(data[0]) && get_user_userid(data[0]) == data[1])
    {
        if (failstate == TQUERY_SUCCESS)
            client_print(data[0], print_chat, "[HMS] SQL connectivity test PASSED (SELECT 1, queue %.3fs).", queuetime);
        else
            client_print(data[0], print_chat, "[HMS] SQL connectivity test FAILED (%d): %s", errcode, error);
    }
}

stock Hms_StartSqlSchemaCheck(requester)
{
    if (!g_SqlEnabled || g_SqlTuple == Empty_Handle)
    {
        if (requester > 0 && is_user_connected(requester))
            client_print(requester, print_chat, "[HMS] Schema check unavailable: SQL is not configured/enabled.");
        return;
    }
    if (g_SqlSchemaCheckPending)
    {
        if (requester > 0 && is_user_connected(requester))
            client_print(requester, print_chat, "[HMS] Schema check already pending.");
        return;
    }

    new data[3], query[2048];
    data[0] = requester;
    data[1] = requester > 0 && is_user_connected(requester) ? get_user_userid(requester) : 0;
    data[2] = g_SqlGeneration;
    g_SqlSchemaCheckPending = true;
    g_SqlSchemaCheckCompleted = false;
    copy(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "Schema check pending");
    // LIMIT 0 makes the query validate every required table/column without reading player data.
    // A missing/renamed column makes SQL fail, rather than reporting a misleading table-only PASS.
    copy(query, charsmax(query), "SELECT p.authid,p.last_name,p.first_seen,p.last_seen,");
    add(query, charsmax(query), "m.session_max_speed,m.max_bhop_chain,m.jumps,m.landings,m.low_speed_events,m.strafe_samples,m.strafe_good,m.air_turns,m.fog_total_frames,m.fog_samples,m.distance_units,m.sessions,m.updated_at,");
    add(query, charsmax(query), "s.hud_enabled,s.sounds_enabled,s.takeoff_enabled,s.landing_enabled,s.achievement_enabled,s.chatstats_enabled,s.hud_style,s.style_pick,s.updated_at,");
    add(query, charsmax(query), "l.field_id,l.enabled,l.hud_x,l.hud_y,l.color_id,l.updated_at,");
    add(query, charsmax(query), "hp.panel_id,hp.enabled,hp.hud_x,hp.hud_y,hp.color_id,hp.updated_at,");
    add(query, charsmax(query), "je.id,je.authid,je.map_name,je.jump_type,je.distance_units,je.takeoff_speed,je.max_air_speed,je.landing_speed,je.air_time,je.fog_frames,je.strafe_gain,je.strafe_loss,je.turn_sync,je.created_at ");
    add(query, charsmax(query), "FROM hms_players p ");
    add(query, charsmax(query), "LEFT JOIN hms_movement_totals m ON m.authid=p.authid ");
    add(query, charsmax(query), "LEFT JOIN hms_player_settings s ON s.authid=p.authid ");
    add(query, charsmax(query), "LEFT JOIN hms_hud_layout l ON l.authid=p.authid ");
    add(query, charsmax(query), "LEFT JOIN hms_hud_panels hp ON hp.authid=p.authid ");
    add(query, charsmax(query), "LEFT JOIN hms_jump_events je ON je.authid=p.authid LIMIT 0");
    SQL_ThreadQuery(g_SqlTuple, "Hms_AdminSqlSchemaCallback", query, data, sizeof data);
}

public Hms_AdminSqlSchemaCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    g_SqlSchemaCheckPending = false;
    g_SqlSchemaCheckCompleted = true;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate == TQUERY_SUCCESS)
    {
        g_SqlSchemaValid = true;
        copy(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "All 6 HMS tables and required columns are present");
    }
    else
    {
        g_SqlSchemaValid = false;
        formatex(g_SqlSchemaMessage, charsmax(g_SqlSchemaMessage), "Schema query failed (%d): %s", errcode, error);
        log_amx("[HMS] Schema check failed (%d): %s", errcode, error);
    }

    if (datasize >= 2 && data[0] > 0 && is_user_connected(data[0]) && get_user_userid(data[0]) == data[1])
    {
        if (g_SqlSchemaValid)
            client_print(data[0], print_chat, "[HMS] Schema check PASSED: all six tables and required columns exist.");
        else
            client_print(data[0], print_chat, "[HMS] Schema check FAILED (%d): %s", errcode, error);
    }
}

stock Hms_RecordSqlStatus(failstate, const error[], errcode, Float:queuetime)
{
    g_SqlLastQueueTime = queuetime;
    if (failstate != TQUERY_SUCCESS)
    {
        g_SqlFailureCount++;
        g_SqlErrorCode = errcode;
        copy(g_SqlLastError, charsmax(g_SqlLastError), error);
        log_amx("[HMS] SQL query failed (%d): %s", errcode, error);
    }
    else
    {
        g_SqlSuccessCount++;
        g_SqlLastSuccessTime = get_gametime();
        g_SqlErrorCode = 0;
        copy(g_SqlLastError, charsmax(g_SqlLastError), "No error reported by latest query");
    }
}

public Hms_LoadPlayer(taskid)
{
    new id = taskid;
    if (id < 1 || id > HMS_MAX_PLAYERS || !is_user_connected(id) || g_LoadStarted[id] || !g_SqlEnabled)
        return;

    if (!g_AuthId[id][0])
        get_user_authid(id, g_AuthId[id], charsmax(g_AuthId[]));

    if (!g_AuthId[id][0] || equal(g_AuthId[id], "STEAM_ID_PENDING"))
    {
        if (g_AuthRetryCount[id]++ < 10)
            set_task(1.0, "Hms_LoadPlayer", id);
        return;
    }

    if (g_SqlMigratePending && !g_SqlMigrateCompleted)
    {
        if (g_AuthRetryCount[id]++ < 20)
            set_task(0.25, "Hms_LoadPlayer", id);
        return;
    }

    new quotedAuth[80], query[512], data[3];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0)
        return;

    g_LoadStarted[id] = true;
    if (g_SettingsDirtyMask[id])
        Hms_QueuePrefsSave(id, g_SettingsDirtyMask[id]);
    data[0] = id;
    data[1] = get_user_userid(id);
    data[2] = g_SqlGeneration;
    formatex(query, charsmax(query),
        "INSERT INTO hms_players (authid,last_name) VALUES ('%s','') ON DUPLICATE KEY UPDATE last_seen=CURRENT_TIMESTAMP",
        quotedAuth);
    SQL_ThreadQuery(g_SqlTuple, "Hms_PlayerEnsureCallback", query, data, sizeof data);
}

public Hms_PlayerEnsureCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("[HMS] Player row query failed (%d): %s", errcode, error);
        return;
    }

    new id = data[0];
    if (!Hms_CallbackPlayerValid(id, data, datasize)) return;

    new quotedAuth[80], queryText[256], cbData[3];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;
    formatex(queryText, charsmax(queryText),
        "INSERT IGNORE INTO hms_player_settings (authid) VALUES ('%s')", quotedAuth);
    cbData[0] = id;
    cbData[1] = data[1];
    cbData[2] = data[2];
    SQL_ThreadQuery(g_SqlTuple, "Hms_SettingsEnsureCallback", queryText, cbData, sizeof cbData);
}

public Hms_SettingsEnsureCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("[HMS] Settings row query failed (%d): %s", errcode, error);
        return;
    }

    new id = data[0];
    if (!Hms_CallbackPlayerValid(id, data, datasize)) return;

    new quotedAuth[80], queryText[512], cbData[3];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;
    formatex(queryText, charsmax(queryText),
        "SELECT hud_enabled,sounds_enabled,takeoff_enabled,landing_enabled,achievement_enabled,chatstats_enabled,hud_style,style_pick FROM hms_player_settings WHERE authid='%s' LIMIT 1", quotedAuth);
    cbData[0] = id;
    cbData[1] = data[1];
    cbData[2] = data[2];
    SQL_ThreadQuery(g_SqlTuple, "Hms_LoadPreferencesCallback", queryText, cbData, sizeof cbData);
}

public Hms_LoadPreferencesCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("[HMS] Preferences load query failed (%d): %s", errcode, error);
        Hms_StartHudLayoutLoad(data, datasize);
        return;
    }

    new id = data[0];
    if (!Hms_CallbackPlayerValid(id, data, datasize))
        return;

    if (SQL_NumResults(query) >= 1 && !(g_SettingsTouchedMask[id] & HMS_DIRTY_PREFS))
    {
        g_Player[id][pHudEnabled] = SQL_ReadResult(query, 0) != 0;
        g_Player[id][pSoundsEnabled] = SQL_ReadResult(query, 1) != 0;
        g_Player[id][pTakeoffSound] = SQL_ReadResult(query, 2) != 0;
        g_Player[id][pLandingSound] = SQL_ReadResult(query, 3) != 0;
        g_Player[id][pAchievementSound] = SQL_ReadResult(query, 4) != 0;
        g_Player[id][pChatStatsEnabled] = SQL_ReadResult(query, 5) != 0;
        new style = SQL_ReadResult(query, 6);
        new picked = SQL_ReadResult(query, 7);
        if (style < 0 || style > 2) style = 1;
        // hud_style 0 used to be the implicit default. Move those players to KZ center once.
        // style 1/2 was an explicit older choice, so only remember it.
        if (!picked && style == 0)
        {
            Hms_ApplyKzCenterHud(id);
            g_HmsKeepCenter[id] = true;
            Hms_QueuePrefsSave(id, HMS_DIRTY_PREFS | HMS_DIRTY_FIELDS | HMS_DIRTY_PANELS);
        }
        else
        {
            if (!picked)
                Hms_QueuePrefsSave(id, HMS_DIRTY_PREFS);
            g_Player[id][pHudStyle] = style;
            if (!(g_SettingsTouchedMask[id] & (HMS_DIRTY_FIELDS | HMS_DIRTY_PANELS)))
            {
                if (style == 1)
                    Hms_ApplyKzCenterHud(id);
                else if (style == 2)
                    Hms_ApplyPrefogNumHud(id);
            }
        }
    }

    Hms_StartHudLayoutLoad(data, datasize);
}

stock Hms_StartHudLayoutLoad(data[], datasize)
{
    if (datasize < 3) return;
    new id = data[0];
    if (!Hms_CallbackPlayerValid(id, data, datasize)) return;

    new quotedAuth[80], queryText[512], cbData[3];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;
    cbData[0] = id;
    cbData[1] = data[1];
    cbData[2] = data[2];

    formatex(queryText, charsmax(queryText),
        "SELECT field_id,enabled,hud_x,hud_y,color_id FROM hms_hud_layout WHERE authid='%s'", quotedAuth);
    SQL_ThreadQuery(g_SqlTuple, "Hms_LoadLayoutCallback", queryText, cbData, sizeof cbData);

    formatex(queryText, charsmax(queryText),
        "SELECT panel_id,enabled,hud_x,hud_y,color_id FROM hms_hud_panels WHERE authid='%s'", quotedAuth);
    SQL_ThreadQuery(g_SqlTuple, "Hms_LoadPanelLayoutCallback", queryText, cbData, sizeof cbData);
}

public Hms_LoadLayoutCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("[HMS] HUD layout load query failed (%d): %s", errcode, error);
        return;
    }

    new id = data[0];
    if (!Hms_CallbackPlayerValid(id, data, datasize)) return;
    if (g_HmsKeepCenter[id])
    {
        Hms_ApplyKzCenterHud(id);
        Hms_SaveHudLayout(id);
        return;
    }
    if (g_SettingsTouchedMask[id] & HMS_DIRTY_FIELDS) return;

    new rows = SQL_NumResults(query);
    for (new i = 0; i < rows; i++)
    {
        new field = SQL_ReadResult(query, 0);
        if (field >= 0 && field < HMS_HUD_COUNT)
        {
            g_HudFieldEnabled[id][field] = SQL_ReadResult(query, 1) != 0;
            g_HudFieldX[id][field] = SQL_ReadResult(query, 2);
            g_HudFieldY[id][field] = SQL_ReadResult(query, 3);
            g_HudFieldColor[id][field] = SQL_ReadResult(query, 4);
            if (g_HudFieldColor[id][field] < 0 || g_HudFieldColor[id][field] >= HMS_COLOR_COUNT)
                g_HudFieldColor[id][field] = field % HMS_COLOR_COUNT;
            if (g_HudFieldX[id][field] < -1) g_HudFieldX[id][field] = 2;
            if (g_HudFieldX[id][field] > 100) g_HudFieldX[id][field] = 95;
            if (g_HudFieldY[id][field] < 0) g_HudFieldY[id][field] = 0;
            if (g_HudFieldY[id][field] > 100) g_HudFieldY[id][field] = 95;
        }
        SQL_NextRow(query);
    }

    if (g_HmsHudRev2[id] && g_Player[id][pHudStyle] != 1 && g_Player[id][pHudStyle] != 2)
        Hms_ApplyBottomHud(id);

    // Upsert every field so newly added fields receive defaults after upgrades.
    Hms_SaveHudLayout(id);
}

public Hms_LoadPanelLayoutCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (!Hms_CallbackGenerationValid(data, datasize)) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
    if (failstate != TQUERY_SUCCESS)
        return;

    new id = data[0];
    if (!Hms_CallbackPlayerValid(id, data, datasize)) return;
    if (g_HmsKeepCenter[id])
    {
        Hms_ApplyKzCenterHud(id);
        Hms_SavePanelLayout(id);
        return;
    }
    if (g_SettingsTouchedMask[id] & HMS_DIRTY_PANELS) return;

    new rows = SQL_NumResults(query);
    for (new i = 0; i < rows; i++)
    {
        new panel = SQL_ReadResult(query, 0);
        if (panel >= 0 && panel < HMS_PANEL_COUNT)
        {
            g_HudPanelEnabled[id][panel] = SQL_ReadResult(query, 1) != 0;
            g_HudPanelX[id][panel] = SQL_ReadResult(query, 2);
            g_HudPanelY[id][panel] = SQL_ReadResult(query, 3);
            g_HudPanelColor[id][panel] = SQL_ReadResult(query, 4);
            if (g_HudPanelColor[id][panel] < 0 || g_HudPanelColor[id][panel] >= HMS_COLOR_COUNT)
                g_HudPanelColor[id][panel] = panel;
            if (g_HudPanelX[id][panel] < -1) g_HudPanelX[id][panel] = 2;
            if (g_HudPanelX[id][panel] > 90) g_HudPanelX[id][panel] = 90;
            if (g_HudPanelY[id][panel] < 0) g_HudPanelY[id][panel] = 0;
            if (g_HudPanelY[id][panel] > 90) g_HudPanelY[id][panel] = 90;
        }
        SQL_NextRow(query);
    }
    if (Hms_HudNeedsRev(id))
    {
        Hms_ApplyBottomHud(id);
        g_HmsHudRev2[id] = true;
        Hms_QueuePrefsSave(id, HMS_DIRTY_ALL);
    }
    Hms_SavePanelLayout(id); // backfills newly introduced panels for returning players
}

stock bool:Hms_CallbackGenerationValid(data[], datasize)
{
    return datasize >= 3 && data[2] == g_SqlGeneration;
}

stock bool:Hms_CallbackPlayerValid(id, data[], datasize)
{
    if (!Hms_CallbackGenerationValid(data, datasize) || id < 1 || id > HMS_MAX_PLAYERS || !is_user_connected(id))
        return false;
    if (get_user_userid(id) != data[1])
        return false; // Player slot was reused while the SQL query was running.
    return true;
}

stock Hms_ThreadSqlWrite(const queryText[])
{
    if (!g_SqlEnabled || g_SqlTuple == Empty_Handle) return;
    new callbackData[1];
    callbackData[0] = g_SqlGeneration;
    SQL_ThreadQuery(g_SqlTuple, "Hms_SqlCallback", queryText, callbackData, sizeof callbackData);
}

public Hms_SqlCallback(failstate, Handle:query, error[], errcode, data[], datasize, Float:queuetime)
{
    if (datasize < 1 || data[0] != g_SqlGeneration) return;
    Hms_RecordSqlStatus(failstate, error, errcode, queuetime);
}

public Hms_SavePreferencesTask(taskid)
{
    new id = taskid - HMS_TASK_PREFS;
    if (id < 1 || id > HMS_MAX_PLAYERS || !is_user_connected(id)) return;
    if (!g_SqlEnabled || !g_AuthId[id][0]) return; // Keep dirty bits for a later SQL enable/reload.
    new dirtyMask = g_SettingsDirtyMask[id];
    g_SettingsDirtyMask[id] = 0;
    if (dirtyMask & HMS_DIRTY_PREFS) Hms_SavePreferencesNow(id);
    if (dirtyMask & HMS_DIRTY_FIELDS) Hms_SaveHudLayout(id);
    if (dirtyMask & HMS_DIRTY_PANELS) Hms_SavePanelLayout(id);
}

stock Hms_SavePreferencesNow(id)
{
    if (!g_SqlEnabled || !g_AuthId[id][0]) return;

    new quotedAuth[80], query[1024];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;

    formatex(query, charsmax(query), "INSERT INTO hms_player_settings (authid,hud_enabled,sounds_enabled,takeoff_enabled,landing_enabled,achievement_enabled,chatstats_enabled,hud_style,style_pick) VALUES ('%s',%d,%d,%d,%d,%d,%d,%d,1) ON DUPLICATE KEY UPDATE hud_enabled=VALUES(hud_enabled),sounds_enabled=VALUES(sounds_enabled),takeoff_enabled=VALUES(takeoff_enabled),landing_enabled=VALUES(landing_enabled),achievement_enabled=VALUES(achievement_enabled),chatstats_enabled=VALUES(chatstats_enabled),hud_style=VALUES(hud_style),style_pick=1",
        quotedAuth, g_Player[id][pHudEnabled], g_Player[id][pSoundsEnabled], g_Player[id][pTakeoffSound],
        g_Player[id][pLandingSound], g_Player[id][pAchievementSound], g_Player[id][pChatStatsEnabled], g_Player[id][pHudStyle]);
    Hms_ThreadSqlWrite(query);
}

stock Hms_SaveHudLayout(id)
{
    if (!g_SqlEnabled || !g_AuthId[id][0]) return;

    new quotedAuth[80], query[2048], len;
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;

    len = formatex(query, charsmax(query),
        "INSERT INTO hms_hud_layout (authid,field_id,enabled,hud_x,hud_y,color_id) VALUES ");
    for (new field = 0; field < HMS_HUD_COUNT; field++)
    {
        if (len >= charsmax(query) - 128) break;
        len += formatex(query[len], charsmax(query) - len, "%s('%s',%d,%d,%d,%d,%d)",
            field ? "," : "", quotedAuth, field, g_HudFieldEnabled[id][field],
            g_HudFieldX[id][field], g_HudFieldY[id][field], g_HudFieldColor[id][field]);
    }
    formatex(query[len], charsmax(query) - len,
        " ON DUPLICATE KEY UPDATE enabled=VALUES(enabled),hud_x=VALUES(hud_x),hud_y=VALUES(hud_y),color_id=VALUES(color_id)");
    Hms_ThreadSqlWrite(query);
}

stock Hms_SavePanelLayout(id)
{
    if (!g_SqlEnabled || !g_AuthId[id][0]) return;

    new quotedAuth[80], query[1024], len;
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;
    len = formatex(query, charsmax(query),
        "INSERT INTO hms_hud_panels (authid,panel_id,enabled,hud_x,hud_y,color_id) VALUES ");
    for (new panel = 0; panel < HMS_PANEL_COUNT; panel++)
    {
        if (len >= charsmax(query) - 100) break;
        len += formatex(query[len], charsmax(query) - len, "%s('%s',%d,%d,%d,%d,%d)",
            panel ? "," : "", quotedAuth, panel, g_HudPanelEnabled[id][panel],
            g_HudPanelX[id][panel], g_HudPanelY[id][panel], g_HudPanelColor[id][panel]);
    }
    formatex(query[len], charsmax(query) - len,
        " ON DUPLICATE KEY UPDATE enabled=VALUES(enabled),hud_x=VALUES(hud_x),hud_y=VALUES(hud_y),color_id=VALUES(color_id)");
    Hms_ThreadSqlWrite(query);
}

stock Hms_SavePlayer(id)
{
    if (!g_SqlEnabled || !g_AuthId[id][0] || is_user_bot(id) || is_user_hltv(id))
        return;

    new quotedAuth[80], name[32], quotedName[80], query[1536];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;
    get_user_name(id, name, charsmax(name));
    SQL_QuoteString(Empty_Handle, quotedName, charsmax(quotedName), name);

    formatex(query, charsmax(query), "INSERT INTO hms_players (authid,last_name) VALUES ('%s','%s') ON DUPLICATE KEY UPDATE last_name=VALUES(last_name),last_seen=CURRENT_TIMESTAMP",
        quotedAuth, quotedName);
    Hms_ThreadSqlWrite(query);

    formatex(query, charsmax(query), "INSERT INTO hms_movement_totals (authid,session_max_speed,max_bhop_chain,jumps,landings,low_speed_events,strafe_samples,strafe_good,air_turns,fog_total_frames,fog_samples,distance_units,sessions) VALUES ('%s',%.3f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.3f,1) ON DUPLICATE KEY UPDATE session_max_speed=GREATEST(session_max_speed,VALUES(session_max_speed)),max_bhop_chain=GREATEST(max_bhop_chain,VALUES(max_bhop_chain)),jumps=jumps+VALUES(jumps),landings=landings+VALUES(landings),low_speed_events=low_speed_events+VALUES(low_speed_events),strafe_samples=strafe_samples+VALUES(strafe_samples),strafe_good=strafe_good+VALUES(strafe_good),air_turns=air_turns+VALUES(air_turns),fog_total_frames=fog_total_frames+VALUES(fog_total_frames),fog_samples=fog_samples+VALUES(fog_samples),distance_units=distance_units+VALUES(distance_units),sessions=sessions+1",
        quotedAuth, g_Player[id][pSessionMaxSpeed], g_Player[id][pSessionMaxBhopChain],
        g_Player[id][pJumpCount], g_Player[id][pLandingCount], g_Player[id][pLowSpeedEvents],
        g_Player[id][pSessionStrafeSamples], g_Player[id][pSessionStrafeGood], g_Player[id][pSessionAirTurnCount],
        g_Player[id][pFogTotalFrames], g_Player[id][pFogSamples], g_Player[id][pDistance]);
    Hms_ThreadSqlWrite(query);

    Hms_SavePreferencesNow(id);
    Hms_SaveHudLayout(id);
    Hms_SavePanelLayout(id);
}

stock Hms_SaveJumpEvent(id, Float:distance, Float:airtime)
{
    if (!g_SqlEnabled || !get_pcvar_num(pcvar_sql_save_jump_events) || !g_AuthId[id][0])
        return;

    new quotedAuth[80], mapName[64], quotedMap[128], query[1024], jumpType[12];
    if (SQL_QuoteString(Empty_Handle, quotedAuth, charsmax(quotedAuth), g_AuthId[id]) < 0) return;
    get_mapname(mapName, charsmax(mapName));
    if (SQL_QuoteString(Empty_Handle, quotedMap, charsmax(quotedMap), mapName) < 0) return;
    Hms_GetJumpTypeCode(id, jumpType, charsmax(jumpType));

    formatex(query, charsmax(query), "INSERT INTO hms_jump_events (authid,map_name,jump_type,distance_units,takeoff_speed,max_air_speed,landing_speed,air_time,fog_frames,strafe_gain,strafe_loss,turn_sync) VALUES ('%s','%s','%s',%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.3f,%.3f,%.2f)",
        quotedAuth, quotedMap, jumpType, distance, g_Player[id][pCompletedTakeoffSpeed], g_Player[id][pCompletedMaxSpeed],
        g_Player[id][pLastLandingSpeed], airtime, g_Player[id][pCompletedFogFrames],
        g_Player[id][pLastStrafeGain], g_Player[id][pLastStrafeLoss], Hms_GetSyncPercent(id));
    Hms_ThreadSqlWrite(query);
} 
// HMS extension API. HNS core plugins can call hms_bridge_set_status() to publish their real phase/timer.
// Example: hms_bridge_set_status("HIDE", "Hiders preparing", 12.0);
// The countdown argument is seconds remaining at the time of the call; use -1.0 when no timer is active.
// Update the native periodically (e.g. every second) so the display remains fresh.

public plugin_natives()
{
    register_library("hms_movement_stats");
    register_native("hms_bridge_set_status", "Hms_NativeBridgeSetStatus");
    register_native("hms_bridge_set_ladder_state", "Hms_NativeBridgeSetLadderState");
}

public Hms_NativeBridgeSetStatus(plugin_id, num_params)
{
    if (num_params < 3)
        return 0;

    get_string(1, g_HnsPhase, charsmax(g_HnsPhase));
    get_string(2, g_HnsDetail, charsmax(g_HnsDetail));
    g_HnsCountdown = get_param_f(3);
    g_HnsStatusUpdated = get_gametime();
    return 1;
}

// Optional exact ladder-state hook. A movement/HNS core with reliable ladder detection may
// call this whenever a player's ladder contact state changes or is sampled.
public Hms_NativeBridgeSetLadderState(plugin_id, num_params)
{
    if (num_params < 2)
        return 0;

    new id = get_param(1);
    if (id < 1 || id > HMS_MAX_PLAYERS || !g_Player[id][pConnected])
        return 0;

    g_Player[id][pOnLadderFromBridge] = get_param(2) != 0;
    return 1;
}

// Optional cross-plugin forwards. Other plugins may register handlers with these exact names/signatures.
forward hms_on_jump(id, Float:takeoff_speed);
forward hms_on_land(id, Float:distance, Float:air_time, Float:max_air_speed);
forward hms_on_low_speed(id, Float:old_speed, Float:new_speed);

stock Hms_NotifyJump(id, Float:takeoffSpeed)
{
    new result;
    if (g_ForwardJump != -1)
        ExecuteForward(g_ForwardJump, result, id, takeoffSpeed);
}

stock Hms_NotifyLand(id, Float:distance, Float:airtime, Float:maxAirSpeed)
{
    new result;
    if (g_ForwardLand != -1)
        ExecuteForward(g_ForwardLand, result, id, distance, airtime, maxAirSpeed);
}

stock Hms_NotifyLowSpeed(id, Float:oldSpeed, Float:newSpeed)
{
    new result;
    if (g_ForwardLowSpeed != -1)
        ExecuteForward(g_ForwardLowSpeed, result, id, oldSpeed, newSpeed);
}

#if defined _hms_external_api_included
    #endinput
#endif
#define _hms_external_api_included

// Public API include for external HNS core plugins. Load HMS before plugins using this native.
#pragma reqlib hms_movement_stats
native hms_bridge_set_status(const phase[], const detail[], Float:countdown);

// Optional ladder classifier bridge. Call with the real ladder-contact state from the movement core.
native hms_bridge_set_ladder_state(id, bool:is_on_ladder);

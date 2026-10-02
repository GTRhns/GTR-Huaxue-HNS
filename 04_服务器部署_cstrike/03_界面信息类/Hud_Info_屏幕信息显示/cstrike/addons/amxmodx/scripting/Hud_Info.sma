#include <amxmodx>

public plugin_init() {
    register_plugin("Hud_Info", "2.0", "DeIIyTaT, mx?!")
    register_dictionary("hud_info.txt")

    set_task(1.0, "task_hud", .flags ="b")
}

public task_hud() {
    set_dhudmessage(0, 255, 252, -1.0, 0.0, 0, 1.1, 1.1, 0.1, 0.1)
    show_dhudmessage(0, "%L", LANG_PLAYER, "HI_MSG_1")

    set_dhudmessage(171, 57, 57, -1.0, 0.03, 0, 1.0, 1.0, 1.0, 1.0)
    show_dhudmessage(0, "%L", LANG_PLAYER, "HI_MSG_2")
}

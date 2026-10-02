// PointScap Editor - Zone Measurement Tool
// Author: HNS Match System
// Description: Admin tool for measuring and configuring map zones for PointScap mode
// Compatible with ZONE_DATA enum from globals.inc

#if defined _pointscap_editor_included
    #endinput
#endif
#define _pointscap_editor_included

// Measurement states
enum (<<= 1) {
    MEASURE_NONE = 0,
    MEASURE_STARTED = 1,
    MEASURE_BOTTOM_SET = 2,
    MEASURE_TOP_SET = 4
}

// Temporary measurement data
new Float:g_fMeasureBottom[33][3];
new Float:g_fMeasureTop[33][3];
new g_iMeasureState[33];
new g_iSelectedZone[33];
new g_iSelectedType[33];

// Zone labels A-J
new g_szZoneLabels[][] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"};

// Point type names
new g_szPointTypeNames[][] = {"3-Man Point", "4-Man Point", "5-Man Point"};
new Float:g_fPointScores[] = {0.5, 1.0, 2.0};

// Player model height constant (for zone height calculation)
#define PLAYER_HEIGHT 72.0
#define ZONE_HEIGHT_MULTIPLIER 1.5

/**
 * Initialize the PointScap Editor
 * Registers commands and loads existing config
 */
stock pointscap_editor_init() {
    register_clcmd("say /muin", "cmdPointScapEditor");
    register_clcmd("say_team /muin", "cmdPointScapEditor");
    register_clcmd("say /pointscap_editor", "cmdPointScapEditor");
    register_clcmd("say_team /pointscap_editor", "cmdPointScapEditor");
    register_clcmd("pointscap_editor", "cmdPointScapEditor");

    register_menucmd(register_menuid("PointScap Main Menu"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_0, "handleMainMenu");
    register_menucmd(register_menuid("Select Zone Label"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "handleZoneSelect");
    register_menucmd(register_menuid("Select Point Type"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, "handlePointTypeSelect");
    register_menucmd(register_menuid("Measurement Menu"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_0, "handleMeasurementMenu");
    register_menucmd(register_menuid("View Zones Menu"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "handleViewZonesMenu");
    register_menucmd(register_menuid("Delete Zone Menu"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "handleDeleteZoneMenu");

    // sprites/laserbeam.spr 已在 plugin_precache 中预缓存，此处不再重复
    // g_sprBeam 在 plugin_precache 中赋值

    // Load existing configuration
    pointscap_load_config();

    log_amx("[PointScap Editor] Initialized successfully");
}

/**
 * Main command handler for /muin and /pointscap_editor
 */
public cmdPointScapEditor(id) {
    if (!is_user_connected(id) || !is_user_admin(id)) {
        client_print(id, print_chat, "[PointScap] 你没有权限使用此命令.");
        return PLUGIN_HANDLED;
    }

    pointscapShowMainMenu(id);
    return PLUGIN_HANDLED;
}

/**
 * Display main menu
 */
stock pointscapShowMainMenu(id) {
    new menu[512];
    new len = 0;

    len += formatex(menu[len], charsmax(menu) - len, "\r点位编辑器^n^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r1.\w 测量新点位^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r2.\w 查看已有点位^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r3.\w 删除点位^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r4.\w 保存配置^n^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r0.\w 退出");

    show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_0, menu, -1, "PointScap Main Menu");
}

/**
 * Handle main menu selection
 */
public handleMainMenu(id, key) {
    if (key == 0) {
        // 测量新点位
        menuSelectZone(id);
    } else if (key == 1) {
        // 查看已有点位
        showViewZonesMenu(id);
    } else if (key == 2) {
        // 删除点位
        showDeleteZoneMenu(id);
    } else if (key == 3) {
        // 保存配置
        pointscap_save_config();
        client_print(id, print_chat, "[PointScap] 配置保存成功!");
        pointscapShowMainMenu(id);
    } else if (key == 9) {
        // 退出
    }
    return PLUGIN_HANDLED;
}

/**
 * Zone selection menu
 */
stock menuSelectZone(id) {
    new menu[512];
    new len = 0;

    len += formatex(menu[len], charsmax(menu) - len, "\r选择点位标签^n^n");

    new keys = 0;
    for (new i = 0; i < sizeof(g_szZoneLabels); i++) {
        new bool:exists = false;
        new iExistingTypes[3] = {0, 0, 0}; // 3人, 4人, 5人
        for (new j = 0; j < g_iZoneCount; j++) {
            if (g_eZones[j][ZONE_LABEL] == i) {
                exists = true;
                new typeIdx = g_eZones[j][ZONE_TYPE] - 3;
                if (typeIdx >= 0 && typeIdx < 3) {
                    iExistingTypes[typeIdx] = 1;
                }
            }
        }

        if (exists) {
            // Show all existing types
            new szTypes[32];
            new typeLen = 0;
            for (new t = 0; t < 3; t++) {
                if (iExistingTypes[t]) {
                    if (typeLen > 0) typeLen += formatex(szTypes[typeLen], charsmax(szTypes) - typeLen, ",");
                    typeLen += formatex(szTypes[typeLen], charsmax(szTypes) - typeLen, "%d人", t + 3);
                }
            }
            len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w 点位 %s \y[%s]\w - 可创建其他人数^n", i + 1, g_szZoneLabels[i], szTypes);
        } else {
            len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w 点位 %s^n", i + 1, g_szZoneLabels[i]);
        }
        keys |= (1 << i);
    }

    len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w 返回");
    keys |= MENU_KEY_0;

    show_menu(id, keys, menu, -1, "Select Zone Label");
}

/**
 * Handle zone selection
 */
public handleZoneSelect(id, key) {
    if (key == 9) { // 返回
        pointscapShowMainMenu(id);
        return PLUGIN_HANDLED;
    }

    if (key >= 0 && key < sizeof(g_szZoneLabels)) {
        g_iSelectedZone[id] = key;
        g_iMeasureState[id] = MEASURE_STARTED;

        // Reset measurement coordinates
        g_fMeasureBottom[id][0] = 0.0;
        g_fMeasureBottom[id][1] = 0.0;
        g_fMeasureBottom[id][2] = 0.0;
        g_fMeasureTop[id][0] = 0.0;
        g_fMeasureTop[id][1] = 0.0;
        g_fMeasureTop[id][2] = 0.0;

        showMeasurementMenu(id);
    }
    return PLUGIN_HANDLED;
}

/**
 * Measurement menu
 */
stock showMeasurementMenu(id) {
    new menu[512];
    new len = 0;
    new zoneLabel[2];
    copy(zoneLabel, charsmax(zoneLabel), g_szZoneLabels[g_iSelectedZone[id]]);

    len += formatex(menu[len], charsmax(menu) - len, "\r测量新点位 - 点位 %s^n^n", zoneLabel);

    if (!(g_iMeasureState[id] & MEASURE_BOTTOM_SET)) {
        len += formatex(menu[len], charsmax(menu) - len, "\r1.\w 设置起点位置^n");
        len += formatex(menu[len], charsmax(menu) - len, "\d2. 设置终点位置^n");
        len += formatex(menu[len], charsmax(menu) - len, "^n\r走到点位底角，按 1 设置起点^n");
        show_menu(id, MENU_KEY_1|MENU_KEY_0, menu, -1, "Measurement Menu");
    } else if (!(g_iMeasureState[id] & MEASURE_TOP_SET)) {
        len += formatex(menu[len], charsmax(menu) - len, "\y1.\w 设置起点位置 [已设置]^n");
        len += formatex(menu[len], charsmax(menu) - len, "\r2.\w 设置终点位置^n");
        len += formatex(menu[len], charsmax(menu) - len, "^n\r走到点位顶角，按 2 设置终点^n");
        show_menu(id, MENU_KEY_2|MENU_KEY_0, menu, -1, "Measurement Menu");
    } else {
        len += formatex(menu[len], charsmax(menu) - len, "\y1.\w 设置起点位置 [已设置]^n");
        len += formatex(menu[len], charsmax(menu) - len, "\y2.\w 设置终点位置 [已设置]^n");
        len += formatex(menu[len], charsmax(menu) - len, "^n\r测量完成! 即将进入类型选择...^n");

        // Auto proceed to point type selection
        menuSelectPointType(id);
        return;
    }

    len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w 取消");
}

/**
 * Handle measurement menu
 */
public handleMeasurementMenu(id, key) {
    if (key == 0) {
        // Set bottom/start
        if (!(g_iMeasureState[id] & MEASURE_BOTTOM_SET)) {
            pointscap_start_measure(id);
        }
    } else if (key == 1) {
        // Set top/end
        if ((g_iMeasureState[id] & MEASURE_BOTTOM_SET) && !(g_iMeasureState[id] & MEASURE_TOP_SET)) {
            pointscap_end_measure(id);
        }
    } else if (key == 9) {
        // Cancel/Back
        g_iMeasureState[id] = MEASURE_NONE;
        menuSelectZone(id);
    }
    return PLUGIN_HANDLED;
}

/**
 * Start measurement - record bottom position
 */
stock pointscap_start_measure(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "[PointScap] 你必须存活才能测量!");
        return;
    }

    pev(id, pev_origin, g_fMeasureBottom[id]);
    g_iMeasureState[id] |= MEASURE_BOTTOM_SET;

    new zoneLabel[2];
    copy(zoneLabel, charsmax(zoneLabel), g_szZoneLabels[g_iSelectedZone[id]]);

    client_print(id, print_chat, "[PointScap] 点位 %s 起点已设置: %.1f, %.1f, %.1f",
        zoneLabel,
        g_fMeasureBottom[id][0], g_fMeasureBottom[id][1], g_fMeasureBottom[id][2]);

    // Create visual marker at bottom
    create_beam_point(id, g_fMeasureBottom[id], 0, 255, 0); // Green marker

    showMeasurementMenu(id);
}

/**
 * End measurement - record top position
 */
stock pointscap_end_measure(id) {
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "[PointScap] 你必须存活才能测量!");
        return;
    }

    pev(id, pev_origin, g_fMeasureTop[id]);
    g_iMeasureState[id] |= MEASURE_TOP_SET;

    new zoneLabel[2];
    copy(zoneLabel, charsmax(zoneLabel), g_szZoneLabels[g_iSelectedZone[id]]);

    client_print(id, print_chat, "[PointScap] 点位 %s 终点已设置: %.1f, %.1f, %.1f",
        zoneLabel,
        g_fMeasureTop[id][0], g_fMeasureTop[id][1], g_fMeasureTop[id][2]);

    // Create visual marker at top
    create_beam_point(id, g_fMeasureTop[id], 255, 0, 0); // Red marker

    // Calculate and display zone height
    new Float:height = g_fMeasureTop[id][2] - g_fMeasureBottom[id][2];
    new Float:playerHeights = height / PLAYER_HEIGHT;

    client_print(id, print_chat, "[PointScap] 区域高度: %.1f 单位 (%.1f 个玩家身高)",
        height, playerHeights);

    // Proceed to point type selection
    menuSelectPointType(id);
}

/**
 * Point type selection menu
 */
stock menuSelectPointType(id) {
    new menu[512];
    new len = 0;
    new zoneLabel[2];
    copy(zoneLabel, charsmax(zoneLabel), g_szZoneLabels[g_iSelectedZone[id]]);

    len += formatex(menu[len], charsmax(menu) - len, "\r选择点位类型 - 点位 %s^n^n", zoneLabel);
    len += formatex(menu[len], charsmax(menu) - len, "\r1.\w 3人点 (0.5 分)^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r2.\w 4人点 (1.0 分)^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r3.\w 5人点 (2.0 分)^n^n");
    len += formatex(menu[len], charsmax(menu) - len, "\r0.\w 返回");

    show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, menu, -1, "Select Point Type");
}

/**
 * Handle point type selection
 */
public handlePointTypeSelect(id, key) {
    if (key == 9) { // Back
        g_iMeasureState[id] = MEASURE_STARTED;
        showMeasurementMenu(id);
        return PLUGIN_HANDLED;
    }

    if (key >= 0 && key < 3) {
        g_iSelectedType[id] = key + 3; // 3, 4, or 5
        server_print("[PointScap Editor] handlePointTypeSelect: id=%d, selectedType=%d, selectedZone=%s, saving...", id, g_iSelectedType[id], g_szZoneLabels[g_iSelectedZone[id]]);

        // Save the zone
        pointscap_save_zone(id);
    }
    return PLUGIN_HANDLED;
}

/**
 * Save zone to global variables (ZONE_DATA enum)
 */
stock pointscap_save_zone(id) {
    // ★ 查找是否已有同Label+同Type的zone，有则覆盖，无则新增
    new idx = -1;
    for (new i = 0; i < g_iZoneCount; i++) {
        if (g_eZones[i][ZONE_LABEL] == g_iSelectedZone[id] && g_eZones[i][ZONE_TYPE] == g_iSelectedType[id]) {
            idx = i;
            break;
        }
    }
    
    server_print("[PointScap Editor] Save zone: label=%s, type=%d, existingCount=%d, foundIdx=%d", g_szZoneLabels[g_iSelectedZone[id]], g_iSelectedType[id], g_iZoneCount, idx);
    
    if (idx == -1) {
        if (g_iZoneCount >= MAX_ZONES) {
            client_print(id, print_chat, "[PointScap] 已达到最大点位数量!");
            server_print("[PointScap Editor] Save zone FAILED: MAX_ZONES reached");
            return;
        }
        idx = g_iZoneCount;
        g_iZoneCount++;
        server_print("[PointScap Editor] New zone: idx=%d, new g_iZoneCount=%d", idx, g_iZoneCount);
    } else {
        server_print("[PointScap Editor] Overwriting existing zone: idx=%d", idx);
    }

    new zoneLabel[2];
    copy(zoneLabel, charsmax(zoneLabel), g_szZoneLabels[g_iSelectedZone[id]]);

    // Copy zone data using ZONE_DATA enum fields
    g_eZones[idx][ZONE_LABEL] = g_iSelectedZone[id];
    g_eZones[idx][ZONE_ENABLED] = 1;

    // Calculate zone bounds - ensure mins < maxs for each axis
    new Float:fBottom[3], Float:fTop[3];
    for (new i = 0; i < 3; i++) {
        fBottom[i] = g_fMeasureBottom[id][i];
        fTop[i] = g_fMeasureTop[id][i];
    }

    // Add small padding and keep the measured box precise
    g_eZones[idx][ZONE_MINS][0] = (fBottom[0] < fTop[0] ? fBottom[0] : fTop[0]) - 12.0;
    g_eZones[idx][ZONE_MAXS][0] = (fBottom[0] > fTop[0] ? fBottom[0] : fTop[0]) + 12.0;
    g_eZones[idx][ZONE_MINS][1] = (fBottom[1] < fTop[1] ? fBottom[1] : fTop[1]) - 12.0;
    g_eZones[idx][ZONE_MAXS][1] = (fBottom[1] > fTop[1] ? fBottom[1] : fTop[1]) + 12.0;
    g_eZones[idx][ZONE_MINS][2] = (fBottom[2] < fTop[2] ? fBottom[2] : fTop[2]) - 8.0;
    g_eZones[idx][ZONE_MAXS][2] = (fBottom[2] > fTop[2] ? fBottom[2] : fTop[2]) + 12.0;

    g_eZones[idx][ZONE_TYPE] = g_iSelectedType[id];
    g_eZones[idx][ZONE_SCORE] = g_fPointScores[g_iSelectedType[id] - 3];
    g_eZones[idx][ZONE_CAPTURED] = 0;
    g_eZones[idx][ZONE_CAPTURE_TIME] = 0.0;
    g_eZones[idx][ZONE_STATUS] = 0;
    g_eZones[idx][ZONE_CAPTURED_TYPE] = 0;
    g_eZones[idx][ZONE_PLAYER_COUNT] = 0;

    // Create zone visualization
    new Float:peMins1[3], Float:peMaxs1[3];
    peMins1[0] = g_eZones[idx][ZONE_MINS][0]; peMins1[1] = g_eZones[idx][ZONE_MINS][1]; peMins1[2] = g_eZones[idx][ZONE_MINS][2];
    peMaxs1[0] = g_eZones[idx][ZONE_MAXS][0]; peMaxs1[1] = g_eZones[idx][ZONE_MAXS][1]; peMaxs1[2] = g_eZones[idx][ZONE_MAXS][2];
    create_zone_beam_box(id, peMins1, peMaxs1,
        g_iSelectedType[id] == 3 ? 0 : (g_iSelectedType[id] == 4 ? 100 : 255),
        g_iSelectedType[id] == 3 ? 255 : (g_iSelectedType[id] == 4 ? 255 : 0),
        g_iSelectedType[id] == 3 ? 0 : (g_iSelectedType[id] == 4 ? 0 : 0));

    client_print(id, print_chat, "[PointScap] 点位 %s 已保存为 %d人点 (%.1f 分)!",
        zoneLabel, g_iSelectedType[id], g_eZones[idx][ZONE_SCORE]);

    // ★ 自动写入INI文件
    pointscap_save_config();

    // Reset measurement state
    g_iMeasureState[id] = MEASURE_NONE;

    // Re-open zone selection so user can create more zones
    set_task(0.2, "taskReopenZoneMenu", id);
}

public taskReopenZoneMenu(id) {
    if (!is_user_connected(id)) return;
    menuSelectZone(id);
}

/**
 * View zones menu
 */
stock showViewZonesMenu(id) {
    if (g_iZoneCount == 0) {
        client_print(id, print_chat, "[PointScap] 暂无已配置的点位!");
        pointscapShowMainMenu(id);
        return;
    }

    new menu[512];
    new len = 0;

    len += formatex(menu[len], charsmax(menu) - len, "\r查看点位^n^n");

    new keys = MENU_KEY_0;
    new maxItems = min(g_iZoneCount, 9);

    for (new i = 0; i < maxItems; i++) {
        len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w 点位 %s - %d人 (%.1f 分)^n",
            i + 1, g_szZoneLabels[g_eZones[i][ZONE_LABEL]], g_eZones[i][ZONE_TYPE], g_eZones[i][ZONE_SCORE]);
        keys |= (1 << i);
    }

    len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w 返回");

    show_menu(id, keys, menu, -1, "View Zones Menu");
}

/**
 * Handle view zones menu
 */
public handleViewZonesMenu(id, key) {
    if (key == 9) { // 返回
        pointscapShowMainMenu(id);
        return PLUGIN_HANDLED;
    }

    if (key >= 0 && key < g_iZoneCount) {
        // Teleport to zone
        new Float:teleportPos[3];
        teleportPos[0] = (g_eZones[key][ZONE_MINS][0] + g_eZones[key][ZONE_MAXS][0]) / 2.0;
        teleportPos[1] = (g_eZones[key][ZONE_MINS][1] + g_eZones[key][ZONE_MAXS][1]) / 2.0;
        teleportPos[2] = g_eZones[key][ZONE_MINS][2] + 10.0;

        set_pev(id, pev_origin, teleportPos);

        client_print(id, print_chat, "[PointScap] 已传送到点位 %s", g_szZoneLabels[g_eZones[key][ZONE_LABEL]]);

        // Highlight zone
        new Float:peMins2[3], Float:peMaxs2[3];
        peMins2[0] = g_eZones[key][ZONE_MINS][0]; peMins2[1] = g_eZones[key][ZONE_MINS][1]; peMins2[2] = g_eZones[key][ZONE_MINS][2];
        peMaxs2[0] = g_eZones[key][ZONE_MAXS][0]; peMaxs2[1] = g_eZones[key][ZONE_MAXS][1]; peMaxs2[2] = g_eZones[key][ZONE_MAXS][2];
        create_zone_beam_box(id, peMins2, peMaxs2, 255, 255, 0);
    }

    return PLUGIN_HANDLED;
}

/**
 * Delete zone menu
 */
stock showDeleteZoneMenu(id) {
    if (g_iZoneCount == 0) {
        client_print(id, print_chat, "[PointScap] 没有可删除的点位!");
        pointscapShowMainMenu(id);
        return;
    }

    new menu[512];
    new len = 0;

    len += formatex(menu[len], charsmax(menu) - len, "\r删除点位^n^n");

    new keys = MENU_KEY_0;
    new maxItems = min(g_iZoneCount, 9);

    for (new i = 0; i < maxItems; i++) {
        len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w 点位 %s - %d人^n",
            i + 1, g_szZoneLabels[g_eZones[i][ZONE_LABEL]], g_eZones[i][ZONE_TYPE]);
        keys |= (1 << i);
    }

    len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w 返回");

    show_menu(id, keys, menu, -1, "Delete Zone Menu");
}

/**
 * Handle delete zone menu
 */
public handleDeleteZoneMenu(id, key) {
    if (key == 9) { // 返回
        pointscapShowMainMenu(id);
        return PLUGIN_HANDLED;
    }

    if (key >= 0 && key < g_iZoneCount) {
        new deletedLabel = g_eZones[key][ZONE_LABEL];

        // ★ FIX: 平移后续点位时保留原始 ZONE_LABEL（字母标签）不强制重写为数组索引
        // 原来的 g_eZones[i][ZONE_LABEL] = i 会把 B/C/D... 标签污染为 A/B/C...
        // 导致保存后比赛只认 A 点
        for (new i = key; i < g_iZoneCount - 1; i++) {
            // 直接复制下一个元素的所有字段（包括原始 ZONE_LABEL）
            g_eZones[i][ZONE_LABEL] = g_eZones[i + 1][ZONE_LABEL];  // 保留原始字母标签
            g_eZones[i][ZONE_ENABLED] = g_eZones[i + 1][ZONE_ENABLED];
            g_eZones[i][ZONE_MINS] = g_eZones[i + 1][ZONE_MINS];
            g_eZones[i][ZONE_MAXS] = g_eZones[i + 1][ZONE_MAXS];
            g_eZones[i][ZONE_TYPE] = g_eZones[i + 1][ZONE_TYPE];
            g_eZones[i][ZONE_SCORE] = g_eZones[i + 1][ZONE_SCORE];
            g_eZones[i][ZONE_CAPTURED] = g_eZones[i + 1][ZONE_CAPTURED];
            g_eZones[i][ZONE_CAPTURE_TIME] = g_eZones[i + 1][ZONE_CAPTURE_TIME];
            g_eZones[i][ZONE_STATUS] = g_eZones[i + 1][ZONE_STATUS];
            g_eZones[i][ZONE_CAPTURED_TYPE] = g_eZones[i + 1][ZONE_CAPTURED_TYPE];
            g_eZones[i][ZONE_PLAYER_COUNT] = g_eZones[i + 1][ZONE_PLAYER_COUNT];
            // 不再执行 g_eZones[i][ZONE_LABEL] = i; 这行错误代码
        }

        g_iZoneCount--;

        client_print(id, print_chat, "[PointScap] 点位 %s 已删除!", g_szZoneLabels[deletedLabel]);

        // ★ 自动写入INI文件
        pointscap_save_config();
    }

    showDeleteZoneMenu(id);
    return PLUGIN_HANDLED;
}

/**
 * Save configuration to file (map-specific INI format)
 * Path: configs/mixsystem/pointscap/地图名.ini
 * Format compatible with pointscap_load_zones() in mode_ascension.inl
 */
stock pointscap_save_config() {
    new filePath[128];
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));
    get_configsdir(filePath, charsmax(filePath));

    // Create pointscap directory (if not exists)
    new dirPath[128];
    format(dirPath, charsmax(dirPath), "%s/mixsystem/pointscap", filePath);
    if (!dir_exists(dirPath)) {
        mkdir(dirPath);
    }

    // Save config by map name
    format(filePath, charsmax(filePath), "%s/%s.ini", dirPath, szMapName);
    
    server_print("[PointScap Editor] Saving config: path=%s, g_iZoneCount=%d", filePath, g_iZoneCount);
    for (new d = 0; d < g_iZoneCount; d++) {
        server_print("[PointScap Editor]   Zone[%d]: label=%s, type=%d, enabled=%d", d, g_szZoneLabels[g_eZones[d][ZONE_LABEL]], g_eZones[d][ZONE_TYPE], g_eZones[d][ZONE_ENABLED]);
    }

    // ★ v5.6 FIX: 统一使用 _save_zones_ini 保存，消除编辑器与 /creatzone 两套保存逻辑的冲突
    // 之前编辑器用自己的格式写入，可能覆盖 /creatzone 保存的完整点位数据
    _save_zones_ini(filePath, szMapName);

    server_print("[PointScap Editor] 地图 %s 配置已保存: %d 个点位", szMapName, g_iZoneCount);
}

stock bool:pointscap_editor_append_zone(labelIdx, typeVal, Float:fMins[3], Float:fMaxs[3]) {
    if (g_iZoneCount >= MAX_ZONES) {
        log_amx("[PointScap Editor] 跳过 %c 区 %d 人点: 已达到上限", 'A' + labelIdx, typeVal);
        return false;
    }

    new idx = g_iZoneCount;
    g_eZones[idx][ZONE_LABEL] = labelIdx;
    g_eZones[idx][ZONE_ENABLED] = 1;
    g_eZones[idx][ZONE_STATUS] = 0;
    g_eZones[idx][ZONE_CAPTURED] = 0;
    g_eZones[idx][ZONE_CAPTURE_TIME] = 0.0;
    g_eZones[idx][ZONE_CAPTURED_TYPE] = 0;
    g_eZones[idx][ZONE_PLAYER_COUNT] = 0;
    g_eZones[idx][ZONE_TYPE] = typeVal;

    if (typeVal == 4) {
        g_eZones[idx][ZONE_SCORE] = 1.0;
    } else if (typeVal == 5) {
        g_eZones[idx][ZONE_SCORE] = 2.0;
    } else {
        g_eZones[idx][ZONE_SCORE] = 0.5;
    }

    for (new i = 0; i < 3; i++) {
        g_eZones[idx][ZONE_MINS][i] = fMins[i];
        g_eZones[idx][ZONE_MAXS][i] = fMaxs[i];
    }

    g_iZoneCount++;
    return true;
}

/**
 * Load configuration from file (map-specific INI format)
 * Path: configs/mixsystem/pointscap/地图名.ini
 * Compatible with pointscap_load_zones() format
 */
stock pointscap_load_config() {
    new filePath[128];
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));
    get_configsdir(filePath, charsmax(filePath));

    format(filePath, charsmax(filePath), "%s/mixsystem/pointscap/%s.ini", filePath, szMapName);

    if (!file_exists(filePath)) {
        log_amx("[PointScap Editor] 未找到配置文件: %s", filePath);
        return;
    }

    new file = fopen(filePath, "r");
    if (!file) {
        log_amx("[PointScap Editor] 无法打开配置文件: %s", filePath);
        return;
    }

    new line[256];
    new szKey[32], szVal1[16], szVal2[16], szVal3[16];
    new currentLabel = -1;
    new explicitType;
    new Float:genericMins[3], Float:genericMaxs[3];
    new bool:hasGenericMins, bool:hasGenericMaxs;
    new Float:legacyMins[3][3], Float:legacyMaxs[3][3];
    new bool:hasLegacyMins[3], bool:hasLegacyMaxs[3];

    g_iZoneCount = 0;
    server_print("[PointScap Editor] pointscap_load_config: loading from %s", filePath);

    while (!feof(file) && g_iZoneCount < MAX_ZONES) {
        fgets(file, line, charsmax(line));
        trim(line);

        // Skip comments and empty lines
        if (line[0] == ';' || line[0] == '/' || !line[0]) continue;

        if (line[0] == '[') {
            if (currentLabel >= 0) {
                // ★ 优先 legacy 格式，与 pointscap_zones.inl 保持一致
                new bool:bHasAnyLegacy = false;
                for (new i = 0; i < 3; i++) {
                    if (hasLegacyMins[i] && hasLegacyMaxs[i]) {
                        bHasAnyLegacy = true;
                        break;
                    }
                }

                if (bHasAnyLegacy) {
                    if (explicitType >= 3 && explicitType <= 5 &&
                        hasLegacyMins[explicitType - 3] && hasLegacyMaxs[explicitType - 3]) {
                        pointscap_editor_append_zone(
                            currentLabel,
                            explicitType,
                            legacyMins[explicitType - 3],
                            legacyMaxs[explicitType - 3]
                        );
                    } else {
                        for (new i = 0; i < 3 && g_iZoneCount < MAX_ZONES; i++) {
                            if (hasLegacyMins[i] && hasLegacyMaxs[i]) {
                                pointscap_editor_append_zone(currentLabel, i + 3, legacyMins[i], legacyMaxs[i]);
                            }
                        }
                    }
                } else if (hasGenericMins && hasGenericMaxs) {
                    pointscap_editor_append_zone(
                        currentLabel,
                        (explicitType >= 3 && explicitType <= 5) ? explicitType : 3,
                        genericMins,
                        genericMaxs
                    );
                }
            }

            new labelIdx = line[1] - 'A';
            if (labelIdx >= 0 && labelIdx < 10) {
                currentLabel = labelIdx;
                explicitType = 0;
                hasGenericMins = false;
                hasGenericMaxs = false;

                for (new i = 0; i < 3; i++) {
                    hasLegacyMins[i] = false;
                    hasLegacyMaxs[i] = false;

                    for (new j = 0; j < 3; j++) {
                        legacyMins[i][j] = 0.0;
                        legacyMaxs[i][j] = 0.0;
                    }
                }

                for (new i = 0; i < 3; i++) {
                    genericMins[i] = 0.0;
                    genericMaxs[i] = 0.0;
                }
            } else {
                currentLabel = -1;
            }
            continue;
        }

        if (currentLabel < 0) continue;

        parse(line, szKey, charsmax(szKey), szVal1, charsmax(szVal1), szVal2, charsmax(szVal2), szVal3, charsmax(szVal3));

        if (equal(szKey, "type")) {
            explicitType = str_to_num(szVal1);
        }
        else if (equal(szKey, "mins")) {
            genericMins[0] = str_to_float(szVal1);
            genericMins[1] = str_to_float(szVal2);
            genericMins[2] = str_to_float(szVal3);
            hasGenericMins = true;
        }
        else if (equal(szKey, "maxs")) {
            genericMaxs[0] = str_to_float(szVal1);
            genericMaxs[1] = str_to_float(szVal2);
            genericMaxs[2] = str_to_float(szVal3);
            hasGenericMaxs = true;
        }
        else if (equal(szKey, "point3_mins")) {
            legacyMins[0][0] = str_to_float(szVal1);
            legacyMins[0][1] = str_to_float(szVal2);
            legacyMins[0][2] = str_to_float(szVal3);
            hasLegacyMins[0] = true;
        }
        else if (equal(szKey, "point3_maxs")) {
            legacyMaxs[0][0] = str_to_float(szVal1);
            legacyMaxs[0][1] = str_to_float(szVal2);
            legacyMaxs[0][2] = str_to_float(szVal3);
            hasLegacyMaxs[0] = true;
        }
        else if (equal(szKey, "point4_mins")) {
            legacyMins[1][0] = str_to_float(szVal1);
            legacyMins[1][1] = str_to_float(szVal2);
            legacyMins[1][2] = str_to_float(szVal3);
            hasLegacyMins[1] = true;
        }
        else if (equal(szKey, "point4_maxs")) {
            legacyMaxs[1][0] = str_to_float(szVal1);
            legacyMaxs[1][1] = str_to_float(szVal2);
            legacyMaxs[1][2] = str_to_float(szVal3);
            hasLegacyMaxs[1] = true;
        }
        else if (equal(szKey, "point5_mins")) {
            legacyMins[2][0] = str_to_float(szVal1);
            legacyMins[2][1] = str_to_float(szVal2);
            legacyMins[2][2] = str_to_float(szVal3);
            hasLegacyMins[2] = true;
        }
        else if (equal(szKey, "point5_maxs")) {
            legacyMaxs[2][0] = str_to_float(szVal1);
            legacyMaxs[2][1] = str_to_float(szVal2);
            legacyMaxs[2][2] = str_to_float(szVal3);
            hasLegacyMaxs[2] = true;
        }
    }

    if (currentLabel >= 0 && g_iZoneCount < MAX_ZONES) {
        // ★ 优先 legacy 格式，与 pointscap_zones.inl 保持一致
        new bool:bHasAnyLegacy = false;
        for (new i = 0; i < 3; i++) {
            if (hasLegacyMins[i] && hasLegacyMaxs[i]) {
                bHasAnyLegacy = true;
                break;
            }
        }

        if (bHasAnyLegacy) {
            if (explicitType >= 3 && explicitType <= 5 &&
                hasLegacyMins[explicitType - 3] && hasLegacyMaxs[explicitType - 3]) {
                pointscap_editor_append_zone(
                    currentLabel,
                    explicitType,
                    legacyMins[explicitType - 3],
                    legacyMaxs[explicitType - 3]
                );
            } else {
                for (new i = 0; i < 3 && g_iZoneCount < MAX_ZONES; i++) {
                    if (hasLegacyMins[i] && hasLegacyMaxs[i]) {
                        pointscap_editor_append_zone(currentLabel, i + 3, legacyMins[i], legacyMaxs[i]);
                    }
                }
            }
        } else if (hasGenericMins && hasGenericMaxs) {
            pointscap_editor_append_zone(
                currentLabel,
                (explicitType >= 3 && explicitType <= 5) ? explicitType : 3,
                genericMins,
                genericMaxs
            );
        }
    }

    fclose(file);
    server_print("[PointScap Editor] pointscap_load_config: loaded %d zones", g_iZoneCount);

    // Reset capture status for all loaded zones
    for (new i = 0; i < g_iZoneCount; i++) {
        g_eZones[i][ZONE_CAPTURED] = 0;
        g_eZones[i][ZONE_CAPTURE_TIME] = 0.0;
        g_eZones[i][ZONE_STATUS] = 0;
    }

    log_amx("[PointScap Editor] 已加载 %d 个点位", g_iZoneCount);
}

/**
 * Create a visual beam point marker
 */
stock create_beam_point(id, Float:origin[3], r, g, b) {
    message_begin(MSG_ONE, SVC_TEMPENTITY, _, id);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + 10.0);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + 50.0);
    write_short(g_sprBeam); // Beam sprite (defined in main plugin)
    write_byte(0); // Start frame
    write_byte(10); // Frame rate
    write_byte(50); // Life
    write_byte(5); // Width
    write_byte(0); // Noise
    write_byte(r);
    write_byte(g);
    write_byte(b);
    write_byte(255); // Brightness
    write_byte(10); // Scroll
    message_end();
}

/**
 * Create a visual beam box for zone
 */
stock create_zone_beam_box(id, Float:mins[3], Float:maxs[3], r, g, b) {
    // Draw box edges using beams
    new Float:corners[8][3];

    // Calculate corners
    corners[0][0] = mins[0]; corners[0][1] = mins[1]; corners[0][2] = mins[2];
    corners[1][0] = maxs[0]; corners[1][1] = mins[1]; corners[1][2] = mins[2];
    corners[2][0] = maxs[0]; corners[2][1] = maxs[1]; corners[2][2] = mins[2];
    corners[3][0] = mins[0]; corners[3][1] = maxs[1]; corners[3][2] = mins[2];
    corners[4][0] = mins[0]; corners[4][1] = mins[1]; corners[4][2] = maxs[2];
    corners[5][0] = maxs[0]; corners[5][1] = mins[1]; corners[5][2] = maxs[2];
    corners[6][0] = maxs[0]; corners[6][1] = maxs[1]; corners[6][2] = maxs[2];
    corners[7][0] = mins[0]; corners[7][1] = maxs[1]; corners[7][2] = maxs[2];

    // Draw bottom rectangle
    draw_beam(id, corners[0], corners[1], r, g, b);
    draw_beam(id, corners[1], corners[2], r, g, b);
    draw_beam(id, corners[2], corners[3], r, g, b);
    draw_beam(id, corners[3], corners[0], r, g, b);

    // Draw top rectangle
    draw_beam(id, corners[4], corners[5], r, g, b);
    draw_beam(id, corners[5], corners[6], r, g, b);
    draw_beam(id, corners[6], corners[7], r, g, b);
    draw_beam(id, corners[7], corners[4], r, g, b);

    // Draw vertical edges
    draw_beam(id, corners[0], corners[4], r, g, b);
    draw_beam(id, corners[1], corners[5], r, g, b);
    draw_beam(id, corners[2], corners[6], r, g, b);
    draw_beam(id, corners[3], corners[7], r, g, b);
}

/**
 * Draw a beam between two points
 */
stock draw_beam(id, Float:start[3], Float:end[3], r, g, b) {
    message_begin(MSG_ONE, SVC_TEMPENTITY, _, id);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, start[0]);
    engfunc(EngFunc_WriteCoord, start[1]);
    engfunc(EngFunc_WriteCoord, start[2]);
    engfunc(EngFunc_WriteCoord, end[0]);
    engfunc(EngFunc_WriteCoord, end[1]);
    engfunc(EngFunc_WriteCoord, end[2]);
    write_short(g_sprBeam);
    write_byte(0);
    write_byte(1);
    write_byte(100); // Life
    write_byte(3); // Width
    write_byte(0);
    write_byte(r);
    write_byte(g);
    write_byte(b);
    write_byte(200);
    write_byte(0);
    message_end();
}

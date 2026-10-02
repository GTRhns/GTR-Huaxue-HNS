// ============================================
// PointScap Zone Loading for HnsMatchSystem
// v5.5 修复:
//   [FIX] cmdDelZone: 删除后保留原始标签，不再强制覆盖为数组索引
//   [FIX] 重新启用自动生成：无 INI 文件时自动生成点位
//   [NEW] /reloadzones: 重新加载点位配置
// ============================================

stock bool:_pointscap_append_zone(iZoneLabel, iZoneType, Float:fMins[3], Float:fMaxs[3]) {
	if (g_iZoneCount >= MAX_ZONES) {
		server_print("[PointScap] Skip zone %c type=%d: MAX_ZONES reached", 'A' + iZoneLabel, iZoneType);
		return false;
	}

	new iZone = g_iZoneCount;
	g_eZones[iZone][ZONE_LABEL] = iZoneLabel;
	g_eZones[iZone][ZONE_ENABLED] = 1;
	g_eZones[iZone][ZONE_STATUS] = 0;
	g_eZones[iZone][ZONE_TYPE] = iZoneType;
	g_eZones[iZone][ZONE_SCORE] = (iZoneType == 3) ? 0.5 : ((iZoneType == 4) ? 1.0 : 2.0);
	g_eZones[iZone][ZONE_CAPTURED] = 0;
	g_eZones[iZone][ZONE_CAPTURE_TIME] = 0.0;
	g_eZones[iZone][ZONE_CAPTURED_TYPE] = 0;
	g_eZones[iZone][ZONE_PLAYER_COUNT] = 0;

	for (new k = 0; k < 3; k++) {
		g_eZones[iZone][ZONE_MINS][k] = fMins[k];
		g_eZones[iZone][ZONE_MAXS][k] = fMaxs[k];
	}

	g_iZoneCount++;

	server_print("[PointScap] Zone %c: type=%d, mins=(%.0f,%.0f,%.0f), maxs=(%.0f,%.0f,%.0f)",
		'A' + iZoneLabel, iZoneType,
		fMins[0], fMins[1], fMins[2],
		fMaxs[0], fMaxs[1], fMaxs[2]);

	return true;
}

stock Float:pointscap_get_zone_score(zoneId) {
	new Float:flScore = g_eZones[zoneId][ZONE_SCORE];
	if (flScore > 0.0) {
		return flScore;
	}

	switch (g_eZones[zoneId][ZONE_TYPE]) {
		case 6, 5: return g_flPointScapScore5;
		case 4: return g_flPointScapScore4;
	}

	return g_flPointScapScore3;
}

stock pointscap_set_default_bounds(iType, Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3]) {
	new Float:flHalfXY;
	new Float:flDown;
	new Float:flUp;

	switch (iType) {
		case 5: {
			flHalfXY = 38.0;
			flDown = 8.0;
			flUp = 68.0;
		}
		case 4: {
			flHalfXY = 52.0;
			flDown = 10.0;
			flUp = 78.0;
		}
		default: {
			flHalfXY = 68.0;
			flDown = 12.0;
			flUp = 88.0;
		}
	}

	fMins[0] = fOrigin[0] - flHalfXY;
	fMins[1] = fOrigin[1] - flHalfXY;
	fMins[2] = fOrigin[2] - flDown;
	fMaxs[0] = fOrigin[0] + flHalfXY;
	fMaxs[1] = fOrigin[1] + flHalfXY;
	fMaxs[2] = fOrigin[2] + flUp;
}

// ============================================
// 加载点位配置 - NOT stock，确保一定被编译
// ============================================
pointscap_load_zones() {
	new szPath[256];
	new szMapName[32];
	get_mapname(szMapName, charsmax(szMapName));
	get_configsdir(szPath, charsmax(szPath));
	g_iZoneCount = 0;
	
	server_print("[PointScap] pointscap_load_zones called for map: %s", szMapName);
	
	format(szPath, charsmax(szPath), "%s/mixsystem/pointscap/%s.ini", szPath, szMapName);
	server_print("[PointScap] Trying path: %s (exists=%d)", szPath, file_exists(szPath));
	
	if (file_exists(szPath)) {
        server_print("[PointScap] Found config file, loading...");
        _pointscap_parse_file(szPath, szMapName);
        server_print("[PointScap] After parse: g_iZoneCount=%d", g_iZoneCount);
        
        // v5.5: 如果解析后zone为0但文件存在，输出文件头10行供debug
        if (g_iZoneCount == 0) {
            server_print("[PointScap] WARNING: 文件存在但解析出0个zone! 文件内容:");
            new hDebug = fopen(szPath, "r");
            if (hDebug) {
                new szDbgLine[256];
                new iLines = 0;
                while (!feof(hDebug) && iLines < 30) {
                    fgets(hDebug, szDbgLine, charsmax(szDbgLine));
                    trim(szDbgLine);
                    server_print("[PointScap]   %s", szDbgLine);
                    iLines++;
                }
                fclose(hDebug);
            }
        }
    } else {
        server_print("[PointScap] No zone config for this map. Use /creatzone [3|4|5] to create.");
        client_print(0, print_chat, "[PointScap] 当前地图无点位配置，管理员请使用 /creatzone 创建。");
    }
}

// ============================================
// 解析配置文件
// ============================================
_pointscap_parse_file(szPath[], szMapName[]) {
	new hFile = fopen(szPath, "r");
	if (!hFile) {
		server_print("[PointScap] Cannot open file: %s", szPath);
		return;
	}
	
	new szLine[256];
	new iZone = -1;
	new iZoneLabel = -1;
	new iExplicitType;
	new Float:fGenericMins[3], Float:fGenericMaxs[3];
	new bool:bHasGenericMins, bool:bHasGenericMaxs;
	new Float:fLegacyMins[3][3], Float:fLegacyMaxs[3][3];
	new bool:bHasLegacyMins[3], bool:bHasLegacyMaxs[3];
	
	while (!feof(hFile) && g_iZoneCount < MAX_ZONES) {
		fgets(hFile, szLine, charsmax(szLine));
		trim(szLine);
		
		if (szLine[0] == ';' || szLine[0] == '/' || !szLine[0]) continue;
		
		if (szLine[0] == '[') {
			new iSavedLabel = iZoneLabel;
			if (iZone >= 0) {
				server_print("[PointScap] Committing section '%c' (iZone=%d, g_iZoneCount=%d)", 'A' + iZoneLabel, iZone, g_iZoneCount);
				new bool:bSectionLoaded = false;

				// ★ 优先检查 legacy 格式（point3/point4/point5），支持每区段多个点位
				// 编辑器保存时同时写入 generic 和 legacy 格式，必须优先解析 legacy
				new bool:bHasAnyLegacy = false;
				for (new idx = 0; idx < 3; idx++) {
					if (bHasLegacyMins[idx] && bHasLegacyMaxs[idx]) {
						bHasAnyLegacy = true;
						break;
					}
				}

				if (bHasAnyLegacy) {
					// 优先使用 legacy 格式（可包含多个点位类型）
					if (iExplicitType >= 3 && iExplicitType <= 5 &&
						bHasLegacyMins[iExplicitType - 3] && bHasLegacyMaxs[iExplicitType - 3]) {
						bSectionLoaded = _pointscap_append_zone(
							iZoneLabel,
							iExplicitType,
							fLegacyMins[iExplicitType - 3],
							fLegacyMaxs[iExplicitType - 3]
						);
						server_print("[PointScap]   -> explicit legacy type=%d loaded=%d", iExplicitType, bSectionLoaded);
					} else {
						for (new idx = 0; idx < 3 && g_iZoneCount < MAX_ZONES; idx++) {
							if (!bHasLegacyMins[idx] || !bHasLegacyMaxs[idx]) {
								continue;
							}

							if (_pointscap_append_zone(iZoneLabel, idx + 3, fLegacyMins[idx], fLegacyMaxs[idx])) {
								bSectionLoaded = true;
								server_print("[PointScap]   -> legacy type=%d appended (g_iZoneCount=%d)", idx + 3, g_iZoneCount);
							}
						}
					}
				} else if (bHasGenericMins && bHasGenericMaxs) {
					// 仅有 generic 格式（纯编辑器新格式）
					new iFinalType = (iExplicitType >= 3 && iExplicitType <= 5) ? iExplicitType : 3;
					bSectionLoaded = _pointscap_append_zone(iZoneLabel, iFinalType, fGenericMins, fGenericMaxs);
					server_print("[PointScap]   -> generic mins/maxs: type=%d loaded=%d", iFinalType, bSectionLoaded);
				}

				if (!bSectionLoaded) {
					server_print("[PointScap] Skip invalid zone section: %c (no complete coords found)", 'A' + iZoneLabel);
				}
			}

			iZoneLabel = szLine[1] - 'A';
			if (iZoneLabel < 0 || iZoneLabel >= MAX_ZONES) {
				iZone = -1;
				continue;
			}

			iZone = g_iZoneCount;
			iExplicitType = 0;
			bHasGenericMins = false;
			bHasGenericMaxs = false;
			for (new idx = 0; idx < 3; idx++) {
				bHasLegacyMins[idx] = false;
				bHasLegacyMaxs[idx] = false;
				for (new k = 0; k < 3; k++) {
					fLegacyMins[idx][k] = 0.0;
					fLegacyMaxs[idx][k] = 0.0;
				}
			}
			for (new k = 0; k < 3; k++) {
				fGenericMins[k] = 0.0;
				fGenericMaxs[k] = 0.0;
			}
			continue;
		}
		
		if (iZone >= 0) {
			new szKey[32], szX[32], szY[32], szZ[32];
			parse(szLine, szKey, charsmax(szKey), szX, charsmax(szX), szY, charsmax(szY), szZ, charsmax(szZ));

			if (equal(szKey, "type")) {
				iExplicitType = str_to_num(szX);
			}
			else if (equal(szKey, "mins")) {
				fGenericMins[0] = str_to_float(szX);
				fGenericMins[1] = str_to_float(szY);
				fGenericMins[2] = str_to_float(szZ);
				bHasGenericMins = true;
			}
			else if (equal(szKey, "maxs")) {
				fGenericMaxs[0] = str_to_float(szX);
				fGenericMaxs[1] = str_to_float(szY);
				fGenericMaxs[2] = str_to_float(szZ);
				bHasGenericMaxs = true;
			}
			else if (equal(szKey, "point3_mins") || equal(szKey, "point4_mins") || equal(szKey, "point5_mins")) {
				new iTypeIndex = szKey[5] - '3';
				if (iTypeIndex >= 0 && iTypeIndex < 3) {
					fLegacyMins[iTypeIndex][0] = str_to_float(szX);
					fLegacyMins[iTypeIndex][1] = str_to_float(szY);
					fLegacyMins[iTypeIndex][2] = str_to_float(szZ);
					bHasLegacyMins[iTypeIndex] = true;
				}
			}
			else if (equal(szKey, "point3_maxs") || equal(szKey, "point4_maxs") || equal(szKey, "point5_maxs")) {
				new iTypeIndex = szKey[5] - '3';
				if (iTypeIndex >= 0 && iTypeIndex < 3) {
					fLegacyMaxs[iTypeIndex][0] = str_to_float(szX);
					fLegacyMaxs[iTypeIndex][1] = str_to_float(szY);
					fLegacyMaxs[iTypeIndex][2] = str_to_float(szZ);
					bHasLegacyMaxs[iTypeIndex] = true;
				}
			}
		}
	}
	
	if (iZone >= 0 && g_iZoneCount < MAX_ZONES) {
		new bool:bSectionLoaded = false;

		// ★ 优先检查 legacy 格式（point3/point4/point5），支持每区段多个点位
		new bool:bHasAnyLegacy = false;
		for (new idx = 0; idx < 3; idx++) {
			if (bHasLegacyMins[idx] && bHasLegacyMaxs[idx]) {
				bHasAnyLegacy = true;
				break;
			}
		}

		if (bHasAnyLegacy) {
			if (iExplicitType >= 3 && iExplicitType <= 5 &&
				bHasLegacyMins[iExplicitType - 3] && bHasLegacyMaxs[iExplicitType - 3]) {
				bSectionLoaded = _pointscap_append_zone(
					iZoneLabel,
					iExplicitType,
					fLegacyMins[iExplicitType - 3],
					fLegacyMaxs[iExplicitType - 3]
				);
			} else {
				for (new idx = 0; idx < 3 && g_iZoneCount < MAX_ZONES; idx++) {
					if (!bHasLegacyMins[idx] || !bHasLegacyMaxs[idx]) {
						continue;
					}

					if (_pointscap_append_zone(iZoneLabel, idx + 3, fLegacyMins[idx], fLegacyMaxs[idx])) {
						bSectionLoaded = true;
					}
				}
			}
		} else if (bHasGenericMins && bHasGenericMaxs) {
			new iFinalType = (iExplicitType >= 3 && iExplicitType <= 5) ? iExplicitType : 3;
			bSectionLoaded = _pointscap_append_zone(iZoneLabel, iFinalType, fGenericMins, fGenericMaxs);
		}

		if (!bSectionLoaded) {
			server_print("[PointScap] Skip invalid zone section: %c (no complete coords found)", 'A' + iZoneLabel);
		}
	}
	fclose(hFile);
}

// ============================================
// 自动生成点位 - 从实体位置生成
// ============================================
_pointscap_auto_generate(szMapName[]) {
	new Float:spawns[64][3];
	new iSpawnCount = 0;
	
	// 尝试多种实体类型
	new const szEntTypes[][] = {
		"info_player_deathmatch",
		"info_player_start",
		"info_player_terrorist",
		"info_player_counterterrorist",
		"info_target"
	};
	
	for (new t = 0; t < sizeof(szEntTypes); t++) {
		new iEnt = -1;
		while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", szEntTypes[t])) > 0) {
			if (iSpawnCount >= 64) break;
			get_entvar(iEnt, var_origin, spawns[iSpawnCount]);
			iSpawnCount++;
		}
		server_print("[PointScap] Entity type '%s': found %d total so far", szEntTypes[t], iSpawnCount);
	}
	
	// Fallback: 使用所有玩家当前位置
	if (iSpawnCount == 0) {
		server_print("[PointScap] No entities found, using player positions...");
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum && iSpawnCount < 64; i++) {
			new id = iPlayers[i];
			if (!is_user_alive(id)) continue;
			get_entvar(id, var_origin, spawns[iSpawnCount]);
			iSpawnCount++;
		}
	}

	// Last resort: map center
	if (iSpawnCount == 0) {
		server_print("[PointScap] No positions found, using map center (0,0,0)...");
		spawns[0][0] = 0.0;
		spawns[0][1] = 0.0;
		spawns[0][2] = 0.0;
		iSpawnCount = 1;
	}

	server_print("[PointScap] Got %d position(s) for zone generation", iSpawnCount);

	// 聚类
	new iClusters = 0;
	new iClusterMembers[10][64];
	new iClusterCount[10];

	for (new s = 0; s < iSpawnCount; s++) {
		new bFound = 0;
		for (new c = 0; c < iClusters; c++) {
			for (new m = 0; m < iClusterCount[c]; m++) {
				new idx = iClusterMembers[c][m];
				new Float:dist = floatsqroot(
					(spawns[s][0] - spawns[idx][0]) * (spawns[s][0] - spawns[idx][0]) +
					(spawns[s][1] - spawns[idx][1]) * (spawns[s][1] - spawns[idx][1]) +
					(spawns[s][2] - spawns[idx][2]) * (spawns[s][2] - spawns[idx][2])
				);
				if (dist < 500.0) {
					iClusterMembers[c][iClusterCount[c]++] = s;
					bFound = 1;
					break;
				}
			}
			if (bFound) break;
		}
		if (!bFound && iClusters < 10) {
			iClusterMembers[iClusters][0] = s;
			iClusterCount[iClusters] = 1;
			iClusters++;
		}
	}

	server_print("[PointScap] Clustered into %d zone(s)", iClusters);

	// 写入内存并尝试保存文件
	new szPath[256], szDir[128];
	get_configsdir(szDir, charsmax(szDir));
	
	format(szDir, charsmax(szDir), "%s/mixsystem/pointscap", szDir);
	if (!dir_exists(szDir)) {
		mkdir(szDir);
	}
	
	format(szPath, charsmax(szPath), "%s/%s.ini", szDir, szMapName);

	for (new c = 0; c < iClusters && c < MAX_ZONES; c++) {
		new Float:minX = 99999.0, Float:minY = 99999.0, Float:minZ = 99999.0;
		new Float:maxX = -99999.0, Float:maxY = -99999.0, Float:maxZ = -99999.0;

		for (new m = 0; m < iClusterCount[c]; m++) {
			new idx = iClusterMembers[c][m];
			if (spawns[idx][0] < minX) minX = spawns[idx][0];
			if (spawns[idx][1] < minY) minY = spawns[idx][1];
			if (spawns[idx][2] < minZ) minZ = spawns[idx][2];
			if (spawns[idx][0] > maxX) maxX = spawns[idx][0];
			if (spawns[idx][1] > maxY) maxY = spawns[idx][1];
			if (spawns[idx][2] > maxZ) maxZ = spawns[idx][2];
		}

		minX -= 70.0; minY -= 70.0; minZ -= 15.0;
		maxX += 70.0; maxY += 70.0; maxZ += 90.0;

		// 写入 g_eZones (内存)
		g_eZones[c][ZONE_ENABLED] = 1;
		g_eZones[c][ZONE_LABEL] = c;
		g_eZones[c][ZONE_STATUS] = 0;
		g_eZones[c][ZONE_TYPE] = 3;
		g_eZones[c][ZONE_SCORE] = g_flPointScapScore3;
		g_eZones[c][ZONE_CAPTURED] = 0;
		g_eZones[c][ZONE_CAPTURE_TIME] = 0.0;
		g_eZones[c][ZONE_CAPTURED_TYPE] = 0;
		g_eZones[c][ZONE_PLAYER_COUNT] = 0;
		g_eZones[c][ZONE_MINS][0] = minX;
		g_eZones[c][ZONE_MINS][1] = minY;
		g_eZones[c][ZONE_MINS][2] = minZ;
		g_eZones[c][ZONE_MAXS][0] = maxX;
		g_eZones[c][ZONE_MAXS][1] = maxY;
		g_eZones[c][ZONE_MAXS][2] = maxZ;

		server_print("[PointScap] Zone %c: auto type=3, mins=(%.0f,%.0f,%.0f), maxs=(%.0f,%.0f,%.0f)",
			'A' + c, minX, minY, minZ, maxX, maxY, maxZ);
	}

	g_iZoneCount = (iClusters < MAX_ZONES) ? iClusters : MAX_ZONES;

	// 保存到文件（尝试fopen写）
	new hSave = fopen(szPath, "w");
	if (hSave) {
		fprintf(hSave, "; Auto PointScap zones for %s^n; Generated by HnsMatchSystem^n^n", szMapName);
		for (new c = 0; c < iClusters && c < MAX_ZONES; c++) {
			fprintf(hSave, "[%c]^ntype 3^nmins %.0f %.0f %.0f^nmaxs %.0f %.0f %.0f^n^n",
				'A' + c,
				g_eZones[c][ZONE_MINS][0], g_eZones[c][ZONE_MINS][1], g_eZones[c][ZONE_MINS][2],
				g_eZones[c][ZONE_MAXS][0], g_eZones[c][ZONE_MAXS][1], g_eZones[c][ZONE_MAXS][2]);
		}
		fclose(hSave);
		server_print("[PointScap] Saved zone config: %s", szPath);
	} else {
		server_print("[PointScap] Cannot save to %s (dir may not exist), zones in memory only", szPath);
	}
}

// ============================================
// 辅助：解析坐标
// ============================================
parse_coords(const szValue[], Float:coords[3]) {
	new szX[32], szY[32], szZ[32];
	parse(szValue, szX, charsmax(szX), szY, charsmax(szY), szZ, charsmax(szZ));
	coords[0] = str_to_float(szX);
	coords[1] = str_to_float(szY);
	coords[2] = str_to_float(szZ);
}

// ============================================
// 保存点位到INI文件
// ============================================
_save_zones_ini(szPath[], szMapName[]) {
	new szDir[128];
	get_configsdir(szDir, charsmax(szDir));
	format(szDir, charsmax(szDir), "%s/mixsystem/pointscap", szDir);
	if (!dir_exists(szDir)) {
		mkdir(szDir);
	}

	new hSave = fopen(szPath, "w");
	if (hSave) {
		fprintf(hSave, "; PointScap zones for %s^n; Recorded manually^n^n", szMapName);
		for (new i = 0; i < g_iZoneCount; i++) {
			// ★ 使用 zone 的实际 Label 而非数组索引
			// v5.5 FIX: 同时写 legacy 格式，确保解析器稳定识别
			fprintf(hSave, "[%c]^n", 'A' + g_eZones[i][ZONE_LABEL]);
			fprintf(hSave, "type %d^n", g_eZones[i][ZONE_TYPE]);
			fprintf(hSave, "mins %.0f %.0f %.0f^n", g_eZones[i][ZONE_MINS][0], g_eZones[i][ZONE_MINS][1], g_eZones[i][ZONE_MINS][2]);
			fprintf(hSave, "maxs %.0f %.0f %.0f^n", g_eZones[i][ZONE_MAXS][0], g_eZones[i][ZONE_MAXS][1], g_eZones[i][ZONE_MAXS][2]);
			// ★ 写 legacy 格式（point3/4/5_mins/maxs），解析器优先走 legacy 路径
			fprintf(hSave, "point%d_mins %.0f %.0f %.0f^n", g_eZones[i][ZONE_TYPE], g_eZones[i][ZONE_MINS][0], g_eZones[i][ZONE_MINS][1], g_eZones[i][ZONE_MINS][2]);
			fprintf(hSave, "point%d_maxs %.0f %.0f %.0f^n", g_eZones[i][ZONE_TYPE], g_eZones[i][ZONE_MAXS][0], g_eZones[i][ZONE_MAXS][1], g_eZones[i][ZONE_MAXS][2]);
			fprintf(hSave, "^n");
		}
		fclose(hSave);
		server_print("[PointScap] 已保存点位: %s (%d zones)", szPath, g_iZoneCount);
	} else {
		server_print("[PointScap] 无法保存到 %s", szPath);
	}
}

// ============================================
// 手动录制点位命令
// /creatzone [3|4|5] - 以玩家当前位置为中心创建点位
// /delzone <A-Z>      - 删除指定点位
// /listzones          - 列出所有点位
// /savezones          - 保存点位到INI
// ============================================

// 获取当前地图的点位INI路径
_get_zone_ini_path(szPath[], len) {
	new szMapName[32];
	get_mapname(szMapName, charsmax(szMapName));
	get_configsdir(szPath, len);
	format(szPath, len, "%s/mixsystem/pointscap/%s.ini", szPath, szMapName);
}

public cmdCreatZone(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	if (get_user_flags(id) & ADMIN_RCON) {
		// admin only
	} else {
		client_print(id, print_chat, "[PointScap] 仅管理员可创建点位.");
		return PLUGIN_HANDLED;
	}

	if (g_iZoneCount >= MAX_ZONES) {
		client_print(id, print_chat, "[PointScap] 已达最大点位数量 (%d)!", MAX_ZONES);
		return PLUGIN_HANDLED;
	}

	// 读取类型参数
	new szArg[8], iType = 3;
	read_argv(1, szArg, charsmax(szArg));
	if (szArg[0]) iType = str_to_num(szArg);
	if (iType < 3) iType = 3;
	if (iType > 5) iType = 5;

	// 获取玩家位置（使用 pev_origin 作为脚底基准）
	new Float:fOrigin[3];
	pev(id, pev_origin, fOrigin);
	
	new Float:fMins[3], Float:fMaxs[3];
	pointscap_set_default_bounds(iType, fOrigin, fMins, fMaxs);

	new i = g_iZoneCount;
	g_eZones[i][ZONE_ENABLED] = 1;
	g_eZones[i][ZONE_LABEL] = i;
	g_eZones[i][ZONE_STATUS] = 0;
	g_eZones[i][ZONE_TYPE] = iType;
	g_eZones[i][ZONE_SCORE] = (iType == 5) ? g_flPointScapScore5 : ((iType == 4) ? g_flPointScapScore4 : g_flPointScapScore3);
	g_eZones[i][ZONE_CAPTURED] = 0;
	g_eZones[i][ZONE_CAPTURE_TIME] = 0.0;
	g_eZones[i][ZONE_CAPTURED_TYPE] = 0;
	g_eZones[i][ZONE_PLAYER_COUNT] = 0;
	g_eZones[i][ZONE_MINS][0] = fMins[0];
	g_eZones[i][ZONE_MINS][1] = fMins[1];
	g_eZones[i][ZONE_MINS][2] = fMins[2];
	g_eZones[i][ZONE_MAXS][0] = fMaxs[0];
	g_eZones[i][ZONE_MAXS][1] = fMaxs[1];
	g_eZones[i][ZONE_MAXS][2] = fMaxs[2];
	g_iZoneCount++;

	new szPath[256], szMapName[32];
	_get_zone_ini_path(szPath, charsmax(szPath));
	get_mapname(szMapName, charsmax(szMapName));
	_save_zones_ini(szPath, szMapName);

	client_print(id, print_chat, "[PointScap] 点位 %c 已创建! 类型=%d人, 坐标=(%.0f,%.0f,%.0f)", 
		'A' + i, iType, fOrigin[0], fOrigin[1], fOrigin[2]);
	client_print(id, print_chat, "[PointScap] 判定框: %.0fx%.0fx%.0f, 已自动保存.",
		fMaxs[0] - fMins[0], fMaxs[1] - fMins[1], fMaxs[2] - fMins[2]);

	return PLUGIN_HANDLED;
}

public cmdDelZone(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	if (!(get_user_flags(id) & ADMIN_RCON)) {
		client_print(id, print_chat, "[PointScap] 仅管理员可删除点位.");
		return PLUGIN_HANDLED;
	}

	new szArg[4];
	read_argv(1, szArg, charsmax(szArg));
	if (!szArg[0]) {
		client_print(id, print_chat, "[PointScap] 用法: /delzone <A-Z>");
		return PLUGIN_HANDLED;
	}

	new iLabel = szArg[0] - 'A';
	new iDeleteIndex = -1;
	for (new i = 0; i < g_iZoneCount; i++) {
		if (g_eZones[i][ZONE_LABEL] == iLabel) {
			iDeleteIndex = i;
			break;
		}
	}
	if (iDeleteIndex == -1) {
		client_print(id, print_chat, "[PointScap] 未找到点位 %c.", szArg[0]);
		return PLUGIN_HANDLED;
	}

	// v5.5 FIX: 删除后将后面的区域前移，但保留原始 ZONE_LABEL（字母标签）
    // 原来的 g_eZones[i][ZONE_LABEL] = i 会把 B/C/D... 标签污染为 A/B/C...
    // 导致保存后 INI 文件 section 标签错乱，比赛只认 A 点
    for (new i = iDeleteIndex; i < g_iZoneCount - 1; i++) {
        g_eZones[i] = g_eZones[i + 1];
        // 不再强制覆盖 ZONE_LABEL，保留原始字母标签
    }
	g_iZoneCount--;

	new szPath[256], szMapName[32];
	_get_zone_ini_path(szPath, charsmax(szPath));
	get_mapname(szMapName, charsmax(szMapName));
	_save_zones_ini(szPath, szMapName);

	client_print(id, print_chat, "[PointScap] 点位 %c 已删除. 剩余 %d 个点位.", szArg[0], g_iZoneCount);
	client_print(id, print_chat, "[PointScap] 点位文件已自动更新.");

	return PLUGIN_HANDLED;
}

public cmdListZones(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	if (g_iZoneCount == 0) {
		client_print(id, print_chat, "[PointScap] 暂无点位. 使用 /creatzone [3|4|5] 创建.");
		return PLUGIN_HANDLED;
	}

	new szLine[192], iLen;
	for (new i = 0; i < g_iZoneCount; i++) {
		iLen = 0;
		iLen += formatex(szLine, charsmax(szLine), "[PointScap] %c: 类型=%d人 ", 'A' + g_eZones[i][ZONE_LABEL], g_eZones[i][ZONE_TYPE]);
		iLen += formatex(szLine[iLen], charsmax(szLine) - iLen, "mins=(%.0f,%.0f,%.0f) ", 
			g_eZones[i][ZONE_MINS][0], g_eZones[i][ZONE_MINS][1], g_eZones[i][ZONE_MINS][2]);
		iLen += formatex(szLine[iLen], charsmax(szLine) - iLen, "maxs=(%.0f,%.0f,%.0f)",
			g_eZones[i][ZONE_MAXS][0], g_eZones[i][ZONE_MAXS][1], g_eZones[i][ZONE_MAXS][2]);
		client_print(id, print_chat, "%s", szLine);
	}

	return PLUGIN_HANDLED;
}

public cmdSaveZones(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	if (!(get_user_flags(id) & ADMIN_RCON)) {
		client_print(id, print_chat, "[PointScap] 仅管理员可保存点位.");
		return PLUGIN_HANDLED;
	}

	if (g_iZoneCount == 0) {
		client_print(id, print_chat, "[PointScap] 没有点位可保存!");
		return PLUGIN_HANDLED;
	}

	new szPath[256], szMapName[32];
	_get_zone_ini_path(szPath, charsmax(szPath));
	get_mapname(szMapName, charsmax(szMapName));

	_save_zones_ini(szPath, szMapName);

	client_print(id, print_chat, "[PointScap] 已保存 %d 个点位到 %s", g_iZoneCount, szPath);
	client_print(0, print_chat, "[PointScap] 点位已保存! 重启比赛后生效.");

	return PLUGIN_HANDLED;
}

// v5.5: 重新加载点位配置（无需重启服务器）
public cmdReloadZones(id) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (!(get_user_flags(id) & ADMIN_RCON)) {
        client_print(id, print_chat, "[PointScap] 仅管理员可重新加载点位.");
        return PLUGIN_HANDLED;
    }

    pointscap_load_zones();
    client_print(id, print_chat, "[PointScap] 点位已重新加载. 共 %d 个点位.", g_iZoneCount);
    client_print(0, print_chat, "[PointScap] 管理员 %n 重新加载了点位配置 (%d个点位).", id, g_iZoneCount);

    return PLUGIN_HANDLED;
}

// ============================================
// 辅助：判断玩家是否在区域内
// ============================================
bool:is_player_in_box(id, Float:mins[3], Float:maxs[3]) {
	if (!is_user_alive(id)) return false;
	
	// 用玩家实际包围盒做相交检测，而不是 center point
	new Float:fAbsMin[3], Float:fAbsMax[3];
	get_entvar(id, var_absmin, fAbsMin);
	get_entvar(id, var_absmax, fAbsMax);
	
	// 两个包围盒相交检测
	return (fAbsMax[0] >= mins[0] && fAbsMin[0] <= maxs[0] &&
			fAbsMax[1] >= mins[1] && fAbsMin[1] <= maxs[1] &&
			fAbsMax[2] >= mins[2] && fAbsMin[2] <= maxs[2]);
}

/*
 * HnsPersistentDataStorage.sma
 * 持久数据存储插件 (nvault 实现)
 *
 * 作用:
 *   - 提供 PersistentDataStorage 库: PDS_SetCell/GetCell/SetArray/GetArray/
 *     SetString/GetString natives 与 PDS_Save forward。
 *   - HnsMatchSystem 在编译时 #include <PersistentDataStorage>, 运行时要求
 *     库 "PersistentDataStorage" 已加载, 否则比赛系统拒绝启动。
 *     本插件即该库的提供方。
 *
 * 存储方式:
 *   每个 key 对应 nvault 一条记录, 写入即持久化
 *   (文件: addons/amxmodx/data/vault/hns_pds.vault)。
 *   PDS_Save forward 在插件卸载(换图/关服)前触发, 供消费方刷新易变数据。
 *
 * 注意:
 *   本插件必须注册在 plugins.ini 中, 且位于 HnsMatchSystem 之前,
 *   保证比赛系统加载时库已存在。
 */

#include <amxmodx>
#include <nvault>

#define VAULT_NAME "hns_pds"

new g_iVault;
new g_hSaveForward;

public plugin_init() {
	register_plugin("Hns Persistent Data Storage", "1.0", "OpenHNS");

	g_iVault = nvault_open(VAULT_NAME);
	g_hSaveForward = CreateMultiForward("PDS_Save", ET_IGNORE);
}

public plugin_end() {
	// 卸载前通知消费方刷新数据 (save.inc 的 PDS_Save 会重新 PDS_Set*)
	if (g_hSaveForward != INVALID_HANDLE) {
		ExecuteForward(g_hSaveForward, _);
		DestroyForward(g_hSaveForward);
		g_hSaveForward = INVALID_HANDLE;
	}

	if (g_iVault != INVALID_HANDLE) {
		nvault_close(g_iVault);
		g_iVault = INVALID_HANDLE;
	}
}

public plugin_natives() {
	// 必须在 plugin_natives() 注册: AMXX 在"插件加载时"就校验 #pragma reqlib,
	// 早于 plugin_init(), 放到 plugin_init() 会导致 HnsMatchSystem bad load。
	register_library("PersistentDataStorage");

	register_native("PDS_SetCell", "native_set_cell");
	register_native("PDS_GetCell", "native_get_cell");
	register_native("PDS_SetArray", "native_set_array");
	register_native("PDS_GetArray", "native_get_array");
	register_native("PDS_SetString", "native_set_string");
	register_native("PDS_GetString", "native_get_string");
}

/* PDS_SetCell(key, data) */
public native_set_cell(amxx, params) {
	enum { arg_key = 1, arg_data };

	new szKey[64], szData[16];
	get_string(arg_key, szKey, charsmax(szKey));
	num_to_str(get_param(arg_data), szData, charsmax(szData));

	nvault_set(g_iVault, szKey, szData);
	return 1;
}

/* bool:PDS_GetCell(key, &data) */
public native_get_cell(amxx, params) {
	enum { arg_key = 1, arg_data };

	new szKey[64], szData[16];
	get_string(arg_key, szKey, charsmax(szKey));

	if (!nvault_get(g_iVault, szKey, szData, charsmax(szData)) || !szData[0]) {
		set_param_byref(arg_data, 0);
		return 0;
	}

	set_param_byref(arg_data, str_to_num(szData));
	return 1;
}

/* PDS_SetString(key, data[]) */
public native_set_string(amxx, params) {
	enum { arg_key = 1, arg_data };

	new szKey[64], szData[4096];
	get_string(arg_key, szKey, charsmax(szKey));
	get_string(arg_data, szData, charsmax(szData));

	nvault_set(g_iVault, szKey, szData);
	return 1;
}

/* bool:PDS_GetString(key, buffer[], maxLength)
 * playerslist 是玩家 JSON 数组, 可能较长, 用大缓冲一次性取回。 */
public native_get_string(amxx, params) {
	enum { arg_key = 1, arg_buffer, arg_maxlen };

	new szKey[64], szData[4096];
	get_string(arg_key, szKey, charsmax(szKey));

	new iMaxLen = get_param(arg_maxlen);
	if (iMaxLen > charsmax(szData))
		iMaxLen = charsmax(szData);

	if (!nvault_get(g_iVault, szKey, szData, iMaxLen) || !szData[0]) {
		set_string(arg_buffer, "", get_param(arg_maxlen));
		return 0;
	}

	set_string(arg_buffer, szData, get_param(arg_maxlen));
	return 1;
}

/* PDS_SetArray(key, data[], size)
 * nvault 无法直接存二进制, 以空格分隔数字字符串存储。
 * 注: AMXX 1.8 的 get_array 无位置参数, 一次性读取整个数组。 */
public native_set_array(amxx, params) {
	enum { arg_key = 1, arg_data, arg_size };

	new szKey[64], szBuf[2048], iArr[256];
	get_string(arg_key, szKey, charsmax(szKey));

	new iSize = get_param(arg_size);
	if (iSize > 256)
		iSize = 256;
	get_array(arg_data, iArr, iSize);

	new iLen = 0;
	for (new i = 0; i < iSize && iLen < charsmax(szBuf); i++) {
		if (i)
			szBuf[iLen++] = ' ';
		iLen += num_to_str(iArr[i], szBuf[iLen], charsmax(szBuf) - iLen);
	}

	nvault_set(g_iVault, szKey, szBuf);
	return 1;
}

/* bool:PDS_GetArray(key, data[], size) */
public native_get_array(amxx, params) {
	enum { arg_key = 1, arg_data, arg_size };

	new szKey[64], szBuf[2048], iArr[256];
	get_string(arg_key, szKey, charsmax(szKey));

	new iSize = get_param(arg_size);
	if (iSize > 256)
		iSize = 256;

	arrayset(iArr, 0, iSize);

	new iIndex = 0;
	if (nvault_get(g_iVault, szKey, szBuf, charsmax(szBuf)) && szBuf[0]) {
		new iPos, szNum[16];

		while (szBuf[iPos] && iIndex < iSize) {
			new iStart = iPos;
			while (szBuf[iPos] && szBuf[iPos] != ' ')
				iPos++;

			copy(szNum, iPos - iStart + 1, szBuf[iStart]);
			iArr[iIndex++] = str_to_num(szNum);

			while (szBuf[iPos] == ' ')
				iPos++;
		}
	}

	set_array(arg_data, iArr, iSize);

	return iIndex ? 1 : 0;
}

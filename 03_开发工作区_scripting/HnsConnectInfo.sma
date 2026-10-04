/* ============================================================
   HnsConnectInfo  -  进服提示
   ------------------------------------------------------------
   玩家进入服务器时，按每人 /lang 发送聊天提示:
     [HNS] 房主 LINNA 已连接 (中国) [正版]
     [HNS] PTS / 段位 / 胜负 / 胜率 / GBIC
     [HNS] SteamID / 排名 / 延迟 / 在线

   依赖:
     - HnsLanguage.amxx   (/lang 简体/繁体/英语/俄语)
     - HnsMatchPts.amxx   (PTS, 可选; 未加载时显示默认 1000)
     - hns_gc             (GBIC, 可选)
     - Reunion            (正版/盗版, 可选)
     - geoip              (国家, 可选; 无模块时显示未知地区)
   ============================================================ */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_language>
#include <hns_matchsystem_pts>
#include <hns_gc>

#define PLUGIN_NAME    "HNS Connect Info"
#define PLUGIN_VERSION "1.4.1"
#define PLUGIN_AUTHOR  "GTR"

#define TASK_ANNOUNCE  54000
#define ANNOUNCE_DELAY 1.80
#define ANNOUNCE_RETRY 1.20
#define ANNOUNCE_MAX   6.50

#define MSG_MAX 191
#define NAME_MAX 32
#define AUTH_MAX 35
#define IP_MAX 22
#define COUNTRY_MAX 48

native bool:geoip_code2_ex(const ip[], result[3]);
native geoip_country_ex(const ip[], result[], len, id = -1);

new bool:g_bNeedAnnounce[MAX_PLAYERS + 1];
new bool:g_bAnnounced[MAX_PLAYERS + 1];
new Float:g_flJoinTime[MAX_PLAYERS + 1];
new g_pEnabled;
new g_pSound;
new bool:g_bHasReunion;
new bool:g_bHasGeoIP = true;

enum _:COUNTRY_INFO {
COUNTRY_CODE[4],
COUNTRY_CN[24],
COUNTRY_TW[24],
COUNTRY_EN[24],
COUNTRY_RU[48]
}

new const g_szCountry[][COUNTRY_INFO] = {
{ "CN", "中国", "中國", "China", "Китай" },
{ "HK", "香港", "香港", "Hong Kong", "Гонконг" },
{ "TW", "台湾", "台灣", "Taiwan", "Тайвань" },
{ "MO", "澳门", "澳門", "Macao", "Макао" },
{ "JP", "日本", "日本", "Japan", "Япония" },
{ "KR", "韩国", "韓國", "South Korea", "Южная Корея" },
{ "KP", "朝鲜", "朝鮮", "North Korea", "КНДР" },
{ "MN", "蒙古", "蒙古", "Mongolia", "Монголия" },
{ "VN", "越南", "越南", "Vietnam", "Вьетнам" },
{ "TH", "泰国", "泰國", "Thailand", "Таиланд" },
{ "MY", "马来西亚", "馬來西亞", "Malaysia", "Малайзия" },
{ "SG", "新加坡", "新加坡", "Singapore", "Сингапур" },
{ "ID", "印度尼西亚", "印尼", "Indonesia", "Индонезия" },
{ "PH", "菲律宾", "菲律賓", "Philippines", "Филиппины" },
{ "IN", "印度", "印度", "India", "Индия" },
{ "PK", "巴基斯坦", "巴基斯坦", "Pakistan", "Пакистан" },
{ "BD", "孟加拉", "孟加拉", "Bangladesh", "Бангладеш" },
{ "NP", "尼泊尔", "尼泊爾", "Nepal", "Непал" },
{ "LK", "斯里兰卡", "斯里蘭卡", "Sri Lanka", "Шри-Ланка" },
{ "MM", "缅甸", "緬甸", "Myanmar", "Мьянма" },
{ "KH", "柬埔寨", "柬埔寨", "Cambodia", "Камбоджа" },
{ "LA", "老挝", "寮國", "Laos", "Лаос" },
{ "RU", "俄罗斯", "俄羅斯", "Russia", "Россия" },
{ "UA", "乌克兰", "烏克蘭", "Ukraine", "Украина" },
{ "BY", "白俄罗斯", "白俄羅斯", "Belarus", "Беларусь" },
{ "KZ", "哈萨克斯坦", "哈薩克", "Kazakhstan", "Казахстан" },
{ "UZ", "乌兹别克斯坦", "烏茲別克", "Uzbekistan", "Узбекистан" },
{ "KG", "吉尔吉斯斯坦", "吉爾吉斯", "Kyrgyzstan", "Кыргызстан" },
{ "TJ", "塔吉克斯坦", "塔吉克", "Tajikistan", "Таджикистан" },
{ "TM", "土库曼斯坦", "土庫曼", "Turkmenistan", "Туркменистан" },
{ "AZ", "阿塞拜疆", "亞塞拜然", "Azerbaijan", "Азербайджан" },
{ "AM", "亚美尼亚", "亞美尼亞", "Armenia", "Армения" },
{ "GE", "格鲁吉亚", "喬治亞", "Georgia", "Грузия" },
{ "MD", "摩尔多瓦", "摩爾多瓦", "Moldova", "Молдова" },
{ "TR", "土耳其", "土耳其", "Turkey", "Турция" },
{ "US", "美国", "美國", "United States", "США" },
{ "CA", "加拿大", "加拿大", "Canada", "Канада" },
{ "MX", "墨西哥", "墨西哥", "Mexico", "Мексика" },
{ "BR", "巴西", "巴西", "Brazil", "Бразилия" },
{ "AR", "阿根廷", "阿根廷", "Argentina", "Аргентина" },
{ "CL", "智利", "智利", "Chile", "Чили" },
{ "CO", "哥伦比亚", "哥倫比亞", "Colombia", "Колумбия" },
{ "PE", "秘鲁", "秘魯", "Peru", "Перу" },
{ "VE", "委内瑞拉", "委內瑞拉", "Venezuela", "Венесуэла" },
{ "GB", "英国", "英國", "United Kingdom", "Британия" },
{ "DE", "德国", "德國", "Germany", "Германия" },
{ "FR", "法国", "法國", "France", "Франция" },
{ "IT", "意大利", "義大利", "Italy", "Италия" },
{ "ES", "西班牙", "西班牙", "Spain", "Испания" },
{ "NL", "荷兰", "荷蘭", "Netherlands", "Нидерланды" },
{ "PL", "波兰", "波蘭", "Poland", "Польша" },
{ "SE", "瑞典", "瑞典", "Sweden", "Швеция" },
{ "NO", "挪威", "挪威", "Norway", "Норвегия" },
{ "FI", "芬兰", "芬蘭", "Finland", "Финляндия" },
{ "DK", "丹麦", "丹麥", "Denmark", "Дания" },
{ "CZ", "捷克", "捷克", "Czechia", "Чехия" },
{ "SK", "斯洛伐克", "斯洛伐克", "Slovakia", "Словакия" },
{ "HU", "匈牙利", "匈牙利", "Hungary", "Венгрия" },
{ "RO", "罗马尼亚", "羅馬尼亞", "Romania", "Румыния" },
{ "BG", "保加利亚", "保加利亞", "Bulgaria", "Болгария" },
{ "GR", "希腊", "希臘", "Greece", "Греция" },
{ "PT", "葡萄牙", "葡萄牙", "Portugal", "Португалия" },
{ "AT", "奥地利", "奧地利", "Austria", "Австрия" },
{ "CH", "瑞士", "瑞士", "Switzerland", "Швейцария" },
{ "BE", "比利时", "比利時", "Belgium", "Бельгия" },
{ "IE", "爱尔兰", "愛爾蘭", "Ireland", "Ирландия" },
{ "LT", "立陶宛", "立陶宛", "Lithuania", "Литва" },
{ "LV", "拉脱维亚", "拉脫維亞", "Latvia", "Латвия" },
{ "EE", "爱沙尼亚", "愛沙尼亞", "Estonia", "Эстония" },
{ "RS", "塞尔维亚", "塞爾維亞", "Serbia", "Сербия" },
{ "HR", "克罗地亚", "克羅埃西亞", "Croatia", "Хорватия" },
{ "SI", "斯洛文尼亚", "斯洛維尼亞", "Slovenia", "Словения" },
{ "BA", "波黑", "波士尼亞", "Bosnia", "Босния" },
{ "AL", "阿尔巴尼亚", "阿爾巴尼亞", "Albania", "Албания" },
{ "MK", "北马其顿", "北馬其頓", "N. Macedonia", "С. Македония" },
{ "SA", "沙特", "沙烏地", "Saudi Arabia", "Сауд. Аравия" },
{ "AE", "阿联酋", "阿聯酋", "UAE", "ОАЭ" },
{ "IL", "以色列", "以色列", "Israel", "Израиль" },
{ "EG", "埃及", "埃及", "Egypt", "Египет" },
{ "IR", "伊朗", "伊朗", "Iran", "Иран" },
{ "IQ", "伊拉克", "伊拉克", "Iraq", "Ирак" },
{ "QA", "卡塔尔", "卡達", "Qatar", "Катар" },
{ "KW", "科威特", "科威特", "Kuwait", "Кувейт" },
{ "JO", "约旦", "約旦", "Jordan", "Иордания" },
{ "LB", "黎巴嫩", "黎巴嫩", "Lebanon", "Ливан" },
{ "AU", "澳大利亚", "澳洲", "Australia", "Австралия" },
{ "NZ", "新西兰", "紐西蘭", "New Zealand", "Н. Зеландия" },
{ "ZA", "南非", "南非", "South Africa", "ЮАР" },
{ "NG", "尼日利亚", "奈及利亞", "Nigeria", "Нигерия" },
{ "KE", "肯尼亚", "肯亞", "Kenya", "Кения" },
{ "MA", "摩洛哥", "摩洛哥", "Morocco", "Марокко" }
};

public plugin_natives() {
set_native_filter("NativeFilter");
}

public NativeFilter(const szName[], iIndex, iTrap) {
if (equal(szName, "HnsLang_Get")
|| equal(szName, "HnsLang_GetPlayer")
|| equal(szName, "hns_gc_sql_available")
|| equal(szName, "hns_gc_sql_get")
|| equal(szName, "hns_gc_sql_set")
|| equal(szName, "hns_gc_local_available")
|| equal(szName, "hns_gc_local_get")
|| equal(szName, "hns_gc_local_set")
|| equal(szName, "has_reunion")
|| equal(szName, "REU_GetAuthtype")
|| equal(szName, "geoip_code2_ex")
|| equal(szName, "geoip_country_ex")) {
if (equal(szName, "has_reunion") || equal(szName, "REU_GetAuthtype"))
g_bHasReunion = false;
if (equal(szName, "geoip_code2_ex") || equal(szName, "geoip_country_ex"))
g_bHasGeoIP = false;
return PLUGIN_HANDLED;
}
return PLUGIN_CONTINUE;
}

public plugin_precache() {
precache_sound("buttons/blip1.wav");
}

public plugin_init() {
register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
g_pEnabled = register_cvar("hns_connect_info", "1");
g_pSound = register_cvar("hns_connect_sound", "1");
g_bHasReunion = has_reunion();
}

public client_connect(id) {
ClearPlayer(id);
g_bNeedAnnounce[id] = true;
}

public client_putinserver(id) {
if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
return;
if (g_bAnnounced[id])
return;

// ReHLDS/本地服经常不走 client_connect, 真正进服后补触发
g_bNeedAnnounce[id] = true;
g_flJoinTime[id] = get_gametime();
remove_task(id + TASK_ANNOUNCE);
set_task(ANNOUNCE_DELAY, "TaskAnnounce", id + TASK_ANNOUNCE);
}

public client_disconnected(id) {
remove_task(id + TASK_ANNOUNCE);
ClearPlayer(id);
}

ClearPlayer(id) {
g_bNeedAnnounce[id] = false;
g_bAnnounced[id] = false;
g_flJoinTime[id] = 0.0;
g_ePlayerPtsData[id][e_bInit] = false;
g_ePlayerPtsData[id][e_iPts] = 0;
g_ePlayerPtsData[id][e_iWins] = 0;
g_ePlayerPtsData[id][e_iLoss] = 0;
g_ePlayerPtsData[id][e_iTop] = 0;
g_ePlayerPtsData[id][e_szRank][0] = EOS;
}

public TaskAnnounce(taskid) {
new id = taskid - TASK_ANNOUNCE;
if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
return;
if (!g_bNeedAnnounce[id] || g_bAnnounced[id])
return;
if (!get_pcvar_num(g_pEnabled))
return;

new bool:bPtsReady = g_ePlayerPtsData[id][e_bInit];
new bool:bAuthReady = !IsAuthPending(id);
new Float:flWaited = get_gametime() - g_flJoinTime[id];
if ((!bPtsReady || !bAuthReady) && flWaited < ANNOUNCE_MAX) {
set_task(ANNOUNCE_RETRY, "TaskAnnounce", id + TASK_ANNOUNCE);
return;
}

AnnounceJoin(id);
}

AnnounceJoin(id) {
if (!is_user_connected(id) || g_bAnnounced[id])
return;

g_bAnnounced[id] = true;
g_bNeedAnnounce[id] = false;

new szName[NAME_MAX];
get_user_name(id, szName, charsmax(szName));

new iPts = g_ePlayerPtsData[id][e_iPts];
if (!g_ePlayerPtsData[id][e_bInit] && iPts <= 0)
iPts = 1000;

new szRank[10];
copy(szRank, charsmax(szRank), g_ePlayerPtsData[id][e_szRank]);
if (!szRank[0])
copy(szRank, charsmax(szRank), get_skill_player(iPts));

new iWins = g_ePlayerPtsData[id][e_iWins];
new iLoss = g_ePlayerPtsData[id][e_iLoss];
new iTop = g_ePlayerPtsData[id][e_iTop];
new iGold = hns_gc_available() ? hns_gc_get_player(id) : 0;

new szAuth[AUTH_MAX];
GetPlayerAuth(id, szAuth, charsmax(szAuth));

new szIP[IP_MAX];
GetPlayerIP(id, szIP, charsmax(szIP));

new iPing, iLossNet;
get_user_ping(id, iPing, iLossNet);

new iGames = iWins + iLoss;
new szRate[8];
if (iGames <= 0)
copy(szRate, charsmax(szRate), "--");
else
formatex(szRate, charsmax(szRate), "%d%%", floatround((float(iWins) * 100.0) / float(iGames)));

new szTop[12];
if (iTop > 0)
formatex(szTop, charsmax(szTop), "#%d", iTop);
else
copy(szTop, charsmax(szTop), "--");

new iPlayers[MAX_PLAYERS], iNum;
get_players(iPlayers, iNum, "ch");
for (new i = 0; i < iNum; i++) {
new viewer = iPlayers[i];
if (!is_user_connected(viewer) || is_user_bot(viewer) || is_user_hltv(viewer))
continue;

new szRole[24], szShowName[NAME_MAX], szAccount[16], szAccountTag[24], szCountry[COUNTRY_MAX];
GetJoinIdentity(id, viewer, szName, szRole, charsmax(szRole), szShowName, charsmax(szShowName));
GetAccountType(id, viewer, szAccount, charsmax(szAccount));
if (IsSteamAccount(id))
formatex(szAccountTag, charsmax(szAccountTag), "^4%s", szAccount);
else
formatex(szAccountTag, charsmax(szAccountTag), "^3%s", szAccount);
GetPlayerCountry(id, viewer, szIP, szCountry, charsmax(szCountry));

new szLine1[MSG_MAX], szLine2[MSG_MAX], szLine3[MSG_MAX];
if (szCountry[0])
LangFormat(viewer, "CONNECT_JOIN", "^4[HNS] ^4%s ^3%s^1 已连接 ^1(^4%s^1) ^1[%s^1]",
szLine1, charsmax(szLine1), szRole, szShowName, szCountry, szAccountTag);
else
LangFormat(viewer, "CONNECT_JOIN_NOLOC", "^4[HNS] ^4%s ^3%s^1 已连接 ^1[%s^1]",
szLine1, charsmax(szLine1), szRole, szShowName, szAccountTag);
LangFormat(viewer, "CONNECT_INFO", "^4[HNS]^1 PTS: ^4%d^1 (^3%s^1)  胜/负: ^4%d^1/^3%d^1  胜率: ^4%s^1  GBIC: ^4%d",
szLine2, charsmax(szLine2), iPts, szRank, iWins, iLoss, szRate, iGold);
LangFormat(viewer, "CONNECT_DETAIL", "^4[HNS]^1 SteamID: ^3%s^1  排名: ^4%s^1  延迟: ^4%dms^1  在线: ^4%d",
szLine3, charsmax(szLine3), szAuth, szTop, iPing, iNum);

client_print_color(viewer, print_team_default, "%s", szLine1);
client_print_color(viewer, print_team_default, "%s", szLine2);
client_print_color(viewer, print_team_default, "%s", szLine3);
}

if (get_pcvar_num(g_pSound))
client_cmd(0, "spk buttons/blip1");
}

GetJoinIdentity(id, viewer, const szName[], szRole[], iRoleLen, szShowName[], iNameLen) {
copy(szShowName, iNameLen, szName);

new iFlags = get_user_flags(id);
if (iFlags & ADMIN_IMMUNITY) {
LangGet(viewer, "CONNECT_ROLE_OWNER", szRole, iRoleLen, "房主");
LangGet(viewer, "CONNECT_OWNER_NAME", szShowName, iNameLen, "LINNA");
return;
}
if (iFlags & ADMIN_RESERVATION) {
LangGet(viewer, "CONNECT_ROLE_ADMIN", szRole, iRoleLen, "管理员");
return;
}
if (iFlags & ADMIN_BAN) {
LangGet(viewer, "CONNECT_ROLE_VIP", szRole, iRoleLen, "VIP");
return;
}
if (iFlags & (ADMIN_KICK | ADMIN_SLAY | ADMIN_MAP | ADMIN_CVAR | ADMIN_CFG | ADMIN_RCON | ADMIN_MENU)) {
LangGet(viewer, "CONNECT_ROLE_ADMIN", szRole, iRoleLen, "管理员");
return;
}

LangGet(viewer, "CONNECT_ROLE_PLAYER", szRole, iRoleLen, "玩家");
}

GetAccountType(id, viewer, szOut[], iLen) {
if (IsSteamAccount(id))
LangGet(viewer, "CONNECT_STEAM", szOut, iLen, "正版");
else
LangGet(viewer, "CONNECT_PIRATE", szOut, iLen, "盗版");
}

bool:IsSteamAccount(id) {
if (g_bHasReunion) {
return (REU_GetAuthtype(id) == CA_TYPE_STEAM);
}

new szAuth[AUTH_MAX];
get_user_authid(id, szAuth, charsmax(szAuth));
if (!szAuth[0] || containi(szAuth, "PENDING") != -1)
return false;
if (containi(szAuth, "STEAM_ID") != -1)
return false;
if (containi(szAuth, "VALVE") != -1)
return false;
if (equali(szAuth, "STEAM_0:0:0") || equali(szAuth, "STEAM_1:0:0"))
return false;
if (equali(szAuth, "BOT"))
return false;
return true;
}

GetPlayerAuth(id, szOut[], iLen) {
get_user_authid(id, szOut, iLen);
if (!szOut[0] || containi(szOut, "PENDING") != -1)
copy(szOut, iLen, "STEAM_ID_PENDING");
}

GetPlayerIP(id, szOut[], iLen) {
get_user_ip(id, szOut, iLen, 1);
if (!szOut[0])
copy(szOut, iLen, "0.0.0.0");
}

GetPlayerCountry(id, viewer, const szIP[], szOut[], iLen) {
#pragma unused id
szOut[0] = EOS;

if (IsLocalIP(szIP))
return;

new szCode[3];
szCode[0] = EOS;
if (g_bHasGeoIP)
geoip_code2_ex(szIP, szCode);

if (szCode[0] && TranslateCountry(viewer, szCode, szOut, iLen))
return;

if (g_bHasGeoIP) {
new szRaw[COUNTRY_MAX];
if (geoip_country_ex(szIP, szRaw, charsmax(szRaw), viewer) && szRaw[0]
&& !equali(szRaw, "error") && !equali(szRaw, "unknown")) {
copy(szOut, iLen, szRaw);
return;
}
}

LangGet(viewer, "CONNECT_UNKNOWN", szOut, iLen, "未知地区");
}

bool:TranslateCountry(viewer, const szCode[], szOut[], iLen) {
new iLang = HnsLang_GetPlayer(viewer);
if (iLang < 0 || iLang > 3)
iLang = 0;

for (new i = 0; i < sizeof(g_szCountry); i++) {
if (!equali(szCode, g_szCountry[i][COUNTRY_CODE]))
continue;
switch (iLang) {
case 1: copy(szOut, iLen, g_szCountry[i][COUNTRY_TW]);
case 2: copy(szOut, iLen, g_szCountry[i][COUNTRY_EN]);
case 3: copy(szOut, iLen, g_szCountry[i][COUNTRY_RU]);
default: copy(szOut, iLen, g_szCountry[i][COUNTRY_CN]);
}
return true;
}
return false;
}

bool:IsLocalIP(const szIP[]) {
if (!szIP[0] || equal(szIP, "loopback") || equal(szIP, "localhost"))
return true;
if (equal(szIP, "127.0.0.1") || equal(szIP, "0.0.0.0") || equal(szIP, "::1"))
return true;
if (equal(szIP, "10.", 3) || equal(szIP, "192.168.", 8) || equal(szIP, "169.254.", 8))
return true;
if (equal(szIP, "172.")) {
new iOctet = str_to_num(szIP[4]);
if (iOctet >= 16 && iOctet <= 31)
return true;
}
return false;
}

bool:IsAuthPending(id) {
new szAuth[AUTH_MAX];
get_user_authid(id, szAuth, charsmax(szAuth));
return (!szAuth[0] || containi(szAuth, "PENDING") != -1);
}

LangUnescape(szText[], iLen) {
replace_all(szText, iLen, "^^n", "^n");
replace_all(szText, iLen, "^^1", "^1");
replace_all(szText, iLen, "^^2", "^2");
replace_all(szText, iLen, "^^3", "^3");
replace_all(szText, iLen, "^^4", "^4");
}

LangGet(id, const szKey[], szOut[], iLen, const szFallback[]) {
szOut[0] = EOS;
HnsLang_Get(id, szKey, szOut, iLen);
if (!szOut[0] || equal(szOut, szKey))
copy(szOut, iLen, szFallback);
LangUnescape(szOut, iLen);
}

LangFormat(id, const szKey[], const szFallback[], szOut[], iLen, any:...) {
new szFmt[MSG_MAX];
LangGet(id, szKey, szFmt, charsmax(szFmt), szFallback);
vformat(szOut, iLen, szFmt, 6);
}

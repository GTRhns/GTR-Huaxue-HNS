#include <amxmodx>
#include <amxmisc>

#define HNS_LANG_MAX 4
#define HNS_LANG_ID_ZH      0
#define HNS_LANG_ID_ZH_TW   1
#define HNS_LANG_ID_EN      2
#define HNS_LANG_ID_RU      3
#define HNS_LANG_NAME_LEN   16
#define HNS_LANG_KEY_LEN    64
#define HNS_LANG_VALUE_LEN  512

new g_iPlayerLang[MAX_PLAYERS + 1];
new bool:g_bLangManual[MAX_PLAYERS + 1];   // ★ 玩家手动选择语言后, 不再被 cl_language 覆盖
new Trie:g_hLang[HNS_LANG_MAX];
new g_iKeyCount;
new g_szLangFile[256];

public plugin_init()
{
    register_plugin("HNS Language Core", "1.2.0", "HNSIC");
    register_clcmd("say /lang", "CmdLanguageMenu");
    register_clcmd("say_team /lang", "CmdLanguageMenu");
    register_clcmd("say /language", "CmdLanguageMenu");
    register_clcmd("say_team /language", "CmdLanguageMenu");
    get_configsdir(g_szLangFile, charsmax(g_szLangFile));
    add(g_szLangFile, charsmax(g_szLangFile), "/hns_language.txt");
    for (new i = 0; i < HNS_LANG_MAX; i++)
        g_hLang[i] = TrieCreate();

    LoadLanguageFile();
}

public plugin_end()
{
    for (new i = 0; i < HNS_LANG_MAX; i++)
    {
        if (g_hLang[i])
            TrieDestroy(g_hLang[i]);
    }
}

public client_putinserver(id)
{
    g_iPlayerLang[id] = HNS_LANG_ID_ZH;
    g_bLangManual[id] = false;
    set_task(0.5, "TaskDetectLanguage", id);
}

public client_infochanged(id)
{
    if (is_user_connected(id))
        TaskDetectLanguage(id);
}

public TaskDetectLanguage(id)
{
    if (!is_user_connected(id) || is_user_bot(id))
        return;

    if (g_bLangManual[id])
        return;

    new lang[16];
    get_user_info(id, "lang", lang, charsmax(lang));
    strtolower(lang);

    // ★ AMXX 原生 %L 直接用客户端 lang 去对应 lang 文件段名:
    //    cn=简体, tw=繁体, en=英文, ru=俄语
    if (equal(lang, "cn") || equal(lang, "zh") || containi(lang, "schinese") != -1)
        g_iPlayerLang[id] = HNS_LANG_ID_ZH;       // 简体中文
    else if (equal(lang, "tw") || equal(lang, "zh_tw") || containi(lang, "tchinese") != -1)
        g_iPlayerLang[id] = HNS_LANG_ID_ZH_TW;    // 繁体中文
    else if (equal(lang, "en"))
        g_iPlayerLang[id] = HNS_LANG_ID_EN;       // 英文
    else if (equal(lang, "ru"))
        g_iPlayerLang[id] = HNS_LANG_ID_RU;       // 俄语
    else
        g_iPlayerLang[id] = HNS_LANG_ID_ZH;       // 默认简体中文
}

public client_disconnected(id)
{
    g_iPlayerLang[id] = HNS_LANG_ID_ZH;
    g_bLangManual[id] = false;
}

public CmdLanguageMenu(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    new title[128], item[64], info[8];
    GetTranslation(id, "LANG_MENU_TITLE", title, charsmax(title));
    new menu = menu_create(title, "LanguageMenuHandler");

    GetTranslation(id, "LANG_ZH", item, charsmax(item));
    num_to_str(HNS_LANG_ID_ZH, info, charsmax(info));
    menu_additem(menu, item, info);

    GetTranslation(id, "LANG_ZH_TW", item, charsmax(item));
    num_to_str(HNS_LANG_ID_ZH_TW, info, charsmax(info));
    menu_additem(menu, item, info);

    GetTranslation(id, "LANG_EN", item, charsmax(item));
    num_to_str(HNS_LANG_ID_EN, info, charsmax(info));
    menu_additem(menu, item, info);

    GetTranslation(id, "LANG_RU", item, charsmax(item));
    num_to_str(HNS_LANG_ID_RU, info, charsmax(info));
    menu_additem(menu, item, info);

    GetTranslation(id, "MENU_EXIT", item, charsmax(item));
    menu_setprop(menu, MPROP_EXITNAME, item);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public LanguageMenuHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);
    menu_destroy(menu);

    new lang = str_to_num(info);
    if (lang < 0 || lang >= HNS_LANG_MAX)
        return PLUGIN_HANDLED;

    g_iPlayerLang[id] = lang;
    g_bLangManual[id] = true;

    // ★ 关键: 同时把语言同步给 AMXX 原生多语言系统 (cl_language)。
    //   主插件 HnsMatchSystem 的 mix 菜单/HUD 走的是原生 %L + mixsystem.txt,
    //   它只看客户端 "lang" 信息, 与 /lang 插件无关。
    //   这里主动改 cl_language, 让主插件菜单也跟随 /lang 的选择。
    SetClientLanguage(id, lang);

    new msg[192];
    GetTranslation(id, "LANG_CHANGED", msg, charsmax(msg));
    client_print_color(id, print_team_default, "^4[HNS]^1 %s", msg);
    return PLUGIN_HANDLED;
}

// 把插件内部语言 ID 同步为客户端 cl_language (供 AMXX 原生多语言系统使用)
stock SetClientLanguage(id, lang)
{
    if (!is_user_connected(id))
        return;

    // ★ 语言代码与 lang 文件段名对齐: cn(简体), tw(繁体), en(英语), ru(俄语)
    new const szCodes[HNS_LANG_MAX][] = { "cn", "tw", "en", "ru" };
    if (lang < 0 || lang >= HNS_LANG_MAX)
        return;

    // setinfo 会持久化到客户端 config; set_user_info 作为即时兜底
    client_cmd(id, "setinfo ^"lang^" ^"%s^"", szCodes[lang]);
    set_user_info(id, "lang", szCodes[lang]);
    client_cmd(id, "cl_language ^"%s^"", szCodes[lang]);
}

stock GetTranslation(id, const key[], out[], len)
{
    if (!FindTranslation(id, key, out, len))
        formatex(out, len, "%s", key);
}

public plugin_natives()
{
    register_native("HnsLang_Get", "NativeLangGet");
    register_native("HnsLang_Set", "NativeLangSet");
    register_native("HnsLang_GetPlayer", "NativeLangGetPlayer");
    register_native("HnsLang_Reset", "NativeLangReset");
}

public NativeLangGet(plugin, params)
{
    new id = get_param(1);
    new szKey[HNS_LANG_KEY_LEN];
    new szOut[HNS_LANG_VALUE_LEN];
    new iLen = get_param(4);

    get_string(2, szKey, charsmax(szKey));
    if (!FindTranslation(id, szKey, szOut, charsmax(szOut)))
        szOut[0] = 0;

    set_string(3, szOut, iLen);
    return szOut[0] != 0;
}

public NativeLangSet(plugin, params)
{
    new id = get_param(1);
    new lang = get_param(2);

    if (id < 1 || id > MaxClients || lang < 0 || lang >= HNS_LANG_MAX)
        return 0;

    g_iPlayerLang[id] = lang;
    g_bLangManual[id] = true;
    SetClientLanguage(id, lang);
    return 1;
}

public NativeLangGetPlayer(plugin, params)
{
    new id = get_param(1);
    if (id < 1 || id > MaxClients)
        return HNS_LANG_ID_ZH;
    return g_iPlayerLang[id];
}

public NativeLangReset(plugin, params)
{
    new id = get_param(1);
    if (id < 1 || id > MaxClients)
        return 0;
    g_iPlayerLang[id] = HNS_LANG_ID_ZH;
    g_bLangManual[id] = false;
    SetClientLanguage(id, HNS_LANG_ID_ZH);
    return 1;
}

stock bool:FindTranslation(id, const szKey[], szOut[], iLen)
{
    new lang = HNS_LANG_ID_ZH;
    if (id >= 1 && id <= MaxClients)
        lang = g_iPlayerLang[id];

    if (TrieGetString(g_hLang[lang], szKey, szOut, iLen))
        return true;

    if (lang != HNS_LANG_ID_ZH && TrieGetString(g_hLang[HNS_LANG_ID_ZH], szKey, szOut, iLen))
        return true;

    return false;
}

stock LoadLanguageFile()
{
    new fp = fopen(g_szLangFile, "rt");
    if (!fp)
    {
        log_amx("[HnsLanguage] Cannot open %s", g_szLangFile);
        return;
    }

    new line[HNS_LANG_VALUE_LEN + HNS_LANG_KEY_LEN + 32];
    new section[HNS_LANG_NAME_LEN];
    new key[HNS_LANG_KEY_LEN];
    new value[HNS_LANG_VALUE_LEN];
    new lang = HNS_LANG_ID_ZH;

    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);

        if (!line[0] || line[0] == ';' || line[0] == '#')
            continue;

        if (line[0] == '[')
        {
            section[0] = 0;
            if (strlen(line) > 2)
            {
                copyc(section, charsmax(section), line[1], ']');
                trim(section);
            }
            lang = LanguageId(section);
            continue;
        }

        new eq = contain(line, "=");
        if (eq <= 0)
            continue;

        copy(key, charsmax(key), line);
        key[eq] = 0;
        trim(key);

        copy(value, charsmax(value), line[eq + 1]);
        trim(value);

        new bool:alreadyExists;
        for (new i = 0; i < HNS_LANG_MAX; i++)
        {
            if (TrieKeyExists(g_hLang[i], key))
            {
                alreadyExists = true;
                break;
            }
        }
        if (!alreadyExists)
            g_iKeyCount++;

        TrieSetString(g_hLang[lang], key, value);
    }

    fclose(fp);
    log_amx("[HnsLanguage] Loaded %d keys from %s", g_iKeyCount, g_szLangFile);
}

stock LanguageId(const section[])
{
    if (equali(section, "cn") || equali(section, "zh")) return HNS_LANG_ID_ZH;
    if (equali(section, "tw") || equali(section, "zh_tw")) return HNS_LANG_ID_ZH_TW;
    if (equali(section, "en")) return HNS_LANG_ID_EN;
    if (equali(section, "ru")) return HNS_LANG_ID_RU;
    return HNS_LANG_ID_ZH;
}


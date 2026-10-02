#if defined _hns_language_included
    #endinput
#endif
#define _hns_language_included

#define HNS_LANG_ZH      0
#define HNS_LANG_ZH_TW   1
#define HNS_LANG_EN      2
#define HNS_LANG_RU      3

/*
 * Get one translated string from configs/hns_language.txt.
 * Default language: Simplified Chinese.
 */
native HnsLang_Get(id, const szKey[], szOut[], iLen);

/* Set one player's language. */
native HnsLang_Set(id, iLanguage);

/* Get one player's current language id. */
native HnsLang_GetPlayer(id);

/* Reset one player's language to Simplified Chinese. */
native HnsLang_Reset(id);

stock HnsLang_Format(id, const szKey[], szOut[], iLen)
{
    return HnsLang_Get(id, szKey, szOut, iLen);
}

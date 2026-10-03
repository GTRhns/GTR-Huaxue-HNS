# 🎮 GTR HNS Match Plugin System · Huaxue Edition

<p align="center">
  <img src="assets/banner.jpg" alt="华雪版封面" width="480">
</p>

<div align="center">

[![AMX Mod X](https://img.shields.io/badge/AMX_Mod_X-1.10-blue)]()
[![ReGameDLL](https://img.shields.io/badge/ReGameDLL-5.x-orange)]()
[![Version](https://img.shields.io/badge/Version-v1.19-green)]()
[![Storage](https://img.shields.io/badge/Storage-PDS_%2B_MySQL-9cf)]()
[![Language](https://img.shields.io/badge/Language-4_Languages-ff69b4)]()
[![License](https://img.shields.io/badge/License-GPLv3-success)]()

</div>

**🌐 Language / 语言:** [简体中文](README.md) · [繁體中文](README_ZH-TW.md) · [English](README_EN.md) · [Deutsch](README_DE.md) · [Русский](README_RU.md) · [Italiano](README_IT.md) · [Türkçe](README_TR.md) · [Français](README_FR.md)

> **Built on the OpenHNS match engine and extended with extensive self-developed features by the GTR team**
> Requires: CS 1.6 / ReHLDS / AMX Mod X 1.10
> Current version: **Huaxue Edition v1.19** (tag: `huaxue-v1.19`) · 2026-10-01 release

---

## 📌 Table of Contents

- [1. Project Introduction](#1-project-introduction)
- [2. New vs Old: What's Different](#2-new-vs-old-whats-different)
- [3. Huaxue Edition v1.19 Highlights](#3-huaxue-edition-v118-highlights)
- [4. Plugin List](#4-plugin-list)
- [5. Repository Structure](#5-repository-structure)
- [6. Quick Deployment](#6-quick-deployment)
- [7. Tech Stack](#7-tech-stack)
- [8. Copyright Notice](#8-copyright-notice)
- [9. Multi-language Versions](#9-multi-language-versions)

---

## 1. Project Introduction

This is a complete CS 1.6 HNS (Hide 'n' Seek) match server plugin system.

The foundation comes from the open-source project **OpenHNS** (HnsMatchSystem 2.0.5 and its official plugin set).
Building on it, the GTR team has injected a large amount of self-developed code around the full flow of "**signup → team grouping → match type/map selection → match start → settlement**",
forming an independent **GTR self-developed match engine**.

---

## 2. New vs Old: What's Different

### 2.1 Problems in the Old Version (Root Causes Fixed in This Repository)

| # | Old Version Problem | What Users Actually Encountered |
|---|---|---|
| 1 | AI menu hardcoded in Chinese | After switching `/lang` to English, the AI signup menu is still in Chinese |
| 2 | Flawed force-start flow | After force-start sends everyone to spectator, it "disappears" without selecting a map/mode |
| 3 | Uses the `jointeam` command for player entry | Intercepted by `blockCmd`, players get stuck in spectator in LOBBY mode |
| 4 | No participant marking before match start | `forceUnmatchedToSpec` in `mix_start()` kicks everyone who just entered back to spectator |
| 5 | All state lost on map change | After AI picks a map and changelevel, signup/match type are all lost; the match can never start |
| 6 | Normal map changes also auto-start a match | When an admin changes the map, the server starts signup on its own and auto-forms teams 2 minutes later |
| 7 | No sponsor entry for sponsored matches | A sponsored match is started but nobody can tell the system "who is the sponsor" |
| 8 | Mix menu item 7 misbehaves | HNS mode at item 7 "can't be clicked"; the language string lacks `^n`, so it looks like a dead item |
| 9 | Signup count number bar | Chat/HUD shows `012345[6]78910`; users asked to remove it |
| 10 | Signup menu closes on a single click | Users want to keep operating the menu, but it auto-closes |

### 2.2 Corresponding Improvements in the New Version (Huaxue Edition v1.19)

| # | Improvement | Implementation |
|---|---|---|
| 1 | **Fully localized AI menu** | All lookups go through `HnsLang_Get(id, key)`, supporting four languages (Simplified Chinese / Traditional Chinese / English / Russian), synced in real time with `/lang` |
| 2 | **Signup flow refactored** | `SIGNUP_STATE` state machine: signup → team gathering (everyone to spectator + one player enters every second) → match type/map selection → match start |
| 3 | **Safe player entry via ReAPI** | Switched to `rg_set_user_team` (ReAPI) instead of `jointeam`; allowed in LOBBY/TRAINING, eliminating players being stuck in spectator |
| 4 | **Pre-marking for external match start** | New native `hns_begin_external_match` marks T/CT as participants before the match starts, fixing the second root cause of "everyone returning to spectator the moment the match starts" |
| 5 | **Cross-map PDS recovery** | After map selection, `PDS_SetCell("ai_pending_start",1)`; the match resumes automatically 5 seconds after the map change (`taskPendingResume`) |
| 6 | **Normal map changes no longer auto-start** | Non-pending map change: signup cleared, enters standby, started manually by an admin |
| 7 | **Sponsored match sponsor entry** | After map selection, the first online VIP/admin types the sponsor's name in chat; skipped after a 30-second timeout or with `/cancel` |
| 8 | **Fixed mix menu numbering** | Item 7 is always ICGB (grayed out and unclickable in non-sponsored matches), item 8 is always the admin menu |
| 9 | **Number bar UI removed** | `buildSignupBar()` deleted; HUD only shows `Signup: n/12` |
| 10 | **Menu stays open after selection** | The signup menu returns to the main menu after an action, making consecutive operations convenient |
| 11 | **Win/loss determined by logical team** | New native `hns_get_player_match_team`; wintime settlement credits the correct team (v1.19) |
| 12 | **Tightened menu permissions** | Team size / re-group / force start visible and clickable only for VIP/admin (v1.19) |
| 13 | **Single match-type state** | AI and MatchSystem share one match type, restored together after a map change; no more divergence (v1.19) |

### 2.3 Version Evolution Timeline (HnsAISignup Main Plugin)

| Version | Time | Status | Description |
|---|---|---|---|
| v1.3 | 09-27 19:12 | Historical backup | Version before the team fix (teamfix) |
| v1.5 | 09-27 19:55 | Historical backup | Admin fix (adminfix) version |
| v1.5 | 09-27 20:00 | Historical backup | Backup before the second fix |
| v1.9 | 09-27 22:07 | Historical backup | Before large-scale changes (before the signup flow refactor) |
| **v1.17** | 09-30 23:00 | **Previous release** | Huaxue Edition release, all improvements in place |
| v1.17+ | 10-01 02:13 | In development | Adds `taskRestorePendingRules` (delayed mode recovery after map change), not deployed |
| **v1.19** | 10-01 | **Currently deployed version** | wintime win/loss fix + match type restored after map change + tightened menu permissions + single match-type state |

> For the full version history, see `02_各插件历史版本/`; each version has its own folder + description.

---

## 3. Huaxue Edition v1.19 Highlights

- 🤖 **AI Signup System v1.19**: `/signup` one-click signup, team gathering and grouping, casual/sponsored matches, mode and map voting, force start (testable with 1 player), cross-map match resumption, HUD signup counter.
- 🎨 **Skin System (MySQL)**: player-customized skins, coin purchase / rental / permanent upgrades, random death sounds, admin management via the `/cpm` menu.
- 💳 **Sponsorship / ICGB Coin System**: sponsored matches auto-record the sponsor; coins are linked to skins.
- 🗂 **Cross-map Persistence (PDS)**: map changes don't lose match state; the match auto-resumes after AI map selection.
- 🌐 **Four-language Localization**: Simplified / Traditional / English / Русский, unified across the AI and match menus.
- 🧠 **AI Match Solo Test**: with no players, the match can start with 1 player for testing; no getting stuck in spectator.
- 🛡 **Stable Load Order**: `plugins.ini` arranges HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin.
- 🎯 **Win/loss determination fix**: wintime settlement adds points by logical match team; no wrong players credited after side swap or map change.
- 🔐 **Tightened permissions**: admin operations (team size / re-group / force start) visible and clickable only for VIP/admin.

---

## 4. Plugin List

| Plugin | Version | Function |
|---|---|---|
| HnsAISignup | v1.19 | AI signup system (core, self-developed) |
| HnsMatchSystem | 2.0.5+ | Match state machine (OpenHNS base + 2 new natives: `hns_get_player_match_team` / `hns_get_match_team_cs`) |
| HnsMatchBans | 1.1 | Ban management |
| HnsMatchMaps | 4.0.4 | Map management |
| HnsMatchStats | 1.1.1 | Statistics |
| HnsMatchPts | 1.1 | Points |
| HnsMatchQuery | 1.0.0 | Match query `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | Admin settings `/adminmenu` |
| HnsMatchSkin | 1.0 | Skin system (MySQL) |
| HnsMatchSql | 1.1 | Unified MySQL management |
| HnsLanguage | 1.3.0 | Four-language core |
| HnsPersistentDataStorage | 1.0 | Cross-map persistence |
| HnsSponsorLocal | 1.0 | Sponsorship / ICGB coins |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | Match utilities |

---

## 5. Repository Structure

```
01_当前版本_核心源码/       Core plugin source of the currently deployed version + include + compiled
02_各插件历史版本/          Each multi-version plugin in its own directory, labeled by version
03_开发工作区_scripting/   Local development workspace + AMXX compiler
04_服务器部署_cstrike/      Complete deployment directory structure (addons/amxmodx + third-party plugin categories)
05_皮肤系统_v1.0完整版/     Complete skin system MySQL installation package
06_Beta测试插件包/         5 standalone mini plugins
07_第三方插件包/           SEM / semiclip / rtv_rus (dream-x.ru)
08_资源文件_asd/           Skin models / sounds / texture assets
09_开发脚本与临时文件/     Intermediate AI programming artifacts (for troubleshooting reference only)
10_交接与文档/             Modification records, handover notes, changelog
```

---

## 6. Quick Deployment

1. Go to **Release** and download the latest **Huaxue Edition** deployment package `gtr_deploy_package_v1.19.zip`
2. Extract `addons/` over the server's `cstrike/` directory
3. Configure MySQL according to `部署说明.txt` (the skin database needs tables created on first use)
4. Restart the server / change the map, then verify there are no failed entries with `amxx plugins` in the console
5. After players join, the `/menu` main menu title shows **Hide'And'Seek**

> For detailed deployment instructions, see `10_交接与文档/` and the Release notes.

---

## 7. Tech Stack

| Component | Description |
|---|---|
| Engine | CS 1.6 / ReHLDS / ReGameDLL |
| Platform | AMX Mod X 1.10 (amxxpc 1.10.0.5479) |
| Base | OpenHNS Match System 2.0.5 |
| Database | MySQL (HnsMatchSql) + nvault (offline fallback) |
| Extensions | ReAPI, HamSandwich, MixSystem |
| Self-developed | AI signup / sponsorship / skin takeover / cross-map persistence / four languages |

---

## 8. Copyright Notice

- **OpenHNS-family plugins** (HnsMatchSystem / Bans / Maps / Stats, etc.): Copyright belongs to the original authors (OpenHNS / Garey / Cultura, etc.), MIT-style open-source license.
- **GTR self-developed extensions** (AI signup, sponsorship, skin takeover, cross-map storage, localization, etc.): Extended from the engines above.
- **Third-party plugin packages** (SEM / rtv / FreshBans, etc.): Copyright belongs to their respective authors, sourced from the Russian site dream-x.ru.
- **Skin assets** (models / sounds / textures): Copyright not specified; please confirm on your own before commercial use.
- Fork / PR / Issues are welcome; just credit the source.

---

## 9. Multi-language Versions

- [简体中文](README.md)
- [繁體中文](README_ZH-TW.md)
- [English](README_EN.md)
- [Deutsch](README_DE.md)
- [Русский](README_RU.md)
- [Italiano](README_IT.md)
- [Türkçe](README_TR.md)
- [Français](README_FR.md)

---

<div align="center">

![声明](https://img.shields.io/badge/declaration-%E4%B8%80%E5%88%87%E8%A7%A3%E9%87%8A%E6%9D%83%E5%BD%92%20LINNA%20%E6%89%80%E6%9C%89%EF%BC%8CGTRhns%20%E5%B0%86%E6%9C%8D%E5%8A%A1%E4%BA%8E%E6%AF%8F%E4%B8%80%E4%B8%AA%E4%BA%BA%E3%80%82-red)

<b>All rights of interpretation belong to LINNA. GTRhns will serve everyone.</b>

</div>

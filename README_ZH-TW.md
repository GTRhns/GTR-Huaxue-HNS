# 🎮 GTR HNS 比賽外掛系統 · 華雪版

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

> **基於 OpenHNS 比賽引擎二次開發，融合 GTR 團隊大量自研功能**
> 適用：CS 1.6 / ReHLDS / AMX Mod X 1.10
> 目前版本：**華雪版 v1.19**（tag: `huaxue-v1.19`）· 2026-10-01 版

---

## 📌 目錄

- [一、項目簡介](#一項目簡介)
- [二、新版 vs 舊版：有什麼不一樣](#二新版-vs-舊版有什麼不一樣)
- [三、華雪版 v1.19 亮點](#三華雪版-v118-亮點)
- [四、外掛清單](#四外掛清單)
- [五、倉庫結構](#五倉庫結構)
- [六、快速部署](#六快速部署)
- [七、技術棧](#七技術棧)
- [八、版權說明](#八版權說明)
- [九、多語言版本](#九多語言版本)

---

## 一、項目簡介

這是一套完整的 CS 1.6 HNS（Hide 'n' Seek，捉迷藏）比賽伺服器外掛系統。

底座來自開源專案 **OpenHNS**（HnsMatchSystem 2.0.5 及其官方外掛集），
GTR 團隊在其上圍繞「**報名 → 分組 → 選賽制/地圖 → 開賽 → 結算**」全流程，
注入了大量自研程式碼，形成獨立的 **GTR 自研比賽引擎**。

---

## 二、新版 vs 舊版：有什麼不一樣

### 2.1 舊版的問題（本倉庫修復的根源）

| # | 舊版問題 | 使用者實際遇到的現象 |
|---|---|---|
| 1 | AI 選單硬編碼中文 | `/lang` 改成英文後，AI 報名選單還是中文 |
| 2 | 強制開賽流程有缺陷 | 強制開賽把人拉去觀戰後就「消失」了，不選地圖/模式 |
| 3 | 上場用 `jointeam` 指令 | 被 `blockCmd` 攔截，人在 LOBBY 模式卡在觀戰 |
| 4 | 開賽前不標記參賽者 | `mix_start()` 裡的 `forceUnmatchedToSpec` 把剛上場的人全踢回觀戰 |
| 5 | 換圖狀態全丟 | AI 選好圖 changelevel 後，報名/賽制全部遺失，比賽永遠開不起來 |
| 6 | 普通換圖也自動開賽 | 管理員換張圖，伺服器自己就開始報名、2 分鐘後自動收團 |
| 7 | 贊助局無贊助者錄入 | 開了贊助局卻沒人能告訴系統「贊助者是誰」 |
| 8 | mix 選單第 7 項異常 | 第 7 項 HNS 模式「點不下去」，語言字串沒有 `^n`，視覺上像死選項 |
| 9 | 報名人數數字條 | 聊天框/HUD 顯示 `012345[6]78910`，使用者要求移除 |
| 10 | 報名選單點一下就關 | 想連續操作選單卻自動關閉 |

### 2.2 新版（華雪版 v1.19）的對應改進

| # | 改進 | 實作方式 |
|---|---|---|
| 1 | **AI 選單全語言化** | 全部走 `HnsLang_Get(id, key)`，支援簡中/繁中/英語/俄語四語，`/lang` 即時連動 |
| 2 | **報名流程重構** | `SIGNUP_STATE` 狀態機：報名 → 收團（全員觀戰+1秒1人上場）→ 選賽制/地圖 → 開賽 |
| 3 | **ReAPI 安全上場** | 改用 `rg_set_user_team`（ReAPI），不再走 `jointeam`，LOBBY/TRAINING 下放行，杜絕卡觀戰 |
| 4 | **外部開賽預標記** | 新 native `hns_begin_external_match` 開賽前先把 T/CT 標為參賽者，解決「開賽瞬間全員回觀戰」的第二層根因 |
| 5 | **跨圖 PDS 恢復** | 選圖後 `PDS_SetCell("ai_pending_start",1)`，換圖回來 5 秒自動續賽（`taskPendingResume`） |
| 6 | **普通換圖不再自動開賽** | 非 pending 換圖：報名清空、進入待命，由管理員手動開 |
| 7 | **贊助局錄入** | 選完地圖後第一個線上 VIP/管理員聊天輸入贊助者名，30 秒逾時或 `/取消` 跳過 |
| 8 | **mix 選單固定編號** | 第 7 項永遠 ICGB（非贊助局灰色不可點）、第 8 項永遠管理員選單 |
| 9 | **取消數字條 UI** | 刪除 `buildSignupBar()`，HUD 只顯示 `報名: n/12` |
| 10 | **選單點完不關** | 報名選單操作後返回主選單，方便連續操作 |
| 11 | **勝負判定按邏輯隊伍** | 新 native `hns_get_player_match_team`，wintime 結算加對分（v1.19） |
| 12 | **選單權限收斂** | 隊伍人數/重新分隊/強制開賽僅 VIP/管理員可見可點（v1.19） |
| 13 | **賽制狀態唯一** | AI 與 MatchSystem 共用一份賽制，換圖後連賽制一起恢復，杜絕分叉（v1.19） |

### 2.3 版本演進時間線（HnsAISignup 主外掛）

| 版本 | 時間 | 狀態 | 說明 |
|---|---|---|---|
| v1.3 | 09-27 19:12 | 歷史備份 | 隊伍修復（teamfix）前的版本 |
| v1.5 | 09-27 19:55 | 歷史備份 | 管理員修復（adminfix）版 |
| v1.5 | 09-27 20:00 | 歷史備份 | 第二次修復前的備份 |
| v1.9 | 09-27 22:07 | 歷史備份 | 大規模改動前（報名流程重構前） |
| **v1.17** | 09-30 23:00 | **上一發行版** | 華雪版正式版，全部改進落地 |
| v1.17+ | 10-01 02:13 | 開發中 | 新增 `taskRestorePendingRules`（換圖後延遲恢復模式），未部署 |
| **v1.19** | 10-01 | **目前部署版** | wintime 勝負判定修復 + 換圖恢復賽制 + 選單權限收斂 + 賽制狀態唯一 |

> 完整版本歷史見 `02_各插件历史版本/`，每個版本都有獨立資料夾 + 說明。

---

## 三、華雪版 v1.19 亮點

- 🤖 **AI 報名系統 v1.19**：`/signup` 一鍵報名、收團分組、娛樂局/贊助局、模式與地圖投票、強制開賽（1 人可測）、換圖跨圖續賽、HUD 報名計數。
- 🎨 **皮膚系統（MySQL）**：玩家自訂皮膚，金幣購買 / 租期 / 永久升級，死亡音效隨機，管理員 `/cpm` 選單管理。
- 💳 **贊助 / ICGB 金幣體系**：贊助局自動錄入贊助者，金幣與皮膚連動。
- 🗂 **跨圖持久化（PDS）**：換圖不丟比賽狀態，AI 選圖後自動恢復開賽。
- 🌐 **四語本地化**：簡體 / 繁體 / English / Русский，AI 選單與比賽選單統一。
- 🧠 **AI 比賽人機**：無人時可 1 人開賽測試，不卡觀戰。
- 🛡 **穩定載入順序**：`plugins.ini` 已排好 HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin。
- 🎯 **勝負判定修復**：wintime 結算按邏輯比賽隊伍加積分，換邊/換圖不再加錯人。
- 🔐 **權限收斂**：管理操作（隊伍人數/重新分隊/強制開賽）僅 VIP/管理員可見可點。

---

## 四、外掛清單

| 外掛 | 版本 | 功能 |
|---|---|---|
| HnsAISignup | v1.19 | AI 報名系統（核心自研） |
| HnsMatchSystem | 2.0.5+ | 比賽狀態機（OpenHNS 底座 + 2 個新 native：`hns_get_player_match_team` / `hns_get_match_team_cs`） |
| HnsMatchBans | 1.1 | 封禁管理 |
| HnsMatchMaps | 4.0.4 | 地圖管理 |
| HnsMatchStats | 1.1.1 | 資料統計 |
| HnsMatchPts | 1.1 | 積分 |
| HnsMatchQuery | 1.0.0 | 比賽查詢 `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | 管理員設定 `/adminmenu` |
| HnsMatchSkin | 1.0 | 皮膚系統（MySQL） |
| HnsMatchSql | 1.1 | MySQL 統一管理 |
| HnsLanguage | 1.3.0 | 四語語言核心 |
| HnsPersistentDataStorage | 1.0 | 跨圖持久化 |
| HnsSponsorLocal | 1.0 | 贊助 / ICGB 金幣 |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | 比賽輔助 |

---

## 五、倉庫結構

```
01_当前版本_核心源码/       目前部署版核心外掛原始碼 + include + compiled
02_各插件历史版本/          每個多版本外掛獨立分目錄、按版本標註
03_开发工作区_scripting/   本地開發工作區 + AMXX 編譯器
04_服务器部署_cstrike/      完整部署目錄結構（addons/amxmodx + 第三方外掛分類）
05_皮肤系统_v1.0完整版/     皮膚系統 MySQL 完整安裝包
06_Beta测试插件包/         5 個獨立小外掛
07_第三方插件包/           SEM / semiclip / rtv_rus（dream-x.ru）
08_资源文件_asd/           皮膚模型/音效/貼圖素材
10_交接与文档/             修改記錄、交接說明、更新日誌
```

---

## 六、快速部署

1. 前往 **Release** 下載最新 **華雪版** 的部署包 `gtr_deploy_package_v1.19.zip`
2. 解壓 `addons/` 覆蓋到伺服器 `cstrike/` 目錄
3. 依照 `部署说明.txt` 設定 MySQL（皮膚庫首次需建表）
4. 重新啟動伺服器 / 換圖，控制台 `amxx plugins` 驗證無 failed
5. 玩家進服後 `/menu` 主選單標題顯示 **Hide'And'Seek**

> 詳細部署見 `10_交接与文档/` 與 Release 說明。

---

## 七、技術棧

| 元件 | 說明 |
|---|---|
| 引擎 | CS 1.6 / ReHLDS / ReGameDLL |
| 平台 | AMX Mod X 1.10（amxxpc 1.10.0.5479） |
| 底座 | OpenHNS Match System 2.0.5 |
| 資料庫 | MySQL（HnsMatchSql）+ nvault（離線兜底） |
| 擴充 | ReAPI、HamSandwich、MixSystem |
| 自研 | AI 報名 / 贊助 / 皮膚接管 / 跨圖持久化 / 四語 |

---

## 八、版權說明

- **OpenHNS 系外掛**（HnsMatchSystem / Bans / Maps / Stats 等）：版權歸原作者（OpenHNS / Garey / Cultura 等），MIT 類開源授權。
- **GTR 自研擴充**（AI 報名、贊助、皮膚接管、跨圖儲存、語言化等）：基於上述引擎二次開發。
- **第三方外掛包**（SEM / rtv / FreshBans 等）：版權歸各自作者，來源俄站 dream-x.ru。
- **皮膚素材**（models / sounds / 貼圖）：版權未註明，商用前請自行確認。
- 歡迎 Fork / PR / 提 Issue，標註來源即可。

---

## 九、多語言版本

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

<b>一切解釋權歸 LINNA 所有，GTRhns 將服務於每一個人。</b>

</div>

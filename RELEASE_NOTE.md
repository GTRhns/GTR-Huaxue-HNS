# 🎮 华雪版 · 第 1 版发行（v1.17）

**GTR HNS 比赛插件系统 —— 完整源码 + 部署包**

> **基于 OpenHNS 比赛引擎二次开发，GTR 团队注入大量自研功能**
> 适用：CS 1.6 / ReHLDS / AMX Mod X 1.10
> 项目代号：「华雪」（Huaxue）
> Tag：`huaxue-v1.17`

---

## 📦 本 Release 内容

| # | 附件 | 说明 |
|---|---|---|
| 1 | `gtr_deploy_package_v1.17.zip` | **服务器一键部署包**（`addons/amxmodx` 结构，解压覆盖即用，含编译好的 `.amxx`） |
| 2 | `gtr_source_full_v1.17.zip` | **完整源码包**（当前版本核心源码 + 各插件历史版本 + 开发工作区 + 全套文档） |

> 源码也同步在仓库 `main` 分支，按目录整理并标注了每个插件的历史版本。

---

## 🆕 新版 vs 旧版：改了什么、为什么改

本仓库的「旧版」指 **OpenHNS 原生引擎 / 早期 GTR 版本**，「新版」指 **华雪版 v1.17**。

### 旧版存在的问题（本次全部修复）

| # | 旧版问题 | 实际现象 |
|---|---|---|
| 1 | AI 菜单硬编码中文 | `/lang` 改成英文后，AI 报名菜单仍是中文 |
| 2 | 强制开赛流程有缺陷 | 强制开赛把人拉去观战后就"消失"，不选地图 / 模式 |
| 3 | 上场走 `jointeam` 命令 | 被 `blockCmd` 拦截，LOBBY 模式下卡在观战上不了场 |
| 4 | 开赛前不标记参赛者 | 开赛瞬间 `forceUnmatchedToSpec` 把刚上场的人全踢回观战 |
| 5 | 换图后状态全丢 | AI 选好图 changelevel 后，报名 / 赛制全部丢失，比赛永远开不起来 |
| 6 | 普通换图也自动开赛 | 管理员随便换张图，服务器自动开始报名、2 分钟后自动收团 |
| 7 | 赞助局无赞助者录入 | 开了赞助局却没人能告诉系统"赞助者是谁" |
| 8 | mix 菜单第 7 项点不下去 | HNS 模式项语言串缺 `^n`，视觉上像死项 |
| 9 | 报名人数数字条 | 聊天框 / HUD 显示 `012345[6]78910`，观感杂乱 |
| 10 | 报名菜单点一下自动关 | 无法连续操作菜单 |

### 新版（华雪版 v1.17）的对应改进

| # | 改进 | 实现方式 |
|---|---|---|
| 1 | **AI 菜单全语言化** | 全部走 `HnsLang_Get(id, key)`，简中 / 繁中 / 英语 / 俄语四语，`/lang` 实时联动 |
| 2 | **报名流程重构** | `SIGNUP_STATE` 状态机：报名 → 收团（全员观战 + 1 秒 1 人上场）→ 选赛制 / 地图 → 开赛 |
| 3 | **ReAPI 安全上场** | 改用 `rg_set_user_team`，不再走 `jointeam`，LOBBY / TRAINING 下放行，杜绝卡观战 |
| 4 | **外部开赛预标记** | 新 native `hns_begin_external_match` 开赛前先标记 T/CT 为参赛者，根治"开赛瞬间全员回观战" |
| 5 | **跨图 PDS 恢复** | 选图后 `PDS_SetCell("ai_pending_start",1)`，换图回来 5 秒自动续赛 |
| 6 | **普通换图不再自动开赛** | 非 pending 换图：报名清空、进入待命，由管理员手动开 |
| 7 | **赞助局赞助者录入** | 选完地图后第一位在线 VIP/管理员聊天输入赞助者名，30 秒超时或 `/取消` 跳过 |
| 8 | **mix 菜单固定编号** | 第 7 项永远 ICGB、第 8 项永远管理员菜单 |
| 9 | **取消数字条 UI** | 删除 `buildSignupBar()`，HUD 只显示 `报名: n/12` |
| 10 | **菜单点完不关** | 报名菜单操作后返回主菜单，可连续操作 |

### 主菜单改名
- 主菜单标题由 **GTR游戏菜单** 统一改为 **Hide'And'Seek**，四语（`hns_language.txt`）同步修改。

---

## ✨ 华雪版 v1.17 亮点

- 🤖 **AI 报名系统 v1.17（核心自研）**：`/signup` 一键报名、收团分组、娱乐局 / 赞助局、
  模式与地图投票、强制开赛（1 人可测）、换图跨图续赛、HUD 报名计数。
- 🎨 **皮肤系统（MySQL）**：玩家自定义皮肤，金币购买 / 租期 / 永久升级，死亡音效随机，管理员 `/cpm` 管理。
- 💳 **赞助 / ICGB 金币体系**：赞助局自动录入赞助者，金币与皮肤联动。
- 🗂 **跨图持久化（PDS）**：换图不丢比赛状态，AI 选图后自动恢复开赛。
- 🌐 **四语本地化**：简体 / 繁体 / English / Русский，AI 菜单与比赛菜单统一。
- 🧠 **AI 比赛人机**：无人时可 1 人开赛测试，不卡观战。
- 🛡 **稳定加载顺序**：`plugins.ini` 已排好 HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin。

---

## 🧩 核心插件清单

| 插件 | 版本 | 功能 |
|---|---|---|
| HnsAISignup | v1.17 | AI 报名系统（核心自研） |
| HnsMatchSystem | 2.0.5 | 比赛状态机（OpenHNS 底座 + 3 个新 native） |
| HnsMatchBans | 1.1 | 封禁管理 |
| HnsMatchMaps | 4.0.4 | 地图管理 |
| HnsMatchStats | 1.1.1 | 数据统计 |
| HnsMatchPts | 1.1 | 积分 |
| HnsMatchQuery | 1.0.0 | 比赛查询 `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | 管理员设置 `/adminmenu` |
| HnsMatchSkin | 1.0 | 皮肤系统（MySQL） |
| HnsMatchSql | 1.1 | MySQL 统一管理 |
| HnsLanguage | 1.3.0 | 四语语言核心 |
| HnsPersistentDataStorage | 1.0 | 跨图持久化 |
| HnsSponsorLocal | 1.0 | 赞助 / ICGB 金币 |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | 比赛辅助 |

---

## 🚀 快速部署

1. 下载部署包 `gtr_deploy_package_v1.17.zip`
2. 解压 `addons/` 覆盖到服务器 `cstrike/` 目录
3. 按 `10_交接与文档/` 配置 MySQL（皮肤库首次部署需建表）
4. 重启服务器 / 换图，控制台 `amxx plugins` 验证无 failed
5. 玩家进服 `/menu`，主菜单标题显示 **Hide'And'Seek**

---

## 📁 仓库结构（源码包）

```
01_当前版本_核心源码/       当前部署版核心插件源码 + include + compiled
02_各插件历史版本/          每个多版本插件独立分目录、按版本标注
03_开发工作区_scripting/    本地开发工作区 + AMXX 编译器
04_服务器部署_cstrike/      完整部署目录结构（addons/amxmodx + 第三方插件分类）
05_皮肤系统_v1.0完整版/     皮肤系统 MySQL 完整安装包
06_Beta测试插件包/         5 个独立小插件
07_第三方插件包/            SEM / semiclip / rtv_rus（dream-x.ru）
08_资源文件_asd/           皮肤模型 / 音效 / 贴图素材
09_开发脚本与临时文件/      AI 编程中间产物（仅供排查对照）
10_交接与文档/             修改记录、交接说明、更新日志
```

---

## ⏳ 版本演进时间线（HnsAISignup 主插件）

| 版本 | 时间 | 状态 | 说明 |
|---|---|---|---|
| v1.3 | 09-27 19:12 | 历史备份 | 队伍修复（teamfix）前的版本 |
| v1.5 | 09-27 19:55 | 历史备份 | 管理员修复（adminfix）版 |
| v1.5 | 09-27 20:00 | 历史备份 | 第二次修复前的备份 |
| v1.9 | 09-27 22:07 | 历史备份 | 大规模改动前（报名流程重构前） |
| **v1.17** | 09-30 23:00 | **当前部署版** | 华雪版正式版，全部改进落地 |
| v1.17+ | 10-01 02:13 | 开发中 | 新增 `taskRestorePendingRules`（换图后延迟恢复模式），未部署 |

> 完整历史版本见 `02_各插件历史版本/`，每个版本都有独立文件夹 + 说明。

---

## 📜 版权说明

- **OpenHNS 系插件**（HnsMatchSystem / Bans / Maps / Stats 等）：版权归原作者（OpenHNS / Garey / Cultura 等），MIT 类开源许可。
- **GTR 自研扩展**（AI 报名、赞助、皮肤接管、跨图存储、语言化等）：基于上述引擎二次开发。
- **第三方插件包**（SEM / rtv / FreshBans 等）：版权归各自作者，来源俄站 dream-x.ru。
- **皮肤素材**（models / sounds / 贴图）：版权未注明，商用前请自行确认。
- 欢迎 Fork / PR / 提 Issue，标注来源即可。

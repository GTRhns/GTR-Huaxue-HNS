# 🎮 GTR HNS 比赛插件系统 · 华雪版

<p align="center">
  <img src="assets/banner.jpg" alt="华雪版封面" width="480">
</p>

<div align="center">

[![AMX Mod X](https://img.shields.io/badge/AMX_Mod_X-1.10-blue)]()
[![ReGameDLL](https://img.shields.io/badge/ReGameDLL-5.x-orange)]()
[![Version](https://img.shields.io/badge/Version-v1.17-green)]()
[![Storage](https://img.shields.io/badge/Storage-PDS_%2B_MySQL-9cf)]()
[![Language](https://img.shields.io/badge/Language-4_Languages-ff69b4)]()
[![License](https://img.shields.io/badge/License-GPLv3-success)]()

</div>

> **基于 OpenHNS 比赛引擎二次开发，融合 GTR 团队大量自研功能**
> 适用：CS 1.6 / ReHLDS / AMX Mod X 1.10
> 当前版本：**华雪版 v1.17**（tag: `huaxue-v1.17`）

---

## 📌 目录

- [一、项目简介](#一项目简介)
- [二、新版 vs 旧版：有什么不一样](#二新版-vs-旧版有什么不一样)
- [三、华雪版 v1.17 亮点](#三华雪版-v117-亮点)
- [四、插件清单](#四插件清单)
- [五、仓库结构](#五仓库结构)
- [六、快速部署](#六快速部署)
- [七、技术栈](#七技术栈)
- [八、版权说明](#八版权说明)

---

## 一、项目简介

这是一套完整的 CS 1.6 HNS（Hide 'n' Seek，捉迷藏）比赛服务器插件系统。

底座来自开源项目 **OpenHNS**（HnsMatchSystem 2.0.5 及其官方插件集），
GTR 团队在其上围绕「**报名 → 分组 → 选赛制/地图 → 开赛 → 结算**」全流程，
注入了大量自研代码，形成独立的 **GTR 自研比赛引擎**。

---

## 二、新版 vs 旧版：有什么不一样

### 2.1 旧版的问题（本仓库修复的根源）

| # | 旧版问题 | 用户实际遇到的现象 |
|---|---|---|
| 1 | AI 菜单硬编码中文 | `/lang` 改成英文后，AI 报名菜单还是中文 |
| 2 | 强制开赛流程有缺陷 | 强制开赛把人拉去观战后就"消失"了，不选地图/模式 |
| 3 | 上场用 `jointeam` 命令 | 被 `blockCmd` 拦截，人在 LOBBY 模式卡在观战 |
| 4 | 开赛前不标记参赛者 | `mix_start()` 里 `forceUnmatchedToSpec` 把刚上场的人全踢回观战 |
| 5 | 换图状态全丢 | AI 选好图 changelevel 后，报名/赛制全部丢失，比赛永远开不起来 |
| 6 | 普通换图也自动开赛 | 管理员换张图，服务器自己就开始报名、2 分钟后自动收团 |
| 7 | 赞助局无赞助者录入 | 开了赞助局却没人能告诉系统"赞助者是谁" |
| 8 | mix 菜单第 7 项异常 | 第 7 项 HNS 模式"点不下去"，语言串没有 `^n` 视觉上像死项 |
| 9 | 报名人数数字条 | 聊天框/HUD 显示 `012345[6]78910`，用户要求去掉 |
| 10 | 报名菜单点一下就关 | 想连续操作菜单却自动关闭 |

### 2.2 新版（华雪版 v1.17）的对应改进

| # | 改进 | 实现方式 |
|---|---|---|
| 1 | **AI 菜单全语言化** | 全部走 `HnsLang_Get(id, key)`，支持简中/繁中/英语/俄语四语，`/lang` 实时联动 |
| 2 | **报名流程重构** | `SIGNUP_STATE` 状态机：报名 → 收团（全员观战+1秒1人上场）→ 选赛制/地图 → 开赛 |
| 3 | **ReAPI 安全上场** | 改用 `rg_set_user_team`（ReAPI），不再走 `jointeam`，LOBBY/TRAINING 下放行，杜绝卡观战 |
| 4 | **外部开赛预标记** | 新 native `hns_begin_external_match` 开赛前先把 T/CT 标为参赛者，解决"开赛瞬间全员回观战"的第二层根因 |
| 5 | **跨图 PDS 恢复** | 选图后 `PDS_SetCell("ai_pending_start",1)`，换图回来 5 秒自动续赛（`taskPendingResume`） |
| 6 | **普通换图不再自动开赛** | 非 pending 换图：报名清空、进入待命，由管理员手动开 |
| 7 | **赞助局录入** | 选完地图后第一个在线 VIP/管理员聊天输入赞助者名，30 秒超时或 `/取消` 跳过 |
| 8 | **mix 菜单固定编号** | 第 7 项永远 ICGB（非赞助局灰色不可点）、第 8 项永远管理员菜单 |
| 9 | **取消数字条 UI** | 删除 `buildSignupBar()`，HUD 只显示 `报名: n/12` |
| 10 | **菜单点完不关** | 报名菜单操作后返回主菜单，方便连续操作 |

### 2.3 版本演进时间线（HnsAISignup 主插件）

| 版本 | 时间 | 状态 | 说明 |
|---|---|---|---|
| v1.3 | 09-27 19:12 | 历史备份 | 队伍修复（teamfix）前的版本 |
| v1.5 | 09-27 19:55 | 历史备份 | 管理员修复（adminfix）版 |
| v1.5 | 09-27 20:00 | 历史备份 | 第二次修复前的备份 |
| v1.9 | 09-27 22:07 | 历史备份 | 大规模改动前（报名流程重构前） |
| **v1.17** | 09-30 23:00 | **当前部署版** | 华雪版正式版，全部改进落地 |
| v1.17+ | 10-01 02:13 | 开发中 | 新增 `taskRestorePendingRules`（换图后延迟恢复模式），未部署 |

> 完整版本历史见 `02_各插件历史版本/`，每个版本都有独立文件夹 + 说明。

---

## 三、华雪版 v1.17 亮点

- 🤖 **AI 报名系统 v1.17**：`/signup` 一键报名、收团分组、娱乐局/赞助局、模式与地图投票、
  强制开赛（1 人可测）、换图跨图续赛、HUD 报名计数。
- 🎨 **皮肤系统（MySQL）**：玩家自定义皮肤，金币购买 / 租期 / 永久升级，
  死亡音效随机，管理员 `/cpm` 菜单管理。
- 💳 **赞助 / ICGB 金币体系**：赞助局自动录入赞助者，金币与皮肤联动。
- 🗂 **跨图持久化（PDS）**：换图不丢比赛状态，AI 选图后自动恢复开赛。
- 🌐 **四语本地化**：简体 / 繁体 / English / Русский，AI 菜单与比赛菜单统一。
- 🧠 **AI 比赛人机**：无人时可 1 人开赛测试，不卡观战。
- 🛡 **稳定加载顺序**：`plugins.ini` 已排好 HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin。

---

## 四、插件清单

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

## 五、仓库结构

```
01_当前版本_核心源码/       当前部署版核心插件源码 + include + compiled
02_各插件历史版本/          每个多版本插件独立分目录、按版本标注
03_开发工作区_scripting/   本地开发工作区 + AMXX 编译器
04_服务器部署_cstrike/      完整部署目录结构（addons/amxmodx + 第三方插件分类）
05_皮肤系统_v1.0完整版/     皮肤系统 MySQL 完整安装包
06_Beta测试插件包/         5 个独立小插件
07_第三方插件包/            SEM / semiclip / rtv_rus（dream-x.ru）
08_资源文件_asd/           皮肤模型/音效/贴图素材
09_开发脚本与临时文件/      AI 编程中间产物（仅供排查对照）
10_交接与文档/             修改记录、交接说明、更新日志
```

---

## 六、快速部署

1. 前往 **Release** 下载最新 **华雪版** 的部署包 `gtr_deploy_package_v1.17.zip`
2. 解压 `addons/` 覆盖到服务器 `cstrike/` 目录
3. 按 `部署说明.txt` 配置 MySQL（皮肤库首次需建表）
4. 重启服务器 / 换图，控制台 `amxx plugins` 验证无 failed
5. 玩家进服后 `/menu` 主菜单标题显示 **Hide'And'Seek**

> 详细部署见 `10_交接与文档/` 与 Release 说明。

---

## 七、技术栈

| 组件 | 说明 |
|---|---|
| 引擎 | CS 1.6 / ReHLDS / ReGameDLL |
| 平台 | AMX Mod X 1.10（amxxpc 1.10.0.5479） |
| 底座 | OpenHNS Match System 2.0.5 |
| 数据库 | MySQL（HnsMatchSql）+ nvault（离线兜底） |
| 扩展 | ReAPI、HamSandwich、MixSystem |
| 自研 | AI 报名 / 赞助 / 皮肤接管 / 跨图持久化 / 四语 |

---

## 八、版权说明

- **OpenHNS 系插件**（HnsMatchSystem / Bans / Maps / Stats 等）：版权归原作者
  （OpenHNS / Garey / Cultura 等），MIT 类开源许可。
- **GTR 自研扩展**（AI 报名、赞助、皮肤接管、跨图存储、语言化等）：基于上述引擎二次开发。
- **第三方插件包**（SEM / rtv / FreshBans 等）：版权归各自作者，来源俄站 dream-x.ru。
- **皮肤素材**（models / sounds / 贴图）：版权未注明，商用前请自行确认。
- 欢迎 Fork / PR / 提 Issue，标注来源即可。
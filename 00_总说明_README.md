# GTR HNS 插件源码整理总说明

> 整理日期：2026-10-02
> 原始包：`8815622f-a2b2-4e4f-b770-bae6bcc4afca_gtr (1).rar`
> 项目类型：CS 1.6 / AMX Mod X (AMXX 1.10) HNS 比赛服务器插件集

---

## 一、项目背景

这是 GTR 服务器的 HNS（Hide 'n' Seek）比赛插件源码包，核心是 OpenHNS 系比赛系统
（HnsMatchSystem 2.0.5）加 GTR 自研的 **AI 报名系统**（HnsAISignup，当前 v1.17）。
源码以 `c:\Users\Administrator\Desktop\delivery` 为工作目录，使用 AMXX 1.10.0.5479 编译器。

关键参考文档（已归入 `10_交接与文档/`）：
- `插件修改记录.txt` —— 2026-09-27 详细改动记录（含踩坑记录）
- `上班交接_AI报名.txt` —— 上班交接短版说明（当前完整流程）
- `cstrike_scripting_UPDATELOG.txt` —— 回合制规则 / 自动切刀 / 无人训练模式更新日志

---

## 二、整理后目录总览

| 目录 | 内容 | 来源 |
|---|---|---|
| `01_当前版本_核心源码/` | 当前部署版核心插件源码（source/）+ 编译头文件（include/）+ 编译产物（compiled/） | gtr/source, include, compiled |
| `02_各插件历史版本/` | 每个多版本插件独立分目录，版本再分文件夹，附版本说明 | source/.bak、scripting、cstrike 等 |
| `03_开发工作区_scripting/` | 本地开发工作区：HNS 最新源码 + 官方 AMXX 基插件 + 编译器工具 | gtr/scripting |
| `04_服务器部署_cstrike/` | 服务器完整部署目录（addons/amxmodx + 插件分类 01-05 + 旧比赛插件） | gtr/cstrike |
| `05_皮肤系统_v1.0完整版/` | HNS 皮肤系统 1.0（MySQL 完整版，含安装说明） | gtr/skin 1.0 |
| `06_Beta测试插件包/` | 5 个小插件整理包（观察者列表/广告/解封/比分/游戏内广告） | gtr/amxx plugins bata |
| `07_第三方插件包/` | SEM(semiclip+metamod)、semiclip_package、rtv_rus（俄站 dream-x.ru 来源） | gtr/SEM, semiclip_package, rtv_rus |
| `08_资源文件_asd/` | 皮肤模型/音效资源（buffclass 皮肤素材） | gtr/asd |
| `10_交接与文档/` | 修改记录、交接说明、更新日志、源地址、AI agent 定义 | 各文档 |

---

## 三、核心插件版本对照表（重点）

### 3.1 HnsAISignup.sma —— AI 报名系统（GTR 自研，多版本）

| 版本 | 文件（整理后路径） | 原始文件 | 时间 | 大小 | 说明 |
|---|---|---|---|---|---|
| v1.3 | `02_.../HnsAISignup_AI报名/v1.3_teamfix_0927-1912/` | source/HnsAISignup.sma.bak_teamfix | 09-27 19:12 | 70726 | 修复队伍相关问题的版本（teamfix） |
| v1.5 | `02_.../v1.5_adminfix_0927-1955/` | .bak_adminfix | 09-27 19:55 | 71883 | 修复管理员相关问题的版本（adminfix） |
| v1.5 | `02_.../v1.5_before_fix2_0927-2000/` | .bak_before_fix2 | 09-27 20:00 | 71983 | 第二次修复前的备份 |
| v1.9 | `02_.../v1.9_before_19_0927-2207/` | .bak_before_19 | 09-27 22:07 | 79463 | "第19项改动"前的备份，体积开始明显增大 |
| **v1.17 当前部署版** | `01_当前版本_核心源码/HnsAISignup.sma` | source/HnsAISignup.sma | 09-30 23:00 | 92766 | 当前交付/部署版（= cstrike/scripting 与 cstrike/addons 副本，md5 一致） |
| v1.17+ 最新开发版 | `02_.../v1.17_scripting最新_1001-0213/` | scripting/HnsAISignup.sma | 10-01 02:13 | 92873 | 在部署版基础上新增 `taskRestorePendingRules`（换图后延迟恢复模式），未确认是否部署 |

> v1.17 当前版的备份副本关系：`source/` = `cstrike/scripting/` = `cstrike/addons/amxmodx/scripting/`（md5 全同）。

### 3.2 HnsMatchSystem.sma —— Hide'n'Seek 比赛主系统（OpenHNS 2.0.5 系）

| 变体 | 整理后路径 | 原始文件 | 时间 | 大小 | 说明 |
|---|---|---|---|---|---|
| v2.0.5 旧 | `02_.../HnsMatchSystem_比赛主系统/v2.0.5_cstrikeScripting_旧/` | cstrike/scripting/HnsMatchSystem.sma | 09-30 03:34 | 18961 | cstrike/scripting 工作副本（无 LOBBY 相关最新修改） |
| v2.0.5 部署 | `02_.../v2.0.5_source/` | source/HnsMatchSystem.sma | 09-30 22:25 | 19187 | 交付源码（含 hns_ai_enter_lobby 等 3 个新 native） |
| v2.0.5 addons | `02_.../v2.0.5_cstrikeAddons/` | cstrike/addons/amxmodx/scripting/HnsMatchSystem.sma | 09-30 22:25 | 18981 | 运行侧副本（与 source 有差异） |
| v2.0.5 最新 | `02_.../v2.0.5_scripting最新/` | scripting/HnsMatchSystem.sma | 10-01 02:06 | 19202 | 最新开发版，尚未与 source 同步 |

> 4 份都标 2.0.5，但内容各不相同（md5 全异），改代码时必须确认以哪份为准，并保持
> include 与 native 两边一致。

### 3.3 HnsMatchSkin.sma —— 皮肤系统

| 变体 | 整理后路径 | 原始文件 | 时间 | 大小 | 说明 |
|---|---|---|---|---|---|
| v1.0 完整版 | `02_.../HnsMatchSkin_皮肤/v1.0_完整版MySQL/` | skin 1.0/addons/.../HnsMatchSkin.sma | 09-30 22:29 | 78233 | MySQL 完整版（管理菜单/多音效随机/调试项），随 05 皮肤包发布 |
| addons 部署版 | `02_.../addons部署版/` | cstrike/addons/amxmodx/scripting/HnsMatchSkin.sma | 09-28 19:42 | 44295 | 服务器运行侧副本（精简过） |
| scripting 重构版 | `02_.../scripting重构版/` | scripting/HnsMatchSkin.sma | 10-01 22:29 | 45905 | 最新重构版（菜单简化，管理员菜单独立入口） |

### 3.4 其他多版本插件（source 版 = 当前部署，scripting 版 = 工作区）

| 插件 | source 版（当前） | scripting 版 | 备注 |
|---|---|---|---|
| HnsLanguage | v1.3.0，09-27，10692B | 09-11，8880B + .fixed | source 版是最新（改过语言键）；scripting 是旧版 |
| HnsMatchBans | 10-01，33596B | 09-30，33411B | addons 版 10-01 18:26 33426B（第三份） |
| HnsMatchStats | 09-26，13134B | 10-01，12633B | addons 版 = 2025-03-16 老文件 |
| HnsMatchAdmin | 10-01 18:27，14138B | 10-01 02:55，14132B | addons 版 10-01 18:26 为第三份 |
| HnsMatchPlayerInfo | 09-28，17120B | 09-30，17186B | |
| HnsMatchTraining | 09-29，12268B | 2025-03-16 旧版 11103B | |
| HnsMatchWatcher | 09-26，11530B | 09-30，11306B | |
| HnsMatchMaps | v4.0.4，09-30，21749B | 另有 .current 2026-07-13 20543B 旧版 | |
| HnsPersistentDataStorage | 09-26，5043B | 09-25，4775B | |
| HnsSponsorLocal | 09-26，1719B | 09-25，1665B | |

无多版本的插件（当前版见 01）：HnsMatchChatmanager、HnsMatchMapRules、HnsMatchOwnage、
HnsMatchPause、HnsMatchPts、HnsMatchQuery、HnsMatchRecontrol、HnsMatchSql、
HnsAISignupBots、hns_bot_test。

---

## 四、编译与部署要点（摘自交接文档）

```
工作目录: c:\Users\Administrator\Desktop\delivery
编译: cstrike\scripting\amxxpc.exe -ic:\...\delivery\include source\HnsAISignup.sma -ocompiled\HnsAISignup.amxx
注意: -i / -o 必须与路径连写, 不能有空格; PowerShell 禁止 here-string 写 SMA;
      禁止对同一 SMA 区域做重叠 patch（会把文件截断）。
部署: compiled\*.amxx -> cstrike\addons\amxmodx\plugins\
加载顺序(plugins.ini): HnsLanguage -> HnsPersistentDataStorage -> HnsSponsorLocal ->
      HnsMatchSystem -> ... -> HnsAISignup(在 MatchSystem 之后)
```

---

## 五、注意事项 / 已知坑

1. 有两套 include：`include\`（编译用）与 `cstrike\addons\amxmodx\scripting\include\`
   （运行侧副本）。改 hnsmenu.inc / cmds.inc 必须两边同步。
2. `cstrike\scripting\include\hns_matchsystem.inc` 是**旧 enum 版本，不要当编译源用**。
3. 上场必须用 ReAPI `rg_set_user_team`，不要用 `rg_internal_cmd("jointeam")`（会被 blockCmd 拦截）。
4. 换图会重载插件、全局变量全丢，跨图状态只能靠 PDS（PersistentDataStorage）。
5. 赞助者输入由 AI 插件自己捕获 say（g_bSponsorNameInput），与 cmds.inc 同名数组互不覆盖。
6. 无独立 VIP 系统，权限用 `isUserWatcher / isUserAdmin / is_user_admin` 合成 `isUserVipOrAdmin()`。
7. 部分聊天提示仍为中文硬编码，未全部走语言键。

---

## 六、第三方来源标注

- OpenHNS 系插件（HnsMatch* 大部分）：原始作者 OpenHNS / Garey / Cultura 等。
- `04_服务器部署_cstrike/01-05` 分类插件、`07_第三方插件包/rtv_rus`：俄站
  DREAM-X.RU（dream-x.ru）下载包，内含 .URL 快捷方式与俄语说明。
- `08_资源文件_asd/`：buffclass 皮肤模型/音效素材（第三方资源，未注明版权，商用请自行确认）。
- `源地址.txt`：https://cs-bg.info/game-cs/mods/amxmodx/plugins/534

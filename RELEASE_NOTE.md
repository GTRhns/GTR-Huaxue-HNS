# 正式版 1.0 GTR HNS（GTR HNS 比赛插件系统）

**GTR HNS 比赛插件系统 —— 完整源码 + 部署包**

> 基于 OpenHNS 比赛引擎二次开发，GTR 团队大量自研功能
> 适用：CS 1.6 / ReHLDS / AMX Mod X 1.10
> 版本：正式版 1.0（原华雪版系列正式定名）
> Tag：`v1.0`

---

## 本 Release 内容

| # | 附件 | 说明 |
|---|---|---|
| 1 | gtr_deploy_package_v1.0.zip | 服务器一键部署包（addons/amxmodx + rechecker + semiclip 结构，解压覆盖即用，含编译好的 .amxx 与全部配置） |
| 2 | gtr_source_full_v1.0.zip | 完整源码包（当前版本核心源码 + 各插件历史版本 + 开发工作区 + 全套文档） |

> 源码同步在仓库 main 分支，按目录整理并标注了每个插件的历史版本。

---

## 正式版 1.0 相比华雪版 v1.19.3：新增内容

正式版 1.0 = 华雪版 v1.19.3 全部功能 + 反作弊与比赛工具扩充。

### 新增插件（plugins.ini 已启用）

| # | 插件 | 功能 |
|---|---|---|
| 1 | HnsClientBuild v1.1.0 | 客户端构建校验：hw.dll 哈希检测，命令 hns_build_trust / hns_build_enforce / hns_build_status，默认只记录不踢人 |
| 2 | hns_multiflash | mix 自动多重闪光，比赛设置 开/关/自动，VIP /mflash 设置数量 |
| 3 | HnsMatchAccess | 比赛进入授权（SQL 配置 mixsystem/hnsmatch-sql.cfg） |
| 4 | HnsPlayerAdmin | 管理员玩家管理菜单：选人 / 拍打 / 处死 / 踢出 / 封禁 / 换队 / 处死全队 |
| 5 | HnsShowKeys | KZ 按键 HUD：WASD / 跳 / 蹲 + 水平速度显示，/kzhud 开关 |
| 6 | HnsAISizeVote v1.0.0 | 在线玩家投票 3v3-6v6 报名规模（20 秒投票） |
| 7 | HnsAISignupBots | AI 机器人报名，无真人时补齐比赛 |
| 8 | uq_jumpstats | 跳跃数据统计（Jumpstats） |
| 9 | hns_movement_stats | HNS 移动数据统计（HMS Movement Suite，SQL 记录） |

### 新增模块与数据

| # | 项目 | 说明 |
|---|---|---|
| 1 | ReChecker 2.7 | 官方反作弊模块（rechecker_mm.dll / rechecker_mm_i386.so），与 HnsClientBuild 配合校验客户端 hw.dll 构建号（2024-10-07 / 10210） |
| 2 | semiclip.dll | 团队半透明模块（team-semiclip，含 SemiclipSystem 配置） |
| 3 | ip2region_v4.xdb / GeoLite2 | 地理位置数据库，进服信息显示国家地区 |

### 随部署包附带（默认未启用）

| # | 插件 | 说明 |
|---|---|---|
| 1 | GtrMatchMix | mix 系统源码（10.3 起由 HnsMatchSystem 统一管理 mix，避免双生命周期冲突） |
| 2 | PugRegistration | PUG 报名系统源码（local / mysql / simple 三种接入） |
| 3 | HnsMatchDemo / HnsMatchHltv | 比赛 demo 自动录制、HLTV 录制推送源码 |
| 4 | hns_fps_limit / yj_prefog | FPS 限制、预雾化（prefog）源码与编译包 |

### 更新与增强

| # | 插件 | 说明 |
|---|---|---|
| 1 | HnsMatchSystem 2.0.5 | 比赛状态机更新，mix 生命周期统一管理 |
| 2 | HnsAISignup | 报名流程与权限进一步优化，主菜单整理 |
| 3 | HnsMatchSql / HnsMatchSkin / HnsMatchPts | MySQL 统一管理、皮肤系统、积分细节更新 |
| 4 | HnsConnectInfo | 进服信息结合 ip2region 显示地区 |

---

## 快速部署

1. 下载部署包 gtr_deploy_package_v1.0.zip
2. 解压 addons/ 覆盖到服务器 cstrike/ 目录
3. 按 10_交接与文档/ 配置 MySQL（皮肤库首次部署需建表）
4. ReChecker 与 HnsClientBuild：确认 cstrike/addons/metamod/plugins.ini 在 amxmodx 之上加载 rechecker_mm，重启后 hns_build_trust 玩家名 开始校验
5. 重启服务器 / 换图，控制台 amxx plugins 验证无 failed

---

## 仓库结构（源码包）

```
01_当前版本_核心源码/       当前部署版核心插件源码 + include + compiled
02_各插件历史版本/          每个多版本插件独立分目录、按版本标注
03_开发工作区_scripting/    本地开发工作区 + AMXX 编译器
04_服务器部署_cstrike/      完整部署目录结构（addons/amxmodx + rechecker + semiclip）
05_皮肤系统_v1.0完整版/     皮肤系统 MySQL 完整安装包
06_Beta测试插件包/         5 个独立小插件
07_第三方插件包/            SEM / semiclip / rtv_rus（dream-x.ru）
08_资源文件_asd/           皮肤模型/音效/贴图素材
10_交接与文档/             修改记录、交接说明、更新日志
```

---

## 版本演进时间线（HnsAISignup 主插件）

| 版本 | 时间 | 状态 | 说明 |
|---|---|---|---|
| v1.3 | 09-27 19:12 | 历史备份 | 队伍修复（teamfix）前的版本 |
| v1.5 | 09-27 19:55 | 历史备份 | 管理员修复（adminfix）版 |
| v1.9 | 09-27 22:07 | 历史备份 | 大规模改动前（报名流程重构前） |
| v1.17 | 09-30 23:00 | 上一发行版 | 华雪版正式版，报名流程重构全部落地 |
| v1.18 | 10-01 | 上一发行版 | wintime 胜负判定修复 + 换图恢复赛制 + 菜单权限收敛 |
| v1.19 | 10-03 | 上一发行版 | 主菜单更名 Hide'And'Seek（四语同步） |
| v1.19.3 | 10-05 | 上一发行版 | 冰冻烟雾玩法 + 比赛设置菜单整合 + 多插件升级 |
| 正式版 1.0 | 10-20 | 当前部署版 | 客户端构建校验 + 比赛工具扩充 + 大量新插件 |

> 完整历史版本见 02_各插件历史版本/，每个版本都有独立文件夹 + 说明。

---

## 版权说明

- OpenHNS 系插件（HnsMatchSystem / Bans / Maps / Stats 等）：版权归原作者（OpenHNS / Garey / Cultura 等），MIT 类开源许可。
- GTR 自研扩展（AI 报名、赞助、皮肤接管、跨图存储、语言化等）：基于上述引擎二次开发。
- ReChecker：官方开源反作弊模块（ReHLDS 团队）。
- 第三方插件包（SEM / rtv / FreshBans 等）：版权归各自作者，来源俄站 dream-x.ru。
- 皮肤素材（models / sounds / 贴图）：版权未注明，商用前请自行确认。
- 欢迎 Fork / PR / 提 Issue，标注来源即可。

---

一切解释权归 LINNA 所有，GTRhns 将服务于每一个人。

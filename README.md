# 🎮 GTRhns · HNS 比赛插件系统（华雪版）

> **底部基于 [OpenHNS](https://github.com/OpenHNS/) 引擎与原生插件扩展，融合 GTR 团队多年自研功能**
> 适合 CS 1.6 / AMX Mod X 1.10 的 HNS（Hide 'n' Seek）比赛服务器使用。

---

## ✨ 特性亮点（自研部分）

本系统并非简单套壳，而是在 OpenHNS 比赛的底座之上，围绕**报名→分组→开赛→结算**全流程，
注入了大量 GTR 自研逻辑：

- 🤖 **AI 报名系统（HnsAISignup）** — 当前 **v1.17**，`/signup` 一键报名、收团分组、
  模式/地图投票、赞助局、强制开赛；支持换图后通过 PDS 恢复待开赛状态。
- 🎨 **皮肤系统（HnsMatchSkin）** — MySQL 接管的玩家自定义皮肤，金币购买 / 租期 / 永久；
  多死亡音效随机。
- 🧠 **AI 比赛人机（HnsAISignupBots）** — 无人时可 1 人开赛测试，不卡观战。
- 🗂 **跨图持久化（HnsPersistentDataStorage）** — 换图不丢状态，mat 规则自动恢复。
- 💳 **本地赞助 / ICGB 金币（HnsSponsorLocal）** — 双端接入，赞助即入场。
- 🌐 **四语语言系统（HnsLanguage v1.3.0）** — 简中 / 繁中 / 英语 / 俄语一键切换。

---

## 📁 仓库结构

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

## 🚀 快速部署

1. 下载最新 **华雪版 Release**（附**部署包** `gtr_部署包_9-30版_v1.17.zip`）
2. 解压 `addons/` 后覆盖到服务器 `cstrike/` 目录
3. 按 `部署说明.txt` 配置 MySQL（皮肤库首次需建表）
4. 重启服务器 / 换图，控制台 `amxx plugins` 验证无 failed

> 详细步骤见 Release 说明或仓库内 `10_交接与文档/`。

---

## 🧩 技术栈

| 组件 | 说明 |
|---|---|
| 引擎 | CS 1.6 / ReHLDS - AMXX 1.10 (amxxpc 1.10.0.5479) |
| 底座 | OpenHNS Match System 2.0.5（HnsMatchSystem / HnsMatchBans / Maps / Stats …） |
| 数据库 | MySQL（HnsMatchSql 统一管理，皮肤 / PTS / 封禁） |
| 扩展 | ReAPI、HamSandwich、MixSystem（比赛模式）+ 自研 AI 报名 |

---

## 📜 版权说明

- 核心 OpenHNS 系插件版权归原作者（OpenHNS / Garey / Cultura 等）。
- GTR 自研扩展（AI 报名、赞助、皮肤接管、跨图存储等）基于上述引擎二次开发。
- 第三方插件包（SEM / rtv / FreshBans 等）版权归各自作者，来自俄站 dream-x.ru。
- 皮肤素材（models / sounds）版权未注明，商用前请自行确认。
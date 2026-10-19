GTR HNS 最终修复包 - 2026-10-03

本包为完整 scripting 项目包，不是只包含两个源码文件。

【权限】
1. Skin -> 管理员设置：仅 AMXX A 权限（ADMIN_IMMUNITY）。
2. Skin -> SQL 调试：A 或 B 任一权限（ADMIN_IMMUNITY / ADMIN_RESERVATION）。
3. 所有菜单入口与 Handler 均再次检查权限，隐藏菜单不等于唯一安全措施。

【AI 报名】
1. 主菜单重新整理：普通玩家只看到实际可用的报名/分组/类型/模式功能。
2. 队伍人数、重新分队、强制开赛仅管理员/VIP显示。
3. 重新分队命令本身增加权限检查。
4. 比赛模式换图恢复继续从 PDS 恢复，并同步到 HnsMatchSystem，避免又回 MR。
5. 模式选择仍保留无管理员时的投票机制。

【Skin】
1. 一级菜单重新整理为：角色皮肤 / 刀皮 / 投掷物 / GBIC / 管理员设置 / SQL调试。
2. 菜单状态按玩家隔离，避免多人同时操作互相串状态。
3. 管理和 SQL 菜单使用独立返回/权限检查。

【编译】
Windows AMXX 编译环境中重新编译：
- HnsAISignup.sma
- HnsMatchSkin.sma

本运行环境没有 Windows PE 运行器，因此没有伪造“已生成新的 AMXX”。ZIP 中保留原有 amxx 文件作为项目现状备份；部署前请用你的 AMXX 1.9/1.10 对上述两个 SMA 重新编译。

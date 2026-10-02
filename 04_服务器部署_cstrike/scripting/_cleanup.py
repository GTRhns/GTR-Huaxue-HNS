# -*- coding: utf-8 -*-
import io

def read(p):
    return io.open(p, 'r', encoding='utf-8-sig').read()

def write(p, s):
    io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)

def strip_blank(s):
    lines = s.split('\n')
    out=[]; prev_blank=False
    for l in lines:
        if l.strip()=='':
            if not prev_blank: out.append('')
            prev_blank=True
        else:
            out.append(l); prev_blank=False
    return '\n'.join(out)

p = 'HnsMatchSystem.sma'
s = read(p)
orig = s

block1 = """	// v6.2: 强制摔伤 (0=关闭, 1=引擎返回0伤害但下落超速时手动补算)
	g_pForceFallDamage = register_cvar("hns_force_falldamage", "1");
	// ★ 主动摔伤检测循环任务: 不依赖引擎 FlPlayerFallDamage hook,
	//   解决"打几把后 T 摔落不掉血"(半穿 SOLID_NOT / 残留无敌导致引擎不再触发摔伤)
	set_task(0.05, "taskFallDamageCheck", TASK_FALLDMG_CHECK, _, _, "b");

"""
assert block1 in orig, "block1 not found"
orig = orig.replace(block1, "")

old_fz = """public rgOnRoundFreezeEnd() {
	g_bReGameDLLRoundFired = true; // 无 ReGameDLL 时 AMXX fallback 也跳过 freezeend
	// ★ 只在"整场比赛开场的第一局"刷新一次回合 (g_bRoundStartRefreshed 防循环)
	//   刷新回合 = sv_restart 让 T 重新 spawn, 彻底清除残留无敌/碰撞/模型
	if (!g_bRoundStartRefreshed && g_iCurrentMode != MODE_TRAINING) {
		g_bRoundStartRefreshed = true;
		remove_task(TASK_ROUNDSTART_REFRESH);
		set_task(1.0, "taskRoundStartRefresh", TASK_ROUNDSTART_REFRESH);
	}
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);
}"""
new_fz = """public rgOnRoundFreezeEnd() {
	g_bReGameDLLRoundFired = true; // 无 ReGameDLL 时 AMXX fallback 也跳过 freezeend
	// ★ 只在 [mix 比赛] 开场第一局刷新一次回合 (g_bRoundStartRefreshed 防循环)
	//   仅 mix 触发, 公共/其他模式不 sv_restart, 避免干扰掉血
	if (!g_bRoundStartRefreshed && g_iCurrentMode == MODE_MIX) {
		g_bRoundStartRefreshed = true;
		remove_task(TASK_ROUNDSTART_REFRESH);
		set_task(1.0, "taskRoundStartRefresh", TASK_ROUNDSTART_REFRESH);
	}
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);
}"""
assert old_fz in orig, "rgOnRoundFreezeEnd block not found"
orig = orig.replace(old_fz, new_fz)

old_tsr = """public taskRoundStartRefresh() {
	if (g_iCurrentMode == MODE_TRAINING) return; // 训练模式保留无敌
	hns_restart_round(1.0);
}"""
new_tsr = """public taskRoundStartRefresh() {
	if (g_iCurrentMode != MODE_MIX) return; // 只在 mix 比赛刷新
	hns_restart_round(1.0);
}"""
assert old_tsr in orig, "taskRoundStartRefresh not found"
orig = orig.replace(old_tsr, new_tsr)

start = orig.find("// ★ 主动摔伤检测 (高频循环): 不依赖引擎 FlPlayerFallDamage hook,")
end_marker = "// ============================================\n// AMXX标准事件fallback"
if start == -1:
    start = orig.find("public taskFallDamageCheck()")
end = orig.find(end_marker)
if start != -1 and end != -1 and start < end:
    orig = orig[:start] + orig[end:]
else:
    print("WARN: taskFallDamageCheck block not cleanly located; start=%d end=%d" % (start,end))

old_pre = """// v5.5: 坠落伤害显示 - 预钩子保存当前血量
// v6.2: ★ 强制解除残留无敌, 修复"匪徒从多高摔下去都不掉血"
public rgFlPlayerFallDamagePre(const id) {
    g_fPendingFallDmg[id] = 0.0;

    if (is_user_connected(id)) {
        // 1. 解除残留无敌 (godmode 免疫所有伤害包括摔落)
        //    ★ 训练模式除外——训练模式玩家本来就该无敌
        //    ★ 同时检测 entvar(var_takedamage) 与 pev_takedamage:
        //      有些插件(如 hnsic)只设 var_takedamage=DAMAGE_NO 而不设 pev,
        //      之前只读 pev_takedamage 会漏判, 导致"匪徒摔落不掉血"
        new Float:flTake = 0.0;
        get_entvar(id, var_takedamage, flTake);
        new iPevTake;
        pev(id, pev_takedamage, iPevTake);
        if (g_iCurrentMode != MODE_TRAINING && (flTake == 0.0 || iPevTake == DAMAGE_NO)) {
            setUserGodmode(id, false);
        }

        // 2. 恢复实体碰撞: 半穿插件把玩家设为 SOLID_NOT 时,
        //    引擎可能无法正确检测落地 (FL_ONGROUND 不更新),
        //    导致"从多高摔下去都不掉血"。落地判定前强制恢复碰撞体积。
        new iSolid;
        pev(id, pev_solid, iSolid);
        if (iSolid == SOLID_NOT) {
            set_pev(id, pev_solid, SOLID_SLIDEBOX);
        }
    }
}"""
new_pre = """// v5.5: 坠落伤害显示 - 预钩子保存当前血量
public rgFlPlayerFallDamagePre(const id) {
    g_fPendingFallDmg[id] = 0.0;
}"""
assert old_pre in orig, "rgFlPlayerFallDamagePre block not found"
orig = orig.replace(old_pre, new_pre)

old_fd = """public rgFlPlayerFallDamage(const id) {
    new Float:flDmg = Float:GetHookChainReturn(ATYPE_FLOAT);

    // v6.2: 强制摔伤(可选) - 若引擎返回0伤害但玩家下落速度超过安全阈值
    //   (jumpbug/半穿/边缘落地导致 m_flFallVelocity 未被正确结算),
    //   手动补算伤害。默认关闭, 用 hns_force_falldamage 开启。
    //   ★ 训练模式不做强制摔伤
    if (flDmg <= 0.0 && is_user_alive(id) && g_iCurrentMode != MODE_TRAINING && get_pcvar_num(g_pForceFallDamage)) {
        new Float:flFallVel;
        get_entvar(id, var_flFallVelocity, flFallVel);
        if (flFallVel > 580.0) {
            flDmg = (flFallVel - 580.0) * 0.075;
            SetHookChainReturn(ATYPE_FLOAT, flDmg);
        }
    }

    // v5.5: 坠落伤害显示（仅对玩家显示，忽略0伤害）"""
new_fd = """public rgFlPlayerFallDamage(const id) {
    new Float:flDmg = Float:GetHookChainReturn(ATYPE_FLOAT);

    // v5.5: 坠落伤害显示（仅对玩家显示，忽略0伤害）"""
assert old_fd in orig, "rgFlPlayerFallDamage block not found"
orig = orig.replace(old_fd, new_fd)

orig = strip_blank(orig)
write(p, orig)
print("DONE HnsMatchSystem.sma")

gp = 'include/hns-match/globals.inc'
g = read(gp)
old_g = """// === Knife ViewModel Settings ===
new bool:g_bKnifeViewModel[MAX_PLAYERS + 1];  // 每个玩家是否显示刀模型（true=显示, false=隐藏）
// ★ 主动摔伤检测: 记录上一帧是否落地 (FL_ONGROUND), 用于捕捉"落地瞬间"计算摔伤
new bool:g_bPrevOnGround[MAX_PLAYERS + 1];
// ★ 主动摔伤检测: 上一帧的 Z 坐标, 用于在"虚体(SOLID_NOT)"下用位置变化可靠判定落地
//   (虚体时 FL_ONGROUND 不更新, 须改为追踪是否从"持续下降"转为"稳定"来判断落地)
new Float:g_fPrevZ[MAX_PLAYERS + 1];
new Float:g_fClimbVel[MAX_PLAYERS + 1];  // 追踪最近一次"下落"的垂直速度峰值
new bool:g_bWasFalling[MAX_PLAYERS + 1]; // 上一帧是否处于下落"""
new_g = """// === Knife ViewModel Settings ===
new bool:g_bKnifeViewModel[MAX_PLAYERS + 1];  // 每个玩家是否显示刀模型（true=显示, false=隐藏）"""
if old_g in g:
    g = g.replace(old_g, new_g)
else:
    print("WARN: globals block not found")

old_t = """// 观察者模式初始化延迟任务 (jointeam 6 后延迟设置 iuser1/iuser2, 避免被引擎覆盖)
#define TASK_SPEC_INIT 13343
// ★ 主动摔伤检测循环任务 (解决"打几把后 T 摔落不掉血")
#define TASK_FALLDMG_CHECK 13346"""
new_t = """// 观察者模式初始化延迟任务 (jointeam 6 后延迟设置 iuser1/iuser2, 避免被引擎覆盖)
#define TASK_SPEC_INIT 13343"""
if old_t in g:
    g = g.replace(old_t, new_t)
else:
    print("WARN: TASK_FALLDMG_CHECK define not found")

g = strip_blank(g)
write(gp, g)
print("DONE globals.inc")
print("ALL DONE")

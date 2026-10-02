$ErrorActionPreference = 'Stop'
$Dir = 'C:\Users\Administrator\Desktop\scripting'
$p = Join-Path $Dir 'HnsMatchSystem.sma'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$s = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)

function CollapseBlank([string]$t) {
    $lines = $t -split "`n"
    $out = New-Object System.Collections.Generic.List[string]
    $prevBlank = $false
    foreach($l in $lines){
        $tl = $l.TrimEnd("`r")
        if($tl.Trim() -eq ''){
            if(-not $prevBlank){ $out.Add('') }
            $prevBlank = $true
        } else {
            $out.Add($l)
            $prevBlank = $false
        }
    }
    return ($out -join "`n")
}

function ReplaceBlock([string]$from, [string]$to){
    if($s.Contains($from)){
        $script:s = $s.Replace($from, $to)
        Write-Output "OK  replaced ($($from.Substring(0, [Math]::Min(30,$from.Length)))...)"
    } else {
        Write-Output "MISS  $($from.Substring(0, [Math]::Min(40,$from.Length)))..."
    }
}

# --- 1. plugin_init: remove startup + cvar (keep cvar? remove with forcefalldamage) ---
$b1 = "`t// v6.2: 强制摔伤 (0=关闭, 1=引擎返回0伤害但下落超速时手动补算)`r`n`tg_pForceFallDamage = register_cvar(`"hns_force_falldamage`", `"1`");`r`n`t// ★ 主动摔伤检测循环任务: 不依赖引擎 FlPlayerFallDamage hook,`r`n`t//   解决`"打几把后 T 摔落不掉血`"(半穿 SOLID_NOT / 残留无敌导致引擎不再触发摔伤)`r`n`tset_task(0.05, `"taskFallDamageCheck`", TASK_FALLDMG_CHECK, _, _, `"b`");`r`n`r`n"
if($s.Contains($b1)){ $s = $s.Replace($b1, "") } else { Write-Output "MISS block1" }

# --- 2. rgOnRoundFreezeEnd -> MIX ---
$fzFrom = "public rgOnRoundFreezeEnd() {`r`n`tg_bReGameDLLRoundFired = true; // 无 ReGameDLL 时 AMXX fallback 也跳过 freezeend`r`n`t// ★ 只在`"整场比赛开场的第一局`"刷新一次回合 (g_bRoundStartRefreshed 防循环)`r`n`t//   刷新回合 = sv_restart 让 T 重新 spawn, 彻底清除残留无敌/碰撞/模型`r`n`tif (!g_bRoundStartRefreshed && g_iCurrentMode != MODE_TRAINING) {`r`n`t`tg_bRoundStartRefreshed = true;`r`n`t`tremove_task(TASK_ROUNDSTART_REFRESH);`r`n`t`tset_task(1.0, `"taskRoundStartRefresh`", TASK_ROUNDSTART_REFRESH);`r`n`t}`r`n`tif (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])`r`n`t`tExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);`r`n}"
$fzTo  = "public rgOnRoundFreezeEnd() {`r`n`tg_bReGameDLLRoundFired = true; // 无 ReGameDLL 时 AMXX fallback 也跳过 freezeend`r`n`t// ★ 只在 [mix 比赛] 开场第一局刷新一次回合 (g_bRoundStartRefreshed 防循环)`r`n`t//   仅 mix 触发, 公共/其他模式不 sv_restart, 避免干扰掉血`r`n`tif (!g_bRoundStartRefreshed && g_iCurrentMode == MODE_MIX) {`r`n`t`tg_bRoundStartRefreshed = true;`r`n`t`tremove_task(TASK_ROUNDSTART_REFRESH);`r`n`t`tset_task(1.0, `"taskRoundStartRefresh`", TASK_ROUNDSTART_REFRESH);`r`n`t}`r`n`tif (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])`r`n`t`tExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);`r`n}"
if($s.Contains($fzFrom)){ $s = $s.Replace($fzFrom, $fzTo) } else { Write-Output "MISS rgOnRoundFreezeEnd" }

# --- 3. taskRoundStartRefresh -> MIX only ---
$tsrFrom = "public taskRoundStartRefresh() {`r`n`tif (g_iCurrentMode == MODE_TRAINING) return; // 训练模式保留无敌`r`n`thns_restart_round(1.0);`r`n}"
$tsrTo   = "public taskRoundStartRefresh() {`r`n`tif (g_iCurrentMode != MODE_MIX) return; // 只在 mix 比赛刷新`r`n`thns_restart_round(1.0);`r`n}"
if($s.Contains($tsrFrom)){ $s = $s.Replace($tsrFrom, $tsrTo) } else { Write-Output "MISS taskRoundStartRefresh" }

# --- 4. remove taskFallDamageCheck whole block (incl comment) ---
$startIdx = $s.IndexOf("// ★ 主动摔伤检测 (高频循环): 不依赖引擎 FlPlayerFallDamage hook,")
if($startIdx -lt 0){ $startIdx = $s.IndexOf("public taskFallDamageCheck()") }
$endMark  = "// ============================================`r`n// AMXX标准事件fallback"
$endIdx   = $s.IndexOf($endMark)
if($startIdx -ge 0 -and $endIdx -ge 0 -and $startIdx -lt $endIdx){
    $s = $s.Substring(0, $startIdx) + $s.Substring($endIdx)
    Write-Output "OK removed taskFallDamageCheck"
} else { Write-Output "MISS taskFallDamageCheck block start=$startIdx end=$endIdx" }

# --- 5. rgFlPlayerFallDamagePre -> clean ---
$preMark = "public rgFlPlayerFallDamagePre(const id) {"
$preIdx  = $s.IndexOf($preMark)
$nextPub = $s.IndexOf("public rgFlPlayerFallDamage(const id) {")
if($preIdx -ge 0 -and $nextPub -ge 0){
    # find comment header start just before
    $head = $s.LastIndexOf("// v5.5: 坠落伤害显示 - 预钩子保存当前血量", $preIdx)
    $repl = "// v5.5: 坠落伤害显示 - 预钩子保存当前血量`r`npublic rgFlPlayerFallDamagePre(const id) {`r`n    g_fPendingFallDmg[id] = 0.0;`r`n}`
"
    $s = $s.Substring(0, $head) + $repl + $s.Substring($nextPub)
    Write-Output "OK cleaned rgFlPlayerFallDamagePre"
} else { Write-Output "MISS rgFlPlayerFallDamagePre idx=$preIdx next=$nextPub" }

# --- 6. rgFlPlayerFallDamage -> remove forced block ---
$fdFrom = "    // v6.2: 强制摔伤(可选) - 若引擎返回0伤害但玩家下落速度超过安全阈值`r`n    //   (jumpbug/半穿/边缘落地导致 m_flFallVelocity 未被正确结算),`r`n    //   手动补算伤害。默认关闭, 用 hns_force_falldamage 开启。`r`n    //   ★ 训练模式不做强制摔伤`r`n    if (flDmg <= 0.0 && is_user_alive(id) && g_iCurrentMode != MODE_TRAINING && get_pcvar_num(g_pForceFallDamage)) {`r`n        new Float:flFallVel;`r`n        get_entvar(id, var_flFallVelocity, flFallVel);`r`n        if (flFallVel > 580.0) {`r`n            flDmg = (flFallVel - 580.0) * 0.075;`r`n            SetHookChainReturn(ATYPE_FLOAT, flDmg);`r`n        }`r`n    }`r`n`r`n"
if($s.Contains($fdFrom)){ $s = $s.Replace($fdFrom, "") } else { Write-Output "MISS rgFlPlayerFallDamage forced-block" }

$s = CollapseBlank $s
[System.IO.File]::WriteAllText($p, $s, $utf8)
Write-Output "WROTE HnsMatchSystem.sma"

# ---- globals.inc ----
$gp = Join-Path $Dir 'include\hns-match\globals.inc'
$g = [System.IO.File]::ReadAllText($gp, [System.Text.Encoding]::UTF8)
$gFrom = "new bool:g_bKnifeViewModel[MAX_PLAYERS + 1];  // 每个玩家是否显示刀模型（true=显示, false=隐藏）`r`n// ★ 主动摔伤检测: 记录上一帧是否落地 (FL_ONGROUND), 用于捕捉`"落地瞬间`"计算摔伤`r`nnew bool:g_bPrevOnGround[MAX_PLAYERS + 1];`r`n// ★ 主动摔伤检测: 上一帧的 Z 坐标, 用于在`"虚体(SOLID_NOT)`"下用位置变化可靠判定落地`r`n//   (虚体时 FL_ONGROUND 不更新, 须改为追踪是否从`"持续下降`"转为`"稳定`"来判断落地)`r`nnew Float:g_fPrevZ[MAX_PLAYERS + 1];`r`nnew Float:g_fClimbVel[MAX_PLAYERS + 1];  // 追踪最近一次`"下落`"的垂直速度峰值`r`nnew bool:g_bWasFalling[MAX_PLAYERS + 1]; // 上一帧是否处于下落"
$gTo  = "new bool:g_bKnifeViewModel[MAX_PLAYERS + 1];  // 每个玩家是否显示刀模型（true=显示, false=隐藏）"
if($g.Contains($gFrom)){ $g = $g.Replace($gFrom, $gTo); Write-Output "OK globals var cleanup" } else { Write-Output "MISS globals var block" }

$tFrom = "// 观察者模式初始化延迟任务 (jointeam 6 后延迟设置 iuser1/iuser2, 避免被引擎覆盖)`r`n#define TASK_SPEC_INIT 13343`r`n// ★ 主动摔伤检测循环任务 (解决`"打几把后 T 摔落不掉血`")`r`n#define TASK_FALLDMG_CHECK 13346"
$tTo   = "// 观察者模式初始化延迟任务 (jointeam 6 后延迟设置 iuser1/iuser2, 避免被引擎覆盖)`r`n#define TASK_SPEC_INIT 13343"
if($g.Contains($tFrom)){ $g = $g.Replace($tFrom, $tTo); Write-Output "OK globals TASK define cleanup" } else { Write-Output "MISS globals TASK define" }

$g = CollapseBlank $g
[System.IO.File]::WriteAllText($gp, $g, $utf8)
Write-Output "WROTE globals.inc"
Write-Output "ALL DONE"

$p = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma'
$enc = New-Object System.Text.UTF8Encoding $false
$text = $enc.GetString([System.IO.File]::ReadAllBytes($p))

function ReplaceBetween([string]$src, [string]$startMark, [string]$endMark, [string]$replacement, [bool]$keepEnd) {
    $a = $src.IndexOf($startMark)
    if ($a -lt 0) { throw "start not found: $startMark" }
    $b = $src.IndexOf($endMark, $a)
    if ($b -lt 0) { throw "end not found: $endMark" }
    if ($keepEnd) {
        return $src.Substring(0, $a) + $replacement + $src.Substring($b)
    }
    return $src.Substring(0, $a) + $replacement + $src.Substring($b + $endMark.Length)
}

$block1 = @'
	if (g_bForceStart) {
		if (iSize < 1)
			iSize = 1;
	} else if (iSize < 3) {
		iSize = 3;
	}

	return iSize;
}

stock bool:isFakeOrBot(id) {
	if (!is_user_connected(id))
		return false;
	if (is_user_bot(id))
		return true;
	if (get_entvar(id, var_flags) & FL_FAKECLIENT)
		return true;

	new szAuth[32];
	get_user_authid(id, szAuth, charsmax(szAuth));
	if (containi(szAuth, "BOT") != -1)
		return true;
	return false;
}

stock bool:isUserVipOrAdmin(id) {
	if (!is_user_connected(id) || isFakeOrBot(id))
		return false;

	return isUserWatcher(id) || isUserAdmin(id) || is_user_admin(id);
}

stock bool:isAdminOnline() {
	for (new i = 1; i <= MaxClients; i++) {
		if (isUserVipOrAdmin(i))
			return true;
	}
	return false;
}

stock getFirstVipOrAdmin() {
	for (new i = 1; i <= MaxClients; i++) {
		if (isUserVipOrAdmin(i))
			return i;
	}
	return 0;
}

stock bool:showSetupToAdmins() {
	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		showSetupMenu(i);
		bShown = true;
	}
	return bShown;
}

'@

$text = ReplaceBetween $text "	if (g_bForceStart) {`r`n		if (iSize < 1)" "`r`n// 已投票人数" ($block1 + "`r`n// 已投票人数") $true
if ($text.IndexOf("`r`n// 已投票人数") -lt 0) {
    $text = $enc.GetString([System.IO.File]::ReadAllBytes($p))
    $text = ReplaceBetween $text "	if (g_bForceStart) {`n		if (iSize < 1)" "`n// 已投票人数" ($block1.Replace("`r`n","`n") + "`n// 已投票人数") $true
}

$block2 = @'
	if (!isUserVipOrAdmin(id)) {
		showMainMenu(id);
		return PLUGIN_HANDLED;
	}

	g_bSponsorMatch = bool:equal(data, "sponsor");
	if (g_bSponsorMatch) {
		for (new i = g_iSignupCount - 1; i >= 0; i--) {
			new p = g_iSignupList[i];
			if (isGuestPlayer(p)) {
				g_bSignedUp[p] = false;
				g_iSignupTeam[p] = 0;
				g_iSignupList[i] = g_iSignupList[--g_iSignupCount];
				ai_print(p, "已从报名中移除: 盗版玩家不能参与赞助局");
			}
		}
	}

	ai_print(0, "AI 报名比赛类型已设为: ^3%s^1", g_bSponsorMatch ? "赞助局" : "娱乐局");
	broadcastStatus();
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showSetupMenu(id) {
	if (!is_user_connected(id) || !isUserVipOrAdmin(id) || !g_bPostGroupSetup)
		return;

	new szTitle[64], szRule[32];
	ai_ruleName(id, _:g_iMatchRules, szRule, charsmax(szRule));
	formatex(szTitle, charsmax(szTitle), "\r赛前设置 \y[模式: %s]", szRule);

	new menu = menu_create(szTitle, "SetupMenuHandler");
	menu_additem(menu, "选择比赛模式", "rules");
	menu_additem(menu, "选择地图", "map");
	menu_setprop(menu, MPROP_EXITNAME, "关闭");
	menu_display(id, menu);
}

public SetupMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	menu_destroy(menu);

	if (!isUserVipOrAdmin(id) || !g_bPostGroupSetup)
		return PLUGIN_HANDLED;

	if (equal(data, "map"))
		beginMapSelect();
	else
		showRulesMenu(id);
	return PLUGIN_HANDLED;
}

public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;

	ai_print(0, "分组完成, 先选择比赛模式, 再选择地图");
	showGroups(0);

	if (showSetupToAdmins()) {
		ai_print(0, "管理员/VIP 优先选择比赛模式 (聊天输入 /signup 可重新打开)");
		return;
	}

	startRulesVote(0, -1);
}

public beginMapSelect() {
	if (!g_bPostGroupSetup) {
		startMatch();
		return;
	}

	if (g_iSkillMapCount <= 0 && g_iBoostMapCount <= 0)
		loadMapPools();

	if (!isSkillOrTimerRules()) {
		setActivePool(POOL_BOOST);
		ai_print(0, "%s 使用 Boost 地图池, 请选择随机 / 投票 / 指定地图", g_szRules[_:g_iMatchRules]);
		offerMapChoice();
		return;
	}

	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		showPoolChoiceMenu(i);
		bShown = true;
	}
	if (bShown) {
		ai_print(0, "管理员/VIP 优先选择地图池 (Skill / Boost)");
		return;
	}

	startPoolVote();
}

stock offerMapChoice() {
	new bool:bShown;
	for (new i = 1; i <= MaxClients; i++) {
		if (!isUserVipOrAdmin(i))
			continue;
		showMapChoiceMenu(i);
		bShown = true;
	}
	if (bShown)
		return;

	startMapVote();
}

'@

$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
if ($nl -eq "`n") { $block2 = $block2.Replace("`r`n", "`n") }

$start2 = "	if (!isUserVipOrAdmin(id)) {" + $nl + "		showMainMenu(id);" + $nl + "		return PLUGIN_HANDLED;" + $nl + "	}"
# unique enough near TypeMenuHandler broken region: after TypeMenuHandler's isUserVipOrAdmin check
$idxType = $text.IndexOf("public TypeMenuHandler")
if ($idxType -lt 0) { throw 'TypeMenuHandler missing' }
$a = $text.IndexOf($start2, $idxType)
if ($a -lt 0) { throw 'type handler start not found' }
$end2 = "public showPoolChoiceMenu(id) {"
$b = $text.IndexOf($end2, $a)
if ($b -lt 0) { throw 'showPoolChoiceMenu not found' }
$text = $text.Substring(0, $a) + $block2 + $text.Substring($b)

$bad = @('g_szbool:bShown','bShownserVipOrAdmin','return;blic','showSetupMenu(id) {')
# last one is ok if preceded by public
if ($text.Contains('g_szbool:bShown')) { throw 'still g_szbool' }
if ($text.Contains('bShownserVipOrAdmin')) { throw 'still broken return' }
if ($text.Contains('return;blic')) { throw 'still return;blic' }
if ($text.Contains("`nshowSetupMenu(id)")) { throw 'still missing public showSetupMenu' }
if ($text.IndexOf('stock bool:isFakeOrBot') -lt 0) { throw 'missing isFakeOrBot' }
if ($text.IndexOf('public showSetupMenu') -lt 0) { throw 'missing public showSetupMenu' }
if ($text.IndexOf('return iSize;') -lt 0) { throw 'missing return iSize' }

# duplicate offerMapChoice / beginPostGroupSetup check
$c1 = ([regex]::Matches($text, 'public beginPostGroupSetup\(\)')).Count
$c2 = ([regex]::Matches($text, 'stock offerMapChoice\(\)')).Count
$c3 = ([regex]::Matches($text, 'public beginMapSelect\(\)')).Count
Write-Host "beginPostGroupSetup=$c1 offerMapChoice=$c2 beginMapSelect=$c3"
if ($c1 -ne 1 -or $c2 -ne 1 -or $c3 -ne 1) { throw 'duplicate or missing functions' }

[System.IO.File]::WriteAllText($p, $text, $enc)
Write-Host 'repaired ok'

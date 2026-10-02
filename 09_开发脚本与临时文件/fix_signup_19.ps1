$ErrorActionPreference = 'Stop'
$p = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma'
$bak = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma.bak_before_19'
Copy-Item -LiteralPath $p -Destination $bak -Force

$utf8 = New-Object System.Text.UTF8Encoding $false
$text = $utf8.GetString([System.IO.File]::ReadAllBytes($p))

function Replace-Exact([string]$old, [string]$new, [string]$label) {
    $idx = $text.IndexOf($old)
    if ($idx -lt 0) {
        Write-Host "FAIL missing: $label"
        throw "missing $label"
    }
    $count = 0
    $search = 0
    while (($pos = $text.IndexOf($old, $search)) -ge 0) {
        $count++
        $search = $pos + $old.Length
    }
    if ($count -ne 1) {
        Write-Host "FAIL count=$count : $label"
        throw "count $label"
    }
    $script:text = $text.Remove($idx, $old.Length).Insert($idx, $new)
    Write-Host "OK $label"
}

$old1 = @'
public taskPendingResume() {
	rebuildSignupFromOnline();
	if (g_iSignupCount < 1) {
		ai_print(0, "换图后没有在线玩家, 取消开赛");
		g_bPendingMatchStart = false;
		g_bForceStart = false;
		g_eState = SIGNUP_IDLE;
		return;
	}CLOSE;
	a

	g_eState = SIGNUP_CLOSE;
	ai_print(0, "人齐, 全员观战, 按换图前分组一个一个上场 (^3%d^1 人)", g_iSignupCount);
	specEveryoneNow();
	if (!g_bKeepSavedTeams)
		shuffleTeamsNow();
	g_bKeepSavedTeams = false;
	buildPlaceQueue(g_iPlaceTeamSize);
	showGroups(0);
	startPlacingOneByOne

stock rebuildSignupFromOnline() {
'@

$new1 = @'
public taskPendingResume() {
	rebuildSignupFromOnline();
	if (g_iSignupCount < 1) {
		ai_print(0, "换图后没有在线玩家, 取消开赛");
		g_bPendingMatchStart = false;
		g_bForceStart = false;
		g_eState = SIGNUP_IDLE;
		return;
	}

	g_bForceStart = true;
	g_eState = SIGNUP_CLOSE;
	ai_print(0, "人齐, 全员观战, 按换图前分组一个一个上场 (^3%d^1 人)", g_iSignupCount);
	specEveryoneNow();
	if (!g_bKeepSavedTeams)
		shuffleTeamsNow();
	g_bKeepSavedTeams = false;
	buildPlaceQueue(g_iPlaceTeamSize);
	showGroups(0);
	startPlacingOneByOne();
}

stock rebuildSignupFromOnline() {
'@

$old2 = @'
	return PLUGIN_HANDLED;
}换图前不拉


public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;
	g_iSetupMenuTries = 0;

	ai_print(0, "分组完成, 换图前不拉天输入 /signup 重新打开");
	showGroups(0);
'@

$new2 = @'
	return PLUGIN_HANDLED;
}

public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;
	g_iSetupMenuTries = 0;

	ai_print(0, "分组完成, 换图前不拉观战, 先选择比赛模式, 再选择地图");
	ai_print(0, "如果没看到菜单, 聊天输入 /signup 重新打开");
	showGroups(0);
'@

$old3 = @'
public taskSignupHud() {
	if (g_eState == SIGNUP_CLOSE) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			if (g_bPendingMatchStart || g_iPlaceIndex > 0)
			set_hudmessage(0, 255, 0, 0.02, 0.28, 0, 0.0, 1.1, 0.0, 0.0, -1);
			if (g_bPendingMatchStart || g_iPlaceIndex > 0)
				show_hudmessage(iPlayers[i], "换图后按分组上场 %d/%d ...", g_iPlaceIndex, g_iPlaceTotal);
			else
			}
		return;
	}
'@

$new3 = @'
public taskSignupHud() {
	if (g_eState == SIGNUP_CLOSE) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			set_hudmessage(0, 255, 0, 0.02, 0.28, 0, 0.0, 1.1, 0.0, 0.0, -1);
			if (g_bPendingMatchStart || g_iPlaceIndex > 0)
				show_hudmessage(iPlayers[i], "换图后按分组上场 %d/%d ...", g_iPlaceIndex, g_iPlaceTotal);
			else
				show_hudmessage(iPlayers[i], "正在分配队伍, 请稍候...");
		}
		return;
	}
'@

Replace-Exact $old1 $new1 'taskPendingResume'
Replace-Exact $old2 $new2 'beginPostGroupSetup'
Replace-Exact $old3 $new3 'taskSignupHud'

# leftover junk checks
foreach ($n in @('}CLOSE','换图前不拉天','startPlacingOneByOne`nstock','}换图前不拉')) {
    if ($text.Contains($n)) { Write-Host "STILL HAS $n" } else { Write-Host "clean $n" }
}

[System.IO.File]::WriteAllBytes($p, $utf8.GetBytes($text))
Write-Host "wrote $($utf8.GetByteCount($text)) bytes"

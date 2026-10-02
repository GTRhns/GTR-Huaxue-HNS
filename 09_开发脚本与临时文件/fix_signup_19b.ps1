$ErrorActionPreference = 'Stop'
$p = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma'
$bak = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma.bak_before_19'
if (-not (Test-Path $bak)) {
    Copy-Item -LiteralPath $p -Destination $bak -Force
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$text = $utf8.GetString([System.IO.File]::ReadAllBytes($p))

function Replace-Between([string]$startNeedle, [string]$endNeedle, [string]$newBody, [string]$label, [bool]$keepEnd = $true) {
    $s = $text.IndexOf($startNeedle)
    if ($s -lt 0) { throw "missing start $label" }
    $e = $text.IndexOf($endNeedle, $s + $startNeedle.Length)
    if ($e -lt 0) { throw "missing end $label" }
    $endLen = if ($keepEnd) { 0 } else { $endNeedle.Length }
    $oldLen = ($e + $endLen) - $s
    $script:text = $text.Remove($s, $oldLen).Insert($s, $newBody)
    Write-Host "OK $label oldLen=$oldLen newLen=$($newBody.Length)"
}

$resume = @"
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

"@

$setup = @"
public beginPostGroupSetup() {
	g_eState = SIGNUP_SETUP;
	g_bPostGroupSetup = true;
	g_szPickedMap[0] = EOS;
	g_iSetupMenuTries = 0;

	ai_print(0, "分组完成, 换图前不拉观战, 先选择比赛模式, 再选择地图");
	ai_print(0, "如果没看到菜单, 聊天输入 /signup 重新打开");
	showGroups(0);

	showSetupToAdmins();
	remove_task(TASK_SETUP_MENU);
	set_task(0.15, "taskShowPostGroupMenus", TASK_SETUP_MENU);
}

"@

$hudClose = @"
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

"@

# 1) taskPendingResume through start of rebuildSignupFromOnline
Replace-Between "public taskPendingResume() {" "`nstock rebuildSignupFromOnline() {" ($resume + "stock rebuildSignupFromOnline() {") "taskPendingResume" $false

# 2) junk before beginPostGroupSetup + the function itself
$junk = $text.IndexOf("}换图前不拉")
if ($junk -ge 0) {
    $script:text = $text.Remove($junk, 1).Insert($junk, "}")  # keep closing brace of previous function, drop junk later via function replace
}

# Remove leftover junk token if still present
$script:text = $text.Replace("}换图前不拉", "}")

Replace-Between "public beginPostGroupSetup() {" "`npublic taskShowPostGroupMenus() {" ($setup + "public taskShowPostGroupMenus() {") "beginPostGroupSetup" $false

# 3) SIGNUP_CLOSE HUD block
Replace-Between "public taskSignupHud() {" "`nif (g_eState == SIGNUP_SETUP) {" ($hudClose + "if (g_eState == SIGNUP_SETUP) {") "taskSignupHud" $false

# leftover junk checks
foreach ($n in @('}CLOSE','换图前不拉天','}换图前不拉','startPlacingOneByOne`r`nstock','startPlacingOneByOne`nstock')) {
    if ($text.Contains($n)) { Write-Host "STILL HAS [$n]" } else { Write-Host "clean [$n]" }
}

# extra: if startPlacingOneByOne is not followed by (); then stock
$i = $text.IndexOf('startPlacingOneByOne')
while ($i -ge 0) {
    $after = $text.Substring($i, [Math]::Min(40, $text.Length-$i))
    Write-Host ("OCCUR startPlacingOneByOne => " + ($after -replace "`r","\\r" -replace "`n","\\n"))
    $i = $text.IndexOf('startPlacingOneByOne', $i+1)
}

[System.IO.File]::WriteAllBytes($p, $utf8.GetBytes($text))
Write-Host "wrote $($utf8.GetByteCount($text)) bytes"

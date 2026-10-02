$ErrorActionPreference = "Stop"
$root = "c:\Users\Administrator\Desktop\gtr"
$src = Join-Path $root "source\HnsAISignup.sma"
$bak = Join-Path $root "source\HnsAISignup.sma.bak_before_fix2"
$enc = New-Object System.Text.UTF8Encoding $false

Copy-Item -LiteralPath $bak -Destination $src -Force
$text = $enc.GetString([System.IO.File]::ReadAllBytes($src))
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
Write-Host ("restored_len=" + $text.Length + " nl=" + ($(if ($nl -eq "`r`n") {"CRLF"} else {"LF"})))

function Normalize-Newlines([string]$s, [string]$targetNl) {
    $s = $s.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($targetNl -eq "`r`n") { $s = $s.Replace("`n", "`r`n") }
    return $s
}

function Replace-Between([string]$text, [string]$startMark, [string]$endMark, [string]$block, [string]$label) {
    $a = $text.IndexOf($startMark)
    $b = $text.IndexOf($endMark, [Math]::Max($a, 0))
    Write-Host ($label + " a=" + $a + " b=" + $b)
    if ($a -lt 0 -or $b -lt 0 -or $b -le $a) { throw ($label + " markers failed") }
    $block = Normalize-Newlines $block $nl
    if (-not $block.EndsWith($nl)) { $block += $nl }
    return $text.Substring(0, $a) + $block + $text.Substring($b)
}

function Replace-Once([string]$text, [string]$old, [string]$new, [string]$label) {
    $old = Normalize-Newlines $old $nl
    $a = $text.IndexOf($old)
    if ($a -lt 0) { throw ($label + " old not found") }
    $b = $text.IndexOf($old, $a + 1)
    if ($b -ge 0) { throw ($label + " old found more than once") }
    Write-Host ($label + " a=" + $a)
    return $text.Substring(0, $a) + (Normalize-Newlines $new $nl) + $text.Substring($a + $old.Length)
}

function Replace-AllExact([string]$text, [string]$old, [string]$new, [int]$expect, [string]$label) {
    $old = Normalize-Newlines $old $nl
    $new = Normalize-Newlines $new $nl
    $count = 0
    $idx = 0
    while (($idx = $text.IndexOf($old, $idx)) -ge 0) {
        $count++
        $idx += $old.Length
    }
    Write-Host ($label + " count=" + $count)
    if ($count -ne $expect) { throw ($label + " expected " + $expect + " got " + $count) }
    return $text.Replace($old, $new)
}

$text = Replace-Once $text '#define PLUGIN_VERSION "1.5"' '#define PLUGIN_VERSION "1.6"' "version"
$text = Replace-Once $text "#define TASK_MAP_WAIT      92007" "#define TASK_MAP_WAIT      92007`n#define TASK_SETUP_MENU    92008" "task_define"
$text = Replace-Once $text "new bool:g_bKeepSavedTeams;" "new bool:g_bKeepSavedTeams;`nnew g_iSetupMenuTries;" "setup_tries"

$cmdOld = @"
	if (g_eState == SIGNUP_SETUP) {
		if (isUserVipOrAdmin(id)) {
			showSetupMenu(id);
			return PLUGIN_HANDLED;
		}
		ai_print(id, "正在选择比赛模式/地图, 请稍候");
		return PLUGIN_HANDLED;
	}
"@
$cmdNew = [System.IO.File]::ReadAllText((Join-Path $root "_tmp\block_cmdsetup.sma"), $enc).TrimEnd()
$text = Replace-Once $text $cmdOld $cmdNew "cmd_setup"

$text = Replace-AllExact $text "	remove_task(TASK_MAP_WAIT);" "	remove_task(TASK_MAP_WAIT);`n	remove_task(TASK_SETUP_MENU);" 2 "remove_setup_task"

$post = [System.IO.File]::ReadAllText((Join-Path $root "_tmp\block_postgroup.sma"), $enc)
$text = Replace-Between $text "public beginPostGroupSetup() {" "public showPoolChoiceMenu(id) {" $post "postgroup"

$hud = [System.IO.File]::ReadAllText((Join-Path $root "_tmp\block_hudsetup.sma"), $enc)
$text = Replace-Between $text "public taskSignupHud() {" "public showTypeMenu(id) {" $hud "hud"

$move = [System.IO.File]::ReadAllText((Join-Path $root "_tmp\block_moveteam.sma"), $enc)
$text = Replace-Between $text "stock moveToSpec(id) {" "stock getEffectiveTeamSize() {" $move "moveteam"

function Count-Pat([string]$pat) { return ([regex]::Matches($text, $pat)).Count }
$names = @(
    "public beginPostGroupSetup\(\)",
    "public taskShowPostGroupMenus\(\)",
    "stock offerMapChoice\(\)",
    "public beginMapSelect\(\)",
    "stock closeGameMenu\(",
    "stock reopenActiveVoteMenu\(",
    "stock bool:showSetupToAdmins\(",
    "public showSetupMenu\(",
    "public showPoolChoiceMenu\(",
    "stock getEffectiveTeamSize\(\)",
    "public taskSignupHud\(\)",
    "stock moveToSpec\(",
    "stock moveToTeam\("
)
foreach ($pat in $names) {
    $n = Count-Pat $pat
    Write-Host ($pat + "=" + $n)
    if ($n -ne 1) { throw ("count fail " + $pat + "=" + $n) }
}
foreach ($bad in @("g_szbool:bShown", "bShownserVipOrAdmin", "return;blic", "g_szbool")) {
    if ($text.Contains($bad)) { throw ("broken marker still present: " + $bad) }
}
if ($text.IndexOf("#define TASK_SETUP_MENU    92008") -lt 0) { throw "missing TASK_SETUP_MENU" }
if ($text.IndexOf("new g_iSetupMenuTries;") -lt 0) { throw "missing g_iSetupMenuTries" }
if (([regex]::Matches($text, "remove_task\(TASK_SETUP_MENU\)")).Count -lt 3) { throw "missing remove_task SETUP" }
if ($text.IndexOf('PLUGIN_VERSION "1.6"') -lt 0) { throw "version not 1.6" }
if ($text.IndexOf("聊天输入 /signup 重新打开") -lt 0) { throw "missing reopen hint" }

[System.IO.File]::WriteAllText($src, $text, $enc)
Write-Host ("patched ok len=" + $text.Length)

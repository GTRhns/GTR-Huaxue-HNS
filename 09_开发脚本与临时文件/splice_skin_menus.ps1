$ErrorActionPreference = 'Stop'
$src = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$fix = 'c:\Users\Administrator\Desktop\gtr\_tmp\skin_menus_fix.sma'
$bak = 'c:\Users\Administrator\Desktop\gtr\_tmp\HnsMatchSkin.sma.i18n.bak'
$log = 'c:\Users\Administrator\Desktop\gtr\_tmp\splice_log.txt'

$t = [System.IO.File]::ReadAllText($src)
$mid = [System.IO.File]::ReadAllText($fix)
# normalize fix to CRLF
$mid = $mid -replace "`r`n", "`n"
$mid = $mid -replace "`n", "`r`n"
if (-not $mid.EndsWith("`r`n")) { $mid += "`r`n" }

$marker = "`tSkinMenuReturn(id, menu);`r`n`tmenuszTitle"
$start = $t.IndexOf($marker)
if ($start -lt 0) { throw "start marker not found" }

$end = $t.IndexOf("public plugin_natives()", $start)
if ($end -lt 0) { throw "end marker not found" }

$tailPrefix = @"
/* ============================================================
   事件 / 菜单回调 (public)
   ============================================================ */
"@
$tailPrefix = $tailPrefix -replace "`n", "`r`n"
if (-not $tailPrefix.EndsWith("`r`n")) { $tailPrefix += "`r`n" }

Copy-Item -LiteralPath $src -Destination $bak -Force
$new = $t.Substring(0, $start) + $mid.TrimEnd("`r", "`n") + "`r`n`r`n" + $tailPrefix + $t.Substring($end)
[System.IO.File]::WriteAllText($src, $new, (New-Object System.Text.UTF8Encoding $false))

$lines = @(
  "start=$start"
  "end=$end"
  "oldLen=$($t.Length)"
  "newLen=$($new.Length)"
  "midLen=$($mid.Length)"
  "hasMenuszTitle=$($new.Contains('menuszTitle'))"
  "hasMenuGold=$($new.Contains('MenuGold(id) {'))"
  "hasMenuConfirmUpgrade=$($new.Contains('MenuConfirmUpgrade(id, idx)'))"
  "hasCurMatch=$($new.Contains('bool:cur_match(target, const key[], teamChar)'))"
  "dupSqlCount=$(([regex]::Matches($new, 'SqlCountMine\(id\) \{')).Count)"
  "dupMenuAdmin=$(([regex]::Matches($new, 'MenuAdmin\(id\) \{')).Count)"
  "dupPool=$(([regex]::Matches($new, 'PoolTeamChar\(idx\) \{')).Count)"
)
[System.IO.File]::WriteAllLines($log, $lines)
Write-Output "ok"

$ErrorActionPreference = "Stop"
$root = "c:\Users\Administrator\Desktop\gtr"
$p = Join-Path $root "source\HnsAISignup.sma"
$enc = New-Object System.Text.UTF8Encoding $false
$text = $enc.GetString([System.IO.File]::ReadAllBytes($p))
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
Write-Host ("sma_len=" + $text.Length + " nl=" + ($(if ($nl -eq "`r`n") {"CRLF"} else {"LF"})))

function Normalize-Newlines([string]$s, [string]$targetNl) {
    $s = $s.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($targetNl -eq "`r`n") { $s = $s.Replace("`n", "`r`n") }
    return $s
}

$block1 = Normalize-Newlines ([System.IO.File]::ReadAllText((Join-Path $root "_tmp\block_admin1.sma"), $enc)) $nl
$block2 = Normalize-Newlines ([System.IO.File]::ReadAllText((Join-Path $root "_tmp\block_admin2.sma"), $enc)) $nl
if (-not $block1.EndsWith($nl)) { $block1 += $nl }
if (-not $block2.EndsWith($nl)) { $block2 += $nl }

$start1 = "stock getEffectiveTeamSize() {"
$end1 = "stock countVoted() {"
$a = $text.IndexOf($start1)
$b = $text.IndexOf($end1, [Math]::Max($a,0))
Write-Host ("block1 a=" + $a + " b=" + $b)
if ($a -lt 0 -or $b -lt 0 -or $b -le $a) { throw "block1 markers failed" }
$text = $text.Substring(0, $a) + $block1 + $text.Substring($b)

$start2 = "public TypeMenuHandler(id, menu, item) {"
$end2 = "public showPoolChoiceMenu(id) {"
$a = $text.IndexOf($start2)
$b = $text.IndexOf($end2, [Math]::Max($a,0))
Write-Host ("block2 a=" + $a + " b=" + $b)
if ($a -lt 0 -or $b -lt 0 -or $b -le $a) { throw "block2 markers failed" }
$text = $text.Substring(0, $a) + $block2 + $text.Substring($b)

function Count-Pat([string]$pat) { return ([regex]::Matches($text, $pat)).Count }
$c = @{
  beginPostGroupSetup = (Count-Pat "public beginPostGroupSetup\(\)")
  offerMapChoice = (Count-Pat "stock offerMapChoice\(\)")
  beginMapSelect = (Count-Pat "public beginMapSelect\(\)")
  isFakeOrBot = (Count-Pat "stock bool:isFakeOrBot\(")
  showSetupMenu = (Count-Pat "public showSetupMenu\(")
  getEffectiveTeamSize = (Count-Pat "stock getEffectiveTeamSize\(\)")
  TypeMenuHandler = (Count-Pat "public TypeMenuHandler\(")
  showPoolChoiceMenu = (Count-Pat "public showPoolChoiceMenu\(")
  countVoted = (Count-Pat "stock countVoted\(\)")
}
$c.GetEnumerator() | ForEach-Object { Write-Host ($_.Key + "=" + $_.Value) }

foreach ($k in @("beginPostGroupSetup","offerMapChoice","beginMapSelect","isFakeOrBot","showSetupMenu","getEffectiveTeamSize","TypeMenuHandler","showPoolChoiceMenu","countVoted")) {
    if ($c[$k] -ne 1) { throw ("count fail " + $k + "=" + $c[$k]) }
}
foreach ($bad in @("g_szbool:bShown","bShownserVipOrAdmin","return;blic")) {
    if ($text.Contains($bad)) { throw ("broken marker still present: " + $bad) }
}
if ($text.Contains("showSetupMenu(id) {") -and -not $text.Contains("public showSetupMenu(id) {")) {
    throw "showSetupMenu missing public"
}
if ($text.IndexOf("return iSize;") -lt 0) { throw "missing return iSize" }

[System.IO.File]::WriteAllText($p, $text, $enc)
Write-Host "repaired ok"
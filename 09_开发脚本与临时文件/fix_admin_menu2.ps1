$ErrorActionPreference = "Stop"
$root = "c:\Users\Administrator\Desktop\gtr"
$p = Join-Path $root "source\HnsAISignup.sma"
$enc = New-Object System.Text.UTF8Encoding $false
$text = $enc.GetString([System.IO.File]::ReadAllBytes($p))
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

function Get-Block([string]$file) {
    $raw = [System.IO.File]::ReadAllText($file, $enc)
    if ($nl -eq "`n") { $raw = $raw.Replace("`r`n", "`n") }
    else { $raw = $raw.Replace("`n", "`r`n").Replace("`r`r`n", "`r`n") }
    return $raw
}

$block1 = Get-Block (Join-Path $root "_tmp\block_admin1.sma")
$block2 = Get-Block (Join-Path $root "_tmp\block_admin2.sma")

$start1 = "stock getEffectiveTeamSize() {"
$end1 = "stock countVoted() {"
$a = $text.IndexOf($start1)
if ($a -lt 0) { throw "getEffectiveTeamSize not found" }
$b = $text.IndexOf($end1, $a)
if ($b -lt 0) { throw "countVoted not found" }
$text = $text.Substring(0, $a) + $block1 + $text.Substring($b)

$start2 = "public TypeMenuHandler(id, menu, item) {"
$end2 = "public showPoolChoiceMenu(id) {"
$a = $text.IndexOf($start2)
if ($a -lt 0) { throw "TypeMenuHandler not found" }
$b = $text.IndexOf($end2, $a)
if ($b -lt 0) { throw "showPoolChoiceMenu not found" }
$text = $text.Substring(0, $a) + $block2 + $text.Substring($b)

$c1 = ([regex]::Matches($text, "public beginPostGroupSetup\(\)")).Count
$c2 = ([regex]::Matches($text, "stock offerMapChoice\(\)")).Count
$c3 = ([regex]::Matches($text, "public beginMapSelect\(\)")).Count
$c4 = ([regex]::Matches($text, "stock bool:isFakeOrBot\(")).Count
$c5 = ([regex]::Matches($text, "public showSetupMenu\(")).Count
$c6 = ([regex]::Matches($text, "stock getEffectiveTeamSize\(\)")).Count
Write-Host "beginPostGroupSetup=$c1 offerMapChoice=$c2 beginMapSelect=$c3 isFakeOrBot=$c4 showSetupMenu=$c5 getEffectiveTeamSize=$c6"
if ($c1 -ne 1 -or $c2 -ne 1 -or $c3 -ne 1 -or $c4 -ne 1 -or $c5 -ne 1 -or $c6 -ne 1) {
    throw "duplicate or missing functions after repair"
}
if ($text.Contains("g_szbool:bShown") -or $text.Contains("bShownserVipOrAdmin") -or $text.Contains("return;blic")) {
    throw "broken markers still present"
}

[System.IO.File]::WriteAllText($p, $text, $enc)
Write-Host "repaired ok"

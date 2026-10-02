$p = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$t = [System.IO.File]::ReadAllText($p)
$marker1 = '// 裸区块头'
$marker2 = '/* 把 "[TT]"'
$start = $t.IndexOf($marker1)
$end = $t.IndexOf($marker2)
Write-Output ("start=$start end=$end len=$($t.Length)")
if ($start -ge 0 -and $end -gt $start) {
  $block = $t.Substring($start, $end - $start)
  [System.IO.File]::WriteAllText('c:\Users\Administrator\Desktop\gtr\_tmp\broken_import.txt', $block)
  Write-Output ("block_len=" + $block.Length)
}

$p = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$lines = [System.IO.File]::ReadAllLines($p)
Write-Output ("linecount=" + $lines.Length)
for ($i=0; $i -lt $lines.Length; $i++) {
  if ($lines[$i] -like '*裸区块头*') { Write-Output ("bare=$($i+1) $($lines[$i])") }
  if ($lines[$i] -like '*把 "[TT]"*') { Write-Output ("trim=$($i+1) $($lines[$i])") }
  if ($lines[$i] -like '*ifif*') { Write-Output ("ifif=$($i+1) $($lines[$i])") }
}

$p = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$enc = New-Object System.Text.UTF8Encoding $false
$lines = [System.IO.File]::ReadAllLines($p, $enc)
Write-Output ("linecount=" + $lines.Length)
for ($i=420; $i -le 490; $i++) {
  Write-Output ("{0,4}|{1}" -f ($i+1), $lines[$i])
}

$p = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$blockPath = 'c:\Users\Administrator\Desktop\gtr\_tmp\skin_import_block.txt'
$enc = New-Object System.Text.UTF8Encoding $false
$lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($p, $enc))
$replacement = [System.IO.File]::ReadAllLines($blockPath, $enc)
$lines.RemoveRange(425, 54)
$lines.InsertRange(425, $replacement)
[System.IO.File]::WriteAllLines($p, $lines, $enc)
Write-Output ('new_linecount=' + $lines.Count)
Write-Output $lines[425]
Write-Output $lines[426]
Write-Output $lines[447]
Write-Output $lines[478]

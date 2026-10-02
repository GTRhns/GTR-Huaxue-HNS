$ErrorActionPreference = 'Stop'
$langFile = 'c:\Users\Administrator\Desktop\gtr\cstrike\addons\amxmodx\configs\hns_language.txt'
$bak = 'c:\Users\Administrator\Desktop\gtr\_tmp\hns_language.txt.i18n.bak'
Copy-Item -LiteralPath $langFile -Destination $bak -Force

$text = [System.IO.File]::ReadAllText($langFile)
if ($text.Contains('SKIN_CHAT_PREFIX')) { throw 'SKIN keys already present' }

function Insert-Before([string]$src, [string]$marker, [string]$blockFile) {
    $idx = $src.IndexOf($marker)
    if ($idx -lt 0) { throw "marker not found: $marker" }
    $block = [System.IO.File]::ReadAllText($blockFile).TrimEnd("`r", "`n") + "`r`n`r`n"
    return $src.Substring(0, $idx) + $block + $src.Substring($idx)
}

$text = Insert-Before $text "`r`n[tw]`r`n" 'c:\Users\Administrator\Desktop\gtr\_tmp\skin_lang_cn.txt'
$text = Insert-Before $text "`r`n[en]`r`n" 'c:\Users\Administrator\Desktop\gtr\_tmp\skin_lang_tw.txt'
$text = Insert-Before $text "`r`n[ru]`r`n" 'c:\Users\Administrator\Desktop\gtr\_tmp\skin_lang_en.txt'

$ru = [System.IO.File]::ReadAllText('c:\Users\Administrator\Desktop\gtr\_tmp\skin_lang_ru.txt').TrimEnd("`r", "`n")
if (-not $text.EndsWith("`n")) { $text += "`r`n" }
$text += "`r`n" + $ru + "`r`n"

[System.IO.File]::WriteAllText($langFile, $text, (New-Object System.Text.UTF8Encoding $false))
Write-Output 'lang inserted'

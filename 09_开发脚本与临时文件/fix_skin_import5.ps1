$p = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$enc = New-Object System.Text.UTF8Encoding $false
$lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($p, $enc))

$replacement = @(
	"`t`t// 裸区块头 tt / t / ct (单独一行, 不带方括号)",
	"`t`tif ((equali(szHead, `"tt`") || equali(szHead, `"t`") || equali(szHead, `"ct`")) && !szRestA[0]) {",
	"`t`t`tif (bPending) {",
	"`t`t`t`tif (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))",
	"`t`t`t`t`tiImported++;",
	"`t`t`t`telse",
	"`t`t`t`t`tiSkipped++;",
	"`t`t`t}",
	"`t`t`tif (equali(szHead, `"tt`") || equali(szHead, `"t`")) sTeam[0] = TEAM_CHAR_T;",
	"`t`t`telse sTeam[0] = TEAM_CHAR_C;",
	"`t`t`tbPending = false;",
	"`t`t`tcontinue;",
	"`t`t}",
	"",
	"`t`t// 音效行: 以 wav 开头, 属于上一款",
	"`t`tif (equali(szHead, `"wav`")) {",
	"`t`t`tcopy(sWav, charsmax(sWav), szRestA);",
	"`t`t`ttrim(sWav);",
	"`t`t`tStripQuotes(sWav);",
	"`t`t`tcontinue;",
	"`t`t}",
	"",
	"`t`t// 新皮肤行: 先提交上一款",
	"`t`tif (bPending) {",
	"`t`t`tif (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))",
	"`t`t`t`tiImported++;",
	"`t`t`telse",
	"`t`t`t`tiSkipped++;",
	"`t`t}",
	"",
	"`t`t// 名字 模型 价格 (阵营来自当前区块)",
	"`t`tcopy(szKey, charsmax(szKey), szHead);",
	"`t`tStripQuotes(szKey);",
	"`t`tParseSkinFields(szRestA, szModel, charsmax(szModel), sPrice, charsmax(sPrice));",
	"",
	"`t`tif (!szKey[0] || (sTeam[0] != TEAM_CHAR_T && sTeam[0] != TEAM_CHAR_C) || !szModel[0]) {",
	"`t`t`tlog_amx(`"[Skin] 跳过无效行: %s`", szLine);",
	"`t`t`tbPending = false;",
	"`t`t`tiSkipped++;",
	"`t`t`tcontinue;",
	"`t`t}",
	"`t`tsWav[0] = EOS;",
	"`t`tbPending = true;",
	"`t}",
	"`tif (bPending) {",
	"`t`tif (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))",
	"`t`t`tiImported++;",
	"`t`telse",
	"`t`t`tiSkipped++;",
	"`t}",
	"",
	"`tfclose(file);",
	"`tlog_amx(`"[Skin] 从 %s 导入/更新皮肤 %d 条, 跳过 %d 条`", szCfg, iImported, iSkipped);",
	"}"
)

$lines.RemoveRange(425, 54)
$lines.InsertRange(425, $replacement)
[System.IO.File]::WriteAllLines($p, $lines, $enc)
Write-Output ("new_linecount=" + $lines.Count)
Write-Output $lines[425]
Write-Output $lines[426]
Write-Output $lines[447]
Write-Output $lines[$lines.Count-1]

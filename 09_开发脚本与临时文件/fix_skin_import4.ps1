$p = 'c:\Users\Administrator\Desktop\gtr\skin 1.0\addons\amxmodx\scripting\HnsMatchSkin.sma'
$enc = New-Object System.Text.UTF8Encoding $false
$lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($p, $enc))

$replacement = @(
	'		// 裸区块头 tt / t / ct (单独一行, 不带方括号)',
	'		if ((equali(szHead, "tt") || equali(szHead, "t") || equali(szHead, "ct")) && !szRestA[0]) {',
	'			if (bPending) {',
	'				if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))',
	'					iImported++;',
	'				else',
	'					iSkipped++;',
	'			}',
	'			if (equali(szHead, "tt") || equali(szHead, "t")) sTeam[0] = TEAM_CHAR_T;',
	'			else sTeam[0] = TEAM_CHAR_C;',
	'			bPending = false;',
	'			continue;',
	'		}',
	'',
	'		// 音效行: 以 wav 开头, 属于上一款',
	'		if (equali(szHead, "wav")) {',
	'			copy(sWav, charsmax(sWav), szRestA);',
	'			trim(sWav);',
	' mar			StripQuotes(sWav);',
	'			continue;',
	'		}',
	'',
	'		// 新皮肤行: 先提交上一款',
	'		if (bPending) {',
	'			if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))',
	'				iImported++;',
	'			else',
	'				iSkipped++;',
	'		}',
	'',
	'		// 名字 模型 价格 (阵营来自当前区块)',
	'		copy(szKey, charsmax(szKey), szHead);',
	'		StripQuotes(szKey);',
	'		ParseSkinFields(szRestA, szModel, charsmax(szModel), sPrice, charsmax(sPrice));',
	'',
	'		if (!szKey[0] || (sTeam[0] != TEAM_CHAR_T && sTeam[0] != TEAM_CHAR_C) || !szModel[0]) {',
	'			log_amx("[Skin] 跳过无效行: %s", szLine);',
	'			bPending = false;',
	'			iSkipped++;',
	'			continue;',
	'		}',
	'		sWav[0] = EOS;',
	'		bPending = true;',
	'	}',
	'	if (bPending) {',
	'		if (CommitSkinRow(conn, szKey, sTeam, szModel, sPrice, sWav))',
	'			iImported++;',
	'		else',
	'			iSkipped++;',
	'	}',
	'',
	'	fclose(file);',
	'	log_amx("[Skin] 从 %s 导入/更新皮肤 %d 条, 跳过 %d 条", szCfg, iImported, iSkipped);',
	'}'
)

# Replace 1-based lines 426-479 (indexes 425-478)
$lines.RemoveRange(425, 54)
$lines.InsertRange(425, $replacement)
[System.IO.File]::WriteAllLines($p, $lines, $enc)
Write-Output ("new_linecount=" + $lines.Count)
Write-Output $lines[425]
Write-Output $lines[426]
Write-Output $lines[447]
Write-Output $lines[478]

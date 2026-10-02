$ErrorActionPreference = 'Stop'
$sma = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma'
$bak = 'c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma.bak_before_19'
if (-not (Test-Path -LiteralPath $bak)) {
    Copy-Item -LiteralPath $sma -Destination $bak -Force
}

function IndexOfBytes([byte[]]$hay, [byte[]]$needle, [int]$start = 0) {
    if ($needle.Length -lt 1) { return -1 }
    $last = $hay.Length - $needle.Length
    for ($i = $start; $i -le $last; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $needle.Length; $j++) {
            if ($hay[$i + $j] -ne $needle[$j]) { $ok = $false; break }
        }
        if ($ok) { return $i }
    }
    return -1
}

function Replace-Bytes([byte[]]$hay, [byte[]]$old, [byte[]]$new, [string]$label) {
    $idx = IndexOfBytes $hay $old 0
    if ($idx -lt 0) { throw "missing $label" }
    $idx2 = IndexOfBytes $hay $old ($idx + 1)
    if ($idx2 -ge 0) { throw "multiple $label" }
    $out = New-Object byte[] ($hay.Length - $old.Length + $new.Length)
    [Array]::Copy($hay, 0, $out, 0, $idx)
    [Array]::Copy($new, 0, $out, $idx, $new.Length)
    [Array]::Copy($hay, ($idx + $old.Length), $out, ($idx + $new.Length), ($hay.Length - $idx - $old.Length))
    Write-Host "OK $label at $idx old=$($old.Length) new=$($new.Length)"
    return $out
}

$data = [System.IO.File]::ReadAllBytes($sma)
$data = Replace-Bytes $data ([System.IO.File]::ReadAllBytes('c:\Users\Administrator\Desktop\gtr\_tmp\old_resume.txt')) ([System.IO.File]::ReadAllBytes('c:\Users\Administrator\Desktop\gtr\_tmp\new_resume.txt')) 'resume'
$data = Replace-Bytes $data ([System.IO.File]::ReadAllBytes('c:\Users\Administrator\Desktop\gtr\_tmp\old_setup.txt')) ([System.IO.File]::ReadAllBytes('c:\Users\Administrator\Desktop\gtr\_tmp\new_setup.txt')) 'setup'
$data = Replace-Bytes $data ([System.IO.File]::ReadAllBytes('c:\Users\Administrator\Desktop\gtr\_tmp\old_hud.txt')) ([System.IO.File]::ReadAllBytes('c:\Users\Administrator\Desktop\gtr\_tmp\new_hud.txt')) 'hud'

$utf8 = New-Object System.Text.UTF8Encoding $false
$text = $utf8.GetString($data)
$junk = '}换图前不拉'
if ($text.Contains($junk)) {
    $text = $text.Replace($junk, '}')
    Write-Host 'OK junk removed'
} else {
    Write-Host 'no junk token'
}

foreach ($n in @('}CLOSE', '换图前不拉天', '}换图前不拉')) {
    if ($text.Contains($n)) { Write-Host "STILL HAS $n" } else { Write-Host "clean $n" }
}

[System.IO.File]::WriteAllBytes($sma, $utf8.GetBytes($text))
Write-Host ("wrote " + $utf8.GetByteCount($text))

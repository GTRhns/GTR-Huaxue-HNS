$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$out = Join-Path $root "_lang_audit_out.txt"
$files = @(
    (Join-Path $root "configs\hns_language.txt"),
    (Join-Path $root "data\lang\HnsSkin.txt"),
    (Join-Path $root "data\lang\mixsystem.txt"),
    (Join-Path $root "data\lang\match_additons.txt"),
    (Join-Path $root "data\lang\SemiclipSystem.txt"),
    (Join-Path $root "data\lang\KnifeModels.txt")
)

function Test-Cjk([string]$s) {
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if ($c -ge 0x4E00 -and $c -le 0x9FFF) { return $true }
    }
    return $false
}

function Get-Specs([string]$s) {
    $m = [regex]::Matches($s, '%[!0-9\.\-\+ #]*[a-zA-Z%]')
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($x in $m) { $list.Add($x.Value) }
    return ($list | Sort-Object) -join ","
}

$lines = New-Object System.Collections.Generic.List[string]
function Add-Line([string]$s) { $script:lines.Add($s) | Out-Null }

foreach ($path in $files) {
    Add-Line ("=" * 80)
    Add-Line (Split-Path $path -Leaf)
    $sections = New-Object System.Collections.Specialized.OrderedDictionary
    $cur = $null
    $dups = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($raw in [System.IO.File]::ReadAllLines($path)) {
        $i++
        $s = $raw.Trim()
        if (-not $s -or $s.StartsWith(";") -or $s.StartsWith("//")) { continue }
        if ($s -match '^\[([^\]]+)\]' -and $s.IndexOf("=") -lt 0) {
            $cur = ($Matches[1] -split '\s+')[0].Trim()
            if (-not $sections.Contains($cur)) {
                $sections[$cur] = New-Object System.Collections.Specialized.OrderedDictionary
            }
            continue
        }
        if ($cur -and $s -match '^([A-Za-z0-9_]+)\s*=\s*(.*)$') {
            $k = $Matches[1]
            $v = $Matches[2].Trim()
            if ($sections[$cur].Contains($k)) {
                $dups.Add("$cur $k line $i")
            }
            $sections[$cur][$k] = @{ v = $v; line = $i }
        }
    }

    $counts = @()
    foreach ($name in $sections.Keys) { $counts += "$name=$($sections[$name].Count)" }
    Add-Line ("sections: " + ($counts -join ", "))
    Add-Line ("DUPS: " + $dups.Count)
    foreach ($d in $dups) { Add-Line ("  DUP " + $d) }

    $enName = $null
    foreach ($name in $sections.Keys) {
        if ($name.ToLower() -eq "en" -or $name.ToLower() -eq "english") { $enName = $name; break }
    }
    if (-not $enName) { Add-Line "NO EN"; continue }
    $en = $sections[$enName]

    $all = New-Object System.Collections.Generic.HashSet[string]
    foreach ($name in $sections.Keys) {
        foreach ($k in $sections[$name].Keys) { [void]$all.Add($k) }
    }
    $missEn = @($all | Where-Object { -not $en.Contains($_) } | Sort-Object)
    Add-Line ("MISSING IN EN: " + $missEn.Count)
    foreach ($k in $missEn) {
        $owners = @()
        $sample = ""
        foreach ($name in $sections.Keys) {
            if ($sections[$name].Contains($k)) {
                $owners += $name
                if (-not $sample) {
                    $sample = $sections[$name][$k].v
                    if ($sample.Length -gt 120) { $sample = $sample.Substring(0, 120) }
                }
            }
        }
        Add-Line ("  $k from " + ($owners -join ",") + " :: $sample")
    }

    Add-Line "CJK IN EN:"
    $nCjk = 0
    foreach ($k in $en.Keys) {
        if (Test-Cjk $en[$k].v) {
            $nCjk++
            $vv = $en[$k].v
            if ($vv.Length -gt 140) { $vv = $vv.Substring(0, 140) }
            Add-Line ("  L$($en[$k].line) $k = $vv")
        }
    }
    Add-Line ("  count $nCjk")

    $cnNames = @()
    foreach ($name in $sections.Keys) {
        $low = $name.ToLower()
        if ($low -eq "cn" -or $low -eq "zh" -or $low -eq "schinese") { $cnNames += $name }
    }
    foreach ($cn in $cnNames) {
        $miss = @($en.Keys | Where-Object { -not $sections[$cn].Contains($_) } | Sort-Object)
        Add-Line ("EN not in ${cn}: " + $miss.Count)
        foreach ($k in $miss) {
            $vv = $en[$k].v
            if ($vv.Length -gt 100) { $vv = $vv.Substring(0, 100) }
            Add-Line ("  $k = $vv")
        }
        $extra = @($sections[$cn].Keys | Where-Object { -not $en.Contains($_) })
        Add-Line ("${cn} not in EN: " + $extra.Count)

        $bad = 0
        foreach ($k in $en.Keys) {
            if (-not $sections[$cn].Contains($k)) { continue }
            $a = Get-Specs $sections[$cn][$k].v
            $b = Get-Specs $en[$k].v
            if ($a -ne $b) {
                $bad++
                Add-Line ("  SPEC $k cn=[$a] en=[$b]")
                $cv = $sections[$cn][$k].v; if ($cv.Length -gt 100) { $cv = $cv.Substring(0,100) }
                $ev = $en[$k].v; if ($ev.Length -gt 100) { $ev = $ev.Substring(0,100) }
                Add-Line ("    CN $cv")
                Add-Line ("    EN $ev")
            }
        }
        Add-Line ("SPEC MISMATCH ${cn} vs en: $bad")

        $sameN = 0
        foreach ($k in $en.Keys) {
            if (-not $sections[$cn].Contains($k)) { continue }
            $cv = $sections[$cn][$k].v
            $ev = $en[$k].v
            if ($cv -eq $ev -and ((Test-Cjk $cv) -or ($cv.Length -gt 18 -and $cv -match '[A-Za-z]{5}'))) {
                $sameN++
                $vv = $ev; if ($vv.Length -gt 100) { $vv = $vv.Substring(0,100) }
                Add-Line ("  SAME $k = $vv")
            }
        }
        Add-Line ("IDENTICAL ${cn}==en: $sameN")
    }

    $twName = $null
    foreach ($name in $sections.Keys) {
        $low = $name.ToLower()
        if ($low -eq "tw" -or $low -eq "zh-tw" -or $low -eq "zh_tw") { $twName = $name; break }
    }
    if ($twName) {
        $base = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in $en.Keys) { [void]$base.Add($k) }
        if ($cnNames.Count -gt 0) {
            foreach ($k in $sections[$cnNames[0]].Keys) { [void]$base.Add($k) }
        }
        $missTw = @($base | Where-Object { -not $sections[$twName].Contains($_) } | Sort-Object)
        Add-Line ("missing in ${twName}: " + $missTw.Count)
        foreach ($k in $missTw) { Add-Line ("  $k") }
    }

    $ruName = $null
    foreach ($name in $sections.Keys) { if ($name.ToLower() -eq "ru") { $ruName = $name; break } }
    if ($ruName) {
        $missRu = @($en.Keys | Where-Object { -not $sections[$ruName].Contains($_) } | Sort-Object)
        Add-Line ("EN not in ru: " + $missRu.Count)
        foreach ($k in $missRu) { Add-Line ("  $k") }
        $cjkRu = 0
        foreach ($k in $sections[$ruName].Keys) {
            if (Test-Cjk $sections[$ruName][$k].v) { $cjkRu++; Add-Line ("  CJK-RU $k = $($sections[$ruName][$k].v)") }
        }
        Add-Line ("CJK IN RU: $cjkRu")
    }
}

[System.IO.File]::WriteAllLines($out, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Output ("wrote " + $lines.Count)

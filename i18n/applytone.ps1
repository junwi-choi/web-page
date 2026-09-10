param([string]$DictDir)
$ErrorActionPreference = 'Stop'
$enc = [System.Text.UTF8Encoding]::new($false)

function Apply-Override {
    param([string]$Dict, [string]$Override)
    $map = @{}
    foreach ($l in [System.IO.File]::ReadAllLines($Override, $enc)) {
        if ($l.Trim() -eq '' -or $l.StartsWith('#')) { continue }
        $i = $l.IndexOf("`t"); if ($i -lt 1) { continue }
        $map[$l.Substring(0, $i)] = $l.Substring($i + 1)
    }
    $out = New-Object System.Collections.ArrayList
    $applied = 0
    $seen = @{}
    foreach ($l in [System.IO.File]::ReadAllLines($Dict, $enc)) {
        if ($l.Trim() -eq '' -or $l.StartsWith('#')) { [void]$out.Add($l); continue }
        $i = $l.IndexOf("`t"); if ($i -lt 1) { [void]$out.Add($l); continue }
        $ko = $l.Substring(0, $i)
        if ($map.ContainsKey($ko)) {
            [void]$out.Add($ko + "`t" + $map[$ko])
            $applied++
            $seen[$ko] = $true
        } else {
            [void]$out.Add($l)
        }
    }
    # 사전에 없던 표제어는 새로 추가
    $added = 0
    foreach ($k in $map.Keys) {
        if (-not $seen.ContainsKey($k)) { [void]$out.Add($k + "`t" + $map[$k]); $added++ }
    }
    [System.IO.File]::WriteAllLines($Dict, $out, $enc)
    Write-Host ("  {0}: {1}개 교체, {2}개 추가" -f (Split-Path $Dict -Leaf), $applied, $added)
}

Apply-Override -Dict (Join-Path $DictDir 'en.tsv') -Override (Join-Path $DictDir 'tone-en.tsv')
Apply-Override -Dict (Join-Path $DictDir 'zh.tsv') -Override (Join-Path $DictDir 'tone-zh.tsv')
Write-Host 'done'

param(
    [Parameter(Mandatory = $true)][string]$Root,      # web-page 폴더
    [Parameter(Mandatory = $true)][string]$DictDir,   # en.tsv / zh.tsv 가 있는 폴더
    [Parameter(Mandatory = $true)][string]$Lang       # en | zh
)
$ErrorActionPreference = 'Stop'

$dictPath = Join-Path $DictDir "$Lang.tsv"
if (-not (Test-Path $dictPath)) { throw "사전 파일이 없습니다: $dictPath" }

# ---- 사전 읽기 (ko <TAB> 번역) ----
$pairs = New-Object System.Collections.ArrayList
foreach ($line in [System.IO.File]::ReadAllLines($dictPath, [System.Text.UTF8Encoding]::new($false))) {
    if ($line.Trim() -eq '' -or $line.StartsWith('#')) { continue }
    $i = $line.IndexOf("`t")
    if ($i -lt 1) { continue }
    $ko = $line.Substring(0, $i)
    $tr = $line.Substring($i + 1)
    if ($tr.Trim() -eq '') { continue }
    [void]$pairs.Add([PSCustomObject]@{ Ko = $ko; Tr = $tr })
}
# 긴 문자열부터 치환해야 짧은 문자열이 긴 문자열 안쪽을 먼저 갉아먹지 않는다
$pairs = $pairs | Sort-Object -Property @{ Expression = { $_.Ko.Length }; Descending = $true }
Write-Host ("dictionary: {0} entries" -f $pairs.Count)

$langAttr = if ($Lang -eq 'zh') { 'zh-Hans' } else { 'en' }
$outRoot = Join-Path $Root $Lang
New-Item -ItemType Directory -Force $outRoot | Out-Null
New-Item -ItemType Directory -Force (Join-Path $outRoot 'services') | Out-Null

$files = @('index.html', 'price.html', 'contact.html') +
         (Get-ChildItem (Join-Path $Root 'services') -Filter *.html | ForEach-Object { 'services/' + $_.Name })

$totalLeft = 0
foreach ($rel in $files) {
    $srcPath = Join-Path $Root ($rel -replace '/', '\')
    $t = [System.IO.File]::ReadAllText($srcPath, [System.Text.UTF8Encoding]::new($false))
    $isDeep = $rel.StartsWith('services/')

    # ---- 1) 문자열 치환 ----
    foreach ($p in $pairs) { $t = $t.Replace($p.Ko, $p.Tr) }

    # ---- 2) 언어 속성 (html 태그만. 언어 메뉴의 lang="ko" 는 그대로 둔다) ----
    $t = $t -replace '(<html[^>]*?)lang="ko"', ('$1lang="' + $langAttr + '"')
    $t = $t -replace '<meta property="og:locale" content="ko_KR" />', ('<meta property="og:locale" content="' + $(if ($Lang -eq 'zh') { 'zh_CN' } else { 'en_US' }) + '" />')

    # ---- 3) source/ 경로 한 단계 올리기 ----
    if ($isDeep) {
        $t = $t.Replace('"../source/', '"../../source/')
    } else {
        $t = $t.Replace('"./source/', '"../source/')
    }

    # ---- 4) canonical / og:url 을 언어 경로로 ----
    $t = $t.Replace('https://vtax.kr/services/', ('https://vtax.kr/' + $Lang + '/services/'))
    $t = $t.Replace('https://vtax.kr/price.html', ('https://vtax.kr/' + $Lang + '/price.html'))
    $t = $t.Replace('https://vtax.kr/contact.html', ('https://vtax.kr/' + $Lang + '/contact.html'))
    $t = $t -replace 'href="https://vtax\.kr/"', ('href="https://vtax.kr/' + $Lang + '/"')
    $t = $t.Replace('"url": "https://vtax.kr/"', ('"url": "https://vtax.kr/' + $Lang + '/"'))
    $t = $t.Replace('content="https://vtax.kr/"', ('content="https://vtax.kr/' + $Lang + '/"'))
    $t = $t.Replace('"item":"https://vtax.kr/"', ('"item":"https://vtax.kr/' + $Lang + '/"'))
    $t = $t.Replace('"item":"https://vtax.kr/#services"', ('"item":"https://vtax.kr/' + $Lang + '/#services"'))

    # ---- 5) 언어 전환 링크 (원문은 ko 기준으로 적혀 있다) ----
    $up = if ($isDeep) { '../../' } else { '../' }
    $here = if ($isDeep) { '../' } else { './' }
    $other = if ($Lang -eq 'en') { 'zh' } else { 'en' }
    # 원문은 페이지 깊이에 따라 ./ 또는 ../ 로 적혀 있으므로 둘 다 받는다
    $t = $t -replace 'href="(?:\./|\.\./)index\.html" class="is-current" lang="ko"', ('href="' + $up + 'index.html" lang="ko"')
    $t = $t -replace 'href="(?:\./|\.\./)en/index\.html" lang="en"', $(if ($Lang -eq 'en') { 'href="' + $here + 'index.html" class="is-current" lang="en"' } else { 'href="' + $up + 'en/index.html" lang="en"' })
    $t = $t -replace 'href="(?:\./|\.\./)zh/index\.html" lang="zh"', $(if ($Lang -eq 'zh') { 'href="' + $here + 'index.html" class="is-current" lang="zh"' } else { 'href="' + $up + 'zh/index.html" lang="zh"' })
    $t = $t.Replace('<span class="nav-icon-label">KO</span>', ('<span class="nav-icon-label">' + $Lang.ToUpper() + '</span>'))

    # ---- 5-b) 검색 색인은 textContent 로 들어가므로 HTML 엔티티를 실제 문자로 되돌린다 ----
    $t = [regex]::Replace($t, '(?s)(var INDEX = \[.*?\];)', {
        param($m) $m.Groups[1].Value.Replace('&amp;', '&')
    })

    # ---- 6) 남은 한글 확인 ----
    $left = ([regex]'[가-힣]').Matches(($t -replace '(?s)<script.*?</script>', '')).Count
    $totalLeft += $left

    $outPath = Join-Path $outRoot ($rel -replace '/', '\')
    [System.IO.File]::WriteAllText($outPath, $t, [System.Text.UTF8Encoding]::new($false))
    Write-Host ("  {0,-28} -> {1}/{0}   남은 한글 {2}자" -f $rel, $Lang, $left)
}

Write-Host ("done. 남은 한글 합계: {0}자" -f $totalLeft)

param([string]$DictDir)
$ErrorActionPreference = 'Stop'
$enc = [System.Text.UTF8Encoding]::new($false)

# 세무사 검수 반영. 순서대로 적용되므로 긴 문구를 먼저 둔다.
$en = @(
    @('deemed input VAT credit', 'deemed input tax credit'),
    @('Deemed input VAT credit', 'Deemed input tax credit'),
    @('Percentage-of-completion revenue', 'Revenue recognition based on percentage of completion'),
    @('percentage-of-completion revenue', 'revenue recognition based on percentage of completion'),
    @('real net worth', 'substantive capital'),
    @('business status return', 'business establishment status return'),
    @('Business status return', 'Business establishment status return'),
    @('payment statements', 'income payment statements'),
    @('Payment statements', 'Income payment statements'),
    @('payment statement', 'income payment statement'),
    @('Payment statement', 'Income payment statement'),
    @('the four major insurances', 'the four major social insurance programs'),
    @('four major insurances', 'four major social insurance programs'),
    @('Tax appeals', 'Tax dispute resolution'),
    @('tax appeals', 'tax dispute resolution'),
    @('qualifying evidence', 'qualified supporting documentation'),
    @('penalty for missing documentation', 'penalty tax for failure to maintain supporting documentation'),
    @('credit for card and equivalent sales', 'VAT credit for credit-card and similar sales'),
    @('Estimated filing (simplified / standard expense rate)', 'Presumptive income tax filing (simplified / standard expense ratio)'),
    @('Is simplified or ordinary taxation more favourable?', 'Is simplified or general VAT taxation more favourable?'),
    @('ordinary taxation, which allows refunds', 'general VAT taxation, which allows refunds'),
    @('Double-entry bookkeeping required', 'Taxpayer required to keep double-entry books'),
    @('Simplified bookkeeping eligible', 'Taxpayer eligible for simplified bookkeeping'),
    @('Ordinary taxpayer', 'General VAT taxpayer'),
    @('Simplified taxpayer', 'Simplified VAT taxpayer'),
    @('daily wage income', 'daily labor income'),
    @('Daily-worker', 'Day-laborer'),
    @('daily-worker', 'day-laborer'),
    @('Daily worker', 'Day laborer'),
    @('daily workers', 'day laborers'),
    @('daily worker', 'day laborer'),
    @('provisional payments', 'advances receivable'),
    @('inclusion in taxable income', 'inclusion in gross income for tax purposes'),
    @('the requirements for deductibility', 'the requirements for recognition as a deductible expense'),
    @('R&amp;D tax credit', 'R&amp;D and human resources development tax credit'),
    @('R&D tax credit', 'R&D and human resources development tax credit'),
    @('the special SME tax reduction', 'the Special Tax Reduction for Small and Medium Enterprises'),
    @('key money', 'key money (business-premium payment)')
)

$zh = @(
    @('拟制进项税额抵扣', '拟制进项税额扣除'),
    @('完工百分比收入确认', '完工进度（履约进度）收入确认'),
    @('按完工百分比', '按完工进度'),
    @('营业场所现况申报', '营业场所现状申报'),
    @('支付明细表', '收入支付明细表'),
    @('四大保险', '韩国四大社会保险'),
    @('税务复议', '税务争议救济'),
    @('合格凭证', '合格证明文件'),
    @('凭证不备加算税', '未备齐证明文件加算税'),
    @('购买方开具税务发票', '购货方开具的税务发票'),
    @('信用卡等销项税额抵扣', '信用卡等销售额税额扣除'),
    @('推计申报', '推定申报'),
    @('简易 · 标准费用率', '简易费用率／标准费用率'),
    @('复式记账义务人', '负有复式记账义务者'),
    @('简易账簿适用人', '简易账簿适用对象'),
    @('代理申报', '代理纳税申报'),
    @('调整费', '税务调整服务费'),
    @('日工所得', '日雇劳动所得'),
    @('日工', '日雇劳动者'),
    @('计入应税收益', '计入益金（计入应税所得）'),
    @('符合税前扣除要件', '符合损金认定要件'),
    @('税前扣除要件', '损金认定要件'),
    @('供应时点', '供给时点'),
    @('研发与人力开发费税额抵免', '研究及人力开发费税额抵免'),
    @('研发人力开发费税额抵免', '研究及人力开发费税额抵免'),
    @('企业附设研究所', '企业附属研究所'),
    @('举证', '说明及举证'),
    @('崔浚位', 'Choi Jun-wi')
)

# 표제어 자체를 통째로 바꿔야 하는 항목 (부분 치환으로는 어색해지는 것들)
$enWhole = @{
    '기장대리'    = 'Bookkeeping agency service'
    '신고대리'    = 'Tax return filing agency service'
    '조정료 (연 1회)' = 'Tax return adjustment fee (once a year)'
    '간이과세자'  = 'Simplified VAT taxpayer'
    '일반과세자'  = 'General VAT taxpayer'
    '손금 인정'   = 'Recognition as a deductible expense'
    '공급시기'    = 'Time of supply (VAT taxable event)'
    '가지급금'    = 'Advances receivable'
}
$zhWhole = @{
    '기장대리'    = '代理记账服务'
    '신고대리'    = '代理纳税申报服务'
    '조정료 (연 1회)' = '税务调整服务费（每年一次）'
    '간이과세자'  = '简易课税者（韩国税制）'
    '일반과세자'  = '一般课税者（韩国税制）'
    '손금 인정'   = '认定为损金（税前扣除）'
    '공급시기'    = '供给时点（增值税纳税义务发生时点）'
    '가지급금'    = '暂付款（临时垫付款）'
}

function Fix-Dict {
    param([string]$Path, [array]$Pairs, [hashtable]$Whole)
    $lines = [System.IO.File]::ReadAllLines($Path, $enc)
    $out = New-Object System.Collections.ArrayList
    $hits = 0
    foreach ($line in $lines) {
        if ($line.Trim() -eq '' -or $line.StartsWith('#')) { [void]$out.Add($line); continue }
        $i = $line.IndexOf("`t")
        if ($i -lt 1) { [void]$out.Add($line); continue }
        $ko = $line.Substring(0, $i)
        $tr = $line.Substring($i + 1)
        $before = $tr
        if ($Whole.ContainsKey($ko)) {
            $tr = $Whole[$ko]
        } else {
            foreach ($p in $Pairs) { $tr = $tr.Replace($p[0], $p[1]) }
        }
        if ($tr -ne $before) { $hits++ }
        [void]$out.Add($ko + "`t" + $tr)
    }
    [System.IO.File]::WriteAllLines($Path, $out, $enc)
    Write-Host ("  {0}: {1}개 항목 수정" -f (Split-Path $Path -Leaf), $hits)
}

Fix-Dict -Path (Join-Path $DictDir 'en.tsv') -Pairs $en -Whole $enWhole
Fix-Dict -Path (Join-Path $DictDir 'zh.tsv') -Pairs $zh -Whole $zhWhole
Write-Host 'done'

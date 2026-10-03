[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CodeRepository,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$Seed,

    [ValidateSet("pilot", "final")]
    [string]$Category = "pilot",

    [string]$ExperimentRoot = "results\experiment",

    [string]$ResultsRepository = (Split-Path -Parent $PSScriptRoot),

    [switch]$Force
)

$ErrorActionPreference = "Stop"

$expectedConditions = @(
    "A_COST", "D_COST", "E_COST",
    "A_BW", "D_BW", "E_BW",
    "H00", "HC1", "HC2", "HC3",
    "HT1", "HT2", "HT3",
    "HM1", "HM2", "HM3", "HM4",
    "HCT1", "HCT3"
)
$requiredFiles = @("summary.json", "periods.csv", "demand.csv", "result.json")

$codePath = (Resolve-Path -LiteralPath $CodeRepository).Path
$resultsPath = (Resolve-Path -LiteralPath $ResultsRepository).Path
if ([IO.Path]::IsPathRooted($ExperimentRoot)) {
    $experimentPath = (Resolve-Path -LiteralPath $ExperimentRoot).Path
}
else {
    $experimentPath = (Resolve-Path -LiteralPath (Join-Path $codePath $ExperimentRoot)).Path
}

$episodesRoot = Join-Path $experimentPath "screening\episodes"
if (-not (Test-Path -LiteralPath $episodesRoot -PathType Container)) {
    throw "실험 결과 폴더를 찾을 수 없습니다: $episodesRoot"
}

$namePattern = "screening__seed-{0}__*" -f $Seed
$episodeDirectories = @(
    Get-ChildItem -LiteralPath $episodesRoot -Directory |
        Where-Object { $_.Name -like $namePattern } |
        Sort-Object Name
)

if ($episodeDirectories.Count -ne $expectedConditions.Count) {
    throw "seed $Seed 결과가 완전하지 않습니다. 필요한 조건: $($expectedConditions.Count), 발견: $($episodeDirectories.Count)"
}

$summaries = @()
$foundConditions = @()
foreach ($directory in $episodeDirectories) {
    foreach ($requiredFile in $requiredFiles) {
        $requiredPath = Join-Path $directory.FullName $requiredFile
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "필수 파일이 없습니다: $requiredPath"
        }
    }

    $summaryPath = Join-Path $directory.FullName "summary.json"
    $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($summary.status -ne "completed") {
        throw "완료되지 않은 조건입니다: $($directory.Name)"
    }
    if ([int]$summary.episode.seed -ne $Seed) {
        throw "seed 번호가 일치하지 않습니다: $($directory.Name)"
    }
    $condition = [string]$summary.episode.condition
    if ([string]::IsNullOrWhiteSpace($condition)) {
        throw "조건 코드가 없습니다: $summaryPath"
    }
    if ($directory.Name -ne ("screening__seed-{0}__{1}" -f $Seed, $condition)) {
        throw "폴더명과 summary 조건이 일치하지 않습니다: $($directory.Name)"
    }
    $summaries += $summary
    $foundConditions += $condition
}

$missingConditions = @($expectedConditions | Where-Object { $_ -notin $foundConditions })
$unexpectedConditions = @($foundConditions | Where-Object { $_ -notin $expectedConditions })
if ($missingConditions.Count -or $unexpectedConditions.Count -or ($foundConditions | Select-Object -Unique).Count -ne $expectedConditions.Count) {
    throw "조건 집합이 올바르지 않습니다. 누락: $($missingConditions -join ','), 예상 외: $($unexpectedConditions -join ',')"
}

$demandIds = @($summaries | ForEach-Object { [string]$_.artifacts.demand_sha256 } | Select-Object -Unique)
if ($demandIds.Count -ne 1) {
    throw "동일 seed의 조건들이 서로 다른 수요경로를 사용했습니다."
}

$fingerprintTexts = @(
    $summaries | ForEach-Object { $_.fingerprints | ConvertTo-Json -Compress } | Select-Object -Unique
)
if ($fingerprintTexts.Count -ne 1) {
    throw "동일 seed의 조건들이 서로 다른 실행 설정을 사용했습니다."
}

$destinationDirectory = Join-Path $resultsPath ("seeds\{0}" -f $Category)
New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
$zipPath = Join-Path $destinationDirectory ("seed-{0}-results.zip" -f $Seed)
if ((Test-Path -LiteralPath $zipPath) -and -not $Force) {
    throw "이미 ZIP이 존재합니다: $zipPath. 다시 만들려면 -Force를 명시하세요."
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("scm-seed-{0}-{1}" -f $Seed, [guid]::NewGuid().ToString("N"))
$bundleRoot = Join-Path $temporaryRoot ("seed-{0}-results" -f $Seed)
New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null

try {
    foreach ($directory in $episodeDirectories) {
        Copy-Item -LiteralPath $directory.FullName -Destination $bundleRoot -Recurse
    }

    $sourceCommit = "unavailable"
    try {
        $commitOutput = & git -C $codePath rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $commitOutput) {
            $sourceCommit = [string]$commitOutput
        }
    }
    catch {
        $sourceCommit = "unavailable"
    }

    $metadata = [ordered]@{
        schema_version = "scm_seed_result_bundle_v1"
        seed = $Seed
        category = $Category
        condition_count = $expectedConditions.Count
        conditions = $expectedConditions
        packaged_at_utc = [DateTime]::UtcNow.ToString("o")
        source_code_commit = $sourceCommit
        source_experiment_root = $experimentPath
        fingerprints = $summaries[0].fingerprints
    }
    $metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $bundleRoot "bundle_metadata.json") -Encoding UTF8

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -LiteralPath $bundleRoot -DestinationPath $zipPath -CompressionLevel Optimal
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

$zip = Get-Item -LiteralPath $zipPath
[pscustomobject]@{
    status = "completed"
    seed = $Seed
    category = $Category
    conditions = $expectedConditions.Count
    zip_path = $zip.FullName
    zip_bytes = $zip.Length
} | ConvertTo-Json


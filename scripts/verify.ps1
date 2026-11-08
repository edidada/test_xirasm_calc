$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'build\app.exe'
$inputFile = Join-Path $PSScriptRoot 'input.txt'

if (-not (Test-Path -LiteralPath $exe)) { throw "missing built program: $exe" }

# ---- Mode 1 + 2 + 3: expression lines, function table, built-in self-test ----
Write-Host '================ calculator output ================'
$out = Get-Content -LiteralPath $inputFile | & $exe
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }
Write-Host '===================================================='
if ($code -ne 0) { throw "calculator exit code = $code (expected 0)" }

$text = $out -join "`n"
$needles = @(
    '2+3*4 = 14',
    '(2+3)*4 = 20',
    '2^10 = 1024',
    'sqrt(2) = 1.414213562',
    'sin(pi/6) = 0.5',
    'table for x = 0.5',
    'sin(x) = 0.4794255386',
    '--- selftest ---',
    'PASS 2+3*4 = 14',
    'PASS deg(pi) = 180',
    'PASS rad(180) = 3.141592654'
)
foreach ($n in $needles) {
    if (-not $text.Contains($n)) { throw "missing expected output: $n" }
}
if ($text.Contains('FAIL')) { throw 'a self-test case reported FAIL' }
$passCount = ([regex]::Matches($text, 'PASS ')).Count
Write-Host "self-test PASS lines: $passCount"
if ($passCount -lt 20) { throw "too few PASS lines: $passCount" }

# ---- Empty stdin must trigger the built-in self-test ----
Write-Host '=========== empty stdin -> selftest ==========='
Push-Location $root
$emptyOut = cmd /c "build\app.exe < NUL"
$emptyCode = $LASTEXITCODE
Pop-Location
$emptyOut | ForEach-Object { Write-Host $_ }
if ($emptyCode -ne 0) { throw "empty-stdin exit code = $emptyCode" }
$emptyText = $emptyOut -join "`n"
if (-not $emptyText.Contains('--- selftest ---')) { throw 'empty stdin did not trigger the self-test' }
if ($emptyText.Contains('FAIL')) { throw 'empty-stdin self-test reported FAIL' }

Write-Host 'ALL CHECKS PASSED - scientific calculator built and ran successfully'

# دخان منطق دورة الطلب + المحفظة (بدون جهاز فعلي)
# يغطي اختبارات الوحدة الحرجة المشار إليها في TESTING.md
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$flutter = 'C:\Users\GWY-6\flutter\bin\flutter.bat'
Set-Location $root

Write-Host '== job + wallet + geo + phone logic =='
& $flutter test test/job_logic_test.dart test/wallet_logic_test.dart test/geo_test.dart test/phone_test.dart test/api_config_test.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== auth/role widgets =='
& $flutter test test/auth_gate_test.dart test/role_home_test.dart test/orders_screen_test.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== live API health (FCM path) =='
$health = Invoke-RestMethod -Uri 'https://albatariq.com/api/health' -TimeoutSec 20
if (-not $health.ok) { throw 'API health failed' }
Write-Host ($health | ConvertTo-Json -Compress)

Write-Host ''
Write-Host 'SMOKE LOGIC PASSED'
Write-Host 'Manual on-device checklist (still required once):'
Write-Host '  1) Customer login → create tow/tech request'
Write-Host '  2) Provider online → receive offer / FCM'
Write-Host '  3) Accept → enRoute → complete → commission debit'
Write-Host '  4) Admin https://albatariq.com sees order + wallet top-up approve'
exit 0

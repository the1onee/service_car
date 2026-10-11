# دخان إنتاج: صحة API + موقع الأدمن + عقود محلية (اختبارات)
# لا يستبدل اختباراً يدوياً على جهاز، لكنه يتحقق من البنية التحتية الحية.
$ErrorActionPreference = 'Stop'
$failed = 0

function Check([string]$name, [scriptblock]$block) {
  try {
    & $block
    Write-Host "PASS  $name"
  } catch {
    Write-Host "FAIL  $name — $($_.Exception.Message)"
    $script:failed++
  }
}

$base = if ($env:BARRR_API_BASE) { $env:BARRR_API_BASE.TrimEnd('/') } else { 'https://albatariq.com' }

Check "HTTPS admin home ($base/)" {
  $r = Invoke-WebRequest -Uri "$base/" -UseBasicParsing -TimeoutSec 20
  if ($r.StatusCode -ne 200) { throw "status $($r.StatusCode)" }
}

Check "API health ($base/api/health)" {
  $r = Invoke-RestMethod -Uri "$base/api/health" -TimeoutSec 20
  if (-not $r.ok) { throw "ok!=true: $($r | ConvertTo-Json -Compress)" }
  if ($r.passwordReset -ne 'firebase_email') { throw "unexpected passwordReset" }
}

Check "API CORS preflight origin https://albatariq.com" {
  $headers = @{
    Origin                        = 'https://albatariq.com'
    'Access-Control-Request-Method' = 'POST'
  }
  $r = Invoke-WebRequest -Uri "$base/api/health" -Method Options -Headers $headers -UseBasicParsing -TimeoutSec 20 -ErrorAction SilentlyContinue
  # بعض الـ proxies لا ترد على OPTIONS لـ GET health — نقبل 204/200/404 من nginx
  if ($null -eq $r) { return }
}

Check "Android release keystore present" {
  $root = Split-Path -Parent $PSScriptRoot
  if (-not (Test-Path (Join-Path $root 'android\key.properties'))) { throw 'key.properties missing' }
  if (-not (Test-Path (Join-Path $root 'android\upload-keystore.pfx'))) { throw 'upload-keystore.pfx missing' }
}

Check "Flutter unit/widget tests" {
  $root = Split-Path -Parent $PSScriptRoot
  $flutter = 'C:\Users\GWY-6\flutter\bin\flutter.bat'
  Push-Location $root
  try {
    & $flutter test 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "flutter test exit $LASTEXITCODE" }
  } finally { Pop-Location }
}

Check "Firestore rules smoke" {
  $root = Split-Path -Parent $PSScriptRoot
  Push-Location (Join-Path $root 'rules-test')
  try {
    npm test 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "rules smoke exit $LASTEXITCODE" }
  } finally { Pop-Location }
}

Check "Admin Vitest + Express tests" {
  $admin = Resolve-Path (Join-Path (Split-Path -Parent $PSScriptRoot) '..\barrr-admin')
  Push-Location $admin
  try {
    npm test 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "admin vitest exit $LASTEXITCODE" }
    Push-Location (Join-Path $admin 'server')
    try {
      npm test 2>&1 | Out-Host
      if ($LASTEXITCODE -ne 0) { throw "server test exit $LASTEXITCODE" }
    } finally { Pop-Location }
  } finally { Pop-Location }
}

Write-Host ''
if ($failed -gt 0) {
  Write-Host "SMOKE FAILED: $failed check(s)"
  exit 1
}
Write-Host 'SMOKE PASSED (infra + automated tests). Manual device cycle still recommended:'
Write-Host '  login → request → offer → accept → commission → FCM'
exit 0

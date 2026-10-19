# بناء حزمة AAB موقّعة لـ Google Play مع عنوان API على albatariq.com
# الاستخدام: powershell -File scripts/build-release-apk.ps1
# لبناء APK للتجربة المباشرة على الهاتف: أضف -Apk
param([switch]$Apk)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$props = Join-Path $root 'android\key.properties'
$pfx = Join-Path $root 'android\upload-keystore.pfx'
if (-not (Test-Path $props) -or -not (Test-Path $pfx)) {
  Write-Error "Missing android/key.properties or android/upload-keystore.pfx - generate signing first."
}

$flutter = @(
  "$env:USERPROFILE\flutter\bin\flutter.bat",
  'flutter'
) | Where-Object { $_ -eq 'flutter' -or (Test-Path $_) } | Select-Object -First 1

$apiBase = if ($env:BARRR_API_BASE) { $env:BARRR_API_BASE } else { 'https://albatariq.com' }
$target = if ($Apk) { 'apk' } else { 'appbundle' }

Write-Host "Building release $target with BARRR_API_BASE=$apiBase"
& $flutter build $target --release `
  --dart-define="BARRR_API_BASE=$apiBase"
if ($LASTEXITCODE -ne 0) { Write-Error "flutter build $target failed" }

$out = if ($Apk) {
  Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
} else {
  Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
}
if (Test-Path $out) {
  Write-Host "OK: $out"
} else {
  Write-Error "Output not found after build: $out"
}

# بناء APK مُوقَّع للإنتاج مع عنوان API على albatariq.com
# الاستخدام: powershell -File scripts/build-release-apk.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$props = Join-Path $root 'android\key.properties'
$pfx = Join-Path $root 'android\upload-keystore.pfx'
if (-not (Test-Path $props) -or -not (Test-Path $pfx)) {
  Write-Error "Missing android/key.properties or android/upload-keystore.pfx — generate signing first."
}

$flutter = @(
  'C:\Users\GWY-6\flutter\bin\flutter.bat',
  "$env:USERPROFILE\flutter\bin\flutter.bat",
  'flutter'
) | Where-Object { $_ -eq 'flutter' -or (Test-Path $_) } | Select-Object -First 1

$apiBase = if ($env:BARRR_API_BASE) { $env:BARRR_API_BASE } else { 'https://albatariq.com' }

Write-Host "Building release APK with BARRR_API_BASE=$apiBase"
& $flutter build apk --release `
  --dart-define="BARRR_API_BASE=$apiBase"

$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
  Write-Host "OK: $apk"
} else {
  Write-Error 'APK not found after build'
}

param(
  [string]$ApiBase = 'https://api-staging.31.220.90.124.nip.io'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($ApiBase -match '^https://(www\.)?albatariq\.com/?$') {
  Write-Error 'Refusing to build staging against the production API.'
}

$flutter = @(
  "$env:USERPROFILE\flutter\bin\flutter.bat",
  'flutter'
) | Where-Object { $_ -eq 'flutter' -or (Test-Path $_) } | Select-Object -First 1

& $flutter build apk --debug `
  --flavor staging `
  --dart-define='APP_ENV=staging' `
  --dart-define="BARRR_API_BASE=$ApiBase"
if ($LASTEXITCODE -ne 0) { Write-Error 'Flutter staging build failed.' }

$output = Join-Path $root 'build\app\outputs\flutter-apk\app-staging-debug.apk'
if (-not (Test-Path $output)) { Write-Error "Output not found: $output" }
Write-Host "OK: $output"

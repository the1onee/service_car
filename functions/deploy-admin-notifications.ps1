# نشر دوال الإشعارات عبر Firebase (FCM من Cloud Functions)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "Deploying notification functions to car-services-iraq..."
npx -y firebase-tools@latest deploy --only functions:onAdminNotificationCreated,functions:onJobStatus --project car-services-iraq

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "فشل النشر. إن ظهر خطأ الفوترة: فعّل Blaze من"
  Write-Host "https://console.firebase.google.com/project/car-services-iraq/usage/details"
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "تم. الإرسال من لوحة الإدارة يمر عبر Firestore → Cloud Functions → FCM."

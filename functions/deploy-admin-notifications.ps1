# نشر دالة إشعارات الأدمن فقط — شغّله بعد تفعيل خطة Blaze
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "Deploying onAdminNotificationCreated to car-services-iraq..."
npx -y firebase-tools@latest deploy --only functions:onAdminNotificationCreated --project car-services-iraq

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "فشل النشر. إن ظهر خطأ الفوترة: فعّل Blaze من"
  Write-Host "https://console.firebase.google.com/project/car-services-iraq/usage/details"
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "تم. جرّب إرسال إشعار من لوحة الإدارة."

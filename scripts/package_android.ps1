# Usage: powershell -ExecutionPolicy Bypass -File scripts/package_android.ps1 `
#   [-SkipPubGet] [-SkipAab] `
#   [-SupabaseUrl "..."] [-SupabaseAnonKey "..."] `
#   [-SupabaseUserEmail "user@example.com"] [-SupabaseUserPassword "..."] `
#   [-R2AccountId "..."] [-R2AccessKey "..."] [-R2SecretKey "..."] `
#   [-R2Bucket "..."] [-R2PublicBase "..."]
#
# Genera APK release (y opcionalmente AAB) y los deja en dist/android/ con timestamp.

param(
  [switch]$SkipPubGet,
  [switch]$SkipAab,
  [string]$SupabaseUrl = "",
  [string]$SupabaseAnonKey = "",
  [string]$SupabaseUserEmail = "",
  [string]$SupabaseUserPassword = "",
  [string]$R2AccountId = "",
  [string]$R2AccessKey = "",
  [string]$R2SecretKey = "",
  [string]$R2Bucket = "",
  [string]$R2PublicBase = ""
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $root "..")

if (-not $SkipPubGet) {
  flutter pub get
}

$defines = @()
if ($SupabaseUrl) { $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl" }
if ($SupabaseAnonKey) { $defines += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey" }
if ($SupabaseUserEmail) { $defines += "--dart-define=SUPABASE_USER_EMAIL=$SupabaseUserEmail" }
if ($SupabaseUserPassword) { $defines += "--dart-define=SUPABASE_USER_PASSWORD=$SupabaseUserPassword" }
if ($R2AccountId) { $defines += "--dart-define=R2_ACCOUNT_ID=$R2AccountId" }
if ($R2AccessKey) { $defines += "--dart-define=R2_ACCESS_KEY=$R2AccessKey" }
if ($R2SecretKey) { $defines += "--dart-define=R2_SECRET_KEY=$R2SecretKey" }
if ($R2Bucket) { $defines += "--dart-define=R2_BUCKET=$R2Bucket" }
if ($R2PublicBase) { $defines += "--dart-define=R2_PUBLIC_BASE=$R2PublicBase" }

Write-Host "Building APK release..."
flutter build apk --release @defines

if (-not $SkipAab) {
  Write-Host "Building AAB release..."
  flutter build appbundle --release @defines
}

$apkSrc = "build/app/outputs/flutter-apk/app-release.apk"
$aabSrc = "build/app/outputs/bundle/release/app-release.aab"

if (-not (Test-Path $apkSrc)) {
  Write-Error "No se encontr\u00f3 el APK en $apkSrc"
  exit 1
}

$destRoot = Join-Path $PWD "dist/android"
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmm"

$apkDest = Join-Path $destRoot "voicex_android_$stamp.apk"
Copy-Item $apkSrc $apkDest -Force

if (-not $SkipAab -and (Test-Path $aabSrc)) {
  $aabDest = Join-Path $destRoot "voicex_android_$stamp.aab"
  Copy-Item $aabSrc $aabDest -Force
}

Write-Host "Artefactos listos en ${destRoot}:"
Get-ChildItem $destRoot | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | ForEach-Object {
  Write-Host " - $($_.Name)"
}

Start-Process explorer.exe $destRoot

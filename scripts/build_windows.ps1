# Build Windows release with optional dart-defines for secrets.
# Usage:
#   .\scripts\build_windows.ps1 `
#     -SupabaseUrl "https://xxx.supabase.co" `
#     -SupabaseAnonKey "..." `
#     -SupabaseUserEmail "user@example.com" -SupabaseUserPassword "..." `
#     -R2AccountId "..." -R2AccessKey "..." -R2SecretKey "..." `
#     -R2Bucket "voicex-video" -R2PublicBase "https://pub-xxxx.r2.dev"

param(
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

$ErrorActionPreference = "Stop"

$defines = @()
if ($SupabaseUrl)   { $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl" }
if ($SupabaseAnonKey) { $defines += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey" }
if ($SupabaseUserEmail) { $defines += "--dart-define=SUPABASE_USER_EMAIL=$SupabaseUserEmail" }
if ($SupabaseUserPassword) { $defines += "--dart-define=SUPABASE_USER_PASSWORD=$SupabaseUserPassword" }
if ($R2AccountId)   { $defines += "--dart-define=R2_ACCOUNT_ID=$R2AccountId" }
if ($R2AccessKey)   { $defines += "--dart-define=R2_ACCESS_KEY=$R2AccessKey" }
if ($R2SecretKey)   { $defines += "--dart-define=R2_SECRET_KEY=$R2SecretKey" }
if ($R2Bucket)      { $defines += "--dart-define=R2_BUCKET=$R2Bucket" }
if ($R2PublicBase)  { $defines += "--dart-define=R2_PUBLIC_BASE=$R2PublicBase" }

Write-Host "Building Windows release..."
flutter build windows --release @defines

Write-Host "Done. Artifacts in build\\windows\\x64\\runner\\Release\\"

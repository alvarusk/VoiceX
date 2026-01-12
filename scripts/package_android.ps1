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

function Load-DotEnv([string]$path) {
  $map = @{}
  if (-not (Test-Path $path)) { return $map }
  foreach ($raw in Get-Content $path) {
    $line = $raw.Trim()
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }
    $idx = $line.IndexOf('=')
    if ($idx -le 0) { continue }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    if ($value.Length -ge 2) {
      $first = $value.Substring(0, 1)
      $last = $value.Substring($value.Length - 1, 1)
      if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
        $value = $value.Substring(1, $value.Length - 2)
      }
    }
    if ($key) { $map[$key] = $value }
  }
  return $map
}

function Resolve-EnvValue([string]$explicit, [string]$key, [hashtable]$dotEnv) {
  if ($explicit) { return $explicit }
  $fromEnv = [Environment]::GetEnvironmentVariable($key)
  if ($fromEnv) { return $fromEnv }
  if ($dotEnv.ContainsKey($key)) { return $dotEnv[$key] }
  return ""
}

$dotEnv = Load-DotEnv (Join-Path $PWD ".env")

$SupabaseUrl = Resolve-EnvValue $SupabaseUrl "SUPABASE_URL" $dotEnv
$SupabaseAnonKey = Resolve-EnvValue $SupabaseAnonKey "SUPABASE_ANON_KEY" $dotEnv
$SupabaseUserEmail = Resolve-EnvValue $SupabaseUserEmail "SUPABASE_USER_EMAIL" $dotEnv
$SupabaseUserPassword = Resolve-EnvValue $SupabaseUserPassword "SUPABASE_USER_PASSWORD" $dotEnv
$R2AccountId = Resolve-EnvValue $R2AccountId "R2_ACCOUNT_ID" $dotEnv
$R2AccessKey = Resolve-EnvValue $R2AccessKey "R2_ACCESS_KEY" $dotEnv
$R2SecretKey = Resolve-EnvValue $R2SecretKey "R2_SECRET_KEY" $dotEnv
$R2Bucket = Resolve-EnvValue $R2Bucket "R2_BUCKET" $dotEnv
$R2PublicBase = Resolve-EnvValue $R2PublicBase "R2_PUBLIC_BASE" $dotEnv

$missing = @()
if (-not $R2AccountId) { $missing += "R2_ACCOUNT_ID" }
if (-not $R2AccessKey) { $missing += "R2_ACCESS_KEY" }
if (-not $R2SecretKey) { $missing += "R2_SECRET_KEY" }
if (-not $R2Bucket) { $missing += "R2_BUCKET" }
if ($missing.Count -gt 0) {
  Write-Error "Faltan variables R2 obligatorias: $($missing -join ', '). Completa .env o pasa parametros."
  exit 1
}

if (-not $SupabaseUrl -or -not $SupabaseAnonKey) {
  Write-Warning "SUPABASE_URL o SUPABASE_ANON_KEY no definidos. La sync en cloud puede fallar."
}

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

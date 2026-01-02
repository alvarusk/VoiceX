# Usage: powershell -ExecutionPolicy Bypass -File scripts/package_windows.ps1 [-SkipPubGet]

param(
  [switch]$SkipPubGet
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $root "..")

if (-not $SkipPubGet) {
  flutter pub get
}

flutter build windows --release

$releaseDir = Join-Path $PWD "build/windows/x64/runner/Release"
if (-not (Test-Path $releaseDir)) {
  Write-Error "No se encontr\x00f3 la carpeta de build en $releaseDir"
  exit 1
}

$destRoot = Join-Path $PWD "dist/windows"
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$dest = Join-Path $destRoot "voicex_win_$stamp"

Copy-Item $releaseDir $dest -Recurse -Force

$zipPath = "$dest.zip"
Compress-Archive -Path (Join-Path $dest '*') -DestinationPath $zipPath -Force

Write-Host "Build empaquetado en:"
Write-Host "  $dest"
Write-Host "  $zipPath"

Start-Process explorer.exe $destRoot

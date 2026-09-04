# AI Connect Africa — offline update package builder
#
# Builds release artifacts and zips them into a dated update package
# you can copy to a USB drive or a local school server. No internet
# is needed on the receiving devices.
#
# Usage (from the repo root):
#   powershell -ExecutionPolicy Bypass -File tools\make_update_package.ps1 [-Target windows|apk|both]

param(
    [ValidateSet('windows', 'apk', 'both')]
    [string]$Target = 'both'
)

$ErrorActionPreference = 'Stop'
$flutter = 'D:\flutter\bin\flutter.bat'
$root = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format 'yyyy-MM-dd'
$outDir = Join-Path $root "dist\otic-update-$stamp"

New-Item -ItemType Directory -Force $outDir | Out-Null

if ($Target -in @('windows', 'both')) {
    Write-Host '== Building Windows release ==' -ForegroundColor Cyan
    & $flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    $winOut = Join-Path $root 'build\windows\x64\runner\Release'
    Compress-Archive -Path "$winOut\*" `
        -DestinationPath (Join-Path $outDir "AI Connect Africa Windows $stamp.zip") -Force
    Write-Host "Windows package ready" -ForegroundColor Green
}

if ($Target -in @('apk', 'both')) {
    Write-Host '== Building Android release APK ==' -ForegroundColor Cyan
    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
    Copy-Item (Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk') `
        (Join-Path $outDir "AI Connect Africa $stamp.apk")
    Write-Host "APK package ready" -ForegroundColor Green
}

# Instructions that travel with the package
@"
AI Connect Africa update package — $stamp

WINDOWS
  1. Copy the zip to the target PC and extract anywhere (e.g. C:\OTIC).
  2. Run "AI Connect Africa.exe". Student data is stored separately in
     Documents and is preserved across updates.

ANDROID
  1. Copy the .apk to the phone (USB cable or SD card).
  2. Open it with the file manager and allow 'Install unknown apps'.
  3. Installing over an older version keeps all student data.

AI MODEL (only needed once per device)
  Windows: Documents\OTIC\gemma-3-1b-q4_k_m.gguf
  Android: Internal Storage\OTIC\gemma-3-1b.bin

No internet connection is required for any step.
"@ | Out-File -Encoding utf8 (Join-Path $outDir 'README.txt')

Write-Host "`nUpdate package created at: $outDir" -ForegroundColor Green

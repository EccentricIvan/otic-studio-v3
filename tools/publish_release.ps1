<#
.SYNOPSIS
  Publishes an AI Connect Africa GitHub release with both the Android APK and the
  Windows desktop zip attached.

.DESCRIPTION
  Verifies that the build artifacts exist and that `gh` is authenticated, then
  creates the release. `gh` cannot be authenticated automatically (reading the
  stored credential is blocked by security policy), so if it is not logged in
  this script stops and tells you to run `gh auth login` once.

.PARAMETER Version
  Marketing version without the leading 'v', e.g. 1.1.0

.PARAMETER ArtifactDir
  Folder holding AI Connect Africa v<Version>.apk and AI Connect Africa Windows v<Version>.zip
  (default: D:\)

.EXAMPLE
  .\tools\publish_release.ps1 -Version 1.1.0
#>

param(
  [Parameter(Mandatory = $true)] [string] $Version,
  [string] $ArtifactDir = 'D:\'
)

$ErrorActionPreference = 'Stop'

$tag      = "v$Version"
$apk      = Join-Path $ArtifactDir "AI Connect Africa v$Version.apk"
$zip      = Join-Path $ArtifactDir "AI Connect Africa Windows v$Version.zip"
$repoRoot = Split-Path $PSScriptRoot -Parent
$notes    = Join-Path $repoRoot "dist\release-notes-v$Version.md"

# --- Preconditions -----------------------------------------------------------
foreach ($f in @($apk, $zip, $notes)) {
  if (-not (Test-Path $f)) { throw "Missing required file: $f" }
}

# gh must be authenticated; we cannot do it for you.
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "gh is not authenticated. Run this once, then re-run this script:" -ForegroundColor Yellow
  Write-Host "    gh auth login" -ForegroundColor Cyan
  throw "gh not authenticated"
}

# --- Publish -----------------------------------------------------------------
Write-Host "Publishing $tag with APK + Windows zip..." -ForegroundColor Green
gh release create $tag $apk $zip `
  --title "AI Connect Africa $tag" `
  --notes-file $notes

Write-Host "Done. Release page: " -NoNewline
gh release view $tag --json url --jq '.url'

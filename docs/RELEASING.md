# Releasing

How to build, sign, and publish an AI Connect Africa release, and how to make an
offline update bundle for schools. Written for Windows + PowerShell.

---

## 0. Prerequisites

- Flutter on PATH (`D:\flutter\bin`), `flutter doctor` green for Windows + Android.
- Android keystore present: `C:\Users\LENOVO\otic-release.jks` + password file,
  wired through `android/key.properties` (gitignored).
- `gh` (GitHub CLI) installed. It must be **authenticated once** before it can
  publish — see step 4.
- Because C: is tight, redirect build temp to D: for every build:
  ```powershell
  $env:TEMP='D:\temp'; $env:TMP='D:\temp'
  ```

---

## 1. Bump the version

In `pubspec.yaml`:

```yaml
version: 1.1.0+2        # marketingVersion+buildNumber — bump both
```

Update the in-app footer label in
[lib/shared/widgets/app_shell.dart](../lib/shared/widgets/app_shell.dart)
("Offline · vX.Y") and add a [CHANGELOG.md](../CHANGELOG.md) entry. Commit.

---

## 2. Build the artifacts

```powershell
$env:TEMP='D:\temp'; $env:TMP='D:\temp'

# Desktop
flutter build windows --release
Compress-Archive -Path build\windows\x64\runner\Release\* `
  -DestinationPath D:\AI Connect Africa Windows v1.1.0.zip -Force

# Free C: before the APK build (the windows tree is ~1 GB and regenerable)
Remove-Item build\windows -Recurse -Force

# Android (signed)
flutter build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk D:\AI Connect Africa v1.1.0.apk
```

> Keep large outputs on **D:**. After releasing, delete `build/` to reclaim C:.

---

## 3. Verify the APK signature

```powershell
$bt = Get-ChildItem D:\Android\build-tools | Sort-Object Name -Descending | Select-Object -First 1
& "$($bt.FullName)\apksigner.bat" verify --print-certs D:\AI Connect Africa v1.1.0.apk
```

Expect: `CN=Otic Studio, OU=Education, O=OTIC, L=Kampala, C=UG`. Android only
accepts updates signed with this same key.

---

## 4. Authenticate gh (one time per machine)

`git push` works for code/tags via the credential helper, but `gh` needs its own
login to upload release binaries. Automation **cannot** scrape the token from the
credential store (blocked by security policy), so a human runs this once:

```powershell
gh auth login          # choose GitHub.com → HTTPS → authenticate in browser
gh auth status         # confirm "Logged in to github.com"
```

This persists; subsequent releases don't need it again.

---

## 5. Publish the GitHub release

```powershell
gh release create v1.1.0 `
  D:\AI Connect Africa v1.1.0.apk `
  D:\AI Connect Africa Windows v1.1.0.zip `
  --title "AI Connect Africa v1.1.0 — Website Builder" `
  --notes-file dist\release-notes-v1.1.0.md
```

The release page then offers **both** downloads: the `.apk` for phones/tablets and
the `.zip` for Windows desktop — anyone with the link can download from a browser.

A ready-to-run helper exists at [tools/publish_release.ps1](../tools/publish_release.ps1):

```powershell
.\tools\publish_release.ps1 -Version 1.1.0
```

It checks `gh auth status` first and prints the manual login command if needed.

---

## 6. Offline update bundle (USB / school LAN)

For sites with no internet, build a bundle instead of (or in addition to) the
GitHub release:

```powershell
.\tools\make_update_package.ps1
```

This stages the build for distribution. Copy the resulting folder (or
`dist\otic-update-<date>\`) to a USB drive or the school LAN share. Installing an
APK over an older version **keeps all student data** (additive DB migrations). The
~1 GB model file travels separately and is installed in-app via **Install from
file…**.

---

## Quick reference

| Step | Command |
|---|---|
| Build desktop | `flutter build windows --release` |
| Build Android | `flutter build apk --release` |
| Verify signature | `apksigner verify --print-certs <apk>` |
| Auth (once) | `gh auth login` |
| Publish | `gh release create vX.Y.Z <apk> <zip> --title … --notes-file …` |
| Offline bundle | `.\tools\make_update_package.ps1` |

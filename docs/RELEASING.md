# Releasing

How to build, sign, and publish an AI Connect Africa release that includes a
**single Android download with the AI models inside**, plus the Windows zip.

---

## 0. Prerequisites

- Flutter on PATH, `flutter doctor` green for Windows + Android.
- Android keystore wired through `android/key.properties` (gitignored). `storeFile`
  is resolved by Gradle relative to **`android/app/`**, not `android/` — a keystore
  kept at `android/release-keystore.jks` must be written as
  `storeFile=../release-keystore.jks`. Getting this wrong fails the build at
  `:app:validateSigningRelease` only after the full ~50-minute compile, and the
  "falls back to debug signing" path in `build.gradle.kts` does **not** rescue it:
  that fallback fires only when `key.properties` is missing entirely.
- `gh` authenticated once (`gh auth login`).
- Model pack on disk (never commit these):

```
dist\models\chat-model.litertlm
dist\models\translate-afrislm.gguf
```

---

## 1. Bump the version

In `pubspec.yaml`:

```yaml
version: 1.2.0+3        # marketingVersion+buildNumber — bump both
```

Add a [CHANGELOG.md](../CHANGELOG.md) entry. Commit.

---

## 2. Build with models (recommended)

```powershell
.\tools\build_release_with_models.ps1 -Version 1.2.0
```

This injects the model pack into `android/app/src/main/assets/models/`, builds
a fat arm64 APK, clears the injected files from the tree, and builds a Windows
zip with a `models/` folder next to the exe.

Outputs in `dist\`:

- `AI Connect Africa v1.2.0-with-models.apk`  (~1–1.5 GB)
- `AI Connect Africa Windows v1.2.0.zip`

---

## 3. Publish — get the download link

```powershell
.\tools\publish_release.ps1 -Version 1.2.0 -WithModels
```

The script prints the **direct Android URL**, for example:

```
https://github.com/<owner>/<repo>/releases/download/v1.2.0/AI%20Connect%20Africa%20v1.2.0-with-models.apk
```

Share that link. Installers get chat + translation with no extra model step.
First app launch unpacks the assets once (~1 GB free space on the phone).

---

## 4. One-time: CI model pack (optional rolling fat APK)

So GitHub Actions can rebuild a with-models APK without checking models into git:

```powershell
gh release create model-pack `
  dist\models\chat-model.litertlm `
  dist\models\translate-afrislm.gguf `
  --title "Model pack (not an app release)" `
  --notes "Source assets for fat Android APK builds. Not for end users."
```

Then run **Actions → Build Release Artifacts → Run workflow** with
**bundle_models = true**. That uploads
`ai-connect-africa-latest-with-models.apk` to the `latest-build` release.

Default pushes to `main` still publish a **slim** APK (fast CI).

---

## 5. Offline USB bundle

```powershell
.\tools\make_update_package.ps1 -WithModels -Version 1.2.0
```

---

## Quick reference

| Step | Command |
|---|---|
| Build fat Android + Windows | `.\tools\build_release_with_models.ps1 -Version X.Y.Z` |
| Publish + print download URL | `.\tools\publish_release.ps1 -Version X.Y.Z -WithModels` |
| USB bundle with models | `.\tools\make_update_package.ps1 -WithModels -Version X.Y.Z` |
| Auth (once) | `gh auth login` |

# Contributing / Developer Setup

How to get AI Connect Africa running on a fresh machine and make changes correctly.
The app is **fully offline by design** — do not add any dependency or API that
requires network access at runtime. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
for how the pieces fit together.

---

## 1. Prerequisites

| Tool | Version | Notes |
|---|---|---|
| **Flutter SDK** | 3.44+ | Includes Dart. Add `flutter/bin` to PATH. |
| **JDK** | 17 (Temurin) | For Android builds. Avoid mismatched winget manifests. |
| **Android SDK** | platforms 35 + 36, build-tools 34.0.0 | Only needed to build/run the Android app. |
| **Android NDK + CMake** | NDK 28.0.12433566, CMake 3.31.0 | Needed by the experimental `fllama`/llama.cpp Android test path. |
| **Visual Studio Build Tools** | "Desktop development with C++" | Only needed to build the Windows desktop app. |
| **Git** | any recent | |
| **GitHub CLI** (`gh`) | optional | Only for publishing releases. |

Verify your environment:

```powershell
flutter doctor
```

Resolve anything that isn't a green check for the platforms you intend to build.

---

## 2. Clone and install

```powershell
git clone https://github.com/malinzijeremiah01-lab/Otic-Studio.git
cd Otic-Studio
flutter pub get
```

---

## 3. Generate code (required after pulling, and after any DB change)

The Drift database DAOs are generated. The `*.g.dart` files are committed, but
regenerate them whenever you change a table or DAO:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

---

## 4. Run

```powershell
flutter run -d windows     # desktop
flutter run -d android     # connected device / emulator
flutter run -d chrome      # quick UI check in a browser
```

The app starts even **without** the AI model present — it falls back to a
`MockEngine` so every screen works. To exercise real inference you need the model
file (next section).

---

## 5. The AI model file (not in the repo)

The Gemma model (~1 GB) is **gitignored and distributed separately** (USB / local
server) — it is never committed or downloaded over the internet.

- **In-app:** open the app → **Model Not Installed** screen → **Install from
  file…** → pick the model file. The app validates, copies, and activates it.
- **Manual placement (alternative):**
  - Android: `[InternalStorage]/OTIC/gemma-3-1b.bin`
  - Windows: `[Documents]/OTIC/gemma-3-1b-q4_k_m.gguf`

Files matching `*.gguf`, `*.bin`, `*.ggml` are gitignored — do not commit them.

### Experimental Llama 3.2 GGUF test model

The `/llama-test` screen is a separate llama.cpp experiment using `fllama`. It
downloads **Llama 3.2 1B Q4_K_M** from a direct URL into app documents storage
and records a small install marker beside the file. This is for A/B testing only:
it does not change the Gemma model installer or the production tutor engine.

Do not place the Llama GGUF in `assets/` and do not commit it. The file is large
and should stay outside the APK/repo.

---

## 6. Android signing (only needed for release builds)

Debug builds work out of the box. For a **signed release** build you need a
keystore — never commit it:

```powershell
# 1. Generate a keystore once
keytool -genkey -v -keystore <path>\otic-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias otic

# 2. Copy the template and fill in your values
Copy-Item android\key.properties.example android\key.properties
#    edit android\key.properties → storePassword, keyPassword, keyAlias, storeFile
```

`android/key.properties`, `*.jks`, and `*.keystore` are gitignored. **Back up your
keystore + passwords securely** — losing them means you can never ship a signed
update to existing installs.

---

## 7. Before you commit

```powershell
flutter analyze     # must be clean (zero issues)
flutter test        # all tests must pass
```

Add tests for non-trivial logic (see [test/](test/) for examples). Keep commits
focused; update [CHANGELOG.md](CHANGELOG.md) for user-facing changes.

---

## 8. What NOT to commit (already gitignored)

- Keystores / passwords: `*.jks`, `*.keystore`, `android/key.properties`
- Local config: `android/local.properties` (your SDK paths)
- AI model files: `*.gguf`, `*.bin`, `*.ggml`
- Build output: `/build/`, `.dart_tool/`, `/dist/`

If you're unsure whether a file is safe to commit, it probably holds machine- or
secret-specific data — leave it out.

---

## 9. Releasing

Building, signing, and publishing a release (plus offline USB update bundles) is
documented in [docs/RELEASING.md](docs/RELEASING.md).

---

## Project layout

A map of the codebase is in the [README](README.md#project-structure); the system
design and request flow are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); the
history of decisions and obstacles is in
[docs/ENGINEERING_LOG.md](docs/ENGINEERING_LOG.md).

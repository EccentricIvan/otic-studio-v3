# Publishing to Play with the models attached

**Goal:** a user installs from Play and the app comes up with both models
present and translation working — no manual install step, no "transfer via
USB" screen, no tap-to-download.

That goal is reachable, but not with the APK this repo builds today. This
document is the handoff for whoever does the Play work.

## What already works, and what doesn't

The model wiring is done and on `main`/`build/android-fat-apk`. Android
translation runs llama.cpp directly (`LlamaCppEngineImpl`, no Ollama —
Ollama is desktop-only). `android-fat-apk.yml` downloads both models from
SHA-pinned Hugging Face URLs and embeds them in the APK, and
`BundledModelBootstrap` extracts the GGUF to app storage on first launch.

That APK is a good USB/sideload artifact. It **cannot be uploaded to Play**:

| Play limit | Value | Ours |
|---|---|---|
| **Base module (compressed download)** | **500 MB** | 1.228 GB ❌ |
| Individual asset pack | 1.5 GB | 586 MB ✅ / 642 MB ✅ |
| All modules + install-time asset packs | 4 GB | 1.228 GB ✅ |
| Fast-follow / on-demand cumulative | 30 GB | 1.228 GB ✅ |

`chat-model.litertlm` is 586 MB and `translate-afrislm.gguf` is 642 MB. The
chat model alone exceeds the 500 MB base cap. Both models must leave the
base module and become **asset packs**, and the build must become an AAB
(`flutter build appbundle`), not an APK.

## Use `fast-follow`, not `install-time`

This is the one decision that is easy to get wrong, so it is worth being
explicit about why.

`install-time` asset packs are only reachable through
`AssetManager.open()`, which yields an `InputStream` and **no file system
path**. llama.cpp opens a *path*. That mismatch is the entire reason
`MainActivity.extractBundledAsset` exists today — it streams the 642 MB
GGUF out of the APK into app storage just so llama.cpp has something to
open.

`fast-follow` packs are unpacked onto disk and expose a real path:

```kotlin
val loc = assetPackManager.getPackLocation("translate_model") ?: return null
val path = File(loc.assetsPath(), "models/translate-afrislm.gguf").absolutePath
```

Fast-follow also downloads **automatically as soon as installation
completes** — no user interaction — which is exactly the "reaches the app
and downloads into it automatically" requirement.

Second-order win: with a real path, the extraction copy goes away. Today
the GGUF costs 642 MB inside the APK *plus* 642 MB extracted alongside it.
On the 32 GB / 4 GB minimum-spec target that is ~640 MB of pure waste plus
a slow, silent first launch. Fast-follow removes it.

Use **two packs**, not one — `chat_model` and `translate_model`. Each sits
well under the 1.5 GB per-pack cap, and re-quantizing the translation model
then does not force users to re-download the chat model.

## The work, by layer

1. **`android/app/build.gradle`** — there is currently no `assetPacks`,
   `splits`, or `bundle` block at all. Add
   `assetPacks = [":chat_model", ":translate_model"]`.

2. **New pack modules** — `chat_model/` and `translate_model/`, each with a
   `build.gradle` applying `com.android.asset-pack` and an
   `AndroidManifest.xml` declaring `<dist:delivery><dist:fast-follow/>`.
   Model files live at `src/main/assets/models/<name>`.

3. **`pubspec.yaml`** — no change needed. It has no `flutter: assets:`
   block; the models reach the APK through the native Android assets
   directory, so only CI's copy destination moves.

4. **`MainActivity.kt`** — add the `com.google.android.play:asset-delivery`
   dependency and a `getAssetPackPath` method channel handler beside the
   existing `hasBundledAsset` / `extractBundledAsset` ones. Keep the
   existing two: they remain the sideload path.

5. **`lib/ai_core/model/model_locations.dart`** — prepend the asset-pack
   path to `modelCandidateFiles()`. On sideloaded or non-Play installs
   `getPackLocation()` returns null, and discovery falls through to the
   existing Documents / exe-dir / `dist/models` chain unchanged. The USB
   route keeps working.

6. **CI** — add a `flutter build appbundle` job. Keep the fat-APK job; it
   is still the USB artifact.

### Handle the not-yet-downloaded window

Fast-follow is automatic but not instantaneous, and it can fail. The app
must cope with a first launch where the pack has not landed:

- `getPackLocation()` returning null is a normal state, not an error.
- `translateEngineLoadedProvider` already soft-fails to null and leaves
  chat working, which is the correct behaviour here too.
- Use `AssetPackManager` download-state callbacks to show progress rather
  than the existing "Model not installed — transfer via USB" screen, which
  would be actively misleading for a Play user.

## Blocker: release signing

CI cannot produce an uploadable AAB yet. `android/release-keystore.jks` and
`android/key.properties` are local-only and gitignored (correctly — they
are secrets). They exist on one developer machine and nowhere else.

Required: base64 the keystore into a GitHub Secret, add password/alias
secrets, and write `key.properties` at build time in the workflow.

**Back the keystore up off that machine before anything else.** If it is
lost, the app can never be updated under the same Play listing.

## Model licensing

`Qwen3-0.6B` (chat) is Apache-2.0 — clean for redistribution.

`TranslatePsy-AfriSLM-0.8B-Q4-GGUF` declares `license: apache-2.0` on the
weights, so redistribution is permitted as published. Note for whoever
signs off commercially: the model card also states NLLB-200-3.3B
(CC-BY-NC-4.0) was used as the teacher model and that the synthetic
training mix is CC-BY-NC-4.0. Those NC terms are stated against training
data and teacher provenance, not the released weights. Whether NC-teacher
distillation reaches the output weights is unsettled, so a commercial Play
listing deserves a legal glance. If it needs resolving first, a chat-only
release is unblocked; translation is the only piece in question.

## On the offline-first constraint

Play delivers the models over the network at install time. This does not
break the offline-first rule: it changes how the model bytes are
*obtained*, not the runtime, exactly as the bundled Release zip already
does. After install the app runs with zero connectivity, and the USB /
local-server route stays supported for schools with none. There is no way
to move 1.2 GB through Play without it crossing the network once.

## References

- Play maximum size limits — https://support.google.com/googleplay/android-developer/answer/9859372
- Play Asset Delivery — https://developer.android.com/guide/playcore/asset-delivery
- Java/Kotlin integration (`getPackLocation`) — https://developer.android.com/guide/playcore/asset-delivery/integrate-java

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/providers/db_provider.dart';

/// Single source of truth for "what language is this app speaking right now".
///
/// Both halves of the dual-model setup hang off this one value:
///
///   * static UI labels  → [AppLocale] / `tr()`, table lookups, instant
///   * dynamic chat text → AfriSLM round-trip around the Qwen3-0.6B tutor
///
/// Before this, each half resolved the language independently from
/// [activeStudentProvider] — the UI in `app.dart` and the engine in
/// `studentLanguageCode`. They agreed in the steady state, but there was no
/// way to change the language *without* writing a student row (so guests had
/// no language at all), and a single chat turn re-derived the code up to four
/// times, which a mid-turn switch could tear across.
///
/// Deliberately stores only the *explicit* choice, never a copy of the
/// student's saved language. [StudentNotifier.updateProfile] invalidates
/// [activeStudentProvider] on every profile edit, so a notifier that seeded
/// itself from the DB would push the stored value back over an unsaved guest
/// choice whenever an unrelated field (name, age, interests) was touched.
class LanguageOverride extends Notifier<String?> {
  /// Null means "nothing chosen this session" — fall through to the profile.
  @override
  String? build() => null;

  /// Flips the whole app — labels and model routing — to [code].
  ///
  /// Applies to the UI synchronously, then persists to the student profile so
  /// it survives a restart. Guests (no profile yet) keep the choice in memory
  /// only, matching the "no saved state" rule for that role: the demo speaks
  /// their language, nothing is written to disk.
  Future<void> setLanguage(String code) async {
    state = code;
    try {
      final student = await ref.read(activeStudentProvider.future);
      if (student == null) return;
      await ref.read(studentNotifierProvider.notifier).updateProfile(
            id: student.id,
            name: student.name,
            language: code,
          );
    } catch (e) {
      // The UI has already switched; failing to persist is not worth
      // interrupting a lesson over. It reverts on next launch.
      debugPrint('setLanguage: could not persist language "$code": $e');
    }
  }

  /// Aligns the session choice with a language just written to a profile.
  ///
  /// Onboarding writes `language` straight through [StudentNotifier], so
  /// without this a guest who picked Swahili in Settings and then onboarded in
  /// Yoruba would keep getting Swahili — the override would outrank the
  /// profile it was meant to defer to.
  void adoptSaved(String code) => state = code;

  /// Drops back to whatever the profile says (used when switching profiles).
  void clear() => state = null;
}

final languageOverrideProvider =
    NotifierProvider<LanguageOverride, String?>(LanguageOverride.new);

/// The resolved language code for **UI rendering**: explicit choice, else the
/// saved profile, else English.
///
/// Synchronous on purpose — a widget cannot await, and rendering English for
/// the frame or two before the profile loads is what the previous inline
/// `maybeWhen(orElse: 'en')` in `app.dart` already did. The engine side must
/// *not* use this: see [studentLanguageCode], which awaits the profile so the
/// very first message of a session is routed in the right language.
final appLanguageProvider = Provider<String>((ref) {
  final override = ref.watch(languageOverrideProvider);
  if (override != null) return override;
  return ref.watch(activeStudentProvider).valueOrNull?.language ?? 'en';
});

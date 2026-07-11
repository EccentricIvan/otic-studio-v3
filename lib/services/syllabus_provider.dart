import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'syllabus_retriever.dart';

final syllabusRetrieverProvider = Provider<SyllabusRetriever>((ref) {
  final retriever = SyllabusRetriever();
  ref.onDispose(retriever.dispose);
  return retriever;
});

/// Toggle for syllabus-grounded retrieval, off by default until the feature
/// has been tested — flip on from Settings while verifying answer quality.
class SyllabusGroundingNotifier extends Notifier<bool> {
  static const _key = 'syllabus_grounding_enabled';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final syllabusGroundingEnabledProvider =
    NotifierProvider<SyllabusGroundingNotifier, bool>(
        SyllabusGroundingNotifier.new);

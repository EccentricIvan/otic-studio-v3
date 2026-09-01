import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional cloud AI (OpenAI-compatible) credentials stored on-device only.
class CloudApiConfig {
  const CloudApiConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.groq.com/openai/v1',
    this.model = 'llama-3.3-70b-versatile',
    this.enabled = false,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final bool enabled;

  bool get isConfigured =>
      enabled && apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  CloudApiConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? enabled,
  }) {
    return CloudApiConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
    );
  }
}

class CloudApiSettingsNotifier extends AsyncNotifier<CloudApiConfig> {
  static const _kKey = 'cloud_ai_api_key';
  static const _kUrl = 'cloud_ai_base_url';
  static const _kModel = 'cloud_ai_model';
  static const _kEnabled = 'cloud_ai_enabled';

  @override
  Future<CloudApiConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    return CloudApiConfig(
      apiKey: prefs.getString(_kKey) ?? '',
      baseUrl: prefs.getString(_kUrl) ?? 'https://api.openai.com/v1',
      model: prefs.getString(_kModel) ?? 'gpt-4o-mini',
      enabled: prefs.getBool(_kEnabled) ?? false,
    );
  }

  Future<void> save(CloudApiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, config.apiKey.trim());
    await prefs.setString(_kUrl, config.baseUrl.trim());
    await prefs.setString(_kModel, config.model.trim());
    await prefs.setBool(_kEnabled, config.enabled);
    state = AsyncData(config);
    // Force AI engine to reload with the new backend.
    ref.read(cloudApiReloadTickProvider.notifier).state++;
  }

  Future<void> clearKey() async {
    final current = state.valueOrNull ?? const CloudApiConfig();
    await save(current.copyWith(apiKey: '', enabled: false));
  }
}

/// Bumped when cloud settings change so [engineLoadedProvider] rebuilds.
final cloudApiReloadTickProvider = StateProvider<int>((ref) => 0);

final cloudApiSettingsProvider =
    AsyncNotifierProvider<CloudApiSettingsNotifier, CloudApiConfig>(
  CloudApiSettingsNotifier.new,
);

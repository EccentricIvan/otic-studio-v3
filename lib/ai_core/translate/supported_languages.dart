/// The English ↔ African-language pairs TranslatePsy-AfriSLM supports.
///
/// Codes are BCP-47 (matches `Students.language`, students_table.dart).
class SupportedLanguage {
  const SupportedLanguage(this.code, this.name);
  final String code;
  final String name;
}

/// English plus the 19 Sub-Saharan African languages AfriSLM translates.
/// Order matches the model card (huggingface.co/qvac/TranslatePsy-AfriSLM-2B).
const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage('en', 'English'),
  SupportedLanguage('af', 'Afrikaans'),
  SupportedLanguage('am', 'Amharic'),
  SupportedLanguage('ha', 'Hausa'),
  SupportedLanguage('ig', 'Igbo'),
  SupportedLanguage('rw', 'Kinyarwanda'),
  SupportedLanguage('ln', 'Lingala'),
  SupportedLanguage('lg', 'Luganda'),
  SupportedLanguage('mg', 'Malagasy'),
  SupportedLanguage('ny', 'Nyanja (Chichewa)'),
  SupportedLanguage('om', 'Oromo'),
  SupportedLanguage('sn', 'Shona'),
  SupportedLanguage('so', 'Somali'),
  SupportedLanguage('st', 'Southern Sotho'),
  SupportedLanguage('sw', 'Swahili'),
  SupportedLanguage('tn', 'Tswana'),
  SupportedLanguage('wo', 'Wolof'),
  SupportedLanguage('xh', 'Xhosa'),
  SupportedLanguage('yo', 'Yoruba'),
  SupportedLanguage('zu', 'Zulu'),
];

/// Display name for a language code, falling back to the code itself for
/// anything outside the supported list (defensive — shouldn't happen since
/// onboarding/Settings only ever write codes from [supportedLanguages]).
String languageName(String code) {
  for (final lang in supportedLanguages) {
    if (lang.code == code) return lang.name;
  }
  return code;
}

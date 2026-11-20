import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:voteguard/services/nigerian_languages_dict.dart';

enum AppLanguage {
  en,
  pcm,
  ha,
  yo,
  ig,
  ff,
  kr,
  tiv,
  ibb,
  efi,
  ijc,
  bin,
  urh,
  nup,
  idu,
  igl,
  igb,
  its,
  ish,
  gbr,
}

class LanguageOption {
  final AppLanguage language;
  final String code;
  final String name;
  final String nativeName;
  final String shortLabel;
  final String region;

  const LanguageOption({
    required this.language,
    required this.code,
    required this.name,
    required this.nativeName,
    required this.shortLabel,
    required this.region,
  });
}

class LanguageService extends ChangeNotifier {
  static const String _storageKey = 'vg_language';
  static const String _cachePrefix = 'vg_i18n_cache_v1_';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AppLanguage _currentLanguage = AppLanguage.en;
  bool _isTranslating = false;
  int _cacheVersion = 0;
  String? _geminiApiKey;
  String _geminiModel = 'gemini-2.0-flash';
  final Set<String> _inFlightBatchKeys = {};
  final Set<String> _attemptedBatchKeys = {};

  final Map<AppLanguage, Map<String, String>> _aiCache = {};

  int get cacheVersion => _cacheVersion;

  static const Map<AppLanguage, String> _languagePromptNames = {
    AppLanguage.en: 'English',
    AppLanguage.pcm:
        'Nigerian Pidgin English (clear, natural grassroots Pidgin)',
    AppLanguage.ha: 'Hausa',
    AppLanguage.yo: 'Yoruba (with proper tonal diacritics)',
    AppLanguage.ig: 'Igbo',
    AppLanguage.ff: 'Fulfulde (Nigerian Fulani)',
    AppLanguage.kr: 'Kanuri (Yerwa Kanuri spoken in Borno and Yobe, Nigeria)',
    AppLanguage.tiv: 'Tiv (spoken in Benue, Taraba, and Nasarawa, Nigeria)',
    AppLanguage.ibb: 'Ibibio (spoken in Akwa Ibom, Nigeria)',
    AppLanguage.efi: 'Efik (spoken in Cross River, Nigeria)',
    AppLanguage.ijc: 'Ijaw / Izon (spoken in the Niger Delta, Nigeria)',
    AppLanguage.bin: 'Edo / Bini (spoken in Edo State, Nigeria)',
    AppLanguage.urh: 'Urhobo (spoken in Delta State, Nigeria)',
    AppLanguage.nup: 'Nupe (spoken in Niger, Kwara, and Kogi States, Nigeria)',
    AppLanguage.idu: 'Idoma (spoken in Benue State, Nigeria)',
    AppLanguage.igl: 'Igala (spoken in Kogi State, Nigeria)',
    AppLanguage.igb: 'Ebira (spoken in Kogi State, Nigeria)',
    AppLanguage.its: 'Itsekiri (spoken in Delta State, Nigeria)',
    AppLanguage.ish: 'Esan (spoken in Edo State, Nigeria)',
    AppLanguage.gbr: 'Gbagyi (spoken in FCT Abuja, Niger, and Kaduna, Nigeria)',
  };

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isTranslating => _isTranslating;

  void setGeminiConfig({String? apiKey, String? modelName}) {
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      _geminiApiKey = apiKey.trim();
    }
    if (modelName != null && modelName.trim().isNotEmpty) {
      _geminiModel = modelName.trim();
    }
  }

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
      language: AppLanguage.en,
      code: 'en',
      name: 'English',
      nativeName: 'English',
      shortLabel: 'EN',
      region: 'Official',
    ),
    LanguageOption(
      language: AppLanguage.pcm,
      code: 'pcm',
      name: 'Nigerian Pidgin',
      nativeName: 'Pidgin',
      shortLabel: 'PCM',
      region: 'Nationwide',
    ),
    LanguageOption(
      language: AppLanguage.ha,
      code: 'ha',
      name: 'Hausa',
      nativeName: 'Hausa',
      shortLabel: 'HA',
      region: 'North-West / North-East',
    ),
    LanguageOption(
      language: AppLanguage.yo,
      code: 'yo',
      name: 'Yoruba',
      nativeName: 'Yorùbá',
      shortLabel: 'YO',
      region: 'South-West',
    ),
    LanguageOption(
      language: AppLanguage.ig,
      code: 'ig',
      name: 'Igbo',
      nativeName: 'Igbo',
      shortLabel: 'IG',
      region: 'South-East',
    ),
    LanguageOption(
      language: AppLanguage.ff,
      code: 'ff',
      name: 'Fulani (Fulfulde)',
      nativeName: 'Fulfulde',
      shortLabel: 'FUL',
      region: 'Northern Nigeria',
    ),
    LanguageOption(
      language: AppLanguage.kr,
      code: 'kr',
      name: 'Kanuri',
      nativeName: 'Kanuri',
      shortLabel: 'KAN',
      region: 'Borno / Yobe',
    ),
    LanguageOption(
      language: AppLanguage.tiv,
      code: 'tiv',
      name: 'Tiv',
      nativeName: 'Tiv',
      shortLabel: 'TIV',
      region: 'Benue / Taraba / Nasarawa',
    ),
    LanguageOption(
      language: AppLanguage.ibb,
      code: 'ibb',
      name: 'Ibibio',
      nativeName: 'Ibibio',
      shortLabel: 'IBB',
      region: 'Akwa Ibom',
    ),
    LanguageOption(
      language: AppLanguage.efi,
      code: 'efi',
      name: 'Efik',
      nativeName: 'Efik',
      shortLabel: 'EFI',
      region: 'Cross River',
    ),
    LanguageOption(
      language: AppLanguage.ijc,
      code: 'ijc',
      name: 'Ijaw (Izon)',
      nativeName: 'Izon (Ijaw)',
      shortLabel: 'IJW',
      region: 'Bayelsa / Rivers / Delta',
    ),
    LanguageOption(
      language: AppLanguage.bin,
      code: 'bin',
      name: 'Edo (Bini)',
      nativeName: 'Ẹ̀dó (Bini)',
      shortLabel: 'EDO',
      region: 'Edo State',
    ),
    LanguageOption(
      language: AppLanguage.urh,
      code: 'urh',
      name: 'Urhobo',
      nativeName: 'Urhobo',
      shortLabel: 'URH',
      region: 'Delta State',
    ),
    LanguageOption(
      language: AppLanguage.nup,
      code: 'nup',
      name: 'Nupe',
      nativeName: 'Nupe',
      shortLabel: 'NUP',
      region: 'Niger / Kwara / Kogi',
    ),
    LanguageOption(
      language: AppLanguage.idu,
      code: 'idu',
      name: 'Idoma',
      nativeName: 'Idoma',
      shortLabel: 'IDO',
      region: 'Benue State',
    ),
    LanguageOption(
      language: AppLanguage.igl,
      code: 'igl',
      name: 'Igala',
      nativeName: 'Igala',
      shortLabel: 'IGL',
      region: 'Kogi State',
    ),
    LanguageOption(
      language: AppLanguage.igb,
      code: 'igb',
      name: 'Ebira',
      nativeName: 'Ebira',
      shortLabel: 'EBR',
      region: 'Kogi State',
    ),
    LanguageOption(
      language: AppLanguage.its,
      code: 'its',
      name: 'Itsekiri',
      nativeName: 'Itsekiri',
      shortLabel: 'ITS',
      region: 'Delta State',
    ),
    LanguageOption(
      language: AppLanguage.ish,
      code: 'ish',
      name: 'Esan',
      nativeName: 'Esan',
      shortLabel: 'ESN',
      region: 'Edo State',
    ),
    LanguageOption(
      language: AppLanguage.gbr,
      code: 'gbr',
      name: 'Gbagyi',
      nativeName: 'Gbagyi',
      shortLabel: 'GBG',
      region: 'FCT Abuja / Niger / Kaduna',
    ),
  ];

  LanguageOption get activeOption => supportedLanguages.firstWhere(
        (opt) => opt.language == _currentLanguage,
        orElse: () => supportedLanguages.first,
      );

  Future<void> init() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null) {
        final match = supportedLanguages.where((l) => l.code == saved);
        if (match.isNotEmpty) {
          _currentLanguage = match.first.language;
        }
      }
      await _loadAiCache(_currentLanguage);
      notifyListeners();
    } catch (e) {
      debugPrint('[LanguageService] Init error: $e');
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: activeOption.code);
      await _loadAiCache(lang);
      notifyListeners();
    } catch (e) {
      debugPrint('[LanguageService] Save language error: $e');
    }
  }

  Future<void> _loadAiCache(AppLanguage lang) async {
    if (lang == AppLanguage.en) return;
    try {
      final raw = await _storage.read(key: '$_cachePrefix${lang.name}');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _aiCache[lang] = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('[LanguageService] Cache load error: $e');
    }
  }

  Future<void> _saveAiCache(AppLanguage lang) async {
    if (lang == AppLanguage.en) return;
    try {
      final map = _aiCache[lang] ?? {};
      await _storage.write(
        key: '$_cachePrefix${lang.name}',
        value: jsonEncode(map),
      );
    } catch (e) {
      debugPrint('[LanguageService] Cache save error: $e');
    }
  }

  String _matchCase(String original, String translated) {
    final trimmed = original.trim();
    if (trimmed == trimmed.toUpperCase() && trimmed != trimmed.toLowerCase()) {
      return translated.toUpperCase();
    }
    return translated;
  }

  static const Set<String> _protectedTokens = {
    'INEC', 'EC8A', 'EC8B', 'EC8C', 'EC8D', 'EC8E', 'BVAS', 'IREV', 'OCR',
    'GPS', 'PU', 'LGA', 'PVC', 'APC', 'PDP', 'LP', 'NNPP', 'APGA', 'ADC',
    'SDP', 'YPP', 'AA', 'AAC', 'ADP', 'APP', 'APM', 'BP', 'NRM', 'PRP',
    'ZLP', 'A', 'NDC', 'DLA', 'EN', 'HA', 'YO', 'IG', 'PCM', 'NGN', 'ID',
    'PDF', 'CSV', 'JPG', 'PNG', 'AI', 'URL', 'API', 'HTTP', 'HTTPS', 'SMS',
    '2FA', 'OTP', 'PIN', 'VOTEGUARD', 'NAIJAOBSERVE', 'WHATSAPP', 'GOOGLE',
    'GEMINI', 'WAT',
  };

  /// Returns true for numbers, codes, emails, URLs, party acronyms, etc.
  static bool shouldSkipTranslation(String rawText) {
    final text = rawText.trim();
    if (text.length < 2 || text.length > 400) return true;
    if (RegExp(r'^[\d\s.,:%+\-/()#:•·|&–—!?]+$').hasMatch(text)) return true;
    if (text.startsWith('ID: #') ||
        text.startsWith('#NGA-') ||
        text.startsWith('http://') ||
        text.startsWith('https://')) {
      return true;
    }
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return true;
    if (RegExp(r'^\+?\d[\d\s-]{6,}$').hasMatch(text)) return true;
    if (_protectedTokens.contains(text.toUpperCase())) return true;
    if (RegExp(r'[a-zA-Z]').allMatches(text).length < 2) return true;
    return false;
  }

  /// Instant synchronous offline lookup (hardcoded in-code dictionary + cached AI translations).
  /// Also handles dynamic prefixes like "ROLE: ...", "PROVINCE: ...", "ELECTION: ..." offline.
  String tr(String text) {
    if (_currentLanguage == AppLanguage.en) return text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;

    final leading = RegExp(r'^\s*').firstMatch(text)?.group(0) ?? '';
    final trailing = RegExp(r'\s*$').firstMatch(text)?.group(0) ?? '';

    final lower = trimmed.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final dict = _phraseDictionary[lower];
    if (dict != null && dict[_currentLanguage] != null) {
      return '$leading${_matchCase(trimmed, dict[_currentLanguage]!)}$trailing';
    }
    final extDict = extendedNigerianDictionary[lower];
    if (extDict != null && extDict[_currentLanguage] != null) {
      return '$leading${_matchCase(trimmed, extDict[_currentLanguage]!)}$trailing';
    }

    // Handle "LABEL: value" patterns offline (e.g. "ROLE: OBSERVER", "PROVINCE: OWERRI")
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx > 1 && colonIdx < 28) {
      final prefix = trimmed.substring(0, colonIdx).trim();
      final rest = trimmed.substring(colonIdx + 1);
      final pLower = prefix.toLowerCase();
      final pVal = _phraseDictionary[pLower]?[_currentLanguage] ??
          extendedNigerianDictionary[pLower]?[_currentLanguage];
      if (pVal != null) {
        final translatedPrefix = _matchCase(prefix, pVal);
        return '$leading$translatedPrefix:$rest$trailing';
      }
    }

    // Handle "Reporting for <election>" prefix offline
    if (lower.startsWith('reporting for ')) {
      final rest = trimmed.substring('reporting for '.length);
      final pVal = extendedNigerianDictionary['reporting for']?[_currentLanguage];
      if (pVal != null) {
        return '$leading$pVal $rest$trailing';
      }
    }

    // Handle "Enter results for <election>" prefix offline
    if (lower.startsWith('enter results for ')) {
      final rest = trimmed.substring('enter results for '.length);
      final pVal =
          extendedNigerianDictionary['enter results for']?[_currentLanguage];
      if (pVal != null) {
        return '$leading$pVal $rest$trailing';
      }
    }

    final cached = _aiCache[_currentLanguage]?[trimmed];
    if (cached != null && cached.isNotEmpty) {
      return '$leading$cached$trailing';
    }

    return text;
  }

  /// Batch-translate dynamic Firestore strings (e.g. checklist questions & sections)
  /// in one fast Gemini JSON request and cache permanently offline.
  Future<void> translateBatch(Iterable<String> texts) async {
    final targetLang = _currentLanguage;
    if (targetLang == AppLanguage.en) return;
    final apiKey = _geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) return;

    final missing = <String>[];
    final seen = <String>{};
    for (final raw in texts) {
      final trimmed = raw.trim();
      if (trimmed.length < 2 || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      final lower = trimmed.toLowerCase();
      if (_phraseDictionary[lower]?[targetLang] != null) continue;
      if (extendedNigerianDictionary[lower]?[targetLang] != null) continue;
      if (_aiCache[targetLang]?[trimmed]?.isNotEmpty == true) continue;
      final inFlightKey = '${targetLang.name}::$trimmed';
      if (_inFlightBatchKeys.contains(inFlightKey) ||
          _attemptedBatchKeys.contains(inFlightKey)) {
        continue;
      }
      missing.add(trimmed);
    }

    if (missing.isEmpty) return;

    final targetName = _languagePromptNames[targetLang] ?? 'English';

    for (final s in missing) {
      final k = '${targetLang.name}::$s';
      _inFlightBatchKeys.add(k);
      _attemptedBatchKeys.add(k);
    }
    _isTranslating = true;
    notifyListeners();

    try {
      final modelsToTry = <String>{
        _geminiModel,
        'gemini-2.0-flash',
        'gemini-1.5-flash',
      }.toList();

      for (var i = 0; i < missing.length; i += 15) {
        final chunk = missing.sublist(
          i,
          (i + 15) > missing.length ? missing.length : (i + 15),
        );

        final prompt =
            'You are a professional Nigerian election observation UI translator.\n'
            'Translate this JSON array of English election checklist questions and labels into $targetName.\n'
            'STRICT RULES:\n'
            '1. Keep Nigerian election acronyms untouched (INEC, EC8A, BVAS, IREV, PU, LGA, PVC, APC, PDP, LP, NNPP).\n'
            '2. Keep translations clear, accurate, and concise.\n'
            '3. Return ONLY a valid JSON object mapping each exact original English string to its translation.\n\n'
            'INPUT STRINGS:\n${jsonEncode(chunk)}';

        bool chunkSucceeded = false;
        for (final model in modelsToTry) {
          try {
            final uri = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
            );
            final response = await http
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'contents': [
                      {
                        'parts': [
                          {'text': prompt}
                        ]
                      }
                    ],
                    'generationConfig': {
                      'temperature': 0.1,
                      'maxOutputTokens': 8192,
                      'responseMimeType': 'application/json',
                    },
                  }),
                )
                .timeout(const Duration(seconds: 25));

            if (response.statusCode != 200) continue;

            final data = jsonDecode(response.body);
            final rawOut = data['candidates']?[0]?['content']?['parts']?[0]
                    ?['text']
                ?.toString();
            if (rawOut == null || rawOut.isEmpty) continue;

            final cleaned = rawOut
                .replaceFirst(RegExp(r'^```json\s*', caseSensitive: false), '')
                .replaceFirst(RegExp(r'```\s*$'), '')
                .trim();

            Map<String, dynamic>? parsed;
            try {
              final decoded = jsonDecode(cleaned);
              if (decoded is Map<String, dynamic>) parsed = decoded;
            } catch (_) {
              // Resilient partial JSON recovery if model output was ever truncated
              final recovered = <String, dynamic>{};
              final pairRe = RegExp(r'"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"');
              for (final m in pairRe.allMatches(cleaned)) {
                try {
                  final k = jsonDecode('"${m.group(1)}"') as String;
                  final v = jsonDecode('"${m.group(2)}"') as String;
                  recovered[k] = v;
                } catch (_) {}
              }
              if (recovered.isNotEmpty) parsed = recovered;
            }

            if (parsed != null) {
              _aiCache[targetLang] ??= {};
              var added = 0;
              for (final key in chunk) {
                final val = parsed[key]?.toString().trim();
                if (val != null && val.isNotEmpty) {
                  _aiCache[targetLang]![key] = val;
                  added++;
                }
              }
              if (added > 0) {
                _cacheVersion++;
                await _saveAiCache(targetLang);
                chunkSucceeded = true;
                break;
              }
            }
          } catch (e) {
            debugPrint('[LanguageService] Batch failed on $model: $e');
          }
        }
        if (chunkSucceeded) {
          notifyListeners();
        }
      }
    } finally {
      for (final s in missing) {
        _inFlightBatchKeys.remove('${targetLang.name}::$s');
      }
      _isTranslating = false;
      notifyListeners();
    }
  }

  /// Dynamic on-demand Gemini AI translation for user-entered or Firestore text
  Future<String> translateDynamic(
    String text, {
    required String? geminiApiKey,
    String modelName = 'gemini-2.0-flash',
  }) async {
    if (_currentLanguage == AppLanguage.en) return text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;

    // 1. Check offline dictionary & cache first
    final syncHit = tr(trimmed);
    if (syncHit != trimmed) return syncHit;

    if (geminiApiKey == null || geminiApiKey.trim().isEmpty) return text;

    final targetName = _languagePromptNames[_currentLanguage] ?? 'English';

    _isTranslating = true;
    notifyListeners();
    try {
      final prompt =
          'Translate this Nigerian election observation text into $targetName. '
          'Keep acronyms like INEC, EC8A, BVAS, PU, LGA, APC, PDP, LP, NNPP untouched. '
          'Return ONLY the translated text without quotes or explanations.\n\n$trimmed';

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=${geminiApiKey.trim()}',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 512,
              }
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final out =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString().trim();
        if (out != null && out.isNotEmpty) {
          _aiCache[_currentLanguage] ??= {};
          _aiCache[_currentLanguage]![trimmed] = out;
          await _saveAiCache(_currentLanguage);
          return out;
        }
      }
    } catch (e) {
      debugPrint('[LanguageService] Dynamic translate error: $e');
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
    return text;
  }

  static const Map<String, Map<AppLanguage, String>> _phraseDictionary = {
    // Navigation & Tabs
    'observer dashboard': {
      AppLanguage.ha: 'ALLON MAI SA IDO',
      AppLanguage.yo: 'PÁTÁKÓ OLÙṢỌ́',
      AppLanguage.ig: 'BỌỌDỤ ONYE NLEBA ANYA',
      AppLanguage.pcm: 'OBSERVER MAIN BOARD',
    },
    'dashboard': {
      AppLanguage.ha: 'Allon Aiki',
      AppLanguage.yo: 'Pátákó',
      AppLanguage.ig: 'Bọọdụ',
      AppLanguage.pcm: 'Main Board',
    },
    'checklist': {
      AppLanguage.ha: 'Bincike',
      AppLanguage.yo: 'Àyẹ̀wò',
      AppLanguage.ig: 'Nlele',
      AppLanguage.pcm: 'Checklist (Wetin You Check)',
    },
    'incidents': {
      AppLanguage.ha: 'Rahotanni',
      AppLanguage.yo: 'Ìṣẹ̀lẹ̀',
      AppLanguage.ig: 'Ihe Mere',
      AppLanguage.pcm: 'Wahala / Incidents',
    },
    'results': {
      AppLanguage.ha: 'Sakamako',
      AppLanguage.yo: 'Èsì',
      AppLanguage.ig: 'Nsonaazụ',
      AppLanguage.pcm: 'Vote Results',
    },
    'election gallery': {
      AppLanguage.ha: 'Rumbun Zaɓe',
      AppLanguage.yo: 'Àkójọ Ìdìbò',
      AppLanguage.ig: 'Ebe Ntuli Aka',
      AppLanguage.pcm: 'All Elections Room',
    },
    'sync': {
      AppLanguage.ha: 'Daidaita',
      AppLanguage.yo: 'Múṣọ̀kan',
      AppLanguage.ig: 'Mekọrịta',
      AppLanguage.pcm: 'Sync Data',
    },
    'logout': {
      AppLanguage.ha: 'Fita',
      AppLanguage.yo: 'Jáde',
      AppLanguage.ig: 'Pụọ',
      AppLanguage.pcm: 'Log Out',
    },
    'settings': {
      AppLanguage.ha: 'Saituna',
      AppLanguage.yo: 'Ètò',
      AppLanguage.ig: 'Ntọala',
      AppLanguage.pcm: 'App Settings',
    },
    'notifications': {
      AppLanguage.ha: 'Sanarwa',
      AppLanguage.yo: 'Ìfitónilétí',
      AppLanguage.ig: 'Ọkwa',
      AppLanguage.pcm: 'Alerts & Messages',
    },

    // Login
    'election portal for voteguard': {
      AppLanguage.ha: 'SHAFIN SA IDO NA ZAɓE NA VOTEGUARD',
      AppLanguage.yo: 'IBÙDÓ ÌDÌBÒ FÚN VOTEGUARD',
      AppLanguage.ig: 'PỌTAL NTULI AKA NKE VOTEGUARD',
      AppLanguage.pcm: 'VOTEGUARD ELECTION OBSERVATION PORTAL',
    },
    'email / phone number': {
      AppLanguage.ha: 'Imel / Lambar Waya',
      AppLanguage.yo: 'Ímeèlì / Nọ́mbà Fóònù',
      AppLanguage.ig: 'Email / Nọmba Ekwentị',
      AppLanguage.pcm: 'Email or Phone Number',
    },
    'email/phone number': {
      AppLanguage.ha: 'Imel/Lambar Waya',
      AppLanguage.yo: 'Ímeèlì/Nọ́mbà Fóònù',
      AppLanguage.ig: 'Email/Nọmba Ekwentị',
      AppLanguage.pcm: 'Email or Phone Number',
    },
    'password': {
      AppLanguage.ha: 'Kalmar Sirri',
      AppLanguage.yo: 'Ọ̀rọ̀ Aṣínà',
      AppLanguage.ig: 'Okwuntughe',
      AppLanguage.pcm: 'Secret Password',
    },
    'sign in': {
      AppLanguage.ha: 'Shiga',
      AppLanguage.yo: 'Wọlé',
      AppLanguage.ig: 'Banye',
      AppLanguage.pcm: 'Enter Inside',
    },
    'login': {
      AppLanguage.ha: 'Shiga',
      AppLanguage.yo: 'Wọlé',
      AppLanguage.ig: 'Banye',
      AppLanguage.pcm: 'Enter Inside',
    },
    'forgot password?': {
      AppLanguage.ha: 'An Manta Kalmar Sirri?',
      AppLanguage.yo: 'Ṣé O Gbàgbé Ọ̀rọ̀ Aṣínà?',
      AppLanguage.ig: 'Chefuru Okwuntughe?',
      AppLanguage.pcm: 'You Forget Password?',
    },

    // Results & EC8A
    'result sheet (ec8a)': {
      AppLanguage.ha: 'Takardar Sakamako (EC8A)',
      AppLanguage.yo: 'Ìwé Èsì (EC8A)',
      AppLanguage.ig: 'Akwụkwọ Nsonaazụ (EC8A)',
      AppLanguage.pcm: 'Result Paper (EC8A)',
    },
    'election results': {
      AppLanguage.ha: 'Sakamakon Zaɓe',
      AppLanguage.yo: 'Èsì Ìdìbò',
      AppLanguage.ig: 'Nsonaazụ Ntuli Aka',
      AppLanguage.pcm: 'Party Vote Counts',
    },
    'voter statistics (ec8a)': {
      AppLanguage.ha: 'Ƙididdigar Masu Zaɓe (EC8A)',
      AppLanguage.yo: 'Ìṣirò Olùdìbò (EC8A)',
      AppLanguage.ig: 'Ọnụọgụgụ Ndị Ntuli Aka (EC8A)',
      AppLanguage.pcm: 'Voter Numbers (EC8A)',
    },
    'rescan sheet': {
      AppLanguage.ha: 'Sake Duba Takarda',
      AppLanguage.yo: 'Tún Ìwé Yẹ̀ Wò',
      AppLanguage.ig: 'Nyochaa Akwụkwọ Ọzọ',
      AppLanguage.pcm: 'Scan Sheet Again',
    },
    'delete submission & unlock': {
      AppLanguage.ha: 'Goge Aikewa & Buɗe',
      AppLanguage.yo: 'Pa Ìfisílẹ̀ Rẹ́ & Ṣí',
      AppLanguage.ig: 'Hichapụ Nzipu & Mepee',
      AppLanguage.pcm: 'Delete & Unlock Submission',
    },
    'final submission': {
      AppLanguage.ha: 'Aikewa ta Ƙarshe',
      AppLanguage.yo: 'Ìfisílẹ̀ Ìkẹyìn',
      AppLanguage.ig: 'Nzipu Ikpeazụ',
      AppLanguage.pcm: 'Final Submit',
    },
    'cancel': {
      AppLanguage.ha: 'Soke',
      AppLanguage.yo: 'Fagilé',
      AppLanguage.ig: 'Kagbuo',
      AppLanguage.pcm: 'Leave Am',
    },
    'delete': {
      AppLanguage.ha: 'Goge',
      AppLanguage.yo: 'Pa Rẹ́',
      AppLanguage.ig: 'Hichapụ',
      AppLanguage.pcm: 'Comot Am',
    },
    'submit': {
      AppLanguage.ha: 'Aika',
      AppLanguage.yo: 'Fi Ránṣẹ́',
      AppLanguage.ig: 'Zipu',
      AppLanguage.pcm: 'Send Am',
    },
    'save': {
      AppLanguage.ha: 'Ajiye',
      AppLanguage.yo: 'Fi Pamọ́',
      AppLanguage.ig: 'Chekwaa',
      AppLanguage.pcm: 'Keep Am',
    },
    'language': {
      AppLanguage.ha: 'Harshe',
      AppLanguage.yo: 'Èdè',
      AppLanguage.ig: 'Asụsụ',
      AppLanguage.pcm: 'App Language',
    },
    'select language': {
      AppLanguage.ha: 'Zaɓi Harshe',
      AppLanguage.yo: 'Yan Èdè',
      AppLanguage.ig: 'Họrọ Asụsụ',
      AppLanguage.pcm: 'Choose Language',
    },

    // Checklist UI Labels
    'checklist finalized': {
      AppLanguage.ha: 'AN KAMMALA JERIN BINCIKE',
      AppLanguage.yo: 'A TI PARÍ ÀKÓJỌ ÀYẸ̀WÒ',
      AppLanguage.ig: 'EMECHARA NDEPỤTA NLELE',
      AppLanguage.pcm: 'CHECKLIST DON SUBMIT',
    },
    'all responses are now locked for synchronization.': {
      AppLanguage.ha: 'An kulle dukkan amsoshi don daidaitawa.',
      AppLanguage.yo: 'A ti tì gbogbo ìdáhùn fún ìmúṣọ̀kan.',
      AppLanguage.ig: 'Akpọchiela azịza niile maka mmekọrịta.',
      AppLanguage.pcm: 'All your answers don lock for sync.',
    },
    'auto-draft saved — not yet finally submitted': {
      AppLanguage.ha: 'AN AJIYE DAFTARI — BA A AIKA TA ƘARSHE BA TUKUNA',
      AppLanguage.yo: 'A TI FI ÀKỌSÍLẸ̀ PAMỌ́ — A KÒ TÍÌ FI RÁNṢẸ́ NÍ ÌKẸYÌN',
      AppLanguage.ig: 'ECHEWARA NDETU — EZIPỤBEGHỊ YA N\'IKPEAZỤ',
      AppLanguage.pcm: 'AUTO-DRAFT SAVED — YOU NEVER FINALLY SUBMIT AM',
    },
    'completion tracker': {
      AppLanguage.ha: 'BINCIKEN CI GABA',
      AppLanguage.yo: 'ÒṢÙWỌ̀N ÌPARÍ',
      AppLanguage.ig: 'NSOCHI MMECHA',
      AppLanguage.pcm: 'PROGRESS CHECKER',
    },
    'questions answered': {
      AppLanguage.ha: 'Tambayoyin da Aka Amsa',
      AppLanguage.yo: 'Àwọn Ìbéèrè Tí A Dáhùn',
      AppLanguage.ig: 'Ajụjụ A Zara',
      AppLanguage.pcm: 'Questions Wey You Don Answer',
    },
    'live connection': {
      AppLanguage.ha: 'AKWAI INTANET',
      AppLanguage.yo: 'ÍŃTÁNẸ́Ẹ̀TÌ Ń ṢIṢẸ́',
      AppLanguage.ig: 'NETWỌK DỊ',
      AppLanguage.pcm: 'NETWORK DEY',
    },
    'offline connection': {
      AppLanguage.ha: 'BABU INTANET',
      AppLanguage.yo: 'KÒ SÍ ÍŃTÁNẸ́Ẹ̀TÌ',
      AppLanguage.ig: 'ENWEGHỊ NETWỌK',
      AppLanguage.pcm: 'NO NETWORK (OFFLINE)',
    },
    'direct observation': {
      AppLanguage.ha: 'SA IDO KAI TSAYE',
      AppLanguage.yo: 'ÌṢỌ́ TÀÀRÀ',
      AppLanguage.ig: 'NLEBA ANYA KPỌMKWEM',
      AppLanguage.pcm: 'DIRECT CHECK',
    },
    'standard metric': {
      AppLanguage.ha: 'MA\'AUNI NA YAU DA KULLUM',
      AppLanguage.yo: 'ÒṢÙWỌ̀N ÀṢÀ',
      AppLanguage.ig: 'Ọ̀TỤ̀TỤ̀ IWU',
      AppLanguage.pcm: 'STANDARD CHECK',
    },
    'media evidence': {
      AppLanguage.ha: 'SHAIDAR HOTO/BIDIYO',
      AppLanguage.yo: 'Ẹ̀RÍ FỌ́TÒ/FÍDÍÒ',
      AppLanguage.ig: 'IHE AKA EBE FOTO/VIDIO',
      AppLanguage.pcm: 'PHOTO / VIDEO PROOF',
    },
    'time record': {
      AppLanguage.ha: 'RIJISTAR LOKACI',
      AppLanguage.yo: 'ÀKỌSÍLẸ̀ ÀKÓKÒ',
      AppLanguage.ig: 'NDEKỌ OGE',
      AppLanguage.pcm: 'Time Wey You Put',
    },
    'required': {
      AppLanguage.ha: 'DOLE NE',
      AppLanguage.yo: 'PÀTÀKÌ',
      AppLanguage.ig: 'Ọ DỊ MKPA',
      AppLanguage.pcm: 'MUST FILL',
    },
    'optional': {
      AppLanguage.ha: 'NA ZAƁI',
      AppLanguage.yo: 'KÌ Í ṢE PÀTÀKÌ',
      AppLanguage.ig: 'NHỌRỌ',
      AppLanguage.pcm: 'If You Like (Optional)',
    },
    'yes': {
      AppLanguage.ha: 'Eh',
      AppLanguage.yo: 'Bẹ́ẹ̀ ni',
      AppLanguage.ig: 'Ee',
      AppLanguage.pcm: 'Yes (Na So)',
    },
    'no': {
      AppLanguage.ha: 'A\'a',
      AppLanguage.yo: 'Rárá',
      AppLanguage.ig: 'Mba',
      AppLanguage.pcm: 'No (No Be So)',
    },
    'undecided': {
      AppLanguage.ha: 'Ban Tabbatar Ba',
      AppLanguage.yo: 'Kò Dájú',
      AppLanguage.ig: 'Emeghị Mkpebi',
      AppLanguage.pcm: 'Not Sure',
    },
    'replace media': {
      AppLanguage.ha: 'SAUYA HOTO/BIDIYO',
      AppLanguage.yo: 'PÀÀRỌ̀ FỌ́TÒ/FÍDÍÒ',
      AppLanguage.ig: 'Gbanwee Foto/Vidio',
      AppLanguage.pcm: 'CHANGE PHOTO/VIDEO',
    },
    'add photo/video': {
      AppLanguage.ha: 'ƘARA HOTO/BIDIYO',
      AppLanguage.yo: 'FI FỌ́TÒ/FÍDÍÒ KÚN',
      AppLanguage.ig: 'TINYE FOTO/VIDIO',
      AppLanguage.pcm: 'Add Picture / Video',
    },
    'translating checklist...': {
      AppLanguage.ha: 'Ana fassara tambayoyin bincike...',
      AppLanguage.yo: 'Ń túmọ̀ àwọn ìbéèrè àyẹ̀wò...',
      AppLanguage.ig: 'Na-asụgharị ajụjụ nlele...',
      AppLanguage.pcm: 'Dey translate checklist questions...',
    },

    // Election Gallery & Polling Unit Assignment
    'observer command center': {
      AppLanguage.ha: 'CIBIYAR MAI SA IDO',
      AppLanguage.yo: 'IBÙDÓ ÀṢẸ OLÙṢỌ́',
      AppLanguage.ig: 'EBE NCHỊKWA ONYE NLEBA ANYA',
      AppLanguage.pcm: 'Observer Control Room',
    },
    'choose an election to start observing': {
      AppLanguage.ha: 'Zaɓi Zaɓe Don Fara Sa Ido',
      AppLanguage.yo: 'Yan Ìdìbò Kan Láti Bẹ̀rẹ̀ Ìṣọ́',
      AppLanguage.ig: 'Họrọ Ntuli Aka Iji Malite Nleba Anya',
      AppLanguage.pcm: 'Pick Election Wey You Wan Observe',
    },
    'select your polling unit': {
      AppLanguage.ha: 'ZAƁI RUKUNIN ZAƁENKA',
      AppLanguage.yo: 'YAN IBÙDÓ ÌDÌBÒ RẸ',
      AppLanguage.ig: 'HỌRỌ EBE NTULI AKA GỊ',
      AppLanguage.pcm: 'PICK YOUR POLLING UNIT',
    },
    'change unit': {
      AppLanguage.ha: 'SAUYA RUKUNI',
      AppLanguage.yo: 'PÀÀRỌ̀ IBÙDÓ',
      AppLanguage.ig: 'GBANWEE EBE',
      AppLanguage.pcm: 'Change Polling Unit',
    },
    'state': {
      AppLanguage.ha: 'JIHA',
      AppLanguage.yo: 'ÌPÍNLẸ̀',
      AppLanguage.ig: 'STEETI',
      AppLanguage.pcm: 'State (Jiha)',
    },
    'ward': {
      AppLanguage.ha: 'GUNDUMA',
      AppLanguage.yo: 'WỌ́Ọ̀DÙ',
      AppLanguage.ig: 'WỌỌDỤ',
      AppLanguage.pcm: 'Ward (Area)',
    },
    'polling unit': {
      AppLanguage.ha: 'RUKUNIN ZAƁE',
      AppLanguage.yo: 'IBÙDÓ ÌDÌBÒ',
      AppLanguage.ig: 'EBE NTULI AKA',
      AppLanguage.pcm: 'Polling Unit (Vote Spot)',
    },
    'province': {
      AppLanguage.ha: 'LARDI',
      AppLanguage.yo: 'AGBÈGBÈ',
      AppLanguage.ig: 'MPAĞHARA',
      AppLanguage.pcm: 'Province (Zone)',
    },
    'location verified': {
      AppLanguage.ha: 'AN TABBATAR DA WURI',
      AppLanguage.yo: 'A TI JẸ́RÌÍSÍ IPÒ',
      AppLanguage.ig: 'AKWADORO EBE A',
      AppLanguage.pcm: 'LOCATION DON VERIFY',
    },
    'your elections': {
      AppLanguage.ha: 'ZAƁUƁƁUKANKA',
      AppLanguage.yo: 'ÀWỌN ÌDÌBÒ RẸ',
      AppLanguage.ig: 'NTULI AKA GỊ',
      AppLanguage.pcm: 'Elections Wey Concern You',
    },
    'active': {
      AppLanguage.ha: 'NA YANZU',
      AppLanguage.yo: 'LỌ́WỌ́LỌ́WỌ́',
      AppLanguage.ig: 'UGBU A',
      AppLanguage.pcm: 'Dey Go On',
    },
    'upcoming': {
      AppLanguage.ha: 'MAI ZUWA',
      AppLanguage.yo: 'TÓ Ń BỌ̀',
      AppLanguage.ig: 'NA-ABỊA',
      AppLanguage.pcm: 'COMING SOON',
    },
    'completed': {
      AppLanguage.ha: 'AN KAMMALA',
      AppLanguage.yo: 'TI PARÍ',
      AppLanguage.ig: 'EMECHARA',
      AppLanguage.pcm: 'DONE',
    },
    'start observing': {
      AppLanguage.ha: 'FARA SA IDO',
      AppLanguage.yo: 'BẸ̀RẸ̀ ÌṢỌ́',
      AppLanguage.ig: 'MALITE NLEBA ANYA',
      AppLanguage.pcm: 'Start To Observe',
    },
    'continue observing': {
      AppLanguage.ha: 'CI GABA DA SA IDO',
      AppLanguage.yo: 'TẸ̀SÍWÁJÚ NÍ ÌṢỌ́',
      AppLanguage.ig: 'GAA N\'IHU N\'ILEBA ANYA',
      AppLanguage.pcm: 'Continue To Observe',
    },
    'save assignment': {
      AppLanguage.ha: 'Ajiye Wurin Aiki',
      AppLanguage.yo: 'Fi Ibùdó Pamọ́',
      AppLanguage.ig: 'Chekwaa Ebe Ọrụ',
      AppLanguage.pcm: 'Save Polling Unit',
    },
    'role': {
      AppLanguage.ha: 'Matsayi',
      AppLanguage.yo: 'Ipò',
      AppLanguage.ig: 'Ọrụ',
      AppLanguage.pcm: 'Your Work',
      AppLanguage.tiv: 'Tom',
      AppLanguage.kr: 'Cida',
      AppLanguage.ff: 'Kuugal',
      AppLanguage.ibb: 'Utom',
      AppLanguage.efi: 'Utom',
      AppLanguage.ijc: 'Furo',
      AppLanguage.bin: 'Iwinna',
      AppLanguage.urh: 'Iruo',
      AppLanguage.nup: 'Etun',
      AppLanguage.idu: 'Uklo',
      AppLanguage.igl: 'Ukọlọ',
      AppLanguage.igb: 'Ukọ',
      AppLanguage.its: 'Uṣẹ',
      AppLanguage.ish: 'Iwinna',
      AppLanguage.gbr: 'Tnutnu',
    },
    'select your polling ...': {
      AppLanguage.ha: 'ZAƁI RUKUNIN ZAƁE...',
      AppLanguage.yo: 'YAN IBÙDÓ ÌDÌBÒ...',
      AppLanguage.ig: 'HỌRỌ EBE NTULI AKA...',
      AppLanguage.pcm: 'PICK POLLING UNIT...',
      AppLanguage.tiv: 'TSUA IJIIR I SHIA...',
      AppLanguage.kr: 'KARNO WURIN KARNO...',
      AppLanguage.ff: 'SUƁU NOKKUURE...',
    },
    'select your polling unit assignment': {
      AppLanguage.ha: 'Zaɓi Rukunin Zaɓenka',
      AppLanguage.yo: 'Yan Ibùdó Ìdìbò Rẹ',
      AppLanguage.ig: 'Họrọ Ebe Ntuli Aka Gị',
      AppLanguage.pcm: 'Pick Your Polling Unit',
      AppLanguage.tiv: 'Tsua Ijiir You I Shia',
      AppLanguage.kr: 'Karno Wurin Karno Nəm',
      AppLanguage.ff: 'Suɓu Nokkuure Cuɓol Maa',
    },
    'no active elections': {
      AppLanguage.ha: 'Babu Zaɓe da ke Gudana',
      AppLanguage.yo: 'Kò Sí Ìdìbò Tó Ń Lọ',
      AppLanguage.ig: 'Enweghị Ntuli Aka Na-aga',
      AppLanguage.pcm: 'No Active Election Now',
    },
    'no upcoming elections': {
      AppLanguage.ha: 'Babu Zaɓe Mai Zuwa',
      AppLanguage.yo: 'Kò Sí Ìdìbò Tó Ń Bọ̀',
      AppLanguage.ig: 'Enweghị Ntuli Aka Na-abịa',
      AppLanguage.pcm: 'No Upcoming Election',
    },
    'no completed elections': {
      AppLanguage.ha: 'Babu Zaɓe da Aka Kammala',
      AppLanguage.yo: 'Kò Sí Ìdìbò Tó Ti Parí',
      AppLanguage.ig: 'Enweghị Ntuli Aka Emechara',
      AppLanguage.pcm: 'No Completed Election',
    },
    'elections': {
      AppLanguage.ha: 'Zaɓuɓɓuka',
      AppLanguage.yo: 'Àwọn Ìdìbò',
      AppLanguage.ig: 'Ntuli Aka',
      AppLanguage.pcm: 'All Elections',
      AppLanguage.tiv: 'Ushia',
      AppLanguage.kr: 'Karno',
      AppLanguage.ff: 'Cuɓol',
    },
    'election': {
      AppLanguage.ha: 'Zaɓe',
      AppLanguage.yo: 'Ìdìbò',
      AppLanguage.ig: 'Ntuli Aka',
      AppLanguage.pcm: 'Vote Election',
      AppLanguage.tiv: 'Shia',
      AppLanguage.kr: 'Karno',
      AppLanguage.ff: 'Cuɓol',
    },
  };
}

extension LanguageContextExt on BuildContext {
  String tr(String text) => watch<LanguageService>().tr(text);
  String trRead(String text) => read<LanguageService>().tr(text);
}

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Top-level isolate function to compress/normalize image bytes for Gemini Vision
/// without blocking the main UI thread or spiking memory on low-RAM devices (e.g. Tecno Spark).
/// Keeps up to 1600px on the longest side at JPEG quality 85 so every handwritten
/// digit on INEC Form EC8A remains crystal-clear.
Uint8List _prepareImageForGeminiIsolate(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'] as Uint8List;
  final int rotateDegrees = params['rotateDegrees'] as int? ?? 0;

  // Fast path: if no rotation requested and already a crisp JPEG under 450KB,
  // send directly without re-decoding or degrading quality.
  final bool isJpeg = rawBytes.length >= 2 &&
      rawBytes[0] == 0xFF &&
      rawBytes[1] == 0xD8;
  if (rotateDegrees == 0 && isJpeg && rawBytes.lengthInBytes <= 450 * 1024) {
    return rawBytes;
  }

  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;

  img.Image processed = img.bakeOrientation(decoded);

  if (rotateDegrees == 90 || rotateDegrees == 180 || rotateDegrees == 270) {
    processed = img.copyRotate(processed, angle: rotateDegrees);
  }

  const int maxDim = 1600;
  if (processed.width > maxDim || processed.height > maxDim) {
    if (processed.width >= processed.height) {
      processed = img.copyResize(
        processed,
        width: maxDim,
        interpolation: img.Interpolation.cubic,
      );
    } else {
      processed = img.copyResize(
        processed,
        height: maxDim,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  final compressed = img.encodeJpg(processed, quality: 85);
  return Uint8List.fromList(compressed);
}

class AIService with ChangeNotifier {
  String? _apiKey;
  String _primaryModelName = 'gemini-2.5-flash';
  static const _nanoChannel = MethodChannel('com.voteguard/gemini_nano');

  AIService({String? apiKey}) : _apiKey = apiKey;

  String get currentModelName => _primaryModelName;

  /// Checks if the current device supports on-device Gemini Nano (AICore)
  Future<bool> isNanoSupported() async {
    try {
      if (!Platform.isAndroid) return false;
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final model = androidInfo.model.toUpperCase();

      final supportedSeries = [
        'PIXEL 8',
        'PIXEL 9',
        'PIXEL 10',
        'S24',
        'S25',
        'S26',
        'FOLD 6',
        'FOLD 7'
      ];
      return supportedSeries.any((s) => model.contains(s));
    } catch (e) {
      return false;
    }
  }

  void setApiKey(String key) {
    final trimmed = key.trim();
    if (_apiKey == trimmed) return;
    _apiKey = trimmed;
    notifyListeners();
  }

  void setPrimaryModel(String modelName) {
    final trimmed = modelName.trim();
    if (trimmed.isEmpty || _primaryModelName == trimmed) return;
    _primaryModelName = trimmed;
    notifyListeners();
  }

  /// Ensures API key & model config are loaded from Firestore if not yet set.
  Future<void> _ensureApiKeyLoaded() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('system_settings')
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists) {
        final valueStr = doc.data()?['value'] as String?;
        if (valueStr != null && valueStr.isNotEmpty) {
          final valueJson = jsonDecode(valueStr);
          final key = valueJson['ai']?['gemini_api_key'] ??
              valueJson['gemini_api_key'];
          if (key != null && key.toString().trim().isNotEmpty) {
            setApiKey(key.toString().trim());
          }
          final modelId = valueJson['ai']?['ocrModel'];
          if (modelId != null && modelId.toString().trim().isNotEmpty) {
            setPrimaryModel(modelId.toString().trim());
          }
        }
      }
    } catch (e) {
      debugPrint('AIService: Could not lazy-load API key from Firestore: $e');
    }
  }

  static String _buildEC8APrompt(List<String> partyAbbreviations) {
    final activePartyList = partyAbbreviations.join(', ');
    return '''
You are an expert INEC Form EC8A election result sheet reader for Nigeria.

Examine the uploaded image carefully. If the image is slightly tilted or rotated, mentally orient it upright before reading.

STEP 1 — Identify the election type printed on the form header/title.
Look for text near the top of the form such as "PRESIDENTIAL ELECTION", "GOVERNORSHIP ELECTION", "SENATORIAL DISTRICT ELECTION", "HOUSE OF REPRESENTATIVES ELECTION", "STATE HOUSE OF ASSEMBLY ELECTION", "CHAIRMANSHIP ELECTION", "COUNCILLORSHIP ELECTION", etc.
Ignore the "LOCAL GOVERNMENT AREA" address label in the polling unit location box.
Return this as "electionType" using one of: PRESIDENTIAL, GUBERNATORIAL, SENATORIAL, HOUSE OF REPS, STATE ASSEMBLY, LOCAL GOVERNMENT, COUNCILLOR. (Return "" if unclear.)

STEP 2 — Identify the election year printed on the form header/title.
Extract the 4-digit year printed directly next to or above the election type in the form title/header, e.g. from "2026 PRESIDENTIAL ELECTION" the year is 2026.
DO NOT use the date from the presiding/polling officer signature, stamp, or certification at the bottom of the form.
Return as "electionYear" (integer).

STEP 3 — Extract INEC Voter & Ballot Statistics from the upper section of the form:
On Form EC8A, the statistics table has numbered items (1 to 8) on the left and handwritten figures in boxes on the right. DO NOT confuse the item numbers (1, 2, 3, 4, 5, 6, 7, 8) with the figures written in the boxes on the right:
  - "votersInRegister": Item 1 — Number of Voters on the Register
  - "accreditedVoters": Item 2 — Number of Accredited Voters
  - "ballotsIssued": Item 3 — Number of Ballot Papers Issued to the Polling Unit
  - "unusedBallots": Item 4 — Number of Unused Ballot Papers
  - "spoiledBallots": Item 5 — Number of Spoiled Ballot Papers
  - "rejectedBallots": Item 6 — Number of Rejected Ballots
  - "totalValidVotes": Item 7 — Number of Total Valid Votes (Total Valid Votes Cast for all Parties)
  - "totalUsedBallots": Item 8 — Total Number of Used Ballot Papers (Total of 5 + 6 + 7)
If any box shows "NIL", "NONE", "-", "==", or is blank, return 0 for that field. Strip leading zeros (e.g. "005" -> 5).

STEP 4 — Extract Political Party Votes from the RESULTS TABLE.
The results table lists political parties row by row with columns in this order:
  - Col A: S/N (Serial Number 1, 2, 3, 4...) — NEVER read this column as a vote count!
  - Col B: Political Party Logo / Abbreviation (e.g. A, AA, AAC, ADC, ADP, APC, APGA, APM, APP, BP, LP, NNPP, NRM, PDP, PRP, SDP, YPP, YP, ZLP)
  - Col C: Party Full Name (if present on this form variant)
  - Col D: VOTES SCORED (In Figures) ← THIS IS THE PRIMARY COLUMN YOU MUST READ
  - Col E: VOTES SCORED (In Words) ← Use this column to cross-verify the handwritten number in Col D!

Strict accuracy rules for party votes:
1. Follow each horizontal row carefully from the Party Abbreviation in Col B across to its exact cell in Col D ("VOTES SCORED In Figures") and Col E ("VOTES SCORED In Words"). Do NOT shift values up or down between adjacent party rows.
2. Cross-verify Col D (In Figures) with Col E (In Words) on the same row. If handwriting in Col D is ambiguous (for example, "15" vs "75", or "0" vs "6"), use the words written in Col E (e.g. "SEVENTY FIVE" or "ZERO" / "NIL") to determine the exact integer.
3. If Col D or Col E contains "NIL", "NONE", "ZERO", "-", "--", "==", or is blank/empty, the vote is 0.
4. Strip any leading zeros from figures (e.g. "00" -> 0, "02" -> 2, "086" -> 86).
5. Cross-check that the sum of all party votes matches "totalValidVotes" (if written on the sheet).
6. Extract votes for these official party abbreviations: $activePartyList. Use exact party abbreviations as keys inside the "partyVotes" map. If a party is not on the sheet or has no votes, set its value to 0.

STEP 5 — Detect image rotation.
If the whole form image is sideways or upside-down, set "suggestedRotation" to the clockwise angle (90, 180, or 270) needed to make it upright. Otherwise set "suggestedRotation" to 0.

Return ONLY a valid JSON object in this exact structure:
{
  "electionType": "PRESIDENTIAL",
  "electionYear": 2026,
  "votersInRegister": 1615,
  "accreditedVoters": 892,
  "ballotsIssued": 900,
  "unusedBallots": 8,
  "spoiledBallots": 0,
  "rejectedBallots": 0,
  "totalValidVotes": 892,
  "totalUsedBallots": 892,
  "suggestedRotation": 0,
  "partyVotes": {
    "APC": 86,
    "PDP": 2,
    "LP": 0
  }
}
''';
  }

  Future<AIResult> processEC8A(
      File imageFile, [List<String>? partyAbbreviations]) async {
    final activeParties =
        partyAbbreviations ?? ['APC', 'PDP', 'LP', 'NNPP', 'APGA'];

    await _ensureApiKeyLoaded();

    if (_primaryModelName == 'mlkit') {
      debugPrint(
          'ML Kit forced as primary model. Using Optimized Offline OCR...');
      return processEC8ALocal(imageFile, activeParties);
    }

    if (await isNanoSupported()) {
      try {
        debugPrint(
            'High-end device detected. Attempting Gemini Nano (On-Device)...');
        final data = await _processWithNano(imageFile, activeParties);
        if (data != null) {
          _logUsage('GEMINI_NANO', true);
          return AIResult(
              data: _normalizeExtractedData(data, activeParties),
              modelName: 'Gemini Nano (On-Device)');
        }
      } catch (nanoError) {
        debugPrint('Gemini Nano failed: $nanoError. Falling back to Cloud...');
      }
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
          'Smart Optical Scanner (online) API Key not configured. Please check System Settings.');
    }

    // Prepare crisp 1600px JPEG in a background isolate so UI never stutters on Tecno Spark
    final rawFileBytes = await imageFile.readAsBytes();
    Uint8List preparedBytes = await compute(_prepareImageForGeminiIsolate, {
      'bytes': rawFileBytes,
      'rotateDegrees': 0,
    });
    debugPrint(
        'VoteGuard AI: Prepared EC8A image payload (${(rawFileBytes.lengthInBytes / 1024).toStringAsFixed(1)}KB -> ${(preparedBytes.lengthInBytes / 1024).toStringAsFixed(1)}KB)');

    // Build prioritized list of Gemini Vision models (matching Web App fallback chain)
    final candidateModels = <String>{
      if (_primaryModelName.isNotEmpty && _primaryModelName != 'mlkit')
        _primaryModelName,
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash-latest',
    }.toList();

    Object? lastError;

    for (final modelName in candidateModels) {
      try {
        debugPrint('VoteGuard AI: Calling Gemini model "$modelName"...');
        Map<String, dynamic> data = await _callGeminiRestApi(
          modelName: modelName,
          imageBytes: preparedBytes,
          partyAbbreviations: activeParties,
        );

        // Check if Gemini detected the photo is sideways/upside-down (90, 180, 270)
        final int suggestedRotation = _parseIntSafe(
            data['suggestedRotation'] ?? data['metadata']?['suggestedRotation']);
        if (suggestedRotation == 90 ||
            suggestedRotation == 180 ||
            suggestedRotation == 270) {
          debugPrint(
              'VoteGuard AI: $modelName detected $suggestedRotation° rotation. Auto-rotating upright and re-scanning...');
          final rotatedBytes = await compute(_prepareImageForGeminiIsolate, {
            'bytes': rawFileBytes,
            'rotateDegrees': suggestedRotation,
          });
          // Also persist upright image to file so the observer's preview is upright
          try {
            await imageFile.writeAsBytes(rotatedBytes);
          } catch (_) {}
          data = await _callGeminiRestApi(
            modelName: modelName,
            imageBytes: rotatedBytes,
            partyAbbreviations: activeParties,
          );
        }

        final normalized = _normalizeExtractedData(data, activeParties);
        _logUsage(modelName, true);
        return AIResult(data: normalized, modelName: modelName);
      } catch (e) {
        lastError = e;
        final errStr = e.toString();
        debugPrint('VoteGuard AI: Model "$modelName" failed: $errStr');
        // Stop trying other Gemini models only if API key itself is invalid/forbidden
        if (errStr.contains('HTTP_401') || errStr.contains('HTTP_403')) {
          break;
        }
      }
    }

    _logUsage(_primaryModelName, false, lastError?.toString());
    throw lastError ??
        Exception('Failed to extract EC8A data via Gemini Vision.');
  }

  /// Calls the Gemini REST API directly (identical to VoteGuardWeb) with:
  /// - Image inline_data placed FIRST before text prompt
  /// - temperature: 0 for 100% deterministic digit extraction
  /// - responseMimeType: "application/json"
  /// - Safe filtering of Gemini 2.5/3.x "thought" parts
  Future<Map<String, dynamic>> _callGeminiRestApi({
    required String modelName,
    required Uint8List imageBytes,
    required List<String> partyAbbreviations,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_apiKey',
    );
    final prompt = _buildEC8APrompt(partyAbbreviations);
    final base64Image = base64Encode(imageBytes);

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {'text': prompt},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    });

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode != 200) {
      String apiMsg = 'HTTP_${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        final errDetail = errJson['error']?['message'];
        if (errDetail != null) {
          apiMsg = 'HTTP_${response.statusCode}: $errDetail';
        }
      } catch (_) {}
      throw Exception(apiMsg);
    }

    final decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decodedResponse['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty candidates from Gemini ($modelName)');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? [];

    // Filter out internal thinking parts (part['thought'] == true) in Gemini 2.5 / 3.x models
    String rawJsonText = '';
    for (final part in parts) {
      if (part is Map) {
        if (part['thought'] == true) continue;
        final text = part['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          rawJsonText += text;
        }
      }
    }

    // Fallback if all parts were marked or single part
    if (rawJsonText.isEmpty && parts.isNotEmpty) {
      rawJsonText = parts.last['text']?.toString() ?? '';
    }

    final parsed = _parseLLMJson(rawJsonText);
    if (parsed == null) {
      throw Exception('Failed to parse JSON from $modelName response');
    }
    return parsed;
  }

  Map<String, dynamic>? _parseLLMJson(String text) {
    if (text.trim().isEmpty) return null;
    String cleaned = text
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      cleaned = cleaned.substring(startIdx, endIdx + 1);
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('AIService: JSON parse error: $e | raw: $cleaned');
      return null;
    }
  }

  static int _parseIntSafe(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.round();
    final str = val.toString().trim().toUpperCase();
    if (str.isEmpty ||
        str == 'NIL' ||
        str == 'NONE' ||
        str == 'NULL' ||
        str == '==' ||
        str == '-' ||
        str == '--') {
      return 0;
    }
    final digitsOnly = str.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return 0;
    return int.tryParse(digitsOnly) ?? 0;
  }

  static bool _isValidVoteCount(int n) {
    return n >= 0 && n < 500000;
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[m][n];
  }

  static String? _findBestPartyMatch(
      String ocrKey, List<String> activeParties) {
    final cleanKey =
        ocrKey.toUpperCase().trim().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleanKey.isEmpty) return null;

    // 1. Direct exact match
    for (final p in activeParties) {
      if (p.toUpperCase().trim() == cleanKey) return p;
    }

    // 2. Common OCR single-character alias corrections (same as VoteGuardWeb)
    const commonCorrections = <String, String>{
      'AP': 'APP',
      'APG': 'APGA',
      'NNP': 'NNPP',
      'NPP': 'NNPP',
      'PD': 'PDP',
      'PDD': 'PDP',
      'LPP': 'LP',
      'LPA': 'LP',
      'ACCC': 'ACC',
    };
    final mapped = commonCorrections[cleanKey];
    if (mapped != null) {
      for (final p in activeParties) {
        if (p.toUpperCase().trim() == mapped) return p;
      }
    }

    // 3. Same-length 1-character Levenshtein match (e.g. "APS" -> "APC")
    for (final p in activeParties) {
      final target = p.toUpperCase().trim();
      if (target.length >= 3 &&
          target.length == cleanKey.length &&
          _levenshtein(cleanKey, target) == 1) {
        return p;
      }
    }

    return null;
  }

  /// Normalizes the AI response so both nested `partyVotes` and top-level party keys,
  /// plus all INEC statistics, are clean integers ready for the UI.
  Map<String, dynamic> _normalizeExtractedData(
      Map<String, dynamic> raw, List<String> activeParties) {
    final Map<String, int> normalizedPartyVotes = {
      for (final p in activeParties) p: 0,
    };

    // Extract from nested `partyVotes` or `parties` map if present
    final dynamic nestedVotes = raw['partyVotes'] ?? raw['parties'];
    if (nestedVotes is Map) {
      nestedVotes.forEach((k, v) {
        final matchedParty =
            _findBestPartyMatch(k.toString(), activeParties);
        if (matchedParty != null) {
          final parsedVote = _parseIntSafe(v);
          if (_isValidVoteCount(parsedVote)) {
            normalizedPartyVotes[matchedParty] = parsedVote;
          }
        }
      });
    }

    // Also check top-level keys in case a model returned flat party keys
    raw.forEach((k, v) {
      if (k == 'partyVotes' ||
          k == 'parties' ||
          k == 'stats' ||
          k == 'electionYear' ||
          k == 'electionType' ||
          k == 'suggestedRotation') {
        return;
      }
      final matchedParty = _findBestPartyMatch(k, activeParties);
      if (matchedParty != null &&
          (normalizedPartyVotes[matchedParty] == null ||
              normalizedPartyVotes[matchedParty] == 0)) {
        final parsedVote = _parseIntSafe(v);
        if (_isValidVoteCount(parsedVote)) {
          normalizedPartyVotes[matchedParty] = parsedVote;
        }
      }
    });

    int getStat(String key, List<String> altKeys) {
      dynamic val = raw[key] ?? (raw['stats'] is Map ? raw['stats'][key] : null);
      if (val == null) {
        for (final alt in altKeys) {
          val = raw[alt] ?? (raw['stats'] is Map ? raw['stats'][alt] : null);
          if (val != null) break;
        }
      }
      final n = _parseIntSafe(val);
      return _isValidVoteCount(n) ? n : 0;
    }

    final votersInRegister = getStat(
        'votersInRegister', ['voters_in_register', 'registeredVoters']);
    final accreditedVoters =
        getStat('accreditedVoters', ['accredited_voters']);
    final ballotsIssued = getStat('ballotsIssued', ['ballots_issued']);
    final unusedBallots = getStat('unusedBallots', ['unused_ballots']);
    final spoiledBallots = getStat('spoiledBallots', ['spoiled_ballots']);
    final rejectedBallots = getStat('rejectedBallots', ['rejected_ballots']);
    final totalValidVotes = getStat('totalValidVotes', ['total_valid_votes']);
    final totalUsedBallots = getStat('totalUsedBallots', ['total_used_ballots']);

    final int electionYear = _parseIntSafe(
        raw['electionYear'] ?? raw['year'] ?? raw['metadata']?['electionYear']);
    final String electionType = (raw['electionType'] ??
            raw['type'] ??
            raw['metadata']?['electionType'] ??
            '')
        .toString()
        .trim();

    return {
      'partyVotes': normalizedPartyVotes,
      // Also spread party keys at root so both nested and flat consumers work identically
      ...normalizedPartyVotes,
      'votersInRegister': votersInRegister,
      'accreditedVoters': accreditedVoters,
      'ballotsIssued': ballotsIssued,
      'unusedBallots': unusedBallots,
      'spoiledBallots': spoiledBallots,
      'rejectedBallots': rejectedBallots,
      'totalValidVotes': totalValidVotes,
      'totalUsedBallots': totalUsedBallots,
      if (electionYear >= 1990 && electionYear <= 2099)
        'electionYear': electionYear,
      'electionType': electionType,
    };
  }

  Future<Map<String, dynamic>?> _processWithNano(
      File imageFile, List<String> partyAbbreviations) async {
    try {
      final result = await _nanoChannel.invokeMethod('processEC8A', {
        'imagePath': imageFile.path,
        'prompt': _buildEC8APrompt(partyAbbreviations),
      });
      if (result != null) {
        return _parseLLMJson(result.toString());
      }
    } catch (e) {
      debugPrint('Nano Channel Error: $e');
    }
    return null;
  }

  Future<void> _logUsage(String modelId, bool success, [String? error]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('ai_usage_logs')
          .add({
            'modelId': modelId,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': user?.uid,
            'status': success ? 'success' : 'failure',
            'error': error,
            'type': 'EC8A_SCAN',
          })
          .timeout(const Duration(seconds: 2));
    } catch (e) {}
  }

  /// Refined Offline OCR fallback (only used when device has no internet connection)
  Future<AIResult> processEC8ALocal(
      File imageFile, List<String> partyAbbreviations) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      final String fullText = recognizedText.text.toUpperCase();
      final lines = fullText.split('\n');

      Map<String, int> votes = {
        for (final p in partyAbbreviations) p: 0,
      };

      for (var party in partyAbbreviations) {
        int vote = 0;
        final partyUpper = party.toUpperCase().trim();
        if (partyUpper.isEmpty) continue;

        final partyWordRegex =
            RegExp(r'\b' + RegExp.escape(partyUpper) + r'\b');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Skip header/location lines so short party names like 'A' or 'LP' never match header words
          if (line.contains('INDEPENDENT NATIONAL') ||
              line.contains('LOCAL GOVERNMENT AREA') ||
              line.contains('POLLING UNIT') ||
              line.contains('STATEMENT OF RESULT') ||
              line.contains('VOTERS ON THE REGISTER') ||
              line.contains('ACCREDITED VOTERS') ||
              line.contains('BALLOT PAPERS')) {
            continue;
          }

          if (partyWordRegex.hasMatch(line) || _isFuzzyMatch(line, partyUpper)) {
            vote = _extractVoteAfterParty(line, partyUpper);

            if (vote == 0 &&
                !line.contains('NIL') &&
                !line.contains('ZERO') &&
                !line.contains('==')) {
              for (int j = 1; j <= 2; j++) {
                if (i + j < lines.length) {
                  final nextLine = lines[i + j];
                  if (_isSerialNumber(nextLine)) continue;
                  vote = _extractVoteAfterParty(nextLine, '');
                  if (vote > 0) break;
                }
              }
            }
            if (vote > 0 ||
                line.contains('NIL') ||
                line.contains('ZERO') ||
                line.contains('==')) {
              break;
            }
          }
        }
        votes[party] = vote;
      }

      final data = {
        'partyVotes': votes,
        ...votes,
        'electionYear': _extractYear(fullText),
        'votersInRegister':
            _extractStat(lines, ['VOTERS ON THE REGISTER', 'REGISTERED VOTERS']),
        'accreditedVoters':
            _extractStat(lines, ['ACCREDITED VOTERS', 'NUMBER OF ACCREDITED']),
        'ballotsIssued':
            _extractStat(lines, ['BALLOT PAPERS ISSUED', 'PAPERS ISSUED']),
        'unusedBallots':
            _extractStat(lines, ['UNUSED BALLOT', 'UNUSED PAPERS']),
        'spoiledBallots':
            _extractStat(lines, ['SPOILED BALLOT', 'SPOILT BALLOT']),
        'rejectedBallots': _extractStat(lines, ['REJECTED BALLOT']),
        'electionType': _detectTypeOffline(fullText),
      };

      _logUsage('ML_KIT_OPTIMIZED', true);
      return AIResult(data: data, modelName: 'ML Kit (Optimized Offline)');
    } finally {
      textRecognizer.close();
    }
  }

  bool _isFuzzyMatch(String line, String party) {
    final cleanLine = line.replaceAll(RegExp(r'[^A-Z]'), '');
    return cleanLine == party;
  }

  bool _isSerialNumber(String text) {
    final trimmed = text.trim();
    return RegExp(r'^[1-9][0-9]?$').hasMatch(trimmed);
  }

  int _extractVoteAfterParty(String line, String partyUpper) {
    if (line.contains('NIL') || line.contains('==') || line.contains('ZERO')) {
      return 0;
    }

    String searchSegment = line;
    if (partyUpper.isNotEmpty) {
      final match =
          RegExp(r'\b' + RegExp.escape(partyUpper) + r'\b').firstMatch(line);
      if (match != null) {
        searchSegment = line.substring(match.end);
      }
    }

    // Extract discrete numeric tokens instead of concatenating all digits on the line
    final matches = RegExp(r'\b\d+\b')
        .allMatches(searchSegment)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .where((n) => n >= 0 && n < 100000 && !(n >= 1990 && n <= 2099))
        .toList();

    if (matches.isEmpty) return 0;
    // If first token is a small S/N (1-30) and another number follows, take the second
    if (matches.length > 1 && matches[0] >= 1 && matches[0] <= 30) {
      return matches[1];
    }
    return matches.first;
  }

  int _extractStat(List<String> lines, List<String> keywords) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final kw in keywords) {
        if (line.contains(kw)) {
          final combined =
              i + 1 < lines.length ? '$line ${lines[i + 1]}' : line;
          final afterKw =
              combined.substring(combined.indexOf(kw) + kw.length);
          final nums = RegExp(r'\b\d+\b')
              .allMatches(afterKw)
              .map((m) => int.tryParse(m.group(0)!))
              .whereType<int>()
              .where((n) => n >= 0 && n < 500000 && !(n >= 1990 && n <= 2099))
              .toList();
          if (nums.isNotEmpty) {
            return nums.last;
          }
        }
      }
    }
    return 0;
  }

  String _detectTypeOffline(String text) {
    // Strip the polling-unit address label so it cannot falsely trigger LGA election type.
    final cleaned = text.replaceAll('LOCAL GOVERNMENT AREA', '');
    if (cleaned.contains('PRESIDENTIAL') || cleaned.contains('PRESIDENT')) {
      return 'PRESIDENTIAL';
    }
    if (cleaned.contains('GOVERNOR') || cleaned.contains('GUBERNATORIAL')) {
      return 'GUBERNATORIAL';
    }
    if (cleaned.contains('SENATE') || cleaned.contains('SENATORIAL')) {
      return 'SENATORIAL';
    }
    if (cleaned.contains('HOUSE OF REPRESENTATIVES') ||
        cleaned.contains('HOUSE OF REPS') ||
        cleaned.contains('REPRESENTATIVES') ||
        cleaned.contains('REPS')) {
      return 'HOUSE OF REPS';
    }
    if (cleaned.contains('STATE HOUSE OF ASSEMBLY') ||
        cleaned.contains('STATE ASSEMBLY') ||
        cleaned.contains('HOUSE OF ASSEMBLY')) {
      return 'STATE HOUSE OF ASSEMBLY';
    }
    if (cleaned.contains('COUNCILLOR') || cleaned.contains('COUNCILLORSHIP')) {
      return 'COUNCILLOR';
    }
    if (cleaned.contains('CHAIRMAN') ||
        cleaned.contains('CHAIRMANSHIP') ||
        cleaned.contains('AREA COUNCIL') ||
        cleaned.contains('LOCAL GOVERNMENT ELECTION')) {
      return 'LOCAL GOVERNMENT';
    }
    return '';
  }

  int _extractYear(String text) {
    final upperText = text.toUpperCase();
    final lines = upperText.split('\n');

    final electionKeywords = [
      'PRESIDENTIAL',
      'GUBERNATORIAL',
      'GOVERNOR',
      'GOVERNORSHIP',
      'SENATORIAL',
      'SENATE',
      'HOUSE OF REPS',
      'REPRESENTATIVES',
      'STATE ASSEMBLY',
      'HOUSE OF ASSEMBLY',
      'COUNCILLOR',
      'CHAIRMAN',
      'AREA COUNCIL',
      'LOCAL GOVERNMENT',
      'ELECTION',
    ];

    final yearRegex = RegExp(r'\b(20[2-3][0-9])\b');

    // 1. Direct Regex for adjacent patterns: "[YEAR] [TYPE] ELECTION"
    final adjacentPattern = RegExp(
      r'\b(20[2-3][0-9])\s+(?:[A-Z\s]{0,25})?(?:PRESIDENTIAL|GUBERNATORIAL|GOVERNOR|GOVERNORSHIP|SENATORIAL|SENATE|HOUSE OF REPS|REPRESENTATIVES|STATE ASSEMBLY|HOUSE OF ASSEMBLY|COUNCILLOR|CHAIRMAN|AREA COUNCIL|LOCAL GOVERNMENT|ELECTION)\b',
    );
    final adjMatch = adjacentPattern.firstMatch(upperText);
    if (adjMatch != null) {
      final year = int.tryParse(adjMatch.group(1)!);
      if (year != null && year >= 2020 && year <= 2035) return year;
    }

    final reversePattern = RegExp(
      r'\b(?:PRESIDENTIAL|GUBERNATORIAL|GOVERNOR|GOVERNORSHIP|SENATORIAL|SENATE|HOUSE OF REPS|REPRESENTATIVES|STATE ASSEMBLY|HOUSE OF ASSEMBLY|COUNCILLOR|CHAIRMAN|AREA COUNCIL|LOCAL GOVERNMENT|ELECTION)\s+(?:[A-Z\s]{0,25})?\b(20[2-3][0-9])\b',
    );
    final revMatch = reversePattern.firstMatch(upperText);
    if (revMatch != null) {
      final year = int.tryParse(revMatch.group(1)!);
      if (year != null && year >= 2020 && year <= 2035) return year;
    }

    // 2. Scan lines containing election keywords, strictly ignoring presiding/polling officer signature lines
    for (final line in lines) {
      if (line.contains('PRESIDING') ||
          line.contains('POLLING OFFICER') ||
          line.contains('SIGN') ||
          line.contains('STAMP') ||
          line.contains('CERTIFY')) {
        continue;
      }
      final hasElectionKeyword =
          electionKeywords.any((kw) => line.contains(kw));
      if (hasElectionKeyword) {
        final match = yearRegex.firstMatch(line);
        if (match != null) {
          final year = int.tryParse(match.group(1)!);
          if (year != null && year >= 2020 && year <= 2035) {
            return year;
          }
        }
      }
    }

    // 3. Header check: Look in the top 15 lines of the form, ignoring signature/date lines
    for (int i = 0; i < lines.length && i < 15; i++) {
      final line = lines[i];
      if (line.contains('PRESIDING') ||
          line.contains('POLLING OFFICER') ||
          line.contains('SIGN') ||
          line.contains('STAMP') ||
          line.contains('CERTIFY')) {
        continue;
      }
      final match = yearRegex.firstMatch(line);
      if (match != null) {
        final year = int.tryParse(match.group(1)!);
        if (year != null && year >= 2020 && year <= 2035) return year;
      }
    }

    // 4. Fallback: match any 2020-2035 year in the document
    final match = yearRegex.firstMatch(text);
    return int.tryParse(match?.group(1) ?? '2026') ?? 2026;
  }
}

class AIResult {
  final Map<String, dynamic>? data;
  final String modelName;

  AIResult({required this.data, required this.modelName});
}

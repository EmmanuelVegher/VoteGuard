import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AIService with ChangeNotifier {
  String? _apiKey;
  String _primaryModelName = 'gemini-2.5-flash';
  GenerativeModel? _model;
  static const _nanoChannel = MethodChannel('com.voteguard/gemini_nano');

  AIService({String? apiKey}) : _apiKey = apiKey {
    if (_apiKey != null) {
      _initModel();
    }
  }

  String get currentModelName => _primaryModelName;

  /// Checks if the current device supports on-device Gemini Nano (AICore)
  Future<bool> isNanoSupported() async {
    try {
      if (!Platform.isAndroid) return false;
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final model = androidInfo.model.toUpperCase();
      
      final supportedSeries = ['PIXEL 8', 'PIXEL 9', 'PIXEL 10', 'S24', 'S25', 'S26', 'FOLD 6', 'FOLD 7'];
      return supportedSeries.any((s) => model.contains(s));
    } catch (e) {
      return false;
    }
  }

  void setApiKey(String key) {
    if (_apiKey == key) return;
    _apiKey = key;
    _initModel();
    notifyListeners();
  }

  void setPrimaryModel(String modelName) {
    if (_primaryModelName == modelName) return;
    _primaryModelName = modelName;
    _initModel();
    notifyListeners();
  }

  void _initModel() {
    if (_apiKey == null || _apiKey!.isEmpty || _primaryModelName == 'mlkit') return;
    _model = GenerativeModel(
      model: _primaryModelName,
      apiKey: _apiKey!,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  static const String _ec8aPrompt = 
      'Analyze this INEC EC8A election result sheet image. '
      'Extract the number of votes for each political party (e.g., APC, LP, PDP, NNPP, APGA, etc.). '
      'Use these strict rules: '
      '1. Look at the "VOTES SCORED IN FIGURES" column. '
      '2. If "NIL" or "==" is written, the vote is 0. '
      '3. Ignore the Serial Number (S/N) column (1, 2, 3...). '
      '4. Also extract these official INEC metrics: '
      '   - votersInRegister (Total Registered Voters) '
      '   - accreditedVoters (Total Accredited Voters) '
      '   - ballotsIssued (Total Ballots Issued to PU) '
      '   - unusedBallots (Total Unused Ballots) '
      '   - spoiledBallots (Total Spoiled Ballots) '
      '   - rejectedBallots (Total Rejected Ballots) '
      '   - electionYear (The year of the election written on the form) '
      '   - electionType (Detect type using keywords: "Chairmanship/Chairman" -> LOCAL GOVERNMENT, "Governorship/Gubernatorial" -> GUBERNATORIAL, "Senatorial/Senate" -> SENATORIAL, "Reps" -> HOUSE OF REPS) '
      'Return ONLY a valid JSON object. If a value is missing, use 0.';

  Future<AIResult> processEC8A(File imageFile, [List<String>? partyAbbreviations]) async {
    final activeParties = partyAbbreviations ?? ['APC', 'PDP', 'LP', 'NNPP', 'APGA'];

    if (_primaryModelName == 'mlkit') {
      debugPrint('ML Kit forced as primary model. Using Optimized Offline OCR...');
      return processEC8ALocal(imageFile, activeParties);
    }

    if (await isNanoSupported()) {
      try {
        debugPrint('High-end device detected. Attempting Gemini Nano (On-Device)...');
        final data = await _processWithNano(imageFile);
        if (data != null) {
          await _logUsage('GEMINI_NANO', true);
          return AIResult(data: data, modelName: 'Gemini Nano (On-Device)');
        }
      } catch (nanoError) {
        debugPrint('Gemini Nano failed: $nanoError. Falling back to Cloud...');
      }
    }

    if (_model == null) throw Exception('AI Service not initialized with API Key. Please update your settings.');
    
    try {
      final data = await _generateWithModel(_model!, imageFile, activeParties);
      await _logUsage(_primaryModelName, true);
      return AIResult(data: data, modelName: _primaryModelName);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('503') || errorStr.contains('404') || errorStr.contains('rate limit')) {
        final fallbacks = ['gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-3-flash-preview'];
        for (var modelName in fallbacks) {
          if (modelName == _primaryModelName) continue;
          try {
            final fallbackModel = _createModel(modelName);
            final data = await _generateWithModel(fallbackModel, imageFile, activeParties);
            await _logUsage(modelName, true);
            return AIResult(data: data, modelName: modelName);
          } catch (fallbackError) {}
        }
      }
      await _logUsage(_primaryModelName, false, e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _processWithNano(File imageFile) async {
    try {
      final result = await _nanoChannel.invokeMethod('processEC8A', {
        'imagePath': imageFile.path,
        'prompt': _ec8aPrompt,
      });
      if (result != null) {
        return jsonDecode(result) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Nano Channel Error: $e');
    }
    return null;
  }

  Future<void> _logUsage(String modelId, bool success, [String? error]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('ai_usage_logs').add({
        'modelId': modelId,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user?.uid,
        'status': success ? 'success' : 'failure',
        'error': error,
        'type': 'EC8A_SCAN',
      });
    } catch (e) {}
  }

  Future<Map<String, dynamic>> _generateWithModel(GenerativeModel model, File imageFile, List<String> partyAbbreviations) async {
    final imageBytes = await imageFile.readAsBytes();
    
    final prompt = 
      'Analyze this INEC EC8A election result sheet image. '
      'Extract the number of votes for each political party. '
      'Here is the list of official party abbreviations you MUST extract: ${partyAbbreviations.join(', ')}. '
      'Use these strict rules: '
      '1. Look at the "VOTES SCORED IN FIGURES" column. '
      '2. If "NIL" or "==" is written, the vote is 0. '
      '3. Ignore the Serial Number (S/N) column (1, 2, 3...). '
      '4. Also extract these official INEC metrics: '
      '   - votersInRegister (Total Registered Voters) '
      '   - accreditedVoters (Total Accredited Voters) '
      '   - ballotsIssued (Total Ballots Issued to PU) '
      '   - unusedBallots (Total Unused Ballots) '
      '   - spoiledBallots (Total Spoiled Ballots) '
      '   - rejectedBallots (Total Rejected Ballots) '
      '   - electionYear (The year of the election written on the form) '
      '   - electionType (Detect type using keywords: "Chairmanship/Chairman" -> LOCAL GOVERNMENT, "Governorship/Gubernatorial" -> GUBERNATORIAL, "Senatorial/Senate" -> SENATORIAL, "Reps" -> HOUSE OF REPS) '
      'Return ONLY a valid JSON object. All extracted party votes MUST be grouped inside a nested "partyVotes" map (e.g. {"partyVotes": {"APC": 86, "PDP": 2, ...}, "votersInRegister": 1615, ...}). '
      'Use the exact party abbreviations as the keys inside the "partyVotes" map. If a value is missing or not detected, use 0.';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ])
    ];

    final response = await model.generateContent(content);
    final text = response.text;
    if (text == null) throw Exception('Empty response from AI');
    final cleanedText = text.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(cleanedText) as Map<String, dynamic>;
  }

  GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: _apiKey!,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  /// Refined Offline OCR to avoid S/N confusion and handle NIL values
  Future<AIResult> processEC8ALocal(File imageFile, List<String> partyAbbreviations) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final String fullText = recognizedText.text.toUpperCase();
      final lines = fullText.split('\n');
      
      Map<String, int> votes = {};
      
      for (var party in partyAbbreviations) {
        int vote = 0;
        final partyUpper = party.toUpperCase();
        
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains(partyUpper) || _isFuzzyMatch(line, partyUpper)) {
            // Check the rest of the line first
            vote = _extractVotesFromText(line);
            
            // If nothing on the party line, check subsequent lines but ignore Serial Numbers
            if (vote == 0) {
              for (int j = 1; j <= 2; j++) {
                if (i + j < lines.length) {
                  final nextLine = lines[i + j];
                  // If it's a single digit at the start of a line, it's likely a S/N (1, 2, 3...)
                  if (_isSerialNumber(nextLine)) continue;
                  
                  vote = _extractVotesFromText(nextLine);
                  if (vote > 0) break;
                }
              }
            }
            if (vote > 0) break;
          }
        }
        votes[party] = vote;
      }

      final data = {
        ...votes,
        'electionYear': _extractYear(fullText),
        'votersInRegister': _extractStat(fullText, ['REGISTER', 'TOTAL VOTERS']),
        'accreditedVoters': _extractStat(fullText, ['ACCREDITED', 'ACC']),
        'electionType': _detectTypeOffline(fullText),
      };
      
      await _logUsage('ML_KIT_OPTIMIZED', true);
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
    // Match single digits 1-9 at the start of a line with nothing else
    return RegExp(r'^[1-9]$').hasMatch(trimmed);
  }

  int _extractVotesFromText(String text) {
    if (text.contains('NIL') || text.contains('==')) return 0;
    
    // Specifically look for "X VOTES" or "X VOTE"
    final votesMatch = RegExp(r'(\d+)\s*VOTES?').firstMatch(text);
    if (votesMatch != null) {
      return int.tryParse(votesMatch.group(1)!) ?? 0;
    }

    // Otherwise, take digits but ignore small single digits that might be S/N
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    final val = int.tryParse(digits) ?? 0;
    
    // If the value is the same as the line number (S/N), it's risky
    if (val < 10 && text.length < 3) return 0; 
    
    return val;
  }

  int _extractStat(String text, List<String> keywords) {
    for (var kw in keywords) {
      if (text.contains(kw)) {
        return _extractVotesFromText(text.substring(text.indexOf(kw)));
      }
    }
    return 0;
  }

  String _detectTypeOffline(String text) {
    if (text.contains('CHAIRMAN') || text.contains('COUNCIL')) return 'LOCAL GOVERNMENT';
    if (text.contains('GOVERNOR') || text.contains('GUBERNATORIAL')) return 'GUBERNATORIAL';
    if (text.contains('SENATE') || text.contains('SENATORIAL')) return 'SENATORIAL';
    if (text.contains('REPS') || text.contains('HOUSE OF REPS')) return 'HOUSE OF REPS';
    return 'LOCAL GOVERNMENT';
  }

  int _extractYear(String text) {
    final regExp = RegExp(r'202[0-9]');
    final match = regExp.firstMatch(text);
    return int.tryParse(match?.group(0) ?? '2026') ?? 2026;
  }
}

class AIResult {
  final Map<String, dynamic>? data;
  final String modelName;

  AIResult({required this.data, required this.modelName});
}

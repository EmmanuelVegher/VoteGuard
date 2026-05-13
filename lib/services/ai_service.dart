import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:ui';

class AIService {
  final String apiKey;
  late final GenerativeModel _model;

  AIService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
    );
  }

  Future<Map<String, dynamic>?> processEC8A(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(
            'Analyze this INEC EC8A election result sheet image. '
            'Extract the number of votes for each political party (e.g., APC, LP, PDP, NNPP, APGA, etc.). '
            'Also extract these official INEC metrics: '
            '1. votersInRegister (Total Registered Voters) '
            '2. accreditedVoters (Total Accredited Voters) '
            '3. ballotsIssued (Total Ballots Issued to PU) '
            '4. unusedBallots (Total Unused Ballots) '
            '5. spoiledBallots (Total Spoiled Ballots) '
            '6. rejectedBallots (Total Rejected Ballots) '
            '7. electionYear (The year of the election written on the form, e.g., 2026, 2023, etc.) '
            '8. electionType (The type of election, e.g., PRESIDENTIAL, GOVERNORSHIP, SENATORIAL, HOUSE OF REPRESENTATIVES, STATE ASSEMBLY, LOCAL GOVERNMENT) '
            'Return ONLY a valid JSON object with the party abbreviations as keys for votes, and the metric names above as keys for stats. '
            'If a value is missing or illegible, use 0. Do not include any markdown formatting or extra text, just the JSON.'
          ),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;
      
      if (text != null) {
        // Find JSON block in response
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
        if (jsonMatch != null) {
          return jsonDecode(jsonMatch.group(0)!);
        }
      }
      return null;
    } catch (e) {
      print('AI OCR Error: $e');
      throw Exception('OCR Pipeline Error:\n\n$e');
    }
  }

  Future<Map<String, dynamic>> processEC8ALocal(File imageFile, List<String> partyAbbreviations) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      Map<String, dynamic> results = {};
      
      // 1. Flatten all text elements to access their geometric bounding boxes
      List<TextElement> allElements = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            allElements.add(element);
          }
        }
      }
      
      // Extract election year using simple Regex over the entire text
      final yearMatch = RegExp(r'\b(20[1-9][0-9])\b').firstMatch(recognizedText.text);
      if (yearMatch != null) {
        results['electionYear'] = int.tryParse(yearMatch.group(1)!);
      }
      
      // Extract election type using Regex over the entire text
      final textUpper = recognizedText.text.toUpperCase();
      if (textUpper.contains('PRESIDENTIAL')) {
        results['electionType'] = 'PRESIDENTIAL';
      } else if (textUpper.contains('GOVERNORSHIP')) {
        results['electionType'] = 'GOVERNORSHIP';
      } else if (textUpper.contains('SENATORIAL') || textUpper.contains('SENATE')) {
        results['electionType'] = 'SENATORIAL';
      } else if (textUpper.contains('HOUSE OF REPRESENTATIVES') || textUpper.contains('REPRESENTATIVE')) {
        results['electionType'] = 'HOUSE OF REPRESENTATIVES';
      } else if (textUpper.contains('STATE ASSEMBLY') || textUpper.contains('HOUSE OF ASSEMBLY')) {
        results['electionType'] = 'STATE ASSEMBLY';
      } else if (textUpper.contains('LOCAL GOVERNMENT') || textUpper.contains('CHAIRMANSHIP')) {
        results['electionType'] = 'LOCAL GOVERNMENT';
      }

      // Helper function to scan horizontally to the right for a number
      int? extractNumberOnSameLine(Rect referenceBox) {
        final centerY = referenceBox.top + (referenceBox.height / 2);
        
        List<TextElement> candidates = allElements.where((e) {
          if (e.boundingBox.left <= referenceBox.right) return false;
          
          // Tight vertical tolerance: The center of the candidate must be very close to the center of the reference word
          final eCenterY = e.boundingBox.top + (e.boundingBox.height / 2);
          if ((eCenterY - centerY).abs() > (referenceBox.height * 0.6)) return false;
          
          return true;
        }).toList();

        candidates.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

        for (var c in candidates) {
          String normalized = c.text.toUpperCase().replaceAll('O', '0');
          final match = RegExp(r'^[\s\-\:]*(\d{1,5})[\s\-\:]*$').firstMatch(normalized);
          if (match != null) {
            return int.tryParse(match.group(1)!);
          }
        }
        return null;
      }
      
      // 1.5. Find the Party Column X-Axis Anchor
      double? partyColumnLeft;
      for (String anchor in ['APC', 'PDP', 'NNPP', 'LP']) {
        final anchors = allElements.where((e) => e.text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '') == anchor).toList();
        if (anchors.isNotEmpty) {
          partyColumnLeft = anchors.first.boundingBox.left;
          break;
        }
      }

      // 2. Spatially extract Party Votes
      for (String party in partyAbbreviations) {
        final partyElements = allElements.where((e) {
          // Strictly standalone word match
          String cleanWord = e.text.toUpperCase().replaceAll(RegExp(r'[\.\-\:\s]'), '');
          if (cleanWord != party.toUpperCase()) return false;
          
          if (partyColumnLeft != null) {
            // Widen the vertical column boundary to 250px to handle skewed photos perfectly
            if ((e.boundingBox.left - partyColumnLeft).abs() > 250) return false;
          }
          return true;
        }).toList();
        
        if (partyElements.isNotEmpty) {
          // Sort by Y position just in case there are duplicates, take the top one
          partyElements.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
          final pBox = partyElements.first.boundingBox;
          int? score = extractNumberOnSameLine(pBox);
          results[party] = score ?? 0;
        } else {
          results[party] = 0;
        }
      }
      
      // 3. Spatially extract INEC Stats (Word-Level Anchoring)
      final statKeywords = {
        'votersInRegister': ['REGISTER'],
        'accreditedVoters': ['ACCREDITED'],
        'ballotsIssued': ['ISSUED'],
        'unusedBallots': ['UNUSED'],
        'spoiledBallots': ['SPOILED'],
        'rejectedBallots': ['REJECTED'],
      };

      for (var entry in statKeywords.entries) {
        // Find the specific keyword element (e.g., the word "REGISTER")
        final keywordElements = allElements.where((e) => 
          entry.value.any((k) => e.text.toUpperCase().contains(k))
        ).toList();

        if (keywordElements.isNotEmpty) {
          // Scan directly to the right of that specific word
          int? statVal = extractNumberOnSameLine(keywordElements.first.boundingBox);
          if (statVal != null) {
            results[entry.key] = statVal;
          }
        }
      }
      
      return results;
    } finally {
      textRecognizer.close();
    }
  }
}

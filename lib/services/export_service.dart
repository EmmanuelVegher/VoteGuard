import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:voteguard/models/election_model.dart';

class ExportService {
  static const PdfColor primaryRed = PdfColor.fromInt(0xFFC41E3A);
  static const PdfColor primaryGreen = PdfColor.fromInt(0xFF008B5E);
  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF1E3A8A); // Deep Navy for Results
  static const PdfColor lightPink = PdfColor.fromInt(0xFFFFF1F2);
  static const PdfColor lightGreen = PdfColor.fromInt(0xFFF0FDF4);
  static const PdfColor lightBlue = PdfColor.fromInt(0xFFF0F9FF);
  static const PdfColor tableRowGrey = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor textGrey = PdfColor.fromInt(0xFF64748B);

  // ── Results Export (EC8A) ──────────────────────────────────────
  Future<void> exportResultReport(Election election, Map<String, dynamic> resultData) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final submittedAt = resultData['submittedAt'] != null 
        ? DateFormat('dd/MM/yyyy, h:mm:ss a').format((resultData['submittedAt'] as dynamic).toDate())
        : DateFormat('dd/MM/yyyy, h:mm:ss a').format(now);

    final stats = resultData['statistics'] as Map<String, dynamic>? ?? {};
    final partyResults = resultData['partyResults'] as List<dynamic>? ?? [];
    
    // Pre-fetch Party Logos
    final Map<String, pw.MemoryImage?> partyLogos = {};
    for (var party in partyResults) {
      final logoUrl = party['logoUrl']?.toString();
      if (logoUrl != null && logoUrl.startsWith('http')) {
        try {
          final res = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            partyLogos[logoUrl] = pw.MemoryImage(res.bodyBytes);
          }
        } catch (_) {}
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Title ─────────────────────────────────────────────────
          pw.Text(
            'ELECTION RESULT (FORM EC8A)',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: primaryBlue),
          ),
          pw.SizedBox(height: 16),
          
          // ── Metadata ──────────────────────────────────────────────
          _buildMetaLine('ELECTION', election.name.toUpperCase()),
          _buildMetaLine('POLLING UNIT', (resultData['pollingUnit'] ?? 'N/A').toString().toUpperCase()),
          _buildMetaLine('STATE/LGA', '${resultData['state'] ?? 'N/A'} / ${resultData['lga'] ?? 'N/A'}'.toUpperCase()),
          _buildMetaLine('SUBMITTED BY', (resultData['submittedByName'] ?? 'N/A').toString().toUpperCase()),
          _buildMetaLine('TIMESTAMP', submittedAt),
          pw.SizedBox(height: 24),

          // ── Voter Statistics ──────────────────────────────────────
          pw.Text('VOTER STATISTICS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textGrey)),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildStatBox('REGISTERED', stats['registeredVoters']?.toString() ?? '0'),
              pw.SizedBox(width: 12),
              _buildStatBox('ACCREDITED', stats['accreditedVoters']?.toString() ?? '0'),
              pw.SizedBox(width: 12),
              _buildStatBox('VALID VOTES', stats['totalValidVotes']?.toString() ?? '0'),
              pw.SizedBox(width: 12),
              _buildStatBox('REJECTED', stats['rejectedVotes']?.toString() ?? '0'),
            ],
          ),
          pw.SizedBox(height: 32),

          // ── Party Scores ──────────────────────────────────────────
          pw.Text('PARTY SCORES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textGrey)),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(60), // Logo
              1: const pw.FlexColumnWidth(2),   // Party Name
              2: const pw.FlexColumnWidth(1),   // Score
              3: const pw.FlexColumnWidth(1),   // % Share
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryBlue),
                children: [
                  _buildHeaderCell('LOGO'),
                  _buildHeaderCell('POLITICAL PARTY'),
                  _buildHeaderCell('SCORE'),
                  _buildHeaderCell('% SHARE'),
                ],
              ),
              // Party Rows
              for (var i = 0; i < partyResults.length; i++) ...[
                (() {
                  final party = partyResults[i];
                  final score = int.tryParse(party['score']?.toString() ?? '0') ?? 0;
                  final totalValid = int.tryParse(stats['totalValidVotes']?.toString() ?? '0') ?? 1;
                  final percent = ((score / (totalValid == 0 ? 1 : totalValid)) * 100).toStringAsFixed(1);
                  final logoUrl = party['logoUrl']?.toString();
                  final isEven = i % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : tableRowGrey),
                    children: [
                      pw.Container(
                        height: 40,
                        padding: const pw.EdgeInsets.all(4),
                        child: partyLogos.containsKey(logoUrl) 
                          ? pw.Image(partyLogos[logoUrl]!, fit: pw.BoxFit.contain)
                          : pw.Center(child: pw.Text(party['code']?.toString() ?? '?', style: const pw.TextStyle(fontSize: 10))),
                      ),
                      _buildDataCell(party['name']?.toString() ?? party['code']?.toString() ?? 'Unknown'),
                      _buildDataCell(score.toString()),
                      _buildDataCell('$percent%'),
                    ],
                  );
                })(),
              ],
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'EC8A_Result_${election.name}.pdf',
    );
  }

  pw.Widget _buildStatBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: lightBlue,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColors.blue100),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryBlue)),
          ],
        ),
      ),
    );
  }

  // ── Existing Export Methods ────────────────────────────────────
  
  Future<void> exportIncidentExcel(Election election, List<Map<String, dynamic>> incidents) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Incidents'];
    
    // Header
    sheet.appendRow([
      xl.TextCellValue("Time"),
      xl.TextCellValue("Category"),
      xl.TextCellValue("Description"),
      xl.TextCellValue("Polling Unit"),
      xl.TextCellValue("Evidence URL"),
    ]);

    for (var i = 0; i < incidents.length; i++) {
      final incident = incidents[i];
      final rowIndex = i + 1;
      
      sheet.appendRow([
        xl.TextCellValue(incident['timestamp']?.toString() ?? 'N/A'),
        xl.TextCellValue(incident['category']?.toString() ?? 'General'),
        xl.TextCellValue(incident['description']?.toString() ?? ''),
        xl.TextCellValue(incident['pollingUnit']?.toString() ?? 'N/A'),
        xl.TextCellValue(""), // Placeholder for link
      ]);

      final media = incident['mediaPaths'] ?? incident['mediaPathsJson'] ?? incident['imageUrl'];
      String? imageUrl;
      if (media is List && media.isNotEmpty) imageUrl = media.first.toString();
      else if (media is String) imageUrl = media;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
        cell.value = xl.TextCellValue("Evidence ${i + 1}");
      }
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final filePath = path.join(directory.path, 'Incidents_${election.name.replaceAll(' ', '_')}.xlsx');
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(filePath)], text: 'Incident Report - ${election.name}');
    }
  }

  Future<void> exportIncidentReport(Election election, List<Map<String, dynamic>> incidents) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final electionDate = election.startDate != null 
        ? DateFormat('dd/MM/yyyy, h:mm:ss a').format(election.startDate!) : 'N/A';

    final List<pw.MemoryImage?> incidentImages = [];
    for (var incident in incidents) {
      String? imageUrl;
      final media = incident['mediaPaths'] ?? incident['mediaPathsJson'] ?? incident['imageUrl'];
      if (media is List && media.isNotEmpty) imageUrl = media.first.toString();
      else if (media != null) imageUrl = media.toString();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            incidentImages.add(pw.MemoryImage(response.bodyBytes));
          } else { incidentImages.add(null); }
        } catch (_) { incidentImages.add(null); }
      } else { incidentImages.add(null); }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text('INCIDENT REPORTS', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: primaryRed)),
          pw.SizedBox(height: 24),
          _buildMetaLine('ELECTION', election.name.toUpperCase()),
          _buildMetaLine('ELECTION DATE', electionDate),
          _buildMetaLine('REPORT GENERATED', DateFormat('dd/MM/yyyy, h:mm:ss a').format(now)),
          pw.SizedBox(height: 32),
          pw.Table(
            columnWidths: {0: const pw.FixedColumnWidth(100), 1: const pw.FixedColumnWidth(80), 2: const pw.FlexColumnWidth(), 3: const pw.FixedColumnWidth(100), 4: const pw.FixedColumnWidth(80)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: primaryRed), children: [_buildHeaderCell('TIME'), _buildHeaderCell('TYPE'), _buildHeaderCell('DESCRIPTION'), _buildHeaderCell('UNIT'), _buildHeaderCell('EVIDENCE')]),
              for (var i = 0; i < incidents.length; i++) pw.TableRow(
                decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : tableRowGrey),
                children: [
                  _buildDataCell(incidents[i]['timestamp']?.toString() ?? 'N/A'),
                  _buildDataCell(incidents[i]['category']?.toString() ?? 'General'),
                  _buildDataCell(incidents[i]['description']?.toString() ?? ''),
                  _buildDataCell(incidents[i]['pollingUnit']?.toString() ?? 'N/A'),
                  incidentImages[i] != null ? pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Image(incidentImages[i]!, height: 40, fit: pw.BoxFit.contain)) : _buildDataCell('None'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Incidents_${election.name}.pdf');
  }

  Future<void> exportChecklistReport(Election election, Map<String, dynamic> checklistData) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final electionDate = election.startDate != null 
        ? DateFormat('dd/MM/yyyy, h:mm:ss a').format(election.startDate!) : 'N/A';
    final submittedAt = checklistData['submittedAt'] != null 
        ? DateFormat('dd/MM/yyyy, h:mm:ss a').format((checklistData['submittedAt'] as dynamic).toDate())
        : DateFormat('dd/MM/yyyy, h:mm:ss a').format(now);

    List<dynamic> sections = [];
    if (checklistData['sections'] != null) sections = List.from(checklistData['sections']);
    else if (checklistData['questions'] != null) sections = [{'title': 'General Responses', 'questions': checklistData['questions']}];
    else if (checklistData['responses'] != null) sections = [{'title': 'Responses', 'questions': checklistData['responses']}];
    else {
      final List<Map<String, dynamic>> flat = [];
      final ignored = ['electionId', 'observerId', 'submittedAt', 'fullName', 'assignedPollingUnit', 'assignedState', 'id'];
      checklistData.forEach((key, value) { if (!ignored.contains(key) && value != null) flat.add({'text': key.replaceAll('_', ' ').toUpperCase(), 'response': value.toString()}); });
      if (flat.isNotEmpty) sections = [{'title': 'Submitted Data', 'questions': flat}];
    }

    final observerName = checklistData['observerName'] ?? checklistData['fullName'] ?? 'N/A';
    final pollingUnit = checklistData['pollingUnit'] ?? checklistData['assignedPollingUnit'] ?? 'N/A';

    final Map<String, pw.MemoryImage?> evidenceImages = {};
    for (var section in sections) {
      final questions = section['questions'] as List<dynamic>? ?? [];
      for (var q in questions) {
        final raw = q['response'];
        String? url;
        if (raw is List && raw.isNotEmpty) url = raw.first.toString();
        else if (raw is String) url = raw;
        if (url != null && url.startsWith('http')) {
          try {
            final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
            if (res.statusCode == 200) evidenceImages[url] = pw.MemoryImage(res.bodyBytes);
          } catch (_) {}
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text('OBSERVER CHECKLIST REPORT', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: primaryGreen)),
          pw.SizedBox(height: 16),
          _buildMetaLine('ELECTION', election.name.toUpperCase()),
          _buildMetaLine('ELECTION DATE', electionDate),
          _buildMetaLine('POLLING UNIT', pollingUnit.toString().toUpperCase()),
          _buildMetaLine('OBSERVER', observerName.toString().toUpperCase()),
          _buildMetaLine('SUBMITTED AT', submittedAt),
          pw.SizedBox(height: 30),
          pw.Table(
            columnWidths: {0: const pw.FixedColumnWidth(100), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.5)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: primaryGreen), children: [_buildHeaderCell('SECTION'), _buildHeaderCell('QUESTION'), _buildHeaderCell('ANSWER')]),
              for (var section in sections) ...((section['questions'] as List<dynamic>? ?? []).asMap().entries.map((entry) {
                final q = entry.value;
                final answer = q['response']?.toString() ?? 'N/A';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : tableRowGrey),
                  children: [
                    _buildDataCell(section['title']?.toString() ?? ''),
                    _buildDataCell(q['text']?.toString() ?? ''),
                    evidenceImages.containsKey(answer) ? pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Image(evidenceImages[answer]!, height: 60, fit: pw.BoxFit.contain)) : _buildDataCell(answer),
                  ],
                );
              })),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Checklist_${election.name}.pdf');
  }

  pw.Widget _buildMetaLine(String label, String value) {
    return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Row(children: [pw.SizedBox(width: 100, child: pw.Text('$label:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textGrey))), pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black)))]));
  }

  pw.Widget _buildHeaderCell(String label) {
    return pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)));
  }

  pw.Widget _buildDataCell(String value) {
    return pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)));
  }
}

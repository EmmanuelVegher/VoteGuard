import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:voteguard/data/local/app_database.dart';
import 'package:voteguard/models/election_model.dart' as model;

class SyncService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SyncService(this._db);

  Future<void> syncAllData() async {
    await syncElections();
    await syncParties();
    await syncChecklists();
  }

  Future<void> syncChecklists() async {
    try {
      final templates = await _firestore.collection('checklist_templates').get();
      for (var tDoc in templates.docs) {
        final tData = tDoc.data();
        await _db.upsertChecklistTemplate(ChecklistTemplatesCompanion(
          id: Value(tDoc.id),
          name: Value(tData['name'] ?? 'Template'),
          updatedAt: Value((tData['updatedAt'] as Timestamp?)?.toDate()),
        ));

        // Sync Questions for this template
        final qDocs = await _firestore.collection('checklist_templates').doc(tDoc.id).collection('questions').get();
        if (qDocs.docs.isNotEmpty) {
          await _db.clearTemplateQuestions(tDoc.id);
          for (var qDoc in qDocs.docs) {
            final qData = qDoc.data();
            await _db.upsertChecklistQuestion(ChecklistQuestionsCompanion(
              id: Value(qDoc.id),
              templateId: Value(tDoc.id),
              questionText: Value(qData['text'] ?? ''),
              type: Value(qData['type'] ?? 'text'),
              order: Value(qData['order'] ?? 0),
              category: Value(qData['category']),
              metadataJson: Value(qData['options']?.toString()), // Options or other metadata
            ));
          }
        }
      }
    } catch (e) {
      print('SyncService: Error syncing checklists: $e');
    }
  }

  Future<void> syncElections() async {
    try {
      final snapshot = await _firestore.collection('elections').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final stateList = data['state'] ?? data['states'] ?? data['targetStates'] ?? data['regions'] ?? data['region'] ?? data['targetJurisdictions'];
        final lgaList = data['lga'] ?? data['lgas'] ?? data['targetLgas'];
        final wardList = data['ward'] ?? data['wards'] ?? data['targetWards'];

        final metadata = {
          'state': stateList,
          'lga': lgaList,
          'ward': wardList,
        };
        await _db.upsertElection(ElectionsCompanion(
          id: Value(doc.id),
          name: Value(data['name'] ?? ''),
          type: Value(data['type'] ?? ''),
          startDate: Value((data['startDate'] as Timestamp?)?.toDate()),
          endDate: Value((data['endDate'] as Timestamp?)?.toDate()),
          status: Value(data['status'] ?? 'UPCOMING'),
          metadataJson: Value(jsonEncode(metadata)),
        ));
      }
    } catch (e) {
      print('SyncService: Error syncing elections: $e');
    }
  }

  Future<void> syncParties() async {
    try {
      final snapshot = await _firestore.collection('parties').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        await _db.upsertParty(PartiesCompanion(
          id: Value(doc.id),
          name: Value(data['name'] ?? ''),
          abbreviation: Value(data['abbreviation'] ?? ''),
          logoUrl: Value(data['logoUrl']),
        ));
      }
    } catch (e) {
      print('SyncService: Error syncing parties: $e');
    }
  }
}

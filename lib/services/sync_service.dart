import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voteguard/data/local/app_database.dart';

class SyncService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SyncService(this._db);

  Future<void> syncAll() async {
    await _syncResults();
    await _syncIncidents();
    // More sync logic for checklists, etc.
  }

  Future<void> _syncResults() async {
    final unsynced = await (_db.select(_db.results)..where((t) => t.isSynced.equals(false))).get();
    
    for (var result in unsynced) {
      try {
        await _firestore.collection('results').add({
          'observerId': result.observerId,
          'pollingUnitId': result.pollingUnitId,
          'partyVotes': result.partyVotesJson,
          'ballotStats': result.ballotStatsJson,
          'createdAt': result.createdAt.toIso8601String(),
        });

        // Update local status
        await (_db.update(_db.results)..where((t) => t.id.equals(result.id)))
            .write(const ResultsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Sync Error (Results): $e');
      }
    }
  }

  Future<void> _syncIncidents() async {
    final unsynced = await (_db.select(_db.incidents)..where((t) => t.isSynced.equals(false))).get();

    for (var incident in unsynced) {
      try {
        await _firestore.collection('incidents').add({
          'category': incident.category,
          'severity': incident.severity,
          'description': incident.description,
          'location': {
            'lat': incident.latitude,
            'lng': incident.longitude,
          },
          'createdAt': incident.createdAt.toIso8601String(),
        });

        await (_db.update(_db.incidents)..where((t) => t.id.equals(incident.id)))
            .write(const IncidentsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Sync Error (Incidents): $e');
      }
    }
  }
}

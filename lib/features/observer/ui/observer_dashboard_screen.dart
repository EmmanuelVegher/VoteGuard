import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:voteguard/models/election_model.dart';
import 'package:voteguard/services/ai_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voteguard/services/auth_service.dart';
import 'package:voteguard/data/local/app_database.dart' as db;
import 'package:drift/drift.dart' as drift;

Future<String> _getPublicIP() async {
  try {
    final response = await http
        .get(Uri.parse('https://api.ipify.org'))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      return response.body.trim();
    }
  } catch (_) {}
  return '192.168.1.1'; // fallback local IP
}

class ObserverDashboardScreen extends StatefulWidget {
  final String electionId;
  const ObserverDashboardScreen({super.key, required this.electionId});

  @override
  State<ObserverDashboardScreen> createState() =>
      _ObserverDashboardScreenState();
}

class _ObserverDashboardScreenState extends State<ObserverDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Election? _election;
  String? _userSenatorialDistrict;
  bool _loading = true;
  final Map<int, bool> _syncingMap = {};
  bool _isOffline = false;
  Timer? _networkCheckTimer;
  late BehaviorSubject<List<dynamic>> _unsyncedSubject;

  static final Set<String> _promptedChecklistElections = {};
  static final Set<String> _promptedIncidentElections = {};

  String _sanitizeId(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _fetchUserSenatorialDistrict(String state, String lga) async {
    try {
      // 1. Query flexible state & name
      final q = await FirebaseFirestore.instance
          .collection('lgas')
          .where('state', isEqualTo: state)
          .where('name', isEqualTo: lga)
          .get();
      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        final district = data['senatorialDistrict']?.toString() ??
            data['senatorial_district']?.toString();
        if (district != null && mounted) {
          setState(() {
            _userSenatorialDistrict = district;
          });
          return;
        }
      }

      // 2. Secondary fallback direct document ID lookup
      final docId = '${state}_$lga';
      final docSnap =
          await FirebaseFirestore.instance.collection('lgas').doc(docId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        final district = data?['senatorialDistrict']?.toString() ??
            data?['senatorial_district']?.toString();
        if (district != null && mounted) {
          setState(() {
            _userSenatorialDistrict = district;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user senatorial district: $e");
    }
  }

  Future<void> _deleteOfflineResult(int localId) async {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Offline Draft',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text(
            'Are you sure you want to permanently delete this offline draft results sheet?',
            style: GoogleFonts.outfit(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(confirmCtx);
              await context.read<db.AppDatabase>().deleteResult(localId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Offline draft deleted'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: Text('DELETE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncOfflineResult(db.Result result,
      [StateSetter? modalState]) async {
    if (modalState != null) {
      modalState(() => _syncingMap[result.id] = true);
    } else {
      if (mounted) setState(() => _syncingMap[result.id] = true);
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? evidenceUrl;

      // Parse JSON details
      final stats = jsonDecode(result.ballotStatsJson) as Map<String, dynamic>;
      final electionId = stats['electionId']?.toString() ?? widget.electionId;
      final state = stats['state']?.toString() ?? '';
      final lga = stats['lga']?.toString() ?? '';
      final ward = stats['ward']?.toString() ?? '';
      final pu = stats['pollingUnit']?.toString() ?? '';
      final isFinal = stats['isFinal'] == true;
      final partyVotes = Map<String, int>.from(jsonDecode(result.partyVotesJson)
          .map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0)));

      // Upload local image if exists
      if (result.imagePath != null && result.imagePath!.isNotEmpty) {
        final file = File(result.imagePath!);
        if (await file.exists()) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('results/$electionId/${user?.uid}.jpg');
          await ref.putFile(file).timeout(const Duration(seconds: 15));
          evidenceUrl = await ref.getDownloadURL();
        }
      }

      String? electionType = _election?.type;
      String? primaryElectionType = _election?.primaryElectionType;
      String? primaryParty = _election?.primaryParty;

      if (electionType == null) {
        try {
          final dbInstance = context.read<db.AppDatabase>();
          final localElections = await dbInstance.getAllLocalElections();
          final matchIndex =
              localElections.indexWhere((e) => e.id == electionId);
          if (matchIndex != -1) {
            final le = localElections[matchIndex];
            electionType = le.type;
            if (le.metadataJson != null) {
              final meta = jsonDecode(le.metadataJson!);
              primaryElectionType = meta['primaryElectionType']?.toString();
              primaryParty = meta['primaryParty']?.toString();
            }
          }
        } catch (_) {}
      }
      electionType ??= 'GENERAL';

      // Let's resolve the Assembly Constituency
      String? offlineAssemblyConstituency;
      final isPrimaries = electionType == 'PARTY_PRIMARIES';
      if (isPrimaries &&
          primaryElectionType == 'STATE_HOUSE_OF_ASSEMBLY' &&
          state.isNotEmpty &&
          lga.isNotEmpty &&
          ward.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('wards')
              .where('state', isEqualTo: state)
              .where('lga', isEqualTo: lga)
              .where('name', isEqualTo: ward)
              .get();
          if (q.docs.isNotEmpty) {
            offlineAssemblyConstituency =
                q.docs.first.data()['stateAssemblyConstituency']?.toString() ??
                    q.docs.first.data()['assemblyConstituency']?.toString() ??
                    q.docs.first.data()['constituency']?.toString() ??
                    q.docs.first
                        .data()['state_assembly_constituency']
                        ?.toString() ??
                    q.docs.first.data()['assembly_constituency']?.toString();
          } else {
            final docId = '${state}_${lga}_$ward'
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
                .toLowerCase();
            final docSnap = await FirebaseFirestore.instance
                .collection('wards')
                .doc(docId)
                .get();
            if (docSnap.exists) {
              final data = docSnap.data();
              offlineAssemblyConstituency =
                  data?['stateAssemblyConstituency']?.toString() ??
                      data?['assemblyConstituency']?.toString() ??
                      data?['constituency']?.toString() ??
                      data?['state_assembly_constituency']?.toString() ??
                      data?['assembly_constituency']?.toString();
            }
          }
        } catch (e) {
          debugPrint("Error fetching offline assembly constituency: $e");
        }
        if (offlineAssemblyConstituency == null ||
            offlineAssemblyConstituency.isEmpty) {
          offlineAssemblyConstituency = lga;
        }
      }

      final puKey = _sanitizeId('${state}_${lga}_${ward}_$pu');
      final docRef = FirebaseFirestore.instance
          .collection('election_results')
          .doc('${electionId}_$puKey');
      final docSnap = await docRef.get().timeout(const Duration(seconds: 10));

      List<dynamic> submissionsList = [];
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data() as Map<String, dynamic>;
        submissionsList = List.from(data['submissions'] ?? []);
      }

      // Load user profile name
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      final userProfile = userSnap.data();
      final observerName = FirebaseAuth.instance.currentUser?.displayName ??
          userProfile?['fullName'] ??
          userProfile?['name'] ??
          userProfile?['displayName'] ??
          'Observer';

      String? offlineSenatorialDistrict;
      try {
        final q = await FirebaseFirestore.instance
            .collection('lgas')
            .where('state', isEqualTo: state)
            .where('name', isEqualTo: lga)
            .get();
        if (q.docs.isNotEmpty) {
          offlineSenatorialDistrict =
              q.docs.first.data()['senatorialDistrict']?.toString() ??
                  q.docs.first.data()['senatorial_district']?.toString();
        } else {
          final docSnap = await FirebaseFirestore.instance
              .collection('lgas')
              .doc('${state}_$lga')
              .get();
          if (docSnap.exists) {
            offlineSenatorialDistrict =
                docSnap.data()?['senatorialDistrict']?.toString() ??
                    docSnap.data()?['senatorial_district']?.toString();
          }
        }
      } catch (e) {
        debugPrint("Error fetching offline senatorial district: $e");
      }

      final newReport = {
        'submittedBy': user?.uid,
        'submittedByName': observerName,
        'phone': userProfile?['phone'] ?? userProfile?['phoneNumber'] ?? 'N/A',
        'submittedAt': Timestamp.now(),
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pu,
        'partyVotes': partyVotes,
        'results': partyVotes,
        'evidenceUrl': evidenceUrl ?? '',
        'status': isFinal ? 'final' : 'draft',
        if (offlineSenatorialDistrict != null)
          'senatorialDistrict': offlineSenatorialDistrict,
        if (offlineAssemblyConstituency != null)
          'stateAssemblyConstituency': offlineAssemblyConstituency,
        ...stats
          ..remove('electionId')
          ..remove('state')
          ..remove('lga')
          ..remove('ward')
          ..remove('pollingUnit')
          ..remove('isFinal'),
      };

      final index =
          submissionsList.indexWhere((sub) => sub['submittedBy'] == user?.uid);
      if (index != -1) {
        submissionsList[index] = newReport;
      } else {
        submissionsList.add(newReport);
      }

      final isNewDoc = !docSnap.exists;
      final Map<String, dynamic> docPayload = {
        'electionId': electionId,
        'electionType': electionType,
        if (primaryElectionType != null)
          'primaryElectionType': primaryElectionType,
        if (primaryParty != null) 'primaryParty': primaryParty,
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pu,
        'partyVotes': partyVotes,
        'results': partyVotes,
        if (evidenceUrl != null) 'evidenceUrl': evidenceUrl,
        'submittedBy': user?.uid,
        'submittedByName': observerName,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNewDoc) 'createdAt': FieldValue.serverTimestamp(),
        if (offlineSenatorialDistrict != null)
          'senatorialDistrict': offlineSenatorialDistrict,
        if (offlineAssemblyConstituency != null)
          'stateAssemblyConstituency': offlineAssemblyConstituency,
        ...stats
          ..remove('electionId')
          ..remove('state')
          ..remove('lga')
          ..remove('ward')
          ..remove('pollingUnit')
          ..remove('isFinal'),
        'submissions': submissionsList,
      };

      await docRef
          .set(docPayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // Mark as synced locally
      await context.read<db.AppDatabase>().markResultSynced(result.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline Form for $pu Synced Successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (modalState != null) {
        modalState(() => _syncingMap[result.id] = false);
      } else {
        if (mounted) setState(() => _syncingMap.remove(result.id));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadElection();
    _startNetworkTimer();

    _unsyncedSubject = BehaviorSubject<List<dynamic>>();

    final resultsStream = context.read<db.AppDatabase>().watchUnsyncedResults();
    final checklistsStream =
        context.read<db.AppDatabase>().watchUnsyncedChecklists();
    final incidentsStream =
        context.read<db.AppDatabase>().watchUnsyncedIncidents();

    Rx.combineLatest3(
      resultsStream,
      checklistsStream,
      incidentsStream,
      (List<db.Result> r, List<db.Checklist> c, List<db.Incident> i) {
        final filteredResults = r.where((item) {
          try {
            final stats =
                jsonDecode(item.ballotStatsJson) as Map<String, dynamic>;
            return stats['electionId'] == widget.electionId;
          } catch (e) {
            return false;
          }
        }).toList();

        final filteredChecklists = c.where((item) {
          return item.title.endsWith(widget.electionId);
        }).toList();

        final filteredIncidents = i.where((item) {
          return item.severity == 'reported_${widget.electionId}';
        }).toList();

        return [
          ...filteredResults,
          ...filteredChecklists,
          ...filteredIncidents
        ];
      },
    ).listen((event) {
      if (!_unsyncedSubject.isClosed) {
        _unsyncedSubject.add(event);
      }
    });
  }

  @override
  void dispose() {
    _networkCheckTimer?.cancel();
    _tabController.dispose();
    _unsyncedSubject.close();
    super.dispose();
  }

  void _startNetworkTimer() {
    // Initial check
    _checkNetwork();
    // Periodic check
    _networkCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkNetwork());
  }

  bool _isAutoSyncing = false;

  Future<void> _autoSyncOfflineItems() async {
    if (_isOffline || _isAutoSyncing) return;
    _isAutoSyncing = true;

    try {
      final database = context.read<db.AppDatabase>();

      // Fetch and filter results (only final submissions)
      final results = await database.getUnsyncedResults();
      final filteredResults = results.where((item) {
        try {
          final stats =
              jsonDecode(item.ballotStatsJson) as Map<String, dynamic>;
          final isFinal = stats['isFinal'] == true;
          return stats['electionId'] == widget.electionId && isFinal;
        } catch (e) {
          return false;
        }
      }).toList();

      // Fetch and filter checklists (only completed/final checklists)
      final checklists = await database.getUnsyncedChecklists();
      final filteredChecklists = checklists.where((item) {
        return item.title.endsWith(widget.electionId) && item.isCompleted;
      }).toList();

      // Fetch and filter incidents (incidents submitted offline are always final reports)
      final incidents = await database.getUnsyncedIncidents();
      final filteredIncidents = incidents.where((item) {
        return item.severity == 'reported_${widget.electionId}';
      }).toList();

      if (filteredResults.isEmpty &&
          filteredChecklists.isEmpty &&
          filteredIncidents.isEmpty) {
        _isAutoSyncing = false;
        return;
      }

      debugPrint(
          '[AutoSync] Restored connection. Auto-syncing ${filteredResults.length} final results, ${filteredChecklists.length} final checklists, ${filteredIncidents.length} incidents.');

      for (final result in filteredResults) {
        await _syncOfflineResult(result);
      }
      for (final checklist in filteredChecklists) {
        await _syncOfflineChecklist(checklist);
      }
      for (final incident in filteredIncidents) {
        await _syncOfflineIncident(incident);
      }
    } catch (e) {
      debugPrint('[AutoSync] Error: $e');
    } finally {
      _isAutoSyncing = false;
    }
  }

  Future<void> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (_isOffline != !isConnected) {
        if (mounted) {
          setState(() {
            _isOffline = !isConnected;
          });
          if (isConnected) {
            _autoSyncOfflineItems();
          }
        }
      }
    } catch (_) {
      if (!_isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    }
  }

  Future<void> _loadElection() async {
    final doc =
        await _firestore.collection('elections').doc(widget.electionId).get();
    if (doc.exists && mounted) {
      setState(() {
        _election = Election.fromFirestore(doc.data()!, doc.id);
        _loading = false;
      });
    }
  }

  /// Helper to check if two dates are the same day
  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Parse date from various formats
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Find related elections happening on the same day at the same polling unit
  Future<List<Map<String, dynamic>>> _findRelatedElections() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _election == null) {
        debugPrint('FindRelatedElections: User is $user, _election is ${_election?.name}');
        return [];
      }

      // Get user profile for location info
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userProfile = profile.data() ?? {};
      debugPrint('FindRelatedElections: User Profile data: $userProfile');

      final state = userProfile['assignedState']?.toString() ?? '';
      final lga = userProfile['assignedLga']?.toString() ?? '';
      final ward = userProfile['assignedWard']?.toString() ?? '';
      debugPrint('FindRelatedElections: Observer location: state=$state, lga=$lga, ward=$ward');

      // Get all elections
      final electionsSnap =
          await FirebaseFirestore.instance.collection('elections').get();
      final relatedElections = <Map<String, dynamic>>[];
      debugPrint('FindRelatedElections: Total elections found in db: ${electionsSnap.docs.length}');

      for (final doc in electionsSnap.docs) {
        if (doc.id == widget.electionId) continue; // Skip current election

        final data = doc.data();
        final electionName = data['name'] ?? 'Unknown';
        final startDate = _parseDate(data['startDate']);
        final electionType = data['type'] ?? 'GENERAL';

        final dateMatches = _isSameDay(startDate, _election!.startDate);
        debugPrint('FindRelatedElections: Checking election ${doc.id} ($electionName): startDate=$startDate, dateMatches=$dateMatches');
        if (!dateMatches) continue;

        // Safely parse state
        List<String> electionStates = [];
        final rawState = data['state'] ?? data['states'] ?? data['targetStates'] ?? data['region'] ?? data['regions'] ?? data['targetJurisdictions'];
        if (rawState is List) {
          electionStates = rawState.map((e) => e.toString()).toList();
        } else if (rawState is String) {
          electionStates = [rawState];
        }

        // Safely parse lga
        List<String> electionLgas = [];
        final rawLga = data['lga'] ?? data['lgas'] ?? data['targetLgas'];
        if (rawLga is List) {
          electionLgas = rawLga.map((e) => e.toString()).toList();
        } else if (rawLga is String) {
          electionLgas = [rawLga];
        }

        // Safely parse ward
        List<String> electionWards = [];
        final rawWard = data['ward'] ?? data['wards'] ?? data['targetWards'];
        if (rawWard is List) {
          electionWards = rawWard.map((e) => e.toString()).toList();
        } else if (rawWard is String) {
          electionWards = [rawWard];
        }

        debugPrint('FindRelatedElections: parsedStates=$electionStates, parsedLgas=$electionLgas, parsedWards=$electionWards');

        bool locationMatch = false;
        if (state.isNotEmpty && lga.isNotEmpty) {
          final hasStateMatch = electionStates.any((s) => s.trim().toLowerCase() == state.trim().toLowerCase()) ||
              electionStates.isEmpty;
          
          final hasLgaMatch = electionLgas.any((l) => l.trim().toLowerCase() == lga.trim().toLowerCase()) ||
              electionLgas.isEmpty;
          
          final hasWardMatch = electionWards.any((w) => w.trim().toLowerCase() == ward.trim().toLowerCase()) ||
              electionWards.isEmpty;

          debugPrint('FindRelatedElections: locationMatch hasStateMatch=$hasStateMatch, hasLgaMatch=$hasLgaMatch, hasWardMatch=$hasWardMatch');
          if (hasStateMatch && hasLgaMatch && hasWardMatch) {
            locationMatch = true;
          }
        } else {
          // If observer profile has no location assigned, match anyway
          locationMatch = true;
        }

        debugPrint('FindRelatedElections: final locationMatch=$locationMatch');

        if (locationMatch) {
          relatedElections.add({
            'id': doc.id,
            'name': electionName,
            'type': electionType,
          });
        }
      }

      debugPrint('FindRelatedElections: Returning related elections count: ${relatedElections.length}');
      return relatedElections;
    } catch (e, stackTrace) {
      debugPrint('Error finding related elections: $e\n$stackTrace');
      return [];
    }
  }

  /// Check for and import checklist from related elections
  Future<void> _importChecklistFromRelatedElection() async {
    // Skip if already prompted for this election in this session
    if (_promptedChecklistElections.contains(widget.electionId)) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Double check if there's already a checklist for the current election with answers
      final currentDocId = '${user.uid}_${widget.electionId}';
      final currentDoc = await FirebaseFirestore.instance
          .collection('observer_checklists')
          .doc(currentDocId)
          .get();
      if (currentDoc.exists) {
        final currentData = currentDoc.data();
        if (currentData != null && currentData['answers'] != null && (currentData['answers'] as Map).isNotEmpty) {
          return;
        }
      }

      final relatedElections = await _findRelatedElections();
      if (relatedElections.isEmpty) return;

      // Check each related election for a checklist
      for (final election in relatedElections) {
        final electionId = election['id'] as String;
        final docId = '${user.uid}_$electionId';

        final doc = await FirebaseFirestore.instance
            .collection('observer_checklists')
            .doc(docId)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;

          // Import if it has answers, whether submitted or draft
          if (data['answers'] != null && (data['answers'] as Map).isNotEmpty) {
            // Mark as prompted
            _promptedChecklistElections.add(widget.electionId);

            // Show import dialog
            if (mounted) {
              final shouldImport = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    'Import Checklist?',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  content: Text(
                    'An existing checklist was found for "${election['name']}" on the same day. Would you like to auto-populate this checklist with its answers as a draft for review?',
                    style: GoogleFonts.outfit(color: Colors.black),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('NO',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065F46)),
                      child: Text('IMPORT',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (shouldImport == true) {
                // Import the answers to the current election as a draft
                // so the user can review before finalizing
                await FirebaseFirestore.instance
                    .collection('observer_checklists')
                    .doc(currentDocId)
                    .set({
                  'electionId': widget.electionId,
                  'observerId': user.uid,
                  'state': data['state'],
                  'lga': data['lga'],
                  'ward': data['ward'],
                  'pollingUnit': data['pollingUnit'],
                  'answers': data['answers'],
                  'status': 'draft', // Import as draft for review
                  'timestamp': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Checklist imported! Please review before finalizing.'),
                        backgroundColor: Color(0xFF10B981)),
                  );
                }
                return; // Stop after first successful import
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing checklist: $e');
    }
  }

  /// Check for and import incident from related elections
  Future<void> _importIncidentFromRelatedElection() async {
    // Skip if already prompted for this election in this session
    if (_promptedIncidentElections.contains(widget.electionId)) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if there is already a draft incident or a reported incident for the current election
      final currentDraftDoc = await FirebaseFirestore.instance
          .collection('incident_reports')
          .doc('${widget.electionId}_${user.uid}_draft')
          .get();
      if (currentDraftDoc.exists) {
        final data = currentDraftDoc.data();
        if (data != null && data['incidentType'] != null && data['description'] != null && data['description'].toString().isNotEmpty) {
          return; // Already has draft details, do not overwrite/prompt
        }
      }

      final currentReportedSnap = await FirebaseFirestore.instance
          .collection('incident_reports')
          .where('electionId', isEqualTo: widget.electionId)
          .where('observerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'reported')
          .limit(1)
          .get();
      if (currentReportedSnap.docs.isNotEmpty) {
        return; // Already submitted a report, do not prompt
      }

      final relatedElections = await _findRelatedElections();
      if (relatedElections.isEmpty) return;

      // Check each related election for reported incidents or draft incidents
      for (final election in relatedElections) {
        final electionId = election['id'] as String;

        // Try to fetch a reported incident first
        final querySnap = await FirebaseFirestore.instance
            .collection('incident_reports')
            .where('electionId', isEqualTo: electionId)
            .where('observerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'reported')
            .limit(1)
            .get();

        Map<String, dynamic>? sourceData;
        if (querySnap.docs.isNotEmpty) {
          sourceData = querySnap.docs.first.data();
        } else {
          // If no reported incident, try to fetch a draft incident
          final draftDoc = await FirebaseFirestore.instance
              .collection('incident_reports')
              .doc('${electionId}_${user.uid}_draft')
              .get();
          if (draftDoc.exists) {
            sourceData = draftDoc.data();
          }
        }

        // If we found incident data from a related election
        if (sourceData != null && sourceData['incidentType'] != null) {
          // Mark as prompted
          _promptedIncidentElections.add(widget.electionId);

          // Show import dialog
          if (mounted) {
            final shouldImport = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text(
                  'Import Incident Report?',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
                content: Text(
                  'An existing incident report was found for "${election['name']}" on the same day. Would you like to auto-populate this incident report as a draft for review?',
                  style: GoogleFonts.outfit(color: Colors.black),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('NO',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46)),
                    child: Text('IMPORT',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            );

            if (shouldImport == true) {
              final payload = {
                'electionId': widget.electionId,
                'observerId': user.uid,
                'submittedBy': user.uid,
                'incidentType': sourceData['incidentType'],
                'description': sourceData['description'],
                'mediaItems': sourceData['mediaItems'] ?? [],
                'mediaUrls': sourceData['mediaUrls'] ?? [],
                'state': sourceData['state'],
                'lga': sourceData['lga'],
                'ward': sourceData['ward'],
                'pollingUnit': sourceData['pollingUnit'],
                'latitude': sourceData['latitude'],
                'longitude': sourceData['longitude'],
                'deviceId': 'OBS-${DateTime.now().millisecondsSinceEpoch}',
                'status': 'draft', // Save as draft for the current election
                'isSynced': true,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              // Import the incident as draft to the current election
              await FirebaseFirestore.instance
                  .collection('incident_reports')
                  .doc('${widget.electionId}_${user.uid}_draft')
                  .set(payload, SetOptions(merge: true));

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Incident report imported as draft! Please review.'),
                      backgroundColor: Color(0xFF10B981)),
                );
              }
              return; // Stop after first successful import
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing incident: $e');
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout Confirmation',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        content: Text(
            'Are you sure you want to log out of VoteGuard? Any unsaved progress may be lost.',
            style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('LOGOUT',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Stream<List<dynamic>> _watchAllUnsynced() {
    final resultsStream = context.read<db.AppDatabase>().watchUnsyncedResults();
    final checklistsStream =
        context.read<db.AppDatabase>().watchUnsyncedChecklists();
    final incidentsStream =
        context.read<db.AppDatabase>().watchUnsyncedIncidents();

    return Rx.combineLatest3(
      resultsStream,
      checklistsStream,
      incidentsStream,
      (List<db.Result> r, List<db.Checklist> c, List<db.Incident> i) {
        return [...r, ...c, ...i];
      },
    );
  }

  Future<void> _deleteOfflineChecklist(int localId) async {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Offline Checklist',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text(
            'Are you sure you want to permanently delete this offline saved checklist draft?',
            style: GoogleFonts.outfit(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(confirmCtx);
              await context.read<db.AppDatabase>().deleteChecklist(localId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Offline checklist draft deleted'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: Text('DELETE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOfflineIncident(int localId) async {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Offline Incident',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text(
            'Are you sure you want to permanently delete this offline saved incident report?',
            style: GoogleFonts.outfit(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(confirmCtx);
              await context.read<db.AppDatabase>().deleteIncident(localId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Offline incident report deleted'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: Text('DELETE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncOfflineChecklist(db.Checklist checklist,
      [StateSetter? modalState]) async {
    if (modalState != null) {
      modalState(() => _syncingMap[checklist.id] = true);
    } else {
      if (mounted) setState(() => _syncingMap[checklist.id] = true);
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      final answers = jsonDecode(checklist.category) as Map<String, dynamic>;

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      final userProfile = userSnap.data();

      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'state': userProfile?['assignedState'],
        'lga': userProfile?['assignedLga'],
        'ward': userProfile?['assignedWard'],
        'pollingUnit': userProfile?['assignedPollingUnit'],
        'answers': answers,
        'status': checklist.isCompleted ? 'submitted' : 'draft',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('observer_checklists')
          .doc(checklist.title)
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      await context.read<db.AppDatabase>().markChecklistSynced(checklist.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Offline Checklist Synced Successfully!'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Checklist Sync Failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (modalState != null) {
        modalState(() => _syncingMap[checklist.id] = false);
      } else {
        if (mounted) setState(() => _syncingMap.remove(checklist.id));
      }
    }
  }

  Future<void> _syncOfflineIncident(db.Incident incident,
      [StateSetter? modalState]) async {
    if (modalState != null) {
      modalState(() => _syncingMap[incident.id] = true);
    } else {
      if (mounted) setState(() => _syncingMap[incident.id] = true);
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      final mediaPaths = List<String>.from(jsonDecode(incident.mediaPathsJson));
      final List<Map<String, String>> mediaItems = [];

      for (int i = 0; i < mediaPaths.length; i++) {
        final file = File(mediaPaths[i]);
        if (await file.exists()) {
          final ref = FirebaseStorage.instance.ref().child(
              'incidents/${user?.uid}/${DateTime.now().millisecondsSinceEpoch}_$i');
          await ref.putFile(file).timeout(const Duration(seconds: 15));
          final url = await ref.getDownloadURL();
          mediaItems.add({'url': url, 'type': 'photo'});
        }
      }

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      final userProfile = userSnap.data();

      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'submittedBy': user?.uid,
        'incidentType': incident.category,
        'description': incident.description,
        'mediaItems': mediaItems,
        'mediaUrls': mediaItems.map((e) => e['url']).toList(),
        'state': userProfile?['assignedState'],
        'lga': userProfile?['assignedLga'],
        'ward': userProfile?['assignedWard'],
        'pollingUnit': userProfile?['assignedPollingUnit'],
        'latitude': incident.latitude,
        'longitude': incident.longitude,
        'deviceId': 'OBS-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'reported',
        'isSynced': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('incident_reports')
          .add(payload)
          .timeout(const Duration(seconds: 10));

      await context.read<db.AppDatabase>().markIncidentSynced(incident.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Offline Incident Synced Successfully!'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Incident Sync Failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (modalState != null) {
        modalState(() => _syncingMap[incident.id] = false);
      } else {
        if (mounted) setState(() => _syncingMap.remove(incident.id));
      }
    }
  }

  Widget _buildOfflineSyncBanner() {
    return StreamBuilder<List<dynamic>>(
      stream: _unsyncedSubject.stream,
      builder: (context, snapshot) {
        final unsynced = snapshot.data ?? [];

        // If there's no offline unsynced data and we are online, hide the banner
        if (unsynced.isEmpty && !_isOffline) return const SizedBox.shrink();

        final colors = _isOffline
            ? [
                const Color(0xFFEF4444),
                const Color(0xFFF87171)
              ] // Red alert gradient for offline
            : [
                const Color(0xFFD97706),
                const Color(0xFFF59E0B)
              ]; // Amber warning gradient for pending sync

        final text = _isOffline
            ? 'Offline Mode: Data will be saved locally. Tap to manage & upload'
            : "${unsynced.length} Form${unsynced.length > 1 ? 's' : ''} Stored Offline (Pending Sync)";

        final actionLabel = _isOffline ? 'MANAGE' : 'SYNC NOW';
        final iconData =
            _isOffline ? LucideIcons.wifiOff : LucideIcons.cloudLightning;

        return Builder(
          builder: (builderContext) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => Scaffold.of(builderContext).openEndDrawer(),
              child: Row(
                children: [
                  Icon(iconData, color: Colors.white, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        actionLabel,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineSyncSidebar() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.cloudLightning,
                      color: Color(0xFFD97706), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Manager',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A))),
                        Text('Offline Saved Submissions',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<dynamic>>(
                stream: _unsyncedSubject.stream,
                builder: (context, snapshot) {
                  final unsynced = snapshot.data ?? [];
                  if (unsynced.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.check,
                              color: Color(0xFF10B981), size: 48),
                          const SizedBox(height: 16),
                          Text('All Forms Synced!',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A))),
                          Text('No offline items pending.',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }

                  return StatefulBuilder(
                    builder: (context, setStateModal) => ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: unsynced.length,
                      itemBuilder: (context, index) {
                        try {
                          final item = unsynced[index];

                          if (item is db.Result) {
                            Map<String, dynamic> stats = {};
                            try {
                              stats = jsonDecode(item.ballotStatsJson)
                                  as Map<String, dynamic>;
                            } catch (e) {}
                            final pu = stats['pollingUnit'] ?? '';
                            final isFinal = stats['isFinal'] == true;
                            final isSyncing = _syncingMap[item.id] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: const Color(0xFFF8FAFC),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            pu.isNotEmpty
                                                ? pu
                                                : 'Election Result Form',
                                            style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        _buildSidebarTypeBadge('RESULTS'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: ${isFinal ? 'FINAL' : 'DRAFT'}',
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2,
                                              color: Color(0xFFEF4444),
                                              size: 18),
                                          onPressed: isSyncing
                                              ? null
                                              : () =>
                                                  _deleteOfflineResult(item.id),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSidebarSyncButton(
                                          isSyncing: isSyncing,
                                          onTap: () => _syncOfflineResult(
                                              item, setStateModal),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (item is db.Checklist) {
                            final isFinal = item.isCompleted;
                            final isSyncing = _syncingMap[item.id] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: const Color(0xFFF8FAFC),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Observer Checklist Form',
                                            style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        _buildSidebarTypeBadge('CHECKLIST'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: ${isFinal ? 'SUBMITTED' : 'DRAFT'}',
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2,
                                              color: Color(0xFFEF4444),
                                              size: 18),
                                          onPressed: isSyncing
                                              ? null
                                              : () => _deleteOfflineChecklist(
                                                  item.id),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSidebarSyncButton(
                                          isSyncing: isSyncing,
                                          onTap: () => _syncOfflineChecklist(
                                              item, setStateModal),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (item is db.Incident) {
                            final isSyncing = _syncingMap[item.id] == true;
                            final label = item.category
                                .replaceAll('_', ' ')
                                .toUpperCase();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: const Color(0xFFF8FAFC),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            label,
                                            style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: const Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildSidebarTypeBadge('INCIDENT'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2,
                                              color: Color(0xFFEF4444),
                                              size: 18),
                                          onPressed: isSyncing
                                              ? null
                                              : () => _deleteOfflineIncident(
                                                  item.id),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSidebarSyncButton(
                                          isSyncing: isSyncing,
                                          onTap: () => _syncOfflineIncident(
                                              item, setStateModal),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Fallback debug card if type is unknown
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Unrecognized Item Type: ${item.runtimeType}\nDetails: $item',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF991B1B)),
                              ),
                            ),
                          );
                        } catch (e, stack) {
                          print('Error building sync card: $e\n$stack');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error rendering card: $e',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF991B1B),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarTypeBadge(String label) {
    Color color = const Color(0xFF065F46);
    Color bg = const Color(0xFFECFDF5);
    if (label == 'CHECKLIST') {
      color = const Color(0xFF1E3A8A);
      bg = const Color(0xFFEFF6FF);
    } else if (label == 'INCIDENT') {
      color = const Color(0xFFB45309);
      bg = const Color(0xFFFEF3C7);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
            fontSize: 9, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }

  Widget _buildSidebarSyncButton(
      {required bool isSyncing, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      onPressed: isSyncing ? null : onTap,
      icon: isSyncing
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(LucideIcons.cloudLightning,
              size: 12, color: Colors.white),
      label: Text(
        isSyncing ? 'SYNCING...' : 'SYNC NOW',
        style: GoogleFonts.outfit(
            fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF065F46))));
    if (_election == null)
      return const Scaffold(body: Center(child: Text('Election not found')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_election!.name,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A))),
            Text('OBSERVER DASHBOARD',
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10B981),
                    letterSpacing: 1)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut,
                color: Color(0xFFEF4444), size: 20),
            onPressed: () => _showLogoutConfirmation(),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false, // Forces all tabs to fit on screen
          labelPadding: const EdgeInsets.symmetric(
              horizontal: 2), // Minimizes padding for small screens
          labelColor: const Color(0xFF065F46),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF065F46),
          labelStyle:
              GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'DASHBOARD'),
            Tab(text: 'CHECKLIST'),
            Tab(text: 'INCIDENTS'),
            Tab(text: 'RESULTS'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildOfflineSyncBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DashboardTab(
                    electionId: widget.electionId,
                    tabController: _tabController,
                    isOffline: _isOffline),
                _ChecklistTab(
                    electionId: widget.electionId,
                    onImportFromRelated: _importChecklistFromRelatedElection),
                _IncidentsTab(
                    electionId: widget.electionId,
                    onImportFromRelated: _importIncidentFromRelatedElection),
                _EC8AResultsTab(electionId: widget.electionId),
              ],
            ),
          ),
        ],
      ),
      endDrawer: _buildOfflineSyncSidebar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showChatOverlay,
        backgroundColor: const Color(0xFF0F172A),
        child: const Icon(LucideIcons.messageSquare, color: Colors.white),
      ),
    );
  }

  void _showChatOverlay() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Opening Group Chat...'),
        duration: Duration(milliseconds: 500)));

    // Fetch user profile for state and name
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data() ?? {};
    final state = data['assignedState']?.toString().toLowerCase() ?? 'national';
    final groupId = 'group_state_$state';
    final fullName = data['name'] ?? data['fullName'] ?? 'Observer';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatWidget(
        groupId: groupId,
        userId: user.uid,
        userName: fullName,
        role: data['role'] ?? 'OBSERVER',
      ),
    );
  }
}

// --- TAB 1: DASHBOARD ---
class _DashboardTab extends StatelessWidget {
  final String electionId;
  final TabController tabController;
  final bool isOffline;

  const _DashboardTab(
      {required this.electionId,
      required this.tabController,
      required this.isOffline});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(user?.uid).snapshots(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data?.data() as Map<String, dynamic>?;

          return StreamBuilder<List<int>>(
            stream: Rx.combineLatest3(
                firestore
                    .collection('observer_checklists')
                    .where('electionId', isEqualTo: electionId)
                    .where('observerId', isEqualTo: user?.uid)
                    .snapshots(),
                firestore
                    .collection('incident_reports')
                    .where('electionId', isEqualTo: electionId)
                    .where('observerId', isEqualTo: user?.uid)
                    .snapshots(),
                firestore
                    .collection('election_results')
                    .where('electionId', isEqualTo: electionId)
                    .where('submittedBy', isEqualTo: user?.uid)
                    .snapshots(),
                (check, inc, res) =>
                    [check.docs.length, inc.docs.length, res.docs.length]),
            builder: (context, statsSnapshot) {
              final stats = statsSnapshot.data ?? [0, 0, 0];

              return ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _buildCommandHeader(profile),
                  const SizedBox(height: 24),
                  _buildStatGrid(context, stats, profile),
                  const SizedBox(height: 24),
                  _buildAnalyticsSection(),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildSupportSection(context),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        });
  }

  Widget _buildCommandHeader(Map<String, dynamic>? profile) {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOffline
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: isOffline
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isOffline ? 'SYSTEM OFFLINE' : 'SYSTEM LIVE',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isOffline
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF065F46),
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                  DateFormat('EEEE, MMM d')
                      .format(DateTime.now())
                      .toUpperCase(),
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Command Center',
              style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -1)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBadge('2024 PRESIDENTIAL ELECTION', const Color(0xFFF1F5F9),
                  const Color(0xFF475569)),
              const SizedBox(width: 8),
              _buildBadge('#VG-8829-LIVE', const Color(0xFFECFDF5),
                  const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                  fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
              children: [
                const TextSpan(text: 'Welcome back, '),
                TextSpan(
                    text:
                        user?.displayName ?? profile?['fullName'] ?? 'Observer',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const TextSpan(text: '. Deployment verified for '),
                TextSpan(
                    text:
                        '${profile?['assignedState'] ?? 'FCT'} / ${profile?['assignedLga'] ?? 'Abuja'}.',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: GoogleFonts.outfit(
            fontSize: 9, fontWeight: FontWeight.w900, color: textCol),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildStatGrid(
      BuildContext context, List<int> stats, Map<String, dynamic>? profile) {
    final checklist = stats[0];
    final incidents = stats[1];
    final results = stats[2];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildStatCard('Checklists', checklist.toString(),
                    LucideIcons.fileCheck, const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard('Incidents', incidents.toString(),
                    LucideIcons.triangleAlert, const Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildMetricCard(
                    'PU RESULTS',
                    results.toString(),
                    'VALIDATED & UPLOADED',
                    LucideIcons.trendingUp,
                    const Color(0xFF10B981),
                    'ACTIVE SUBMISSION')),
            const SizedBox(width: 16),
            Expanded(
                child: _buildMetricCard(
                    'LIVE INCIDENTS',
                    incidents.toString(),
                    'REQUIRING REVIEW',
                    LucideIcons.triangleAlert,
                    const Color(0xFFEF4444),
                    'CRISIS CONTROL')),
          ],
        ),
        const SizedBox(height: 16),
        _buildLocationCard(profile),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, IconData icon,
      Color color, String badge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Flexible(
                  child: _buildBadge(badge, color.withOpacity(0.1), color)),
            ],
          ),
          const SizedBox(height: 16),
          Text(val,
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(sub,
              style: GoogleFonts.outfit(
                  fontSize: 8,
                  color: const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic>? profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.mapPin,
                  color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEPLOYMENT INTELLIGENCE',
                        style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8))),
                    Text(profile?['assignedLga'] ?? 'Area Council',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A))),
                    Text(profile?['assignedState'] ?? 'State/FCT',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              _buildBadge(
                  'SECURED', const Color(0xFFECFDF5), const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                _buildLocationRow('WARD', profile?['assignedWard'] ?? 'N/A'),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildLocationRow(
                    'POLLING UNIT', profile?['assignedPollingUnit'] ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 120,
              width: double.infinity,
              color: const Color(0xFFF8FAFC),
              child: const Icon(LucideIcons.map,
                  size: 40, color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8))),
        const SizedBox(width: 16),
        Flexible(
            child: Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B)),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return Row(
      children: [
        Expanded(child: _buildDonutChart()),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildPulseChart()),
      ],
    );
  }

  Widget _buildDonutChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIVITY MIX',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8))),
          const Spacer(),
          SizedBox(
            height: 100,
            child: PieChart(PieChartData(sections: [
              PieChartSectionData(
                  color: const Color(0xFF10B981),
                  value: 40,
                  radius: 20,
                  showTitle: false),
              PieChartSectionData(
                  color: const Color(0xFFEF4444),
                  value: 20,
                  radius: 20,
                  showTitle: false),
              PieChartSectionData(
                  color: const Color(0xFF0F172A),
                  value: 40,
                  radius: 20,
                  showTitle: false),
            ], centerSpaceRadius: 30)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPulseChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('OPERATIONAL PULSE',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Flexible(
                  child: _buildBadge('LIVE TRACKING', const Color(0xFFF1F5F9),
                      const Color(0xFF64748B))),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 100,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: const Color(0xFF10B981),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withOpacity(0.1)),
                  spots: [
                    const FlSpot(0, 3),
                    const FlSpot(2.6, 2),
                    const FlSpot(4.9, 5),
                    const FlSpot(6.8, 3.1),
                    const FlSpot(8, 4)
                  ],
                )
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK ACTIONS',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          _buildActionItem('PROCESS CHECKLIST', LucideIcons.squareCheck,
              const Color(0xFF10B981), () => tabController.animateTo(1)),
          _buildActionItem('LOG INCIDENT', LucideIcons.triangleAlert,
              const Color(0xFFEF4444), () => tabController.animateTo(2)),
          _buildActionItem('RESULT ENTRY', LucideIcons.trendingUp,
              const Color(0xFF0F172A), () => tabController.animateTo(3)),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      String label, IconData icon, Color col, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 14)),
            const SizedBox(width: 16),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B))),
            const Spacer(),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Future<void> _initiateCall(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('system_settings')
          .get();
      if (doc.exists) {
        final valueStr = doc.data()?['value'] as String?;
        if (valueStr != null) {
          final valueJson = jsonDecode(valueStr);
          final phone = valueJson['support']?['phone'];
          if (phone != null && phone.toString().isNotEmpty) {
            final Uri url = Uri.parse('tel:$phone');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
              return;
            }
          }
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not initiate call. Support number not found.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildSupportSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(32)),
      child: Column(
        children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Color(0xFF10B981), shape: BoxShape.circle),
              child:
                  const Icon(LucideIcons.phone, color: Colors.white, size: 24)),
          const SizedBox(height: 20),
          Text('Security & Support',
              style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text('DIRECT ENCRYPTED UPLINK TO THE NATIONAL COMMAND CENTER.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8),
                  height: 1.5)),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => _initiateCall(context),
            child: Text('INITIATE VOICE CALL',
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10B981),
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

// --- PLACEHOLDER TABS (To be implemented in next phases) ---
class _ChecklistTab extends StatefulWidget {
  final String electionId;
  final Future<void> Function()? onImportFromRelated;
  const _ChecklistTab({required this.electionId, this.onImportFromRelated});

  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  List<dynamic> _questions = [];
  Map<String, dynamic>? _userProfile;
  bool _isFinalized = false;
  bool _hasSavedDraft = false;
  final Set<String> _editableFields = {};
  bool _isOffline = false;
  Timer? _networkCheckTimer;
  StreamSubscription<DocumentSnapshot>? _templateSubscription;
  StreamSubscription<DocumentSnapshot>? _templateDocSubscription;
  bool _hasImportedFromRelated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startNetworkTimer();
    _listenForTemplateChanges();
  }

  void _listenForTemplateChanges() {
    // Listen for changes to the election document to detect templateId updates
    _templateSubscription = FirebaseFirestore.instance
        .collection('elections')
        .doc(widget.electionId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final newTemplateId =
            snapshot.data()?['checklistTemplateId']?.toString();
        // Reload questions when template changes
        _loadQuestions(newTemplateId);
      }
    });
  }

  Future<void> _loadQuestions(String? templateId) async {
    List<dynamic> questionsData = [];
    if (templateId != null) {
      try {
        final templateDoc = await FirebaseFirestore.instance
            .collection('checklist_templates')
            .doc(templateId)
            .get()
            .timeout(const Duration(seconds: 10));
        final data = templateDoc.data();
        questionsData = (data?['questions'] as List<dynamic>?) ?? [];
        questionsData.sort((a, b) {
          final aOrder = (a is Map ? a['order'] : null) as num? ?? 0;
          final bOrder = (b is Map ? b['order'] : null) as num? ?? 0;
          return aOrder.compareTo(bOrder);
        });
      } catch (e) {
        debugPrint('Checklist: Offline questions fallback: $e');
        final localQs = await context
            .read<db.AppDatabase>()
            .getLocalChecklistQuestions(templateId);
        questionsData = localQs
            .map((q) => {
                  'id': q.id,
                  'text': q.questionText,
                  'type': q.type,
                  'order': q.order,
                  'category': q.category,
                })
            .toList();
      }
    } else {
      // Fallback to latest local template if no network and no templateId from election
      final latestLocal =
          await context.read<db.AppDatabase>().getLocalLatestTemplate();
      if (latestLocal != null) {
        final localQs = await context
            .read<db.AppDatabase>()
            .getLocalChecklistQuestions(latestLocal.id);
        questionsData = localQs
            .map((q) => {
                  'id': q.id,
                  'text': q.questionText,
                  'type': q.type,
                  'order': q.order,
                  'category': q.category,
                })
            .toList();
      }
    }

    if (mounted) {
      setState(() {
        _questions = questionsData;
      });
    }

    // Listen for real-time updates to this template's questions
    _templateDocSubscription?.cancel();
    if (templateId != null) {
      _templateDocSubscription = FirebaseFirestore.instance
          .collection('checklist_templates')
          .doc(templateId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data();
          final updatedQuestions = (data?['questions'] as List<dynamic>?) ?? [];
          setState(() {
            _questions = updatedQuestions;
          });
        }
      });
    }
  }

  Future<void> _loadData() async {
    // Force clear state to prevent cross-election data bleed
    if (mounted) {
      setState(() {
        _answers.clear();
        for (var c in _controllers.values) c.clear();
        _isFinalized = false;
        _hasSavedDraft = false;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      // Load user profile safely
      try {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get()
            .timeout(const Duration(seconds: 5));
        _userProfile = profile.data();
      } catch (profileError) {
        debugPrint('Checklist: Profile load failed/offline: $profileError');
      }

      // Step 1: Get the election template ID safely
      String? templateId;
      try {
        final electionDoc = await FirebaseFirestore.instance
            .collection('elections')
            .doc(widget.electionId)
            .get()
            .timeout(const Duration(seconds: 5));
        templateId = electionDoc.data()?['checklistTemplateId'];
      } catch (electionError) {
        debugPrint('Checklist: Election load failed/offline: $electionError');
      }

      // Step 2: Fallback to the latest template if not specified in the election
      if (templateId == null) {
        try {
          final latestTemplate = await FirebaseFirestore.instance
              .collection('checklist_templates')
              .orderBy('updatedAt', descending: true)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));
          if (latestTemplate.docs.isNotEmpty) {
            templateId = latestTemplate.docs.first.id;
          }
        } catch (templateListError) {
          debugPrint(
              'Checklist: Template list fetch failed: $templateListError');
        }
      }

      // Step 3: Fetch questions from the template document
      await _loadQuestions(templateId);

      final pu = _userProfile?['assignedPollingUnit'] ?? 'unknown_pu';
      final primaryId = '${user?.uid}_${widget.electionId}';
      final secondaryId = '${widget.electionId}_${user?.uid}_$pu';

      // Step 4: Load draft/submission
      bool loadedLocal = false;
      try {
        final localChecklists =
            await context.read<db.AppDatabase>().getAllChecklists();
        final matchIndex = localChecklists
            .indexWhere((c) => c.title == primaryId || c.title == secondaryId);
        if (matchIndex != -1) {
          final match = localChecklists[matchIndex];
          _answers
              .addAll(Map<String, dynamic>.from(jsonDecode(match.category)));
          _isFinalized = match.isCompleted;
          _hasSavedDraft = !match.isCompleted;
          loadedLocal = true;
        }
      } catch (localDbError) {
        debugPrint('Checklist: Error loading local checklist: $localDbError');
      }

      DocumentSnapshot? draft;
      try {
        draft = await FirebaseFirestore.instance
            .collection('observer_checklists')
            .doc(primaryId)
            .get();
        if (!draft.exists) {
          draft = await FirebaseFirestore.instance
              .collection('observer_checklists')
              .doc(secondaryId)
              .get();
        }
        // Query Fallback to make absolutely sure we find the document by fields!
        if (!draft.exists) {
          final querySnap = await FirebaseFirestore.instance
              .collection('observer_checklists')
              .where('observerId', isEqualTo: user?.uid)
              .where('electionId', isEqualTo: widget.electionId)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            draft = querySnap.docs.first;
            debugPrint('Checklist: Found document via query fallback!');
          }
        }
      } catch (e) {
        debugPrint('Checklist: Error fetching Firestore draft: $e');
      }

      final dataMap = draft?.data() as Map<String, dynamic>?;
      debugPrint(
          'Checklist load diagnostic: primaryId=$primaryId, draft.exists=${draft?.exists}, status=${dataMap?['status']}');

      if (mounted) {
        setState(() {
          if (draft != null && draft.exists) {
            final data = draft.data() as Map<String, dynamic>;
            _answers
                .clear(); // Clear any local data to prioritize the remote Firestore master document
            _answers.addAll(Map<String, dynamic>.from(data['answers'] ?? {}));
            _isFinalized = data['status'] == 'submitted';
            _hasSavedDraft = data['status'] == 'draft';

            // Initialize controllers with saved data from Firestore
            _answers.forEach((key, value) {
              if (!_controllers.containsKey(key)) {
                _controllers[key] =
                    TextEditingController(text: value?.toString());
              } else {
                _controllers[key]!.text = value?.toString() ?? '';
              }
            });

            // Auto-sync the local database record to match Firestore
            try {
              final dbInstance = context.read<db.AppDatabase>();
              dbInstance.getAllChecklists().then((localList) {
                final idx = localList.indexWhere(
                    (c) => c.title == primaryId || c.title == secondaryId);
                if (idx != -1) {
                  dbInstance.updateChecklistItem(
                    localList[idx].copyWith(
                      category: jsonEncode(_answers),
                      isCompleted: _isFinalized,
                      isSynced: true,
                      updatedAt: DateTime.now(),
                    ),
                  );
                } else {
                  dbInstance.insertChecklist(
                    db.ChecklistsCompanion(
                      title: drift.Value(primaryId),
                      category: drift.Value(jsonEncode(_answers)),
                      isCompleted: drift.Value(_isFinalized),
                      isSynced: const drift.Value(true),
                    ),
                  );
                }
              });
            } catch (err) {
              debugPrint('Local DB sync from Firestore failed: $err');
            }
          } else if (loadedLocal) {
            // Initialize controllers with saved local data
            _answers.forEach((key, value) {
              if (!_controllers.containsKey(key)) {
                _controllers[key] =
                    TextEditingController(text: value?.toString());
              } else {
                _controllers[key]!.text = value?.toString() ?? '';
              }
            });
          }

          // Intelligent Auto-fill Logic
          for (var q in _questions) {
            final text = (q['text'] ?? '').toString().toLowerCase();
            final qId = q['id'];
            final type = q['type']?.toString();

            // Skip any time or date related inputs from identity/geography auto-fill
            if (text.contains('time') ||
                text.contains('date') ||
                text.contains('at what time')) {
              continue;
            }

            // Skip numeric/count fields from identity/geography auto-fill
            if (type == 'number' ||
                text.contains('number of') ||
                text.contains('how many') ||
                text.contains('security personnel')) {
              continue;
            }

            if (_answers[qId] == null ||
                _answers[qId].toString().trim().isEmpty) {
              String? autoValue;
              if (text.contains('name') &&
                  !text.contains('officer') &&
                  !text.contains('agent')) {
                autoValue = _userProfile?['fullName'] ??
                    _userProfile?['name'] ??
                    _userProfile?['displayName'];
              } else if (text.contains('phone') || text.contains('mobile')) {
                autoValue =
                    _userProfile?['phone'] ?? _userProfile?['phoneNumber'];
              } else if (text.contains('lga') ||
                  text.contains('local government') ||
                  text.contains('l.g.a') ||
                  text.contains('government')) {
                autoValue = _userProfile?['assignedLga'];
              } else if (text.contains('ward')) {
                autoValue = _userProfile?['assignedWard'];
              } else if (text.contains('polling unit') ||
                  text.contains('polling_unit') ||
                  text == 'pu' ||
                  text.endsWith(' pu') ||
                  text.startsWith('pu ')) {
                autoValue = _userProfile?['assignedPollingUnit'];
              } else if (text.contains('state')) {
                autoValue = _userProfile?['assignedState'];
              }

              if (autoValue != null) {
                _answers[qId] = autoValue;
                if (!_controllers.containsKey(qId)) {
                  _controllers[qId] = TextEditingController(text: autoValue);
                } else {
                  _controllers[qId]!.text = autoValue;
                }
              }
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Checklist load error: $e');
      if (mounted) {
        setState(() => _loading = false);
        if (e.toString().contains('permission-denied') ||
            e.toString().contains('PERMISSION_DENIED')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Access Denied: Checklist templates require admin authorization.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ));
        }
      }
    }

    // After loading, check if we should import from related elections
    if (!_isFinalized &&
        !_hasSavedDraft &&
        !_hasImportedFromRelated &&
        widget.onImportFromRelated != null) {
      _hasImportedFromRelated = true;
      await widget.onImportFromRelated!();
      // Reload data to reflect any imported values
      if (mounted) {
        _loadData();
      }
    }
  }

  double get _completionProgress {
    if (_questions.isEmpty) return 0;
    int visibleCount = 0;
    int answeredCount = 0;
    for (var q in _questions) {
      if (!_isQuestionVisible(q)) continue;
      visibleCount++;
      if (_answers[q['id']] != null && _answers[q['id']].toString().isNotEmpty)
        answeredCount++;
    }
    return visibleCount == 0 ? 0 : answeredCount / visibleCount;
  }

  bool _isQuestionVisible(Map<String, dynamic> q) {
    final textLower = (q['text'] ?? '').toString().toLowerCase();

    bool _answerIsYes(String? answer) =>
        answer?.toString().trim().toLowerCase() == 'yes';
    bool _answerIsNo(String? answer) =>
        answer?.toString().trim().toLowerCase() == 'no';

    String? _questionIdByOrder(num order) {
      final target = order;
      final matches = _questions.whereType<Map>().where((q) {
        final qOrder = q['order'];
        if (qOrder is num) return qOrder == target;
        if (qOrder is String) return num.tryParse(qOrder) == target;
        return false;
      }).toList();
      if (matches.isNotEmpty) return matches.first['id']?.toString();

      // Fallback: match by id string directly
      final idMatches = _questions
          .whereType<Map>()
          .where((q) => q['id']?.toString() == target.toString())
          .toList();
      return idMatches.isNotEmpty ? idMatches.first['id']?.toString() : null;
    }

    final q27Id = _questionIdByOrder(27);
    final q28Id = _questionIdByOrder(28);
    final q31Id = _questionIdByOrder(31);
    final q32Id = _questionIdByOrder(32);
    final q33Id = _questionIdByOrder(33);
    final q34Id = _questionIdByOrder(34);
    final q35Id = _questionIdByOrder(35);
    final q38Id = _questionIdByOrder(38);
    final q39Id = _questionIdByOrder(39);
    final q40Id = _questionIdByOrder(40);

    if (q['id'] == q28Id && q27Id != null && !_answerIsYes(_answers[q27Id]))
      return false;
    if (q['id'] == q32Id && q31Id != null && !_answerIsYes(_answers[q31Id]))
      return false;
    if ((q['id'] == q34Id || q['id'] == q35Id) &&
        q33Id != null &&
        !_answerIsYes(_answers[q33Id])) return false;
    if (q['id'] == q39Id && q38Id != null && !_answerIsYes(_answers[q38Id]))
      return false;
    if (q['id'] == q40Id && q38Id != null && !_answerIsNo(_answers[q38Id]))
      return false;

    // Skip Q39/Q40 from generic text-based checks - they have their own visibility rules based on Q38
    final isQ39OrQ40 = q['id'] == q39Id || q['id'] == q40Id;

    // electoral commission members presence conditional visibility
    if (!isQ39OrQ40 &&
        textLower.contains('how many') &&
        textLower.contains('them')) {
      Map<String, dynamic>? parent;
      for (var item in _questions) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().toLowerCase();
          if (t.contains('electoral commission') && t.contains('present')) {
            parent = Map<String, dynamic>.from(item);
            break;
          }
        }
      }
      if (parent != null && !_answerIsYes(_answers[parent['id']])) return false;
    }

    // polling agents presence conditional visibility
    // Q39 and Q40 are exempt — they are controlled by Q38's specific rules above
    if (!isQ39OrQ40 && textLower.contains('how many') && textLower.contains('part')) {
      Map<String, dynamic>? parent;
      for (var item in _questions) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().toLowerCase();
          if (t.contains('agent') && t.contains('present')) {
            parent = Map<String, dynamic>.from(item);
            break;
          }
        }
      }
      if (parent != null && !_answerIsYes(_answers[parent['id']])) return false;
    }

    // agents signed / refused to sign conditional visibility
    // Q39 and Q40 are exempt — they are controlled exclusively by Q38's specific rules above
    final isSignedOrRefusedChild = !isQ39OrQ40 &&
        ((textLower.contains('if not') && textLower.contains('signed')) ||
            textLower.contains('refuse to sign') ||
            textLower.contains('refused to sign') ||
            textLower.contains('why did they refuse'));

    if (isSignedOrRefusedChild) {
      Map<String, dynamic>? parent;
      for (var item in _questions) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().toLowerCase();
          if (t.contains('agent') && t.contains('sign')) {
            parent = Map<String, dynamic>.from(item);
            break;
          }
        }
      }
      if (parent != null &&
          _answers[parent['id']]?.toString().toLowerCase() == 'no')
        return false;
    }

    return true;
  }

  bool _isQuestionDependent(Map<String, dynamic> q) {
    final textLower = (q['text'] ?? '').toString().toLowerCase();

    String? _questionIdByOrder(num order) {
      final target = order;
      final matches = _questions.whereType<Map>().where((item) {
        final qOrder = item['order'];
        if (qOrder is num) return qOrder == target;
        if (qOrder is String) return num.tryParse(qOrder) == target;
        return false;
      }).toList();
      if (matches.isNotEmpty) return matches.first['id']?.toString();

      final idMatches = _questions
          .whereType<Map>()
          .where((item) => item['id']?.toString() == target.toString())
          .toList();
      return idMatches.isNotEmpty ? idMatches.first['id']?.toString() : null;
    }

    final q28Id = _questionIdByOrder(28);
    final q32Id = _questionIdByOrder(32);
    final q34Id = _questionIdByOrder(34);
    final q35Id = _questionIdByOrder(35);
    final q39Id = _questionIdByOrder(39);
    final q40Id = _questionIdByOrder(40);

    if (q['id'] == q28Id ||
        q['id'] == q32Id ||
        q['id'] == q34Id ||
        q['id'] == q35Id ||
        q['id'] == q39Id ||
        q['id'] == q40Id) {
      return true;
    }

    final isQ39OrQ40 = q['id'] == q39Id || q['id'] == q40Id;

    if (!isQ39OrQ40 &&
        textLower.contains('how many') &&
        textLower.contains('them')) {
      for (var item in _questions) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().toLowerCase();
          if (t.contains('electoral commission') && t.contains('present')) {
            return true;
          }
        }
      }
    }

    if (!isQ39OrQ40 && textLower.contains('how many') && textLower.contains('part')) {
      for (var item in _questions) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().toLowerCase();
          if (t.contains('agent') && t.contains('present')) {
            return true;
          }
        }
      }
    }

    final isSignedOrRefusedChild = !isQ39OrQ40 &&
        ((textLower.contains('if not') && textLower.contains('signed')) ||
            textLower.contains('refuse to sign') ||
            textLower.contains('refused to sign') ||
            textLower.contains('why did they refuse'));

    if (isSignedOrRefusedChild) {
      for (var item in _questions) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().toLowerCase();
          if (t.contains('agent') && t.contains('sign')) {
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<void> _save(bool isFinal) async {
    if (isFinal) {
      for (var q in _questions) {
        if (_isQuestionVisible(q) &&
            q['required'] == true &&
            !_isQuestionDependent(q) &&
            q['type'] != 'media') {
          if (_answers[q['id']] == null ||
              _answers[q['id']].toString().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Please answer all required questions before submitting.'),
                backgroundColor: Colors.orange));
            return;
          }
        }
      }
    }

    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'state': _userProfile?['assignedState'],
        'lga': _userProfile?['assignedLga'],
        'ward': _userProfile?['assignedWard'],
        'pollingUnit': _userProfile?['assignedPollingUnit'],
        'answers': _answers,
        'status': isFinal ? 'submitted' : 'draft',
        'timestamp': FieldValue.serverTimestamp(),
      };

      final pu = _userProfile?['assignedPollingUnit'] ?? 'unknown_pu';
      // Use the ID format confirmed in Firestore: observerId_electionId
      final docId = '${user?.uid}_${widget.electionId}';

      await FirebaseFirestore.instance
          .collection('observer_checklists')
          .doc(docId)
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      final ipAddress = await _getPublicIP();

      // Audit Log (swallow permission errors gracefully so it does not block the submission)
      try {
        await FirebaseFirestore.instance.collection('audit_logs').add({
          'userId': user?.uid,
          'userEmail': user?.email,
          'action': isFinal ? 'CHECKLIST_SUBMIT' : 'CHECKLIST_SAVE_DRAFT',
          'resource': 'checklist',
          'ipAddress': ipAddress,
          'details': {
            'observerName': _userProfile?['fullName'] ??
                _userProfile?['name'] ??
                _userProfile?['displayName'] ??
                'Observer',
            'phone':
                _userProfile?['phone'] ?? _userProfile?['phoneNumber'] ?? 'N/A',
            'electionId': widget.electionId,
            'state': _userProfile?['assignedState'] ?? 'N/A',
            'lga': _userProfile?['assignedLga'] ?? 'N/A',
            'ward': _userProfile?['assignedWard'] ?? 'N/A',
            'pollingUnit': pu,
            'answeredCount': _answers.length,
          },
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      } catch (auditError) {
        debugPrint(
            'Graceful: Failed to write checklist audit log to Firestore (rules constraint): $auditError');
      }

      // Also ALWAYS store/update in local Drift database!
      try {
        final dbInstance = context.read<db.AppDatabase>();
        final localChecklists = await dbInstance.getAllChecklists();
        final matchIndex = localChecklists.indexWhere((c) => c.title == docId);

        if (matchIndex != -1) {
          final existing = localChecklists[matchIndex];
          await dbInstance.updateChecklistItem(
            existing.copyWith(
              category: jsonEncode(_answers),
              isCompleted: isFinal,
              isSynced: true,
              updatedAt: DateTime.now(),
            ),
          );
        } else {
          final checklistCompanion = db.ChecklistsCompanion(
            title: drift.Value(docId),
            category: drift.Value(jsonEncode(_answers)),
            isCompleted: drift.Value(isFinal),
            isSynced: const drift.Value(true),
          );
          await dbInstance.insertChecklist(checklistCompanion);
        }
      } catch (localDbError) {
        debugPrint('Local DB Sync/Save failed: $localDbError');
      }

      if (mounted) {
        setState(() {
          _isFinalized = isFinal;
          _hasSavedDraft = !isFinal;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFinal
              ? 'Checklist Finalized Successfully!'
              : 'Progress Saved as Draft'),
          backgroundColor: const Color(0xFF065F46),
        ));
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socket') ||
          errorStr.contains('network') ||
          errorStr.contains('unavailable') ||
          errorStr.contains('host-lookup') ||
          errorStr.contains('connection') ||
          errorStr.contains('timeout');

      if (isNetworkError) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final docId = '${user?.uid}_${widget.electionId}';

          final dbInstance = context.read<db.AppDatabase>();
          final localChecklists = await dbInstance.getAllChecklists();
          final matchIndex =
              localChecklists.indexWhere((c) => c.title == docId);

          if (matchIndex != -1) {
            final existing = localChecklists[matchIndex];
            await dbInstance.updateChecklistItem(
              existing.copyWith(
                category: jsonEncode(_answers),
                isCompleted: isFinal,
                isSynced: false,
                updatedAt: DateTime.now(),
              ),
            );
          } else {
            final checklistCompanion = db.ChecklistsCompanion(
              title: drift.Value(docId),
              category: drift.Value(jsonEncode(_answers)),
              isCompleted: drift.Value(isFinal),
              isSynced: const drift.Value(false),
            );
            await dbInstance.insertChecklist(checklistCompanion);
          }

          if (mounted) {
            setState(() {
              _isFinalized = isFinal;
              _hasSavedDraft = !isFinal;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No internet connection. Checklist saved locally to offline drafts!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        } catch (localDbError) {
          debugPrint('Local DB Save failed: $localDbError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Checklist save failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _discardDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    final docId = '${user?.uid}_${widget.electionId}';

    await FirebaseFirestore.instance
        .collection('observer_checklists')
        .doc(docId)
        .delete();
    setState(() {
      _answers.clear();
      _controllers.values.forEach((c) => c.clear());
      _hasSavedDraft = false;
      _loadData(); // Reload to re-apply auto-fill
    });
  }

  @override
  void dispose() {
    _templateSubscription?.cancel();
    _templateDocSubscription?.cancel();
    _networkCheckTimer?.cancel();
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _startNetworkTimer() {
    _checkNetwork();
    _networkCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (_isOffline != !isConnected) {
        if (mounted) {
          setState(() {
            _isOffline = !isConnected;
          });
        }
      }
    } catch (_) {
      if (!_isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    }
  }

  Widget _buildConnectionStatusBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: textCol, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF065F46)));

    final grouped = <String, List<dynamic>>{};
    for (var q in _questions) {
      final section = q['section'] ?? 'General';
      if (!grouped.containsKey(section)) grouped[section] = [];
      grouped[section]!.add(q);
    }

    final showBottomActions = MediaQuery.of(context).viewInsets.bottom == 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          if (_isFinalized)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CHECKLIST FINALIZED',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(
                            'All responses are now locked for synchronization.',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _buildProgressHUD(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: grouped.entries
                  .map((entry) => _buildSection(entry.key, entry.value))
                  .toList(),
            ),
          ),
          if (showBottomActions) _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildProgressHUD() {
    final progress = _completionProgress;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    strokeWidth: 6,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMPLETION TRACKER',
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF64748B),
                              letterSpacing: 1)),
                      Text('${(progress * 100).toInt()}% Questions Answered',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _isOffline
              ? _buildConnectionStatusBadge('OFFLINE CONNECTION',
                  const Color(0xFFFEF2F2), const Color(0xFFEF4444))
              : _buildConnectionStatusBadge('LIVE CONNECTION',
                  const Color(0xFFECFDF5), const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> questions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(title.toUpperCase(),
            style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1)),
        const SizedBox(height: 16),
        ...questions.map((q) => _isQuestionVisible(q)
            ? _buildQuestionCard(q)
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final id = q['id'];
    final isAnswered =
        _answers[id] != null && _answers[id].toString().isNotEmpty;
    final text = (q['text'] ?? '').toString();
    final type = q['type'] ?? 'text';
    final isRequired = q['required'] == true && !_isQuestionDependent(q);
    // Derive category label from question type (mirrors web UI)
    String categoryLabel;
    switch (type) {
      case 'yes_no':
        categoryLabel = 'DIRECT OBSERVATION';
        break;
      case 'number':
        categoryLabel = 'STANDARD METRIC';
        break;
      case 'media':
        categoryLabel = 'MEDIA EVIDENCE';
        break;
      case 'time':
        categoryLabel = 'TIME RECORD';
        break;
      default:
        categoryLabel = 'DIRECT OBSERVATION';
    }

    // Strict identification field check
    final textLower = text.toLowerCase();
    final isIdentificationField = (type == 'text' || type == 'number') &&
        (textLower == 'state' ||
            textLower == 'lga' ||
            textLower == 'local government' ||
            textLower == 'local government area' ||
            textLower == 'ward' ||
            textLower == 'polling unit' ||
            textLower == 'polling unit name' ||
            textLower == 'polling unit code' ||
            textLower.contains('your lga') ||
            textLower.contains('your ward') ||
            textLower.contains('your state') ||
            textLower.contains('your polling unit') ||
            textLower.contains('your name') ||
            textLower.contains('observer name') ||
            textLower.contains('full name') ||
            textLower.contains('phone number') ||
            textLower.contains('phone'));

    final isEditable = _editableFields.contains(id) || !isIdentificationField;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isAnswered
                ? const Color(0xFF10B981).withOpacity(0.2)
                : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(text,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B)))),
              if (isIdentificationField)
                IconButton(
                  icon: Icon(
                      _editableFields.contains(id)
                          ? LucideIcons.check
                          : LucideIcons.pencil,
                      size: 14,
                      color: const Color(0xFF64748B)),
                  onPressed: _isFinalized
                      ? null
                      : () => setState(() {
                            if (_editableFields.contains(id))
                              _editableFields.remove(id);
                            else
                              _editableFields.add(id);
                          }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Green + icon matching web design
              const Icon(Icons.add, size: 10, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                categoryLabel,
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              // Pipe separator
              Container(width: 1, height: 10, color: const Color(0xFFCBD5E1)),
              const SizedBox(width: 8),
              Text(
                isRequired ? 'REQUIRED' : 'OPTIONAL',
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isRequired
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput(q, isEditable && !_isFinalized),
        ],
      ),
    );
  }

  Widget _buildInput(Map<String, dynamic> q, bool enabled) {
    final type = q['type'] ?? 'text';
    final id = q['id'];

    if (type == 'yes_no') {
      return Row(
        children: [
          _buildChoiceChip(id, 'YES', 'yes', enabled),
          const SizedBox(width: 12),
          _buildChoiceChip(id, 'NO', 'no', enabled),
        ],
      );
    }

    if (type == 'media') {
      final url = _answers[id]?.toString() ?? '';
      final hasUrl = url.isNotEmpty;

      // Determine media type
      String mediaType = 'photo';
      if (hasUrl) {
        final lowerUrl = url.toLowerCase();
        if (lowerUrl.contains('.mp4') ||
            lowerUrl.contains('.mov') ||
            lowerUrl.contains('.avi'))
          mediaType = 'video';
        else if (lowerUrl.contains('.mp3') ||
            lowerUrl.contains('.wav') ||
            lowerUrl.contains('.m4a') ||
            lowerUrl.contains('.aac')) mediaType = 'audio';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUrl)
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: mediaType == 'video'
                    ? VideoPlayerWidget(url: url)
                    : mediaType == 'audio'
                        ? AudioPlayerWidget(url: url)
                        : GestureDetector(
                            onTap: () => _showFullScreenImage(url),
                            child: (!url.startsWith('http://') &&
                                    !url.startsWith('https://'))
                                ? Image.file(File(url), fit: BoxFit.cover)
                                : CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) => const Center(
                                        child: CircularProgressIndicator()),
                                    errorWidget: (c, u, e) => const Center(
                                        child: Icon(LucideIcons.image,
                                            color: Colors.grey)),
                                  ),
                          ),
              ),
            ),
          InkWell(
            onTap: !enabled ? null : () => _showChecklistSourcePicker(id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(hasUrl ? LucideIcons.refreshCw : LucideIcons.camera,
                        size: 16, color: const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(hasUrl ? 'REPLACE MEDIA' : 'ADD PHOTO/VIDEO',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isDateTimeField = type == 'time';
    final isTimeOnlyField = !isDateTimeField &&
        (q['text'] ?? '').toString().toLowerCase().contains('time');
    final isTimeField = isDateTimeField || isTimeOnlyField;

    if (isTimeField) {
      if (!_controllers.containsKey(id)) {
        _controllers[id] =
            TextEditingController(text: _answers[id]?.toString());
      }

      return InkWell(
        onTap: !enabled
            ? null
            : () async {
                if (isDateTimeField) {
                  DateTime initialDateTime = DateTime.now();
                  if (_controllers[id]!.text.isNotEmpty) {
                    final parsed = DateTime.tryParse(_controllers[id]!.text);
                    if (parsed != null) initialDateTime = parsed;
                  }

                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: initialDateTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (BuildContext context, Widget? child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF065F46),
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Color(0xFF0F172A),
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (selectedDate != null && mounted) {
                    final selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(initialDateTime),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF065F46),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                            dialogBackgroundColor: Colors.white,
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (selectedTime != null && mounted) {
                      final dateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      final formattedDateTime = dateTime.toIso8601String();
                      setState(() {
                        _answers[id] = formattedDateTime;
                        _controllers[id]!.text = formattedDateTime;
                      });
                    }
                  }
                } else {
                  TimeOfDay initialTime = TimeOfDay.now();
                  if (_controllers[id]!.text.isNotEmpty) {
                    try {
                      final parts = _controllers[id]!.text.split(':');
                      if (parts.length >= 2) {
                        final hour = int.parse(parts[0].trim());
                        final minute = int.parse(
                            parts[1].replaceAll(RegExp(r'[^0-9]'), '').trim());
                        initialTime = TimeOfDay(hour: hour, minute: minute);
                      }
                    } catch (_) {}
                  }

                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                    builder: (BuildContext context, Widget? child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF065F46),
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Color(0xFF0F172A),
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (selectedTime != null) {
                    final formattedTime =
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                    setState(() {
                      _answers[id] = formattedTime;
                      _controllers[id]!.text = formattedTime;
                    });
                  }
                }
              },
        child: IgnorePointer(
          child: TextField(
            controller: _controllers[id],
            style: GoogleFonts.outfit(
                fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: isDateTimeField
                  ? 'Select date and time...'
                  : 'Select time...',
              suffixIcon: Icon(
                isDateTimeField ? LucideIcons.calendarClock : LucideIcons.clock,
                color: const Color(0xFF64748B),
                size: 18,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
      );
    }

    if (type == 'number') {
      if (!_controllers.containsKey(id)) {
        _controllers[id] =
            TextEditingController(text: _answers[id]?.toString());
      }

      return TextField(
        enabled: enabled,
        controller: _controllers[id],
        keyboardType: TextInputType.number,
        style: GoogleFonts.outfit(
            fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Enter number...',
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
        onChanged: (v) => _answers[id] = v,
      );
    }

    if (!_controllers.containsKey(id)) {
      _controllers[id] = TextEditingController(text: _answers[id]?.toString());
    }

    return TextField(
      enabled: enabled,
      controller: _controllers[id],
      style: GoogleFonts.outfit(
          fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Enter response...',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      onChanged: (v) => _answers[id] = v,
    );
  }

  Widget _buildChoiceChip(String id, String label, String value, bool enabled) {
    final selected = _answers[id] == value;
    final isNo = value.toLowerCase() == 'no';
    final activeColor =
        isNo ? const Color(0xFFEF4444) : const Color(0xFF065F46);

    return Expanded(
      child: InkWell(
        onTap: !enabled ? null : () => setState(() => _answers[id] = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? activeColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : const Color(0xFF64748B))),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_isFinalized) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5))
      ]),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _submitting ? null : () => _save(false),
                      child: Text('SAVE PROGRESS',
                          style: GoogleFonts.outfit(
                              fontSize: 12, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 16),
              Expanded(
                  child: ElevatedButton(
                      onPressed: _submitting ? null : () => _save(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065F46)),
                      child: Text('FINAL SUBMIT',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)))),
            ],
          ),
          if (_hasSavedDraft)
            TextButton(
              onPressed: _submitting ? null : _discardDraft,
              child: Text('DISCARD DRAFT',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: (!url.startsWith('http://') &&
                        !url.startsWith('https://'))
                    ? Image.file(File(url), fit: BoxFit.contain)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (c, u) => const CircularProgressIndicator(
                            color: Colors.white),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChecklistSourcePicker(String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('ATTACH EVIDENCE',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Select evidence from your device',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildChecklistPickerOption(
              icon: LucideIcons.camera,
              title: 'TAKE SNAPSHOT',
              subtitle: 'Capture evidence now',
              onTap: () {
                Navigator.pop(ctx);
                _handleChecklistMedia(id, ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildChecklistPickerOption(
              icon: LucideIcons.image,
              title: 'PICK FROM GALLERY',
              subtitle: 'Upload existing file',
              onTap: () {
                Navigator.pop(ctx);
                _handleChecklistMedia(id, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistPickerOption(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A))),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChecklistMedia(String id, ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 70);
    if (img != null) {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Uploading evidence...'),
          duration: Duration(seconds: 2)));

      final user = FirebaseAuth.instance.currentUser;
      final ref = FirebaseStorage.instance.ref().child(
          'checklist_media/${user?.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(img.path));
      final url = await ref.getDownloadURL();
      setState(() => _answers[id] = url);
    }
  }
}

class _IncidentsTab extends StatefulWidget {
  final String electionId;
  final Future<void> Function()? onImportFromRelated;
  const _IncidentsTab({required this.electionId, this.onImportFromRelated});

  @override
  State<_IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends State<_IncidentsTab> {
  final _descriptionController = TextEditingController();
  String? _selectedType;
  final List<Map<String, dynamic>> _media = [];
  bool _submitting = false;
  bool _savingDraft = false;
  double _uploadProgress = 0;
  Position? _currentPosition;
  Map<String, dynamic>? _userProfile;
  final String _deviceId =
      'OBS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  Timer? _clockTimer;
  bool _isOffline = false;
  Timer? _networkCheckTimer;
  bool _hasPromptedForRelatedImport = false;

  final List<Map<String, String>> _types = [
    {'id': 'ballot_snatching', 'label': 'Ballot Snatching'},
    {'id': 'violence', 'label': 'Violence or Threat'},
    {'id': 'underage_voting', 'label': 'Underage Voting'},
    {'id': 'vote_buying', 'label': 'Vote Buying'},
    {'id': 'equipment_failure', 'label': 'Equipment Failure'},
    {'id': 'no_materials', 'label': 'Insufficient Materials'},
    {'id': 'late_start', 'label': 'Late Commencement'},
    {'id': 'other', 'label': 'Other Incident'},
  ];

  @override
  void initState() {
    super.initState();
    _initData();
    _startNetworkTimer();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _networkCheckTimer?.cancel();
    _clockTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startNetworkTimer() {
    _checkNetwork();
    _networkCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (_isOffline != !isConnected) {
        if (mounted) {
          setState(() {
            _isOffline = !isConnected;
          });
        }
      }
    } catch (_) {
      if (!_isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    }
  }

  Future<void> _initData() async {
    // Force clear state to prevent cross-election data bleed
    if (mounted) {
      setState(() {
        _descriptionController.clear();
        _selectedType = null;
        _media.clear();
        _savingDraft = false;
        _submitting = false;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      _userProfile = profile.data();
      _currentPosition = await _determinePosition();
      if (mounted) setState(() {});

      // Load current draft if exists
      if (user != null) {
        final draftDoc = await FirebaseFirestore.instance
            .collection('incident_reports')
            .doc('${widget.electionId}_${user.uid}_draft')
            .get();
        if (draftDoc.exists && mounted) {
          final data = draftDoc.data();
          if (data != null) {
            setState(() {
              _selectedType = data['incidentType'];
              _descriptionController.text = data['description'] ?? '';
              final mediaItems = data['mediaItems'] as List<dynamic>? ?? [];
              _media.clear();
              for (final item in mediaItems) {
                if (item is Map) {
                  _media.add({
                    'type': item['type'],
                    'url': item['url'],
                  });
                }
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Location/Draft load error: $e');
    }

    // After loading, check if we should import from related elections
    if (!_hasPromptedForRelatedImport &&
        _selectedType == null &&
        _descriptionController.text.isEmpty &&
        _media.isEmpty &&
        widget.onImportFromRelated != null) {
      _hasPromptedForRelatedImport = true;
      await widget.onImportFromRelated!();

      // Reload draft after potential import
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final draftDoc = await FirebaseFirestore.instance
              .collection('incident_reports')
              .doc('${widget.electionId}_${user.uid}_draft')
              .get();
          if (draftDoc.exists && mounted) {
            final data = draftDoc.data();
            if (data != null) {
              setState(() {
                _selectedType = data['incidentType'];
                _descriptionController.text = data['description'] ?? '';
                final mediaItems = data['mediaItems'] as List<dynamic>? ?? [];
                _media.clear();
                for (final item in mediaItems) {
                  if (item is Map) {
                    _media.add({
                      'type': item['type'],
                      'url': item['url'],
                    });
                  }
                }
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error reloading incident draft: $e');
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Location permissions are denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _pickMedia(String type,
      {ImageSource source = ImageSource.camera}) async {
    if (type == 'audio') {
      // For audio, we use FilePicker.
      // If source is 'camera' (Live), we try to use the system recorder if available via FilePicker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _media
            .add({'type': type, 'file': File(result.files.single.path!)}));
      }
      return;
    }

    final picker = ImagePicker();
    XFile? file;
    if (type == 'photo') {
      file = await picker.pickImage(source: source, imageQuality: 70);
    } else if (type == 'video') {
      file = await picker.pickVideo(source: source);
    }

    if (file != null) {
      setState(() => _media.add({'type': type, 'file': File(file!.path)}));
    }
  }

  void _showSourcePicker(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('SELECT SOURCE',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Choose how you want to attach ${type.toUpperCase()}',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildPickerOption(
              icon: type == 'audio' ? LucideIcons.mic : LucideIcons.camera,
              title: type == 'audio'
                  ? 'RECORD LIVE'
                  : 'LIVE ${type == 'photo' ? 'SNAPSHOT' : 'RECORDING'}',
              subtitle: type == 'audio'
                  ? 'Capture audio now'
                  : 'Use your device camera',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(type, source: ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildPickerOption(
              icon: type == 'audio' ? LucideIcons.mic : LucideIcons.image,
              title: type == 'audio' ? 'UPLOAD FILE' : 'UPLOAD FROM GALLERY',
              subtitle: type == 'audio'
                  ? 'Select from storage'
                  : 'Pick from your photo library',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(type, source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A))),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedType == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a type and provide a description.'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _submitting = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final List<Map<String, String>> mediaItems = [];

      for (int i = 0; i < _media.length; i++) {
        final item = _media[i];
        final type = item['type'] as String;

        if (item['url'] != null) {
          mediaItems.add({'url': item['url'] as String, 'type': type});
          continue;
        }

        final file = item['file'] as File;
        final ref = FirebaseStorage.instance.ref().child(
            'incidents/${user?.uid}/${DateTime.now().millisecondsSinceEpoch}_$i');
        final uploadTask = ref.putFile(file);

        uploadTask.snapshotEvents.listen((event) {
          final p = (event.bytesTransferred / event.totalBytes) / _media.length;
          setState(() => _uploadProgress = (i / _media.length) + p);
        });

        await uploadTask.timeout(const Duration(seconds: 15));
        final url = await ref.getDownloadURL();
        mediaItems.add({'url': url, 'type': type});
      }

      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'submittedBy': user?.uid,
        'incidentType': _selectedType,
        'description': _descriptionController.text,
        'mediaItems': mediaItems,
        'mediaUrls': mediaItems
            .map((e) => e['url'])
            .toList(), // for backward compatibility
        'state': _userProfile?['assignedState'],
        'lga': _userProfile?['assignedLga'],
        'ward': _userProfile?['assignedWard'],
        'pollingUnit': _userProfile?['assignedPollingUnit'],
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'deviceId': _deviceId,
        'status': 'reported',
        'isSynced': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('incident_reports')
          .add(payload)
          .timeout(const Duration(seconds: 10));

      final ipAddress = await _getPublicIP();

      // Audit Log for Incident Submission
      try {
        await FirebaseFirestore.instance.collection('audit_logs').add({
          'userId': user?.uid,
          'userEmail': user?.email,
          'action': 'INCIDENT_SUBMIT',
          'resource': 'incident',
          'ipAddress': ipAddress,
          'details': {
            'observerName': _userProfile?['fullName'] ??
                _userProfile?['name'] ??
                _userProfile?['displayName'] ??
                'Observer',
            'phone':
                _userProfile?['phone'] ?? _userProfile?['phoneNumber'] ?? 'N/A',
            'electionId': widget.electionId,
            'incidentType': _selectedType ?? 'other',
            'state': _userProfile?['assignedState'] ?? 'N/A',
            'lga': _userProfile?['assignedLga'] ?? 'N/A',
            'ward': _userProfile?['assignedWard'] ?? 'N/A',
            'pollingUnit': _userProfile?['assignedPollingUnit'] ?? 'N/A',
          },
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      } catch (auditError) {
        debugPrint('Graceful: Failed to write incident audit log: $auditError');
      }

      // Clean up draft if it exists
      await FirebaseFirestore.instance
          .collection('incident_reports')
          .doc('${widget.electionId}_${user?.uid}_draft')
          .delete();

      if (mounted) {
        _descriptionController.clear();
        setState(() {
          _selectedType = null;
          _media.clear();
          _uploadProgress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Incident report submitted successfully!'),
            backgroundColor: Color(0xFF10B981)));
        DefaultTabController.maybeOf(context)?.animateTo(0);
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socket') ||
          errorStr.contains('network') ||
          errorStr.contains('unavailable') ||
          errorStr.contains('host-lookup') ||
          errorStr.contains('connection') ||
          errorStr.contains('timeout');

      if (isNetworkError) {
        try {
          final incidentCompanion = db.IncidentsCompanion(
            category: drift.Value(_selectedType ?? 'other'),
            severity: drift.Value('reported_${widget.electionId}'),
            description: drift.Value(_descriptionController.text),
            latitude: drift.Value(_currentPosition?.latitude),
            longitude: drift.Value(_currentPosition?.longitude),
            mediaPathsJson: drift.Value(jsonEncode(
                _media.map((e) => e['file'] != null ? (e['file'] as File).path : e['url'] ?? '').toList())),
            isSynced: const drift.Value(false),
          );

          await context
              .read<db.AppDatabase>()
              .insertIncident(incidentCompanion);

          if (mounted) {
            _descriptionController.clear();
            setState(() {
              _selectedType = null;
              _media.clear();
              _uploadProgress = 1.0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No internet connection. Incident saved locally to offline reports!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        } catch (localDbError) {
          debugPrint('Local DB Save failed: $localDbError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Incident submission failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleSaveDraft() async {
    setState(() => _savingDraft = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'incidentType': _selectedType,
        'description': _descriptionController.text,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('incident_reports')
          .doc('${widget.electionId}_${user?.uid}_draft')
          .set(payload, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: Color(0xFF065F46)));
      }
    } catch (e) {
      debugPrint('Save draft error: $e');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildHeader(),
        const SizedBox(height: 32),
        _buildIssueDetailsCard(),
        const SizedBox(height: 24),
        _buildEvidenceCard(),
        const SizedBox(height: 24),
        _buildReportDetailsCard(),
        const SizedBox(height: 24),
        _buildGuidelinesCard(),
        const SizedBox(height: 32),
        _buildSubmitActions(),
        const SizedBox(height: 48),
        _buildRecentSubmissions(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report an Issue',
                  style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -1)),
              const SizedBox(height: 4),
              Text('Reporting for 2026 Presidential Election',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _isOffline
            ? _buildConnectionStatusBadge('OFFLINE CONNECTION',
                const Color(0xFFFEF2F2), const Color(0xFFEF4444))
            : _buildConnectionStatusBadge('LIVE CONNECTION',
                const Color(0xFFECFDF5), const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildConnectionStatusBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: textCol, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildIssueDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
              LucideIcons.activity, 'ISSUE DETAILS', 'INCIDENT INFORMATION'),
          const SizedBox(height: 32),
          Text('TYPE OF ISSUE',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedType,
            dropdownColor: Colors.white,
            icon: const Icon(LucideIcons.chevronDown,
                size: 16, color: Color(0xFF64748B)),
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
            decoration: _inputDecoration('Select an option'),
            items: _types
                .map((t) => DropdownMenuItem(
                    value: t['id'],
                    child: Text(t['label']!,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black))))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: 24),
          Text('POLLING UNIT',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                    child: Text(
                        _userProfile?['assignedPollingUnit'] ??
                            'LOCATING POLLING UNIT...',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A)))),
                const Icon(LucideIcons.mapPin,
                    size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('DESCRIBE WHAT HAPPENED',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 6,
            style: GoogleFonts.outfit(
                fontSize: 14, height: 1.5, color: Colors.black),
            decoration: _inputDecoration(
                'Provide a detailed description of the incident. Include what happened, who was involved, and when it occurred...'),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
              LucideIcons.camera, 'PHOTOS & VIDEO', 'OPTIONAL EVIDENCE'),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildEvidenceTile('TAKE PHOTO', 'PHOTOS/STILLS',
                  LucideIcons.camera, () => _showSourcePicker('photo')),
              const SizedBox(width: 12),
              _buildEvidenceTile('RECORD VIDEO', 'HD VIDEO', LucideIcons.video,
                  () => _showSourcePicker('video')),
            ],
          ),
          const SizedBox(height: 12),
          _buildEvidenceTile('RECORD AUDIO', 'VOICE/SOUND', LucideIcons.mic,
              () => _showSourcePicker('audio'),
              isFullWidth: true),
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _media.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 100,
                      height: 110,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          image: _media[i]['type'] == 'photo'
                              ? DecorationImage(
                                  image: _media[i]['file'] != null
                                      ? FileImage(_media[i]['file'])
                                      : NetworkImage(_media[i]['url'] ?? '') as ImageProvider,
                                  fit: BoxFit.cover)
                              : null),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_media[i]['type'] != 'photo') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: Icon(
                                  _media[i]['type'] == 'video'
                                      ? LucideIcons.video
                                      : LucideIcons.mic,
                                  color: const Color(0xFF10B981),
                                  size: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _media[i]['type'].toString().toUpperCase(),
                              style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 1),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _media.removeAt(i)),
                        child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 4)
                                ]),
                            child: const Icon(LucideIcons.x,
                                size: 14, color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceTile(
      String title, String sub, IconData icon, VoidCallback onTap,
      {bool isFullWidth = false}) {
    final content = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFFF1F5F9), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0F172A), size: 28),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );

    return isFullWidth ? content : Expanded(child: content);
  }

  Widget _buildReportDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                      color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('REPORT DETAILS',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 32),
          _buildDetailRow('TIME', DateFormat('HH:mm:ss').format(DateTime.now()),
              LucideIcons.clock),
          _buildDetailRow(
              'LATITUDE',
              '${_currentPosition?.latitude.toStringAsFixed(4) ?? '0.0000'}° N',
              LucideIcons.mapPin),
          _buildDetailRow(
              'LONGITUDE',
              '${_currentPosition?.longitude.toStringAsFixed(4) ?? '0.0000'}° E',
              LucideIcons.mapPin),
          _buildDetailRow('DEVICE ID', _deviceId, LucideIcons.smartphone),
          const SizedBox(height: 24),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24)),
            child: const Center(
                child:
                    Icon(LucideIcons.map, size: 40, color: Color(0xFFCBD5E1))),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {Color? labelColor, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: labelColor ?? const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: valueColor ?? const Color(0xFF0F172A))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.shieldCheck, 'GUIDELINES', ''),
          const SizedBox(height: 24),
          _buildGuidelineItem('ONLY REPORT WHAT YOU PERSONALLY SAW.'),
          _buildGuidelineItem('MAKE SURE YOUR GPS IS TURNED ON.'),
          _buildGuidelineItem('YOUR SAFETY IS MORE IMPORTANT THAN REPORTING.'),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(LucideIcons.check,
                  size: 10, color: Color(0xFF10B981))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF64748B),
                      height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildSubmitActions() {
    return Column(
      children: [
        if (_submitting) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('UPLOADING REPORT...',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 1)),
                    Text('${(_uploadProgress * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: const Color(0xFFECFDF5),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_submitting || _savingDraft) ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.send, size: 16, color: Colors.white),
                const SizedBox(width: 12),
                Text('SUBMIT REPORT',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (_submitting || _savingDraft) ? null : _handleSaveDraft,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
              side: const BorderSide(color: Color(0xFFF1F5F9)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.save,
                    size: 16, color: Color(0xFF065F46)),
                const SizedBox(width: 12),
                Text('SAVE DRAFT',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF065F46),
                        letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSubmissions() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(LucideIcons.fileText, 'RECENT SUBMISSIONS',
            'HISTORY FOR THIS ELECTION'),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('incident_reports')
              .where('electionId', isEqualTo: widget.electionId)
              .where('observerId', isEqualTo: user?.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty)
              return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24)),
                  child: Center(
                      child: Text('No reports submitted yet',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: const Color(0xFF64748B)))));

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final date = d['createdAt'] != null
                    ? (d['createdAt'] as Timestamp).toDate()
                    : (d['timestamp'] != null
                        ? (d['timestamp'] as Timestamp).toDate()
                        : DateTime.now());
                return GestureDetector(
                  onTap: () => _showIncidentDetails(docs[i].id, d),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9))),
                    child: Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(LucideIcons.triangleAlert,
                                size: 16, color: Colors.orange)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                      d['incidentType']
                                              ?.toString()
                                              .replaceAll('_', ' ')
                                              .toUpperCase() ??
                                          'INCIDENT',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A))),
                                  const Spacer(),
                                  _buildStatusBadge(d['status'] ?? 'reported'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  DateFormat('dd/MM/yyyy, HH:mm:ss')
                                      .format(date),
                                  style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(LucideIcons.chevronRight,
                            size: 16, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDraft = status.toLowerCase() == 'draft';
    final color = isDraft ? Colors.orange : const Color(0xFF10B981);
    final bgColor = isDraft ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5),
      ),
    );
  }

  void _showIncidentDetails(String docId, Map<String, dynamic> data) {
    final date = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : (data['timestamp'] != null
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now());
    final List<dynamic> mediaItems = data['mediaItems'] ?? [];
    final List<String> mediaUrls = List<String>.from(data['mediaUrls'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                child: Row(
                  children: [
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.arrowLeft)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text('INCIDENT REPORT',
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black))),
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (confirmCtx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            title: Text('Delete Report',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            content: Text(
                                'Are you sure you want to delete this incident report? This action cannot be undone.',
                                style: GoogleFonts.outfit(color: Colors.black)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(confirmCtx),
                                child: Text('CANCEL',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(confirmCtx);
                                  await FirebaseFirestore.instance
                                      .collection('incident_reports')
                                      .doc(docId)
                                      .delete();
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Report deleted'),
                                            backgroundColor: Colors.red));
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                child: Text('DELETE',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.trash2, color: Colors.red),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 300,
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24)),
                        child: (mediaItems.isEmpty && mediaUrls.isEmpty)
                            ? const Center(
                                child: Icon(LucideIcons.image,
                                    color: Colors.white24, size: 48))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: mediaItems.isNotEmpty
                                    ? mediaItems.length
                                    : mediaUrls.length,
                                itemBuilder: (c, i) {
                                  final url = mediaItems.isNotEmpty
                                      ? mediaItems[i]['url']
                                      : mediaUrls[i];
                                  String type = mediaItems.isNotEmpty
                                      ? mediaItems[i]['type']
                                      : 'photo';

                                  // Enhanced type detection for backward compatibility with older reports
                                  if (type == 'photo') {
                                    final lowerUrl = url.toLowerCase();
                                    if (lowerUrl.contains('.mp4') ||
                                        lowerUrl.contains('.mov') ||
                                        lowerUrl.contains('.avi')) {
                                      type = 'video';
                                    } else if (lowerUrl.contains('.mp3') ||
                                        lowerUrl.contains('.wav') ||
                                        lowerUrl.contains('.m4a') ||
                                        lowerUrl.contains('.aac')) {
                                      type = 'audio';
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.85,
                                      decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: type == 'video'
                                            ? VideoPlayerWidget(url: url)
                                            : type == 'audio'
                                                ? AudioPlayerWidget(url: url)
                                                : (!url.startsWith('http://') &&
                                                        !url.startsWith(
                                                            'https://'))
                                                    ? Image.file(File(url),
                                                        fit: BoxFit.cover)
                                                    : CachedNetworkImage(
                                                        imageUrl: url,
                                                        fit: BoxFit.cover,
                                                        placeholder: (context,
                                                                url) =>
                                                            const Center(
                                                                child: CircularProgressIndicator(
                                                                    color: Color(
                                                                        0xFF065F46))),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            const Center(
                                                                child: Icon(
                                                                    LucideIcons
                                                                        .image,
                                                                    color: Colors
                                                                        .grey)),
                                                      ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                data['incidentType']
                                        ?.toString()
                                        .replaceAll('_', ' ')
                                        .toUpperCase() ??
                                    'INCIDENT',
                                style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black)),
                            const SizedBox(height: 8),
                            Text(
                                DateFormat('EEEE, MMMM d, yyyy - HH:mm:ss')
                                    .format(date),
                                style: GoogleFonts.outfit(
                                    fontSize: 14, color: Colors.black)),
                            const SizedBox(height: 32),
                            Text('DESCRIPTION',
                                style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 1)),
                            const SizedBox(height: 12),
                            Text(data['description'] ?? '',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Colors.black)),
                            const SizedBox(height: 32),
                            Text('LOCATION DETAILS',
                                style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 1)),
                            const SizedBox(height: 12),
                            _buildDetailRow('POLLING UNIT',
                                data['pollingUnit'] ?? '', LucideIcons.mapPin,
                                labelColor: Colors.black,
                                valueColor: Colors.black),
                            _buildDetailRow(
                                'WARD', data['ward'] ?? '', LucideIcons.map,
                                labelColor: Colors.black,
                                valueColor: Colors.black),
                            _buildDetailRow(
                                'LGA / STATE',
                                '${data['lga']} / ${data['state']}',
                                LucideIcons.map,
                                labelColor: Colors.black,
                                valueColor: Colors.black),
                            _buildDetailRow(
                                'COORDINATES',
                                '${data['latitude']}°, ${data['longitude']}°',
                                LucideIcons.navigation,
                                labelColor: Colors.black,
                                valueColor: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: Color(0xFFECFDF5), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis),
              if (sub.isNotEmpty)
                Text(sub,
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFCBD5E1)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(20),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textCol,
              letterSpacing: 0.5)),
    );
  }
}

class _EC8AResultsTab extends StatefulWidget {
  final String electionId;
  const _EC8AResultsTab({required this.electionId});

  @override
  State<_EC8AResultsTab> createState() => _EC8AResultsTabState();
}

class _EC8AResultsTabState extends State<_EC8AResultsTab> {
  final Map<String, int> _partyVotes = {};
  final Map<String, int> _stats = {
    'votersInRegister': 0,
    'accreditedVoters': 0,
    'ballotsIssued': 0,
    'unusedBallots': 0,
    'spoiledBallots': 0,
    'rejectedBallots': 0,
  };

  List<Map<String, dynamic>> _parties = [
    {
      'id': 'apc',
      'name': 'All Progressives Congress',
      'abbreviation': 'APC',
      'logoUrl': null
    },
    {
      'id': 'pdp',
      'name': 'Peoples Democratic Party',
      'abbreviation': 'PDP',
      'logoUrl': null
    },
    {'id': 'lp', 'name': 'Labour Party', 'abbreviation': 'LP', 'logoUrl': null},
    {
      'id': 'nnpp',
      'name': 'New Nigeria Peoples Party',
      'abbreviation': 'NNPP',
      'logoUrl': null
    },
    {
      'id': 'apga',
      'name': 'All Progressives Grand Alliance',
      'abbreviation': 'APGA',
      'logoUrl': null
    },
  ];
  bool _loading = true;
  bool _scanning = false;
  bool _submitting = false;
  bool _isFinal = false;
  Map<String, dynamic>? _userProfile;
  List<dynamic> _puSubmissions = [];
  String? _puResultStatus;
  File? _evidenceFile;
  String? _evidenceUrl;
  bool _isPrecisionView = true;
  DateTime? _lastScanTime;
  int? _expectedYear;
  String? _expectedType;
  final Map<String, TextEditingController> _partyControllers = {};
  final Map<String, TextEditingController> _statControllers = {};
  bool _isOffline = false;
  Timer? _networkCheckTimer;

  String? _electionType;
  String? _primaryElectionType;
  String? _primaryParty;
  String? _userSenatorialDistrict;

  StreamSubscription<DocumentSnapshot>? _electionSubscription;
  StreamSubscription<DocumentSnapshot>? _resultsSubscription;
  String? _currentWebDocId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startNetworkTimer();
    _listenForElectionChanges();
  }

  void _listenForElectionChanges() {
    _electionSubscription = FirebaseFirestore.instance
        .collection('elections')
        .doc(widget.electionId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        // Just reload the data to sync parties array.
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _electionSubscription?.cancel();
    _resultsSubscription?.cancel();
    _networkCheckTimer?.cancel();
    for (var c in _partyControllers.values) {
      c.dispose();
    }
    for (var c in _statControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startNetworkTimer() {
    _checkNetwork();
    _networkCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (_isOffline != !isConnected) {
        if (mounted) {
          setState(() {
            _isOffline = !isConnected;
          });
        }
      }
    } catch (_) {
      if (!_isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    }
  }

  String _sanitizeId(String id) {
    return id
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _fetchUserSenatorialDistrict(String state, String lga) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('lgas')
          .where('state', isEqualTo: state)
          .where('name', isEqualTo: lga)
          .get();
      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        final district = data['senatorialDistrict']?.toString() ??
            data['senatorial_district']?.toString();
        if (district != null && mounted) {
          setState(() {
            _userSenatorialDistrict = district;
          });
          return;
        }
      }
      final docId = '${state}_$lga';
      final docSnap =
          await FirebaseFirestore.instance.collection('lgas').doc(docId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        final district = data?['senatorialDistrict']?.toString() ??
            data?['senatorial_district']?.toString();
        if (district != null && mounted) {
          setState(() {
            _userSenatorialDistrict = district;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user senatorial district: $e");
    }
  }

  void _updateControllers() {
    _partyVotes.forEach((k, v) {
      if (_partyControllers.containsKey(k)) {
        _partyControllers[k]!.text = v == 0 ? '' : v.toString();
      }
    });
    _stats.forEach((k, v) {
      if (_statControllers.containsKey(k)) {
        _statControllers[k]!.text = v == 0 ? '' : v.toString();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      _userProfile = profileSnap.data();

      final state = _userProfile?['assignedState'] ?? '';
      final lga = _userProfile?['assignedLga'] ?? '';
      final ward = _userProfile?['assignedWard'] ?? '';
      final pu = _userProfile?['assignedPollingUnit'] ?? '';

      if (state.isNotEmpty && lga.isNotEmpty) {
        _fetchUserSenatorialDistrict(state, lga);
      }

      final puKey = _sanitizeId('${state}_${lga}_${ward}_$pu');
      final webDocId = '${widget.electionId}_$puKey';
      final mobileDocId = '${widget.electionId}_${user?.uid}';
      final submissionId = '${widget.electionId}_${puKey}_${user?.uid}';

      if (_resultsSubscription == null || _currentWebDocId != webDocId) {
        _resultsSubscription?.cancel();
        _currentWebDocId = webDocId;
        _resultsSubscription = FirebaseFirestore.instance
            .collection('election_results')
            .doc(webDocId)
            .snapshots()
            .skip(1)
            .listen((snapshot) {
          if (mounted) {
            _loadData();
          }
        });
      }

      // Load Parties and Election
      List<Map<String, dynamic>> partiesData = [];
      try {
        final partiesSnap = await FirebaseFirestore.instance
            .collection('parties')
            .orderBy('abbreviation')
            .get();
        partiesData = partiesSnap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();
      } catch (e) {
        debugPrint('EC8A: Offline parties fallback');
        final localParties =
            await context.read<db.AppDatabase>().getAllLocalParties();
        partiesData = localParties
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'abbreviation': p.abbreviation,
                  'logoUrl': p.logoUrl,
                })
            .toList();
      }

      if (partiesData.isEmpty) {
        partiesData = [
          {
            'id': 'apc',
            'name': 'All Progressives Congress',
            'abbreviation': 'APC',
            'logoUrl': null
          },
          {
            'id': 'pdp',
            'name': 'Peoples Democratic Party',
            'abbreviation': 'PDP',
            'logoUrl': null
          },
          {
            'id': 'lp',
            'name': 'Labour Party',
            'abbreviation': 'LP',
            'logoUrl': null
          },
          {
            'id': 'nnpp',
            'name': 'New Nigeria Peoples Party',
            'abbreviation': 'NNPP',
            'logoUrl': null
          },
          {
            'id': 'apga',
            'name': 'All Progressives Grand Alliance',
            'abbreviation': 'APGA',
            'logoUrl': null
          },
        ];
      }

      DocumentSnapshot? electionDoc;
      List<String> allowedParties = [];
      int? expectedYear;
      String? expectedType;
      String? electionType;
      String? primaryElectionType;
      String? primaryParty;
      List<Map<String, dynamic>> aspirants = [];

      try {
        electionDoc = await FirebaseFirestore.instance
            .collection('elections')
            .doc(widget.electionId)
            .get();
      } catch (e) {
        debugPrint('EC8A: Offline election fallback');
      }

      if (electionDoc?.exists == true && electionDoc?.data() != null) {
        final data = electionDoc!.data() as Map<String, dynamic>;
        electionType = data['type']?.toString();
        primaryElectionType = data['primaryElectionType']?.toString();
        primaryParty = data['primaryParty']?.toString();
        if (data['aspirants'] != null && data['aspirants'] is List) {
          aspirants = (data['aspirants'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (data['startDate'] != null) {
          expectedYear = (data['startDate'] as Timestamp).toDate().year;
          expectedType = data['type']?.toString().toUpperCase();
        }
        if (data['parties'] != null && data['parties'] is List) {
          allowedParties = (data['parties'] as List)
              .map((e) => e.toString().toUpperCase())
              .toList();
        }
      } else {
        try {
          final dbInstance = context.read<db.AppDatabase>();
          final localElections = await dbInstance.getAllLocalElections();
          final matchIndex =
              localElections.indexWhere((e) => e.id == widget.electionId);
          if (matchIndex != -1) {
            final le = localElections[matchIndex];
            electionType = le.type;
            expectedType = le.type?.toUpperCase();
            if (le.startDate != null) {
              expectedYear = le.startDate!.year;
            }
            if (le.metadataJson != null) {
              final meta = jsonDecode(le.metadataJson!);
              primaryElectionType = meta['primaryElectionType']?.toString();
              primaryParty = meta['primaryParty']?.toString();
              if (meta['aspirants'] != null && meta['aspirants'] is List) {
                aspirants = (meta['aspirants'] as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
              }
              if (meta['parties'] != null && meta['parties'] is List) {
                allowedParties = (meta['parties'] as List)
                    .map((e) => e.toString().toUpperCase())
                    .toList();
              }
            }
          }
        } catch (_) {}
      }

      electionType ??= 'GENERAL';

      if (electionType == 'PARTY_PRIMARIES') {
        partiesData = aspirants
            .map((a) => {
                  'id': a['name']?.toString() ?? '',
                  'abbreviation': a['name']?.toString() ?? '',
                  'name': a['name']?.toString() ?? '',
                  'logoUrl': a['imageUrl']?.toString(),
                })
            .toList();
      }

      Map<String, dynamic>? observerSubmission;
      Map<String, dynamic>? observerStats;

      bool checkLocalOnly = _isOffline;
      List<dynamic> localSubmissions = [];
      String? localStatus;

      if (!_isOffline) {
        try {
          final docSnap = await FirebaseFirestore.instance
              .collection('election_results')
              .doc(webDocId)
              .get()
              .timeout(const Duration(seconds: 5));
          if (docSnap.exists && docSnap.data() != null) {
            final data = docSnap.data() as Map<String, dynamic>;
            localStatus = data['status']?.toString();
            localSubmissions = data['submissions'] as List<dynamic>? ?? [];

            final sub = localSubmissions.firstWhere(
              (s) => s['submittedBy'] == user?.uid,
              orElse: () => null,
            );
            if (sub != null) {
              observerSubmission = Map<String, dynamic>.from(sub);
              observerStats = observerSubmission;
            } else {
              // Not found in submissions array -> Deleted or wiped on Firestore!
              // Automatically wipe local copy from Drift DB
              final dbInstance = context.read<db.AppDatabase>();
              final localResults = await dbInstance.getAllResults();
              final matchIndex = localResults.indexWhere((r) =>
                  r.pollingUnitId == '${widget.electionId}_$puKey' &&
                  r.observerId == user?.uid);
              if (matchIndex != -1) {
                await dbInstance.deleteResult(localResults[matchIndex].id);
                debugPrint(
                    'EC8A: Wiped local result because submission was deleted in Firestore submissions array');
              }
            }
          } else {
            // Entire document deleted on Firestore!
            // Automatically wipe local copy from Drift DB
            final dbInstance = context.read<db.AppDatabase>();
            final localResults = await dbInstance.getAllResults();
            final matchIndex = localResults.indexWhere((r) =>
                r.pollingUnitId == '${widget.electionId}_$puKey' &&
                r.observerId == user?.uid);
            if (matchIndex != -1) {
              await dbInstance.deleteResult(localResults[matchIndex].id);
              debugPrint(
                  'EC8A: Wiped local result because Firestore document was deleted');
            }
          }
        } catch (e) {
          debugPrint('EC8A: Error checking Firestore, fallback to local: $e');
          checkLocalOnly = true;
        }
      }

      if (checkLocalOnly || observerSubmission == null) {
        // Fallback or read from local database
        try {
          final localResults =
              await context.read<db.AppDatabase>().getAllResults();
          final matchIndex = localResults.indexWhere((r) =>
              r.pollingUnitId == '${widget.electionId}_$puKey' &&
              r.observerId == user?.uid);
          if (matchIndex != -1) {
            final match = localResults[matchIndex];
            final statsMap =
                jsonDecode(match.ballotStatsJson) as Map<String, dynamic>;
            observerSubmission = {
              'partyVotes': jsonDecode(match.partyVotesJson),
              'evidenceUrl': match.imagePath,
              'status': statsMap['isFinal'] == true ? 'final' : 'draft',
            };
            observerStats = statsMap;
          }
        } catch (localDbError) {
          debugPrint('EC8A: Error loading local result: $localDbError');
        }
      }

      // If no submission is found in the array, check legacy paths
      if (observerSubmission == null) {
        try {
          var legacyDoc = await FirebaseFirestore.instance
              .collection('election_submissions')
              .doc(submissionId)
              .get();
          if (legacyDoc.exists) {
            observerSubmission = legacyDoc.data();
          } else {
            legacyDoc = await FirebaseFirestore.instance
                .collection('election_results')
                .doc(mobileDocId)
                .get();
            if (legacyDoc.exists) {
              observerSubmission = legacyDoc.data();
            } else {
              legacyDoc = await FirebaseFirestore.instance
                  .collection('election_results')
                  .doc(webDocId)
                  .get();
              if (legacyDoc.exists) {
                observerSubmission = legacyDoc.data();
              }
            }
          }
        } catch (e) {
          debugPrint('EC8A: Error loading legacy results: $e');
        }
      }

      if (observerStats == null) {
        try {
          var legacyStats = await FirebaseFirestore.instance
              .collection('election_statistics_submissions')
              .doc(submissionId)
              .get();
          if (legacyStats.exists) {
            observerStats = legacyStats.data();
          } else {
            legacyStats = await FirebaseFirestore.instance
                .collection('election_statistics')
                .doc(mobileDocId)
                .get();
            if (legacyStats.exists) {
              observerStats = legacyStats.data();
            } else {
              legacyStats = await FirebaseFirestore.instance
                  .collection('election_statistics')
                  .doc('${webDocId}_stats')
                  .get();
              if (legacyStats.exists) {
                observerStats = legacyStats.data();
              }
            }
          }
        } catch (e) {
          debugPrint('EC8A: Error loading legacy statistics: $e');
        }
      }

      if (mounted) {
        setState(() {
          _electionType = electionType;
          _primaryElectionType = primaryElectionType;
          _primaryParty = primaryParty;
          _parties = partiesData;
          _puSubmissions = localSubmissions;
          _puResultStatus = localStatus;

          if (_puSubmissions.isEmpty && observerSubmission != null) {
            final observerName =
                FirebaseAuth.instance.currentUser?.displayName ??
                    _userProfile?['fullName'] ??
                    _userProfile?['name'] ??
                    _userProfile?['displayName'] ??
                    'Observer';
            _puSubmissions = [
              {
                'submittedBy': user?.uid,
                'submittedByName': observerName,
                'phone': _userProfile?['phone'] ??
                    _userProfile?['phoneNumber'] ??
                    'N/A',
                'status': observerSubmission!['status'],
                'partyVotes': observerSubmission!['partyVotes'],
                'evidenceUrl': observerSubmission!['evidenceUrl'] ?? '',
              }
            ];
            _puResultStatus =
                observerSubmission!['status'] == 'final' ? 'Verified' : 'Draft';
          }

          if (electionType != 'PARTY_PRIMARIES' && allowedParties.isNotEmpty) {
            _parties = _parties
                .where((p) => allowedParties
                    .contains(p['abbreviation'].toString().toUpperCase()))
                .toList();
          }
          _expectedYear = expectedYear;
          _expectedType = expectedType;

          // Initialize controllers
          for (var data in _parties) {
            final abb = data['abbreviation'] as String;
            if (!_partyControllers.containsKey(abb)) {
              _partyControllers[abb] = TextEditingController();
            }
          }
          _stats.keys.forEach((key) {
            if (!_statControllers.containsKey(key)) {
              _statControllers[key] = TextEditingController();
            }
          });

          // Hydrate Party Votes Draft Data
          if (observerSubmission != null) {
            final votes =
                observerSubmission!['partyVotes'] as Map<String, dynamic>? ??
                    {};
            votes.forEach(
                (k, v) => _partyVotes[k] = int.tryParse(v.toString()) ?? 0);
            _isFinal = observerSubmission!['status'] == 'final';
            _evidenceUrl = observerSubmission!['evidenceUrl'] as String?;
          }

          // Hydrate EC8A Statistics Draft Data
          if (observerStats != null) {
            _stats.keys.forEach((key) {
              if (observerStats!.containsKey(key)) {
                _stats[key] = int.tryParse(observerStats![key].toString()) ?? 0;
              }
            });
          }
          _loading = false;
          _updateControllers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalValidVotes => _partyVotes.values.fold(0, (sum, v) => sum + v);
  int get _totalUsedBallots =>
      (_stats['ballotsIssued'] ?? 0) - (_stats['unusedBallots'] ?? 0);

  List<String> get _validationErrors {
    List<String> errors = [];
    if (_totalValidVotes > (_stats['votersInRegister'] ?? 0))
      errors.add('OVER-VOTING: Total votes exceed registered voters.');
    if ((_stats['accreditedVoters'] ?? 0) > (_stats['votersInRegister'] ?? 0))
      errors.add('ACCREDITATION ERROR: Accredited exceeds registered.');
    final totalBallotsCounted = (_stats['unusedBallots'] ?? 0) +
        (_stats['spoiledBallots'] ?? 0) +
        (_stats['rejectedBallots'] ?? 0);
    if (totalBallotsCounted > (_stats['ballotsIssued'] ?? 0))
      errors.add('BALLOT MISMATCH: Counted ballots exceed issued.');
    return errors;
  }

  Future<File> _addWatermark(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Draw original image
      canvas.drawImage(image, Offset.zero, Paint());

      // Top Left Watermark (Unobtrusive)
      final double fontSize = image.width * 0.04;
      final ui.TextStyle textStyle = ui.TextStyle(
        color: const Color.fromRGBO(255, 255, 255, 0.9),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          ui.Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.9),
            offset: Offset(2, 2),
            blurRadius: 8,
          ),
        ],
      );

      final ui.ParagraphBuilder topBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          textDirection: ui.TextDirection.ltr,
        ),
      )
        ..pushStyle(textStyle)
        ..addText('VOTEGUARD OFFICIAL SCANNED RECORD');

      final ui.Paragraph topParagraph = topBuilder.build()
        ..layout(ui.ParagraphConstraints(width: image.width.toDouble() - 40));

      canvas.drawParagraph(topParagraph, const Offset(20, 20));

      // Bottom right info watermark
      final double smallFontSize = image.width * 0.03;
      final ui.TextStyle smallTextStyle = ui.TextStyle(
        color: const Color.fromRGBO(255, 255, 255, 0.9),
        fontSize: smallFontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          ui.Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.9),
            offset: Offset(2, 2),
            blurRadius: 6,
          ),
        ],
      );
      final ui.ParagraphBuilder smallBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.right,
          textDirection: ui.TextDirection.ltr,
        ),
      )
        ..pushStyle(smallTextStyle)
        ..addText('Uploaded via VoteGuard System');
      final ui.Paragraph smallParagraph = smallBuilder.build()
        ..layout(ui.ParagraphConstraints(width: image.width.toDouble() - 20));

      canvas.drawParagraph(smallParagraph,
          Offset(0, image.height.toDouble() - smallParagraph.height - 20));

      final ui.Picture picture = recorder.endRecording();
      final ui.Image watermarkedImage =
          await picture.toImage(image.width, image.height);
      final ByteData? byteData =
          await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final watermarkedBytes = byteData.buffer.asUint8List();
        await imageFile.writeAsBytes(watermarkedBytes);
      }
    } catch (e) {
      debugPrint("Error applying watermark: $e");
    }
    return imageFile;
  }

  Future<void> _handleOCR(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img == null) return;

    if (_lastScanTime != null) {
      final diff = DateTime.now().difference(_lastScanTime!).inSeconds;
      if (diff < 65) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Rate Limit: Please wait ${65 - diff}s before scanning again.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    // Apply Watermark Before Saving to State
    File evidenceFile = File(img.path);
    evidenceFile = await _addWatermark(evidenceFile);

    setState(() {
      _evidenceFile = evidenceFile;
    });

    // Ask for pre-scan validation before automatically running the OCR
    _showPreScanValidation();
  }

  void _showPreScanValidation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Quality & Integrity Check',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before we automatically read the numbers, please confirm the following:',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.calendarCheck,
                    size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'This EC8A form is strictly for the ${_expectedYear ?? 'assigned'} ${_expectedType ?? ''} Election.',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.black))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.scanLine,
                    size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'All four borders of the document are visible, well-lit, and in focus.',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.black))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _evidenceFile = null;
              });
            },
            child: Text('RETAKE IMAGE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runOCR();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('I CONFIRM, PROCEED',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String? _lastUsedModel;

  Future<void> _runOCR() async {
    if (_evidenceFile == null) return;

    setState(() => _scanning = true);
    _lastScanTime = DateTime.now();

    try {
      final aiService = context.read<AIService>();
      Map<String, dynamic>? result;
      bool usedFallback = false;

      try {
        List<String> abbs =
            _parties.map((d) => d['abbreviation'] as String).toList();
        final aiResult = await aiService.processEC8A(_evidenceFile!, abbs);
        result = aiResult.data;
        _lastUsedModel = aiResult.modelName;
      } catch (geminiError) {
        debugPrint("Smart Optical T Scanner (online) failed, falling back to Smart Optical T Scanner (offline): $geminiError");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Smart Optical T Scanner (online) failed (falling back to Smart Optical T Scanner (offline): $geminiError'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        usedFallback = true;
        List<String> abbs =
            _parties.map((d) => d['abbreviation'] as String).toList();
        final aiResult = await aiService.processEC8ALocal(_evidenceFile!, abbs);
        result = aiResult.data;
        _lastUsedModel = aiResult.modelName;
      }

      if (result != null && mounted) {
        int? detectedYear =
            int.tryParse(result['electionYear']?.toString() ?? '');
        if (detectedYear != null &&
            _expectedYear != null &&
            detectedYear != _expectedYear &&
            detectedYear > 1900) {
          // Clear the image to force re-upload
          setState(() {
            _evidenceFile = null;
          });
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Election Year Mismatch!',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red)),
                ],
              ),
              content: Text(
                'Data Extraction Aborted.\n\nThe System detected the year $detectedYear on this result sheet, but you are assigned to observe the $_expectedYear election.\n\nPlease upload the correct EC8A image for the actual election.',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w600),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('UPLOAD CORRECT FORM',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          );
          return; // Abort extraction entirely
        }

        String _normalizeType(String? raw) {
          if (raw == null) return '';
          final t = raw.toUpperCase().replaceAll('_', ' ').trim();
          if (t.contains('COUNCILLOR') || t.contains('COUNCILLORSHIP'))
            return 'COUNCILLOR';
          if (t.contains('CHAIRMAN') ||
              t.contains('CHAIRMANSHIP') ||
              t.contains('COUNCIL') ||
              t.contains('MUNICIPAL')) return 'LOCAL GOVERNMENT';
          if (t.contains('GOVERNOR') || t.contains('GUBERNATORIAL'))
            return 'GUBERNATORIAL';
          if (t.contains('SENATE') || t.contains('SENATORIAL'))
            return 'SENATORIAL';
          if (t.contains('REPS') || t.contains('REPRESENTATIVES'))
            return 'HOUSE OF REPRESENTATIVES';
          if (t.contains('STATE HOUSE OF ASSEMBLY') ||
              t.contains('STATE ASSEMBLY') ||
              t.contains('STATE CONSTITUENCY'))
            return 'STATE HOUSE OF ASSEMBLY';
          return t;
        }

        String detectedType =
            _normalizeType(result['electionType']?.toString());
        String expectedType = _normalizeType(_expectedType);

        if (detectedType.isNotEmpty &&
            expectedType.isNotEmpty &&
            detectedType != expectedType) {
          // Clear the image to force re-upload
          setState(() {
            _evidenceFile = null;
          });
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Election Type Mismatch!',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red)),
                ],
              ),
              content: Text(
                'Data Extraction Aborted.\n\nThe System detected this is a $detectedType election result sheet, but you are assigned to observe the $expectedType election.\n\nPlease upload the correct EC8A image for the actual election type.',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w600),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('UPLOAD CORRECT FORM',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          );
          return; // Abort extraction entirely
        }

        // Proceed to map data since year and type matches (or wasn't detected)
        setState(() {
          // Robust mapping of party votes (handles nested "partyVotes" and flat keys)
          final dynamic rawPartyVotes = result?['partyVotes'];
          Map<String, dynamic> partyVotesMap = {};
          if (rawPartyVotes is Map) {
            partyVotesMap = Map<String, dynamic>.from(rawPartyVotes);
          }

          _parties.forEach((data) {
            final key = data['abbreviation'] as String;
            if (partyVotesMap.containsKey(key)) {
              _partyVotes[key] =
                  int.tryParse(partyVotesMap[key].toString()) ?? 0;
            } else if (result != null && result.containsKey(key)) {
              _partyVotes[key] = int.tryParse(result[key].toString()) ?? 0;
            }
          });

          // Map stats
          _stats.keys.forEach((key) {
            if (result != null && result.containsKey(key)) {
              _stats[key] = int.tryParse(result[key].toString()) ?? 0;
            }
          });
          _updateControllers();
        });

        if (usedFallback) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Offline Scan Complete (Best Effort)'),
              backgroundColor: Colors.orange));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('EC8A Sheet Scanned Successfully!'),
              backgroundColor: Color(0xFF10B981)));
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(LucideIcons.check, color: Colors.black),
                const SizedBox(width: 8),
                Text('Scan Complete',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black)),
              ],
            ),
            content: Text(
              'The EC8A data has been extracted using Smart Scan AI.\n\nPlease carefully cross-check the populated numbers with your original EC8A image to ensure 100% accuracy before you submit.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.black),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Verify Now',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(LucideIcons.triangleAlert, color: Colors.red),
                const SizedBox(width: 8),
                Text('Scanning Error',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', ''),
                style: GoogleFonts.outfit(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A))),
              ),
            ],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _handleDeleteLocalSubmission() async {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Local Submission Copy',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text(
            'Are you sure you want to delete this locally stored results sheet submission copy? This will unlock the result entry form.',
            style: GoogleFonts.outfit(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(confirmCtx);
              try {
                final user = FirebaseAuth.instance.currentUser;
                final state = _userProfile?['assignedState'] ?? '';
                final lga = _userProfile?['assignedLga'] ?? '';
                final ward = _userProfile?['assignedWard'] ?? '';
                final pu = _userProfile?['assignedPollingUnit'] ?? '';
                final puKey = _sanitizeId('${state}_${lga}_${ward}_$pu');

                final dbInstance = context.read<db.AppDatabase>();
                final localResults = await dbInstance.getAllResults();
                final matchIndex = localResults.indexWhere((r) =>
                    r.pollingUnitId == '${widget.electionId}_$puKey' &&
                    r.observerId == user?.uid);

                if (matchIndex != -1) {
                  await dbInstance.deleteResult(localResults[matchIndex].id);
                }

                if (mounted) {
                  setState(() {
                    _isFinal = false;
                    _evidenceUrl = null;
                    _evidenceFile = null;
                    _partyVotes.clear();
                    _stats.keys.forEach((k) => _stats[k] = 0);
                    _updateControllers();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Local submission copy deleted. Form unlocked.'),
                        backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                debugPrint('Error deleting local result: $e');
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: Text('DELETE COPY',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _attemptSubmit(bool isFinal) {
    final isPrimaries = _electionType == 'PARTY_PRIMARIES';
    if (isPrimaries) {
      _submit(isFinal);
      return;
    }

    if (_evidenceFile != null || _evidenceUrl != null) {
      showDialog(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Data Accuracy',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, color: Colors.black)),
          content: Text(
            'You have an EC8A image attached. Are you absolutely sure the numbers you have entered match the numbers on the physical EC8A form?',
            style: GoogleFonts.outfit(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: Text('REVIEW',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(confirmCtx);
                _submit(isFinal);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Text('PROCEED',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // Missing EC8A Warning Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(LucideIcons.image, color: Colors.orange),
              const SizedBox(width: 10),
              Text('Missing EC8A Form',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black)),
            ],
          ),
          content: Text(
            'There is no EC8A Form image uploaded to support this entry. Please upload the physical result sheet before finalizing your submission.',
            style: GoogleFonts.outfit(
                fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submit(isFinal);
              },
              child: Text('CONTINUE WITHOUT FORM',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK, UPLOAD FORM',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  Future<void> _submit(bool isFinal) async {
    final isPrimaries = _electionType == 'PARTY_PRIMARIES';
    if (isFinal && !isPrimaries && _validationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_validationErrors.first), backgroundColor: Colors.red));
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? evidenceUrl;

      if (_evidenceFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('results/${widget.electionId}/${user?.uid}.jpg');
        await ref
            .putFile(_evidenceFile!, SettableMetadata(contentType: 'image/png'))
            .timeout(const Duration(seconds: 15));
        evidenceUrl = await ref.getDownloadURL();
      }

      // 1. Data Preparation (Both Modes)
      final state = _userProfile?['assignedState'] ?? '';
      final lga = _userProfile?['assignedLga'] ?? '';
      final ward = _userProfile?['assignedWard'] ?? '';
      final pu = _userProfile?['assignedPollingUnit'] ?? '';
      final puKey = _sanitizeId('${state}_${lga}_${ward}_$pu');

      final docRef = FirebaseFirestore.instance
          .collection('election_results')
          .doc('${widget.electionId}_$puKey');
      final docSnap = await docRef.get().timeout(const Duration(seconds: 10));

      List<dynamic> submissionsList = [];
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data() as Map<String, dynamic>;
        submissionsList = List.from(data['submissions'] ?? []);
      }

      final observerName = FirebaseAuth.instance.currentUser?.displayName ??
          _userProfile?['fullName'] ??
          _userProfile?['name'] ??
          _userProfile?['displayName'] ??
          'Observer';

      // Let's resolve the Senatorial District offline
      String? resolvedSenatorialDistrict = _userSenatorialDistrict;
      if (resolvedSenatorialDistrict == null &&
          state.isNotEmpty &&
          lga.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('lgas')
              .where('state', isEqualTo: state)
              .where('name', isEqualTo: lga)
              .get();
          if (q.docs.isNotEmpty) {
            resolvedSenatorialDistrict =
                q.docs.first.data()['senatorialDistrict']?.toString() ??
                    q.docs.first.data()['senatorial_district']?.toString();
          } else {
            final docSnap = await FirebaseFirestore.instance
                .collection('lgas')
                .doc('${state}_$lga')
                .get();
            if (docSnap.exists) {
              resolvedSenatorialDistrict =
                  docSnap.data()?['senatorialDistrict']?.toString() ??
                      docSnap.data()?['senatorial_district']?.toString();
            }
          }
        } catch (e) {
          debugPrint(
              "Error fetching offline senatorial district in submit: $e");
        }
      }

      // Let's resolve the Assembly Constituency
      String? resolvedAssemblyConstituency;
      if (isPrimaries &&
          _primaryElectionType == 'STATE_HOUSE_OF_ASSEMBLY' &&
          state.isNotEmpty &&
          lga.isNotEmpty &&
          ward.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('wards')
              .where('state', isEqualTo: state)
              .where('lga', isEqualTo: lga)
              .where('name', isEqualTo: ward)
              .get();
          if (q.docs.isNotEmpty) {
            resolvedAssemblyConstituency =
                q.docs.first.data()['stateAssemblyConstituency']?.toString() ??
                    q.docs.first.data()['assemblyConstituency']?.toString() ??
                    q.docs.first.data()['constituency']?.toString() ??
                    q.docs.first
                        .data()['state_assembly_constituency']
                        ?.toString() ??
                    q.docs.first.data()['assembly_constituency']?.toString();
          } else {
            final docId = '${state}_${lga}_$ward'
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
                .toLowerCase();
            final docSnap = await FirebaseFirestore.instance
                .collection('wards')
                .doc(docId)
                .get();
            if (docSnap.exists) {
              final data = docSnap.data();
              resolvedAssemblyConstituency =
                  data?['stateAssemblyConstituency']?.toString() ??
                      data?['assemblyConstituency']?.toString() ??
                      data?['constituency']?.toString() ??
                      data?['state_assembly_constituency']?.toString() ??
                      data?['assembly_constituency']?.toString();
            }
          }
        } catch (e) {
          debugPrint("Error fetching assembly constituency in submit: $e");
        }
        if (resolvedAssemblyConstituency == null ||
            resolvedAssemblyConstituency.isEmpty) {
          resolvedAssemblyConstituency = lga;
        }
      }

      final newReport = {
        'submittedBy': user?.uid,
        'submittedByName': observerName,
        'phone':
            _userProfile?['phone'] ?? _userProfile?['phoneNumber'] ?? 'N/A',
        'submittedAt': Timestamp.now(),
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pu,
        'partyVotes': _partyVotes,
        'results': _partyVotes,
        'evidenceUrl': evidenceUrl ?? _evidenceUrl ?? '',
        'status': isFinal ? 'final' : 'draft',
        if (resolvedSenatorialDistrict != null)
          'senatorialDistrict': resolvedSenatorialDistrict,
        if (resolvedAssemblyConstituency != null)
          'stateAssemblyConstituency': resolvedAssemblyConstituency,
        ..._stats,
        'totalValidVotes': _totalValidVotes,
        'totalUsedBallots': _totalUsedBallots,
      };

      final index =
          submissionsList.indexWhere((sub) => sub['submittedBy'] == user?.uid);
      if (index != -1) {
        submissionsList[index] = newReport;
      } else {
        submissionsList.add(newReport);
      }

      final isNewDoc = !docSnap.exists;
      final Map<String, dynamic> docPayload = {
        'electionId': widget.electionId,
        'electionType': _electionType ?? 'GENERAL',
        if (_primaryElectionType != null)
          'primaryElectionType': _primaryElectionType,
        if (_primaryParty != null) 'primaryParty': _primaryParty,
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pu,
        'partyVotes': _partyVotes,
        'results': _partyVotes,
        if (evidenceUrl != null || _evidenceUrl != null)
          'evidenceUrl': evidenceUrl ?? _evidenceUrl,
        'submittedBy': user?.uid,
        'submittedByName': observerName,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNewDoc) 'createdAt': FieldValue.serverTimestamp(),
        if (resolvedSenatorialDistrict != null)
          'senatorialDistrict': resolvedSenatorialDistrict,
        if (resolvedAssemblyConstituency != null)
          'stateAssemblyConstituency': resolvedAssemblyConstituency,
        ..._stats,
        'totalValidVotes': _totalValidVotes,
        'totalUsedBallots': _totalUsedBallots,
        'submissions': submissionsList,
      };

      await docRef
          .set(docPayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      final ipAddress = await _getPublicIP();

      // Audit Log for Results Submission
      try {
        await FirebaseFirestore.instance.collection('audit_logs').add({
          'userId': user?.uid,
          'userEmail': user?.email,
          'action': isFinal ? 'RESULTS_SUBMIT' : 'RESULTS_SAVE_DRAFT',
          'resource': 'results',
          'ipAddress': ipAddress,
          'details': {
            'observerName': _userProfile?['fullName'] ??
                _userProfile?['name'] ??
                _userProfile?['displayName'] ??
                'Observer',
            'phone':
                _userProfile?['phone'] ?? _userProfile?['phoneNumber'] ?? 'N/A',
            'electionId': widget.electionId,
            'state': state,
            'lga': lga,
            'ward': ward,
            'pollingUnit': pu,
            'totalValidVotes': _totalValidVotes,
            'totalUsedBallots': _totalUsedBallots,
          },
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      } catch (auditError) {
        debugPrint('Graceful: Failed to write results audit log: $auditError');
      }

      // Also ALWAYS store/update in local Drift database!
      try {
        final dbInstance = context.read<db.AppDatabase>();
        final localResults = await dbInstance.getAllResults();
        final matchIndex = localResults.indexWhere(
            (r) => r.pollingUnitId == '${widget.electionId}_$puKey');

        if (matchIndex != -1) {
          final existing = localResults[matchIndex];
          await dbInstance.deleteResult(existing.id);
        }

        final resultCompanion = db.ResultsCompanion(
          observerId: drift.Value(user?.uid ?? ''),
          pollingUnitId: drift.Value('${widget.electionId}_$puKey'),
          partyVotesJson: drift.Value(jsonEncode(_partyVotes)),
          ballotStatsJson: drift.Value(jsonEncode({
            ..._stats,
            'electionId': widget.electionId,
            'state': state,
            'lga': lga,
            'ward': ward,
            'pollingUnit': pu,
            'totalValidVotes': _totalValidVotes,
            'totalUsedBallots': _totalUsedBallots,
            'isFinal': isFinal,
            if (resolvedSenatorialDistrict != null)
              'senatorialDistrict': resolvedSenatorialDistrict,
            if (resolvedAssemblyConstituency != null)
              'stateAssemblyConstituency': resolvedAssemblyConstituency,
          })),
          imagePath: drift.Value(_evidenceFile?.path ?? _evidenceUrl),
          isSynced: const drift.Value(true),
        );
        await dbInstance.insertResult(resultCompanion);
      } catch (localDbError) {
        debugPrint('Local DB Sync/Save failed: $localDbError');
      }

      await _loadData();
      if (mounted) {
        if (isFinal) {
          // 3. Final Submission Post-Action
          setState(() =>
              _isFinal = true); // _isFinal acts as the isSubmitted boolean
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Results Submitted and Locked'),
              backgroundColor: Color(0xFF10B981)));
          // Navigate back to Observer Command Center Dashboard
          DefaultTabController.maybeOf(context)?.animateTo(0);
        } else {
          // 2. Save Progress Post-Action
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Draft Saved'),
              backgroundColor: Color(0xFF3B82F6)));
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socket') ||
          errorStr.contains('network') ||
          errorStr.contains('unavailable') ||
          errorStr.contains('host-lookup') ||
          errorStr.contains('connection') ||
          errorStr.contains('timeout');

      if (isNetworkError) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final state = _userProfile?['assignedState'] ?? '';
          final lga = _userProfile?['assignedLga'] ?? '';
          final ward = _userProfile?['assignedWard'] ?? '';
          final pu = _userProfile?['assignedPollingUnit'] ?? '';
          final puKey = _sanitizeId('${state}_${lga}_${ward}_$pu');

          final dbInstance = context.read<db.AppDatabase>();
          final localResults = await dbInstance.getAllResults();
          final matchIndex = localResults.indexWhere(
              (r) => r.pollingUnitId == '${widget.electionId}_$puKey');

          if (matchIndex != -1) {
            final existing = localResults[matchIndex];
            await dbInstance.deleteResult(existing.id);
          }

          final resultCompanion = db.ResultsCompanion(
            observerId: drift.Value(user?.uid ?? ''),
            pollingUnitId: drift.Value('${widget.electionId}_$puKey'),
            partyVotesJson: drift.Value(jsonEncode(_partyVotes)),
            ballotStatsJson: drift.Value(jsonEncode({
              ..._stats,
              'electionId': widget.electionId,
              'state': state,
              'lga': lga,
              'ward': ward,
              'pollingUnit': pu,
              'totalValidVotes': _totalValidVotes,
              'totalUsedBallots': _totalUsedBallots,
              'isFinal': isFinal,
            })),
            imagePath: drift.Value(_evidenceFile?.path),
            isSynced: const drift.Value(false),
          );

          await dbInstance.insertResult(resultCompanion);

          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No internet connection. Saved locally to offline drafts!'),
                backgroundColor: Colors.orange,
              ),
            );
            if (isFinal) {
              setState(() => _isFinal = true);
              DefaultTabController.maybeOf(context)?.animateTo(0);
            }
          }
          return;
        } catch (localDbError) {
          debugPrint('Local DB Save failed: $localDbError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Submission failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF065F46)));

    final isPrimaries = _electionType == 'PARTY_PRIMARIES';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildHeader(),
        if (_validationErrors.isNotEmpty && !isPrimaries) ...[
          const SizedBox(height: 16),
          _buildValidationBanner(),
        ],
        const SizedBox(height: 32),
        _buildResultsGridCard(),
        if (!isPrimaries) ...[
          const SizedBox(height: 24),
          _buildEvidenceSidebarCard(),
          const SizedBox(height: 24),
          _buildStatsSidebarCard(),
        ],
        const SizedBox(height: 32),
        _buildPollingUnitSubmissionsSection(),
        const SizedBox(height: 32),
        _buildProgressFooter(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildPollingUnitSubmissionsSection() {
    if (_puSubmissions.isEmpty) return const SizedBox.shrink();

    final isDisputed = _puResultStatus?.toLowerCase() == 'disputed';
    final isResolved = _puResultStatus?.toLowerCase() == 'resolved';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 30,
              offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('POLLING UNIT SUBMISSIONS',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDisputed
                      ? const Color(0xFFFEF2F2)
                      : (isResolved
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  (_puResultStatus ?? 'VERIFIED').toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isDisputed
                        ? const Color(0xFFEF4444)
                        : (isResolved
                            ? const Color(0xFF10B981)
                            : const Color(0xFF3B82F6)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isDisputed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert,
                      color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISPUTED ELECTION RESULT DETECTED',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF991B1B))),
                        const SizedBox(height: 4),
                        Text(
                            'Results uploaded by observers have conflicting party figures. Admin review has been initiated.',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: const Color(0xFF7F1D1D))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else if (isResolved) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldCheck,
                      color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CONFLICT RESOLVED BY ADMINISTRATOR',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF065F46))),
                        const SizedBox(height: 4),
                        Text(
                            'The conflicting entries have been officially audited and resolved by election officials.',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: const Color(0xFF064E3B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _puSubmissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final sub = _puSubmissions[index] as Map<String, dynamic>;
              final observerName =
                  sub['submittedByName']?.toString() ?? 'Observer';
              final observerPhone = sub['phone']?.toString() ?? 'N/A';
              final rawVotes = sub['partyVotes'] as Map<String, dynamic>? ?? {};
              final evidence = sub['evidenceUrl']?.toString() ?? '';

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.user,
                              size: 18, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(observerName,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(LucideIcons.phone,
                                      size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(observerPhone,
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (evidence.isNotEmpty) ...[
                          IconButton(
                            onPressed: () =>
                                _viewSubmissionEvidence(evidence, observerName),
                            icon: const Icon(LucideIcons.eye,
                                size: 20, color: Color(0xFF0F172A)),
                            tooltip: 'View Results Document',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('PARTY VOTES SUBMITTED',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: rawVotes.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.key.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A))),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text('${e.value}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF334155))),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _viewSubmissionEvidence(String url, String observerName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Evidence Preview',
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white));
                    },
                  ),
                ),
              ),
              Positioned(
                top: 54,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RESULTS SHEET',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white54,
                                letterSpacing: 1)),
                        Text('Submitted by $observerName',
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Submit Results',
                  style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -1)),
              const SizedBox(height: 4),
              Text('Enter results for 2026 Presidential Election',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _isOffline
            ? _buildConnectionStatusBadge('OFFLINE CONNECTION',
                const Color(0xFFFEF2F2), const Color(0xFFEF4444))
            : _buildConnectionStatusBadge('LIVE CONNECTION',
                const Color(0xFFECFDF5), const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildConnectionStatusBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: textCol, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildValidationBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.triangleAlert,
                  color: Color(0xFFB91C1C), size: 18),
              const SizedBox(width: 10),
              Text('VALIDATION ERRORS DETECTED',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFB91C1C),
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ..._validationErrors.map((err) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: Color(0xFFB91C1C), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(err,
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7F1D1D)))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildResultsGridCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.chartBar, 'Election Results', ''),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleItem('CONDENSED', !_isPrecisionView,
                    () => setState(() => _isPrecisionView = false)),
                _buildToggleItem('PRECISION VIEW', _isPrecisionView,
                    () => setState(() => _isPrecisionView = true)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_isPrecisionView)
            _buildPrecisionHeader()
          else
            const SizedBox.shrink(),
          if (_isPrecisionView)
            _buildPrecisionList()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: _parties.length,
              itemBuilder: (context, i) => _buildPartyEntryCard(_parties[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildPrecisionHeader() {
    final isPrimaries = _electionType == 'PARTY_PRIMARIES';
    final logoSize = isPrimaries ? 64.0 : 48.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: logoSize,
              child: Text(isPrimaries ? 'ASPIRANTS' : 'PARTY LOGO',
                  style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5))),
          const SizedBox(width: 16),
          Expanded(
              child: Text(isPrimaries ? 'ASPIRANT NAME' : 'PARTY NAME',
                  style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5))),
          const SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text('TOTAL VOTES',
                  style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildPrecisionList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _parties.length,
      separatorBuilder: (context, i) =>
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, i) => _buildPartyEntryRow(_parties[i]),
    );
  }

  Widget _buildPartyEntryRow(Map<String, dynamic> party) {
    final abb = party['abbreviation'] ?? '';
    final name = party['name'] ?? '';
    final logoUrl = party['logoUrl'];
    final isPrimaries = _electionType == 'PARTY_PRIMARIES';
    final logoSize = isPrimaries ? 64.0 : 48.0;
    final fontSize = isPrimaries ? 20.0 : 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _buildSmartLogo(logoUrl, abb, logoSize, fontSize: fontSize),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B))),
                if (!isPrimaries) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(abb,
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900)),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                              color: Color(0xFFCBD5E1),
                              shape: BoxShape.circle)),
                      Text('OFFICIAL PARTY',
                          style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextField(
              enabled: !_isFinal,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) =>
                  setState(() => _partyVotes[abb] = int.tryParse(v) ?? 0),
              controller: _partyControllers[abb],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: active
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _buildPartyEntryCard(Map<String, dynamic> party) {
    final abb = party['abbreviation'] ?? '';
    final name = party['name'] ?? '';
    final logoUrl = party['logoUrl'];
    final isPrimaries = _electionType == 'PARTY_PRIMARIES';
    final logoSize = isPrimaries ? 48.0 : 24.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          _buildSmartLogo(logoUrl, abb, logoSize,
              fontSize: isPrimaries ? 14 : 10),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(abb,
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: TextField(
              enabled: !_isFinal,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) =>
                  setState(() => _partyVotes[abb] = int.tryParse(v) ?? 0),
              controller: _partyControllers[abb],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSidebarCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: _buildCardHeader(
                      LucideIcons.fileImage, 'RESULT SHEET (EC8A)', '')),
              if (_evidenceFile != null || _evidenceUrl != null)
                IconButton(
                  onPressed: () => _showFullImage(),
                  icon: const Icon(LucideIcons.maximize2,
                      size: 14, color: Color(0xFF10B981)),
                )
              else
                const Icon(LucideIcons.maximize2,
                    size: 14, color: Color(0xFFCBD5E1)),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              image: _evidenceFile != null
                  ? DecorationImage(
                      image: FileImage(_evidenceFile!),
                      fit: BoxFit.cover,
                      colorFilter: _scanning
                          ? ColorFilter.mode(
                              Colors.black.withOpacity(0.6), BlendMode.darken)
                          : null,
                    )
                  : (_evidenceUrl != null
                      ? DecorationImage(
                          image: (!_evidenceUrl!.startsWith('http://') &&
                                  !_evidenceUrl!.startsWith('https://'))
                              ? FileImage(File(_evidenceUrl!)) as ImageProvider
                              : CachedNetworkImageProvider(_evidenceUrl!),
                          fit: BoxFit.cover,
                        )
                      : null),
            ),
            child: _scanning
                ? Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 0.99),
                      duration: const Duration(seconds: 12),
                      builder: (context, value, _) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 6,
                                    color: const Color(0xFF10B981),
                                    backgroundColor: const Color(0xFFECFDF5)),
                              ),
                              Text('${(value * 100).toInt()}%',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF065F46))),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : (_evidenceFile == null && _evidenceUrl == null)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.image,
                                size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 16),
                            Text(
                                'No result sheet uploaded yet.\nUpload the EC8A form to automatically read the numbers.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : null,
          ),
          const SizedBox(height: 24),
          if (_evidenceFile == null && _evidenceUrl == null && !_isFinal)
            Row(
              children: [
                Expanded(
                    child: _buildActionButton(
                        'TAKE SNAPSHOT',
                        LucideIcons.camera,
                        () => _handleOCR(ImageSource.camera))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildActionButton(
                        'PICK FROM GALLERY',
                        LucideIcons.image,
                        () => _handleOCR(ImageSource.gallery))),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                    child: _buildActionButton(
                        'CHANGE IMAGE', LucideIcons.refreshCw, () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24))),
                    backgroundColor: Colors.white,
                    builder: (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Change Image Source',
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(LucideIcons.camera,
                                  color: Colors.black),
                              title: Text('Take New Photo',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _handleOCR(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(LucideIcons.image,
                                  color: Colors.black),
                              title: Text('Upload from Gallery',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _handleOCR(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF10B981)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : () => _runOCR(),
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.scan,
                              size: 16, color: Colors.white),
                      label: Text('AUTO-FILL NUMBERS',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Center(
            child: ListenableBuilder(
              listenable: context.read<AIService>(),
              builder: (context, _) {
                final aiService = context.read<AIService>();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon(LucideIcons.cpu, size: 12, color: Colors.blueGrey.withOpacity(0.6)),
                    // const SizedBox(width: 6),
                    // Text(
                    //   'ACTIVE ENGINE: ${aiService.currentModelName.toUpperCase()}',
                    //   style: GoogleFonts.outfit(
                    //     fontSize: 9,
                    //     fontWeight: FontWeight.w900,
                    //     color: Colors.blueGrey.withOpacity(0.7),
                    //     letterSpacing: 0.8,
                    //   ),
                    // ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage() {
    if (_evidenceFile == null && _evidenceUrl == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: _evidenceFile != null
                    ? Image.file(_evidenceFile!)
                    : ((!_evidenceUrl!.startsWith('http://') &&
                            !_evidenceUrl!.startsWith('https://'))
                        ? Image.file(File(_evidenceUrl!))
                        : CachedNetworkImage(imageUrl: _evidenceUrl!)),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.black, size: 24),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isFinal ? null : onTap,
        icon: Icon(icon, size: 16),
        label: Text(label,
            style:
                GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildStatsSidebarCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
              LucideIcons.calculator, 'VOTER STATISTICS (EC8A)', ''),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildCompactStatInput('VOTERS IN REGISTER', 'votersInRegister'),
              const SizedBox(width: 12),
              _buildCompactStatInput('ACCREDITED VOTERS', 'accreditedVoters'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCompactStatInput('BALLOTS ISSUED', 'ballotsIssued'),
              const SizedBox(width: 12),
              _buildCompactStatInput('UNUSED BALLOTS', 'unusedBallots'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCompactStatInput('SPOILED BALLOTS', 'spoiledBallots'),
              const SizedBox(width: 12),
              _buildCompactStatInput('REJECTED BALLOTS', 'rejectedBallots'),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL VALID VOTES',
                      style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF94A3B8))),
                  Text(_totalValidVotes.toString(),
                      style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOTAL USED BALLOTS',
                      style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF94A3B8))),
                  Text(_totalUsedBallots.toString(),
                      style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatInput(String label, String key) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          TextField(
            enabled: !_isFinal,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '0',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
            onChanged: (v) =>
                setState(() => _stats[key] = int.tryParse(v) ?? 0),
            controller: _statControllers[key],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                  child: _buildStepIndicator(
                      '1', 'ACCREDITATION', 'VERIFIED', true)),
              _buildStepDivider(),
              Flexible(
                  child: _buildStepIndicator(
                      '2', 'RESULT ENTRY', 'ACTIVE', false,
                      isCurrent: true)),
              _buildStepDivider(),
              Flexible(
                  child: _buildStepIndicator(
                      '3', 'FINAL REVIEW', 'PENDING', false)),
            ],
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isFinal || _submitting)
                      ? null
                      : () => _attemptSubmit(false),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0F172A)))
                      : const Icon(LucideIcons.save, size: 16),
                  label: Text(
                      _submitting ? 'SAVING...' : 'SAVE PROGRESS / DRAFT',
                      style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    side: const BorderSide(color: Color(0xFFF1F5F9)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              if (!_isFinal) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF059669).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : () => _attemptSubmit(true),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.check,
                            size: 16, color: Colors.white),
                    label: Text(
                        _submitting ? 'SUBMITTING...' : 'FINAL SUBMISSION',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              ],
              if (_isFinal) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleDeleteLocalSubmission,
                    icon: const Icon(LucideIcons.trash2,
                        size: 16, color: Color(0xFFEF4444)),
                    label: Text('DELETE LOCAL SUBMISSION COPY',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFEF4444))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      backgroundColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
      String num, String title, String sub, bool verified,
      {bool isCurrent = false}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: verified
                ? const Color(0xFFECFDF5)
                : (isCurrent
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF1F5F9)),
            shape: BoxShape.circle,
            border:
                verified ? Border.all(color: const Color(0xFF10B981)) : null,
          ),
          child: Center(
            child: verified
                ? const Icon(LucideIcons.check,
                    size: 14, color: Color(0xFF10B981))
                : Text(num,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isCurrent
                            ? Colors.white
                            : const Color(0xFF94A3B8))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A))),
              Text(sub,
                  style: GoogleFonts.outfit(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: verified
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Container(width: 20, height: 1, color: const Color(0xFFF1F5F9));
  }

  void _showResultsSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('RESULTS EVIDENCE',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Attach the EC8A result sheet',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildResultsPickerOption(
              icon: LucideIcons.camera,
              title: 'TAKE SNAPSHOT',
              subtitle: 'Scan official document now',
              onTap: () {
                Navigator.pop(ctx);
                _handleOCR(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildResultsPickerOption(
              icon: LucideIcons.image,
              title: 'PICK FROM GALLERY',
              subtitle: 'Upload from device storage',
              onTap: () {
                Navigator.pop(ctx);
                _handleOCR(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPickerOption(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A))),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: Color(0xFFECFDF5), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis),
              if (sub.isNotEmpty)
                Text(sub,
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartLogo(String? url, String abb, double size,
      {double fontSize = 14}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    _buildFallbackLogo(abb, size, fontSize),
                errorWidget: (context, url, error) =>
                    _buildFallbackLogo(abb, size, fontSize),
              )
            : _buildFallbackLogo(abb, size, fontSize),
      ),
    );
  }

  Widget _buildFallbackLogo(String abb, double size, double fontSize) {
    String initials = '?';
    if (abb.isNotEmpty) {
      final parts = abb.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        final first = parts[0].isNotEmpty ? parts[0][0] : '';
        final second = parts[1].isNotEmpty ? parts[1][0] : '';
        initials = (first + second).toUpperCase();
      } else {
        initials = parts[0].length >= 2
            ? parts[0].substring(0, 2).toUpperCase()
            : parts[0].toUpperCase();
      }
    }
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A)),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      debugPrint('Initializing video player for: ${widget.url}');
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));

      await _videoPlayerController!.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(color: Colors.black),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 42),
                const SizedBox(height: 12),
                Text(
                  'Video playback error',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          );
        },
      );

      setState(() {});
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load video',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return _chewieController != null &&
            _chewieController!.videoPlayerController.value.isInitialized
        ? Chewie(controller: _chewieController!)
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Buffering...',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
    _audioPlayer.onPlayerStateChanged
        .listen((s) => setState(() => _isPlaying = s == PlayerState.playing));
    await _audioPlayer.setSourceUrl(widget.url);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child:
                const Icon(LucideIcons.mic, color: Color(0xFF10B981), size: 32),
          ),
          const SizedBox(height: 12),
          Text('AUDIO RECORDING',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: const Color(0xFF10B981),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.white,
            ),
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds
                  .toDouble()
                  .clamp(0.0, _duration.inMilliseconds.toDouble()),
              onChanged: (value) async {
                await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position),
                    style:
                        GoogleFonts.outfit(fontSize: 9, color: Colors.white54)),
                Text(_formatDuration(_duration),
                    style:
                        GoogleFonts.outfit(fontSize: 9, color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IconButton(
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.url));
              }
            },
            iconSize: 48,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class _ChatWidget extends StatefulWidget {
  final String groupId;
  final String userId;
  final String userName;
  final String role;

  const _ChatWidget({
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.role,
  });

  @override
  State<_ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<_ChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _replyingToMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.users,
                      size: 20, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GROUP CHAT',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A))),
                      Text(widget.groupId.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_messages')
                  .where('groupId', isEqualTo: widget.groupId)
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final isMe = d['senderId'] == widget.userId;
                    final sender = d['sender'] as Map<String, dynamic>? ?? {};
                    final isDeleted = d['isDeleted'] == true;
                    final isEdited = d['isEdited'] == true;
                    final docId = docs[i].id;

                    if (isDeleted) {
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "This message has been deleted",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 0),
                                bottomRight: Radius.circular(isMe ? 0 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  Text(
                                      sender['name'] ??
                                          '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'
                                              .trim(),
                                      style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                ],
                                if (d['replyTo'] != null) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.1)
                                          : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(
                                        left: BorderSide(
                                          color: isMe
                                              ? Colors.white54
                                              : const Color(0xFF991B1B),
                                          width: 3.0,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d['replyTo']['senderName'] ?? '',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isMe
                                                ? Colors.white70
                                                : const Color(0xFF991B1B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          d['replyTo']['content'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: isMe
                                                ? Colors.white60
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (d['type'] == 'image' &&
                                    d['imageUrl'] != null &&
                                    d['imageUrl'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: d['imageUrl'],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          height: 150,
                                          color: isMe
                                              ? Colors.white12
                                              : Colors.black12,
                                          child: const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error,
                                                color: Colors.red),
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        d['content'] ?? '',
                                        style: GoogleFonts.outfit(
                                          color: isMe
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 12),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                LucideIcons.cornerUpLeft,
                                                size: 13,
                                                color: Colors.white70),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _replyingToMessage = {
                                                  'messageId': docId,
                                                  'senderName': 'You',
                                                  'content': d['content'] ??
                                                      (d['type'] == 'image'
                                                          ? '[Image]'
                                                          : ''),
                                                  'type': d['type'] ?? 'text',
                                                };
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          if (d['type'] != 'image') ...[
                                            IconButton(
                                              icon: const Icon(
                                                  LucideIcons.pencil,
                                                  size: 13,
                                                  color: Colors.white70),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                _showEditDialog(
                                                    docId, d['content'] ?? '');
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          IconButton(
                                            icon: const Icon(LucideIcons.trash2,
                                                size: 13,
                                                color: Color(0xFFFCA5A5)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _confirmDelete(docId);
                                            },
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(
                                            LucideIcons.cornerUpLeft,
                                            size: 13,
                                            color: Color(0xFF64748B)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            _replyingToMessage = {
                                              'messageId': docId,
                                              'senderName': sender['name'] ??
                                                  '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'
                                                      .trim(),
                                              'content': d['content'] ??
                                                  (d['type'] == 'image'
                                                      ? '[Image]'
                                                      : ''),
                                              'type': d['type'] ?? 'text',
                                            };
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12.0, right: 12.0, bottom: 12.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTimestamp(d['createdAt']),
                                  style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B)),
                                ),
                                if (isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      "(edited)",
                                      style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.cornerUpRight,
                      size: 16, color: Color(0xFF991B1B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Replying to ${_replyingToMessage!['senderName']}",
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!['content'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x,
                        size: 16, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.outfit(
                          fontSize: 14, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.send,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(
      BuildContext context, String docId, String currentContent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(LucideIcons.pencil, color: Colors.blue),
              title: Text('Edit Message',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A))),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(docId, currentContent);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: Text('Delete Message',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(docId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String docId, String currentContent) {
    final editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Message',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        content: TextField(
          controller: editController,
          autofocus: true,
          style: GoogleFonts.outfit(color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Edit message...',
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('chat_messages')
                    .doc(docId)
                    .update({
                  'content': newContent,
                  'isEdited': true,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('SAVE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Message',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
        content: Text('Are you sure you want to delete this message?',
            style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('chat_messages')
                  .doc(docId)
                  .update({
                'isDeleted': true,
                'content': '',
                'imageUrl': '',
                'type': 'text',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('DELETE',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final replyData = _replyingToMessage;
    setState(() {
      _replyingToMessage = null;
    });

    _controller.clear();

    final names = widget.userName.split(' ');
    final firstName = names.isNotEmpty ? names[0] : 'Observer';
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

    await FirebaseFirestore.instance.collection('chat_messages').add({
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
      'groupId': widget.groupId,
      'isRead': false,
      'senderId': widget.userId,
      'type': 'text',
      'sender': {
        'firstName': firstName,
        'lastName': lastName,
        'name': widget.userName,
        'role': widget.role,
        'senderId': widget.userId,
      },
      if (replyData != null) 'replyTo': replyData,
    });
  }

  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return '';
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final minutes = date.minute.toString().padLeft(2, '0');
      return "${date.hour}:$minutes";
    }
    return '';
  }
}

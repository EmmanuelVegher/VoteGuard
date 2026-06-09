import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voteguard/models/geo_models.dart';

class GeoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<GeoItem>> getStates() async {
    try {
      final snapshot = await _firestore.collection('states').orderBy('name').get();
      return snapshot.docs.map((doc) => GeoItem.fromFirestore(doc.data())).toList();
    } catch (e) {
      debugPrint("GeoService Error (States): $e");
      rethrow;
    }
  }

  Future<List<GeoItem>> getLGAs(String stateName) async {
    debugPrint("GeoService: Fetching LGAs for state: $stateName");
    try {
      var snapshot = await _firestore
          .collection('lgas')
          .where('state', isEqualTo: stateName)
          .orderBy('name')
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint("GeoService: No LGAs found for '$stateName', trying uppercase...");
        snapshot = await _firestore
            .collection('lgas')
            .where('state', isEqualTo: stateName.toUpperCase())
            .orderBy('name')
            .get();
      }

      debugPrint("GeoService: Found ${snapshot.docs.length} LGAs");
      return snapshot.docs.map((doc) => GeoItem.fromFirestore(doc.data())).toList();
    } catch (e) {
      debugPrint("------------------------------------------------------------------");
      debugPrint("FIRESTORE INDEX REQUIRED FOR LGAS:");
      debugPrint("$e");
      debugPrint("------------------------------------------------------------------");
      rethrow;
    }
  }

  Future<List<GeoItem>> getWards(String stateName, String lgaName) async {
    debugPrint("GeoService: Fetching Wards for $stateName, $lgaName");
    try {
      var snapshot = await _firestore
          .collection('wards')
          .where('state', isEqualTo: stateName)
          .where('lga', isEqualTo: lgaName)
          .orderBy('name')
          .get();
      
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('wards')
            .where('state', isEqualTo: stateName.toUpperCase())
            .where('lga', isEqualTo: lgaName.toUpperCase())
            .orderBy('name')
            .get();
      }

      debugPrint("GeoService: Found ${snapshot.docs.length} Wards");
      return snapshot.docs.map((doc) => GeoItem.fromFirestore(doc.data())).toList();
    } catch (e) {
      debugPrint("------------------------------------------------------------------");
      debugPrint("FIRESTORE INDEX REQUIRED FOR WARDS:");
      debugPrint("$e");
      debugPrint("------------------------------------------------------------------");
      rethrow;
    }
  }

  Future<List<PollingUnit>> getPollingUnits(String state, String lga, String ward) async {
    debugPrint("GeoService: Fetching units for $state, $lga, $ward");
    try {
      String searchLga = lga;
      if (lga == "Municipal Area Council") searchLga = "municipal";

      final originalWard = ward;
      final singleSpacedWard = ward.replaceAll(RegExp(r'\s+'), ' ').trim();
      final doubleSpacedWard = ward.replaceAll(RegExp(r'\s+'), '  ').trim();

      final wardVariations = [
        originalWard,
        originalWard.toLowerCase(),
        originalWard.toUpperCase(),
        singleSpacedWard,
        singleSpacedWard.toLowerCase(),
        singleSpacedWard.toUpperCase(),
        doubleSpacedWard,
        doubleSpacedWard.toLowerCase(),
        doubleSpacedWard.toUpperCase(),
      ].toSet().toList();

      final originalLga = searchLga;
      final singleSpacedLga = searchLga.replaceAll(RegExp(r'\s+'), ' ').trim();
      final doubleSpacedLga = searchLga.replaceAll(RegExp(r'\s+'), '  ').trim();

      final lgaVariations = [
        originalLga,
        originalLga.toLowerCase(),
        originalLga.toUpperCase(),
        singleSpacedLga,
        singleSpacedLga.toLowerCase(),
        singleSpacedLga.toUpperCase(),
        doubleSpacedLga,
        doubleSpacedLga.toLowerCase(),
        doubleSpacedLga.toUpperCase(),
      ].toSet().toList();

      final stateVariations = [
        state,
        state.toLowerCase(),
        state.toUpperCase(),
      ].toSet().toList();

      // Prioritize the strategies to try the most likely combinations first.
      List<Map<String, String>> strategies = [];
      
      // Phase 1: Try original spacing variations first
      for (var w in [originalWard, originalWard.toLowerCase(), originalWard.toUpperCase()]) {
        for (var l in [originalLga, originalLga.toLowerCase(), originalLga.toUpperCase()]) {
          for (var s in stateVariations) {
            strategies.add({'s': s, 'l': l, 'w': w});
          }
        }
      }

      // Phase 2: Try single-spaced variations
      for (var w in [singleSpacedWard, singleSpacedWard.toLowerCase(), singleSpacedWard.toUpperCase()]) {
        for (var l in [singleSpacedLga, singleSpacedLga.toLowerCase(), singleSpacedLga.toUpperCase()]) {
          for (var s in stateVariations) {
            strategies.add({'s': s, 'l': l, 'w': w});
          }
        }
      }

      // Phase 3: Try double-spaced variations
      for (var w in [doubleSpacedWard, doubleSpacedWard.toLowerCase(), doubleSpacedWard.toUpperCase()]) {
        for (var l in [doubleSpacedLga, doubleSpacedLga.toLowerCase(), doubleSpacedLga.toUpperCase()]) {
          for (var s in stateVariations) {
            strategies.add({'s': s, 'l': l, 'w': w});
          }
        }
      }

      // De-duplicate strategies list
      final seen = <String>{};
      final uniqueStrategies = <Map<String, String>>[];
      for (var strategy in strategies) {
        final key = "${strategy['s']}_${strategy['l']}_${strategy['w']}";
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueStrategies.add(strategy);
        }
      }

      debugPrint("GeoService: Generated ${uniqueStrategies.length} unique search strategies for polling units.");

      for (var strategy in uniqueStrategies) {
        debugPrint("GeoService: Trying Strategy: $strategy");
        var snapshot = await _firestore
            .collection('polling_units')
            .where('state', isEqualTo: strategy['s'])
            .where('lga', isEqualTo: strategy['l'])
            .where('ward', isEqualTo: strategy['w'])
            .orderBy('name')
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          debugPrint("GeoService: Found ${snapshot.docs.length} units using strategy: $strategy");
          return snapshot.docs.map((doc) => PollingUnit.fromFirestore(doc.data())).toList();
        }
      }
      
      debugPrint("GeoService: Found 0 units after all strategies.");
      return [];
    } catch (e) {
      debugPrint("------------------------------------------------------------------");
      debugPrint("FIRESTORE INDEX REQUIRED FOR POLLING UNITS:");
      debugPrint("$e");
      debugPrint("------------------------------------------------------------------");
      rethrow;
    }
  }
}

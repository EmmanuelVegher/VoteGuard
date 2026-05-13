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

      // Define strategies to try
      final strategies = [
        // Strategy 1: As per guide (Original State, Mapped LGA, Lower Ward)
        {'s': state, 'l': searchLga, 'w': ward.toLowerCase()},
        // Strategy 2: All Uppercase (Very common for Nigerian PU data)
        {'s': state.toUpperCase(), 'l': searchLga.toUpperCase(), 'w': ward.toUpperCase()},
        // Strategy 3: Mapped LGA Lowercased (Common discrepancy)
        {'s': state, 'l': searchLga.toLowerCase(), 'w': ward.toLowerCase()},
        // Strategy 4: Ward as displayed
        {'s': state, 'l': searchLga, 'w': ward},
      ];

      for (var strategy in strategies) {
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

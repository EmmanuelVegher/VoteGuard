import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voteguard/models/geo_models.dart';
import 'package:voteguard/services/neon_api_service.dart';

class GeoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-Memory Caches for instant responses (0ms)
  final Map<String, List<GeoItem>> _cacheStates = {};
  final Map<String, List<GeoItem>> _cacheLgas = {};
  final Map<String, List<GeoItem>> _cacheWards = {};
  final Map<String, List<PollingUnit>> _cachePus = {};

  Future<List<GeoItem>> getStates() async {
    if (_cacheStates.containsKey('all')) {
      return _cacheStates['all']!;
    }
    try {
      final apiStates = await NeonApiService.getGeoStates();
      if (apiStates.isNotEmpty) {
        final items = apiStates
            .map((name) => GeoItem(id: name.hashCode, name: name))
            .toList();
        _cacheStates['all'] = items;
        return items;
      }
    } catch (e) {
      debugPrint("GeoService API (States) notice: $e");
    }

    try {
      final snapshot =
          await _firestore.collection('states').orderBy('name').get();
      final items =
          snapshot.docs.map((doc) => GeoItem.fromFirestore(doc.data())).toList();
      _cacheStates['all'] = items;
      return items;
    } catch (e) {
      debugPrint("GeoService Error (States): $e");
      rethrow;
    }
  }

  Future<List<GeoItem>> getLGAs(String stateName) async {
    final cacheKey = stateName.toLowerCase().trim();
    if (_cacheLgas.containsKey(cacheKey)) {
      return _cacheLgas[cacheKey]!;
    }

    try {
      final apiLgas = await NeonApiService.getGeoLGAs(stateName);
      if (apiLgas.isNotEmpty) {
        final items = apiLgas
            .map((name) => GeoItem(id: name.hashCode, name: name))
            .toList();
        _cacheLgas[cacheKey] = items;
        return items;
      }
    } catch (e) {
      debugPrint("GeoService API (LGAs) notice: $e");
    }

    try {
      var snapshot = await _firestore
          .collection('lgas')
          .where('state', isEqualTo: stateName)
          .orderBy('name')
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('lgas')
            .where('state', isEqualTo: stateName.toUpperCase())
            .orderBy('name')
            .get();
      }

      final items =
          snapshot.docs.map((doc) => GeoItem.fromFirestore(doc.data())).toList();

      if (items.isEmpty) {
        final staticLgas = _getStaticLGAsForState(stateName);
        if (staticLgas.isNotEmpty) {
          final staticItems = staticLgas
              .map((name) => GeoItem(id: name.hashCode, name: name))
              .toList();
          _cacheLgas[cacheKey] = staticItems;
          return staticItems;
        }
      }

      _cacheLgas[cacheKey] = items;
      return items;
    } catch (e) {
      debugPrint("GeoService Error (LGAs): $e");
      final staticLgas = _getStaticLGAsForState(stateName);
      if (staticLgas.isNotEmpty) {
        final staticItems = staticLgas
            .map((name) => GeoItem(id: name.hashCode, name: name))
            .toList();
        _cacheLgas[cacheKey] = staticItems;
        return staticItems;
      }
      rethrow;
    }
  }

  Future<List<GeoItem>> getWards(String stateName, String lgaName) async {
    final cacheKey =
        "${stateName.toLowerCase().trim()}_${lgaName.toLowerCase().trim()}";
    if (_cacheWards.containsKey(cacheKey)) {
      return _cacheWards[cacheKey]!;
    }

    try {
      final apiWards = await NeonApiService.getGeoWards(stateName, lgaName);
      if (apiWards.isNotEmpty) {
        final items = apiWards
            .map((name) => GeoItem(id: name.hashCode, name: name))
            .toList();
        _cacheWards[cacheKey] = items;
        return items;
      }
    } catch (e) {
      debugPrint("GeoService API (Wards) notice: $e");
    }

    try {
      final lgaVariations = <String>{lgaName, lgaName.toLowerCase(), lgaName.toUpperCase()};
      if (lgaName.toLowerCase().contains('atakunmosa')) {
        lgaVariations.add(lgaName.replaceAll(RegExp(r'atakunmosa', caseSensitive: false), 'Atakumosa'));
        lgaVariations.add(lgaName.replaceAll(RegExp(r'atakunmosa', caseSensitive: false), 'atakumosa'));
        lgaVariations.add(lgaName.replaceAll(RegExp(r'atakunmosa', caseSensitive: false), 'ATAKUMOSA'));
      }
      if (lgaName.toLowerCase().contains('atakumosa')) {
        lgaVariations.add(lgaName.replaceAll(RegExp(r'atakumosa', caseSensitive: false), 'Atakunmosa'));
        lgaVariations.add(lgaName.replaceAll(RegExp(r'atakumosa', caseSensitive: false), 'atakunmosa'));
        lgaVariations.add(lgaName.replaceAll(RegExp(r'atakumosa', caseSensitive: false), 'ATAKUNMOSA'));
      }

      QuerySnapshot<Map<String, dynamic>>? snapshot;
      for (var lgaVar in lgaVariations) {
        var snap = await _firestore
            .collection('wards')
            .where('state', isEqualTo: stateName)
            .where('lga', isEqualTo: lgaVar)
            .orderBy('name')
            .get();
        if (snap.docs.isEmpty) {
          snap = await _firestore
              .collection('wards')
              .where('state', isEqualTo: stateName.toUpperCase())
              .where('lga', isEqualTo: lgaVar.toUpperCase())
              .orderBy('name')
              .get();
        }
        if (snap.docs.isNotEmpty) {
          snapshot = snap;
          break;
        }
      }

      final items = snapshot != null
          ? snapshot.docs.map((doc) => GeoItem.fromFirestore(doc.data())).toList()
          : <GeoItem>[];
      _cacheWards[cacheKey] = items;
      return items;
    } catch (e) {
      debugPrint("GeoService Error (Wards): $e");
      rethrow;
    }
  }

  Future<List<PollingUnit>> getPollingUnits(
      String state, String lga, String ward) async {
    final cacheKey =
        "${state.toLowerCase().trim()}_${lga.toLowerCase().trim()}_${ward.toLowerCase().trim()}";
    if (_cachePus.containsKey(cacheKey)) {
      return _cachePus[cacheKey]!;
    }

    debugPrint("GeoService: Fetching units for $state, $lga, $ward");

    // 1. Primary fast lookup: Express API Backend (includes full static lookup fallback)
    try {
      final apiPus = await NeonApiService.getGeoPollingUnits(state, lga, ward);
      if (apiPus.isNotEmpty) {
        final items = apiPus
            .map((name) => PollingUnit(
                  id: name.hashCode,
                  name: name,
                  pollingUnitId: name,
                  wardId: 0,
                  lgaId: 0,
                  stateId: 0,
                ))
            .toList();
        _cachePus[cacheKey] = items;
        debugPrint(
            "GeoService: Successfully fetched ${items.length} units via Express API backend");
        return items;
      }
    } catch (e) {
      debugPrint("GeoService API (Polling Units) notice: $e");
    }

    // 2. Parallelized Firestore Fallback
    try {
      String searchLga = lga;
      if (lga == "Municipal Area Council") searchLga = "municipal";

      final lgaVariations = <String>{
        searchLga,
        searchLga.toLowerCase(),
        searchLga.toUpperCase()
      };
      if (searchLga.toLowerCase().contains('atakunmosa')) {
        lgaVariations.add(searchLga.replaceAll(RegExp(r'atakunmosa', caseSensitive: false), 'Atakumosa'));
        lgaVariations.add(searchLga.replaceAll(RegExp(r'atakunmosa', caseSensitive: false), 'atakumosa'));
        lgaVariations.add(searchLga.replaceAll(RegExp(r'atakunmosa', caseSensitive: false), 'ATAKUMOSA'));
      }
      if (searchLga.toLowerCase().contains('atakumosa')) {
        lgaVariations.add(searchLga.replaceAll(RegExp(r'atakumosa', caseSensitive: false), 'Atakunmosa'));
        lgaVariations.add(searchLga.replaceAll(RegExp(r'atakumosa', caseSensitive: false), 'atakunmosa'));
        lgaVariations.add(searchLga.replaceAll(RegExp(r'atakumosa', caseSensitive: false), 'ATAKUNMOSA'));
      }

      final originalWard = ward;
      final singleSpacedWard = ward.replaceAll(RegExp(r'\s+'), ' ').trim();
      final doubleSpacedWard = ward.replaceAll(RegExp(r'\s+'), '  ').trim();

      final stateVariations =
          {state, state.toLowerCase(), state.toUpperCase()}.toList();

      List<Map<String, String>> strategies = [];

      for (var w in [
        originalWard,
        originalWard.toLowerCase(),
        originalWard.toUpperCase(),
        singleSpacedWard,
        doubleSpacedWard
      ]) {
        for (var l in lgaVariations) {
          for (var s in stateVariations) {
            strategies.add({'s': s, 'l': l, 'w': w});
          }
        }
      }

      final seen = <String>{};
      final uniqueStrategies = <Map<String, String>>[];
      for (var strategy in strategies) {
        final key = "${strategy['s']}_${strategy['l']}_${strategy['w']}";
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueStrategies.add(strategy);
        }
      }

      // Execute queries in PARALLEL batches
      final futures = uniqueStrategies.map((strategy) {
        return _firestore
            .collection('polling_units')
            .where('state', isEqualTo: strategy['s'])
            .where('lga', isEqualTo: strategy['l'])
            .where('ward', isEqualTo: strategy['w'])
            .orderBy('name')
            .get()
            .then<QuerySnapshot<Map<String, dynamic>>?>((snap) => snap)
            .catchError((_) => null);
      });

      final snapshots = await Future.wait(futures);
      for (var snapshot in snapshots) {
        if (snapshot != null && snapshot.docs.isNotEmpty) {
          final items = snapshot.docs
              .map((doc) => PollingUnit.fromFirestore(doc.data()))
              .toList();
          _cachePus[cacheKey] = items;
          debugPrint(
              "GeoService: Found ${items.length} units in Firestore parallel fallback");
          return items;
        }
      }

      // Stage 3 Fallback: State-level query with super-normalization matching
      try {
        final String superNormLgaTarget = lga.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').replaceAll('n', 'm');
        final String superNormWardTarget = ward
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '')
            .replaceAll(RegExp(r'^ward0+'), 'ward')
            .replaceAll('ward', '')
            .replaceAll(RegExp(r'^0+'), '');

        for (var s in stateVariations) {
          final stateSnap = await _firestore
              .collection('polling_units')
              .where('state', isEqualTo: s)
              .get();
          if (stateSnap.docs.isNotEmpty) {
            final matchedDocs = stateSnap.docs.where((doc) {
              final data = doc.data();
              final docLga = (data['lga'] ?? data['lgaName'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').replaceAll('n', 'm');
              final docWard = (data['ward'] ?? data['wardName'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').replaceAll(RegExp(r'^ward0+'), 'ward').replaceAll('ward', '').replaceAll(RegExp(r'^0+'), '');
              
              final lgaMatch = docLga.isEmpty || docLga == superNormLgaTarget || docLga.contains(superNormLgaTarget) || superNormLgaTarget.contains(docLga);
              final wardMatch = docWard == superNormWardTarget || docWard.contains(superNormWardTarget) || superNormWardTarget.contains(docWard);
              return lgaMatch && wardMatch;
            }).toList();

            if (matchedDocs.isNotEmpty) {
              final items = matchedDocs
                  .map((doc) => PollingUnit.fromFirestore(doc.data()))
                  .toList();
              _cachePus[cacheKey] = items;
              debugPrint("GeoService: Found ${items.length} units in state-wide fallback matcher");
              return items;
            }
          }
        }
      } catch (fallbackErr) {
        debugPrint("GeoService Stage 3 fallback warning: $fallbackErr");
      }

      // Stage 4 Fallback: Local Static Polling Units Fallback
      final staticPus = _getStaticPollingUnits(state, lga, ward);
      if (staticPus.isNotEmpty) {
        final items = staticPus
            .map((name) => PollingUnit(
                  id: name.hashCode,
                  name: name,
                  pollingUnitId: name,
                  wardId: 0,
                  lgaId: 0,
                  stateId: 0,
                ))
            .toList();
        _cachePus[cacheKey] = items;
        debugPrint(
            "GeoService: Found ${items.length} units in local static fallback");
        return items;
      }

      return [];
    } catch (e) {
      debugPrint("GeoService Error (Polling Units): $e");
      rethrow;
    }
  }

  List<String> _getStaticPollingUnits(String state, String lga, String ward) {
    final sNorm = state.toLowerCase().trim();
    final lNorm = lga.toLowerCase().trim();
    final wNorm = ward.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (sNorm == 'osun') {
      if (lNorm.contains('atakunmosa') || lNorm.contains('atakumosa')) {
        if (wNorm.contains('okebode') || wNorm.contains('bode')) {
          return [
            "OJU OJA OKEBODE",
            "ST. JOHN PRY. SCHOOL, OKE-BODE",
            "ABEBEYUN/ISEDO PRY. SCHOL",
            "OKE-OSIN PRY. SCHOOL",
            "L.A. PRY. SCHOOL, KAJOLA",
            "ARAROMI KAJOLA",
            "LAALA VILLAGE",
            "ASIPA/SALORO",
            "L.A. PRY. SCHOOL, GIDIGBI",
            "MATERNITY CENTRE, OSUNJELA",
            "OPEN SPACE IN FRONT ETISALAT MAST"
          ];
        } else if (wNorm.contains('muroko')) {
          return [
            "ST. JAMES PRY. SCHOOL, ILAA",
            "L.A. SCHOOL, ISOLO",
            "ILOYA VILLAGE",
            "IPOYE VILLAGE",
            "ESIRA VILLAGE"
          ];
        } else if (wNorm.contains('ifewarai') && !wNorm.contains('ii')) {
          return [
            "TOWN HALL, IFEWARA",
            "OGOGODOJA VILLAGE",
            "AGBABIAKA VILLAGE",
            "N. U. D. PRY. SCHOOL, IFEWARA",
            "OPEN SPACE, INFRONT OF ADIMULA HALL"
          ];
        } else if (wNorm.contains('ifewaraii') || wNorm.contains('ifewara2')) {
          return [
            "ST. DOMINIC PRY. SCHOOL, IFEWARA",
            "IFEWARA HIGH SCHOOL I",
            "IFEWARA HIGH SCHOOL II",
            "ABA ORUNTO",
            "MATERNITY IFEWARA"
          ];
        } else if (wNorm.contains('ifelodun')) {
          return [
            "EPE VILLAGE",
            "IJANA VILLAGE",
            "ODO IJU VILLAGE",
            "IYEMOGUN VILLAGE",
            "METHODIST PRY. SCHOOL, IGUN",
            "APEPE VILLAGE"
          ];
        } else if (wNorm.contains('osui') && !wNorm.contains('ii') && !wNorm.contains('iii')) {
          return [
            "METHODIST PRIMARY SCHOOL, OKE OJA - OSU",
            "C & S PRY.SCHOOL, OSU (OPPOSITE HM'S OFFICE)",
            "ARUAJI, OSU",
            "ATAKUNMOSA HIGH SCHOOL, OSU"
          ];
        } else if (wNorm.contains('osuii') && !wNorm.contains('iii')) {
          return [
            "APOSTOLIC PRY SCHOOL, IWARO",
            "PRY SCHOOL, ILOBA",
            "BARA VILLAGE",
            "PRY SCHOOL, ALAKOWE",
            "AYORUNBO VILLAGE",
            "ODESOMI VILLAGE",
            "PRY SCHOOL, SASA",
            "R.C.M. PRY. SCHOOL, KAJOLA",
            "COMM. PRY. SCHOOL, ASAOBI",
            "BALOGUN VILLAGE",
            "KANYE VILLAGE"
          ];
        } else if (wNorm.contains('ibodi')) {
          return [
            "COMM. GRAMMAR SCHOOL, IBODI",
            "TEMIDIRE PRY. SCHOOL, IBODI",
            "IGILA VILLAGE",
            "IYERE VILLAGE",
            "OSUN STATE COLL. OF EDUCATION",
            "ILOTIN VILLAGE",
            "OPEN SPACE, BEHIND TRANSFORMER, ITAMERIN AREA, IBODI",
            "OPEN SPACE, INFRONT OF WHITE HOUSE, ODO OJA"
          ];
        } else if (wNorm.contains('osuiii') || wNorm.contains('osu3')) {
          return [
            "METHODIST PRY. SCHOOL, OKEOMI, OSU",
            "METHODIST PRY. SCHOOL, OSU",
            "L.A. PRY. SCHOOL, ILOWO ST. OSU",
            "PRY. SCHOOL, ITAMERIN",
            "COMM. GRAMMAR SCHOOL, AJIDO, OSU",
            "OPEN SPACE, INFRONT OF MISSION'S HOUSE, OSU",
            "OPEN SPACE, INFRONT AGUNJA JUNCTION, OSU"
          ];
        } else if (wNorm.contains('itagunmodi')) {
          return [
            "TOWN HALL, ITAGUNMODI  I",
            "TOWN HALL, ITAGUNMODI II",
            "ALABA/OWENA VILLAGE (OPEN SPACE)",
            "ARAROMI VILLAGE",
            "OKE IPA VILLAGE (OPEN SPACE)",
            "ARIGBABU VILLAGE (OPEN SPACE)"
          ];
        } else if (wNorm.contains('isaobi') || wNorm.contains('obi')) {
          return [
            "ISAOBI PRY. SCHOOL,",
            "INASIN VILLAGE",
            "RISAWE VILLAGE",
            "ITAOSAN VILLAGE"
          ];
        }
      }
    }
    return [];
  }

  List<String> _getStaticLGAsForState(String stateName) {
    final Map<String, List<String>> mapping = {
      "Abia": ["Aba North", "Aba South", "Arochukwu", "Bende", "Ikwuano", "Isiala Ngwa North", "Isiala Ngwa South", "Isiukwuato", "Obingwa", "Ohafia", "Osisioma Ngwa", "Ugwunagbo", "Ukwa East", "Ukwa West", "Umuahia North", "Umuahia South", "Umunneochi"],
      "Adamawa": ["Demsa", "Fufore", "Ganye", "Girei", "Gombi", "Guyuk", "Hong", "Jada", "Lamurde", "Madagali", "Maiha", "Mayo-Belwa", "Michika", "Mubi North", "Mubi South", "Numan", "Shelleng", "Song", "Toungo", "Yola North", "Yola South"],
      "Akwa Ibom": ["Abak", "Eastern Obolo", "Eket", "Esit-Eket", "Essien Udim", "Etim-Ekpo", "Etinan", "Ibeno", "Ibesikpo-Asutan", "Ibiono-Ibom", "Ika", "Ikono", "Ikot Abasi", "Ikot Ekpene", "Ini", "Itu", "Mbo", "Mkpat-Enin", "Nsit-Atai", "Nsit-Ibom", "Nsit-Ubium", "Obot Akara", "Okobo", "Onna", "Oron", "Oruk Anam", "Udung-Uko", "Ukanafun", "Uruan", "Urue-Offong/Oruko", "Uyo"],
      "Anambra": ["Aguata", "Anambra East", "Anambra West", "Anaocha", "Awka North", "Awka South", "Ayamelum", "Dunukofia", "Ekwusigo", "Idemili North", "Idemili South", "Ihiala", "Njikoka", "Nnewi North", "Nnewi South", "Ogbaru", "Onitsha North", "Onitsha South", "Orumba North", "Orumba South", "Oyi"],
      "Bauchi": ["Alkaleri", "Bauchi", "Bogoro", "Damban", "Darazo", "Dass", "Gamawa", "Ganjuwa", "Giade", "Itas/Gadau", "Jama'are", "Katagum", "Kirfi", "Misau", "Ningi", "Shira", "Tafawa Balewa", "Toro", "Warji", "Zaki"],
      "Bayelsa": ["Brass", "Ekeremor", "Kolokuma/Opokuma", "Nembe", "Ogbia", "Sagbama", "Southern Ijaw", "Yenagoa"],
      "Benue": ["Ado", "Agatu", "Apa", "Buruku", "Gboko", "Guma", "Gwer East", "Gwer West", "Katsina-Ala", "Konshisha", "Kwande", "Logo", "Makurdi", "Obi", "Ogbadibo", "Ohimini", "Oju", "Okpokwu", "Otukpo", "Tarka", "Ukum", "Ushongo", "Vandeikya"],
      "Borno": ["Abadam", "Askira/Uba", "Bama", "Bayo", "Biu", "Chibok", "Damboa", "Dikwa", "Gubio", "Guzamala", "Gwoza", "Hawul", "Jere", "Kaga", "Kala/Balge", "Konduga", "Kukawa", "Kwaya Kusar", "Mafa", "Magumeri", "Maiduguri", "Marte", "Mobbar", "Monguno", "Ngala", "Nganzai", "Shani"],
      "Cross River": ["Abi", "Akamkpa", "Akpabuyo", "Bakassi", "Bekwarra", "Biase", "Boki", "Calabar Municipal", "Calabar South", "Etung", "Ikom", "Obanliku", "Obubra", "Obudu", "Odukpani", "Ogoja", "Yakuur", "Yala"],
      "Delta": ["Aniocha North", "Aniocha South", "Bomadi", "Burutu", "Ethiope East", "Ethiope West", "Ika North East", "Ika South", "Isoko North", "Isoko South", "Ndokwa East", "Ndokwa West", "Okpe", "Oshimili North", "Oshimili South", "Patani", "Sapele", "Udu", "Ughelli North", "Ughelli South", "Ukwuani", "Uvwie", "Warri North", "Warri South", "Warri South West"],
      "Ebonyi": ["Abakaliki", "Afikpo North", "Afikpo South", "Ebonyi", "Ezza North", "Ezza South", "Ikwo", "Ishielu", "Ivo", "Izzi", "Ohaozara", "Ohaukwu", "Onicha"],
      "Edo": ["Akoko-Edo", "Egor", "Esan Central", "Esan North-East", "Esan South-East", "Esan West", "Etsako Central", "Etsako East", "Etsako West", "Igueben", "Ikpoba-Okha", "Oredo", "Orhionmwon", "Ovia North-East", "Ovia South-West", "Owan East", "Owan West", "Uhunmwonde"],
      "Ekiti": ["Ado-Ekiti", "Efon", "Ekiti East", "Ekiti South-West", "Ekiti West", "Emure", "Gbonyin", "Ido-Osi", "Ijero", "Ikere", "Ikole", "Ilejemeje", "Irepodun/Ifelodun", "Ise/Orun", "Moba", "Oye"],
      "Enugu": ["Aninri", "Awgu", "Enugu East", "Enugu North", "Enugu South", "Ezeagu", "Igbo Etiti", "Igbo Eze North", "Igbo Eze South", "Isi Uzo", "Nkanu East", "Nkanu West", "Nsukka", "Oji River", "Udenu", "Udi", "Uzo-Uwani"],
      "FCT": ["Abaji", "Bwari", "Gwagwalada", "Kuje", "Municipal Area Council", "Kwali"],
      "Gombe": ["Akko", "Balanga", "Billiri", "Dukku", "Funakaye", "Gombe", "Kaltungo", "Kwami", "Nafada", "Shongom", "Yamaltu/Deba"],
      "Imo": ["Aboh Mbaise", "Ahiazu Mbaise", "Ehime Mbano", "Ezinihitte", "Ideato North", "Ideato South", "Ihitte/Uboma", "Ikeduru", "Isiala Mbano", "Isu", "Mbaitoli", "Ngor Okpala", "Njaba", "Nkwerre", "Nwangele", "Obowo", "Oguta", "Ohaji/Egbema", "Okigwe", "Onuimo", "Orlu", "Orsu", "Oru East", "Oru West", "Owerri Municipal", "Owerri North", "Owerri West"],
      "Jigawa": ["Auyo", "Babura", "Biriniwa", "Birnin Kudu", "Buji", "Dutse", "Gagarawa", "Garki", "Gumel", "Guri", "Gwaram", "Gwiwa", "Hadejia", "Jahun", "Kafin Hausa", "Kaugama", "Kazaure", "Kirikasamma", "Kiyawa", "Maigatari", "Malam Madori", "Miga", "Ringim", "Roni", "Sule Tankarkar", "Taura", "Yankwashi"],
      "Kaduna": ["Birnin Gwari", "Chikun", "Giwa", "Igabi", "Ikara", "Jaba", "Jema'a", "Kachia", "Kaduna North", "Kaduna South", "Kagarko", "Kajuru", "Kaura", "Kauru", "Kubau", "Kudan", "Lere", "Makarfi", "Sabon Gari", "Sanga", "Soba", "Zangon Kataf", "Zaria"],
      "Kano": ["Ajingi", "Albasu", "Bagwai", "Bebeji", "Bichi", "Bunkure", "Dala", "Dambatta", "Dawakin Kudu", "Dawakin Tofa", "Doguwa", "Fagge", "Gabasawa", "Garko", "Garun Mallam", "Gaya", "Gezawa", "Gwale", "Gwarzo", "Kabo", "Kano Municipal", "Karaye", "Kibiya", "Kiru", "Kumbotso", "Kunchi", "Kura", "Madobi", "Makoda", "Minjibir", "Nasarawa", "Rano", "Rimin Gado", "Rogo", "Shanono", "Sumaila", "Takai", "Tarauni", "Tofa", "Tsanyawa", "Tudun Wada", "Ungogo", "Warawa", "Wudil"],
      "Katsina": ["Bakori", "Batagarawa", "Batsari", "Baure", "Bindawa", "Charanchi", "Dandume", "Danja", "Dan Musa", "Daura", "Dutsi", "Dutsin Ma", "Faskari", "Funtua", "Ingawa", "Jibia", "Kafur", "Kaita", "Kankara", "Kankia", "Katsina", "Kurfi", "Kusada", "Mai'Adua", "Malumfashi", "Mani", "Mashi", "Matazu", "Musawa", "Rimi", "Sabuwa", "Safana", "Sandamu", "Zango"],
      "Kebbi": ["Aleiro", "Arewa Dandi", "Argungu", "Augie", "Bagudo", "Birnin Kebbi", "Bunza", "Dandi", "Fakai", "Gwandu", "Jega", "Kalgo", "Koko/Besse", "Maiyama", "Ngaski", "Sakaba", "Shanga", "Suru", "Wasagu/Danko", "Yauri", "Zuru"],
      "Kogi": ["Adavi", "Ajaokuta", "Ankpa", "Bassa", "Dekina", "Ibaji", "Idah", "Igalamela Odolu", "Ijumu", "Kabba/Bunu", "Kogi", "Lokoja", "Mopa Muro", "Ofu", "Ogori/Magongo", "Okehi", "Okene", "Olamaboro", "Omala", "Yagba East", "Yagba West"],
      "Kwara": ["Asa", "Baruten", "Edu", "Ekiti", "Ifelodun", "Ilorin East", "Ilorin South", "Ilorin West", "Irepodun", "Isin", "Kaiama", "Moro", "Offa", "Oke Ero", "Oyun", "Pategi"],
      "Lagos": ["Agege", "Ajeromi-Ifelodun", "Alimosho", "Amuwo-Odofin", "Apapa", "Badagry", "Epe", "Eti-Osa", "Ibeju-Lekki", "Ifako-Ijaiye", "Ikeja", "Ikorodu", "Kosofe", "Lagos Island", "Lagos Mainland", "Mushin", "Ojo", "Oshodi-Isolo", "Shomolu", "Surulere"],
      "Nasarawa": ["Akwanga", "Awe", "Doma", "Karu", "Keana", "Keffi", "Kokona", "Lafia", "Nasarawa", "Nasarawa Egon", "Obi", "Toto", "Wamba"],
      "Niger": ["Agaie", "Agwara", "Bida", "Borgu", "Bosso", "Chanchaga", "Edati", "Gbako", "Gurara", "Katcha", "Kontagora", "Lapai", "Lavun", "Magama", "Mariga", "Mashegu", "Mokwa", "Moya", "Paikoro", "Rafi", "Rijau", "Shiroro", "Suleja", "Tafa", "Wushishi"],
      "Ogun": ["Abeokuta North", "Abeokuta South", "Ado-Odo/Ota", "Egbado North", "Egbado South", "Ewekoro", "Ifo", "Ijebu East", "Ijebu North", "Ijebu North East", "Ijebu Ode", "Ikenne", "Imeko Afon", "Ipokia", "Obafemi Owode", "Odeda", "Odogbolu", "Ogun Waterside", "Remo North", "Shagamu"],
      "Ondo": ["Akoko North-East", "Akoko North-West", "Akoko South-West", "Akoko South-East", "Akure North", "Akure South", "Ese Odo", "Idanre", "Ifedore", "Ilaje", "Ile Oluji/Okeigbo", "Irele", "Odigbo", "Okitipupa", "Ondo East", "Ondo West", "Ose", "Owo"],
      "Osun": ["Atakunmosa East", "Atakunmosa West", "Aiyedaade", "Aiyedire", "Boluwaduro", "Boripe", "Ede North", "Ede South", "Egbedore", "Ejigbo", "Ife Central", "Ife East", "Ife North", "Ife South", "Ifedayo", "Ifelodun", "Ila", "Ilesa East", "Ilesa West", "Irepodun", "Irewole", "Isokan", "Iwo", "Obokun", "Odo Otin", "Ola Oluwa", "Olorunda", "Oriade", "Orolu", "Osogbo"],
      "Oyo": ["Afijio", "Akinyele", "Atiba", "Atisbo", "Egbeda", "Ibadan North", "Ibadan North-East", "Ibadan North-West", "Ibadan South-East", "Ibadan South-West", "Ibarapa Central", "Ibarapa East", "Ibarapa North", "Ido", "Irepo", "Iseyin", "Itesiwaju", "Iwajowa", "Kajola", "Lagelu", "Ogbomoso North", "Ogbomoso South", "Ogo Oluwa", "Olorunsogo", "Oluyole", "Ona Ara", "Orelope", "Ori Ire", "Oyo East", "Oyo West", "Saki East", "Saki West", "Surulere"],
      "Plateau": ["Barkin Ladi", "Bassa", "Bokkos", "Jos East", "Jos North", "Jos South", "Kanam", "Kanke", "Langtang North", "Langtang South", "Mangu", "Mikang", "Pankshin", "Qua'an Pan", "Riyom", "Shendam", "Wase"],
      "Rivers": ["Abua/Odual", "Ahoada East", "Ahoada West", "Akuku-Toru", "Andoni", "Asari-Toru", "Bonny", "Degema", "Eleme", "Emuoha", "Etche", "Gokana", "Ikwerre", "Khana", "Obio/Akpor", "Ogba/Egbema/Ndoni", "Ogu/Bolo", "Okrika", "Omuma", "Opobo/Nkoro", "Oyigbo", "Port Harcourt", "Tai"],
      "Sokoto": ["Binji", "Bodinga", "Dange Shuni", "Gada", "Goronyo", "Gudu", "Gwadabawa", "Illela", "Isa", "Kebbe", "Kware", "Rabah", "Sabon Birni", "Shagari", "Silame", "Sokoto North", "Sokoto South", "Tambuwal", "Tangaza", "Tureta", "Wamako", "Wurno", "Yabo"],
      "Taraba": ["Ardo Kola", "Bali", "Donga", "Gashaka", "Gassol", "Ibi", "Jalingo", "Karim Lamido", "Kurmi", "Lau", "Sardauna", "Takum", "Ussa", "Wukari", "Yorro", "Zing"],
      "Yobe": ["Bade", "Bursari", "Damaturu", "Fika", "Fune", "Geidam", "Gujba", "Gulani", "Jakusko", "Karasuwa", "Machina", "Nangere", "Nguru", "Potiskum", "Tarmuwa", "Yunusari", "Yusufari"],
      "Zamfara": ["Anka", "Bakura", "Birnin Magaji/Kiyaw", "Bukkuyum", "Bungudu", "Gummi", "Gusau", "Kaura Namoda", "Maradun", "Maru", "Shinkafi", "Talata Mafara", "Chafe", "Zurmi"]
    };

    final key = mapping.keys.firstWhere(
      (k) => k.toLowerCase() == stateName.toLowerCase().trim(),
      orElse: () => '',
    );
    return key.isNotEmpty ? mapping[key]! : <String>[];
  }
}

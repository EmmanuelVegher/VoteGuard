import 'package:cloud_firestore/cloud_firestore.dart';

class Election {
  final String id;
  final String name;
  final String type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String? description;
  final List<String> states;
  final List<String> lgas;
  final List<String> wards;
  final List<String> senatorialDistricts;
  final String? primaryParty;
  final String? primaryElectionType;
  final List<Map<String, dynamic>> aspirants;

  Election({
    required this.id,
    required this.name,
    required this.type,
    this.startDate,
    this.endDate,
    required this.status,
    this.description,
    this.states = const [],
    this.lgas = const [],
    this.wards = const [],
    this.senatorialDistricts = const [],
    this.primaryParty,
    this.primaryElectionType,
    this.aspirants = const [],
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Election.fromFirestore(Map<String, dynamic> data, String id) {
    final stateList = data['state'] ?? data['states'] ?? data['targetStates'] ?? data['region'] ?? data['regions'] ?? data['targetJurisdictions'];
    final lgaList = data['lga'] ?? data['lgas'] ?? data['targetLgas'];
    final wardList = data['ward'] ?? data['wards'] ?? data['targetWards'];
    final senatorialDistList = data['senatorialDistricts'] ?? data['senatorialDistrict'] ?? [];
    final aspirantsList = data['aspirants'] ?? [];

    return Election(
      id: id,
      name: data['name'] ?? 'Unknown Election',
      type: data['type'] ?? 'GENERAL',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      status: data['status'] ?? 'UPCOMING',
      description: data['description'],
      states: (stateList is List) ? stateList.map((e) => e.toString()).toList() : [],
      lgas: (lgaList is List) ? lgaList.map((e) => e.toString()).toList() : [],
      wards: (wardList is List) ? wardList.map((e) => e.toString()).toList() : [],
      senatorialDistricts: (senatorialDistList is List) ? senatorialDistList.map((e) => e.toString()).toList() : [],
      primaryParty: data['primaryParty']?.toString(),
      primaryElectionType: data['primaryElectionType']?.toString(),
      aspirants: (aspirantsList is List) ? aspirantsList.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [],
    );
  }
}

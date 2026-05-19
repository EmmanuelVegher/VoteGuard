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
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Election.fromFirestore(Map<String, dynamic> data, String id) {
    final stateList = data['state'] ?? data['states'] ?? data['targetStates'] ?? data['regions'] ?? data['region'] ?? data['targetJurisdictions'];
    final lgaList = data['lga'] ?? data['lgas'] ?? data['targetLgas'];
    final wardList = data['ward'] ?? data['wards'] ?? data['targetWards'];

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
    );
  }
}

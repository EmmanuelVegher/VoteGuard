import 'package:cloud_firestore/cloud_firestore.dart';

class Election {
  final String id;
  final String name;
  final String type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String? description;

  Election({
    required this.id,
    required this.name,
    required this.type,
    this.startDate,
    this.endDate,
    required this.status,
    this.description,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Election.fromFirestore(Map<String, dynamic> data, String id) {
    return Election(
      id: id,
      name: data['name'] ?? 'Unknown Election',
      type: data['type'] ?? 'GENERAL',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      status: data['status'] ?? 'UPCOMING',
      description: data['description'],
    );
  }
}

class GeoItem {
  final int id;
  final String name;

  GeoItem({required this.id, required this.name});

  factory GeoItem.fromFirestore(Map<String, dynamic> data) {
    return GeoItem(
      id: data['id'] ?? 0,
      name: data['name'] ?? '',
    );
  }
}

class PollingUnit extends GeoItem {
  final String pollingUnitId;
  final int wardId;
  final int lgaId;
  final int stateId;

  PollingUnit({
    required super.id,
    required super.name,
    required this.pollingUnitId,
    required this.wardId,
    required this.lgaId,
    required this.stateId,
  });

  factory PollingUnit.fromFirestore(Map<String, dynamic> data) {
    return PollingUnit(
      id: data['id'] ?? 0,
      name: (data['name'] ?? '').toString().toUpperCase(),
      pollingUnitId: data['pollingUnitId'] ?? '',
      wardId: data['wardId'] ?? 0,
      lgaId: data['lgaId'] ?? 0,
      stateId: data['stateId'] ?? 0,
    );
  }
}

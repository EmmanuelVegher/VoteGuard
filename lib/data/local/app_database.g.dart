// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ResultsTable extends Results with TableInfo<$ResultsTable, Result> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _observerIdMeta =
      const VerificationMeta('observerId');
  @override
  late final GeneratedColumn<String> observerId = GeneratedColumn<String>(
      'observer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pollingUnitIdMeta =
      const VerificationMeta('pollingUnitId');
  @override
  late final GeneratedColumn<String> pollingUnitId = GeneratedColumn<String>(
      'polling_unit_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _partyVotesJsonMeta =
      const VerificationMeta('partyVotesJson');
  @override
  late final GeneratedColumn<String> partyVotesJson = GeneratedColumn<String>(
      'party_votes_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ballotStatsJsonMeta =
      const VerificationMeta('ballotStatsJson');
  @override
  late final GeneratedColumn<String> ballotStatsJson = GeneratedColumn<String>(
      'ballot_stats_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        observerId,
        pollingUnitId,
        partyVotesJson,
        ballotStatsJson,
        imagePath,
        createdAt,
        isSynced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results';
  @override
  VerificationContext validateIntegrity(Insertable<Result> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('observer_id')) {
      context.handle(
          _observerIdMeta,
          observerId.isAcceptableOrUnknown(
              data['observer_id']!, _observerIdMeta));
    } else if (isInserting) {
      context.missing(_observerIdMeta);
    }
    if (data.containsKey('polling_unit_id')) {
      context.handle(
          _pollingUnitIdMeta,
          pollingUnitId.isAcceptableOrUnknown(
              data['polling_unit_id']!, _pollingUnitIdMeta));
    } else if (isInserting) {
      context.missing(_pollingUnitIdMeta);
    }
    if (data.containsKey('party_votes_json')) {
      context.handle(
          _partyVotesJsonMeta,
          partyVotesJson.isAcceptableOrUnknown(
              data['party_votes_json']!, _partyVotesJsonMeta));
    } else if (isInserting) {
      context.missing(_partyVotesJsonMeta);
    }
    if (data.containsKey('ballot_stats_json')) {
      context.handle(
          _ballotStatsJsonMeta,
          ballotStatsJson.isAcceptableOrUnknown(
              data['ballot_stats_json']!, _ballotStatsJsonMeta));
    } else if (isInserting) {
      context.missing(_ballotStatsJsonMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Result map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Result(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      observerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}observer_id'])!,
      pollingUnitId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}polling_unit_id'])!,
      partyVotesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}party_votes_json'])!,
      ballotStatsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}ballot_stats_json'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $ResultsTable createAlias(String alias) {
    return $ResultsTable(attachedDatabase, alias);
  }
}

class Result extends DataClass implements Insertable<Result> {
  final int id;
  final String observerId;
  final String pollingUnitId;
  final String partyVotesJson;
  final String ballotStatsJson;
  final String? imagePath;
  final DateTime createdAt;
  final bool isSynced;
  const Result(
      {required this.id,
      required this.observerId,
      required this.pollingUnitId,
      required this.partyVotesJson,
      required this.ballotStatsJson,
      this.imagePath,
      required this.createdAt,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['observer_id'] = Variable<String>(observerId);
    map['polling_unit_id'] = Variable<String>(pollingUnitId);
    map['party_votes_json'] = Variable<String>(partyVotesJson);
    map['ballot_stats_json'] = Variable<String>(ballotStatsJson);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  ResultsCompanion toCompanion(bool nullToAbsent) {
    return ResultsCompanion(
      id: Value(id),
      observerId: Value(observerId),
      pollingUnitId: Value(pollingUnitId),
      partyVotesJson: Value(partyVotesJson),
      ballotStatsJson: Value(ballotStatsJson),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      createdAt: Value(createdAt),
      isSynced: Value(isSynced),
    );
  }

  factory Result.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Result(
      id: serializer.fromJson<int>(json['id']),
      observerId: serializer.fromJson<String>(json['observerId']),
      pollingUnitId: serializer.fromJson<String>(json['pollingUnitId']),
      partyVotesJson: serializer.fromJson<String>(json['partyVotesJson']),
      ballotStatsJson: serializer.fromJson<String>(json['ballotStatsJson']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'observerId': serializer.toJson<String>(observerId),
      'pollingUnitId': serializer.toJson<String>(pollingUnitId),
      'partyVotesJson': serializer.toJson<String>(partyVotesJson),
      'ballotStatsJson': serializer.toJson<String>(ballotStatsJson),
      'imagePath': serializer.toJson<String?>(imagePath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  Result copyWith(
          {int? id,
          String? observerId,
          String? pollingUnitId,
          String? partyVotesJson,
          String? ballotStatsJson,
          Value<String?> imagePath = const Value.absent(),
          DateTime? createdAt,
          bool? isSynced}) =>
      Result(
        id: id ?? this.id,
        observerId: observerId ?? this.observerId,
        pollingUnitId: pollingUnitId ?? this.pollingUnitId,
        partyVotesJson: partyVotesJson ?? this.partyVotesJson,
        ballotStatsJson: ballotStatsJson ?? this.ballotStatsJson,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        createdAt: createdAt ?? this.createdAt,
        isSynced: isSynced ?? this.isSynced,
      );
  Result copyWithCompanion(ResultsCompanion data) {
    return Result(
      id: data.id.present ? data.id.value : this.id,
      observerId:
          data.observerId.present ? data.observerId.value : this.observerId,
      pollingUnitId: data.pollingUnitId.present
          ? data.pollingUnitId.value
          : this.pollingUnitId,
      partyVotesJson: data.partyVotesJson.present
          ? data.partyVotesJson.value
          : this.partyVotesJson,
      ballotStatsJson: data.ballotStatsJson.present
          ? data.ballotStatsJson.value
          : this.ballotStatsJson,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Result(')
          ..write('id: $id, ')
          ..write('observerId: $observerId, ')
          ..write('pollingUnitId: $pollingUnitId, ')
          ..write('partyVotesJson: $partyVotesJson, ')
          ..write('ballotStatsJson: $ballotStatsJson, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, observerId, pollingUnitId, partyVotesJson,
      ballotStatsJson, imagePath, createdAt, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Result &&
          other.id == this.id &&
          other.observerId == this.observerId &&
          other.pollingUnitId == this.pollingUnitId &&
          other.partyVotesJson == this.partyVotesJson &&
          other.ballotStatsJson == this.ballotStatsJson &&
          other.imagePath == this.imagePath &&
          other.createdAt == this.createdAt &&
          other.isSynced == this.isSynced);
}

class ResultsCompanion extends UpdateCompanion<Result> {
  final Value<int> id;
  final Value<String> observerId;
  final Value<String> pollingUnitId;
  final Value<String> partyVotesJson;
  final Value<String> ballotStatsJson;
  final Value<String?> imagePath;
  final Value<DateTime> createdAt;
  final Value<bool> isSynced;
  const ResultsCompanion({
    this.id = const Value.absent(),
    this.observerId = const Value.absent(),
    this.pollingUnitId = const Value.absent(),
    this.partyVotesJson = const Value.absent(),
    this.ballotStatsJson = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  ResultsCompanion.insert({
    this.id = const Value.absent(),
    required String observerId,
    required String pollingUnitId,
    required String partyVotesJson,
    required String ballotStatsJson,
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  })  : observerId = Value(observerId),
        pollingUnitId = Value(pollingUnitId),
        partyVotesJson = Value(partyVotesJson),
        ballotStatsJson = Value(ballotStatsJson);
  static Insertable<Result> custom({
    Expression<int>? id,
    Expression<String>? observerId,
    Expression<String>? pollingUnitId,
    Expression<String>? partyVotesJson,
    Expression<String>? ballotStatsJson,
    Expression<String>? imagePath,
    Expression<DateTime>? createdAt,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (observerId != null) 'observer_id': observerId,
      if (pollingUnitId != null) 'polling_unit_id': pollingUnitId,
      if (partyVotesJson != null) 'party_votes_json': partyVotesJson,
      if (ballotStatsJson != null) 'ballot_stats_json': ballotStatsJson,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  ResultsCompanion copyWith(
      {Value<int>? id,
      Value<String>? observerId,
      Value<String>? pollingUnitId,
      Value<String>? partyVotesJson,
      Value<String>? ballotStatsJson,
      Value<String?>? imagePath,
      Value<DateTime>? createdAt,
      Value<bool>? isSynced}) {
    return ResultsCompanion(
      id: id ?? this.id,
      observerId: observerId ?? this.observerId,
      pollingUnitId: pollingUnitId ?? this.pollingUnitId,
      partyVotesJson: partyVotesJson ?? this.partyVotesJson,
      ballotStatsJson: ballotStatsJson ?? this.ballotStatsJson,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (observerId.present) {
      map['observer_id'] = Variable<String>(observerId.value);
    }
    if (pollingUnitId.present) {
      map['polling_unit_id'] = Variable<String>(pollingUnitId.value);
    }
    if (partyVotesJson.present) {
      map['party_votes_json'] = Variable<String>(partyVotesJson.value);
    }
    if (ballotStatsJson.present) {
      map['ballot_stats_json'] = Variable<String>(ballotStatsJson.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsCompanion(')
          ..write('id: $id, ')
          ..write('observerId: $observerId, ')
          ..write('pollingUnitId: $pollingUnitId, ')
          ..write('partyVotesJson: $partyVotesJson, ')
          ..write('ballotStatsJson: $ballotStatsJson, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $IncidentsTable extends Incidents
    with TableInfo<$IncidentsTable, Incident> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncidentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _severityMeta =
      const VerificationMeta('severity');
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
      'severity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _mediaPathsJsonMeta =
      const VerificationMeta('mediaPathsJson');
  @override
  late final GeneratedColumn<String> mediaPathsJson = GeneratedColumn<String>(
      'media_paths_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        category,
        severity,
        description,
        latitude,
        longitude,
        mediaPathsJson,
        createdAt,
        isSynced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'incidents';
  @override
  VerificationContext validateIntegrity(Insertable<Incident> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(_severityMeta,
          severity.isAcceptableOrUnknown(data['severity']!, _severityMeta));
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('media_paths_json')) {
      context.handle(
          _mediaPathsJsonMeta,
          mediaPathsJson.isAcceptableOrUnknown(
              data['media_paths_json']!, _mediaPathsJsonMeta));
    } else if (isInserting) {
      context.missing(_mediaPathsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Incident map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Incident(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      severity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}severity'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      mediaPathsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}media_paths_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $IncidentsTable createAlias(String alias) {
    return $IncidentsTable(attachedDatabase, alias);
  }
}

class Incident extends DataClass implements Insertable<Incident> {
  final int id;
  final String category;
  final String severity;
  final String description;
  final double? latitude;
  final double? longitude;
  final String mediaPathsJson;
  final DateTime createdAt;
  final bool isSynced;
  const Incident(
      {required this.id,
      required this.category,
      required this.severity,
      required this.description,
      this.latitude,
      this.longitude,
      required this.mediaPathsJson,
      required this.createdAt,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category'] = Variable<String>(category);
    map['severity'] = Variable<String>(severity);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['media_paths_json'] = Variable<String>(mediaPathsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  IncidentsCompanion toCompanion(bool nullToAbsent) {
    return IncidentsCompanion(
      id: Value(id),
      category: Value(category),
      severity: Value(severity),
      description: Value(description),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      mediaPathsJson: Value(mediaPathsJson),
      createdAt: Value(createdAt),
      isSynced: Value(isSynced),
    );
  }

  factory Incident.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Incident(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      severity: serializer.fromJson<String>(json['severity']),
      description: serializer.fromJson<String>(json['description']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      mediaPathsJson: serializer.fromJson<String>(json['mediaPathsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String>(category),
      'severity': serializer.toJson<String>(severity),
      'description': serializer.toJson<String>(description),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'mediaPathsJson': serializer.toJson<String>(mediaPathsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  Incident copyWith(
          {int? id,
          String? category,
          String? severity,
          String? description,
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          String? mediaPathsJson,
          DateTime? createdAt,
          bool? isSynced}) =>
      Incident(
        id: id ?? this.id,
        category: category ?? this.category,
        severity: severity ?? this.severity,
        description: description ?? this.description,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        mediaPathsJson: mediaPathsJson ?? this.mediaPathsJson,
        createdAt: createdAt ?? this.createdAt,
        isSynced: isSynced ?? this.isSynced,
      );
  Incident copyWithCompanion(IncidentsCompanion data) {
    return Incident(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      severity: data.severity.present ? data.severity.value : this.severity,
      description:
          data.description.present ? data.description.value : this.description,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      mediaPathsJson: data.mediaPathsJson.present
          ? data.mediaPathsJson.value
          : this.mediaPathsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Incident(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('mediaPathsJson: $mediaPathsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, category, severity, description, latitude,
      longitude, mediaPathsJson, createdAt, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Incident &&
          other.id == this.id &&
          other.category == this.category &&
          other.severity == this.severity &&
          other.description == this.description &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.mediaPathsJson == this.mediaPathsJson &&
          other.createdAt == this.createdAt &&
          other.isSynced == this.isSynced);
}

class IncidentsCompanion extends UpdateCompanion<Incident> {
  final Value<int> id;
  final Value<String> category;
  final Value<String> severity;
  final Value<String> description;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> mediaPathsJson;
  final Value<DateTime> createdAt;
  final Value<bool> isSynced;
  const IncidentsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.severity = const Value.absent(),
    this.description = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.mediaPathsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  IncidentsCompanion.insert({
    this.id = const Value.absent(),
    required String category,
    required String severity,
    required String description,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required String mediaPathsJson,
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  })  : category = Value(category),
        severity = Value(severity),
        description = Value(description),
        mediaPathsJson = Value(mediaPathsJson);
  static Insertable<Incident> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<String>? severity,
    Expression<String>? description,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? mediaPathsJson,
    Expression<DateTime>? createdAt,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
      if (description != null) 'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (mediaPathsJson != null) 'media_paths_json': mediaPathsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  IncidentsCompanion copyWith(
      {Value<int>? id,
      Value<String>? category,
      Value<String>? severity,
      Value<String>? description,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String>? mediaPathsJson,
      Value<DateTime>? createdAt,
      Value<bool>? isSynced}) {
    return IncidentsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mediaPathsJson: mediaPathsJson ?? this.mediaPathsJson,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (mediaPathsJson.present) {
      map['media_paths_json'] = Variable<String>(mediaPathsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncidentsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('mediaPathsJson: $mediaPathsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $ChecklistsTable extends Checklists
    with TableInfo<$ChecklistsTable, Checklist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, category, isCompleted, updatedAt, isSynced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklists';
  @override
  VerificationContext validateIntegrity(Insertable<Checklist> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Checklist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Checklist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $ChecklistsTable createAlias(String alias) {
    return $ChecklistsTable(attachedDatabase, alias);
  }
}

class Checklist extends DataClass implements Insertable<Checklist> {
  final int id;
  final String title;
  final String category;
  final bool isCompleted;
  final DateTime updatedAt;
  final bool isSynced;
  const Checklist(
      {required this.id,
      required this.title,
      required this.category,
      required this.isCompleted,
      required this.updatedAt,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  ChecklistsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistsCompanion(
      id: Value(id),
      title: Value(title),
      category: Value(category),
      isCompleted: Value(isCompleted),
      updatedAt: Value(updatedAt),
      isSynced: Value(isSynced),
    );
  }

  factory Checklist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Checklist(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  Checklist copyWith(
          {int? id,
          String? title,
          String? category,
          bool? isCompleted,
          DateTime? updatedAt,
          bool? isSynced}) =>
      Checklist(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        isCompleted: isCompleted ?? this.isCompleted,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
      );
  Checklist copyWithCompanion(ChecklistsCompanion data) {
    return Checklist(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Checklist(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, category, isCompleted, updatedAt, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Checklist &&
          other.id == this.id &&
          other.title == this.title &&
          other.category == this.category &&
          other.isCompleted == this.isCompleted &&
          other.updatedAt == this.updatedAt &&
          other.isSynced == this.isSynced);
}

class ChecklistsCompanion extends UpdateCompanion<Checklist> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> category;
  final Value<bool> isCompleted;
  final Value<DateTime> updatedAt;
  final Value<bool> isSynced;
  const ChecklistsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  ChecklistsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String category,
    this.isCompleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  })  : title = Value(title),
        category = Value(category);
  static Insertable<Checklist> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? category,
    Expression<bool>? isCompleted,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  ChecklistsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? category,
      Value<bool>? isCompleted,
      Value<DateTime>? updatedAt,
      Value<bool>? isSynced}) {
    return ChecklistsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $ElectionsTable extends Elections
    with TableInfo<$ElectionsTable, LocalElection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ElectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataJsonMeta =
      const VerificationMeta('metadataJson');
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
      'metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, type, startDate, endDate, status, metadataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'elections_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalElection> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
          _metadataJsonMeta,
          metadataJson.isAcceptableOrUnknown(
              data['metadata_json']!, _metadataJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalElection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalElection(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      metadataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata_json']),
    );
  }

  @override
  $ElectionsTable createAlias(String alias) {
    return $ElectionsTable(attachedDatabase, alias);
  }
}

class LocalElection extends DataClass implements Insertable<LocalElection> {
  final String id;
  final String name;
  final String type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String? metadataJson;
  const LocalElection(
      {required this.id,
      required this.name,
      required this.type,
      this.startDate,
      this.endDate,
      required this.status,
      this.metadataJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  ElectionsCompanion toCompanion(bool nullToAbsent) {
    return ElectionsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      status: Value(status),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory LocalElection.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalElection(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      status: serializer.fromJson<String>(json['status']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'status': serializer.toJson<String>(status),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  LocalElection copyWith(
          {String? id,
          String? name,
          String? type,
          Value<DateTime?> startDate = const Value.absent(),
          Value<DateTime?> endDate = const Value.absent(),
          String? status,
          Value<String?> metadataJson = const Value.absent()}) =>
      LocalElection(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        startDate: startDate.present ? startDate.value : this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        status: status ?? this.status,
        metadataJson:
            metadataJson.present ? metadataJson.value : this.metadataJson,
      );
  LocalElection copyWithCompanion(ElectionsCompanion data) {
    return LocalElection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      status: data.status.present ? data.status.value : this.status,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalElection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('status: $status, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, startDate, endDate, status, metadataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalElection &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.status == this.status &&
          other.metadataJson == this.metadataJson);
}

class ElectionsCompanion extends UpdateCompanion<LocalElection> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<String> status;
  final Value<String?> metadataJson;
  final Value<int> rowid;
  const ElectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.status = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ElectionsCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    required String status,
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type),
        status = Value(status);
  static Insertable<LocalElection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? status,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null) 'status': status,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ElectionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? type,
      Value<DateTime?>? startDate,
      Value<DateTime?>? endDate,
      Value<String>? status,
      Value<String?>? metadataJson,
      Value<int>? rowid}) {
    return ElectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      metadataJson: metadataJson ?? this.metadataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ElectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('status: $status, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartiesTable extends Parties with TableInfo<$PartiesTable, LocalParty> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _abbreviationMeta =
      const VerificationMeta('abbreviation');
  @override
  late final GeneratedColumn<String> abbreviation = GeneratedColumn<String>(
      'abbreviation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _logoUrlMeta =
      const VerificationMeta('logoUrl');
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
      'logo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, abbreviation, logoUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parties_table';
  @override
  VerificationContext validateIntegrity(Insertable<LocalParty> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('abbreviation')) {
      context.handle(
          _abbreviationMeta,
          abbreviation.isAcceptableOrUnknown(
              data['abbreviation']!, _abbreviationMeta));
    } else if (isInserting) {
      context.missing(_abbreviationMeta);
    }
    if (data.containsKey('logo_url')) {
      context.handle(_logoUrlMeta,
          logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalParty map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalParty(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      abbreviation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}abbreviation'])!,
      logoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logo_url']),
    );
  }

  @override
  $PartiesTable createAlias(String alias) {
    return $PartiesTable(attachedDatabase, alias);
  }
}

class LocalParty extends DataClass implements Insertable<LocalParty> {
  final String id;
  final String name;
  final String abbreviation;
  final String? logoUrl;
  const LocalParty(
      {required this.id,
      required this.name,
      required this.abbreviation,
      this.logoUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['abbreviation'] = Variable<String>(abbreviation);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    return map;
  }

  PartiesCompanion toCompanion(bool nullToAbsent) {
    return PartiesCompanion(
      id: Value(id),
      name: Value(name),
      abbreviation: Value(abbreviation),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
    );
  }

  factory LocalParty.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalParty(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      abbreviation: serializer.fromJson<String>(json['abbreviation']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'abbreviation': serializer.toJson<String>(abbreviation),
      'logoUrl': serializer.toJson<String?>(logoUrl),
    };
  }

  LocalParty copyWith(
          {String? id,
          String? name,
          String? abbreviation,
          Value<String?> logoUrl = const Value.absent()}) =>
      LocalParty(
        id: id ?? this.id,
        name: name ?? this.name,
        abbreviation: abbreviation ?? this.abbreviation,
        logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
      );
  LocalParty copyWithCompanion(PartiesCompanion data) {
    return LocalParty(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      abbreviation: data.abbreviation.present
          ? data.abbreviation.value
          : this.abbreviation,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalParty(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('logoUrl: $logoUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, abbreviation, logoUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalParty &&
          other.id == this.id &&
          other.name == this.name &&
          other.abbreviation == this.abbreviation &&
          other.logoUrl == this.logoUrl);
}

class PartiesCompanion extends UpdateCompanion<LocalParty> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> abbreviation;
  final Value<String?> logoUrl;
  final Value<int> rowid;
  const PartiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.abbreviation = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartiesCompanion.insert({
    required String id,
    required String name,
    required String abbreviation,
    this.logoUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        abbreviation = Value(abbreviation);
  static Insertable<LocalParty> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? abbreviation,
    Expression<String>? logoUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (abbreviation != null) 'abbreviation': abbreviation,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartiesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? abbreviation,
      Value<String?>? logoUrl,
      Value<int>? rowid}) {
    return PartiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      logoUrl: logoUrl ?? this.logoUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (abbreviation.present) {
      map['abbreviation'] = Variable<String>(abbreviation.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChecklistTemplatesTable extends ChecklistTemplates
    with TableInfo<$ChecklistTemplatesTable, LocalChecklistTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_templates_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalChecklistTemplate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChecklistTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChecklistTemplate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $ChecklistTemplatesTable createAlias(String alias) {
    return $ChecklistTemplatesTable(attachedDatabase, alias);
  }
}

class LocalChecklistTemplate extends DataClass
    implements Insertable<LocalChecklistTemplate> {
  final String id;
  final String name;
  final DateTime? updatedAt;
  const LocalChecklistTemplate(
      {required this.id, required this.name, this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ChecklistTemplatesCompanion toCompanion(bool nullToAbsent) {
    return ChecklistTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LocalChecklistTemplate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChecklistTemplate(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LocalChecklistTemplate copyWith(
          {String? id,
          String? name,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      LocalChecklistTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  LocalChecklistTemplate copyWithCompanion(ChecklistTemplatesCompanion data) {
    return LocalChecklistTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChecklistTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChecklistTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.updatedAt == this.updatedAt);
}

class ChecklistTemplatesCompanion
    extends UpdateCompanion<LocalChecklistTemplate> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const ChecklistTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChecklistTemplatesCompanion.insert({
    required String id,
    required String name,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<LocalChecklistTemplate> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChecklistTemplatesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return ChecklistTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChecklistQuestionsTable extends ChecklistQuestions
    with TableInfo<$ChecklistQuestionsTable, LocalChecklistQuestion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
      'local_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
      'template_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _questionTextMeta =
      const VerificationMeta('questionText');
  @override
  late final GeneratedColumn<String> questionText = GeneratedColumn<String>(
      'question_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _metadataJsonMeta =
      const VerificationMeta('metadataJson');
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
      'metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        localId,
        id,
        templateId,
        questionText,
        type,
        order,
        category,
        metadataJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_questions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalChecklistQuestion> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('question_text')) {
      context.handle(
          _questionTextMeta,
          questionText.isAcceptableOrUnknown(
              data['question_text']!, _questionTextMeta));
    } else if (isInserting) {
      context.missing(_questionTextMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
          _metadataJsonMeta,
          metadataJson.isAcceptableOrUnknown(
              data['metadata_json']!, _metadataJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalChecklistQuestion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChecklistQuestion(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_id'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_id'])!,
      questionText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question_text'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      metadataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata_json']),
    );
  }

  @override
  $ChecklistQuestionsTable createAlias(String alias) {
    return $ChecklistQuestionsTable(attachedDatabase, alias);
  }
}

class LocalChecklistQuestion extends DataClass
    implements Insertable<LocalChecklistQuestion> {
  final int localId;
  final String id;
  final String templateId;
  final String questionText;
  final String type;
  final int order;
  final String? category;
  final String? metadataJson;
  const LocalChecklistQuestion(
      {required this.localId,
      required this.id,
      required this.templateId,
      required this.questionText,
      required this.type,
      required this.order,
      this.category,
      this.metadataJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    map['id'] = Variable<String>(id);
    map['template_id'] = Variable<String>(templateId);
    map['question_text'] = Variable<String>(questionText);
    map['type'] = Variable<String>(type);
    map['order'] = Variable<int>(order);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  ChecklistQuestionsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistQuestionsCompanion(
      localId: Value(localId),
      id: Value(id),
      templateId: Value(templateId),
      questionText: Value(questionText),
      type: Value(type),
      order: Value(order),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory LocalChecklistQuestion.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChecklistQuestion(
      localId: serializer.fromJson<int>(json['localId']),
      id: serializer.fromJson<String>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      questionText: serializer.fromJson<String>(json['questionText']),
      type: serializer.fromJson<String>(json['type']),
      order: serializer.fromJson<int>(json['order']),
      category: serializer.fromJson<String?>(json['category']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'id': serializer.toJson<String>(id),
      'templateId': serializer.toJson<String>(templateId),
      'questionText': serializer.toJson<String>(questionText),
      'type': serializer.toJson<String>(type),
      'order': serializer.toJson<int>(order),
      'category': serializer.toJson<String?>(category),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  LocalChecklistQuestion copyWith(
          {int? localId,
          String? id,
          String? templateId,
          String? questionText,
          String? type,
          int? order,
          Value<String?> category = const Value.absent(),
          Value<String?> metadataJson = const Value.absent()}) =>
      LocalChecklistQuestion(
        localId: localId ?? this.localId,
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        questionText: questionText ?? this.questionText,
        type: type ?? this.type,
        order: order ?? this.order,
        category: category.present ? category.value : this.category,
        metadataJson:
            metadataJson.present ? metadataJson.value : this.metadataJson,
      );
  LocalChecklistQuestion copyWithCompanion(ChecklistQuestionsCompanion data) {
    return LocalChecklistQuestion(
      localId: data.localId.present ? data.localId.value : this.localId,
      id: data.id.present ? data.id.value : this.id,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      questionText: data.questionText.present
          ? data.questionText.value
          : this.questionText,
      type: data.type.present ? data.type.value : this.type,
      order: data.order.present ? data.order.value : this.order,
      category: data.category.present ? data.category.value : this.category,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChecklistQuestion(')
          ..write('localId: $localId, ')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('questionText: $questionText, ')
          ..write('type: $type, ')
          ..write('order: $order, ')
          ..write('category: $category, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localId, id, templateId, questionText, type,
      order, category, metadataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChecklistQuestion &&
          other.localId == this.localId &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.questionText == this.questionText &&
          other.type == this.type &&
          other.order == this.order &&
          other.category == this.category &&
          other.metadataJson == this.metadataJson);
}

class ChecklistQuestionsCompanion
    extends UpdateCompanion<LocalChecklistQuestion> {
  final Value<int> localId;
  final Value<String> id;
  final Value<String> templateId;
  final Value<String> questionText;
  final Value<String> type;
  final Value<int> order;
  final Value<String?> category;
  final Value<String?> metadataJson;
  const ChecklistQuestionsCompanion({
    this.localId = const Value.absent(),
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.questionText = const Value.absent(),
    this.type = const Value.absent(),
    this.order = const Value.absent(),
    this.category = const Value.absent(),
    this.metadataJson = const Value.absent(),
  });
  ChecklistQuestionsCompanion.insert({
    this.localId = const Value.absent(),
    required String id,
    required String templateId,
    required String questionText,
    required String type,
    required int order,
    this.category = const Value.absent(),
    this.metadataJson = const Value.absent(),
  })  : id = Value(id),
        templateId = Value(templateId),
        questionText = Value(questionText),
        type = Value(type),
        order = Value(order);
  static Insertable<LocalChecklistQuestion> custom({
    Expression<int>? localId,
    Expression<String>? id,
    Expression<String>? templateId,
    Expression<String>? questionText,
    Expression<String>? type,
    Expression<int>? order,
    Expression<String>? category,
    Expression<String>? metadataJson,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (questionText != null) 'question_text': questionText,
      if (type != null) 'type': type,
      if (order != null) 'order': order,
      if (category != null) 'category': category,
      if (metadataJson != null) 'metadata_json': metadataJson,
    });
  }

  ChecklistQuestionsCompanion copyWith(
      {Value<int>? localId,
      Value<String>? id,
      Value<String>? templateId,
      Value<String>? questionText,
      Value<String>? type,
      Value<int>? order,
      Value<String?>? category,
      Value<String?>? metadataJson}) {
    return ChecklistQuestionsCompanion(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      questionText: questionText ?? this.questionText,
      type: type ?? this.type,
      order: order ?? this.order,
      category: category ?? this.category,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (questionText.present) {
      map['question_text'] = Variable<String>(questionText.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistQuestionsCompanion(')
          ..write('localId: $localId, ')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('questionText: $questionText, ')
          ..write('type: $type, ')
          ..write('order: $order, ')
          ..write('category: $category, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ResultsTable results = $ResultsTable(this);
  late final $IncidentsTable incidents = $IncidentsTable(this);
  late final $ChecklistsTable checklists = $ChecklistsTable(this);
  late final $ElectionsTable elections = $ElectionsTable(this);
  late final $PartiesTable parties = $PartiesTable(this);
  late final $ChecklistTemplatesTable checklistTemplates =
      $ChecklistTemplatesTable(this);
  late final $ChecklistQuestionsTable checklistQuestions =
      $ChecklistQuestionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        results,
        incidents,
        checklists,
        elections,
        parties,
        checklistTemplates,
        checklistQuestions
      ];
}

typedef $$ResultsTableCreateCompanionBuilder = ResultsCompanion Function({
  Value<int> id,
  required String observerId,
  required String pollingUnitId,
  required String partyVotesJson,
  required String ballotStatsJson,
  Value<String?> imagePath,
  Value<DateTime> createdAt,
  Value<bool> isSynced,
});
typedef $$ResultsTableUpdateCompanionBuilder = ResultsCompanion Function({
  Value<int> id,
  Value<String> observerId,
  Value<String> pollingUnitId,
  Value<String> partyVotesJson,
  Value<String> ballotStatsJson,
  Value<String?> imagePath,
  Value<DateTime> createdAt,
  Value<bool> isSynced,
});

class $$ResultsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ResultsTable,
    Result,
    $$ResultsTableFilterComposer,
    $$ResultsTableOrderingComposer,
    $$ResultsTableCreateCompanionBuilder,
    $$ResultsTableUpdateCompanionBuilder> {
  $$ResultsTableTableManager(_$AppDatabase db, $ResultsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ResultsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ResultsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> observerId = const Value.absent(),
            Value<String> pollingUnitId = const Value.absent(),
            Value<String> partyVotesJson = const Value.absent(),
            Value<String> ballotStatsJson = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              ResultsCompanion(
            id: id,
            observerId: observerId,
            pollingUnitId: pollingUnitId,
            partyVotesJson: partyVotesJson,
            ballotStatsJson: ballotStatsJson,
            imagePath: imagePath,
            createdAt: createdAt,
            isSynced: isSynced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String observerId,
            required String pollingUnitId,
            required String partyVotesJson,
            required String ballotStatsJson,
            Value<String?> imagePath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              ResultsCompanion.insert(
            id: id,
            observerId: observerId,
            pollingUnitId: pollingUnitId,
            partyVotesJson: partyVotesJson,
            ballotStatsJson: ballotStatsJson,
            imagePath: imagePath,
            createdAt: createdAt,
            isSynced: isSynced,
          ),
        ));
}

class $$ResultsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ResultsTable> {
  $$ResultsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get observerId => $state.composableBuilder(
      column: $state.table.observerId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get pollingUnitId => $state.composableBuilder(
      column: $state.table.pollingUnitId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get partyVotesJson => $state.composableBuilder(
      column: $state.table.partyVotesJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get ballotStatsJson => $state.composableBuilder(
      column: $state.table.ballotStatsJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ResultsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ResultsTable> {
  $$ResultsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get observerId => $state.composableBuilder(
      column: $state.table.observerId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get pollingUnitId => $state.composableBuilder(
      column: $state.table.pollingUnitId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get partyVotesJson => $state.composableBuilder(
      column: $state.table.partyVotesJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get ballotStatsJson => $state.composableBuilder(
      column: $state.table.ballotStatsJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get imagePath => $state.composableBuilder(
      column: $state.table.imagePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$IncidentsTableCreateCompanionBuilder = IncidentsCompanion Function({
  Value<int> id,
  required String category,
  required String severity,
  required String description,
  Value<double?> latitude,
  Value<double?> longitude,
  required String mediaPathsJson,
  Value<DateTime> createdAt,
  Value<bool> isSynced,
});
typedef $$IncidentsTableUpdateCompanionBuilder = IncidentsCompanion Function({
  Value<int> id,
  Value<String> category,
  Value<String> severity,
  Value<String> description,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String> mediaPathsJson,
  Value<DateTime> createdAt,
  Value<bool> isSynced,
});

class $$IncidentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $IncidentsTable,
    Incident,
    $$IncidentsTableFilterComposer,
    $$IncidentsTableOrderingComposer,
    $$IncidentsTableCreateCompanionBuilder,
    $$IncidentsTableUpdateCompanionBuilder> {
  $$IncidentsTableTableManager(_$AppDatabase db, $IncidentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$IncidentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$IncidentsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> severity = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String> mediaPathsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              IncidentsCompanion(
            id: id,
            category: category,
            severity: severity,
            description: description,
            latitude: latitude,
            longitude: longitude,
            mediaPathsJson: mediaPathsJson,
            createdAt: createdAt,
            isSynced: isSynced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String category,
            required String severity,
            required String description,
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            required String mediaPathsJson,
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              IncidentsCompanion.insert(
            id: id,
            category: category,
            severity: severity,
            description: description,
            latitude: latitude,
            longitude: longitude,
            mediaPathsJson: mediaPathsJson,
            createdAt: createdAt,
            isSynced: isSynced,
          ),
        ));
}

class $$IncidentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get severity => $state.composableBuilder(
      column: $state.table.severity,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get latitude => $state.composableBuilder(
      column: $state.table.latitude,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get longitude => $state.composableBuilder(
      column: $state.table.longitude,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get mediaPathsJson => $state.composableBuilder(
      column: $state.table.mediaPathsJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$IncidentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get severity => $state.composableBuilder(
      column: $state.table.severity,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get latitude => $state.composableBuilder(
      column: $state.table.latitude,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get longitude => $state.composableBuilder(
      column: $state.table.longitude,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get mediaPathsJson => $state.composableBuilder(
      column: $state.table.mediaPathsJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ChecklistsTableCreateCompanionBuilder = ChecklistsCompanion Function({
  Value<int> id,
  required String title,
  required String category,
  Value<bool> isCompleted,
  Value<DateTime> updatedAt,
  Value<bool> isSynced,
});
typedef $$ChecklistsTableUpdateCompanionBuilder = ChecklistsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> category,
  Value<bool> isCompleted,
  Value<DateTime> updatedAt,
  Value<bool> isSynced,
});

class $$ChecklistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChecklistsTable,
    Checklist,
    $$ChecklistsTableFilterComposer,
    $$ChecklistsTableOrderingComposer,
    $$ChecklistsTableCreateCompanionBuilder,
    $$ChecklistsTableUpdateCompanionBuilder> {
  $$ChecklistsTableTableManager(_$AppDatabase db, $ChecklistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ChecklistsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ChecklistsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              ChecklistsCompanion(
            id: id,
            title: title,
            category: category,
            isCompleted: isCompleted,
            updatedAt: updatedAt,
            isSynced: isSynced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String category,
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              ChecklistsCompanion.insert(
            id: id,
            title: title,
            category: category,
            isCompleted: isCompleted,
            updatedAt: updatedAt,
            isSynced: isSynced,
          ),
        ));
}

class $$ChecklistsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCompleted => $state.composableBuilder(
      column: $state.table.isCompleted,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ChecklistsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCompleted => $state.composableBuilder(
      column: $state.table.isCompleted,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ElectionsTableCreateCompanionBuilder = ElectionsCompanion Function({
  required String id,
  required String name,
  required String type,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  required String status,
  Value<String?> metadataJson,
  Value<int> rowid,
});
typedef $$ElectionsTableUpdateCompanionBuilder = ElectionsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  Value<String> status,
  Value<String?> metadataJson,
  Value<int> rowid,
});

class $$ElectionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ElectionsTable,
    LocalElection,
    $$ElectionsTableFilterComposer,
    $$ElectionsTableOrderingComposer,
    $$ElectionsTableCreateCompanionBuilder,
    $$ElectionsTableUpdateCompanionBuilder> {
  $$ElectionsTableTableManager(_$AppDatabase db, $ElectionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ElectionsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ElectionsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ElectionsCompanion(
            id: id,
            name: name,
            type: type,
            startDate: startDate,
            endDate: endDate,
            status: status,
            metadataJson: metadataJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String type,
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            required String status,
            Value<String?> metadataJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ElectionsCompanion.insert(
            id: id,
            name: name,
            type: type,
            startDate: startDate,
            endDate: endDate,
            status: status,
            metadataJson: metadataJson,
            rowid: rowid,
          ),
        ));
}

class $$ElectionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ElectionsTable> {
  $$ElectionsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get startDate => $state.composableBuilder(
      column: $state.table.startDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get endDate => $state.composableBuilder(
      column: $state.table.endDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get metadataJson => $state.composableBuilder(
      column: $state.table.metadataJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ElectionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ElectionsTable> {
  $$ElectionsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get startDate => $state.composableBuilder(
      column: $state.table.startDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get endDate => $state.composableBuilder(
      column: $state.table.endDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get metadataJson => $state.composableBuilder(
      column: $state.table.metadataJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$PartiesTableCreateCompanionBuilder = PartiesCompanion Function({
  required String id,
  required String name,
  required String abbreviation,
  Value<String?> logoUrl,
  Value<int> rowid,
});
typedef $$PartiesTableUpdateCompanionBuilder = PartiesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> abbreviation,
  Value<String?> logoUrl,
  Value<int> rowid,
});

class $$PartiesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PartiesTable,
    LocalParty,
    $$PartiesTableFilterComposer,
    $$PartiesTableOrderingComposer,
    $$PartiesTableCreateCompanionBuilder,
    $$PartiesTableUpdateCompanionBuilder> {
  $$PartiesTableTableManager(_$AppDatabase db, $PartiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$PartiesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$PartiesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> abbreviation = const Value.absent(),
            Value<String?> logoUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PartiesCompanion(
            id: id,
            name: name,
            abbreviation: abbreviation,
            logoUrl: logoUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String abbreviation,
            Value<String?> logoUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PartiesCompanion.insert(
            id: id,
            name: name,
            abbreviation: abbreviation,
            logoUrl: logoUrl,
            rowid: rowid,
          ),
        ));
}

class $$PartiesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $PartiesTable> {
  $$PartiesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get abbreviation => $state.composableBuilder(
      column: $state.table.abbreviation,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get logoUrl => $state.composableBuilder(
      column: $state.table.logoUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$PartiesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $PartiesTable> {
  $$PartiesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get abbreviation => $state.composableBuilder(
      column: $state.table.abbreviation,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get logoUrl => $state.composableBuilder(
      column: $state.table.logoUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ChecklistTemplatesTableCreateCompanionBuilder
    = ChecklistTemplatesCompanion Function({
  required String id,
  required String name,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$ChecklistTemplatesTableUpdateCompanionBuilder
    = ChecklistTemplatesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$ChecklistTemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChecklistTemplatesTable,
    LocalChecklistTemplate,
    $$ChecklistTemplatesTableFilterComposer,
    $$ChecklistTemplatesTableOrderingComposer,
    $$ChecklistTemplatesTableCreateCompanionBuilder,
    $$ChecklistTemplatesTableUpdateCompanionBuilder> {
  $$ChecklistTemplatesTableTableManager(
      _$AppDatabase db, $ChecklistTemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ChecklistTemplatesTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$ChecklistTemplatesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChecklistTemplatesCompanion(
            id: id,
            name: name,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChecklistTemplatesCompanion.insert(
            id: id,
            name: name,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$ChecklistTemplatesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ChecklistTemplatesTable> {
  $$ChecklistTemplatesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ChecklistTemplatesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ChecklistTemplatesTable> {
  $$ChecklistTemplatesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ChecklistQuestionsTableCreateCompanionBuilder
    = ChecklistQuestionsCompanion Function({
  Value<int> localId,
  required String id,
  required String templateId,
  required String questionText,
  required String type,
  required int order,
  Value<String?> category,
  Value<String?> metadataJson,
});
typedef $$ChecklistQuestionsTableUpdateCompanionBuilder
    = ChecklistQuestionsCompanion Function({
  Value<int> localId,
  Value<String> id,
  Value<String> templateId,
  Value<String> questionText,
  Value<String> type,
  Value<int> order,
  Value<String?> category,
  Value<String?> metadataJson,
});

class $$ChecklistQuestionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChecklistQuestionsTable,
    LocalChecklistQuestion,
    $$ChecklistQuestionsTableFilterComposer,
    $$ChecklistQuestionsTableOrderingComposer,
    $$ChecklistQuestionsTableCreateCompanionBuilder,
    $$ChecklistQuestionsTableUpdateCompanionBuilder> {
  $$ChecklistQuestionsTableTableManager(
      _$AppDatabase db, $ChecklistQuestionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ChecklistQuestionsTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$ChecklistQuestionsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> localId = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> templateId = const Value.absent(),
            Value<String> questionText = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> order = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
          }) =>
              ChecklistQuestionsCompanion(
            localId: localId,
            id: id,
            templateId: templateId,
            questionText: questionText,
            type: type,
            order: order,
            category: category,
            metadataJson: metadataJson,
          ),
          createCompanionCallback: ({
            Value<int> localId = const Value.absent(),
            required String id,
            required String templateId,
            required String questionText,
            required String type,
            required int order,
            Value<String?> category = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
          }) =>
              ChecklistQuestionsCompanion.insert(
            localId: localId,
            id: id,
            templateId: templateId,
            questionText: questionText,
            type: type,
            order: order,
            category: category,
            metadataJson: metadataJson,
          ),
        ));
}

class $$ChecklistQuestionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ChecklistQuestionsTable> {
  $$ChecklistQuestionsTableFilterComposer(super.$state);
  ColumnFilters<int> get localId => $state.composableBuilder(
      column: $state.table.localId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get templateId => $state.composableBuilder(
      column: $state.table.templateId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get questionText => $state.composableBuilder(
      column: $state.table.questionText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get metadataJson => $state.composableBuilder(
      column: $state.table.metadataJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ChecklistQuestionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ChecklistQuestionsTable> {
  $$ChecklistQuestionsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get localId => $state.composableBuilder(
      column: $state.table.localId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get templateId => $state.composableBuilder(
      column: $state.table.templateId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get questionText => $state.composableBuilder(
      column: $state.table.questionText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get metadataJson => $state.composableBuilder(
      column: $state.table.metadataJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ResultsTableTableManager get results =>
      $$ResultsTableTableManager(_db, _db.results);
  $$IncidentsTableTableManager get incidents =>
      $$IncidentsTableTableManager(_db, _db.incidents);
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db, _db.checklists);
  $$ElectionsTableTableManager get elections =>
      $$ElectionsTableTableManager(_db, _db.elections);
  $$PartiesTableTableManager get parties =>
      $$PartiesTableTableManager(_db, _db.parties);
  $$ChecklistTemplatesTableTableManager get checklistTemplates =>
      $$ChecklistTemplatesTableTableManager(_db, _db.checklistTemplates);
  $$ChecklistQuestionsTableTableManager get checklistQuestions =>
      $$ChecklistQuestionsTableTableManager(_db, _db.checklistQuestions);
}

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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ResultsTable results = $ResultsTable(this);
  late final $IncidentsTable incidents = $IncidentsTable(this);
  late final $ChecklistsTable checklists = $ChecklistsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [results, incidents, checklists];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ResultsTableTableManager get results =>
      $$ResultsTableTableManager(_db, _db.results);
  $$IncidentsTableTableManager get incidents =>
      $$IncidentsTableTableManager(_db, _db.incidents);
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db, _db.checklists);
}

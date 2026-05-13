import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Results extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get observerId => text()();
  TextColumn get pollingUnitId => text()();
  TextColumn get partyVotesJson => text()(); // Store as JSON string
  TextColumn get ballotStatsJson => text()(); // Store as JSON string
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

class Incidents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get description => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get mediaPathsJson => text()(); // JSON list of paths
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

class Checklists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get category => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Results, Incidents, Checklists])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // DAO methods could go here or in separate classes
  Future<int> insertResult(ResultsCompanion result) => into(results).insert(result);
  Future<List<Result>> getAllResults() => select(results).get();
  
  Future<int> insertIncident(IncidentsCompanion incident) => into(incidents).insert(incident);
  Future<List<Incident>> getAllIncidents() => select(incidents).get();

  Future<void> updateChecklistItem(Checklist item) => update(checklists).replace(item);
  Future<List<Checklist>> getAllChecklists() => select(checklists).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'voteguard.sqlite'));
    return NativeDatabase(file);
  });
}

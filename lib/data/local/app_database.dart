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
  TextColumn get partyVotesJson => text()(); 
  TextColumn get ballotStatsJson => text()(); 
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
  TextColumn get mediaPathsJson => text()(); 
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

@DataClassName('LocalElection')
class Elections extends Table {
  @override
  String get tableName => 'elections_table';
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get metadataJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalParty')
class Parties extends Table {
  @override
  String get tableName => 'parties_table';
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get abbreviation => text()();
  TextColumn get logoUrl => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalChecklistTemplate')
class ChecklistTemplates extends Table {
  @override
  String get tableName => 'checklist_templates_table';
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalChecklistQuestion')
class ChecklistQuestions extends Table {
  @override
  String get tableName => 'checklist_questions_table';
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get questionText => text()(); // Renamed to avoid conflict with text() method
  TextColumn get type => text()();
  IntColumn get order => integer()();
  TextColumn get category => text().nullable()();
  TextColumn get metadataJson => text().nullable()();
}

@DriftDatabase(tables: [Results, Incidents, Checklists, Elections, Parties, ChecklistTemplates, ChecklistQuestions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // DAO methods
  Future<int> insertResult(ResultsCompanion result) => into(results).insert(result);
  Future<List<Result>> getAllResults() => select(results).get();
  Future<List<Result>> getUnsyncedResults() => (select(results)..where((t) => t.isSynced.equals(false))).get();
  Stream<List<Result>> watchUnsyncedResults() => (select(results)..where((t) => t.isSynced.equals(false))).watch();
  Future<void> markResultSynced(int localId) => (update(results)..where((t) => t.id.equals(localId))).write(const ResultsCompanion(isSynced: Value(true)));
  Future<void> deleteResult(int localId) => (delete(results)..where((t) => t.id.equals(localId))).go();
  
  Future<int> insertIncident(IncidentsCompanion incident) => into(incidents).insert(incident);
  Future<List<Incident>> getAllIncidents() => select(incidents).get();
  Future<List<Incident>> getUnsyncedIncidents() => (select(incidents)..where((t) => t.isSynced.equals(false))).get();
  Stream<List<Incident>> watchUnsyncedIncidents() => (select(incidents)..where((t) => t.isSynced.equals(false))).watch();
  Future<void> markIncidentSynced(int localId) => (update(incidents)..where((t) => t.id.equals(localId))).write(const IncidentsCompanion(isSynced: Value(true)));
  Future<void> deleteIncident(int localId) => (delete(incidents)..where((t) => t.id.equals(localId))).go();

  Future<int> insertChecklist(ChecklistsCompanion checklist) => into(checklists).insert(checklist);
  Future<void> updateChecklistItem(Checklist item) => update(checklists).replace(item);
  Future<List<Checklist>> getAllChecklists() => select(checklists).get();
  Future<List<Checklist>> getUnsyncedChecklists() => (select(checklists)..where((t) => t.isSynced.equals(false))).get();
  Stream<List<Checklist>> watchUnsyncedChecklists() => (select(checklists)..where((t) => t.isSynced.equals(false))).watch();
  Future<void> markChecklistSynced(int localId) => (update(checklists)..where((t) => t.id.equals(localId))).write(const ChecklistsCompanion(isSynced: Value(true)));
  Future<void> deleteChecklist(int localId) => (delete(checklists)..where((t) => t.id.equals(localId))).go();

  // Offline Sync Methods
  Future<void> upsertElection(ElectionsCompanion election) => into(elections).insertOnConflictUpdate(election);
  Future<List<LocalElection>> getAllLocalElections() => select(elections).get();

  Future<void> upsertParty(PartiesCompanion party) => into(parties).insertOnConflictUpdate(party);
  Future<List<LocalParty>> getAllLocalParties() => select(parties).get();

  Future<void> upsertChecklistTemplate(ChecklistTemplatesCompanion template) => into(checklistTemplates).insertOnConflictUpdate(template);
  Future<void> upsertChecklistQuestion(ChecklistQuestionsCompanion question) => into(checklistQuestions).insert(question);
  Future<void> clearTemplateQuestions(String templateId) => (delete(checklistQuestions)..where((t) => t.templateId.equals(templateId))).go();

  Future<List<LocalChecklistQuestion>> getLocalChecklistQuestions(String templateId) => 
      (select(checklistQuestions)..where((t) => t.templateId.equals(templateId))..orderBy([(t) => OrderingTerm(expression: t.order)])).get();
  
  Future<LocalChecklistTemplate?> getLocalLatestTemplate() => 
      (select(checklistTemplates)..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])..limit(1)).getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'voteguard.sqlite'));
    return NativeDatabase(file);
  });
}

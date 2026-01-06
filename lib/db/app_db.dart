import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_db.g.dart';

class Projects extends Table {
  TextColumn get projectId => text()();
  TextColumn get title => text()();
  TextColumn get folder => text().withDefault(const Constant(''))();

  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  TextColumn get baseAssPath => text()();

  TextColumn get exportMode =>
      text().withDefault(const Constant('CLEAN_TRANSLATION_ONLY'))();
  BoolColumn get strictExport =>
      boolean().withDefault(const Constant(true))();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {projectId};
}

class ProjectFiles extends Table {
  TextColumn get fileId => text()();
  TextColumn get projectId => text()();

  // 'base','gpt','claude','gemini','deepseek'
  TextColumn get engine => text()();

  TextColumn get assPath => text()();
  IntColumn get importedAtMs => integer()();

  IntColumn get dialogueCount => integer().withDefault(const Constant(0))();
  IntColumn get unmatchedCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {fileId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, engine},
      ];
}

class SubtitleLines extends Table {
  TextColumn get lineId => text()();
  TextColumn get projectId => text()();

  IntColumn get dialogueIndex => integer()();
  IntColumn get eventsRowIndex => integer()();

  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();

  TextColumn get style => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get effect => text().nullable()();

  TextColumn get sourceText => text().nullable()();
  TextColumn get romanization => text().nullable()();
  TextColumn get gloss => text().nullable()();

  // Para export fiel
  TextColumn get dialoguePrefix => text()(); // incluye la coma justo antes del Text
  TextColumn get leadingTags => text().withDefault(const Constant(''))();
  BoolColumn get hasVectorDrawing =>
      boolean().withDefault(const Constant(false))();
  TextColumn get originalText => text()();

  // Candidatos
  TextColumn get candGpt => text().nullable()();
  TextColumn get candClaude => text().nullable()();
  TextColumn get candGemini => text().nullable()();
  TextColumn get candDeepseek => text().nullable()();
  TextColumn get candVoice => text().nullable()();

  // Selección
  TextColumn get selectedSource => text().nullable()();
  TextColumn get selectedText => text().nullable()();
  BoolColumn get reviewed => boolean().withDefault(const Constant(false))();
  BoolColumn get doubt => boolean().withDefault(const Constant(false))();

  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {lineId};
}

class SelectionEvents extends Table {
  IntColumn get eventId => integer().autoIncrement()();
  TextColumn get projectId => text()();
  TextColumn get lineId => text()();

  TextColumn get chosenSource => text()();
  TextColumn get chosenText => text()();
  IntColumn get atMs => integer()();
  TextColumn get method => text()(); // 'tap','voice','edit'
}

class SessionLogs extends Table {
  TextColumn get sessionId => text()();
  TextColumn get projectId => text()();
  TextColumn get deviceId => text()();
  TextColumn get platform => text()();
  IntColumn get startedAtMs => integer()();
  IntColumn get endedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

@DriftDatabase(tables: [Projects, ProjectFiles, SubtitleLines, SelectionEvents, SessionLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from <= 1) {
            await _safeAddColumn(m, projects, projects.folder);
            from = 2;
          }
          if (from == 2) {
            await _safeCreateTable(m, sessionLogs);
            from = 3;
          }
          if (from == 3) {
            await _safeAddColumn(m, projects, projects.archived);
          }
        },
      );

  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn column,
  ) async {
    try {
      await m.addColumn(table, column);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Ignore duplicate column errors to keep migrations idempotent.
      if (!msg.contains('duplicate column')) {
        rethrow;
      }
    }
  }

  Future<void> _safeCreateTable(
    Migrator m,
    TableInfo<Table, dynamic> table,
  ) async {
    try {
      await m.createTable(table);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains('already exists')) {
        rethrow;
      }
    }
  }

  static QueryExecutor _openConnection() {
    // Drift recomienda driftDatabase() en Flutter y, por defecto, guarda en un directorio de soporte. :contentReference[oaicite:2]{index=2}
    return driftDatabase(
      name: 'voicex_db',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}

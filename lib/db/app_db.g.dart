// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _baseAssPathMeta = const VerificationMeta(
    'baseAssPath',
  );
  @override
  late final GeneratedColumn<String> baseAssPath = GeneratedColumn<String>(
    'base_ass_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportModeMeta = const VerificationMeta(
    'exportMode',
  );
  @override
  late final GeneratedColumn<String> exportMode = GeneratedColumn<String>(
    'export_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CLEAN_TRANSLATION_ONLY'),
  );
  static const VerificationMeta _strictExportMeta = const VerificationMeta(
    'strictExport',
  );
  @override
  late final GeneratedColumn<bool> strictExport = GeneratedColumn<bool>(
    'strict_export',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("strict_export" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    projectId,
    title,
    folder,
    createdAtMs,
    updatedAtMs,
    archived,
    baseAssPath,
    exportMode,
    strictExport,
    currentIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('base_ass_path')) {
      context.handle(
        _baseAssPathMeta,
        baseAssPath.isAcceptableOrUnknown(
          data['base_ass_path']!,
          _baseAssPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseAssPathMeta);
    }
    if (data.containsKey('export_mode')) {
      context.handle(
        _exportModeMeta,
        exportMode.isAcceptableOrUnknown(data['export_mode']!, _exportModeMeta),
      );
    }
    if (data.containsKey('strict_export')) {
      context.handle(
        _strictExportMeta,
        strictExport.isAcceptableOrUnknown(
          data['strict_export']!,
          _strictExportMeta,
        ),
      );
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      baseAssPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_ass_path'],
      )!,
      exportMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}export_mode'],
      )!,
      strictExport: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}strict_export'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String projectId;
  final String title;
  final String folder;
  final int createdAtMs;
  final int updatedAtMs;
  final bool archived;
  final String baseAssPath;
  final String exportMode;
  final bool strictExport;
  final int currentIndex;
  const Project({
    required this.projectId,
    required this.title,
    required this.folder,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.archived,
    required this.baseAssPath,
    required this.exportMode,
    required this.strictExport,
    required this.currentIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['title'] = Variable<String>(title);
    map['folder'] = Variable<String>(folder);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    map['archived'] = Variable<bool>(archived);
    map['base_ass_path'] = Variable<String>(baseAssPath);
    map['export_mode'] = Variable<String>(exportMode);
    map['strict_export'] = Variable<bool>(strictExport);
    map['current_index'] = Variable<int>(currentIndex);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      projectId: Value(projectId),
      title: Value(title),
      folder: Value(folder),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
      archived: Value(archived),
      baseAssPath: Value(baseAssPath),
      exportMode: Value(exportMode),
      strictExport: Value(strictExport),
      currentIndex: Value(currentIndex),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      projectId: serializer.fromJson<String>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      folder: serializer.fromJson<String>(json['folder']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      archived: serializer.fromJson<bool>(json['archived']),
      baseAssPath: serializer.fromJson<String>(json['baseAssPath']),
      exportMode: serializer.fromJson<String>(json['exportMode']),
      strictExport: serializer.fromJson<bool>(json['strictExport']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'title': serializer.toJson<String>(title),
      'folder': serializer.toJson<String>(folder),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'archived': serializer.toJson<bool>(archived),
      'baseAssPath': serializer.toJson<String>(baseAssPath),
      'exportMode': serializer.toJson<String>(exportMode),
      'strictExport': serializer.toJson<bool>(strictExport),
      'currentIndex': serializer.toJson<int>(currentIndex),
    };
  }

  Project copyWith({
    String? projectId,
    String? title,
    String? folder,
    int? createdAtMs,
    int? updatedAtMs,
    bool? archived,
    String? baseAssPath,
    String? exportMode,
    bool? strictExport,
    int? currentIndex,
  }) => Project(
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    folder: folder ?? this.folder,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    archived: archived ?? this.archived,
    baseAssPath: baseAssPath ?? this.baseAssPath,
    exportMode: exportMode ?? this.exportMode,
    strictExport: strictExport ?? this.strictExport,
    currentIndex: currentIndex ?? this.currentIndex,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      folder: data.folder.present ? data.folder.value : this.folder,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      archived: data.archived.present ? data.archived.value : this.archived,
      baseAssPath: data.baseAssPath.present
          ? data.baseAssPath.value
          : this.baseAssPath,
      exportMode: data.exportMode.present
          ? data.exportMode.value
          : this.exportMode,
      strictExport: data.strictExport.present
          ? data.strictExport.value
          : this.strictExport,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('folder: $folder, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('archived: $archived, ')
          ..write('baseAssPath: $baseAssPath, ')
          ..write('exportMode: $exportMode, ')
          ..write('strictExport: $strictExport, ')
          ..write('currentIndex: $currentIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    projectId,
    title,
    folder,
    createdAtMs,
    updatedAtMs,
    archived,
    baseAssPath,
    exportMode,
    strictExport,
    currentIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.folder == this.folder &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs &&
          other.archived == this.archived &&
          other.baseAssPath == this.baseAssPath &&
          other.exportMode == this.exportMode &&
          other.strictExport == this.strictExport &&
          other.currentIndex == this.currentIndex);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> projectId;
  final Value<String> title;
  final Value<String> folder;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<bool> archived;
  final Value<String> baseAssPath;
  final Value<String> exportMode;
  final Value<bool> strictExport;
  final Value<int> currentIndex;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.folder = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.archived = const Value.absent(),
    this.baseAssPath = const Value.absent(),
    this.exportMode = const Value.absent(),
    this.strictExport = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String projectId,
    required String title,
    this.folder = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.archived = const Value.absent(),
    required String baseAssPath,
    this.exportMode = const Value.absent(),
    this.strictExport = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : projectId = Value(projectId),
       title = Value(title),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs),
       baseAssPath = Value(baseAssPath);
  static Insertable<Project> custom({
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<String>? folder,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<bool>? archived,
    Expression<String>? baseAssPath,
    Expression<String>? exportMode,
    Expression<bool>? strictExport,
    Expression<int>? currentIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (folder != null) 'folder': folder,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (archived != null) 'archived': archived,
      if (baseAssPath != null) 'base_ass_path': baseAssPath,
      if (exportMode != null) 'export_mode': exportMode,
      if (strictExport != null) 'strict_export': strictExport,
      if (currentIndex != null) 'current_index': currentIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? projectId,
    Value<String>? title,
    Value<String>? folder,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<bool>? archived,
    Value<String>? baseAssPath,
    Value<String>? exportMode,
    Value<bool>? strictExport,
    Value<int>? currentIndex,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      folder: folder ?? this.folder,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      archived: archived ?? this.archived,
      baseAssPath: baseAssPath ?? this.baseAssPath,
      exportMode: exportMode ?? this.exportMode,
      strictExport: strictExport ?? this.strictExport,
      currentIndex: currentIndex ?? this.currentIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (baseAssPath.present) {
      map['base_ass_path'] = Variable<String>(baseAssPath.value);
    }
    if (exportMode.present) {
      map['export_mode'] = Variable<String>(exportMode.value);
    }
    if (strictExport.present) {
      map['strict_export'] = Variable<bool>(strictExport.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('folder: $folder, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('archived: $archived, ')
          ..write('baseAssPath: $baseAssPath, ')
          ..write('exportMode: $exportMode, ')
          ..write('strictExport: $strictExport, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectFilesTable extends ProjectFiles
    with TableInfo<$ProjectFilesTable, ProjectFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assPathMeta = const VerificationMeta(
    'assPath',
  );
  @override
  late final GeneratedColumn<String> assPath = GeneratedColumn<String>(
    'ass_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMsMeta = const VerificationMeta(
    'importedAtMs',
  );
  @override
  late final GeneratedColumn<int> importedAtMs = GeneratedColumn<int>(
    'imported_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dialogueCountMeta = const VerificationMeta(
    'dialogueCount',
  );
  @override
  late final GeneratedColumn<int> dialogueCount = GeneratedColumn<int>(
    'dialogue_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unmatchedCountMeta = const VerificationMeta(
    'unmatchedCount',
  );
  @override
  late final GeneratedColumn<int> unmatchedCount = GeneratedColumn<int>(
    'unmatched_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    projectId,
    engine,
    assPath,
    importedAtMs,
    dialogueCount,
    unmatchedCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('ass_path')) {
      context.handle(
        _assPathMeta,
        assPath.isAcceptableOrUnknown(data['ass_path']!, _assPathMeta),
      );
    } else if (isInserting) {
      context.missing(_assPathMeta);
    }
    if (data.containsKey('imported_at_ms')) {
      context.handle(
        _importedAtMsMeta,
        importedAtMs.isAcceptableOrUnknown(
          data['imported_at_ms']!,
          _importedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importedAtMsMeta);
    }
    if (data.containsKey('dialogue_count')) {
      context.handle(
        _dialogueCountMeta,
        dialogueCount.isAcceptableOrUnknown(
          data['dialogue_count']!,
          _dialogueCountMeta,
        ),
      );
    }
    if (data.containsKey('unmatched_count')) {
      context.handle(
        _unmatchedCountMeta,
        unmatchedCount.isAcceptableOrUnknown(
          data['unmatched_count']!,
          _unmatchedCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, engine},
  ];
  @override
  ProjectFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectFile(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      assPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ass_path'],
      )!,
      importedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at_ms'],
      )!,
      dialogueCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dialogue_count'],
      )!,
      unmatchedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unmatched_count'],
      )!,
    );
  }

  @override
  $ProjectFilesTable createAlias(String alias) {
    return $ProjectFilesTable(attachedDatabase, alias);
  }
}

class ProjectFile extends DataClass implements Insertable<ProjectFile> {
  final String fileId;
  final String projectId;
  final String engine;
  final String assPath;
  final int importedAtMs;
  final int dialogueCount;
  final int unmatchedCount;
  const ProjectFile({
    required this.fileId,
    required this.projectId,
    required this.engine,
    required this.assPath,
    required this.importedAtMs,
    required this.dialogueCount,
    required this.unmatchedCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<String>(fileId);
    map['project_id'] = Variable<String>(projectId);
    map['engine'] = Variable<String>(engine);
    map['ass_path'] = Variable<String>(assPath);
    map['imported_at_ms'] = Variable<int>(importedAtMs);
    map['dialogue_count'] = Variable<int>(dialogueCount);
    map['unmatched_count'] = Variable<int>(unmatchedCount);
    return map;
  }

  ProjectFilesCompanion toCompanion(bool nullToAbsent) {
    return ProjectFilesCompanion(
      fileId: Value(fileId),
      projectId: Value(projectId),
      engine: Value(engine),
      assPath: Value(assPath),
      importedAtMs: Value(importedAtMs),
      dialogueCount: Value(dialogueCount),
      unmatchedCount: Value(unmatchedCount),
    );
  }

  factory ProjectFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectFile(
      fileId: serializer.fromJson<String>(json['fileId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      engine: serializer.fromJson<String>(json['engine']),
      assPath: serializer.fromJson<String>(json['assPath']),
      importedAtMs: serializer.fromJson<int>(json['importedAtMs']),
      dialogueCount: serializer.fromJson<int>(json['dialogueCount']),
      unmatchedCount: serializer.fromJson<int>(json['unmatchedCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<String>(fileId),
      'projectId': serializer.toJson<String>(projectId),
      'engine': serializer.toJson<String>(engine),
      'assPath': serializer.toJson<String>(assPath),
      'importedAtMs': serializer.toJson<int>(importedAtMs),
      'dialogueCount': serializer.toJson<int>(dialogueCount),
      'unmatchedCount': serializer.toJson<int>(unmatchedCount),
    };
  }

  ProjectFile copyWith({
    String? fileId,
    String? projectId,
    String? engine,
    String? assPath,
    int? importedAtMs,
    int? dialogueCount,
    int? unmatchedCount,
  }) => ProjectFile(
    fileId: fileId ?? this.fileId,
    projectId: projectId ?? this.projectId,
    engine: engine ?? this.engine,
    assPath: assPath ?? this.assPath,
    importedAtMs: importedAtMs ?? this.importedAtMs,
    dialogueCount: dialogueCount ?? this.dialogueCount,
    unmatchedCount: unmatchedCount ?? this.unmatchedCount,
  );
  ProjectFile copyWithCompanion(ProjectFilesCompanion data) {
    return ProjectFile(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      engine: data.engine.present ? data.engine.value : this.engine,
      assPath: data.assPath.present ? data.assPath.value : this.assPath,
      importedAtMs: data.importedAtMs.present
          ? data.importedAtMs.value
          : this.importedAtMs,
      dialogueCount: data.dialogueCount.present
          ? data.dialogueCount.value
          : this.dialogueCount,
      unmatchedCount: data.unmatchedCount.present
          ? data.unmatchedCount.value
          : this.unmatchedCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectFile(')
          ..write('fileId: $fileId, ')
          ..write('projectId: $projectId, ')
          ..write('engine: $engine, ')
          ..write('assPath: $assPath, ')
          ..write('importedAtMs: $importedAtMs, ')
          ..write('dialogueCount: $dialogueCount, ')
          ..write('unmatchedCount: $unmatchedCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileId,
    projectId,
    engine,
    assPath,
    importedAtMs,
    dialogueCount,
    unmatchedCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectFile &&
          other.fileId == this.fileId &&
          other.projectId == this.projectId &&
          other.engine == this.engine &&
          other.assPath == this.assPath &&
          other.importedAtMs == this.importedAtMs &&
          other.dialogueCount == this.dialogueCount &&
          other.unmatchedCount == this.unmatchedCount);
}

class ProjectFilesCompanion extends UpdateCompanion<ProjectFile> {
  final Value<String> fileId;
  final Value<String> projectId;
  final Value<String> engine;
  final Value<String> assPath;
  final Value<int> importedAtMs;
  final Value<int> dialogueCount;
  final Value<int> unmatchedCount;
  final Value<int> rowid;
  const ProjectFilesCompanion({
    this.fileId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.engine = const Value.absent(),
    this.assPath = const Value.absent(),
    this.importedAtMs = const Value.absent(),
    this.dialogueCount = const Value.absent(),
    this.unmatchedCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectFilesCompanion.insert({
    required String fileId,
    required String projectId,
    required String engine,
    required String assPath,
    required int importedAtMs,
    this.dialogueCount = const Value.absent(),
    this.unmatchedCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fileId = Value(fileId),
       projectId = Value(projectId),
       engine = Value(engine),
       assPath = Value(assPath),
       importedAtMs = Value(importedAtMs);
  static Insertable<ProjectFile> custom({
    Expression<String>? fileId,
    Expression<String>? projectId,
    Expression<String>? engine,
    Expression<String>? assPath,
    Expression<int>? importedAtMs,
    Expression<int>? dialogueCount,
    Expression<int>? unmatchedCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (projectId != null) 'project_id': projectId,
      if (engine != null) 'engine': engine,
      if (assPath != null) 'ass_path': assPath,
      if (importedAtMs != null) 'imported_at_ms': importedAtMs,
      if (dialogueCount != null) 'dialogue_count': dialogueCount,
      if (unmatchedCount != null) 'unmatched_count': unmatchedCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectFilesCompanion copyWith({
    Value<String>? fileId,
    Value<String>? projectId,
    Value<String>? engine,
    Value<String>? assPath,
    Value<int>? importedAtMs,
    Value<int>? dialogueCount,
    Value<int>? unmatchedCount,
    Value<int>? rowid,
  }) {
    return ProjectFilesCompanion(
      fileId: fileId ?? this.fileId,
      projectId: projectId ?? this.projectId,
      engine: engine ?? this.engine,
      assPath: assPath ?? this.assPath,
      importedAtMs: importedAtMs ?? this.importedAtMs,
      dialogueCount: dialogueCount ?? this.dialogueCount,
      unmatchedCount: unmatchedCount ?? this.unmatchedCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (assPath.present) {
      map['ass_path'] = Variable<String>(assPath.value);
    }
    if (importedAtMs.present) {
      map['imported_at_ms'] = Variable<int>(importedAtMs.value);
    }
    if (dialogueCount.present) {
      map['dialogue_count'] = Variable<int>(dialogueCount.value);
    }
    if (unmatchedCount.present) {
      map['unmatched_count'] = Variable<int>(unmatchedCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectFilesCompanion(')
          ..write('fileId: $fileId, ')
          ..write('projectId: $projectId, ')
          ..write('engine: $engine, ')
          ..write('assPath: $assPath, ')
          ..write('importedAtMs: $importedAtMs, ')
          ..write('dialogueCount: $dialogueCount, ')
          ..write('unmatchedCount: $unmatchedCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtitleLinesTable extends SubtitleLines
    with TableInfo<$SubtitleLinesTable, SubtitleLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtitleLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dialogueIndexMeta = const VerificationMeta(
    'dialogueIndex',
  );
  @override
  late final GeneratedColumn<int> dialogueIndex = GeneratedColumn<int>(
    'dialogue_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventsRowIndexMeta = const VerificationMeta(
    'eventsRowIndex',
  );
  @override
  late final GeneratedColumn<int> eventsRowIndex = GeneratedColumn<int>(
    'events_row_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectMeta = const VerificationMeta('effect');
  @override
  late final GeneratedColumn<String> effect = GeneratedColumn<String>(
    'effect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _romanizationMeta = const VerificationMeta(
    'romanization',
  );
  @override
  late final GeneratedColumn<String> romanization = GeneratedColumn<String>(
    'romanization',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _glossMeta = const VerificationMeta('gloss');
  @override
  late final GeneratedColumn<String> gloss = GeneratedColumn<String>(
    'gloss',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dialoguePrefixMeta = const VerificationMeta(
    'dialoguePrefix',
  );
  @override
  late final GeneratedColumn<String> dialoguePrefix = GeneratedColumn<String>(
    'dialogue_prefix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leadingTagsMeta = const VerificationMeta(
    'leadingTags',
  );
  @override
  late final GeneratedColumn<String> leadingTags = GeneratedColumn<String>(
    'leading_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hasVectorDrawingMeta = const VerificationMeta(
    'hasVectorDrawing',
  );
  @override
  late final GeneratedColumn<bool> hasVectorDrawing = GeneratedColumn<bool>(
    'has_vector_drawing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_vector_drawing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _originalTextMeta = const VerificationMeta(
    'originalText',
  );
  @override
  late final GeneratedColumn<String> originalText = GeneratedColumn<String>(
    'original_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _candGptMeta = const VerificationMeta(
    'candGpt',
  );
  @override
  late final GeneratedColumn<String> candGpt = GeneratedColumn<String>(
    'cand_gpt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _candClaudeMeta = const VerificationMeta(
    'candClaude',
  );
  @override
  late final GeneratedColumn<String> candClaude = GeneratedColumn<String>(
    'cand_claude',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _candGeminiMeta = const VerificationMeta(
    'candGemini',
  );
  @override
  late final GeneratedColumn<String> candGemini = GeneratedColumn<String>(
    'cand_gemini',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _candDeepseekMeta = const VerificationMeta(
    'candDeepseek',
  );
  @override
  late final GeneratedColumn<String> candDeepseek = GeneratedColumn<String>(
    'cand_deepseek',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _candVoiceMeta = const VerificationMeta(
    'candVoice',
  );
  @override
  late final GeneratedColumn<String> candVoice = GeneratedColumn<String>(
    'cand_voice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectedSourceMeta = const VerificationMeta(
    'selectedSource',
  );
  @override
  late final GeneratedColumn<String> selectedSource = GeneratedColumn<String>(
    'selected_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectedTextMeta = const VerificationMeta(
    'selectedText',
  );
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
    'selected_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewedMeta = const VerificationMeta(
    'reviewed',
  );
  @override
  late final GeneratedColumn<bool> reviewed = GeneratedColumn<bool>(
    'reviewed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reviewed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _doubtMeta = const VerificationMeta('doubt');
  @override
  late final GeneratedColumn<bool> doubt = GeneratedColumn<bool>(
    'doubt',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("doubt" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    lineId,
    projectId,
    dialogueIndex,
    eventsRowIndex,
    startMs,
    endMs,
    style,
    name,
    effect,
    sourceText,
    romanization,
    gloss,
    dialoguePrefix,
    leadingTags,
    hasVectorDrawing,
    originalText,
    candGpt,
    candClaude,
    candGemini,
    candDeepseek,
    candVoice,
    selectedSource,
    selectedText,
    reviewed,
    doubt,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtitle_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubtitleLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('dialogue_index')) {
      context.handle(
        _dialogueIndexMeta,
        dialogueIndex.isAcceptableOrUnknown(
          data['dialogue_index']!,
          _dialogueIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dialogueIndexMeta);
    }
    if (data.containsKey('events_row_index')) {
      context.handle(
        _eventsRowIndexMeta,
        eventsRowIndex.isAcceptableOrUnknown(
          data['events_row_index']!,
          _eventsRowIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eventsRowIndexMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('effect')) {
      context.handle(
        _effectMeta,
        effect.isAcceptableOrUnknown(data['effect']!, _effectMeta),
      );
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('romanization')) {
      context.handle(
        _romanizationMeta,
        romanization.isAcceptableOrUnknown(
          data['romanization']!,
          _romanizationMeta,
        ),
      );
    }
    if (data.containsKey('gloss')) {
      context.handle(
        _glossMeta,
        gloss.isAcceptableOrUnknown(data['gloss']!, _glossMeta),
      );
    }
    if (data.containsKey('dialogue_prefix')) {
      context.handle(
        _dialoguePrefixMeta,
        dialoguePrefix.isAcceptableOrUnknown(
          data['dialogue_prefix']!,
          _dialoguePrefixMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dialoguePrefixMeta);
    }
    if (data.containsKey('leading_tags')) {
      context.handle(
        _leadingTagsMeta,
        leadingTags.isAcceptableOrUnknown(
          data['leading_tags']!,
          _leadingTagsMeta,
        ),
      );
    }
    if (data.containsKey('has_vector_drawing')) {
      context.handle(
        _hasVectorDrawingMeta,
        hasVectorDrawing.isAcceptableOrUnknown(
          data['has_vector_drawing']!,
          _hasVectorDrawingMeta,
        ),
      );
    }
    if (data.containsKey('original_text')) {
      context.handle(
        _originalTextMeta,
        originalText.isAcceptableOrUnknown(
          data['original_text']!,
          _originalTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalTextMeta);
    }
    if (data.containsKey('cand_gpt')) {
      context.handle(
        _candGptMeta,
        candGpt.isAcceptableOrUnknown(data['cand_gpt']!, _candGptMeta),
      );
    }
    if (data.containsKey('cand_claude')) {
      context.handle(
        _candClaudeMeta,
        candClaude.isAcceptableOrUnknown(data['cand_claude']!, _candClaudeMeta),
      );
    }
    if (data.containsKey('cand_gemini')) {
      context.handle(
        _candGeminiMeta,
        candGemini.isAcceptableOrUnknown(data['cand_gemini']!, _candGeminiMeta),
      );
    }
    if (data.containsKey('cand_deepseek')) {
      context.handle(
        _candDeepseekMeta,
        candDeepseek.isAcceptableOrUnknown(
          data['cand_deepseek']!,
          _candDeepseekMeta,
        ),
      );
    }
    if (data.containsKey('cand_voice')) {
      context.handle(
        _candVoiceMeta,
        candVoice.isAcceptableOrUnknown(data['cand_voice']!, _candVoiceMeta),
      );
    }
    if (data.containsKey('selected_source')) {
      context.handle(
        _selectedSourceMeta,
        selectedSource.isAcceptableOrUnknown(
          data['selected_source']!,
          _selectedSourceMeta,
        ),
      );
    }
    if (data.containsKey('selected_text')) {
      context.handle(
        _selectedTextMeta,
        selectedText.isAcceptableOrUnknown(
          data['selected_text']!,
          _selectedTextMeta,
        ),
      );
    }
    if (data.containsKey('reviewed')) {
      context.handle(
        _reviewedMeta,
        reviewed.isAcceptableOrUnknown(data['reviewed']!, _reviewedMeta),
      );
    }
    if (data.containsKey('doubt')) {
      context.handle(
        _doubtMeta,
        doubt.isAcceptableOrUnknown(data['doubt']!, _doubtMeta),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lineId};
  @override
  SubtitleLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubtitleLine(
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      dialogueIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dialogue_index'],
      )!,
      eventsRowIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}events_row_index'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      effect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effect'],
      ),
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
      romanization: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}romanization'],
      ),
      gloss: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gloss'],
      ),
      dialoguePrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dialogue_prefix'],
      )!,
      leadingTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leading_tags'],
      )!,
      hasVectorDrawing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_vector_drawing'],
      )!,
      originalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_text'],
      )!,
      candGpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cand_gpt'],
      ),
      candClaude: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cand_claude'],
      ),
      candGemini: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cand_gemini'],
      ),
      candDeepseek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cand_deepseek'],
      ),
      candVoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cand_voice'],
      ),
      selectedSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_source'],
      ),
      selectedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_text'],
      ),
      reviewed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reviewed'],
      )!,
      doubt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}doubt'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $SubtitleLinesTable createAlias(String alias) {
    return $SubtitleLinesTable(attachedDatabase, alias);
  }
}

class SubtitleLine extends DataClass implements Insertable<SubtitleLine> {
  final String lineId;
  final String projectId;
  final int dialogueIndex;
  final int eventsRowIndex;
  final int startMs;
  final int endMs;
  final String? style;
  final String? name;
  final String? effect;
  final String? sourceText;
  final String? romanization;
  final String? gloss;
  final String dialoguePrefix;
  final String leadingTags;
  final bool hasVectorDrawing;
  final String originalText;
  final String? candGpt;
  final String? candClaude;
  final String? candGemini;
  final String? candDeepseek;
  final String? candVoice;
  final String? selectedSource;
  final String? selectedText;
  final bool reviewed;
  final bool doubt;
  final int updatedAtMs;
  const SubtitleLine({
    required this.lineId,
    required this.projectId,
    required this.dialogueIndex,
    required this.eventsRowIndex,
    required this.startMs,
    required this.endMs,
    this.style,
    this.name,
    this.effect,
    this.sourceText,
    this.romanization,
    this.gloss,
    required this.dialoguePrefix,
    required this.leadingTags,
    required this.hasVectorDrawing,
    required this.originalText,
    this.candGpt,
    this.candClaude,
    this.candGemini,
    this.candDeepseek,
    this.candVoice,
    this.selectedSource,
    this.selectedText,
    required this.reviewed,
    required this.doubt,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['line_id'] = Variable<String>(lineId);
    map['project_id'] = Variable<String>(projectId);
    map['dialogue_index'] = Variable<int>(dialogueIndex);
    map['events_row_index'] = Variable<int>(eventsRowIndex);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    if (!nullToAbsent || style != null) {
      map['style'] = Variable<String>(style);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || effect != null) {
      map['effect'] = Variable<String>(effect);
    }
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    if (!nullToAbsent || romanization != null) {
      map['romanization'] = Variable<String>(romanization);
    }
    if (!nullToAbsent || gloss != null) {
      map['gloss'] = Variable<String>(gloss);
    }
    map['dialogue_prefix'] = Variable<String>(dialoguePrefix);
    map['leading_tags'] = Variable<String>(leadingTags);
    map['has_vector_drawing'] = Variable<bool>(hasVectorDrawing);
    map['original_text'] = Variable<String>(originalText);
    if (!nullToAbsent || candGpt != null) {
      map['cand_gpt'] = Variable<String>(candGpt);
    }
    if (!nullToAbsent || candClaude != null) {
      map['cand_claude'] = Variable<String>(candClaude);
    }
    if (!nullToAbsent || candGemini != null) {
      map['cand_gemini'] = Variable<String>(candGemini);
    }
    if (!nullToAbsent || candDeepseek != null) {
      map['cand_deepseek'] = Variable<String>(candDeepseek);
    }
    if (!nullToAbsent || candVoice != null) {
      map['cand_voice'] = Variable<String>(candVoice);
    }
    if (!nullToAbsent || selectedSource != null) {
      map['selected_source'] = Variable<String>(selectedSource);
    }
    if (!nullToAbsent || selectedText != null) {
      map['selected_text'] = Variable<String>(selectedText);
    }
    map['reviewed'] = Variable<bool>(reviewed);
    map['doubt'] = Variable<bool>(doubt);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  SubtitleLinesCompanion toCompanion(bool nullToAbsent) {
    return SubtitleLinesCompanion(
      lineId: Value(lineId),
      projectId: Value(projectId),
      dialogueIndex: Value(dialogueIndex),
      eventsRowIndex: Value(eventsRowIndex),
      startMs: Value(startMs),
      endMs: Value(endMs),
      style: style == null && nullToAbsent
          ? const Value.absent()
          : Value(style),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      effect: effect == null && nullToAbsent
          ? const Value.absent()
          : Value(effect),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
      romanization: romanization == null && nullToAbsent
          ? const Value.absent()
          : Value(romanization),
      gloss: gloss == null && nullToAbsent
          ? const Value.absent()
          : Value(gloss),
      dialoguePrefix: Value(dialoguePrefix),
      leadingTags: Value(leadingTags),
      hasVectorDrawing: Value(hasVectorDrawing),
      originalText: Value(originalText),
      candGpt: candGpt == null && nullToAbsent
          ? const Value.absent()
          : Value(candGpt),
      candClaude: candClaude == null && nullToAbsent
          ? const Value.absent()
          : Value(candClaude),
      candGemini: candGemini == null && nullToAbsent
          ? const Value.absent()
          : Value(candGemini),
      candDeepseek: candDeepseek == null && nullToAbsent
          ? const Value.absent()
          : Value(candDeepseek),
      candVoice: candVoice == null && nullToAbsent
          ? const Value.absent()
          : Value(candVoice),
      selectedSource: selectedSource == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedSource),
      selectedText: selectedText == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedText),
      reviewed: Value(reviewed),
      doubt: Value(doubt),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory SubtitleLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubtitleLine(
      lineId: serializer.fromJson<String>(json['lineId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      dialogueIndex: serializer.fromJson<int>(json['dialogueIndex']),
      eventsRowIndex: serializer.fromJson<int>(json['eventsRowIndex']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      style: serializer.fromJson<String?>(json['style']),
      name: serializer.fromJson<String?>(json['name']),
      effect: serializer.fromJson<String?>(json['effect']),
      sourceText: serializer.fromJson<String?>(json['sourceText']),
      romanization: serializer.fromJson<String?>(json['romanization']),
      gloss: serializer.fromJson<String?>(json['gloss']),
      dialoguePrefix: serializer.fromJson<String>(json['dialoguePrefix']),
      leadingTags: serializer.fromJson<String>(json['leadingTags']),
      hasVectorDrawing: serializer.fromJson<bool>(json['hasVectorDrawing']),
      originalText: serializer.fromJson<String>(json['originalText']),
      candGpt: serializer.fromJson<String?>(json['candGpt']),
      candClaude: serializer.fromJson<String?>(json['candClaude']),
      candGemini: serializer.fromJson<String?>(json['candGemini']),
      candDeepseek: serializer.fromJson<String?>(json['candDeepseek']),
      candVoice: serializer.fromJson<String?>(json['candVoice']),
      selectedSource: serializer.fromJson<String?>(json['selectedSource']),
      selectedText: serializer.fromJson<String?>(json['selectedText']),
      reviewed: serializer.fromJson<bool>(json['reviewed']),
      doubt: serializer.fromJson<bool>(json['doubt']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lineId': serializer.toJson<String>(lineId),
      'projectId': serializer.toJson<String>(projectId),
      'dialogueIndex': serializer.toJson<int>(dialogueIndex),
      'eventsRowIndex': serializer.toJson<int>(eventsRowIndex),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'style': serializer.toJson<String?>(style),
      'name': serializer.toJson<String?>(name),
      'effect': serializer.toJson<String?>(effect),
      'sourceText': serializer.toJson<String?>(sourceText),
      'romanization': serializer.toJson<String?>(romanization),
      'gloss': serializer.toJson<String?>(gloss),
      'dialoguePrefix': serializer.toJson<String>(dialoguePrefix),
      'leadingTags': serializer.toJson<String>(leadingTags),
      'hasVectorDrawing': serializer.toJson<bool>(hasVectorDrawing),
      'originalText': serializer.toJson<String>(originalText),
      'candGpt': serializer.toJson<String?>(candGpt),
      'candClaude': serializer.toJson<String?>(candClaude),
      'candGemini': serializer.toJson<String?>(candGemini),
      'candDeepseek': serializer.toJson<String?>(candDeepseek),
      'candVoice': serializer.toJson<String?>(candVoice),
      'selectedSource': serializer.toJson<String?>(selectedSource),
      'selectedText': serializer.toJson<String?>(selectedText),
      'reviewed': serializer.toJson<bool>(reviewed),
      'doubt': serializer.toJson<bool>(doubt),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  SubtitleLine copyWith({
    String? lineId,
    String? projectId,
    int? dialogueIndex,
    int? eventsRowIndex,
    int? startMs,
    int? endMs,
    Value<String?> style = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> effect = const Value.absent(),
    Value<String?> sourceText = const Value.absent(),
    Value<String?> romanization = const Value.absent(),
    Value<String?> gloss = const Value.absent(),
    String? dialoguePrefix,
    String? leadingTags,
    bool? hasVectorDrawing,
    String? originalText,
    Value<String?> candGpt = const Value.absent(),
    Value<String?> candClaude = const Value.absent(),
    Value<String?> candGemini = const Value.absent(),
    Value<String?> candDeepseek = const Value.absent(),
    Value<String?> candVoice = const Value.absent(),
    Value<String?> selectedSource = const Value.absent(),
    Value<String?> selectedText = const Value.absent(),
    bool? reviewed,
    bool? doubt,
    int? updatedAtMs,
  }) => SubtitleLine(
    lineId: lineId ?? this.lineId,
    projectId: projectId ?? this.projectId,
    dialogueIndex: dialogueIndex ?? this.dialogueIndex,
    eventsRowIndex: eventsRowIndex ?? this.eventsRowIndex,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    style: style.present ? style.value : this.style,
    name: name.present ? name.value : this.name,
    effect: effect.present ? effect.value : this.effect,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
    romanization: romanization.present ? romanization.value : this.romanization,
    gloss: gloss.present ? gloss.value : this.gloss,
    dialoguePrefix: dialoguePrefix ?? this.dialoguePrefix,
    leadingTags: leadingTags ?? this.leadingTags,
    hasVectorDrawing: hasVectorDrawing ?? this.hasVectorDrawing,
    originalText: originalText ?? this.originalText,
    candGpt: candGpt.present ? candGpt.value : this.candGpt,
    candClaude: candClaude.present ? candClaude.value : this.candClaude,
    candGemini: candGemini.present ? candGemini.value : this.candGemini,
    candDeepseek: candDeepseek.present ? candDeepseek.value : this.candDeepseek,
    candVoice: candVoice.present ? candVoice.value : this.candVoice,
    selectedSource: selectedSource.present
        ? selectedSource.value
        : this.selectedSource,
    selectedText: selectedText.present ? selectedText.value : this.selectedText,
    reviewed: reviewed ?? this.reviewed,
    doubt: doubt ?? this.doubt,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  SubtitleLine copyWithCompanion(SubtitleLinesCompanion data) {
    return SubtitleLine(
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      dialogueIndex: data.dialogueIndex.present
          ? data.dialogueIndex.value
          : this.dialogueIndex,
      eventsRowIndex: data.eventsRowIndex.present
          ? data.eventsRowIndex.value
          : this.eventsRowIndex,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      style: data.style.present ? data.style.value : this.style,
      name: data.name.present ? data.name.value : this.name,
      effect: data.effect.present ? data.effect.value : this.effect,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      romanization: data.romanization.present
          ? data.romanization.value
          : this.romanization,
      gloss: data.gloss.present ? data.gloss.value : this.gloss,
      dialoguePrefix: data.dialoguePrefix.present
          ? data.dialoguePrefix.value
          : this.dialoguePrefix,
      leadingTags: data.leadingTags.present
          ? data.leadingTags.value
          : this.leadingTags,
      hasVectorDrawing: data.hasVectorDrawing.present
          ? data.hasVectorDrawing.value
          : this.hasVectorDrawing,
      originalText: data.originalText.present
          ? data.originalText.value
          : this.originalText,
      candGpt: data.candGpt.present ? data.candGpt.value : this.candGpt,
      candClaude: data.candClaude.present
          ? data.candClaude.value
          : this.candClaude,
      candGemini: data.candGemini.present
          ? data.candGemini.value
          : this.candGemini,
      candDeepseek: data.candDeepseek.present
          ? data.candDeepseek.value
          : this.candDeepseek,
      candVoice: data.candVoice.present ? data.candVoice.value : this.candVoice,
      selectedSource: data.selectedSource.present
          ? data.selectedSource.value
          : this.selectedSource,
      selectedText: data.selectedText.present
          ? data.selectedText.value
          : this.selectedText,
      reviewed: data.reviewed.present ? data.reviewed.value : this.reviewed,
      doubt: data.doubt.present ? data.doubt.value : this.doubt,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubtitleLine(')
          ..write('lineId: $lineId, ')
          ..write('projectId: $projectId, ')
          ..write('dialogueIndex: $dialogueIndex, ')
          ..write('eventsRowIndex: $eventsRowIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('style: $style, ')
          ..write('name: $name, ')
          ..write('effect: $effect, ')
          ..write('sourceText: $sourceText, ')
          ..write('romanization: $romanization, ')
          ..write('gloss: $gloss, ')
          ..write('dialoguePrefix: $dialoguePrefix, ')
          ..write('leadingTags: $leadingTags, ')
          ..write('hasVectorDrawing: $hasVectorDrawing, ')
          ..write('originalText: $originalText, ')
          ..write('candGpt: $candGpt, ')
          ..write('candClaude: $candClaude, ')
          ..write('candGemini: $candGemini, ')
          ..write('candDeepseek: $candDeepseek, ')
          ..write('candVoice: $candVoice, ')
          ..write('selectedSource: $selectedSource, ')
          ..write('selectedText: $selectedText, ')
          ..write('reviewed: $reviewed, ')
          ..write('doubt: $doubt, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    lineId,
    projectId,
    dialogueIndex,
    eventsRowIndex,
    startMs,
    endMs,
    style,
    name,
    effect,
    sourceText,
    romanization,
    gloss,
    dialoguePrefix,
    leadingTags,
    hasVectorDrawing,
    originalText,
    candGpt,
    candClaude,
    candGemini,
    candDeepseek,
    candVoice,
    selectedSource,
    selectedText,
    reviewed,
    doubt,
    updatedAtMs,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtitleLine &&
          other.lineId == this.lineId &&
          other.projectId == this.projectId &&
          other.dialogueIndex == this.dialogueIndex &&
          other.eventsRowIndex == this.eventsRowIndex &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.style == this.style &&
          other.name == this.name &&
          other.effect == this.effect &&
          other.sourceText == this.sourceText &&
          other.romanization == this.romanization &&
          other.gloss == this.gloss &&
          other.dialoguePrefix == this.dialoguePrefix &&
          other.leadingTags == this.leadingTags &&
          other.hasVectorDrawing == this.hasVectorDrawing &&
          other.originalText == this.originalText &&
          other.candGpt == this.candGpt &&
          other.candClaude == this.candClaude &&
          other.candGemini == this.candGemini &&
          other.candDeepseek == this.candDeepseek &&
          other.candVoice == this.candVoice &&
          other.selectedSource == this.selectedSource &&
          other.selectedText == this.selectedText &&
          other.reviewed == this.reviewed &&
          other.doubt == this.doubt &&
          other.updatedAtMs == this.updatedAtMs);
}

class SubtitleLinesCompanion extends UpdateCompanion<SubtitleLine> {
  final Value<String> lineId;
  final Value<String> projectId;
  final Value<int> dialogueIndex;
  final Value<int> eventsRowIndex;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String?> style;
  final Value<String?> name;
  final Value<String?> effect;
  final Value<String?> sourceText;
  final Value<String?> romanization;
  final Value<String?> gloss;
  final Value<String> dialoguePrefix;
  final Value<String> leadingTags;
  final Value<bool> hasVectorDrawing;
  final Value<String> originalText;
  final Value<String?> candGpt;
  final Value<String?> candClaude;
  final Value<String?> candGemini;
  final Value<String?> candDeepseek;
  final Value<String?> candVoice;
  final Value<String?> selectedSource;
  final Value<String?> selectedText;
  final Value<bool> reviewed;
  final Value<bool> doubt;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const SubtitleLinesCompanion({
    this.lineId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.dialogueIndex = const Value.absent(),
    this.eventsRowIndex = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.style = const Value.absent(),
    this.name = const Value.absent(),
    this.effect = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.romanization = const Value.absent(),
    this.gloss = const Value.absent(),
    this.dialoguePrefix = const Value.absent(),
    this.leadingTags = const Value.absent(),
    this.hasVectorDrawing = const Value.absent(),
    this.originalText = const Value.absent(),
    this.candGpt = const Value.absent(),
    this.candClaude = const Value.absent(),
    this.candGemini = const Value.absent(),
    this.candDeepseek = const Value.absent(),
    this.candVoice = const Value.absent(),
    this.selectedSource = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.reviewed = const Value.absent(),
    this.doubt = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtitleLinesCompanion.insert({
    required String lineId,
    required String projectId,
    required int dialogueIndex,
    required int eventsRowIndex,
    required int startMs,
    required int endMs,
    this.style = const Value.absent(),
    this.name = const Value.absent(),
    this.effect = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.romanization = const Value.absent(),
    this.gloss = const Value.absent(),
    required String dialoguePrefix,
    this.leadingTags = const Value.absent(),
    this.hasVectorDrawing = const Value.absent(),
    required String originalText,
    this.candGpt = const Value.absent(),
    this.candClaude = const Value.absent(),
    this.candGemini = const Value.absent(),
    this.candDeepseek = const Value.absent(),
    this.candVoice = const Value.absent(),
    this.selectedSource = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.reviewed = const Value.absent(),
    this.doubt = const Value.absent(),
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : lineId = Value(lineId),
       projectId = Value(projectId),
       dialogueIndex = Value(dialogueIndex),
       eventsRowIndex = Value(eventsRowIndex),
       startMs = Value(startMs),
       endMs = Value(endMs),
       dialoguePrefix = Value(dialoguePrefix),
       originalText = Value(originalText),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<SubtitleLine> custom({
    Expression<String>? lineId,
    Expression<String>? projectId,
    Expression<int>? dialogueIndex,
    Expression<int>? eventsRowIndex,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? style,
    Expression<String>? name,
    Expression<String>? effect,
    Expression<String>? sourceText,
    Expression<String>? romanization,
    Expression<String>? gloss,
    Expression<String>? dialoguePrefix,
    Expression<String>? leadingTags,
    Expression<bool>? hasVectorDrawing,
    Expression<String>? originalText,
    Expression<String>? candGpt,
    Expression<String>? candClaude,
    Expression<String>? candGemini,
    Expression<String>? candDeepseek,
    Expression<String>? candVoice,
    Expression<String>? selectedSource,
    Expression<String>? selectedText,
    Expression<bool>? reviewed,
    Expression<bool>? doubt,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lineId != null) 'line_id': lineId,
      if (projectId != null) 'project_id': projectId,
      if (dialogueIndex != null) 'dialogue_index': dialogueIndex,
      if (eventsRowIndex != null) 'events_row_index': eventsRowIndex,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (style != null) 'style': style,
      if (name != null) 'name': name,
      if (effect != null) 'effect': effect,
      if (sourceText != null) 'source_text': sourceText,
      if (romanization != null) 'romanization': romanization,
      if (gloss != null) 'gloss': gloss,
      if (dialoguePrefix != null) 'dialogue_prefix': dialoguePrefix,
      if (leadingTags != null) 'leading_tags': leadingTags,
      if (hasVectorDrawing != null) 'has_vector_drawing': hasVectorDrawing,
      if (originalText != null) 'original_text': originalText,
      if (candGpt != null) 'cand_gpt': candGpt,
      if (candClaude != null) 'cand_claude': candClaude,
      if (candGemini != null) 'cand_gemini': candGemini,
      if (candDeepseek != null) 'cand_deepseek': candDeepseek,
      if (candVoice != null) 'cand_voice': candVoice,
      if (selectedSource != null) 'selected_source': selectedSource,
      if (selectedText != null) 'selected_text': selectedText,
      if (reviewed != null) 'reviewed': reviewed,
      if (doubt != null) 'doubt': doubt,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtitleLinesCompanion copyWith({
    Value<String>? lineId,
    Value<String>? projectId,
    Value<int>? dialogueIndex,
    Value<int>? eventsRowIndex,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String?>? style,
    Value<String?>? name,
    Value<String?>? effect,
    Value<String?>? sourceText,
    Value<String?>? romanization,
    Value<String?>? gloss,
    Value<String>? dialoguePrefix,
    Value<String>? leadingTags,
    Value<bool>? hasVectorDrawing,
    Value<String>? originalText,
    Value<String?>? candGpt,
    Value<String?>? candClaude,
    Value<String?>? candGemini,
    Value<String?>? candDeepseek,
    Value<String?>? candVoice,
    Value<String?>? selectedSource,
    Value<String?>? selectedText,
    Value<bool>? reviewed,
    Value<bool>? doubt,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return SubtitleLinesCompanion(
      lineId: lineId ?? this.lineId,
      projectId: projectId ?? this.projectId,
      dialogueIndex: dialogueIndex ?? this.dialogueIndex,
      eventsRowIndex: eventsRowIndex ?? this.eventsRowIndex,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      style: style ?? this.style,
      name: name ?? this.name,
      effect: effect ?? this.effect,
      sourceText: sourceText ?? this.sourceText,
      romanization: romanization ?? this.romanization,
      gloss: gloss ?? this.gloss,
      dialoguePrefix: dialoguePrefix ?? this.dialoguePrefix,
      leadingTags: leadingTags ?? this.leadingTags,
      hasVectorDrawing: hasVectorDrawing ?? this.hasVectorDrawing,
      originalText: originalText ?? this.originalText,
      candGpt: candGpt ?? this.candGpt,
      candClaude: candClaude ?? this.candClaude,
      candGemini: candGemini ?? this.candGemini,
      candDeepseek: candDeepseek ?? this.candDeepseek,
      candVoice: candVoice ?? this.candVoice,
      selectedSource: selectedSource ?? this.selectedSource,
      selectedText: selectedText ?? this.selectedText,
      reviewed: reviewed ?? this.reviewed,
      doubt: doubt ?? this.doubt,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (dialogueIndex.present) {
      map['dialogue_index'] = Variable<int>(dialogueIndex.value);
    }
    if (eventsRowIndex.present) {
      map['events_row_index'] = Variable<int>(eventsRowIndex.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (effect.present) {
      map['effect'] = Variable<String>(effect.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (romanization.present) {
      map['romanization'] = Variable<String>(romanization.value);
    }
    if (gloss.present) {
      map['gloss'] = Variable<String>(gloss.value);
    }
    if (dialoguePrefix.present) {
      map['dialogue_prefix'] = Variable<String>(dialoguePrefix.value);
    }
    if (leadingTags.present) {
      map['leading_tags'] = Variable<String>(leadingTags.value);
    }
    if (hasVectorDrawing.present) {
      map['has_vector_drawing'] = Variable<bool>(hasVectorDrawing.value);
    }
    if (originalText.present) {
      map['original_text'] = Variable<String>(originalText.value);
    }
    if (candGpt.present) {
      map['cand_gpt'] = Variable<String>(candGpt.value);
    }
    if (candClaude.present) {
      map['cand_claude'] = Variable<String>(candClaude.value);
    }
    if (candGemini.present) {
      map['cand_gemini'] = Variable<String>(candGemini.value);
    }
    if (candDeepseek.present) {
      map['cand_deepseek'] = Variable<String>(candDeepseek.value);
    }
    if (candVoice.present) {
      map['cand_voice'] = Variable<String>(candVoice.value);
    }
    if (selectedSource.present) {
      map['selected_source'] = Variable<String>(selectedSource.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (reviewed.present) {
      map['reviewed'] = Variable<bool>(reviewed.value);
    }
    if (doubt.present) {
      map['doubt'] = Variable<bool>(doubt.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtitleLinesCompanion(')
          ..write('lineId: $lineId, ')
          ..write('projectId: $projectId, ')
          ..write('dialogueIndex: $dialogueIndex, ')
          ..write('eventsRowIndex: $eventsRowIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('style: $style, ')
          ..write('name: $name, ')
          ..write('effect: $effect, ')
          ..write('sourceText: $sourceText, ')
          ..write('romanization: $romanization, ')
          ..write('gloss: $gloss, ')
          ..write('dialoguePrefix: $dialoguePrefix, ')
          ..write('leadingTags: $leadingTags, ')
          ..write('hasVectorDrawing: $hasVectorDrawing, ')
          ..write('originalText: $originalText, ')
          ..write('candGpt: $candGpt, ')
          ..write('candClaude: $candClaude, ')
          ..write('candGemini: $candGemini, ')
          ..write('candDeepseek: $candDeepseek, ')
          ..write('candVoice: $candVoice, ')
          ..write('selectedSource: $selectedSource, ')
          ..write('selectedText: $selectedText, ')
          ..write('reviewed: $reviewed, ')
          ..write('doubt: $doubt, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SelectionEventsTable extends SelectionEvents
    with TableInfo<$SelectionEventsTable, SelectionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SelectionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chosenSourceMeta = const VerificationMeta(
    'chosenSource',
  );
  @override
  late final GeneratedColumn<String> chosenSource = GeneratedColumn<String>(
    'chosen_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chosenTextMeta = const VerificationMeta(
    'chosenText',
  );
  @override
  late final GeneratedColumn<String> chosenText = GeneratedColumn<String>(
    'chosen_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMsMeta = const VerificationMeta('atMs');
  @override
  late final GeneratedColumn<int> atMs = GeneratedColumn<int>(
    'at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    projectId,
    lineId,
    chosenSource,
    chosenText,
    atMs,
    method,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'selection_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SelectionEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('chosen_source')) {
      context.handle(
        _chosenSourceMeta,
        chosenSource.isAcceptableOrUnknown(
          data['chosen_source']!,
          _chosenSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chosenSourceMeta);
    }
    if (data.containsKey('chosen_text')) {
      context.handle(
        _chosenTextMeta,
        chosenText.isAcceptableOrUnknown(data['chosen_text']!, _chosenTextMeta),
      );
    } else if (isInserting) {
      context.missing(_chosenTextMeta);
    }
    if (data.containsKey('at_ms')) {
      context.handle(
        _atMsMeta,
        atMs.isAcceptableOrUnknown(data['at_ms']!, _atMsMeta),
      );
    } else if (isInserting) {
      context.missing(_atMsMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  SelectionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SelectionEvent(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      chosenSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen_source'],
      )!,
      chosenText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen_text'],
      )!,
      atMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_ms'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
    );
  }

  @override
  $SelectionEventsTable createAlias(String alias) {
    return $SelectionEventsTable(attachedDatabase, alias);
  }
}

class SelectionEvent extends DataClass implements Insertable<SelectionEvent> {
  final int eventId;
  final String projectId;
  final String lineId;
  final String chosenSource;
  final String chosenText;
  final int atMs;
  final String method;
  const SelectionEvent({
    required this.eventId,
    required this.projectId,
    required this.lineId,
    required this.chosenSource,
    required this.chosenText,
    required this.atMs,
    required this.method,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    map['project_id'] = Variable<String>(projectId);
    map['line_id'] = Variable<String>(lineId);
    map['chosen_source'] = Variable<String>(chosenSource);
    map['chosen_text'] = Variable<String>(chosenText);
    map['at_ms'] = Variable<int>(atMs);
    map['method'] = Variable<String>(method);
    return map;
  }

  SelectionEventsCompanion toCompanion(bool nullToAbsent) {
    return SelectionEventsCompanion(
      eventId: Value(eventId),
      projectId: Value(projectId),
      lineId: Value(lineId),
      chosenSource: Value(chosenSource),
      chosenText: Value(chosenText),
      atMs: Value(atMs),
      method: Value(method),
    );
  }

  factory SelectionEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SelectionEvent(
      eventId: serializer.fromJson<int>(json['eventId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      lineId: serializer.fromJson<String>(json['lineId']),
      chosenSource: serializer.fromJson<String>(json['chosenSource']),
      chosenText: serializer.fromJson<String>(json['chosenText']),
      atMs: serializer.fromJson<int>(json['atMs']),
      method: serializer.fromJson<String>(json['method']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'projectId': serializer.toJson<String>(projectId),
      'lineId': serializer.toJson<String>(lineId),
      'chosenSource': serializer.toJson<String>(chosenSource),
      'chosenText': serializer.toJson<String>(chosenText),
      'atMs': serializer.toJson<int>(atMs),
      'method': serializer.toJson<String>(method),
    };
  }

  SelectionEvent copyWith({
    int? eventId,
    String? projectId,
    String? lineId,
    String? chosenSource,
    String? chosenText,
    int? atMs,
    String? method,
  }) => SelectionEvent(
    eventId: eventId ?? this.eventId,
    projectId: projectId ?? this.projectId,
    lineId: lineId ?? this.lineId,
    chosenSource: chosenSource ?? this.chosenSource,
    chosenText: chosenText ?? this.chosenText,
    atMs: atMs ?? this.atMs,
    method: method ?? this.method,
  );
  SelectionEvent copyWithCompanion(SelectionEventsCompanion data) {
    return SelectionEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      chosenSource: data.chosenSource.present
          ? data.chosenSource.value
          : this.chosenSource,
      chosenText: data.chosenText.present
          ? data.chosenText.value
          : this.chosenText,
      atMs: data.atMs.present ? data.atMs.value : this.atMs,
      method: data.method.present ? data.method.value : this.method,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SelectionEvent(')
          ..write('eventId: $eventId, ')
          ..write('projectId: $projectId, ')
          ..write('lineId: $lineId, ')
          ..write('chosenSource: $chosenSource, ')
          ..write('chosenText: $chosenText, ')
          ..write('atMs: $atMs, ')
          ..write('method: $method')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    projectId,
    lineId,
    chosenSource,
    chosenText,
    atMs,
    method,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SelectionEvent &&
          other.eventId == this.eventId &&
          other.projectId == this.projectId &&
          other.lineId == this.lineId &&
          other.chosenSource == this.chosenSource &&
          other.chosenText == this.chosenText &&
          other.atMs == this.atMs &&
          other.method == this.method);
}

class SelectionEventsCompanion extends UpdateCompanion<SelectionEvent> {
  final Value<int> eventId;
  final Value<String> projectId;
  final Value<String> lineId;
  final Value<String> chosenSource;
  final Value<String> chosenText;
  final Value<int> atMs;
  final Value<String> method;
  const SelectionEventsCompanion({
    this.eventId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.chosenSource = const Value.absent(),
    this.chosenText = const Value.absent(),
    this.atMs = const Value.absent(),
    this.method = const Value.absent(),
  });
  SelectionEventsCompanion.insert({
    this.eventId = const Value.absent(),
    required String projectId,
    required String lineId,
    required String chosenSource,
    required String chosenText,
    required int atMs,
    required String method,
  }) : projectId = Value(projectId),
       lineId = Value(lineId),
       chosenSource = Value(chosenSource),
       chosenText = Value(chosenText),
       atMs = Value(atMs),
       method = Value(method);
  static Insertable<SelectionEvent> custom({
    Expression<int>? eventId,
    Expression<String>? projectId,
    Expression<String>? lineId,
    Expression<String>? chosenSource,
    Expression<String>? chosenText,
    Expression<int>? atMs,
    Expression<String>? method,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (projectId != null) 'project_id': projectId,
      if (lineId != null) 'line_id': lineId,
      if (chosenSource != null) 'chosen_source': chosenSource,
      if (chosenText != null) 'chosen_text': chosenText,
      if (atMs != null) 'at_ms': atMs,
      if (method != null) 'method': method,
    });
  }

  SelectionEventsCompanion copyWith({
    Value<int>? eventId,
    Value<String>? projectId,
    Value<String>? lineId,
    Value<String>? chosenSource,
    Value<String>? chosenText,
    Value<int>? atMs,
    Value<String>? method,
  }) {
    return SelectionEventsCompanion(
      eventId: eventId ?? this.eventId,
      projectId: projectId ?? this.projectId,
      lineId: lineId ?? this.lineId,
      chosenSource: chosenSource ?? this.chosenSource,
      chosenText: chosenText ?? this.chosenText,
      atMs: atMs ?? this.atMs,
      method: method ?? this.method,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (chosenSource.present) {
      map['chosen_source'] = Variable<String>(chosenSource.value);
    }
    if (chosenText.present) {
      map['chosen_text'] = Variable<String>(chosenText.value);
    }
    if (atMs.present) {
      map['at_ms'] = Variable<int>(atMs.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SelectionEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('projectId: $projectId, ')
          ..write('lineId: $lineId, ')
          ..write('chosenSource: $chosenSource, ')
          ..write('chosenText: $chosenText, ')
          ..write('atMs: $atMs, ')
          ..write('method: $method')
          ..write(')'))
        .toString();
  }
}

class $SessionLogsTable extends SessionLogs
    with TableInfo<$SessionLogsTable, SessionLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMsMeta = const VerificationMeta(
    'endedAtMs',
  );
  @override
  late final GeneratedColumn<int> endedAtMs = GeneratedColumn<int>(
    'ended_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    projectId,
    deviceId,
    platform,
    startedAtMs,
    endedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('ended_at_ms')) {
      context.handle(
        _endedAtMsMeta,
        endedAtMs.isAcceptableOrUnknown(data['ended_at_ms']!, _endedAtMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionLog(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      endedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_ms'],
      ),
    );
  }

  @override
  $SessionLogsTable createAlias(String alias) {
    return $SessionLogsTable(attachedDatabase, alias);
  }
}

class SessionLog extends DataClass implements Insertable<SessionLog> {
  final String sessionId;
  final String projectId;
  final String deviceId;
  final String platform;
  final int startedAtMs;
  final int? endedAtMs;
  const SessionLog({
    required this.sessionId,
    required this.projectId,
    required this.deviceId,
    required this.platform,
    required this.startedAtMs,
    this.endedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['project_id'] = Variable<String>(projectId);
    map['device_id'] = Variable<String>(deviceId);
    map['platform'] = Variable<String>(platform);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(endedAtMs);
    }
    return map;
  }

  SessionLogsCompanion toCompanion(bool nullToAbsent) {
    return SessionLogsCompanion(
      sessionId: Value(sessionId),
      projectId: Value(projectId),
      deviceId: Value(deviceId),
      platform: Value(platform),
      startedAtMs: Value(startedAtMs),
      endedAtMs: endedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMs),
    );
  }

  factory SessionLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionLog(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      platform: serializer.fromJson<String>(json['platform']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<int?>(json['endedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'projectId': serializer.toJson<String>(projectId),
      'deviceId': serializer.toJson<String>(deviceId),
      'platform': serializer.toJson<String>(platform),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endedAtMs': serializer.toJson<int?>(endedAtMs),
    };
  }

  SessionLog copyWith({
    String? sessionId,
    String? projectId,
    String? deviceId,
    String? platform,
    int? startedAtMs,
    Value<int?> endedAtMs = const Value.absent(),
  }) => SessionLog(
    sessionId: sessionId ?? this.sessionId,
    projectId: projectId ?? this.projectId,
    deviceId: deviceId ?? this.deviceId,
    platform: platform ?? this.platform,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
  );
  SessionLog copyWithCompanion(SessionLogsCompanion data) {
    return SessionLog(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      platform: data.platform.present ? data.platform.value : this.platform,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      endedAtMs: data.endedAtMs.present ? data.endedAtMs.value : this.endedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionLog(')
          ..write('sessionId: $sessionId, ')
          ..write('projectId: $projectId, ')
          ..write('deviceId: $deviceId, ')
          ..write('platform: $platform, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    projectId,
    deviceId,
    platform,
    startedAtMs,
    endedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionLog &&
          other.sessionId == this.sessionId &&
          other.projectId == this.projectId &&
          other.deviceId == this.deviceId &&
          other.platform == this.platform &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs);
}

class SessionLogsCompanion extends UpdateCompanion<SessionLog> {
  final Value<String> sessionId;
  final Value<String> projectId;
  final Value<String> deviceId;
  final Value<String> platform;
  final Value<int> startedAtMs;
  final Value<int?> endedAtMs;
  final Value<int> rowid;
  const SessionLogsCompanion({
    this.sessionId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.platform = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionLogsCompanion.insert({
    required String sessionId,
    required String projectId,
    required String deviceId,
    required String platform,
    required int startedAtMs,
    this.endedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       projectId = Value(projectId),
       deviceId = Value(deviceId),
       platform = Value(platform),
       startedAtMs = Value(startedAtMs);
  static Insertable<SessionLog> custom({
    Expression<String>? sessionId,
    Expression<String>? projectId,
    Expression<String>? deviceId,
    Expression<String>? platform,
    Expression<int>? startedAtMs,
    Expression<int>? endedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (projectId != null) 'project_id': projectId,
      if (deviceId != null) 'device_id': deviceId,
      if (platform != null) 'platform': platform,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endedAtMs != null) 'ended_at_ms': endedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionLogsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? projectId,
    Value<String>? deviceId,
    Value<String>? platform,
    Value<int>? startedAtMs,
    Value<int?>? endedAtMs,
    Value<int>? rowid,
  }) {
    return SessionLogsCompanion(
      sessionId: sessionId ?? this.sessionId,
      projectId: projectId ?? this.projectId,
      deviceId: deviceId ?? this.deviceId,
      platform: platform ?? this.platform,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(endedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionLogsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('projectId: $projectId, ')
          ..write('deviceId: $deviceId, ')
          ..write('platform: $platform, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ProjectFilesTable projectFiles = $ProjectFilesTable(this);
  late final $SubtitleLinesTable subtitleLines = $SubtitleLinesTable(this);
  late final $SelectionEventsTable selectionEvents = $SelectionEventsTable(
    this,
  );
  late final $SessionLogsTable sessionLogs = $SessionLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    projectFiles,
    subtitleLines,
    selectionEvents,
    sessionLogs,
  ];
}

typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String projectId,
      required String title,
      Value<String> folder,
      required int createdAtMs,
      required int updatedAtMs,
      Value<bool> archived,
      required String baseAssPath,
      Value<String> exportMode,
      Value<bool> strictExport,
      Value<int> currentIndex,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> projectId,
      Value<String> title,
      Value<String> folder,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<bool> archived,
      Value<String> baseAssPath,
      Value<String> exportMode,
      Value<bool> strictExport,
      Value<int> currentIndex,
      Value<int> rowid,
    });

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseAssPath => $composableBuilder(
    column: $table.baseAssPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exportMode => $composableBuilder(
    column: $table.exportMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get strictExport => $composableBuilder(
    column: $table.strictExport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseAssPath => $composableBuilder(
    column: $table.baseAssPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exportMode => $composableBuilder(
    column: $table.exportMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get strictExport => $composableBuilder(
    column: $table.strictExport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get baseAssPath => $composableBuilder(
    column: $table.baseAssPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exportMode => $composableBuilder(
    column: $table.exportMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get strictExport => $composableBuilder(
    column: $table.strictExport,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => column,
  );
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
          Project,
          PrefetchHooks Function()
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> baseAssPath = const Value.absent(),
                Value<String> exportMode = const Value.absent(),
                Value<bool> strictExport = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                projectId: projectId,
                title: title,
                folder: folder,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                archived: archived,
                baseAssPath: baseAssPath,
                exportMode: exportMode,
                strictExport: strictExport,
                currentIndex: currentIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required String title,
                Value<String> folder = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<bool> archived = const Value.absent(),
                required String baseAssPath,
                Value<String> exportMode = const Value.absent(),
                Value<bool> strictExport = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                projectId: projectId,
                title: title,
                folder: folder,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                archived: archived,
                baseAssPath: baseAssPath,
                exportMode: exportMode,
                strictExport: strictExport,
                currentIndex: currentIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
      Project,
      PrefetchHooks Function()
    >;
typedef $$ProjectFilesTableCreateCompanionBuilder =
    ProjectFilesCompanion Function({
      required String fileId,
      required String projectId,
      required String engine,
      required String assPath,
      required int importedAtMs,
      Value<int> dialogueCount,
      Value<int> unmatchedCount,
      Value<int> rowid,
    });
typedef $$ProjectFilesTableUpdateCompanionBuilder =
    ProjectFilesCompanion Function({
      Value<String> fileId,
      Value<String> projectId,
      Value<String> engine,
      Value<String> assPath,
      Value<int> importedAtMs,
      Value<int> dialogueCount,
      Value<int> unmatchedCount,
      Value<int> rowid,
    });

class $$ProjectFilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectFilesTable> {
  $$ProjectFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assPath => $composableBuilder(
    column: $table.assPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAtMs => $composableBuilder(
    column: $table.importedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dialogueCount => $composableBuilder(
    column: $table.dialogueCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unmatchedCount => $composableBuilder(
    column: $table.unmatchedCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectFilesTable> {
  $$ProjectFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assPath => $composableBuilder(
    column: $table.assPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAtMs => $composableBuilder(
    column: $table.importedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dialogueCount => $composableBuilder(
    column: $table.dialogueCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unmatchedCount => $composableBuilder(
    column: $table.unmatchedCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectFilesTable> {
  $$ProjectFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get assPath =>
      $composableBuilder(column: $table.assPath, builder: (column) => column);

  GeneratedColumn<int> get importedAtMs => $composableBuilder(
    column: $table.importedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dialogueCount => $composableBuilder(
    column: $table.dialogueCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unmatchedCount => $composableBuilder(
    column: $table.unmatchedCount,
    builder: (column) => column,
  );
}

class $$ProjectFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectFilesTable,
          ProjectFile,
          $$ProjectFilesTableFilterComposer,
          $$ProjectFilesTableOrderingComposer,
          $$ProjectFilesTableAnnotationComposer,
          $$ProjectFilesTableCreateCompanionBuilder,
          $$ProjectFilesTableUpdateCompanionBuilder,
          (
            ProjectFile,
            BaseReferences<_$AppDatabase, $ProjectFilesTable, ProjectFile>,
          ),
          ProjectFile,
          PrefetchHooks Function()
        > {
  $$ProjectFilesTableTableManager(_$AppDatabase db, $ProjectFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fileId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> engine = const Value.absent(),
                Value<String> assPath = const Value.absent(),
                Value<int> importedAtMs = const Value.absent(),
                Value<int> dialogueCount = const Value.absent(),
                Value<int> unmatchedCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectFilesCompanion(
                fileId: fileId,
                projectId: projectId,
                engine: engine,
                assPath: assPath,
                importedAtMs: importedAtMs,
                dialogueCount: dialogueCount,
                unmatchedCount: unmatchedCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileId,
                required String projectId,
                required String engine,
                required String assPath,
                required int importedAtMs,
                Value<int> dialogueCount = const Value.absent(),
                Value<int> unmatchedCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectFilesCompanion.insert(
                fileId: fileId,
                projectId: projectId,
                engine: engine,
                assPath: assPath,
                importedAtMs: importedAtMs,
                dialogueCount: dialogueCount,
                unmatchedCount: unmatchedCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectFilesTable,
      ProjectFile,
      $$ProjectFilesTableFilterComposer,
      $$ProjectFilesTableOrderingComposer,
      $$ProjectFilesTableAnnotationComposer,
      $$ProjectFilesTableCreateCompanionBuilder,
      $$ProjectFilesTableUpdateCompanionBuilder,
      (
        ProjectFile,
        BaseReferences<_$AppDatabase, $ProjectFilesTable, ProjectFile>,
      ),
      ProjectFile,
      PrefetchHooks Function()
    >;
typedef $$SubtitleLinesTableCreateCompanionBuilder =
    SubtitleLinesCompanion Function({
      required String lineId,
      required String projectId,
      required int dialogueIndex,
      required int eventsRowIndex,
      required int startMs,
      required int endMs,
      Value<String?> style,
      Value<String?> name,
      Value<String?> effect,
      Value<String?> sourceText,
      Value<String?> romanization,
      Value<String?> gloss,
      required String dialoguePrefix,
      Value<String> leadingTags,
      Value<bool> hasVectorDrawing,
      required String originalText,
      Value<String?> candGpt,
      Value<String?> candClaude,
      Value<String?> candGemini,
      Value<String?> candDeepseek,
      Value<String?> candVoice,
      Value<String?> selectedSource,
      Value<String?> selectedText,
      Value<bool> reviewed,
      Value<bool> doubt,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$SubtitleLinesTableUpdateCompanionBuilder =
    SubtitleLinesCompanion Function({
      Value<String> lineId,
      Value<String> projectId,
      Value<int> dialogueIndex,
      Value<int> eventsRowIndex,
      Value<int> startMs,
      Value<int> endMs,
      Value<String?> style,
      Value<String?> name,
      Value<String?> effect,
      Value<String?> sourceText,
      Value<String?> romanization,
      Value<String?> gloss,
      Value<String> dialoguePrefix,
      Value<String> leadingTags,
      Value<bool> hasVectorDrawing,
      Value<String> originalText,
      Value<String?> candGpt,
      Value<String?> candClaude,
      Value<String?> candGemini,
      Value<String?> candDeepseek,
      Value<String?> candVoice,
      Value<String?> selectedSource,
      Value<String?> selectedText,
      Value<bool> reviewed,
      Value<bool> doubt,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$SubtitleLinesTableFilterComposer
    extends Composer<_$AppDatabase, $SubtitleLinesTable> {
  $$SubtitleLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dialogueIndex => $composableBuilder(
    column: $table.dialogueIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventsRowIndex => $composableBuilder(
    column: $table.eventsRowIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effect => $composableBuilder(
    column: $table.effect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get romanization => $composableBuilder(
    column: $table.romanization,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gloss => $composableBuilder(
    column: $table.gloss,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dialoguePrefix => $composableBuilder(
    column: $table.dialoguePrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leadingTags => $composableBuilder(
    column: $table.leadingTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasVectorDrawing => $composableBuilder(
    column: $table.hasVectorDrawing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candGpt => $composableBuilder(
    column: $table.candGpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candClaude => $composableBuilder(
    column: $table.candClaude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candGemini => $composableBuilder(
    column: $table.candGemini,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candDeepseek => $composableBuilder(
    column: $table.candDeepseek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candVoice => $composableBuilder(
    column: $table.candVoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedSource => $composableBuilder(
    column: $table.selectedSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reviewed => $composableBuilder(
    column: $table.reviewed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get doubt => $composableBuilder(
    column: $table.doubt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubtitleLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtitleLinesTable> {
  $$SubtitleLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dialogueIndex => $composableBuilder(
    column: $table.dialogueIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventsRowIndex => $composableBuilder(
    column: $table.eventsRowIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effect => $composableBuilder(
    column: $table.effect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get romanization => $composableBuilder(
    column: $table.romanization,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gloss => $composableBuilder(
    column: $table.gloss,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dialoguePrefix => $composableBuilder(
    column: $table.dialoguePrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leadingTags => $composableBuilder(
    column: $table.leadingTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasVectorDrawing => $composableBuilder(
    column: $table.hasVectorDrawing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candGpt => $composableBuilder(
    column: $table.candGpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candClaude => $composableBuilder(
    column: $table.candClaude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candGemini => $composableBuilder(
    column: $table.candGemini,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candDeepseek => $composableBuilder(
    column: $table.candDeepseek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candVoice => $composableBuilder(
    column: $table.candVoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedSource => $composableBuilder(
    column: $table.selectedSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reviewed => $composableBuilder(
    column: $table.reviewed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get doubt => $composableBuilder(
    column: $table.doubt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubtitleLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtitleLinesTable> {
  $$SubtitleLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<int> get dialogueIndex => $composableBuilder(
    column: $table.dialogueIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eventsRowIndex => $composableBuilder(
    column: $table.eventsRowIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get effect =>
      $composableBuilder(column: $table.effect, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get romanization => $composableBuilder(
    column: $table.romanization,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gloss =>
      $composableBuilder(column: $table.gloss, builder: (column) => column);

  GeneratedColumn<String> get dialoguePrefix => $composableBuilder(
    column: $table.dialoguePrefix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leadingTags => $composableBuilder(
    column: $table.leadingTags,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasVectorDrawing => $composableBuilder(
    column: $table.hasVectorDrawing,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get candGpt =>
      $composableBuilder(column: $table.candGpt, builder: (column) => column);

  GeneratedColumn<String> get candClaude => $composableBuilder(
    column: $table.candClaude,
    builder: (column) => column,
  );

  GeneratedColumn<String> get candGemini => $composableBuilder(
    column: $table.candGemini,
    builder: (column) => column,
  );

  GeneratedColumn<String> get candDeepseek => $composableBuilder(
    column: $table.candDeepseek,
    builder: (column) => column,
  );

  GeneratedColumn<String> get candVoice =>
      $composableBuilder(column: $table.candVoice, builder: (column) => column);

  GeneratedColumn<String> get selectedSource => $composableBuilder(
    column: $table.selectedSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reviewed =>
      $composableBuilder(column: $table.reviewed, builder: (column) => column);

  GeneratedColumn<bool> get doubt =>
      $composableBuilder(column: $table.doubt, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$SubtitleLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtitleLinesTable,
          SubtitleLine,
          $$SubtitleLinesTableFilterComposer,
          $$SubtitleLinesTableOrderingComposer,
          $$SubtitleLinesTableAnnotationComposer,
          $$SubtitleLinesTableCreateCompanionBuilder,
          $$SubtitleLinesTableUpdateCompanionBuilder,
          (
            SubtitleLine,
            BaseReferences<_$AppDatabase, $SubtitleLinesTable, SubtitleLine>,
          ),
          SubtitleLine,
          PrefetchHooks Function()
        > {
  $$SubtitleLinesTableTableManager(_$AppDatabase db, $SubtitleLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtitleLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtitleLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtitleLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> lineId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> dialogueIndex = const Value.absent(),
                Value<int> eventsRowIndex = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String?> style = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> effect = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<String?> romanization = const Value.absent(),
                Value<String?> gloss = const Value.absent(),
                Value<String> dialoguePrefix = const Value.absent(),
                Value<String> leadingTags = const Value.absent(),
                Value<bool> hasVectorDrawing = const Value.absent(),
                Value<String> originalText = const Value.absent(),
                Value<String?> candGpt = const Value.absent(),
                Value<String?> candClaude = const Value.absent(),
                Value<String?> candGemini = const Value.absent(),
                Value<String?> candDeepseek = const Value.absent(),
                Value<String?> candVoice = const Value.absent(),
                Value<String?> selectedSource = const Value.absent(),
                Value<String?> selectedText = const Value.absent(),
                Value<bool> reviewed = const Value.absent(),
                Value<bool> doubt = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtitleLinesCompanion(
                lineId: lineId,
                projectId: projectId,
                dialogueIndex: dialogueIndex,
                eventsRowIndex: eventsRowIndex,
                startMs: startMs,
                endMs: endMs,
                style: style,
                name: name,
                effect: effect,
                sourceText: sourceText,
                romanization: romanization,
                gloss: gloss,
                dialoguePrefix: dialoguePrefix,
                leadingTags: leadingTags,
                hasVectorDrawing: hasVectorDrawing,
                originalText: originalText,
                candGpt: candGpt,
                candClaude: candClaude,
                candGemini: candGemini,
                candDeepseek: candDeepseek,
                candVoice: candVoice,
                selectedSource: selectedSource,
                selectedText: selectedText,
                reviewed: reviewed,
                doubt: doubt,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lineId,
                required String projectId,
                required int dialogueIndex,
                required int eventsRowIndex,
                required int startMs,
                required int endMs,
                Value<String?> style = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> effect = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<String?> romanization = const Value.absent(),
                Value<String?> gloss = const Value.absent(),
                required String dialoguePrefix,
                Value<String> leadingTags = const Value.absent(),
                Value<bool> hasVectorDrawing = const Value.absent(),
                required String originalText,
                Value<String?> candGpt = const Value.absent(),
                Value<String?> candClaude = const Value.absent(),
                Value<String?> candGemini = const Value.absent(),
                Value<String?> candDeepseek = const Value.absent(),
                Value<String?> candVoice = const Value.absent(),
                Value<String?> selectedSource = const Value.absent(),
                Value<String?> selectedText = const Value.absent(),
                Value<bool> reviewed = const Value.absent(),
                Value<bool> doubt = const Value.absent(),
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => SubtitleLinesCompanion.insert(
                lineId: lineId,
                projectId: projectId,
                dialogueIndex: dialogueIndex,
                eventsRowIndex: eventsRowIndex,
                startMs: startMs,
                endMs: endMs,
                style: style,
                name: name,
                effect: effect,
                sourceText: sourceText,
                romanization: romanization,
                gloss: gloss,
                dialoguePrefix: dialoguePrefix,
                leadingTags: leadingTags,
                hasVectorDrawing: hasVectorDrawing,
                originalText: originalText,
                candGpt: candGpt,
                candClaude: candClaude,
                candGemini: candGemini,
                candDeepseek: candDeepseek,
                candVoice: candVoice,
                selectedSource: selectedSource,
                selectedText: selectedText,
                reviewed: reviewed,
                doubt: doubt,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubtitleLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtitleLinesTable,
      SubtitleLine,
      $$SubtitleLinesTableFilterComposer,
      $$SubtitleLinesTableOrderingComposer,
      $$SubtitleLinesTableAnnotationComposer,
      $$SubtitleLinesTableCreateCompanionBuilder,
      $$SubtitleLinesTableUpdateCompanionBuilder,
      (
        SubtitleLine,
        BaseReferences<_$AppDatabase, $SubtitleLinesTable, SubtitleLine>,
      ),
      SubtitleLine,
      PrefetchHooks Function()
    >;
typedef $$SelectionEventsTableCreateCompanionBuilder =
    SelectionEventsCompanion Function({
      Value<int> eventId,
      required String projectId,
      required String lineId,
      required String chosenSource,
      required String chosenText,
      required int atMs,
      required String method,
    });
typedef $$SelectionEventsTableUpdateCompanionBuilder =
    SelectionEventsCompanion Function({
      Value<int> eventId,
      Value<String> projectId,
      Value<String> lineId,
      Value<String> chosenSource,
      Value<String> chosenText,
      Value<int> atMs,
      Value<String> method,
    });

class $$SelectionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SelectionEventsTable> {
  $$SelectionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chosenSource => $composableBuilder(
    column: $table.chosenSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chosenText => $composableBuilder(
    column: $table.chosenText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SelectionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SelectionEventsTable> {
  $$SelectionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosenSource => $composableBuilder(
    column: $table.chosenSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosenText => $composableBuilder(
    column: $table.chosenText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SelectionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SelectionEventsTable> {
  $$SelectionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get chosenSource => $composableBuilder(
    column: $table.chosenSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chosenText => $composableBuilder(
    column: $table.chosenText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get atMs =>
      $composableBuilder(column: $table.atMs, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);
}

class $$SelectionEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SelectionEventsTable,
          SelectionEvent,
          $$SelectionEventsTableFilterComposer,
          $$SelectionEventsTableOrderingComposer,
          $$SelectionEventsTableAnnotationComposer,
          $$SelectionEventsTableCreateCompanionBuilder,
          $$SelectionEventsTableUpdateCompanionBuilder,
          (
            SelectionEvent,
            BaseReferences<
              _$AppDatabase,
              $SelectionEventsTable,
              SelectionEvent
            >,
          ),
          SelectionEvent,
          PrefetchHooks Function()
        > {
  $$SelectionEventsTableTableManager(
    _$AppDatabase db,
    $SelectionEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SelectionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SelectionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SelectionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> lineId = const Value.absent(),
                Value<String> chosenSource = const Value.absent(),
                Value<String> chosenText = const Value.absent(),
                Value<int> atMs = const Value.absent(),
                Value<String> method = const Value.absent(),
              }) => SelectionEventsCompanion(
                eventId: eventId,
                projectId: projectId,
                lineId: lineId,
                chosenSource: chosenSource,
                chosenText: chosenText,
                atMs: atMs,
                method: method,
              ),
          createCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                required String projectId,
                required String lineId,
                required String chosenSource,
                required String chosenText,
                required int atMs,
                required String method,
              }) => SelectionEventsCompanion.insert(
                eventId: eventId,
                projectId: projectId,
                lineId: lineId,
                chosenSource: chosenSource,
                chosenText: chosenText,
                atMs: atMs,
                method: method,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SelectionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SelectionEventsTable,
      SelectionEvent,
      $$SelectionEventsTableFilterComposer,
      $$SelectionEventsTableOrderingComposer,
      $$SelectionEventsTableAnnotationComposer,
      $$SelectionEventsTableCreateCompanionBuilder,
      $$SelectionEventsTableUpdateCompanionBuilder,
      (
        SelectionEvent,
        BaseReferences<_$AppDatabase, $SelectionEventsTable, SelectionEvent>,
      ),
      SelectionEvent,
      PrefetchHooks Function()
    >;
typedef $$SessionLogsTableCreateCompanionBuilder =
    SessionLogsCompanion Function({
      required String sessionId,
      required String projectId,
      required String deviceId,
      required String platform,
      required int startedAtMs,
      Value<int?> endedAtMs,
      Value<int> rowid,
    });
typedef $$SessionLogsTableUpdateCompanionBuilder =
    SessionLogsCompanion Function({
      Value<String> sessionId,
      Value<String> projectId,
      Value<String> deviceId,
      Value<String> platform,
      Value<int> startedAtMs,
      Value<int?> endedAtMs,
      Value<int> rowid,
    });

class $$SessionLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMs =>
      $composableBuilder(column: $table.endedAtMs, builder: (column) => column);
}

class $$SessionLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionLogsTable,
          SessionLog,
          $$SessionLogsTableFilterComposer,
          $$SessionLogsTableOrderingComposer,
          $$SessionLogsTableAnnotationComposer,
          $$SessionLogsTableCreateCompanionBuilder,
          $$SessionLogsTableUpdateCompanionBuilder,
          (
            SessionLog,
            BaseReferences<_$AppDatabase, $SessionLogsTable, SessionLog>,
          ),
          SessionLog,
          PrefetchHooks Function()
        > {
  $$SessionLogsTableTableManager(_$AppDatabase db, $SessionLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int?> endedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionLogsCompanion(
                sessionId: sessionId,
                projectId: projectId,
                deviceId: deviceId,
                platform: platform,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String projectId,
                required String deviceId,
                required String platform,
                required int startedAtMs,
                Value<int?> endedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionLogsCompanion.insert(
                sessionId: sessionId,
                projectId: projectId,
                deviceId: deviceId,
                platform: platform,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionLogsTable,
      SessionLog,
      $$SessionLogsTableFilterComposer,
      $$SessionLogsTableOrderingComposer,
      $$SessionLogsTableAnnotationComposer,
      $$SessionLogsTableCreateCompanionBuilder,
      $$SessionLogsTableUpdateCompanionBuilder,
      (
        SessionLog,
        BaseReferences<_$AppDatabase, $SessionLogsTable, SessionLog>,
      ),
      SessionLog,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ProjectFilesTableTableManager get projectFiles =>
      $$ProjectFilesTableTableManager(_db, _db.projectFiles);
  $$SubtitleLinesTableTableManager get subtitleLines =>
      $$SubtitleLinesTableTableManager(_db, _db.subtitleLines);
  $$SelectionEventsTableTableManager get selectionEvents =>
      $$SelectionEventsTableTableManager(_db, _db.selectionEvents);
  $$SessionLogsTableTableManager get sessionLogs =>
      $$SessionLogsTableTableManager(_db, _db.sessionLogs);
}

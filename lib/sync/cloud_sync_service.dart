import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show InsertMode, Value, Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/app_db.dart';
import 'supabase_manager.dart';
import 'sync_prefs.dart';
import '../settings/settings_service.dart';

class CloudSyncException implements Exception {
  CloudSyncException({
    required this.code,
    required this.userMessage,
    this.debugMessage,
    this.cause,
  });

  final String code;
  final String userMessage;
  final String? debugMessage;
  final Object? cause;

  CloudSyncException withContext(String context) {
    final prefix = context.trim();
    if (prefix.isEmpty) return this;
    return CloudSyncException(
      code: code,
      userMessage: '$prefix: $userMessage',
      debugMessage: debugMessage,
      cause: cause,
    );
  }

  @override
  String toString() =>
      'CloudSyncException(code: $code, userMessage: $userMessage, debug: ${debugMessage ?? '-'})';
}

/// Sincroniza proyectos con Supabase (BD) y R2/Supabase Storage (ficheros).
class CloudSyncService {
  CloudSyncService(this.db);

  final AppDatabase db;
  final _supabase = SupabaseManager.instance;
  final _prefs = SyncPrefs();
  bool _supportsFolderColumn = true;
  bool _supportsArchivedColumn = true;
  bool _supportsOwnerColumnProjects = true;
  bool _supportsOwnerColumnFiles = true;
  bool _supportsOwnerColumnLines = true;
  final Map<String, _DirtyCacheEntry> _dirtyCache = {};
  Map<String, String> _fileEnv = const {};
  bool _fileEnvLoaded = false;
  Future<void>? _fileEnvLoading;

  static const _bucket = 'voicex';

  bool get isReady => _supabase.isReady;
  bool get isR2Available => _r2Config != null;
  bool get hasR2PublicBase =>
      _r2Config?.publicBase?.trim().isNotEmpty == true;
  String? get r2Bucket => _r2Config?.bucket;
  String? get r2PublicBase => _r2Config?.publicBase;
  SupabaseClient get _client => Supabase.instance.client;
  String? get _ownerUserId => _supabase.userId;

  Future<void> ensureInit() async {
    await _supabase.init();
    await _ensureR2EnvLoaded();
  }

  Future<void> syncSettingsOnly() async {
    if (!isReady) return;
    await _syncSettings();
  }

  Future<bool> isProjectDirty(String projectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _dirtyCache[projectId];
    if (cached != null && (now - cached.checkedAtMs) < 5000) {
      return cached.isDirty;
    }

    final last = await _prefs.getLastSynced(projectId);
    final proj = await (db.select(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).getSingleOrNull();
    if (proj == null) return false;
    final linesMax = await db
        .customSelect(
          'SELECT MAX(updated_at_ms) AS m FROM subtitle_lines WHERE project_id = ?',
          variables: [Variable<String>(projectId)],
          readsFrom: {db.subtitleLines},
        )
        .getSingleOrNull();
    final maxLine = linesMax == null ? 0 : (linesMax.data['m'] as int? ?? 0);
    final localUpdated = [
      proj.updatedAtMs,
      maxLine,
    ].reduce((a, b) => a > b ? a : b);
    final result = last == null || localUpdated > last;
    _dirtyCache[projectId] = _DirtyCacheEntry(
      checkedAtMs: now,
      isDirty: result,
    );
    return result;
  }

  Future<int?> lastSyncedAt(String projectId) =>
      _prefs.getLastSynced(projectId);

  Future<List<Map<String, dynamic>>> listRemoteProjects() async {
    if (!isReady) return [];
    Future<List<Map<String, dynamic>>> selectRemote({
      required bool withFolder,
      required bool withArchived,
    }) async {
      final cols = [
        'project_id',
        'title',
        if (withFolder) 'folder',
        if (withArchived) 'archived',
        'created_at_ms',
        'updated_at_ms',
      ];
      final columns = cols.join(',');
      final res = await _client
          .from('projects')
          .select(columns)
          .order('updated_at_ms', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    }

    try {
      return await selectRemote(
        withFolder: _supportsFolderColumn,
        withArchived: _supportsArchivedColumn,
      );
    } on PostgrestException catch (e) {
      final missingFolder =
          _supportsFolderColumn &&
          (e.code == 'PGRST204' ||
              e.code == '42703' ||
              e.message.contains('folder'));
      final missingArchived =
          _supportsArchivedColumn &&
          (e.code == 'PGRST204' ||
              e.code == '42703' ||
              e.message.contains('archived'));
      if (missingFolder) _supportsFolderColumn = false;
      if (missingArchived) _supportsArchivedColumn = false;
      if (missingFolder || missingArchived) {
        try {
          return await selectRemote(
            withFolder: _supportsFolderColumn,
            withArchived: _supportsArchivedColumn,
          );
        } catch (_) {}
      }
      debugPrint('listRemoteProjects error: $e');
      return [];
    } catch (e) {
      debugPrint('listRemoteProjects error: $e');
      try {
        return await selectRemote(withFolder: false, withArchived: false);
      } catch (_) {}
      return [];
    }
  }

  Future<void> deleteRemoteProject(String projectId) async {
    if (!isReady) return;
    try {
      await _client
          .from('selection_events')
          .delete()
          .eq('project_id', projectId);
      await _client.from('subtitle_lines').delete().eq('project_id', projectId);
      await _client.from('project_files').delete().eq('project_id', projectId);
      await _client.from('projects').delete().eq('project_id', projectId);
    } catch (e) {
      debugPrint('deleteRemoteProject error: $e');
    }
  }

  /// Sincronización bidireccional: sube lo local más nuevo y baja lo remoto más nuevo.
  Future<void> syncAllProjects({
    void Function(double value, String stage)? onProgress,
  }) async {
    if (!isReady) {
      throw CloudSyncException(
        code: 'supabase_not_ready',
        userMessage: 'Supabase no está disponible (configuración o sesión).',
      );
    }
    try {
      await _syncSettings(onProgress: onProgress);
      final remote = await listRemoteProjects();
      final remoteById = <String, Map<String, dynamic>>{
        for (final m in remote) (m['project_id'] as String): m,
      };
      final remoteIds = remoteById.keys.toSet();
      var localRows = await db.select(db.projects).get();
      var localIds = localRows.map((p) => p.projectId).toSet();

      final settings = SettingsService.instance;
      final deleted = settings.deletedProjects;
      if (deleted.isNotEmpty) {
        final deletedIds = deleted.keys.toSet();
        for (final id in deletedIds.intersection(localIds)) {
          await _deleteLocalProject(id);
        }
        for (final id in deletedIds.intersection(remoteIds)) {
          await deleteRemoteProject(id);
        }
        if (deletedIds.isNotEmpty) {
          localRows = localRows.where((p) => !deletedIds.contains(p.projectId)).toList();
          localIds = localRows.map((p) => p.projectId).toSet();
          for (final id in deletedIds) {
            remoteById.remove(id);
          }
        }
      }
      final remoteIdsFiltered = remoteById.keys.toSet();

      final totalOps = remoteIdsFiltered.union(localIds).length;
      double done = 0;
      void bump(String stage) {
        done += 1;
        final denom = totalOps == 0 ? 1 : totalOps;
        onProgress?.call((done / denom).clamp(0, 1), stage);
      }

      for (final local in localRows) {
        final remoteEntry = remoteById[local.projectId];
        final remoteUpdated = remoteEntry?['updated_at_ms'] as int? ?? 0;
        try {
          if (remoteEntry == null) {
            await pushProject(local.projectId, onProgress: onProgress);
            bump('Subiendo (solo local) ${local.projectId}');
          } else if (local.updatedAtMs > remoteUpdated) {
            await pushProject(local.projectId, onProgress: onProgress);
            bump('Subiendo ${local.projectId}');
          } else if (remoteUpdated > local.updatedAtMs) {
            await pullProject(local.projectId, onProgress: onProgress);
            bump('Descargando ${local.projectId}');
          } else {
            bump('Sin cambios ${local.projectId}');
          }
        } on CloudSyncException catch (e) {
          throw e.withContext(
            'Proyecto "${local.title}" (${local.projectId})',
          );
        }
      }

      for (final id in remoteIdsFiltered.difference(localIds)) {
        try {
          await pullProject(id, onProgress: onProgress);
          bump('Descargando $id');
        } on CloudSyncException catch (e) {
          throw e.withContext('Proyecto remoto ($id)');
        }
      }
    } on CloudSyncException {
      rethrow;
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'sincronizar con cloud',
        debugContext: 'syncAllProjects',
      );
    }
  }

  Future<bool> pushProject(
    String projectId, {
    void Function(double value, String stage)? onProgress,
  }) async {
    if (!isReady) {
      throw CloudSyncException(
        code: 'supabase_not_ready',
        userMessage: 'Supabase no está disponible (configuración o sesión).',
      );
    }
    await _ensureR2EnvLoaded();
    try {
      final project = await (db.select(
        db.projects,
      )..where((t) => t.projectId.equals(projectId))).getSingle();
      final lines = await (db.select(
        db.subtitleLines,
      )..where((t) => t.projectId.equals(projectId))).get();
      final files = await (db.select(
        db.projectFiles,
      )..where((t) => t.projectId.equals(projectId))).get();

      debugPrint('[cloud] pushProject $projectId');
      onProgress?.call(0.1, 'Preparando subida');

      final remotePaths = <String, String>{}; // fileId -> remote url
      for (final f in files.where((f) => f.engine == 'video')) {
        // 1) Si hay URL, la reusamos (rebased).
        if (_looksLikeUrl(f.assPath)) {
          final rebased = _rebaseR2Url(f.assPath);
          final url = rebased ?? f.assPath;
          debugPrint('[cloud] reuse video url ${f.assPath} -> $url');
          remotePaths[f.fileId] = url;
          await _setLocalFilePath(f.fileId, url);
          continue;
        }
        onProgress?.call(0.2, 'Subiendo video');
        final uploaded = await _uploadFileToCloud(f);
        final rebased = _rebaseR2Url(uploaded) ?? uploaded;
        remotePaths[f.fileId] = rebased;
        await _setLocalFilePath(f.fileId, rebased);
        debugPrint('[cloud] uploaded video: $rebased');
      }

      for (final f in files.where((f) => f.engine != 'video')) {
        final uploaded = await _uploadFileToCloud(f);
        final rebased = _rebaseR2Url(uploaded);
        if (rebased != null) {
          debugPrint(
            '[cloud] rebase uploaded ${f.engine}: $uploaded -> $rebased',
          );
          remotePaths[f.fileId] = rebased;
        } else {
          remotePaths[f.fileId] = uploaded;
        }
      }

      onProgress?.call(0.35, 'Subiendo ficheros');
      final baseRemote = remotePaths[_baseFileId(files)];

      var projectMap = _mapProject(project, assPathOverride: baseRemote);
      if (!_supportsFolderColumn) {
        projectMap = Map<String, dynamic>.from(projectMap)..remove('folder');
      }

      try {
        await _client.from('projects').upsert(projectMap);
      } on PostgrestException catch (e) {
        debugPrint('upsert projects error: $e');
        final missingFolder =
            _supportsFolderColumn && _isMissingColumn(e, 'folder');
        final missingArchived =
            _supportsArchivedColumn && _isMissingColumn(e, 'archived');
        final missingOwner =
            _supportsOwnerColumnProjects &&
            _isMissingColumn(e, 'owner_user_id');
        if (missingFolder) _supportsFolderColumn = false;
        if (missingArchived) _supportsArchivedColumn = false;
        if (missingOwner) _supportsOwnerColumnProjects = false;

        if (missingFolder || missingArchived || missingOwner) {
          final fallback = Map<String, dynamic>.from(projectMap);
          if (!_supportsFolderColumn) fallback.remove('folder');
          if (!_supportsArchivedColumn) fallback.remove('archived');
          if (!_supportsOwnerColumnProjects) fallback.remove('owner_user_id');
          await _client.from('projects').upsert(fallback);
        } else {
          rethrow;
        }
      }
      onProgress?.call(0.5, 'Guardando ficheros');
      if (files.isNotEmpty) {
        final mapped = <Map<String, dynamic>>[];
        for (final f in files) {
          final override = remotePaths[f.fileId];
          if (f.engine == 'video' && !_looksLikeUrl(override ?? f.assPath)) {
            // Evita escribir rutas locales de Android/Windows en cloud.
            continue;
          }
          mapped.add(_mapFile(f, assPathOverride: override));
        }
        if (mapped.isNotEmpty) {
          try {
            await _client
                .from('project_files')
                .upsert(mapped, onConflict: 'project_id,engine');
          } on PostgrestException catch (e) {
            if (_supportsOwnerColumnFiles &&
                _isMissingColumn(e, 'owner_user_id')) {
              _supportsOwnerColumnFiles = false;
              for (final m in mapped) {
                m.remove('owner_user_id');
              }
              await _client
                  .from('project_files')
                  .upsert(mapped, onConflict: 'project_id,engine');
            } else {
              rethrow;
            }
          }
        }
      }
      await _uploadProjectMeta(project.projectId, {
        'folder': project.folder,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      onProgress?.call(0.7, 'Guardando lineas');
      await _upsertLinesInBatches(lines);
      onProgress?.call(1.0, 'Completado');

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setLastSynced(projectId, nowMs);
      await (db.update(db.projects)
            ..where((t) => t.projectId.equals(projectId)))
          .write(ProjectsCompanion(updatedAtMs: Value(nowMs)));
      _dirtyCache[projectId] = _DirtyCacheEntry(
        checkedAtMs: nowMs,
        isDirty: false,
      );
      return true;
    } on CloudSyncException {
      rethrow;
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'subir el proyecto a cloud',
        debugContext: 'pushProject($projectId)',
      );
    }
  }

  Future<void> _syncSettings({
    void Function(double value, String stage)? onProgress,
  }) async {
    try {
      final settings = SettingsService.instance;
      await settings.init();
      final local = settings.exportSyncPayload();
      final remote = await _downloadSettingsPayload();

      if (remote == null) {
        await _uploadSettingsPayload(local);
        onProgress?.call(0.05, 'Ajustes subidos');
        return;
      }

      final remoteUpdated = remote['updated_at_ms'] as int? ?? 0;
      final localUpdated = local['updated_at_ms'] as int? ?? 0;
      final remoteFoldersUpdated =
          remote['manual_folders_updated_at_ms'] as int? ?? remoteUpdated;
      final localFoldersUpdated =
          local['manual_folders_updated_at_ms'] as int? ?? localUpdated;
      final remoteDeletedUpdated =
          remote['deleted_projects_updated_at_ms'] as int? ?? remoteUpdated;
      final localDeletedUpdated =
          local['deleted_projects_updated_at_ms'] as int? ?? localUpdated;
      final remoteFolders =
          (remote['manual_folders'] as List?)?.cast<String>() ??
          const <String>[];
      final localFolders =
          (local['manual_folders'] as List?)?.cast<String>() ??
          const <String>[];
      final remoteDeletedRaw =
          (remote['deleted_projects'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final localDeletedRaw =
          (local['deleted_projects'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final remoteDeleted = remoteDeletedRaw.map(
        (k, v) => MapEntry(k, (v as int?) ?? 0),
      );
      final localDeleted = localDeletedRaw.map(
        (k, v) => MapEntry(k, (v as int?) ?? 0),
      );

      final useRemoteGeneral = remoteUpdated > localUpdated;
      final useRemoteFolders = remoteFoldersUpdated > localFoldersUpdated;

      if (useRemoteGeneral) {
        final applied = await settings.importSyncPayload(
          remote,
          includeManualFolders: useRemoteFolders,
          includeDeletedProjects: false,
        );
        if (applied) {
          onProgress?.call(0.05, 'Ajustes sincronizados');
        }
      } else if (useRemoteFolders) {
        await settings.setManualFoldersFromSync(
          remoteFolders,
          remoteFoldersUpdated,
        );
        onProgress?.call(0.05, 'Carpetas sincronizadas');
      }

      final mergedDeleted = <String, int>{};
      for (final entry in remoteDeleted.entries) {
        mergedDeleted[entry.key] = entry.value;
      }
      for (final entry in localDeleted.entries) {
        final existing = mergedDeleted[entry.key] ?? 0;
        if (entry.value >= existing) {
          mergedDeleted[entry.key] = entry.value;
        }
      }
      final mergedDeletedUpdated = [
        localDeletedUpdated,
        remoteDeletedUpdated,
      ].reduce((a, b) => a > b ? a : b);
      final deletedChangedLocal = !_sameDeletedMap(mergedDeleted, localDeleted);
      if (deletedChangedLocal) {
        await settings.setDeletedProjectsFromSync(
          mergedDeleted,
          mergedDeletedUpdated,
        );
        onProgress?.call(0.05, 'Borrados sincronizados');
      }

      final shouldUpload =
          remoteUpdated < localUpdated ||
          remoteFoldersUpdated < localFoldersUpdated ||
          !_sameDeletedMap(mergedDeleted, remoteDeleted);
      if (shouldUpload) {
        final merged = settings.exportSyncPayload();
        if (useRemoteFolders) {
          merged['manual_folders'] = remoteFolders;
          merged['manual_folders_updated_at_ms'] = remoteFoldersUpdated;
        } else {
          merged['manual_folders'] = localFolders;
          merged['manual_folders_updated_at_ms'] = localFoldersUpdated;
        }
        merged['deleted_projects'] = mergedDeleted;
        merged['deleted_projects_updated_at_ms'] = mergedDeletedUpdated;
        await _uploadSettingsPayload(merged);
        onProgress?.call(0.05, 'Ajustes subidos');
      }
    } on CloudSyncException {
      rethrow;
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'sincronizar ajustes de cloud',
        debugContext: '_syncSettings',
      );
    }
  }

  bool _sameDeletedMap(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> _deleteLocalProject(String projectId) async {
    await (db.delete(db.selectionEvents)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (db.delete(db.subtitleLines)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (db.delete(db.projectFiles)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (db.delete(db.projects)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
  }

  Future<void> pullProject(
    String projectId, {
    void Function(double value, String stage)? onProgress,
  }) async {
    if (!isReady) {
      throw CloudSyncException(
        code: 'supabase_not_ready',
        userMessage: 'Supabase no está disponible (configuración o sesión).',
      );
    }
    await _ensureR2EnvLoaded();
    try {
      final existingFiles = await (db.select(
        db.projectFiles,
      )..where((t) => t.projectId.equals(projectId))).get();
      final existingByEngine = {for (final f in existingFiles) f.engine: f};

      final projRes = await _client
          .from('projects')
          .select()
          .eq('project_id', projectId)
          .maybeSingle();
      onProgress?.call(0.1, 'Proyecto');
      final filesRes = await _client
          .from('project_files')
          .select()
          .eq('project_id', projectId);

      String? baseLocalPath;
      final filesList = (filesRes as List).cast<Map<String, dynamic>>();
      for (final m in filesList) {
        final engine = (m['engine'] as String?) ?? '';
        final remotePath = m['ass_path'] as String? ?? '';

        // Evita sobrescribir con rutas locales ajenas (Android -> Windows).
        if (engine == 'video' && !_looksLikeUrl(remotePath)) {
          final existing = existingByEngine[engine];
          if (existing != null && await File(existing.assPath).exists()) {
            m['ass_path'] = existing.assPath;
            await _upsertFileLocal(m);
          } else {
            // Mantén vacío; el usuario deberá volver a subir el vídeo desde un dispositivo con URL pública.
            m['ass_path'] = '';
            await _upsertFileLocal(m);
            debugPrint('[cloud] skip video path (no URL) para $projectId');
          }
          continue;
        }
        if (engine == 'video' && _looksLikeUrl(remotePath)) {
          m['ass_path'] = remotePath; // streaming, no se descarga
          await _upsertFileLocal(m);
          continue;
        }

        final localPath = await _materializeFile(
          projectId,
          engine,
          remotePath,
          onProgress: (v) =>
              onProgress?.call(0.1 + v * 0.6, 'Descargando $engine'),
        );
        if (localPath != null) {
          m['ass_path'] = localPath;
          if (engine == 'base') baseLocalPath = localPath;
        }
        await _upsertFileLocal(m);
      }
      onProgress?.call(0.75, 'Archivos listos');

      if (projRes != null) {
        final map = Map<String, dynamic>.from(projRes);
        var folder = (map['folder'] as String? ?? '').trim();
        if (folder.isEmpty) {
          final meta = await _downloadProjectMeta(projectId);
          folder = (meta?['folder'] as String? ?? '').trim();
          if (folder.isNotEmpty) {
            map['folder'] = folder;
          }
        }
        if (baseLocalPath != null) {
          map['base_ass_path'] = baseLocalPath;
        } else {
          final fallback = map['base_ass_path'] as String? ?? '';
          final localBase = await _materializeFile(projectId, 'base', fallback);
          if (localBase != null) map['base_ass_path'] = localBase;
        }
        await _upsertProjectLocal(map);
      }

      final linesList = await _fetchAllSubtitleLines(projectId);
      for (final m in linesList) {
        await _upsertLineLocal(m);
      }
      onProgress?.call(1.0, 'Completado');

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setLastSynced(projectId, nowMs);
      _dirtyCache[projectId] = _DirtyCacheEntry(
        checkedAtMs: nowMs,
        isDirty: false,
      );
    } on CloudSyncException {
      rethrow;
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'descargar el proyecto desde cloud',
        debugContext: 'pullProject($projectId)',
      );
    }
  }

  Map<String, dynamic> _mapProject(
    Project p, {
    String? assPathOverride,
  }) {
    final map = <String, dynamic>{
      'project_id': p.projectId,
      'title': p.title,
      'folder': p.folder,
      'archived': p.archived,
      'created_at_ms': p.createdAtMs,
      'updated_at_ms': p.updatedAtMs,
      'base_ass_path': assPathOverride ?? p.baseAssPath,
      'export_mode': p.exportMode,
      'strict_export': p.strictExport,
      'current_index': p.currentIndex,
    };
    final ownerId = _ownerUserId;
    if (_supportsOwnerColumnProjects && ownerId != null && ownerId.isNotEmpty) {
      map['owner_user_id'] = ownerId;
    }
    return map;
  }

  Map<String, dynamic> _mapFile(ProjectFile f, {String? assPathOverride}) {
    final map = <String, dynamic>{
      'file_id': f.fileId,
      'project_id': f.projectId,
      'engine': f.engine,
      'ass_path': assPathOverride ?? f.assPath,
      'imported_at_ms': f.importedAtMs,
      'dialogue_count': f.dialogueCount,
      'unmatched_count': f.unmatchedCount,
    };
    final ownerId = _ownerUserId;
    if (_supportsOwnerColumnFiles && ownerId != null && ownerId.isNotEmpty) {
      map['owner_user_id'] = ownerId;
    }
    return map;
  }

  Map<String, dynamic> _mapLine(SubtitleLine l) {
    final map = <String, dynamic>{
      'line_id': l.lineId,
      'project_id': l.projectId,
      'dialogue_index': l.dialogueIndex,
      'events_row_index': l.eventsRowIndex,
      'start_ms': l.startMs,
      'end_ms': l.endMs,
      'style': l.style,
      'name': l.name,
      'effect': l.effect,
      'source_text': l.sourceText,
      'romanization': l.romanization,
      'gloss': l.gloss,
      'dialogue_prefix': l.dialoguePrefix,
      'leading_tags': l.leadingTags,
      'has_vector_drawing': l.hasVectorDrawing,
      'original_text': l.originalText,
      'cand_gpt': l.candGpt,
      'cand_claude': l.candClaude,
      'cand_gemini': l.candGemini,
      'cand_deepseek': l.candDeepseek,
      'cand_voice': l.candVoice,
      'selected_source': l.selectedSource,
      'selected_text': l.selectedText,
      'reviewed': l.reviewed,
      'doubt': l.doubt,
      'updated_at_ms': l.updatedAtMs,
    };
    final ownerId = _ownerUserId;
    if (_supportsOwnerColumnLines && ownerId != null && ownerId.isNotEmpty) {
      map['owner_user_id'] = ownerId;
    }
    return map;
  }

  Future<void> _upsertLinesInBatches(
    List<SubtitleLine> lines, {
    int batchSize = 250,
  }) async {
    if (lines.isEmpty) return;
    for (int i = 0; i < lines.length; i += batchSize) {
      final chunk = lines.skip(i).take(batchSize).map(_mapLine).toList();
      try {
        await _client.from('subtitle_lines').upsert(chunk);
      } on PostgrestException catch (e) {
        if (_supportsOwnerColumnLines && _isMissingColumn(e, 'owner_user_id')) {
          _supportsOwnerColumnLines = false;
          for (final m in chunk) {
            m.remove('owner_user_id');
          }
          await _client.from('subtitle_lines').upsert(chunk);
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _upsertProjectLocal(Map<String, dynamic> m) async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            projectId: m['project_id'] as String,
            title: m['title'] as String? ?? '',
            folder: Value(m['folder'] as String? ?? ''),
            archived: Value(m['archived'] as bool? ?? false),
            createdAtMs: m['created_at_ms'] as int? ?? 0,
            updatedAtMs: m['updated_at_ms'] as int? ?? 0,
            baseAssPath: m['base_ass_path'] as String? ?? '',
            exportMode: Value(
              m['export_mode'] as String? ?? 'CLEAN_TRANSLATION_ONLY',
            ),
            strictExport: Value(m['strict_export'] as bool? ?? true),
            currentIndex: Value(m['current_index'] as int? ?? 0),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> _setLocalFilePath(String fileId, String path) async {
    try {
      await (db.update(db.projectFiles)..where(
            (t) => t.fileId.equals(fileId),
          )).write(
        ProjectFilesCompanion(
          assPath: Value(path),
        ),
      );
    } catch (e) {
      debugPrint('[cloud] no se pudo actualizar ruta local para $fileId: $e');
    }
  }

  Future<void> _upsertFileLocal(Map<String, dynamic> m) async {
    await db
        .into(db.projectFiles)
        .insert(
          ProjectFilesCompanion.insert(
            fileId: m['file_id'] as String,
            projectId: m['project_id'] as String,
            engine: m['engine'] as String? ?? 'base',
            assPath: m['ass_path'] as String? ?? '',
            importedAtMs: m['imported_at_ms'] as int? ?? 0,
            dialogueCount: Value(m['dialogue_count'] as int? ?? 0),
            unmatchedCount: Value(m['unmatched_count'] as int? ?? 0),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> _upsertLineLocal(Map<String, dynamic> m) async {
    await db
        .into(db.subtitleLines)
        .insert(
          SubtitleLinesCompanion.insert(
            lineId: m['line_id'] as String,
            projectId: m['project_id'] as String,
            dialogueIndex: m['dialogue_index'] as int? ?? 0,
            eventsRowIndex: m['events_row_index'] as int? ?? 0,
            startMs: m['start_ms'] as int? ?? 0,
            endMs: m['end_ms'] as int? ?? 0,
            style: Value(m['style'] as String?),
            name: Value(m['name'] as String?),
            effect: Value(m['effect'] as String?),
            sourceText: Value(m['source_text'] as String?),
            romanization: Value(m['romanization'] as String?),
            gloss: Value(m['gloss'] as String?),
            dialoguePrefix: m['dialogue_prefix'] as String? ?? '',
            leadingTags: Value(m['leading_tags'] as String? ?? ''),
            hasVectorDrawing: Value(m['has_vector_drawing'] as bool? ?? false),
            originalText: m['original_text'] as String? ?? '',
            candGpt: Value(m['cand_gpt'] as String?),
            candClaude: Value(m['cand_claude'] as String?),
            candGemini: Value(m['cand_gemini'] as String?),
            candDeepseek: Value(m['cand_deepseek'] as String?),
            candVoice: Value(m['cand_voice'] as String?),
            selectedSource: Value(m['selected_source'] as String?),
            selectedText: Value(m['selected_text'] as String?),
            reviewed: Value(m['reviewed'] as bool? ?? false),
            doubt: Value(m['doubt'] as bool? ?? false),
            updatedAtMs: m['updated_at_ms'] as int? ?? 0,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<List<Map<String, dynamic>>> _fetchAllSubtitleLines(
    String projectId,
  ) async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final res = await _client
          .from('subtitle_lines')
          .select()
          .eq('project_id', projectId)
          .order('dialogue_index')
          .range(from, from + pageSize - 1);
      final chunk = (res as List).cast<Map<String, dynamic>>();
      if (chunk.isEmpty) break;
      all.addAll(chunk);
      if (chunk.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  Future<String> _uploadFileToCloud(ProjectFile f) async {
    final path = f.assPath;
    if (_looksLikeUrl(path)) {
      final rebased = _rebaseR2Url(path);
      return rebased ?? path;
    }
    final file = File(path);
    if (!await file.exists()) {
      throw CloudSyncException(
        code: 'local_file_missing',
        userMessage:
            'No se encontró el archivo local para "${f.engine}" y no se pudo subir.',
        debugMessage: 'missing local file: ${f.assPath}',
      );
    }

    try {
      await _ensureR2EnvLoaded();
      final ext = p.extension(path);
      final storagePath =
          '${f.projectId}/${f.engine}${ext.isNotEmpty ? ext : _defaultExt(f.engine)}';
      final contentType = _guessContentType(ext, f.engine);

      if (f.engine == 'video') {
        if (!_r2Available) {
          throw CloudSyncException(
            code: 'r2_missing_config',
            userMessage:
                'Este proyecto tiene video local y falta configuración R2 para subirlo (R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET).',
            debugMessage: 'R2 required for video upload: $storagePath',
          );
        }
        final size = await file.length();
        debugPrint('[cloud] uploading video (${size ~/ (1024 * 1024)} MB) to R2.');
        return await _uploadVideoToR2(file, storagePath, contentType);
      }

      final client = Supabase.instance.client;
      await client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          )
          .timeout(
            const Duration(minutes: 3),
            onTimeout: () =>
                throw TimeoutException('upload ${f.engine} timed out'),
          );
      final publicUrl = await client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
      return publicUrl;
    } on CloudSyncException {
      rethrow;
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'subir el archivo "${f.engine}"',
        debugContext: '_uploadFileToCloud(${f.engine})',
      );
    }
  }

  Future<String> _uploadVideoToR2(
    File file,
    String storagePath,
    String contentType,
  ) async {
    final cfg = _r2Config;
    if (cfg == null) {
      throw CloudSyncException(
        code: 'r2_missing_config',
        userMessage:
            'Falta configuración R2 para subir el video (R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET).',
      );
    }

    try {
      final payloadHash = await _sha256OfFile(file);
      final now = DateTime.now().toUtc();
      final amzDate = _fmtAmzDate(now);
      final datestamp = _fmtDate(now);
      final host = '${cfg.accountId}.r2.cloudflarestorage.com';
      final canonicalUri = '/${cfg.bucket}/$storagePath';

      final canonicalHeaders =
          'content-type:$contentType\nhost:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
      const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
      final canonicalRequest = [
        'PUT',
        canonicalUri,
        '',
        canonicalHeaders,
        signedHeaders,
        payloadHash,
      ].join('\n');

      final credentialScope = '$datestamp/auto/s3/aws4_request';
      final stringToSign = [
        'AWS4-HMAC-SHA256',
        amzDate,
        credentialScope,
        sha256.convert(utf8.encode(canonicalRequest)).toString(),
      ].join('\n');

      final signingKey = _signingKey(cfg.secretKey, datestamp, 'auto', 's3');
      final signature = Hmac(
        sha256,
        signingKey,
      ).convert(utf8.encode(stringToSign)).toString();

      final authorization =
          'AWS4-HMAC-SHA256 Credential=${cfg.accessKey}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

      final uri = Uri.https(host, canonicalUri);
      final request = http.StreamedRequest('PUT', uri)
        ..headers.addAll({
          'Content-Type': contentType,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'Authorization': authorization,
        })
        ..contentLength = await file.length();

      const uploadTimeout = Duration(minutes: 5);
      final respFuture = request.send();
      try {
        await request.sink.addStream(file.openRead()).timeout(uploadTimeout);
      } on TimeoutException {
        await request.sink.close();
        throw CloudSyncException(
          code: 'video_upload_timeout',
          userMessage:
              'La subida del video tardó demasiado (timeout de 5 minutos).',
          debugMessage: 'R2 upload stream timeout: $storagePath',
        );
      }
      await request.sink.close();

      final resp = await respFuture.timeout(
        uploadTimeout,
        onTimeout: () => throw TimeoutException('R2 upload timeout'),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final base = cfg.publicBase?.isNotEmpty == true
            ? cfg.publicBase!
            : 'https://${cfg.bucket}.$host';
        return '$base/$storagePath';
      } else {
        throw CloudSyncException(
          code: 'video_upload_rejected',
          userMessage:
              'R2 rechazó la subida del video (HTTP ${resp.statusCode}). Revisa credenciales y permisos del bucket.',
          debugMessage:
              'R2 upload failed: ${resp.statusCode} ${resp.reasonPhrase} ($storagePath)',
        );
      }
    } on CloudSyncException {
      rethrow;
    } on TimeoutException {
      throw CloudSyncException(
        code: 'video_upload_timeout',
        userMessage:
            'La subida del video tardó demasiado (timeout de 5 minutos).',
        debugMessage: 'R2 upload timeout: $storagePath',
      );
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'subir video a R2',
        debugContext: '_uploadVideoToR2($storagePath)',
      );
    }
  }

  Future<String?> _materializeFile(
    String projectId,
    String engine,
    String remoteOrLocal, {
    void Function(double value)? onProgress,
  }) async {
    if (remoteOrLocal.isEmpty) return null;
    if (!_looksLikeUrl(remoteOrLocal)) {
      final file = File(remoteOrLocal);
      if (await file.exists()) return file.path;
    }
    if (!_looksLikeUrl(remoteOrLocal)) return null;

    try {
      final uri = Uri.parse(remoteOrLocal);
      final signedUri = _maybeSignR2Get(uri);
      final client = http.Client();
      try {
        final req = http.Request('GET', signedUri);
        final streamed = await client
            .send(req)
            .timeout(const Duration(seconds: 30));
        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          return null;
        }

        final contentLength = streamed.contentLength ?? 0;
        final dir = await _projectDir(projectId);
        final ext = p.extension(uri.path).isNotEmpty
            ? p.extension(uri.path)
            : _defaultExt(engine);
        final fileName = _fileNameForEngine(engine, ext);
        final dst = File(p.join(dir.path, fileName));
        await dst.create(recursive: true);
        final sink = dst.openWrite();
        int received = 0;
        await for (final chunk in streamed.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (contentLength > 0 && onProgress != null) {
            onProgress((received / contentLength).clamp(0, 1));
          }
        }
        await sink.close();
        return dst.path;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('download error ($engine): $e');
      return null;
    }
  }

  Future<Directory> _projectDir(String projectId) async {
    final supportDir = await getApplicationSupportDirectory();
    final projDir = Directory(p.join(supportDir.path, 'voicex', projectId));
    await projDir.create(recursive: true);
    return projDir;
  }

  String _defaultExt(String engine) {
    if (engine == 'video') return '.mp4';
    return '.ass';
  }

  Future<Map<String, dynamic>?> _downloadSettingsPayload() async {
    try {
      final bytes = await _client.storage
          .from(_bucket)
          .download('prefs/settings.json');
      final txt = utf8.decode(bytes);
      return jsonDecode(txt) as Map<String, dynamic>;
    } on StorageException catch (e) {
      if (e.statusCode == '404' || e.statusCode == '400') {
        // Primer uso: el payload puede no existir todavía.
        return null;
      }
      throw _mapCloudError(
        e,
        action: 'descargar ajustes de cloud',
        debugContext: '_downloadSettingsPayload',
      );
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'descargar ajustes de cloud',
        debugContext: '_downloadSettingsPayload',
      );
    }
  }

  Future<void> _uploadSettingsPayload(Map<String, dynamic> payload) async {
    try {
      final data = utf8.encode(jsonEncode(payload));
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            'prefs/settings.json',
            data,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );
    } catch (e) {
      throw _mapCloudError(
        e,
        action: 'subir ajustes de cloud',
        debugContext: '_uploadSettingsPayload',
      );
    }
  }

  Future<Map<String, dynamic>?> _downloadProjectMeta(String projectId) async {
    try {
      final bytes = await _client.storage
          .from(_bucket)
          .download('meta/$projectId.json');
      final txt = utf8.decode(bytes);
      return jsonDecode(txt) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadProjectMeta(
    String projectId,
    Map<String, dynamic> meta,
  ) async {
    try {
      final data = utf8.encode(jsonEncode(meta));
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            'meta/$projectId.json',
            data,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );
    } catch (e) {
      debugPrint('upload project meta error: $e');
    }
  }

  String _fileNameForEngine(String engine, String ext) {
    switch (engine) {
      case 'video':
        return 'video${ext.isNotEmpty ? ext : '.mp4'}';
      case 'base':
        return 'base${ext.isNotEmpty ? ext : '.ass'}';
      default:
        return '$engine${ext.isNotEmpty ? ext : '.ass'}';
    }
  }

  bool _looksLikeUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  bool _isMissingColumn(PostgrestException e, String column) {
    final msg = e.message.toLowerCase();
    final col = column.toLowerCase();
    return e.code == 'PGRST204' || e.code == '42703' || msg.contains(col);
  }

  CloudSyncException _mapCloudError(
    Object error, {
    required String action,
    String? debugContext,
  }) {
    if (error is CloudSyncException) return error;

    final prefix = debugContext == null ? '' : '[$debugContext] ';
    if (error is TimeoutException) {
      return CloudSyncException(
        code: 'timeout',
        userMessage: 'La operación tardó demasiado al $action.',
        debugMessage: '$prefix${error.message ?? error.toString()}',
        cause: error,
      );
    }
    if (error is SocketException) {
      return CloudSyncException(
        code: 'network_error',
        userMessage:
            'No hay conexión de red estable para $action. Revisa internet y vuelve a intentarlo.',
        debugMessage: '$prefix${_compactError(error)}',
        cause: error,
      );
    }
    if (error is AuthException) {
      return CloudSyncException(
        code: 'auth_error',
        userMessage:
            'La sesión de Supabase no es válida para $action. Revisa credenciales o vuelve a iniciar sesión.',
        debugMessage: '$prefix${_compactError(error)}',
        cause: error,
      );
    }
    if (error is StorageException) {
      final status = error.statusCode?.toString() ?? '';
      final msg = (error.message).toLowerCase();
      if (status == '401' || status == '403' || msg.contains('jwt')) {
        return CloudSyncException(
          code: 'storage_auth_error',
          userMessage:
              'Cloud rechazó la autenticación al $action. Revisa credenciales de Supabase/R2.',
          debugMessage: '$prefix storage status=$status message=${error.message}',
          cause: error,
        );
      }
      if (status == '413') {
        return CloudSyncException(
          code: 'storage_file_too_large',
          userMessage:
              'El archivo es demasiado grande para subir a cloud (HTTP 413).',
          debugMessage: '$prefix storage status=$status message=${error.message}',
          cause: error,
        );
      }
      return CloudSyncException(
        code: 'storage_error',
        userMessage:
            'No se pudo $action por un error de almacenamiento en cloud (HTTP ${status.isEmpty ? '?' : status}).',
        debugMessage: '$prefix storage status=$status message=${error.message}',
        cause: error,
      );
    }
    if (error is PostgrestException) {
      final code = error.code;
      final msg = error.message.toLowerCase();
      if (_looksAuthError(code, msg)) {
        return CloudSyncException(
          code: 'supabase_auth_error',
          userMessage:
              'Supabase rechazó la autenticación al $action. Revisa la sesión y las claves.',
          debugMessage: '$prefix postgrest code=$code message=${error.message}',
          cause: error,
        );
      }
      if (_looksPermissionError(code, msg)) {
        return CloudSyncException(
          code: 'supabase_permission_error',
          userMessage:
              'No tienes permisos en Supabase para $action (RLS/policies).',
          debugMessage: '$prefix postgrest code=$code message=${error.message}',
          cause: error,
        );
      }
      return CloudSyncException(
        code: 'supabase_postgrest_error',
        userMessage: 'Supabase devolvió un error al $action (${code ?? 'sin código'}).',
        debugMessage: '$prefix postgrest code=$code message=${error.message}',
        cause: error,
      );
    }

    return CloudSyncException(
      code: 'unknown_cloud_error',
      userMessage: 'No se pudo $action. Error inesperado.',
      debugMessage: '$prefix${_compactError(error)}',
      cause: error,
    );
  }

  bool _looksAuthError(String? code, String msg) {
    return code == 'PGRST301' ||
        code == '401' ||
        msg.contains('jwt') ||
        msg.contains('invalid login') ||
        msg.contains('auth');
  }

  bool _looksPermissionError(String? code, String msg) {
    return code == '42501' ||
        code == '403' ||
        msg.contains('permission denied') ||
        msg.contains('row-level security') ||
        msg.contains('rls');
  }

  String _compactError(Object error) {
    return error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _guessContentType(String ext, String engine) {
    final lower = ext.toLowerCase();
    if (lower == '.mp4' || lower == '.mov' || lower == '.mkv') {
      return 'video/mp4';
    }
    if (lower == '.ass' || lower == '.srt' || lower == '.txt') {
      return 'text/plain';
    }
    if (engine == 'video') return 'video/mp4';
    return 'application/octet-stream';
  }

  String? _baseFileId(List<ProjectFile> files) {
    for (final f in files) {
      if (f.engine == 'base') return f.fileId;
    }
    return null;
  }

  Uri _maybeSignR2Get(Uri uri) {
    final cfg = _r2Config;
    if (cfg == null) return uri;
    final baseHost = '${cfg.accountId}.r2.cloudflarestorage.com';
    final host = uri.host;
    String? key;
    if (host == baseHost) {
      final segments = uri.path.split('/')..removeWhere((e) => e.isEmpty);
      if (segments.isEmpty) return uri;
      final bucketInUrl = segments.first;
      if (bucketInUrl != cfg.bucket) return uri;
      key = segments.skip(1).join('/');
    } else if (host == '${cfg.bucket}.$baseHost') {
      key = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    } else if (cfg.publicBase != null &&
        cfg.publicBase!.isNotEmpty &&
        host == Uri.parse(cfg.publicBase!).host) {
      key = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    }
    if (key == null) return uri;

    final expires = const Duration(hours: 1);
    final now = DateTime.now().toUtc();
    final amzDate = _fmtAmzDate(now);
    final datestamp = _fmtDate(now);
    final credentialScope = '$datestamp/auto/s3/aws4_request';
    const signedHeaders = 'host';

    final canonicalQuery = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '${cfg.accessKey}/$credentialScope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expires.inSeconds.toString(),
      'X-Amz-SignedHeaders': signedHeaders,
    };
    final canonicalQueryStr = canonicalQuery.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final canonicalRequest = [
      'GET',
      '/${cfg.bucket}/$key',
      canonicalQueryStr,
      'host:$baseHost\n',
      signedHeaders,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _signingKey(cfg.secretKey, datestamp, 'auto', 's3');
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    final fullQuery = '$canonicalQueryStr&X-Amz-Signature=$signature';
    return Uri(
      scheme: 'https',
      host: baseHost,
      path: '/${cfg.bucket}/$key',
      query: fullQuery,
    );
  }

  Future<String> resolveVideoUrl(String url) async {
    if (url.isEmpty) return url;
    if (!_looksLikeUrl(url)) return url;
    await _ensureR2EnvLoaded();
    try {
      final signed = _maybeSignR2Get(Uri.parse(url));
      return signed.toString();
    } catch (_) {
      return url;
    }
  }

  String? _rebaseR2Url(String url) {
    final cfg = _r2Config;
    if (cfg == null) return null;
    final publicBase = cfg.publicBase;
    if (publicBase == null || publicBase.isEmpty) return null;
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return null;
    }
    final host = uri.host;
    final baseHost = '${cfg.accountId}.r2.cloudflarestorage.com';
    String? key;
    if (host == baseHost) {
      final segments = uri.path.split('/')..removeWhere((e) => e.isEmpty);
      if (segments.isEmpty) return null;
      final bucketInUrl = segments.first;
      if (bucketInUrl != cfg.bucket) return null;
      key = segments.skip(1).join('/');
    } else if (host == '${cfg.bucket}.$baseHost') {
      key = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    } else if (host == Uri.parse(publicBase).host) {
      return url; // ya público
    }
    if (key == null) return null;
    final base = publicBase.trimRight().replaceAll(RegExp(r'/+$'), '');
    return '$base/$key';
  }

  Future<void> _ensureR2EnvLoaded() async {
    if (_fileEnvLoaded) return;
    if (_fileEnvLoading != null) {
      await _fileEnvLoading;
      return;
    }
    _fileEnvLoading = () async {
      final candidates = <String>{'.env'};
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        candidates.add(p.join(exeDir, '.env'));
      } catch (_) {}
      try {
        final supportDir = await getApplicationSupportDirectory();
        candidates.add(p.join(supportDir.path, '.env'));
      } catch (_) {}

      for (final path in candidates) {
        try {
          final file = File(path);
          final exists = await file.exists();
          if (exists) {
            final lines = await file.readAsLines();
            _fileEnv = _parseEnv(lines);
            break;
          }
        } catch (_) {}
      }
      _fileEnvLoaded = true;
    }();

    try {
      await _fileEnvLoading;
    } finally {
      _fileEnvLoading = null;
    }
  }

  Map<String, String> _parseEnv(List<String> lines) {
    final map = <String, String>{};
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      if (key.isNotEmpty) {
        map[key] = value;
      }
    }
    return map;
  }

  _R2Config? get _r2Config {
    String readEnv(String key) {
      final fromDefine = String.fromEnvironment(key);
      if (fromDefine.isNotEmpty) return fromDefine;
      final fromPlatform = Platform.environment[key];
      if (fromPlatform != null && fromPlatform.isNotEmpty) return fromPlatform;
      if (dotenv.isInitialized) {
        final fromDotenv = dotenv.env[key];
        if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
      }
      final fromFile = _fileEnv[key];
      if (fromFile != null && fromFile.isNotEmpty) return fromFile;
      return '';
    }

    final accountId = readEnv('R2_ACCOUNT_ID');
    final accessKey = readEnv('R2_ACCESS_KEY');
    final secretKey = readEnv('R2_SECRET_KEY');
    final bucket = readEnv('R2_BUCKET');
    final publicBase = readEnv('R2_PUBLIC_BASE');

    if ([accountId, accessKey, secretKey, bucket].any((e) => e.isEmpty)) {
      return null;
    }
    return _R2Config(
      accountId: accountId,
      accessKey: accessKey,
      secretKey: secretKey,
      bucket: bucket,
      publicBase: publicBase.isEmpty ? null : publicBase,
    );
  }

  bool get _r2Available => _r2Config != null;

  List<int> _signingKey(
    String secretKey,
    String date,
    String region,
    String service,
  ) {
    final kDate = _hmac(utf8.encode('AWS4$secretKey'), date);
    final kRegion = _hmac(kDate, region);
    final kService = _hmac(kRegion, service);
    final kSigning = _hmac(kService, 'aws4_request');
    return kSigning;
  }

  List<int> _hmac(List<int> key, String message) {
    return Hmac(sha256, key).convert(utf8.encode(message)).bytes;
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _fmtAmzDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}Z';

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
}

class _R2Config {
  _R2Config({
    required this.accountId,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    this.publicBase,
  });

  final String accountId;
  final String accessKey;
  final String secretKey;
  final String bucket;
  final String? publicBase;
}

class _DirtyCacheEntry {
  _DirtyCacheEntry({
    required this.checkedAtMs,
    required this.isDirty,
  });
  final int checkedAtMs;
  final bool isDirty;
}

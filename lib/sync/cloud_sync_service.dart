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

/// Sincroniza proyectos con Supabase (BD) y R2/Supabase Storage (ficheros).
class CloudSyncService {
  CloudSyncService(this.db);

  final AppDatabase db;
  final _supabase = SupabaseManager.instance;
  final _prefs = SyncPrefs();
  bool _supportsFolderColumn = true;
  bool _supportsArchivedColumn = true;
  final Map<String, _DirtyCacheEntry> _dirtyCache = {};

  static const _bucket = 'voicex';

  bool get isReady => _supabase.isReady;
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> ensureInit() async {
    await _supabase.init();
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
    if (!isReady) return;
    try {
      await _syncSettings(onProgress: onProgress);
      final remote = await listRemoteProjects();
      final remoteById = <String, Map<String, dynamic>>{
        for (final m in remote) (m['project_id'] as String): m,
      };
      final remoteIds = remoteById.keys.toSet();
      final localRows = await db.select(db.projects).get();
      final localIds = localRows.map((p) => p.projectId).toSet();

      final totalOps = remoteIds.union(localIds).length;
      double done = 0;
      void bump(String stage) {
        done += 1;
        final denom = totalOps == 0 ? 1 : totalOps;
        onProgress?.call((done / denom).clamp(0, 1), stage);
      }

      for (final local in localRows) {
        final remoteEntry = remoteById[local.projectId];
        final remoteUpdated = remoteEntry?['updated_at_ms'] as int? ?? 0;
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
      }

      for (final id in remoteIds.difference(localIds)) {
        await pullProject(id, onProgress: onProgress);
        bump('Descargando $id');
      }
    } catch (e) {
      debugPrint('syncAllProjects error: $e');
    }
  }

  Future<void> pushProject(
    String projectId, {
    void Function(double value, String stage)? onProgress,
  }) async {
    if (!isReady) return;
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
      for (final f in files) {
        if (f.engine == 'video') {
          // 1) Si hay URL, la reusamos (rebased).
          if (_looksLikeUrl(f.assPath)) {
            final rebased = _rebaseR2Url(f.assPath);
            final url = rebased ?? f.assPath;
            debugPrint('[cloud] reuse video url ${f.assPath} -> $url');
            remotePaths[f.fileId] = url;
            await _setLocalFilePath(f.fileId, url);
            continue;
          }
          // 2) Si hay fichero local y R2 disponible, lo subimos a R2.
          final file = File(f.assPath);
          if (await file.exists() && _r2Available) {
            final ext = p.extension(f.assPath);
            final storagePath =
                '${f.projectId}/${f.engine}${ext.isNotEmpty ? ext : _defaultExt(f.engine)}';
            final uploaded = await _uploadVideoToR2(
              file,
              storagePath,
              _guessContentType(ext, f.engine),
            );
            if (uploaded != null) {
              final rebased = _rebaseR2Url(uploaded) ?? uploaded;
              remotePaths[f.fileId] = rebased;
              await _setLocalFilePath(f.fileId, rebased);
              debugPrint('[cloud] uploaded video to R2: $rebased');
            } else {
              debugPrint(
                '[cloud] video upload failed/skipped for ${f.assPath}',
              );
            }
            continue;
          }
          // 3) Si no hay R2 y es local, no lo subimos ni lo escribimos en cloud.
          debugPrint('[cloud] skip video (no R2 / solo local): ${f.assPath}');
          continue;
        }

        final uploaded = await _uploadFileToCloud(f);
        if (uploaded != null) {
          final rebased = _rebaseR2Url(uploaded);
          if (rebased != null) {
            debugPrint(
              '[cloud] rebase uploaded ${f.engine}: $uploaded -> $rebased',
            );
            remotePaths[f.fileId] = rebased;
          } else {
            remotePaths[f.fileId] = uploaded;
          }
        } else if (_looksLikeUrl(f.assPath)) {
          final rebased = _rebaseR2Url(f.assPath);
          debugPrint(
            '[cloud] reuse url ${f.engine}: ${f.assPath} -> ${rebased ?? 'no change'}',
          );
          if (rebased != null) remotePaths[f.fileId] = rebased;
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
            _supportsFolderColumn &&
            (e.code == 'PGRST204' ||
                e.code == '42703' ||
                e.message.contains('folder'));
        final missingArchived =
            _supportsArchivedColumn &&
            (e.code == 'PGRST204' ||
                e.code == '42703' ||
                e.message.contains('archived'));
        if (missingFolder) {
          _supportsFolderColumn = false;
          final fallback = Map<String, dynamic>.from(projectMap)
            ..remove('folder');
          await _client.from('projects').upsert(fallback);
        } else if (missingArchived) {
          _supportsArchivedColumn = false;
          final fallback = Map<String, dynamic>.from(projectMap)
            ..remove('archived');
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
          await _client.from('project_files').upsert(mapped);
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
    } catch (e) {
      debugPrint('pushProject error: $e');
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

      final remoteUpdated = remote?['updated_at_ms'] as int? ?? 0;
      final localUpdated = local['updated_at_ms'] as int? ?? 0;

      if (remote != null && remoteUpdated > localUpdated) {
        final applied = await settings.importSyncPayload(remote);
        if (applied) {
          onProgress?.call(0.05, 'Ajustes sincronizados');
        }
      } else {
        await _uploadSettingsPayload(local);
        onProgress?.call(0.05, 'Ajustes subidos');
      }
    } catch (e) {
      debugPrint('sync settings error: $e');
    }
  }

  Future<void> pullProject(
    String projectId, {
    void Function(double value, String stage)? onProgress,
  }) async {
    if (!isReady) return;
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

      final linesRes = await _client
          .from('subtitle_lines')
          .select()
          .eq('project_id', projectId);
      final linesList = (linesRes as List).cast<Map<String, dynamic>>();
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
    } catch (e) {
      debugPrint('pullProject error: $e');
    }
  }

  Map<String, dynamic> _mapProject(Project p, {String? assPathOverride}) => {
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

  Map<String, dynamic> _mapFile(ProjectFile f, {String? assPathOverride}) => {
    'file_id': f.fileId,
    'project_id': f.projectId,
    'engine': f.engine,
    'ass_path': assPathOverride ?? f.assPath,
    'imported_at_ms': f.importedAtMs,
    'dialogue_count': f.dialogueCount,
    'unmatched_count': f.unmatchedCount,
  };

  Map<String, dynamic> _mapLine(SubtitleLine l) => {
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

  Future<void> _upsertLinesInBatches(
    List<SubtitleLine> lines, {
    int batchSize = 250,
  }) async {
    if (lines.isEmpty) return;
    for (int i = 0; i < lines.length; i += batchSize) {
      final chunk = lines.skip(i).take(batchSize).map(_mapLine).toList();
      await _client.from('subtitle_lines').upsert(chunk);
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

  Future<String?> _uploadFileToCloud(ProjectFile f) async {
    final path = f.assPath;
    if (_looksLikeUrl(path)) {
      final rebased = _rebaseR2Url(path);
      return rebased ?? path;
    }
    final file = File(path);
    if (!await file.exists()) return null;

    try {
      final size = await file.length();
      final ext = p.extension(path);
      final storagePath =
          '${f.projectId}/${f.engine}${ext.isNotEmpty ? ext : _defaultExt(f.engine)}';
      final contentType = _guessContentType(ext, f.engine);

      if (f.engine == 'video' && _r2Available) {
        return await _uploadVideoToR2(file, storagePath, contentType);
      }
      if (f.engine == 'video' && size > 50 * 1024 * 1024 && !_r2Available) {
        debugPrint(
          'upload skip (video): tamaño ${size ~/ (1024 * 1024)} MB sin R2.',
        );
        return null;
      }

      final client = Supabase.instance.client;
      await client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          )
          .timeout(const Duration(minutes: 3), onTimeout: () {
        debugPrint('upload timeout (${f.engine}): $storagePath');
        throw TimeoutException('upload ${f.engine} timed out');
      });
      final publicUrl = client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
      return publicUrl;
    } catch (e) {
      debugPrint('upload error (${f.engine}): $e');
      return null;
    }
  }

  Future<String?> _uploadVideoToR2(
    File file,
    String storagePath,
    String contentType,
  ) async {
    final cfg = _r2Config;
    if (cfg == null) return null;

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

      await for (final chunk in file.openRead()) {
        request.sink.add(chunk);
      }
      await request.sink.close();

      final resp = await request
          .send()
          .timeout(const Duration(minutes: 3), onTimeout: () {
        debugPrint('R2 upload timeout: $storagePath');
        throw TimeoutException('R2 upload timeout');
      });
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final base = cfg.publicBase?.isNotEmpty == true
            ? cfg.publicBase!
            : 'https://${cfg.bucket}.$host';
        return '$base/$storagePath';
      } else {
        debugPrint('R2 upload failed: ${resp.statusCode} ${resp.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('R2 upload error: $e');
      return null;
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
    } catch (e) {
      debugPrint('download settings error: $e');
      return null;
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
      debugPrint('upload settings error: $e');
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

  _R2Config? get _r2Config {
    String readEnv(String key) {
      final fromDefine = String.fromEnvironment(key);
      if (fromDefine.isNotEmpty) return fromDefine;
      final fromPlatform = Platform.environment[key];
      if (fromPlatform != null && fromPlatform.isNotEmpty) return fromPlatform;
      final fromDotenv = dotenv.env[key];
      if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
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

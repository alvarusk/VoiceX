// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_db.dart';
import '../export/export_service.dart';
import '../settings/settings_service.dart';
import 'package:uuid/uuid.dart';

class ProjectSummary {
  ProjectSummary({
    required this.projectId,
    required this.title,
    required this.folder,
    required this.updatedAtMs,
    required this.currentIndex,
    required this.total,
    required this.reviewed,
  });

  final String projectId;
  final String title;
  final String folder;
  final int updatedAtMs;
  final int currentIndex;
  final int total;
  final int reviewed;
}

class MetricsSnapshot {
  MetricsSnapshot({
    required this.total,
    required this.reviewed,
    required this.bySource,
    required this.doubtCount,
  });

  final int total;
  final int reviewed;
  final Map<String, int> bySource;
  final int doubtCount;
}

class SessionDurationSummary {
  SessionDurationSummary({required this.totalMs, required this.byPlatform});
  final int totalMs;
  final Map<String, int> byPlatform;
}

class LineTiming {
  LineTiming({
    required this.lineId,
    required this.dialogueIndex,
    required this.startMs,
    required this.endMs,
    this.selectedText,
    this.sourceText,
    required this.originalText,
  });

  final String lineId;
  final int dialogueIndex;
  final int startMs;
  final int endMs;
  final String? selectedText;
  final String? sourceText;
  final String originalText;
}

class ReviewService {
  ReviewService(this.db);

  final AppDatabase db;

  Stream<Project> watchProject(String projectId) {
    return (db.select(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).watchSingle();
  }

  Stream<List<ProjectSummary>> watchProjectSummaries() {
    final q = db.customSelect(
      '''
      SELECT
        p.project_id as projectId,
        p.title as title,
        p.folder as folder,
        p.archived as archived,
        p.updated_at_ms as updatedAtMs,
        p.current_index as currentIndex,
        (SELECT COUNT(*) FROM subtitle_lines s WHERE s.project_id = p.project_id) as total,
        (SELECT COUNT(*) FROM subtitle_lines s WHERE s.project_id = p.project_id AND s.reviewed = 1) as reviewed
      FROM projects p
      WHERE p.archived = 0
      ORDER BY p.updated_at_ms DESC
      ''',
      readsFrom: {db.projects, db.subtitleLines},
    );

    return q.watch().map((rows) {
      return rows.map((r) {
        return ProjectSummary(
          projectId: r.read<String>('projectId'),
          title: r.read<String>('title'),
          folder: r.read<String>('folder'),
          // archived excluded in WHERE
          updatedAtMs: r.read<int>('updatedAtMs'),
          currentIndex: r.read<int>('currentIndex'),
          total: r.read<int>('total'),
          reviewed: r.read<int>('reviewed'),
        );
      }).toList();
    });
  }

  Future<void> deleteProject(String projectId) async {
    await (db.delete(
      db.selectionEvents,
    )..where((t) => t.projectId.equals(projectId))).go();
    await (db.delete(
      db.subtitleLines,
    )..where((t) => t.projectId.equals(projectId))).go();
    await (db.delete(
      db.projectFiles,
    )..where((t) => t.projectId.equals(projectId))).go();
    await (db.delete(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).go();
    await SettingsService.instance.markProjectDeleted(projectId);
  }

  Future<void> archiveProject(String projectId) async {
    final project = await (db.select(db.projects)..where((t) => t.projectId.equals(projectId))).getSingleOrNull();
    final files = await (db.select(db.projectFiles)..where((t) => t.projectId.equals(projectId))).get();

    // Borra ficheros locales grandes.
    Future<void> deleteIfLocal(String path) async {
      if (path.isEmpty) return;
      if (path.startsWith('http://') || path.startsWith('https://')) return;
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }

    for (final f in files) {
      await deleteIfLocal(f.assPath);
    }
    if (project != null) {
      await deleteIfLocal(project.baseAssPath);
    }

    await (db.delete(db.projectFiles)..where((t) => t.projectId.equals(projectId))).go();
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.projects)..where((t) => t.projectId.equals(projectId))).write(
      ProjectsCompanion(
        archived: const Value(true),
        baseAssPath: const Value(''),
        updatedAtMs: Value(now),
      ),
    );
  }

  Stream<int> watchTotalLines(String projectId) {
    final q = db.customSelect(
      'SELECT COUNT(*) as c FROM subtitle_lines WHERE project_id = ?',
      variables: [Variable<String>(projectId)],
      readsFrom: {db.subtitleLines},
    );
    return q.watchSingle().map((r) => r.read<int>('c'));
  }

  Stream<int> watchReviewedLines(String projectId) {
    final q = db.customSelect(
      'SELECT COUNT(*) as c FROM subtitle_lines WHERE project_id = ? AND reviewed = 1',
      variables: [Variable<String>(projectId)],
      readsFrom: {db.subtitleLines},
    );
    return q.watchSingle().map((r) => r.read<int>('c'));
  }

  Stream<SubtitleLine> watchLine(String projectId, int dialogueIndex) {
    return (db.select(db.subtitleLines)..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.dialogueIndex.equals(dialogueIndex),
        ))
        .watchSingle();
  }

  Stream<List<SubtitleLine>> watchAllLines(String projectId) {
    return (db.select(db.subtitleLines)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm(expression: t.startMs)]))
        .watch();
  }

  Future<void> setCurrentIndex(String projectId, int idx) async {
    await (db.update(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).write(
      ProjectsCompanion(
        currentIndex: Value(idx),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setProjectFolder(String projectId, String folder) async {
    await (db.update(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).write(
      ProjectsCompanion(
        folder: Value(folder),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> renameProject(String projectId, String title) async {
    await (db.update(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).write(
      ProjectsCompanion(
        title: Value(title),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> renameFolder(String from, String to) async {
    final target = to.trim();
    await (db.update(db.projects)..where((t) => t.folder.equals(from))).write(
      ProjectsCompanion(
        folder: Value(target),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> chooseCandidate({
    required String projectId,
    required String lineId,
    required String source,
    required String text,
    required String method,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      await (db.update(
        db.subtitleLines,
      )..where((t) => t.lineId.equals(lineId))).write(
        SubtitleLinesCompanion(
          selectedSource: Value(source),
          selectedText: Value(text),
          reviewed: const Value(true),
          updatedAtMs: Value(now),
        ),
      );

      await db
          .into(db.selectionEvents)
          .insert(
            SelectionEventsCompanion.insert(
              projectId: projectId,
              lineId: lineId,
              chosenSource: source,
              chosenText: text,
              atMs: now,
              method: method,
            ),
          );

      await (db.update(db.projects)
            ..where((t) => t.projectId.equals(projectId)))
          .write(ProjectsCompanion(updatedAtMs: Value(now)));
    });
  }

  Future<void> setVoiceText(String lineId, String? text) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(
      db.subtitleLines,
    )..where((t) => t.lineId.equals(lineId))).write(
      SubtitleLinesCompanion(candVoice: Value(text), updatedAtMs: Value(now)),
    );
    await _touchProjectByLine(lineId, now);
  }

  Future<void> toggleDoubt(String lineId, bool value) async {
    final existing = await (db.select(
      db.subtitleLines,
    )..where((t) => t.lineId.equals(lineId))).getSingleOrNull();
    if (existing == null) return;

    String prefix = existing.dialoguePrefix;
    if (value) {
      // Dialogue -> Comment para marcar duda.
      if (prefix.startsWith('Dialogue:')) {
        prefix = prefix.replaceFirst('Dialogue:', 'Comment:');
      } else if (!prefix.startsWith('Comment:')) {
        prefix = 'Comment:${prefix.split(':').skip(1).join(':')}';
      }
    } else {
      // Comment -> Dialogue para limpiar duda.
      if (prefix.startsWith('Comment:')) {
        prefix = prefix.replaceFirst('Comment:', 'Dialogue:');
      } else if (!prefix.startsWith('Dialogue:')) {
        prefix = 'Dialogue:${prefix.split(':').skip(1).join(':')}';
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(
      db.subtitleLines,
    )..where((t) => t.lineId.equals(lineId))).write(
      SubtitleLinesCompanion(
        doubt: Value(value),
        dialoguePrefix: Value(prefix),
        updatedAtMs: Value(now),
      ),
    );
    await _touchProjectByLine(lineId, now);
  }

  Future<void> setCandidateText({
    required String lineId,
    required String source,
    required String text,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trimmed = text.trim();
    SubtitleLinesCompanion data = SubtitleLinesCompanion(
      updatedAtMs: Value(now),
    );
    switch (source.toLowerCase()) {
      case 'gpt':
        data = data.copyWith(candGpt: Value(trimmed));
        break;
      case 'claude':
        data = data.copyWith(candClaude: Value(trimmed));
        break;
      case 'gemini':
        data = data.copyWith(candGemini: Value(trimmed));
        break;
      case 'deepseek':
        data = data.copyWith(candDeepseek: Value(trimmed));
        break;
      case 'voice':
        data = data.copyWith(candVoice: Value(trimmed));
        break;
      default:
        return;
    }
    await (db.update(
      db.subtitleLines,
    )..where((t) => t.lineId.equals(lineId))).write(data);
    await _touchProjectByLine(lineId, now);
  }

  Future<String?> getVideoPath(String projectId) async {
    final row =
        await (db.select(db.projectFiles)..where(
              (t) => t.projectId.equals(projectId) & t.engine.equals('video'),
            ))
            .getSingleOrNull();
    return row?.assPath;
  }

  Future<void> attachVideo({
    required String projectId,
    required String sourcePath,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final projDir = Directory(p.join(supportDir.path, 'voicex', projectId));
    await projDir.create(recursive: true);

    final ext = p.extension(sourcePath);
    final dst = p.join(
      projDir.path,
      'video${ext.isNotEmpty ? ext : '.mp4'}',
    );
    await File(sourcePath).copy(dst);

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        await (db.select(db.projectFiles)..where(
              (t) => t.projectId.equals(projectId) & t.engine.equals('video'),
            ))
            .getSingleOrNull();

    Future<void> deleteIfLocal(String path) async {
      if (path.isEmpty) return;
      if (path.startsWith('http://') || path.startsWith('https://')) return;
      if (path == dst) return;
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }

    if (existing != null) {
      await deleteIfLocal(existing.assPath);
      await (db.update(db.projectFiles)..where(
            (t) => t.fileId.equals(existing.fileId),
          )).write(
        ProjectFilesCompanion(
          assPath: Value(dst),
          importedAtMs: Value(now),
        ),
      );
    } else {
      await db.into(db.projectFiles).insert(
            ProjectFilesCompanion.insert(
              fileId: const Uuid().v4(),
              projectId: projectId,
              engine: 'video',
              assPath: dst,
              importedAtMs: now,
              dialogueCount: const Value(0),
              unmatchedCount: const Value(0),
            ),
          );
    }

    await (db.update(db.projects)
          ..where((t) => t.projectId.equals(projectId)))
        .write(ProjectsCompanion(updatedAtMs: Value(now)));
  }

  Future<int?> findNextUnreviewed(String projectId, int fromIndex) async {
    final row =
        await (db.select(db.subtitleLines)
              ..where(
                (t) =>
                    t.projectId.equals(projectId) &
                    t.dialogueIndex.isBiggerThanValue(fromIndex) &
                    t.reviewed.equals(false),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.dialogueIndex)])
              ..limit(1))
            .getSingleOrNull();
    return row?.dialogueIndex;
  }

  Future<int?> findNextDoubt(String projectId, int fromIndex) async {
    final row =
        await (db.select(db.subtitleLines)
              ..where(
                (t) =>
                    t.projectId.equals(projectId) &
                    t.dialogueIndex.isBiggerThanValue(fromIndex) &
                    t.doubt.equals(true),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.dialogueIndex)])
              ..limit(1))
            .getSingleOrNull();
    return row?.dialogueIndex;
  }

  Stream<MetricsSnapshot> watchMetrics(String projectId) {
    final controller = StreamController<MetricsSnapshot>();

    int total = 0;
    int reviewed = 0;
    int doubtCount = 0;
    Map<String, int> bySource = {};

    void emit() {
      controller.add(
        MetricsSnapshot(
          total: total,
          reviewed: reviewed,
          bySource: bySource,
          doubtCount: doubtCount,
        ),
      );
    }

    final subBase = db
        .customSelect(
          '''
          SELECT
            (SELECT COUNT(*) FROM subtitle_lines s WHERE s.project_id = ?) as total,
            (SELECT COUNT(*) FROM subtitle_lines s WHERE s.project_id = ? AND s.reviewed = 1) as reviewed,
            (SELECT COUNT(*) FROM subtitle_lines s WHERE s.project_id = ? AND s.doubt = 1) as doubtCount
          ''',
          variables: [
            Variable(projectId),
            Variable(projectId),
            Variable(projectId),
          ],
          readsFrom: {db.subtitleLines},
        )
        .watchSingle()
        .listen((r) {
          total = r.read<int>('total');
          reviewed = r.read<int>('reviewed');
          doubtCount = r.read<int>('doubtCount');
          emit();
        });

    final subBySource = db
        .customSelect(
          '''
          SELECT selected_source as src, COUNT(*) as c
          FROM subtitle_lines
          WHERE project_id = ? AND reviewed = 1 AND selected_source IS NOT NULL
          GROUP BY selected_source
          ''',
          variables: [Variable(projectId)],
          readsFrom: {db.subtitleLines},
        )
        .watch()
        .listen((rows) {
          final map = <String, int>{};
          for (final r in rows) {
            final src = (r.read<String?>('src') ?? 'other').toLowerCase();
            final c = r.read<int>('c');
            if (src == 'gpt' ||
                src == 'claude' ||
                src == 'gemini' ||
                src == 'deepseek' ||
                src == 'voice') {
              map[src] = c;
            } else {
              map['other'] = (map['other'] ?? 0) + c;
            }
          }
          bySource = map;
          emit();
        });

    controller.onCancel = () async {
      await subBase.cancel();
      await subBySource.cancel();
    };

    return controller.stream;
  }

  Future<void> exportAndShareProject(
    BuildContext context, {
    required String projectId,
  }) async {
    try {
      final exp = ExportService(db);
      final xfile = await exp.exportCleanAssXFile(projectId);
      if (Platform.isWindows) {
        final destDir = Directory(
          r'C:\Users\ajime\OneDrive\Documentos\PENDING',
        );
        await destDir.create(recursive: true);
        final destPath = p.join(destDir.path, p.basename(xfile.path));
        await File(xfile.path).copy(destPath);
        try {
          await Process.start('explorer', [destDir.path]);
        } catch (_) {
          // best-effort; si falla igual dejamos el archivo copiado
        }
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ASS exportado en $destPath')));
        }
      } else {
        await Share.shareXFiles(
          [xfile],
          text: 'ASS exportado',
          subject: 'ASS exportado',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    }
  }

  Future<void> startSession(String projectId, String platform) async {
    final deviceId = SettingsService.instance.deviceId;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Cierra sesiones previas abiertas para este dispositivo
    await (db.update(db.sessionLogs)
          ..where((t) => t.deviceId.equals(deviceId) & t.endedAtMs.isNull()))
        .write(SessionLogsCompanion(endedAtMs: Value(now)));

    await db
        .into(db.sessionLogs)
        .insert(
          SessionLogsCompanion.insert(
            sessionId: const Uuid().v4(),
            projectId: projectId,
            deviceId: deviceId,
            platform: platform,
            startedAtMs: now,
          ),
        );
  }

  Future<void> endSession(String projectId) async {
    final deviceId = SettingsService.instance.deviceId;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.sessionLogs)..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.deviceId.equals(deviceId) &
              t.endedAtMs.isNull(),
        ))
        .write(SessionLogsCompanion(endedAtMs: Value(now)));
  }

  Stream<SessionDurationSummary> watchSessionDurations(String projectId) {
    final q = (db.select(
      db.sessionLogs,
    )..where((t) => t.projectId.equals(projectId))).watch();
    return q.map((rows) => _computeSessionDurations(rows));
  }

  SessionDurationSummary _computeSessionDurations(List<SessionLog> sessions) {
    if (sessions.isEmpty) {
      return SessionDurationSummary(totalMs: 0, byPlatform: {});
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final events = <_SessionEvent>[];
    for (final s in sessions) {
      final end = s.endedAtMs ?? now;
      events.add(
        _SessionEvent(time: s.startedAtMs, type: _Evt.start, session: s),
      );
      events.add(_SessionEvent(time: end, type: _Evt.end, session: s));
    }
    events.sort((a, b) {
      final cmp = a.time.compareTo(b.time);
      if (cmp != 0) return cmp;
      // end before start when same time
      return a.type.index.compareTo(b.type.index);
    });

    final active = <SessionLog>[];
    SessionLog? primary;
    int lastTime = events.first.time;
    final totals = <String, int>{};

    for (final e in events) {
      final dt = e.time - lastTime;
      if (primary != null && dt > 0) {
        final plat = primary.platform;
        totals[plat] = (totals[plat] ?? 0) + dt;
      }

      if (e.type == _Evt.start) {
        active.add(e.session);
        active.sort((a, b) => a.startedAtMs.compareTo(b.startedAtMs));
      } else {
        active.removeWhere((s) => s.sessionId == e.session.sessionId);
      }

      primary = active.isEmpty ? null : active.first;
      lastTime = e.time;
    }

    final totalMs = totals.values.fold<int>(0, (a, b) => a + b);
    return SessionDurationSummary(totalMs: totalMs, byPlatform: totals);
  }

  Future<List<LineTiming>> fetchLineTimings(String projectId) async {
    final rows = await (db.select(db.subtitleLines)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm(expression: t.dialogueIndex)]))
        .get();
    return rows
        .map(
          (r) => LineTiming(
            lineId: r.lineId,
            dialogueIndex: r.dialogueIndex,
            startMs: r.startMs,
            endMs: r.endMs,
            selectedText: r.selectedText,
            sourceText: r.sourceText,
            originalText: r.originalText,
          ),
        )
        .toList();
  }

  Future<void> _touchProjectByLine(String lineId, int tsMs) async {
    final row = await (db.select(
      db.subtitleLines,
    )..where((t) => t.lineId.equals(lineId))).getSingleOrNull();
    if (row == null) return;
    await (db.update(db.projects)
          ..where((t) => t.projectId.equals(row.projectId)))
        .write(ProjectsCompanion(updatedAtMs: Value(tsMs)));
  }
}

enum _Evt { end, start }

class _SessionEvent {
  _SessionEvent({
    required this.time,
    required this.type,
    required this.session,
  });
  final int time;
  final _Evt type;
  final SessionLog session;
}

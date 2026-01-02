import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import 'ass_parser.dart';
import 'engine.dart';

class ImportService {
  ImportService(this.db);

  final AppDatabase db;
  final _uuid = const Uuid();

  bool _isCartel(ParsedDialogue d) {
    final name = (d.name ?? '').toLowerCase();
    return name.contains('cartel');
  }

  Future<String> importProject({
    required String title,
    String folder = '',
    required PlatformFile baseAss,
    required Map<Engine, PlatformFile> engineAssFiles,
    PlatformFile? videoFile,
    String? videoWebUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final projectId = _uuid.v4();

    // Carpeta interna del proyecto
    final supportDir =
        await getApplicationSupportDirectory(); // ficheros internos :contentReference[oaicite:7]{index=7}
    final projDir = Directory(p.join(supportDir.path, 'voicex', projectId));
    await projDir.create(recursive: true);

    // Copiar base (respetar nombre original para exportar con mismo nombre)
    final baseSrcPath = baseAss.path;
    if (baseSrcPath == null) {
      throw Exception('baseAss.path es null (FilePicker sin path).');
    }
    final originalName = (baseAss.name.isNotEmpty ? baseAss.name : 'base.ass')
        .trim();
    final safeName = originalName.isEmpty
        ? 'base.ass'
        : originalName.replaceAll(RegExp(r'[\\\\/:*?"<>|]+'), '_');
    final baseDst = p.join(projDir.path, safeName);
    await File(baseSrcPath).copy(baseDst);

    // Copiar motores
    final copiedEnginePaths = <Engine, String>{};
    for (final entry in engineAssFiles.entries) {
      final src = entry.value.path;
      if (src == null) continue;
      final dst = p.join(projDir.path, '${engineToStr(entry.key)}.ass');
      await File(src).copy(dst);
      copiedEnginePaths[entry.key] = dst;
    }

    String? videoDst;
    if (videoFile?.path != null) {
      final ext = p.extension(videoFile!.path!);
      videoDst = p.join(projDir.path, 'video${ext.isNotEmpty ? ext : '.mp4'}');
      await File(videoFile.path!).copy(videoDst);
    }

    // Parse base
    final baseLines = await File(baseDst).readAsLines();
    final parsedBase = AssParser.parseAssLines(baseLines);
    final baseDialogues = parsedBase.dialogues
        .where((d) => !_isCartel(d))
        .toList();

    // Insert proyecto + archivo base
    await db.transaction(() async {
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              projectId: projectId,
              title: title,
              folder: Value(folder),
              createdAtMs: now,
              updatedAtMs: now,
              baseAssPath: baseDst,
            ),
          );

      await db
          .into(db.projectFiles)
          .insert(
            ProjectFilesCompanion.insert(
              fileId: _uuid.v4(),
              projectId: projectId,
              engine: 'base',
              assPath: baseDst,
              importedAtMs: now,
              dialogueCount: Value(baseDialogues.length),
              unmatchedCount: const Value(0),
            ),
          );

      if (videoDst != null) {
        await db
            .into(db.projectFiles)
            .insert(
              ProjectFilesCompanion.insert(
                fileId: _uuid.v4(),
                projectId: projectId,
                engine: 'video',
                assPath: videoDst,
                importedAtMs: now,
                dialogueCount: const Value(0),
                unmatchedCount: const Value(0),
              ),
            );
      }

      // Insert líneas base
      await db.batch((b) {
        for (int idx = 0; idx < baseDialogues.length; idx++) {
          final d = baseDialogues[idx];
          final lineId = _makeLineId(
            projectId,
            idx,
            d.startMs,
            d.endMs,
            d.style,
          );

          b.insert(
            db.subtitleLines,
            SubtitleLinesCompanion.insert(
              lineId: lineId,
              projectId: projectId,
              dialogueIndex: idx,
              eventsRowIndex: d.eventsRowIndex,
              startMs: d.startMs,
              endMs: d.endMs,
              style: Value(d.style),
              name: Value(d.name),
              effect: Value(d.effect),
              sourceText: Value(d.sourceText),
              romanization: Value(d.romanization),
              gloss: Value(d.gloss),
              dialoguePrefix: d.dialoguePrefix,
              leadingTags: Value(d.leadingTags),
              hasVectorDrawing: Value(d.hasVectorDrawing),
              originalText: d.text,
              updatedAtMs: now,
            ),
          );
        }
      });
    });

    // Import motores (alineación por índice si count coincide; si no, fallback por (start,end))
    final baseIndexByTime = _buildTimeIndex(baseDialogues);

    for (final entry in copiedEnginePaths.entries) {
      final engine = entry.key;
      if (engine == Engine.base) continue;

      final enginePath = entry.value;
      final engLines = await File(enginePath).readAsLines();
      final parsedEngine = AssParser.parseAssLines(engLines);
      final engDialogues = parsedEngine.dialogues
          .where((d) => !_isCartel(d))
          .toList();

      int unmatched = 0;

      final updates = <_CandidateUpdate>[];

      if (engDialogues.length == baseDialogues.length) {
        for (int i = 0; i < engDialogues.length; i++) {
          final cand = engDialogues[i].translationCandidate;
          if (cand == null) continue;
          updates.add(_CandidateUpdate(dialogueIndex: i, text: cand));
        }
      } else {
        // fallback por tiempo
        final used = <int>{};
        for (final d in engDialogues) {
          final idx = _matchByTime(baseIndexByTime, used, d.startMs, d.endMs);
          if (idx == null) {
            unmatched++;
            continue;
          }
          final cand = d.translationCandidate;
          if (cand == null) continue;
          updates.add(_CandidateUpdate(dialogueIndex: idx, text: cand));
        }
        unmatched += (engDialogues.length - updates.length).clamp(0, 1 << 30);
      }

      // Guardar project_files y aplicar updates
      final now2 = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        await db
            .into(db.projectFiles)
            .insert(
              ProjectFilesCompanion.insert(
                fileId: _uuid.v4(),
                projectId: projectId,
                engine: engineToStr(engine),
                assPath: enginePath,
                importedAtMs: now2,
                dialogueCount: Value(engDialogues.length),
                unmatchedCount: Value(unmatched),
              ),
            );

        await db.batch((b) {
          for (final u in updates) {
            final col = _candidateColumn(engine);
            b.update(
              db.subtitleLines,
              SubtitleLinesCompanion(
                updatedAtMs: Value(now2),
                // set dinámico abajo
              ).copyWith(
                candGpt: col == 'candGpt'
                    ? Value(u.text)
                    : const Value.absent(),
                candClaude: col == 'candClaude'
                    ? Value(u.text)
                    : const Value.absent(),
                candGemini: col == 'candGemini'
                    ? Value(u.text)
                    : const Value.absent(),
                candDeepseek: col == 'candDeepseek'
                    ? Value(u.text)
                    : const Value.absent(),
              ),
              where: (t) =>
                  t.projectId.equals(projectId) &
                  t.dialogueIndex.equals(u.dialogueIndex),
            );
          }
        });
      });
    }

    return projectId;
  }

  String _makeLineId(
    String projectId,
    int idx,
    int startMs,
    int endMs,
    String? style,
  ) {
    // estable y barato (sin guardar hashes largos)
    final raw = '$projectId|$idx|$startMs|$endMs|${style ?? ''}';
    final digest = sha1.convert(raw.codeUnits).toString(); // corto y suficiente
    return '$projectId-$digest';
  }

  Map<String, List<int>> _buildTimeIndex(List<ParsedDialogue> base) {
    final map = <String, List<int>>{};
    for (int i = 0; i < base.length; i++) {
      final k = '${base[i].startMs}-${base[i].endMs}';
      (map[k] ??= <int>[]).add(i);
    }
    return map;
  }

  int? _matchByTime(
    Map<String, List<int>> index,
    Set<int> used,
    int startMs,
    int endMs,
  ) {
    final k = '$startMs-$endMs';
    final candidates = index[k];
    if (candidates == null) return null;
    for (final idx in candidates) {
      if (!used.contains(idx)) {
        used.add(idx);
        return idx;
      }
    }
    return null;
  }

  String _candidateColumn(Engine e) {
    switch (e) {
      case Engine.gpt:
        return 'candGpt';
      case Engine.claude:
        return 'candClaude';
      case Engine.gemini:
        return 'candGemini';
      case Engine.deepseek:
        return 'candDeepseek';
      case Engine.base:
        return 'base';
    }
  }
}

class _CandidateUpdate {
  _CandidateUpdate({required this.dialogueIndex, required this.text});
  final int dialogueIndex;
  final String text;
}

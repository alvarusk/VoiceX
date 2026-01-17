import 'dart:io';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_db.dart';

class ExportService {
  ExportService(this.db);
  final AppDatabase db;

  Future<XFile> exportCleanAssXFile(String projectId) async {
    final project = await (db.select(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).getSingle();

    final lines =
        await (db.select(db.subtitleLines)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([(t) => OrderingTerm(expression: t.dialogueIndex)]))
            .get();

    final basePath = project.baseAssPath;

    final outName = _buildOutputName(
      basePath: basePath,
      fallbackTitle: project.title,
    );

    if (basePath.startsWith('web://')) {
      final text = _buildMinimalAss(lines);
      return XFile.fromData(
        Uint8List.fromList(utf8.encode(text)),
        mimeType: 'text/plain',
        name: outName,
      );
    }

    final baseFile = File(basePath);
    if (!await baseFile.exists()) {
      throw ExportBlockedException('No se encuentra el ASS base en: $basePath');
    }

    final baseLines = await baseFile.readAsLines();

    final eventsStart = baseLines.indexWhere(
      (l) => l.trim().toLowerCase() == '[events]',
    );
    if (eventsStart < 0) {
      throw ExportBlockedException('ASS base sin sección [Events].');
    }

    int firstDialogue = -1;
    for (int i = eventsStart; i < baseLines.length; i++) {
      if (baseLines[i].startsWith('Dialogue:')) {
        firstDialogue = i;
        break;
      }
    }
    if (firstDialogue < 0) {
      throw ExportBlockedException('ASS base sin líneas Dialogue:.');
    }

    final byEventRow = {for (final l in lines) l.eventsRowIndex: l};
    final useDialogueIndexFallback =
        _countDialogueLines(baseLines) == lines.length;

    int dialogueCursor = 0;
    for (int row = firstDialogue; row < baseLines.length; row++) {
      final raw = baseLines[row];
      final isDialogue = raw.startsWith('Dialogue:');
      if (!isDialogue && !raw.startsWith('Comment:')) continue;

      final absoluteIndex = row;
      final relativeIndex = row - firstDialogue;
      SubtitleLine? match =
          byEventRow[absoluteIndex] ?? byEventRow[relativeIndex];
      if (match == null && useDialogueIndexFallback && isDialogue) {
        if (dialogueCursor < lines.length) {
          match = lines[dialogueCursor];
        }
      }
      if (isDialogue) {
        dialogueCursor++;
      }
      if (match == null) continue;

      final selected = (match.selectedText ?? '').trim();
      if (selected.isEmpty) continue;

      if (raw.contains(r'\p')) continue;

      baseLines[row] = _replaceTextPreservingTags(
        raw,
        _normalizeToAssText(selected),
        forcedPrefix: match.dialoguePrefix,
      );
    }

    final tmp = await getTemporaryDirectory();
    final outDir = Directory(p.join(tmp.path, 'voicex_exports'));
    await outDir.create(recursive: true);

    final outPath = p.join(outDir.path, outName);

    final outFile = File(outPath);
    await outFile.writeAsString(baseLines.join('\n'));

    return XFile(outFile.path, mimeType: 'text/plain', name: outName);
  }

  String _buildOutputName({
    required String basePath,
    required String fallbackTitle,
  }) {
    final baseName = basePath.isNotEmpty ? p.basename(basePath) : '';
    final looksGeneric =
        baseName.isEmpty ||
        baseName.toLowerCase() == 'base.ass' ||
        baseName.toLowerCase() == 'base';

    String candidate = looksGeneric ? '' : baseName;
    if (candidate.isEmpty || !candidate.toLowerCase().endsWith('.ass')) {
      final rawTitle = fallbackTitle.trim().isEmpty
          ? 'voicex_export'
          : fallbackTitle;
      final safe = rawTitle.replaceAll(RegExp(r'[^A-Za-z0-9_. -]+'), '_');
      candidate = '${safe}_voicex_final.ass';
    }
    // Replace any known language code in the filename with es-es.
    candidate = candidate.replaceAll(
      RegExp('(en-us|ja-jp|zh-cn)', caseSensitive: false),
      'es-es',
    );
    if (!candidate.toLowerCase().endsWith('.ass')) {
      candidate = '$candidate.ass';
    }
    return candidate;
  }

  int _countDialogueLines(List<String> baseLines) {
    bool inEvents = false;
    int count = 0;
    for (final raw in baseLines) {
      final line = raw.trimRight();
      if (line.trim().toLowerCase() == '[events]') {
        inEvents = true;
        continue;
      }
      if (!inEvents) continue;
      if (line.startsWith('[') && !line.toLowerCase().startsWith('[events]')) {
        break;
      }
      if (line.startsWith('Dialogue:')) {
        count++;
      }
    }
    return count;
  }

  String _replaceTextPreservingTags(
    String dialogueLine,
    String newText, {
    String? forcedPrefix,
  }) {
    final parts = <String>[];
    int commas = 0;
    int last = 0;
    for (int i = 0; i < dialogueLine.length; i++) {
      if (dialogueLine[i] == ',' && commas < 9) {
        parts.add(dialogueLine.substring(last, i));
        last = i + 1;
        commas++;
      }
    }
    parts.add(dialogueLine.substring(last));

    if (parts.length < 10) return dialogueLine;

    final originalText = parts[9];
    final tagPrefix = RegExp(r'^(\{[^}]*\})+').stringMatch(originalText) ?? '';

    if (forcedPrefix != null && forcedPrefix.isNotEmpty) {
      // forcedPrefix ya incluye la coma final antes del texto.
      return '$forcedPrefix$tagPrefix$newText';
    }

    parts[9] = '$tagPrefix$newText';
    return parts.join(',');
  }

  String _normalizeToAssText(String s) {
    return s.replaceAll('\r\n', '\n').replaceAll('\n', r'\N');
  }

  String _buildMinimalAss(List<SubtitleLine> lines) {
    final buf = StringBuffer();
    buf.writeln('[Script Info]');
    buf.writeln('ScriptType: v4.00+');
    buf.writeln('Collisions: Normal');
    buf.writeln('PlayResX: 1920');
    buf.writeln('PlayResY: 1080');
    buf.writeln('');
    buf.writeln('[V4+ Styles]');
    buf.writeln(
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    );
    buf.writeln(
      'Style: Default,Arial,48,&H00FFFFFF,&H0000FFFF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,3,0,2,40,40,40,1',
    );
    buf.writeln('');
    buf.writeln('[Events]');
    buf.writeln(
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
    );
    for (final l in lines) {
      final t = (l.selectedText ?? '').trim();
      if (t.isEmpty) continue;
      final start = _assTime(l.startMs);
      final end = _assTime(l.endMs);
      final prefix = (l.doubt == true) ? 'Comment' : 'Dialogue';
      buf.writeln(
        '$prefix: 0,$start,$end,${l.style ?? "Default"},${l.name ?? ""},0,0,0,${l.effect ?? ""},${_normalizeToAssText(t)}',
      );
    }
    return buf.toString();
  }

  String _assTime(int ms) {
    final cs = (ms / 10).floor();
    final c = cs % 100;
    final totalSeconds = cs ~/ 100;
    final s = totalSeconds % 60;
    final m = (totalSeconds ~/ 60) % 60;
    final h = totalSeconds ~/ 3600;
    String two(int x) => x.toString().padLeft(2, '0');
    return '$h:${two(m)}:${two(s)}.${two(c)}';
  }
}

class ExportBlockedException implements Exception {
  ExportBlockedException(this.message);
  final String message;

  @override
  String toString() => message;
}

import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart';

import '../db/app_db.dart';

class ExportService {
  ExportService(this.db);
  final AppDatabase db;

  Future<XFile> exportCleanAssXFile(String projectId) async {
    final project = await (db.select(
      db.projects,
    )..where((t) => t.projectId.equals(projectId))).getSingle();

    final outName = _buildOutputName(
      basePath: project.baseAssPath,
      fallbackTitle: project.title,
    );
    final lines =
        await (db.select(db.subtitleLines)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([(t) => OrderingTerm(expression: t.dialogueIndex)]))
            .get();

    final text = _buildMinimalAss(lines);
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(text)),
      mimeType: 'text/plain',
      name: outName,
    );
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
      buf.writeln(
        'Dialogue: 0,$start,$end,${l.style ?? "Default"},${l.name ?? ""},0,0,0,${l.effect ?? ""},${_normalizeToAssText(t)}',
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

  String _buildOutputName({
    required String basePath,
    required String fallbackTitle,
  }) {
    final baseName = _basename(basePath);
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
    candidate = candidate.replaceAll(
      RegExp('(en-us|ja-jp|zh-cn)', caseSensitive: false),
      'es-es',
    );
    if (!candidate.toLowerCase().endsWith('.ass')) {
      candidate = '$candidate.ass';
    }
    return candidate;
  }

  String _basename(String path) {
    if (path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? '' : parts.last;
  }
}

class ExportBlockedException implements Exception {
  ExportBlockedException(this.message);
  final String message;
  @override
  String toString() => message;
}

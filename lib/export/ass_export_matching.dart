import '../db/app_db.dart';
import '../import/ass_parser.dart';

/// Match imported segments by content and timing, never by unverified offsets.
/// Names are deliberately excluded: reviewers can edit the actor name.
Map<int, SubtitleLine> matchAssExportLines(
  List<String> baseLines,
  List<SubtitleLine> lines,
) {
  final events = AssParser.parseAssLines(baseLines).dialogues;
  Object key(int start, int end, String? style, String? effect, String text) =>
      (start, end, style ?? '', effect ?? '', text);
  final byIdentity = <Object, List<ParsedDialogue>>{};
  final imported = <Object, List<SubtitleLine>>{};
  for (final event in events) {
    final identity = key(
      event.startMs,
      event.endMs,
      event.style,
      event.effect,
      event.text,
    );
    (byIdentity[identity] ??= []).add(event);
  }
  for (final line in lines) {
    final identity = key(
      line.startMs,
      line.endMs,
      line.style,
      line.effect,
      line.originalText,
    );
    (imported[identity] ??= []).add(line);
  }
  final result = <int, SubtitleLine>{};
  for (final entry in imported.entries) {
    final candidates = byIdentity[entry.key] ?? [];
    final group = entry.value
      ..sort((a, b) => a.dialogueIndex.compareTo(b.dialogueIndex));
    // Identical repeated events are safe only when their multiplicity agrees.
    if (candidates.length != group.length) continue;
    for (var i = 0; i < group.length; i++) {
      result[candidates[i].eventsRowIndex] = group[i];
    }
  }
  return result;
}

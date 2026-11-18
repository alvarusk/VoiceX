import 'package:drift/drift.dart';

import '../db/app_db.dart';

/// Use project-wide evidence so a missing translation on one line does not
/// accidentally switch a translation project into source review.
Stream<bool> watchSourceReview(AppDatabase db, String projectId) {
  return db
      .customSelect(
        '''SELECT NOT EXISTS (
      SELECT 1 FROM project_files WHERE project_id = ?
      AND engine IN ('final', 'gpt', 'claude', 'gemini', 'deepseek')
    ) AND NOT EXISTS (
      SELECT 1 FROM subtitle_lines WHERE project_id = ? AND (
        COALESCE(cand_final, '') <> '' OR COALESCE(cand_gpt, '') <> '' OR
        COALESCE(cand_claude, '') <> '' OR COALESCE(cand_gemini, '') <> '' OR
        COALESCE(cand_deepseek, '') <> '' OR COALESCE(selected_text, '') <> ''
      )
    ) AS source_review''',
        variables: [Variable(projectId), Variable(projectId)],
        readsFrom: {db.projectFiles, db.subtitleLines},
      )
      .watchSingle()
      .map((row) => row.read<bool>('source_review'));
}

String sourceReviewText(SubtitleLine line) {
  String clean(String text) => text
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\N');
  final text = clean(line.originalText).trim();
  final note = clean(line.reviewNote ?? '').trim();
  return '$text${note.isEmpty ? '' : '($note)'}';
}

String sourceReviewEvent(SubtitleLine line) {
  final prefix = line.dialoguePrefix.replaceFirst(
    RegExp(r'^\s*(Dialogue|Comment):'),
    line.doubt ? 'Comment:' : 'Dialogue:',
  );
  return '$prefix${sourceReviewText(line)}';
}

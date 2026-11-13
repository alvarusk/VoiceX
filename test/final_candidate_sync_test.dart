import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voicex/db/app_db.dart';
import 'package:voicex/sync/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late bool staleView;
  late bool missingTableColumn;
  late List<String> relations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://sync-test.invalid',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
        expect(request.method, 'GET');
        final relation = request.url.pathSegments.last;
        if (relation == 'projects') {
          return json({
            'project_id': 'project',
            'title': 'FINAL sync',
            'folder': 'Test',
            'base_ass_path': '',
            'created_at_ms': 1,
            'updated_at_ms': 2,
          });
        }
        if (relation == 'project_files') return json([]);
        expect(relation, isIn(['subtitle_lines_active', 'subtitle_lines']));
        relations.add(relation);
        final requiresFinal = (request.url.queryParameters['select'] ?? '*')
            .split(',')
            .contains('cand_final');
        if (requiresFinal &&
            ((relation == 'subtitle_lines_active' && staleView) ||
                missingTableColumn)) {
          return json({
            'code': '42703',
            'message': 'column $relation.cand_final does not exist',
          }, 400);
        }
        return json([
          {
            'line_id': 'line',
            'project_id': 'project',
            'dialogue_index': 0,
            'original_text': 'Original',
            'cand_gpt': 'GPT translation',
            if (relation != 'subtitle_lines_active' || !staleView)
              'cand_final': 'FINAL translation',
            'updated_at_ms': 2,
          },
        ]);
      }),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    staleView = false;
    missingTableColumn = false;
    relations = [];
  });
  tearDown(() => db.close());

  test('downloads FINAL through an updated active view', () async {
    await _ReadyCloudSync(db).pullProject('project');
    final line = await db.select(db.subtitleLines).getSingle();
    expect(line.candFinal, 'FINAL translation');
    expect(line.candGpt, 'GPT translation');
    expect(relations, ['subtitle_lines_active']);
  });

  test(
    'an older active view falls back to the table without losing FINAL',
    () async {
      staleView = true;
      await _ReadyCloudSync(db).pullProject('project');
      final line = await db.select(db.subtitleLines).getSingle();
      expect(line.candFinal, 'FINAL translation');
      expect(line.candGpt, 'GPT translation');
      expect(relations, ['subtitle_lines_active', 'subtitle_lines']);
    },
  );

  test(
    'a missing server migration fails instead of silently dropping FINAL',
    () async {
      staleView = true;
      missingTableColumn = true;
      await expectLater(
        _ReadyCloudSync(db).pullProject('project'),
        throwsA(isA<CloudSyncException>()),
      );
      expect(await db.select(db.subtitleLines).get(), isEmpty);
    },
  );
}

class _ReadyCloudSync extends CloudSyncService {
  _ReadyCloudSync(super.db);

  @override
  bool get isReady => true;
}

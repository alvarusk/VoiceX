import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicex/settings/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService.instance;
  const folders = ['Demo', 'Test Folder', 'TestFolder'];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.clearCloudScopedState();
    await settings.setArchivedFoldersFromSync(folders, 200);
  });

  test('legacy settings cannot erase archives on sync or restart', () async {
    final legacy = <String, dynamic>{
      'updated_at_ms': 300,
      'manual_folders': folders,
    };
    expect(SettingsService.archivedFoldersTimestamp(legacy), 0);
    expect(await settings.importSyncPayload(legacy), isTrue);
    await settings.init();
    expect(settings.archivedFolders, folders);
    expect(settings.manualFolders, isEmpty);
    expect(settings.archivedFoldersUpdatedAtMs, 200);
  });

  test('newer general settings cannot override newer archive state', () async {
    await settings.importSyncPayload({
      'updated_at_ms': 300,
      'archived_folders': <String>[],
      'archived_folders_updated_at_ms': 100,
    });
    expect(settings.archivedFolders, folders);
    expect(settings.archivedFoldersUpdatedAtMs, 200);
  });

  test('explicit newer unarchive still syncs', () async {
    await settings.importSyncPayload({
      'updated_at_ms': 300,
      'archived_folders': <String>[],
      'archived_folders_updated_at_ms': 250,
    });
    await settings.init();
    expect(settings.archivedFolders, isEmpty);
    expect(settings.archivedFoldersUpdatedAtMs, 250);
  });

  test('archive lists without a dedicated timestamp remain compatible', () {
    expect(
      SettingsService.archivedFoldersTimestamp({
        'updated_at_ms': 300,
        'archived_folders': folders,
      }),
      300,
    );
  });
}

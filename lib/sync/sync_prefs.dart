import 'package:shared_preferences/shared_preferences.dart';

class SyncPrefs {
  static const _prefix = 'last_synced_';

  Future<int?> getLastSynced(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$projectId');
  }

  Future<void> setLastSynced(String projectId, int tsMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$projectId', tsMs);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

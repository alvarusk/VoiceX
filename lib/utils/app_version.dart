import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Lee la version de la app (versionName + buildNumber) y la cachea.
class AppVersion {
  AppVersion._();

  static final Future<String> _versionFuture = _readVersion();

  static Future<String> load() => _versionFuture;

  static Future<String> _readVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
      return '${info.version}$build';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[app_version] error leyendo version: $e');
      }
      return '';
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_version.dart';

class AppUpdateResult {
  const AppUpdateResult({
    required this.storeUrl,
    required this.currentVersion,
    required this.immediateAllowed,
    required this.flexibleAllowed,
    this.availableVersionCode,
  });

  final String storeUrl;
  final String currentVersion;
  final bool immediateAllowed;
  final bool flexibleAllowed;
  final int? availableVersionCode;
}

class AppUpdateChecker {
  const AppUpdateChecker({
    required this.packageName,
    required this.storeUrl,
  });

  final String packageName;
  final String storeUrl;

  String get _resolvedStoreUrl =>
      storeUrl.isNotEmpty ? storeUrl : 'https://play.google.com/store/apps/details?id=$packageName';

  Future<AppUpdateResult?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return null;
      }
      final versionLabel = await AppVersion.load();
      return AppUpdateResult(
        storeUrl: _resolvedStoreUrl,
        currentVersion: versionLabel,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
        availableVersionCode: info.availableVersionCode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[update_check] error al comprobar actualizaciones: $e');
      }
      return null;
    }
  }

  Future<bool> startImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[update_check] error en immediate update: $e');
      }
      return false;
    }
  }

  Future<void> openPlayStore() async {
    try {
      await launchUrl(
        Uri.parse(_resolvedStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[update_check] error al abrir Play Store: $e');
      }
    }
  }
}

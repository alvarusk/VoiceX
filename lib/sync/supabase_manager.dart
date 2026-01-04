import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Gestiona la instancia de Supabase en toda la app.
///
/// Usa variables de entorno (dart-define o .env) SUPABASE_URL y SUPABASE_ANON_KEY.
/// Si faltan, el cliente no se inicializa y `isReady` será false.
class SupabaseManager {
  SupabaseManager._();
  static final SupabaseManager instance = SupabaseManager._();

  bool _ready = false;
  bool _initAttempted = false;

  bool get isReady => _ready;
  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    if (_ready) return;

    // Permit reintentos si la primera inicialización falló.
    if (_initAttempted && !_ready) {
      if (kDebugMode) {
        debugPrint('[supabase] reintentando inicialización...');
      }
    }
    _initAttempted = true;
    await _loadEnvFromCandidates();

    final platformEnv = Platform.environment;
    final envUrl = dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
    final envKey = dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';

    final url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '')
        .ifEmpty(() => platformEnv['SUPABASE_URL'] ?? '')
        .ifEmpty(() => envUrl);
    final key = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '')
        .ifEmpty(() => platformEnv['SUPABASE_ANON_KEY'] ?? '')
        .ifEmpty(() => envKey);

    if (url.isEmpty || key.isEmpty) {
      if (kDebugMode) {
        debugPrint('[supabase] Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Candidatos: '
            'envUrl=${envUrl.isNotEmpty}, envKey=${envKey.isNotEmpty}, '
            'platformUrl=${(platformEnv['SUPABASE_URL'] ?? '').isNotEmpty}, '
            'platformKey=${(platformEnv['SUPABASE_ANON_KEY'] ?? '').isNotEmpty}');
      }
      _ready = false;
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[supabase] inicializando con url length=${url.length}, key length=${key.length}');
      }
      await Supabase.initialize(url: url, anonKey: key);
      _ready = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[supabase] init error: $e');
      }
      _ready = false;
    }
  }
}

extension on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}

Future<void> _loadEnvFromCandidates() async {
  final candidates = <String>{'.env'};
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add(p.join(exeDir, '.env'));
  } catch (_) {}
  try {
    final supportDir = await getApplicationSupportDirectory();
    candidates.add(p.join(supportDir.path, '.env'));
  } catch (_) {}

  for (final path in candidates) {
    try {
      final file = File(path);
      final exists = await file.exists();
      if (kDebugMode) {
        debugPrint('[supabase] buscando .env en $path (exists=$exists)');
      }
      if (exists) {
        try {
          final content = await file.readAsString();
          final parsed = _parseEnv(content);
          final merged = dotenv.isInitialized
              ? Map<String, String>.from(dotenv.env)
              : <String, String>{};
          merged.addAll(parsed);
          dotenv.env
            ..clear()
            ..addAll(merged);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[supabase] error leyendo $path: $e');
          }
        }
        return;
      }
    } catch (_) {
      // sigue con el siguiente
    }
  }
}

Map<String, String> _parseEnv(String content) {
  final map = <String, String>{};
  for (final rawLine in content.split(RegExp(r'\r?\n'))) {
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    if (key.isNotEmpty) {
      map[key] = value;
    }
  }
  return map;
}

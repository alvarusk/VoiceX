import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona la instancia de Supabase en toda la app.
///
/// Usa variables de entorno (dart-define o .env) SUPABASE_URL y SUPABASE_ANON_KEY.
/// Si faltan o no hay sesion, el cliente no queda listo y `isReady` sera false.
class SupabaseManager {
  SupabaseManager._();
  static final SupabaseManager instance = SupabaseManager._();

  bool _ready = false;
  bool _authed = false;
  bool _initAttempted = false;
  Future<void>? _authInFlight;
  String _authEmail = '';
  String _authPassword = '';

  bool get isReady => _ready && _authed;
  SupabaseClient get client => Supabase.instance.client;
  String? get userId =>
      _authed ? Supabase.instance.client.auth.currentUser?.id : null;

  Future<void> init() async {
    if (_ready && _authed) return;

    final fileEnv = await _readEnvFromCandidates();
    final platformEnv = Platform.environment;

    String readEnv(String key) {
      return _readDefine(key)
          .ifEmpty(() => platformEnv[key] ?? '')
          .ifEmpty(() => fileEnv[key] ?? '');
    }

    final envUrl = fileEnv['SUPABASE_URL'] ?? '';
    final envKey = fileEnv['SUPABASE_ANON_KEY'] ?? '';

    final url = readEnv('SUPABASE_URL');
    final key = readEnv('SUPABASE_ANON_KEY');
    _authEmail = readEnv('SUPABASE_USER_EMAIL');
    _authPassword = readEnv('SUPABASE_USER_PASSWORD');

    if (!_ready) {
      // Permit reintentos si la primera inicializacion fallo.
      if (_initAttempted && !_ready) {
        if (kDebugMode) {
          debugPrint('[supabase] reintentando inicializacion...');
        }
      }
      _initAttempted = true;

      if (url.isEmpty || key.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[supabase] Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Candidatos: '
            'envUrl=${envUrl.isNotEmpty}, envKey=${envKey.isNotEmpty}, '
            'platformUrl=${(platformEnv['SUPABASE_URL'] ?? '').isNotEmpty}, '
            'platformKey=${(platformEnv['SUPABASE_ANON_KEY'] ?? '').isNotEmpty}',
          );
        }
        _ready = false;
        return;
      }

      try {
        if (kDebugMode) {
          debugPrint(
            '[supabase] inicializando con url length=${url.length}, key length=${key.length}',
          );
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

    await _ensureAuth();
  }

  Future<void> _ensureAuth() async {
    if (!_ready) return;
    if (_authInFlight != null) {
      await _authInFlight;
      return;
    }

    _authInFlight = () async {
      final auth = Supabase.instance.client.auth;
      final current = auth.currentUser;
      final hasAnyPasswordAuth =
          _authEmail.isNotEmpty || _authPassword.isNotEmpty;
      final wantsPasswordAuth =
          _authEmail.isNotEmpty && _authPassword.isNotEmpty;
      if (hasAnyPasswordAuth && !wantsPasswordAuth) {
        if (kDebugMode) {
          debugPrint(
            '[supabase] SUPABASE_USER_EMAIL y SUPABASE_USER_PASSWORD incompletos.',
          );
        }
        _authed = false;
        return;
      }

      if (current != null) {
        if (!wantsPasswordAuth || !current.isAnonymous) {
          _authed = true;
          return;
        }
        try {
          await auth.signOut();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[supabase] signOut error: $e');
          }
        }
      }

      bool ok = false;
      if (wantsPasswordAuth) {
        try {
          final res = await auth.signInWithPassword(
            email: _authEmail,
            password: _authPassword,
          );
          ok = res.user != null;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[supabase] signInWithPassword error: $e');
          }
        }
      } else {
        try {
          final res = await auth.signInAnonymously();
          ok = res.user != null;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[supabase] signInAnonymously error: $e');
          }
        }
      }
      _authed = ok;
    }();

    try {
      await _authInFlight;
    } finally {
      _authInFlight = null;
    }
  }
}

String _readDefine(String key) {
  switch (key) {
    case 'SUPABASE_URL':
      return const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    case 'SUPABASE_ANON_KEY':
      return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    case 'SUPABASE_USER_EMAIL':
      return const String.fromEnvironment('SUPABASE_USER_EMAIL', defaultValue: '');
    case 'SUPABASE_USER_PASSWORD':
      return const String.fromEnvironment('SUPABASE_USER_PASSWORD', defaultValue: '');
    case 'R2_ACCOUNT_ID':
      return const String.fromEnvironment('R2_ACCOUNT_ID', defaultValue: '');
    case 'R2_ACCESS_KEY':
      return const String.fromEnvironment('R2_ACCESS_KEY', defaultValue: '');
    case 'R2_SECRET_KEY':
      return const String.fromEnvironment('R2_SECRET_KEY', defaultValue: '');
    case 'R2_BUCKET':
      return const String.fromEnvironment('R2_BUCKET', defaultValue: '');
    case 'R2_PUBLIC_BASE':
      return const String.fromEnvironment('R2_PUBLIC_BASE', defaultValue: '');
    default:
      return '';
  }
}

extension on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}

Future<Map<String, String>> _readEnvFromCandidates() async {
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
        final lines = await file.readAsLines();
        return _parseEnv(lines);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[supabase] error leyendo $path: $e');
      }
    }
  }
  return const {};
}

Map<String, String> _parseEnv(List<String> lines) {
  final map = <String, String>{};
  for (final rawLine in lines) {
    final line = rawLine.trim();
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

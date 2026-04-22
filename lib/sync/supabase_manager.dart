import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona la instancia de Supabase en toda la app.
///
/// Usa variables de entorno (dart-define o .env) SUPABASE_URL y SUPABASE_ANON_KEY.
/// Si faltan o no hay sesion, el cliente no queda listo y `isReady` sera false.
class SupabaseManager extends ChangeNotifier {
  SupabaseManager._();
  static final SupabaseManager instance = SupabaseManager._();

  bool _configPresent = false;
  bool _ready = false;
  bool _authed = false;
  bool _initAttempted = false;
  Future<void>? _coreInitInFlight;
  Future<Map<String, String>>? _envLoadInFlight;
  Map<String, String>? _cachedFileEnv;
  Future<void>? _authInFlight;
  StreamSubscription<AuthState>? _authStateSub;
  String _authEmail = '';
  String _authPassword = '';
  String? _authError;

  bool get hasCloudConfig => _configPresent;
  bool get isReady => _ready && _authed;
  bool get isAuthenticated => _authed;
  bool get initAttempted => _initAttempted;
  bool get isInitializing =>
      _coreInitInFlight != null || _authInFlight != null;
  String? get authError => _authError;
  String? get currentUserEmail =>
      _authed ? Supabase.instance.client.auth.currentUser?.email : null;
  SupabaseClient get client => Supabase.instance.client;
  String? get userId =>
      _authed ? Supabase.instance.client.auth.currentUser?.id : null;

  Future<void> init() async {
    if (_ready && _authed) return;

    final fileEnv = await _loadFileEnv();
    final platformEnv = Platform.environment;

    String readEnv(String key) {
      return _readDefine(key)
          .ifEmpty(() => platformEnv[key] ?? '')
          .ifEmpty(() => _readDotenv(key))
          .ifEmpty(() => fileEnv[key] ?? '');
    }

    final envUrl = fileEnv['SUPABASE_URL'] ?? '';
    final envKey = fileEnv['SUPABASE_ANON_KEY'] ?? '';

    final url = readEnv('SUPABASE_URL');
    final key = readEnv('SUPABASE_ANON_KEY');
    final configPresent = url.isNotEmpty && key.isNotEmpty;
    if (_configPresent != configPresent) {
      _configPresent = configPresent;
      notifyListeners();
    }
    _authEmail = readEnv('SUPABASE_USER_EMAIL');
    _authPassword = readEnv('SUPABASE_USER_PASSWORD').ifEmpty(
      () => _readBase64Secret(
        _readDefine('SUPABASE_USER_PASSWORD_B64')
            .ifEmpty(() => platformEnv['SUPABASE_USER_PASSWORD_B64'] ?? '')
            .ifEmpty(() => _readDotenv('SUPABASE_USER_PASSWORD_B64'))
            .ifEmpty(() => fileEnv['SUPABASE_USER_PASSWORD_B64'] ?? ''),
      ),
    );

    await _ensureCoreInitialized(
      url: url,
      key: key,
      envUrlPresent: envUrl.isNotEmpty,
      envKeyPresent: envKey.isNotEmpty,
      platformUrlPresent: (platformEnv['SUPABASE_URL'] ?? '').isNotEmpty,
      platformKeyPresent: (platformEnv['SUPABASE_ANON_KEY'] ?? '').isNotEmpty,
    );

    await _ensureAuth();
  }

  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await init();
    if (!_ready) {
      _authError = 'Supabase no esta configurado correctamente.';
      notifyListeners();
      return false;
    }

    _authEmail = email.trim();
    _authPassword = password;
    await _ensureAuth(force: true);
    return _authed;
  }

  Future<void> signOut() async {
    if (!_ready) return;
    _authEmail = '';
    _authPassword = '';
    _authError = null;
    _authed = false;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[supabase] signOut error: $e');
      }
    }
  }

  Future<void> _ensureCoreInitialized({
    required String url,
    required String key,
    required bool envUrlPresent,
    required bool envKeyPresent,
    required bool platformUrlPresent,
    required bool platformKeyPresent,
  }) async {
    if (_ready) return;
    if (_coreInitInFlight != null) {
      await _coreInitInFlight;
      return;
    }

    _coreInitInFlight = () async {
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
            'envUrl=$envUrlPresent, envKey=$envKeyPresent, '
            'platformUrl=$platformUrlPresent, '
            'platformKey=$platformKeyPresent',
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
        _attachAuthStateListener();
        _ready = true;
        _authError = null;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[supabase] init error: $e');
        }
        _ready = false;
        notifyListeners();
      }
    }();

    try {
      await _coreInitInFlight;
    } finally {
      _coreInitInFlight = null;
    }
  }

  void _attachAuthStateListener() {
    if (_authStateSub != null) return;
    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final user = data.session?.user;
      final nextAuthed = user != null && !user.isAnonymous;
      if (_authed != nextAuthed) {
        _authed = nextAuthed;
        if (nextAuthed) {
          _authError = null;
        }
        notifyListeners();
      }
    });
  }

  Future<void> _ensureAuth({bool force = false}) async {
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
      if (kDebugMode) {
        debugPrint(
          '[supabase] auth email present=${_authEmail.isNotEmpty}, password present=${_authPassword.isNotEmpty}',
        );
      }
      if (hasAnyPasswordAuth && !wantsPasswordAuth) {
        if (kDebugMode) {
          debugPrint(
            '[supabase] SUPABASE_USER_EMAIL y SUPABASE_USER_PASSWORD incompletos.',
          );
        }
        _authed = false;
        _authError = 'Faltan credenciales de acceso a cloud.';
        notifyListeners();
        return;
      }

      if (current != null) {
        if (!force &&
            !current.isAnonymous &&
            (!wantsPasswordAuth || current.email == _authEmail)) {
          _authed = true;
          _authError = null;
          notifyListeners();
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
          _authError = ok ? null : 'No se pudo iniciar sesion en Supabase.';
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[supabase] signInWithPassword error: $e');
          }
          _authError = 'Credenciales invalidas o acceso no permitido.';
        }
      } else {
        _authError = null;
      }
      _authed = ok;
      notifyListeners();
    }();

    try {
      await _authInFlight;
    } finally {
      _authInFlight = null;
    }
  }
}

String _readDotenv(String key) {
  if (!dotenv.isInitialized) return '';
  return dotenv.env[key] ?? '';
}

String _readBase64Secret(String encoded) {
  if (encoded.isEmpty) return '';
  try {
    return utf8.decode(base64.decode(encoded));
  } catch (_) {
    return '';
  }
}

Future<Map<String, String>> _loadFileEnv() async {
  final manager = SupabaseManager.instance;
  final cached = manager._cachedFileEnv;
  if (cached != null) return cached;
  if (manager._envLoadInFlight != null) {
    return manager._envLoadInFlight!;
  }

  manager._envLoadInFlight = () async {
    final env = await _readEnvFromCandidates();
    manager._cachedFileEnv = env;
    return env;
  }();

  try {
    return await manager._envLoadInFlight!;
  } finally {
    manager._envLoadInFlight = null;
  }
}

String _readDefine(String key) {
  switch (key) {
    case 'SUPABASE_URL':
      return const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    case 'SUPABASE_ANON_KEY':
      return const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      );
    case 'SUPABASE_USER_EMAIL':
      return const String.fromEnvironment(
        'SUPABASE_USER_EMAIL',
        defaultValue: '',
      );
    case 'SUPABASE_USER_PASSWORD':
      return const String.fromEnvironment(
        'SUPABASE_USER_PASSWORD',
        defaultValue: '',
      );
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

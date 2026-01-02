import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona la instancia de Supabase en toda la app.
///
/// Usa variables de entorno (dart-define o .env) SUPABASE_URL y SUPABASE_ANON_KEY.
/// Si faltan, el cliente no se inicializa y `isReady` será false.
class SupabaseManager {
  SupabaseManager._();
  static final SupabaseManager instance = SupabaseManager._();

  bool _initAttempted = false;
  bool _ready = false;

  bool get isReady => _ready;
  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    if (_initAttempted) return;
    _initAttempted = true;

    // Carga .env si existe (sin fallar si no está)
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    final envUrl = dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
    final envKey = dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';

    final url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '')
        .ifEmpty(() => envUrl);
    final key = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '')
        .ifEmpty(() => envKey);

    if (url.isEmpty || key.isEmpty) {
      _ready = false;
      return;
    }

    try {
      await Supabase.initialize(url: url, anonKey: key);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }
}

extension on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}

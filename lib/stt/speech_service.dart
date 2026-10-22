// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper estable para speech_to_text para que ReviewPage no dependa
/// directamente del plugin.
///
/// En Windows, speech_to_text suele no estar implementado -> atrapamos
/// MissingPluginException y marcamos `available=false`.
class SpeechService {
  SpeechService._() : _speech = stt.SpeechToText();
  @visibleForTesting
  SpeechService.forTesting(this._speech);
  static final SpeechService instance = SpeechService._();

  final stt.SpeechToText _speech;

  bool _initAttempted = false;
  bool _initializedOk = false;
  Future<bool>? _initializing;

  /// Disponible y permisos OK (según initialize()).
  final ValueNotifier<bool> available = ValueNotifier<bool>(false);

  /// Estado listening del plugin.
  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);

  /// Texto parcial durante dictado.
  final ValueNotifier<String> partial = ValueNotifier<String>('');

  /// Texto final.
  final ValueNotifier<String> finalText = ValueNotifier<String>('');

  List<stt.LocaleName> _locales = const [];
  String? _spanishLocale;

  bool get isListening => _speech.isListening;

  Future<bool> ensureInitialized() => _initializing ??= _initialize();

  Future<bool> _initialize() async {
    if (_initAttempted) return _initializedOk;

    _initAttempted = true;
    bool ok = false;

    try {
      ok = await _speech.initialize(
        debugLogging: true,
        onStatus: (status) {
          debugPrint('STT status: $status');
          listening.value = _speech.isListening;
        },
        onError: (err) {
          debugPrint('STT error: $err');
          listening.value = false;
        },
      );
    } on MissingPluginException {
      ok = false;
    } catch (_) {
      ok = false;
    }

    if (ok) {
      try {
        _locales = await _speech.locales();
        for (final locale in _locales) {
          final id = locale.localeId.replaceAll('_', '-').toLowerCase();
          if (id == 'es' || id.startsWith('es-')) {
            _spanishLocale ??= locale.localeId;
            if (id == 'es-es') {
              _spanishLocale = locale.localeId;
              break;
            }
          }
        }
      } catch (_) {
        _locales = const [];
      }
    }
    ok = ok && _spanishLocale != null;
    _initializedOk = ok;
    available.value = ok;
    return ok;
  }

  Future<List<stt.LocaleName>> locales() async {
    await ensureInitialized();
    return _locales;
  }

  /// Empieza a escuchar y llama a `onResult` cuando el plugin marque finalResult.
  Future<void> listen({
    required FutureOr<void> Function(String text) onResult,
  }) async {
    final ok = await ensureInitialized();
    if (!ok) return;

    partial.value = '';
    finalText.value = '';

    try {
      await _speech.listen(
        localeId: _spanishLocale!,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        onResult: (res) async {
          final txt = res.recognizedWords;
          partial.value = txt;
          if (res.finalResult) {
            finalText.value = txt;
            await onResult(txt.trim());
          }
        },
      );
      listening.value = _speech.isListening;
    } on MissingPluginException {
      available.value = false;
      listening.value = false;
    } catch (_) {
      listening.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    listening.value = false;
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
    listening.value = false;
  }
}

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
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initAttempted = false;
  bool _initializedOk = false;

  /// Disponible y permisos OK (según initialize()).
  final ValueNotifier<bool> available = ValueNotifier<bool>(false);

  /// Estado listening del plugin.
  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);

  /// Texto parcial durante dictado.
  final ValueNotifier<String> partial = ValueNotifier<String>('');

  /// Texto final.
  final ValueNotifier<String> finalText = ValueNotifier<String>('');

  List<stt.LocaleName> _locales = const [];
  String? preferredLocale = 'es-ES';

  bool get isListening => _speech.isListening;

  Future<bool> ensureInitialized() async {
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

    _initializedOk = ok;
    available.value = ok;

    if (ok) {
      try {
        _locales = await _speech.locales();
        // Añade override aunque no esté anunciado, para intentar forzar es-ES si el paquete está instalado.
        if (preferredLocale != null &&
            !_locales.any((l) => l.localeId.toLowerCase() == preferredLocale!.toLowerCase())) {
          _locales = List<stt.LocaleName>.from(_locales)
            ..add(stt.LocaleName(preferredLocale!, preferredLocale!));
        }
      } catch (_) {
        _locales = const [];
      }
    }
    return ok;
  }

  Future<List<stt.LocaleName>> locales() async {
    await ensureInitialized();
    return _locales;
  }

  /// Empieza a escuchar y llama a `onResult` cuando el plugin marque finalResult.
  Future<void> listen({
    String? localeId,
    required FutureOr<void> Function(String text) onResult,
  }) async {
    final ok = await ensureInitialized();
    if (!ok) return;

    partial.value = '';
    finalText.value = '';

    String? targetLocale = localeId;
    final pref = preferredLocale;
    if ((targetLocale == null || targetLocale.isEmpty) &&
        pref != null &&
        _locales.any((l) => l.localeId.toLowerCase() == pref.toLowerCase())) {
      targetLocale = pref;
    }

    try {
      await _speech.listen(
        localeId: targetLocale,
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
      listening.value = true;
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

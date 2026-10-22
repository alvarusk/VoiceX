import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:voicex/stt/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  var installed = <String>[];
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'locales') return installed;
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('dictates in Spanish even when the system language is French', () async {
    installed = ['fr-FR:French', 'es_MX:Spanish Mexico', 'es_ES:Spanish Spain'];
    final speech = SpeechService.forTesting(SpeechToText.withMethodChannel());
    final results = await Future.wait([
      speech.ensureInitialized(),
      speech.ensureInitialized(),
    ]);
    expect(results, [true, true]);
    expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
    await speech.listen(onResult: (_) {});
    final listen = calls.singleWhere((c) => c.method == 'listen');
    expect((listen.arguments as Map)['localeId'], 'es_ES');
    await speech.cancel();
  });

  test('accepts an installed Spanish variant', () async {
    installed = ['fr-FR:French', 'es-MX:Spanish Mexico'];
    final speech = SpeechService.forTesting(SpeechToText.withMethodChannel());
    await speech.listen(onResult: (_) {});
    final listen = calls.singleWhere((c) => c.method == 'listen');
    expect((listen.arguments as Map)['localeId'], 'es-MX');
    await speech.cancel();
  });

  test('does not start dictation without Spanish', () async {
    installed = ['fr-FR:French', 'en-US:English'];
    final speech = SpeechService.forTesting(SpeechToText.withMethodChannel());
    expect(await speech.ensureInitialized(), isFalse);
    await speech.listen(onResult: (_) {});
    expect(speech.available.value, isFalse);
    expect(calls.where((c) => c.method == 'listen'), isEmpty);
  });
}

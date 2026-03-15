import 'dart:convert';

import 'package:http/http.dart' as http;

import 'openai_usage.dart';

class OpenAiService {
  OpenAiService({required this.apiKey});

  final String apiKey;

  static const _base = 'https://api.openai.com/v1';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  Future<OpenAiTextResult> refineSpanishPunctuation({
    required String text,
    String model = 'gpt-4o-mini',
  }) async {
    final prompt = '''
Arregla la puntuación y las mayúsculas en español.
- NO cambies palabras, nombres ni números.
- NO inventes contenido.
- Mantén el mismo registro.
Devuelve SOLO el texto final (sin comillas, sin explicaciones).

TEXTO:
$text
''';

    final uri = Uri.parse('$_base/responses');
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'model': model,
        'input': prompt,
        'text': {'format': {'type': 'text'}},
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OpenAI refine error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return OpenAiTextResult(
      text: _extractOutputText(data).trim(),
      model: (data['model'] as String?) ?? model,
      usage: _extractUsage(data),
    );
  }

  Future<OpenAiTranscriptionResult> transcribeAudioFile({
    required String filePath,
    String model = 'gpt-4o-mini-transcribe',
    String? language,
    String? prompt,
  }) async {
    final uri = Uri.parse('$_base/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $apiKey';

    req.fields['model'] = model;
    if (language != null && language.isNotEmpty) {
      req.fields['language'] = language;
    }
    if (prompt != null && prompt.isNotEmpty) {
      req.fields['prompt'] = prompt;
    }

    req.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('OpenAI STT error ${streamed.statusCode}: $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final t = (data['text'] as String?) ?? '';
    return OpenAiTranscriptionResult(
      text: t.trim(),
      model: (data['model'] as String?) ?? model,
      usage: _extractUsage(data),
    );
  }

  static String _extractOutputText(Map<String, dynamic> responseJson) {
    final output = responseJson['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map<String, dynamic>) {
          final content = item['content'];
          if (content is List) {
            for (final c in content) {
              if (c is Map<String, dynamic> && c['type'] == 'output_text') {
                final t = c['text'];
                if (t is String) return t;
              }
            }
          }
        }
      }
    }
    return '';
  }

  static OpenAiUsage _extractUsage(Map<String, dynamic> responseJson) {
    final usage = responseJson['usage'];
    if (usage is! Map<String, dynamic>) {
      return const OpenAiUsage();
    }

    final inputTokens =
        _readInt(usage['input_tokens']) ??
        _readInt(usage['input_audio_tokens']) ??
        0;
    final outputTokens =
        _readInt(usage['output_tokens']) ??
        _readInt(usage['output_text_tokens']) ??
        0;
    final totalTokens =
        _readInt(usage['total_tokens']) ?? (inputTokens + outputTokens);
    final durationSeconds =
        _readDouble(usage['seconds']) ??
        _readDouble(usage['duration_seconds']) ??
        _readDouble(responseJson['duration']) ??
        0;

    return OpenAiUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      durationSeconds: durationSeconds,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

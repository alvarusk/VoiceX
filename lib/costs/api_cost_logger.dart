import 'package:flutter/foundation.dart';

import '../db/app_db.dart';
import '../openai/openai_usage.dart';
import '../sync/supabase_manager.dart';
import 'costs_repository.dart';

class ApiCostLogger {
  static const Map<String, ({double inputUsdPer1M, double outputUsdPer1M})>
      _tokenRates = {
        'gpt-4.1': (inputUsdPer1M: 2.0, outputUsdPer1M: 8.0),
        'gpt-4.1-mini': (inputUsdPer1M: 0.4, outputUsdPer1M: 1.6),
        'gpt-4.1-nano': (inputUsdPer1M: 0.1, outputUsdPer1M: 0.4),
        'gpt-4o': (inputUsdPer1M: 2.5, outputUsdPer1M: 10.0),
        'gpt-4o-mini': (inputUsdPer1M: 0.15, outputUsdPer1M: 0.6),
      };

  static const Map<String, double> _audioUsdPerMinute = {
    'gpt-4o-transcribe': 0.006,
    'gpt-4o-mini-transcribe': 0.003,
    'whisper-1': 0.006,
  };

  Future<void> logOpenAiUsage({
    required Project project,
    required String model,
    required OpenAiUsage usage,
    String? engine,
  }) async {
    if (!usage.hasUsage) return;

    try {
      await SupabaseManager.instance.init();
      if (!SupabaseManager.instance.isReady) return;

      final safeModel = model.trim();
      final safeEngine = (engine ?? safeModel).trim().isEmpty
          ? 'openai'
          : (engine ?? safeModel).trim();

      await SupabaseManager.instance.client
          .from(CostsRepository.tableName)
          .insert({
            'series': _normalizeSeries(project.folder),
            'episode': project.title.trim(),
            'engine': safeEngine,
            'input_tokens': usage.inputTokens,
            'output_tokens': usage.outputTokens,
            'total_tokens': usage.totalTokens,
            'cost_usd': _estimateUsd(model: safeModel, usage: usage),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
    } catch (e) {
      debugPrint('[costs] no se pudo registrar coste OpenAI: $e');
    }
  }

  double _estimateUsd({
    required String model,
    required OpenAiUsage usage,
  }) {
    final canonicalModel = _canonicalizeModel(model);

    final audioRate = _audioUsdPerMinute[canonicalModel];
    if (audioRate != null && usage.durationSeconds > 0) {
      return audioRate * (usage.durationSeconds / 60.0);
    }

    final tokenRate = _tokenRates[canonicalModel];
    if (tokenRate == null) return 0;

    var inputTokens = usage.inputTokens;
    var outputTokens = usage.outputTokens;
    final totalTokens = usage.totalTokens;

    if (inputTokens == 0 && outputTokens == 0 && totalTokens > 0) {
      inputTokens = totalTokens;
    } else if (totalTokens > 0 && inputTokens > 0 && outputTokens == 0) {
      outputTokens = (totalTokens - inputTokens).clamp(0, totalTokens).toInt();
    } else if (totalTokens > 0 && outputTokens > 0 && inputTokens == 0) {
      inputTokens = (totalTokens - outputTokens).clamp(0, totalTokens).toInt();
    }

    final inputCost =
        (inputTokens / 1000000.0) * tokenRate.inputUsdPer1M;
    final outputCost =
        (outputTokens / 1000000.0) * tokenRate.outputUsdPer1M;
    return inputCost + outputCost;
  }

  String _canonicalizeModel(String model) {
    final normalized = model.trim().toLowerCase();
    for (final key in {..._tokenRates.keys, ..._audioUsdPerMinute.keys}) {
      if (normalized == key || normalized.startsWith('$key-')) {
        return key;
      }
    }
    return normalized;
  }

  String _normalizeSeries(String folder) {
    final trimmed = folder.trim();
    return trimmed.isEmpty ? 'Sin carpeta' : trimmed;
  }
}

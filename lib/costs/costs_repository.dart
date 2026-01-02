import '../sync/supabase_manager.dart';

class CostRecord {
  final String series;
  final String episode;
  final String engine;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final double costUsd;
  final DateTime createdAt;

  CostRecord({
    required this.series,
    required this.episode,
    required this.engine,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.costUsd,
    required this.createdAt,
  });

  factory CostRecord.fromMap(Map<String, dynamic> m) {
    return CostRecord(
      series: (m['series'] ?? '') as String,
      episode: (m['episode'] ?? '') as String,
      engine: (m['engine'] ?? '') as String,
      inputTokens: (m['input_tokens'] ?? 0) as int,
      outputTokens: (m['output_tokens'] ?? 0) as int,
      totalTokens: (m['total_tokens'] ?? 0) as int,
      costUsd: (m['cost_usd'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse((m['created_at'] ?? '') as String) ??
          DateTime.now(),
    );
  }
}

class CostEngineBreakdown {
  final String engine;
  final double costUsd;
  final int tokens;

  CostEngineBreakdown({
    required this.engine,
    required this.costUsd,
    required this.tokens,
  });
}

class CostEpisodeSummary {
  final String series;
  final String episode;
  final double totalCostUsd;
  final int totalTokens;
  final DateTime lastAt;
  final List<CostEngineBreakdown> engines;

  CostEpisodeSummary({
    required this.series,
    required this.episode,
    required this.totalCostUsd,
    required this.totalTokens,
    required this.lastAt,
    required this.engines,
  });
}

class CostsRepository {
  static const _table = 'voicex_api_costs';

  Future<List<CostEpisodeSummary>> fetchSummaries({int limit = 400}) async {
    if (!SupabaseManager.instance.isReady) return [];
    final client = SupabaseManager.instance.client;

    final rows = await client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    final records = (rows as List<dynamic>)
        .map((e) => CostRecord.fromMap(e as Map<String, dynamic>))
        .toList();

    final Map<String, List<CostRecord>> grouped = {};
    for (final rec in records) {
      final key = '${rec.series}|||${rec.episode}';
      grouped.putIfAbsent(key, () => []).add(rec);
    }

    final summaries = <CostEpisodeSummary>[];
    grouped.forEach((key, recs) {
      double totalCost = 0;
      int totalTokens = 0;
      DateTime lastAt = recs.first.createdAt;
      final Map<String, CostEngineBreakdown> engines = {};

      for (final r in recs) {
        totalCost += r.costUsd;
        totalTokens += r.totalTokens;
        if (r.createdAt.isAfter(lastAt)) {
          lastAt = r.createdAt;
        }
        final ex = engines[r.engine];
        if (ex == null) {
          engines[r.engine] = CostEngineBreakdown(
            engine: r.engine,
            costUsd: r.costUsd,
            tokens: r.totalTokens,
          );
        } else {
          engines[r.engine] = CostEngineBreakdown(
            engine: r.engine,
            costUsd: ex.costUsd + r.costUsd,
            tokens: ex.tokens + r.totalTokens,
          );
        }
      }

      final parts = key.split('|||');
      summaries.add(
        CostEpisodeSummary(
          series: parts[0],
          episode: parts.length > 1 ? parts[1] : '',
          totalCostUsd: totalCost,
          totalTokens: totalTokens,
          lastAt: lastAt,
          engines: engines.values.toList()
            ..sort((a, b) => b.costUsd.compareTo(a.costUsd)),
        ),
      );
    });

    summaries.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return summaries;
  }
}

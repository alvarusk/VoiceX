import 'package:flutter/material.dart';

import '../costs/costs_repository.dart';
import '../db/app_db.dart';
import '../review/review_service.dart';

class MetricsPage extends StatefulWidget {
  const MetricsPage({
    super.key,
    required this.db,
    required this.projectId,
    required this.projectTitle,
    required this.projectFolder,
  });

  final AppDatabase db;
  final String projectId;
  final String projectTitle;
  final String projectFolder;

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  late final ReviewService _svc = ReviewService(widget.db);
  late final Future<CostEpisodeSummary?> _costFuture = _loadCostSummary();

  Future<CostEpisodeSummary?> _loadCostSummary() async {
    return CostsRepository().fetchEpisodeSummary(
      series: _normalizedSeries(widget.projectFolder),
      episode: widget.projectTitle.trim(),
    );
  }

  String _normalizedSeries(String folder) {
    final trimmed = folder.trim();
    return trimmed.isEmpty ? 'Sin carpeta' : trimmed;
  }

  String _fmtDuration(int ms) {
    if (ms <= 0) return '0s';
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  Widget _sourceRow(String label, int count, int total) {
    final pct = total == 0 ? 0 : (count * 100 ~/ total);
    return ListTile(
      title: Text(label),
      trailing: Text('$count  ($pct %)'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metricas')),
      body: StreamBuilder<MetricsSnapshot>(
        stream: _svc.watchMetrics(widget.projectId),
        builder: (context, snap) {
          final m = snap.data;
          if (m == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              ListTile(
                title: const Text('Revisadas'),
                subtitle: Text('${m.reviewed}/${m.total}'),
              ),
              FutureBuilder<CostEpisodeSummary?>(
                future: _costFuture,
                builder: (context, costSnap) {
                  if (costSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Coste IA'),
                      subtitle: Text('Cargando costes del episodio...'),
                    );
                  }

                  final summary = costSnap.data;
                  if (summary == null) {
                    return const ListTile(
                      title: Text('Coste IA'),
                      subtitle: Text('Sin costes registrados para este episodio.'),
                    );
                  }

                  final breakdown = summary.engines
                      .map((e) =>
                          '${e.engine}: \$${e.costUsd.toStringAsFixed(4)} (${e.tokens} tok)')
                      .join(' | ');

                  return ListTile(
                    title: const Text('Coste IA'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: \$${summary.totalCostUsd.toStringAsFixed(4)} | ${summary.totalTokens} tok',
                        ),
                        if (breakdown.isNotEmpty) Text(breakdown),
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder<SessionDurationSummary>(
                stream: _svc.watchSessionDurations(widget.projectId),
                builder: (context, sessionSnap) {
                  final s = sessionSnap.data;
                  int pcMs = 0;
                  int phoneMs = 0;
                  final extras = <String, int>{};
                  if (s != null) {
                    s.byPlatform.forEach((plat, ms) {
                      switch (plat) {
                        case 'windows':
                        case 'macos':
                        case 'linux':
                          pcMs += ms;
                          break;
                        case 'android':
                        case 'ios':
                          phoneMs += ms;
                          break;
                        default:
                          extras[plat] = (extras[plat] ?? 0) + ms;
                      }
                    });
                  }
                  final totalMs =
                      s?.totalMs ??
                      (pcMs + phoneMs + extras.values.fold(0, (a, b) => a + b));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      ListTile(
                        title: const Text('Tiempo en el episodio'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PC: ${_fmtDuration(pcMs)}'),
                            Text('Telefono: ${_fmtDuration(phoneMs)}'),
                            if (extras.isNotEmpty)
                              ...extras.entries.map(
                                (e) => Text('${e.key}: ${_fmtDuration(e.value)}'),
                              ),
                            Text('Total: ${_fmtDuration(totalMs)}'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Divider(),
              const ListTile(title: Text('Motores en este episodio')),
              _sourceRow('GPT', m.bySource['gpt'] ?? 0, m.reviewed),
              _sourceRow('Claude', m.bySource['claude'] ?? 0, m.reviewed),
              _sourceRow('Gemini', m.bySource['gemini'] ?? 0, m.reviewed),
              _sourceRow('DeepSeek', m.bySource['deepseek'] ?? 0, m.reviewed),
              _sourceRow('Mi voz', m.bySource['voice'] ?? 0, m.reviewed),
              _sourceRow('Otro', m.bySource['other'] ?? 0, m.reviewed),
              const Divider(),
              ListTile(
                title: const Text('Motores historicos'),
                subtitle: Text('${m.historicalReviewed} lineas revisadas en total'),
              ),
              _sourceRow(
                'GPT',
                m.historicalBySource['gpt'] ?? 0,
                m.historicalReviewed,
              ),
              _sourceRow(
                'Claude',
                m.historicalBySource['claude'] ?? 0,
                m.historicalReviewed,
              ),
              _sourceRow(
                'Gemini',
                m.historicalBySource['gemini'] ?? 0,
                m.historicalReviewed,
              ),
              _sourceRow(
                'DeepSeek',
                m.historicalBySource['deepseek'] ?? 0,
                m.historicalReviewed,
              ),
              _sourceRow(
                'Mi voz',
                m.historicalBySource['voice'] ?? 0,
                m.historicalReviewed,
              ),
              _sourceRow(
                'Otro',
                m.historicalBySource['other'] ?? 0,
                m.historicalReviewed,
              ),
              const Divider(),
              ListTile(
                title: const Text('Marcadas como duda'),
                trailing: Text('${m.doubtCount}'),
              ),
            ],
          );
        },
      ),
    );
  }
}

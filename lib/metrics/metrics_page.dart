import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../review/review_service.dart';

class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key, required this.db, required this.projectId});
  final AppDatabase db;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final svc = ReviewService(db);
    String fmt(int ms) {
      if (ms <= 0) return '0s';
      final d = Duration(milliseconds: ms);
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
      if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
      return '${s}s';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Métricas')),
      body: StreamBuilder<MetricsSnapshot>(
        stream: svc.watchMetrics(projectId),
        builder: (context, snap) {
          final m = snap.data;
          if (m == null) {
            return const Center(child: CircularProgressIndicator());
          }

          Widget row(String label, int count, int total) {
            final pct = total == 0 ? 0 : (count * 100 ~/ total);
            return ListTile(
              title: Text(label),
              trailing: Text('$count  ($pct %)'),
            );
          }

          return ListView(
            children: [
              ListTile(
                title: const Text('Revisadas'),
                subtitle: Text('${m.reviewed}/${m.total}'),
              ),
              StreamBuilder<SessionDurationSummary>(
                stream: svc.watchSessionDurations(projectId),
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
                  final totalMs = s?.totalMs ?? (pcMs + phoneMs + extras.values.fold(0, (a, b) => a + b));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      ListTile(
                        title: const Text('Tiempo en el episodio'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PC: ${fmt(pcMs)}'),
                            Text('Teléfono: ${fmt(phoneMs)}'),
                            if (extras.isNotEmpty)
                              ...extras.entries.map((e) => Text('${e.key}: ${fmt(e.value)}')),
                            Text('Total: ${fmt(totalMs)}'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Coste IA (estimación)'),
                subtitle: const Text(
                  'No disponible: necesitamos instrumentar llamadas STT/refine para calcular coste por episodio.',
                ),
              ),
              const Divider(),
              row('GPT', m.bySource['gpt'] ?? 0, m.reviewed),
              row('Claude', m.bySource['claude'] ?? 0, m.reviewed),
              row('Gemini', m.bySource['gemini'] ?? 0, m.reviewed),
              row('DeepSeek', m.bySource['deepseek'] ?? 0, m.reviewed),
              row('Mi voz', m.bySource['voice'] ?? 0, m.reviewed),
              row('Otro', m.bySource['other'] ?? 0, m.reviewed),
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

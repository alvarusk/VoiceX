import 'package:flutter/material.dart';

import 'costs_repository.dart' as cr;

class CostsSheet extends StatelessWidget {
  const CostsSheet({super.key, required this.repo});

  final cr.CostsRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<cr.CostEpisodeSummary>>(
      future: repo.fetchSummaries(),
      builder: (context, snapshot) {
        final state = snapshot.connectionState;
        final data = snapshot.data ?? <cr.CostEpisodeSummary>[];
        if (state == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error cargando costes: ${snapshot.error}'),
          );
        }
        if (data.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay costes disponibles.'),
          );
        }

        final totalCost =
            data.fold<double>(0, (sum, e) => sum + e.totalCostUsd);
        final totalTokens =
            data.fold<int>(0, (sum, e) => sum + e.totalTokens);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long),
                    const SizedBox(width: 8),
                    const Text(
                      'Costes API',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '\$${totalCost.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$totalTokens tok'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, idx) =>
                        const Divider(height: 12, thickness: 0.4),
                    itemBuilder: (_, i) {
                      final item = data[i];
                      final engines = item.engines
                          .map((e) =>
                              '${e.engine}: \$${e.costUsd.toStringAsFixed(4)} (${e.tokens} tok)')
                          .join(' | ');
                      return ListTile(
                        dense: true,
                        title: Text('${item.series} - ${item.episode}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Total: \$${item.totalCostUsd.toStringAsFixed(4)} | ${item.totalTokens} tok'),
                            Text(engines),
                            Text(
                              'Ultima: ${item.lastAt.toLocal()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

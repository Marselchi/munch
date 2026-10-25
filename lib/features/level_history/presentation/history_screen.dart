import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../sync/common/event_log.dart';
import 'widgets/history_row.dart';

class HistoryScreen extends StatelessWidget {
  final List<HistoryEntry> entries;
  final String Function(String playerId) getPlayerName;

  const HistoryScreen({
    super.key,
    required this.entries,
    required this.getPlayerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История изменений'),
      ),
      body: entries.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'История пуста',
              subtitle: 'За время текущей сессии изменений уровня еще не производилось.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final name = getPlayerName(entry.targetPlayerId);
                return HistoryRow(
                  entry: entry,
                  playerName: name,
                );
              },
            ),
    );
  }
}

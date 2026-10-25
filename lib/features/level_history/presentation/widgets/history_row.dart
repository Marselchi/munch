import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../sync/common/event_log.dart';
import '../../../../sync/protocol/models.dart';

class HistoryRow extends StatelessWidget {
  final HistoryEntry entry;
  final String playerName;

  const HistoryRow({
    super.key,
    required this.entry,
    required this.playerName,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final isUndone = entry.isUndone;
    final change = entry.appliedEvent;

    final deltaStr = change.delta != null
        ? (change.delta! > 0 ? '+${change.delta}' : '${change.delta}')
        : 'Ур. ${change.newLevel}';

    final textStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: isUndone ? AppColors.textUndone : AppColors.textPrimary,
      decoration: isUndone ? TextDecoration.lineThrough : null,
      decorationColor: AppColors.accentCrimson,
      decorationThickness: 2,
    );

    final initiatorText = switch (change.initiator) {
      HostInitiated() => 'Ведущий',
      PlayerRequested() => 'Запрос игрока',
    };

    return Card(
      color: isUndone
          ? AppColors.darkCard.withOpacity(0.4)
          : AppColors.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Icon / Undone Badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUndone
                    ? AppColors.textMuted.withOpacity(0.15)
                    : (change.delta != null && change.delta! > 0
                        ? AppColors.accentGreen.withOpacity(0.15)
                        : AppColors.accentCrimson.withOpacity(0.15)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUndone
                    ? Icons.undo
                    : (change.delta != null && change.delta! > 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                size: 20,
                color: isUndone
                    ? AppColors.textUndone
                    : (change.delta != null && change.delta! > 0
                        ? AppColors.accentGreen
                        : AppColors.accentCrimson),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        playerName,
                        style: textStyle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$deltaStr → Ур. ${change.newLevel}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isUndone
                              ? AppColors.textUndone
                              : AppColors.primaryGold,
                          decoration: isUndone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (isUndone) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentCrimson.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Отменено',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentCrimson,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${change.reason.localizedTitle} • $initiatorText',
                    style: TextStyle(
                      fontSize: 12,
                      color: isUndone ? AppColors.textUndone : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Timestamp
            Text(
              _formatTime(change.ts),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

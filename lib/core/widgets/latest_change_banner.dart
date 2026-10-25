import 'package:flutter/material.dart';
import '../../sync/protocol/models.dart';
import '../theme/app_colors.dart';

class LatestChangeBanner extends StatelessWidget {
  final LevelApplied? latestChange;
  final String? targetPlayerName;
  final VoidCallback? onTap;

  const LatestChangeBanner({
    super.key,
    required this.latestChange,
    this.targetPlayerName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (latestChange == null) {
      return const SizedBox.shrink();
    }

    final change = latestChange!;
    final name = targetPlayerName ?? 'Игрок';
    final deltaStr = change.delta != null
        ? (change.delta! > 0 ? '+${change.delta}' : '${change.delta}')
        : 'Ур. ${change.newLevel}';

    final initiatorText = switch (change.initiator) {
      HostInitiated() => 'Ведущий',
      PlayerRequested() => 'По запросу игрока',
    };

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGold.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up,
                  size: 20,
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: change.delta != null && change.delta! > 0
                                ? AppColors.accentGreen.withOpacity(0.2)
                                : AppColors.accentCrimson.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$deltaStr → Ур. ${change.newLevel}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: change.delta != null && change.delta! > 0
                                  ? AppColors.accentGreen
                                  : AppColors.accentCrimson,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${change.reason.localizedTitle} • $initiatorText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

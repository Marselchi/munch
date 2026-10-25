import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/rules_entities.dart';

class EntityResultCard extends StatelessWidget {
  final RuleEntity entity;
  final VoidCallback onTap;

  const EntityResultCard({
    super.key,
    required this.entity,
    required this.onTap,
  });

  String _formatKind(String kind) {
    return switch (kind.toLowerCase()) {
      'class' => 'Класс',
      'race' => 'Раса',
      _ => kind.toUpperCase(),
    };
  }

  Color _getKindColor(String kind) {
    return switch (kind.toLowerCase()) {
      'class' => AppColors.accentBlue,
      'race' => AppColors.accentGreen,
      _ => AppColors.primaryGold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final kindColor = _getKindColor(entity.kind);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kindColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kindColor.withOpacity(0.4)),
                ),
                child: Text(
                  _formatKind(entity.kind),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kindColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (entity.aliases.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entity.aliases.join(', '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (entity.epic != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.epicPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.epicPurple.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'ЭПИК',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.epicPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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

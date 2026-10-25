import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../sync/protocol/models.dart';
import 'gear_stepper.dart';

class PlayerPowerCard extends StatelessWidget {
  final Player player;
  final int maxLevel;
  final ValueChanged<int> onGearChanged;
  final VoidCallback onRequestLevel;
  final VoidCallback? onEditTraits;
  final bool isPendingRequest;

  const PlayerPowerCard({
    super.key,
    required this.player,
    required this.maxLevel,
    required this.onGearChanged,
    required this.onRequestLevel,
    this.onEditTraits,
    this.isPendingRequest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.primaryGold, width: 2),
      ),
      color: AppColors.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Header with Name & Total Power
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ВАШ ПЕРСОНАЖ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE65100), Color(0xFFFFB74D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'СИЛА',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${player.totalPower}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Level and Gear Row
            Row(
              children: [
                // Level Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.darkCardBorder),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'УРОВЕНЬ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${player.level}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Gear Stepper
            GearStepper(
              currentGear: player.gearPower,
              onGearChanged: onGearChanged,
            ),
            const SizedBox(height: 14),
            // Request Level Change Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPendingRequest
                      ? AppColors.darkSurface
                      : AppColors.primaryGold,
                  foregroundColor: isPendingRequest
                      ? AppColors.secondaryAmber
                      : Colors.black,
                  side: isPendingRequest
                      ? const BorderSide(color: AppColors.secondaryAmber)
                      : null,
                ),
                onPressed: isPendingRequest ? null : onRequestLevel,
                icon: isPendingRequest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.secondaryAmber,
                        ),
                      )
                    : const Icon(Icons.arrow_upward),
                label: Text(
                  isPendingRequest
                      ? 'Ожидание ответа ведущего…'
                      : 'Запросить изменение уровня',
                ),
              ),
            ),
            // Traits chips
            if (player.traitIds.isNotEmpty || onEditTraits != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...player.traitIds.map(
                    (trait) => Chip(
                      label: Text(trait, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.darkSurface,
                      side: const BorderSide(color: AppColors.darkCardBorder),
                    ),
                  ),
                  if (onEditTraits != null)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('Класс/Раса', style: TextStyle(fontSize: 12)),
                      onPressed: onEditTraits,
                      backgroundColor: AppColors.darkSurface,
                      side: const BorderSide(color: AppColors.primaryGold),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class GearStepper extends StatelessWidget {
  final int currentGear;
  final ValueChanged<int> onGearChanged;

  const GearStepper({
    super.key,
    required this.currentGear,
    required this.onGearChanged,
  });

  void _apply(int delta) {
    final next = (currentGear + delta).clamp(
      AppConstants.minGearPower,
      AppConstants.maxGearPower,
    );
    onGearChanged(next);
  }

  void _openDirectInputDialog(BuildContext context) {
    final controller = TextEditingController(text: '$currentGear');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Бонус шмоток (0–999)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Введите число'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? currentGear;
              onGearChanged(val.clamp(
                AppConstants.minGearPower,
                AppConstants.maxGearPower,
              ));
              Navigator.of(ctx).pop();
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkCardBorder),
      ),
      child: Column(
        children: [
          const Text(
            'БОНУС ШМОТОК',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepButton(
                label: '−5',
                onPressed: currentGear >= 5 ? () => _apply(-5) : null,
              ),
              const SizedBox(width: 4),
              _buildStepButton(
                label: '−1',
                onPressed: currentGear >= 1 ? () => _apply(-1) : null,
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openDirectInputDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '+$currentGear',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryAmber,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStepButton(
                label: '+1',
                onPressed: currentGear < AppConstants.maxGearPower ? () => _apply(1) : null,
              ),
              const SizedBox(width: 4),
              _buildStepButton(
                label: '+5',
                onPressed: currentGear <= AppConstants.maxGearPower - 5 ? () => _apply(5) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 42,
      height: 38,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          side: const BorderSide(color: AppColors.darkCardBorder),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: onPressed != null ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

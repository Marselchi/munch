import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/reason_chip.dart';
import '../../../../sync/protocol/models.dart';

class LevelRequestSheet extends StatefulWidget {
  final Player player;
  final int maxLevel;
  final void Function({
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) onConfirm;

  const LevelRequestSheet({
    super.key,
    required this.player,
    required this.maxLevel,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required Player player,
    required int maxLevel,
    required void Function({
      int? delta,
      int? setValue,
      required LevelReason reason,
    }) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: LevelRequestSheet(
          player: player,
          maxLevel: maxLevel,
          onConfirm: onConfirm,
        ),
      ),
    );
  }

  @override
  State<LevelRequestSheet> createState() => _LevelRequestSheetState();
}

class _LevelRequestSheetState extends State<LevelRequestSheet> {
  int _selectedDelta = 1;
  int? _customValue;
  bool _isSetMode = false;
  LevelReason _reason = const LevelReason.monsterKill();

  @override
  Widget build(BuildContext context) {
    final currentLevel = widget.player.level;
    final targetLevel = _isSetMode
        ? (_customValue ?? currentLevel)
        : (currentLevel + _selectedDelta);

    final isValidBounds =
        targetLevel >= AppConstants.minLevel && targetLevel <= widget.maxLevel;
    final isLevelChanged = targetLevel != currentLevel;
    final isReasonValid = _reason.kind != ReasonKind.other ||
        (_reason.customText != null && _reason.customText!.trim().isNotEmpty);

    final canConfirm = isValidBounds && isLevelChanged && isReasonValid;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Запрос изменения уровня',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Target level preview
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryGold, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$currentLevel',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.arrow_forward,
                      color: AppColors.primaryGold,
                      size: 28,
                    ),
                  ),
                  Text(
                    '$targetLevel',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: targetLevel > currentLevel
                          ? AppColors.accentGreen
                          : (targetLevel < currentLevel
                              ? AppColors.accentCrimson
                              : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_isSetMode && _selectedDelta == -1
                        ? AppColors.accentCrimson.withOpacity(0.2)
                        : null,
                    side: BorderSide(
                      color: !_isSetMode && _selectedDelta == -1
                          ? AppColors.accentCrimson
                          : AppColors.darkCardBorder,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSetMode = false;
                      _selectedDelta = -1;
                    });
                  },
                  child: const Text('−1 Уровень'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_isSetMode && _selectedDelta == 1
                        ? AppColors.accentGreen.withOpacity(0.2)
                        : null,
                    side: BorderSide(
                      color: !_isSetMode && _selectedDelta == 1
                          ? AppColors.accentGreen
                          : AppColors.darkCardBorder,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSetMode = false;
                      _selectedDelta = 1;
                    });
                  },
                  child: const Text('+1 Уровень'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isSetMode
                        ? AppColors.primaryGold.withOpacity(0.2)
                        : null,
                    side: BorderSide(
                      color: _isSetMode
                          ? AppColors.primaryGold
                          : AppColors.darkCardBorder,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSetMode = true;
                      _customValue ??= currentLevel;
                    });
                  },
                  child: const Text('Задать'),
                ),
              ),
            ],
          ),
          if (_isSetMode) ...[
            const SizedBox(height: 12),
            Slider(
              value: (_customValue ?? currentLevel).toDouble(),
              min: AppConstants.minLevel.toDouble(),
              max: widget.maxLevel.toDouble(),
              divisions: widget.maxLevel - AppConstants.minLevel,
              label: '${_customValue ?? currentLevel}',
              activeColor: AppColors.primaryGold,
              onChanged: (val) {
                setState(() {
                  _customValue = val.round();
                });
              },
            ),
          ],
          const SizedBox(height: 16),
          ReasonSelector(
            initialReason: _reason,
            onChanged: (reason) {
              setState(() {
                _reason = reason;
              });
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: canConfirm
                ? () {
                    if (_isSetMode) {
                      widget.onConfirm(
                        setValue: _customValue,
                        reason: _reason,
                      );
                    } else {
                      widget.onConfirm(
                        delta: _selectedDelta,
                        reason: _reason,
                      );
                    }
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Text('Отправить запрос ведущему'),
          ),
        ],
      ),
    );
  }
}

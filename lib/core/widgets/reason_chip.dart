import 'package:flutter/material.dart';
import '../../sync/protocol/models.dart';
import '../theme/app_colors.dart';

class ReasonSelector extends StatefulWidget {
  final LevelReason initialReason;
  final ValueChanged<LevelReason> onChanged;

  const ReasonSelector({
    super.key,
    required this.initialReason,
    required this.onChanged,
  });

  @override
  State<ReasonSelector> createState() => _ReasonSelectorState();
}

class _ReasonSelectorState extends State<ReasonSelector> {
  late ReasonKind _selectedKind;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialReason.kind;
    _customController =
        TextEditingController(text: widget.initialReason.customText ?? '');
    _customController.addListener(_notifyChange);
  }

  void _notifyChange() {
    if (_selectedKind == ReasonKind.sell) {
      widget.onChanged(const LevelReason.sell());
    } else if (_selectedKind == ReasonKind.monsterKill) {
      widget.onChanged(const LevelReason.monsterKill());
    } else {
      widget.onChanged(LevelReason.other(_customController.text.trim()));
    }
  }

  @override
  void dispose() {
    _customController.removeListener(_notifyChange);
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Причина изменения:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(
              kind: ReasonKind.monsterKill,
              label: 'Монстр',
              icon: Icons.shield,
            ),
            _buildChip(
              kind: ReasonKind.sell,
              label: 'Продажа (1000G)',
              icon: Icons.monetization_on,
            ),
            _buildChip(
              kind: ReasonKind.other,
              label: 'Другое',
              icon: Icons.edit_note,
            ),
          ],
        ),
        if (_selectedKind == ReasonKind.other) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customController,
            autofocus: true,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: 'Укажите причину (обязательно)',
              hintText: 'Проклятие, смывка, помощь и т.д.',
              counterText: '',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChip({
    required ReasonKind kind,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedKind == kind;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedKind = kind;
          });
          _notifyChange();
        }
      },
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.black : AppColors.primaryGold,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.darkCard,
      side: BorderSide(
        color: isSelected ? AppColors.primaryGold : AppColors.darkCardBorder,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RulesNavActions extends StatelessWidget {
  final bool showBackButton;
  final bool showTableButton;

  const RulesNavActions({
    super.key,
    this.showBackButton = true,
    this.showTableButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBackButton)
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Назад на 1 шаг',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),
        if (showTableButton)
          IconButton(
            icon: const Icon(Icons.table_restaurant, size: 20, color: AppColors.secondaryAmber),
            tooltip: 'Вернуться к столу',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
      ],
    );
  }
}

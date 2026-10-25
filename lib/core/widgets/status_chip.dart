import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ConnectionStateStatus {
  connected,
  reconnecting,
  disconnected,
}

class StatusChip extends StatelessWidget {
  final ConnectionStateStatus status;
  final String? customLabel;
  final VoidCallback? onTap;

  const StatusChip({
    super.key,
    required this.status,
    this.customLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, defaultText) = switch (status) {
      ConnectionStateStatus.connected => (AppColors.statusConnected, 'В сети'),
      ConnectionStateStatus.reconnecting => (
          AppColors.statusReconnecting,
          'Подключение…'
        ),
      ConnectionStateStatus.disconnected => (
          AppColors.statusDisconnected,
          'Офлайн'
        ),
    };

    final text = customLabel ?? defaultText;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: chip,
      );
    }
    return chip;
  }
}

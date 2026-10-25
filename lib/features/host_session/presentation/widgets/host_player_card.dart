import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../sync/protocol/models.dart';
import 'level_change_sheet.dart';

class HostPlayerCard extends StatelessWidget {
  final Player player;
  final bool isHostPlayer;
  final bool isDisconnected;
  final int maxLevel;
  final void Function({
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) onApplyLevelChange;
  final void Function(int newGear) onUpdateGear;
  final VoidCallback? onEditTraits;
  final VoidCallback? onKickPlayer;

  const HostPlayerCard({
    super.key,
    required this.player,
    required this.isHostPlayer,
    this.isDisconnected = false,
    required this.maxLevel,
    required this.onApplyLevelChange,
    required this.onUpdateGear,
    this.onEditTraits,
    this.onKickPlayer,
  });

  Color _getAvatarColor(String id) {
    final hash = id.hashCode.abs();
    final colors = [
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.blueGrey,
      Colors.brown,
      Colors.pink,
      Colors.amber.shade900,
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(player.id);
    final cardColor = isDisconnected
        ? AppColors.darkCard.withOpacity(0.5)
        : AppColors.darkCard;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Host badge, Kick
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor,
                  radius: 18,
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isHostPlayer) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Ведущий',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isDisconnected) ...[
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.statusReconnecting,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Переподключение…',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.statusReconnecting,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Power Badge: Level + Gear
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryGold.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'СИЛА',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                      Text(
                        '${player.totalPower}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isHostPlayer && onKickPlayer != null) ...[
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                    onPressed: () {
                      _showPlayerOptions(context);
                    },
                  ),
                ],
              ],
            ),
            const Divider(color: AppColors.darkCardBorder, height: 20),
            // Middle Row: Level Controls & Gear Info
            Row(
              children: [
                // Level Control with -/+ buttons
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () {
                      LevelChangeSheet.show(
                        context: context,
                        player: player,
                        maxLevel: maxLevel,
                        onConfirm: onApplyLevelChange,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.darkCardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            color: player.level > 1
                                ? AppColors.accentCrimson
                                : AppColors.textMuted,
                            onPressed: player.level > 1
                                ? () => onApplyLevelChange(
                                      delta: -1,
                                      reason: const LevelReason.other('Понижение уровня'),
                                    )
                                : null,
                          ),
                          Column(
                            children: [
                              const Text(
                                'УРОВЕНЬ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${player.level}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<LevelReason>(
                            tooltip: 'Повысить уровень (выберите причину)',
                            enabled: player.level < maxLevel,
                            offset: const Offset(-100, -240),
                            color: const Color(0xFF22252C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.darkCardBorder),
                            ),
                            icon: Icon(
                              Icons.add,
                              size: 20,
                              color: player.level < maxLevel
                                  ? AppColors.accentGreen
                                  : AppColors.textMuted,
                            ),
                            onSelected: (reason) {
                              if (reason.customText == '__CUSTOM__') {
                                _showCustomReasonDialog(context, isIncrease: true);
                              } else {
                                onApplyLevelChange(delta: 1, reason: reason);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: LevelReason.monsterKill(),
                                child: Row(
                                  children: [
                                    Icon(Icons.sports_martial_arts, size: 18, color: AppColors.accentGreen),
                                    SizedBox(width: 10),
                                    Text('Убийство монстра', style: TextStyle(color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: LevelReason.sell(),
                                child: Row(
                                  children: [
                                    Icon(Icons.monetization_on, size: 18, color: AppColors.primaryGold),
                                    SizedBox(width: 10),
                                    Text('Продажа шмоток (1000 GP)', style: TextStyle(color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: LevelReason.other('Карта «Получи Уровень»'),
                                child: Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 18, color: AppColors.accentBlue),
                                    SizedBox(width: 10),
                                    Text('Карта «Получи Уровень»', style: TextStyle(color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: LevelReason.other('Помощь эльфа'),
                                child: Row(
                                  children: [
                                    Icon(Icons.handshake, size: 18, color: AppColors.secondaryAmber),
                                    SizedBox(width: 10),
                                    Text('Помощь эльфа', style: TextStyle(color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: LevelReason.other('__CUSTOM__'),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                                    SizedBox(width: 10),
                                    Text('Другая причина…', style: TextStyle(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Gear Display
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: isHostPlayer
                        ? () => _showGearDialog(context)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.darkCardBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'ШМОТКИ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (isHostPlayer) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: AppColors.primaryGold,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${player.gearPower}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Traits chips (Classes/Races)
            if (player.traitIds.isNotEmpty || onEditTraits != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...player.traitIds.map(
                    (trait) => Chip(
                      label: Text(
                        trait,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: AppColors.darkSurface,
                      side: const BorderSide(color: AppColors.darkCardBorder),
                    ),
                  ),
                  if (onEditTraits != null)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('Класс/Раса', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
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

  void _showPlayerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.accentCrimson),
              title: Text('Исключить игрока "${player.name}"'),
              onTap: () {
                Navigator.of(ctx).pop();
                onKickPlayer?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGearDialog(BuildContext context) {
    int currentGear = player.gearPower;
    final controller = TextEditingController(text: '$currentGear');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Бонус шмоток (0-999)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Суммарный бонус шмота'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim()) ?? currentGear;
              onUpdateGear(parsed);
              Navigator.of(ctx).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showCustomReasonDialog(BuildContext context, {required bool isIncrease}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIncrease ? 'Причина повышения уровня' : 'Причина понижения уровня'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Причина',
            hintText: 'Например: Способность класса, ловушка',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.of(ctx).pop();
              onApplyLevelChange(
                delta: isIncrease ? 1 : -1,
                reason: LevelReason.other(
                  text.isEmpty ? (isIncrease ? 'Повышение уровня' : 'Понижение уровня') : text,
                ),
              );
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../rules/application/rules_controller.dart';
import '../../../rules/domain/rules_category.dart';
import '../../../rules/domain/rules_entities.dart';
import '../../../rules/presentation/entity_detail_screen.dart';

class TraitTooltipChip extends ConsumerWidget {
  final String traitName;
  final VoidCallback? onDeleted;
  final bool isEditable;

  const TraitTooltipChip({
    super.key,
    required this.traitName,
    this.onDeleted,
    this.isEditable = false,
  });

  void _showTraitModal(BuildContext context, WidgetRef ref) {
    final allEntities = ref.read(allRuleEntitiesProvider);
    final norm = traitName.trim().toLowerCase();

    RuleEntity? foundEntity;
    for (final e in allEntities) {
      if (e.title.toLowerCase() == norm ||
          e.title.toLowerCase().startsWith(norm) ||
          e.aliases.any((a) => a.toLowerCase() == norm)) {
        foundEntity = e;
        break;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final categoryTitle = foundEntity != null
            ? RuleCategoryType.fromKind(foundEntity.kind).title
            : 'Характеристика';

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).padding.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.darkCardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primaryGold.withOpacity(0.4)),
                                ),
                                child: Text(
                                  categoryTitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGold,
                                  ),
                                ),
                              ),
                              if (foundEntity?.epic != null && foundEntity!.epic!.ruleSections.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.epicPurple.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.epicPurple.withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 11, color: AppColors.epicPurple),
                                      SizedBox(width: 4),
                                      Text(
                                        'ЭПИК',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.epicPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            foundEntity?.title ?? traitName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (foundEntity != null && foundEntity.ruleSections.isNotEmpty) ...[
                          ...foundEntity.ruleSections.map((sec) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (sec.heading != null && sec.heading!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        sec.heading!,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondaryAmber,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    sec.text,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.darkCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.darkCardBorder),
                            ),
                            child: Text(
                              '«$traitName» — свойство персонажа. Подробное описание доступно в справочнике правил.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                        if (foundEntity != null &&
                            foundEntity.epic != null &&
                            foundEntity.epic!.ruleSections.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.epicCardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.epicPurple.withOpacity(0.55), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 15, color: AppColors.epicPurple),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Эпические правила (Ур. 10–22)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.epicPurple,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...foundEntity.epic!.ruleSections.map((sec) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (sec.heading != null && sec.heading!.isNotEmpty)
                                          Text(
                                            sec.heading!,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        Text(
                                          sec.text,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Закрыть'),
                      ),
                    ),
                    if (foundEntity != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.menu_book, size: 16),
                          label: const Text(
                            'К описанию',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EntityDetailScreen(entity: foundEntity!),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEntities = ref.watch(allRuleEntitiesProvider);
    final norm = traitName.trim().toLowerCase();
    final hasEpic = allEntities.any((e) =>
        (e.title.toLowerCase() == norm ||
            e.title.toLowerCase().startsWith(norm) ||
            e.aliases.any((a) => a.toLowerCase() == norm)) &&
        e.epic != null &&
        e.epic!.ruleSections.isNotEmpty);

    return ActionChip(
      avatar: const Icon(
        Icons.info_outline,
        size: 14,
        color: AppColors.primaryGold,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            traitName,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          if (hasEpic) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.auto_awesome,
              size: 11,
              color: AppColors.epicPurple,
            ),
          ],
        ],
      ),
      backgroundColor: hasEpic ? AppColors.epicCardBg : AppColors.darkSurface,
      side: BorderSide(
        color: hasEpic ? AppColors.epicPurple.withOpacity(0.5) : AppColors.darkCardBorder,
      ),
      onPressed: () => _showTraitModal(context, ref),
    );
  }
}

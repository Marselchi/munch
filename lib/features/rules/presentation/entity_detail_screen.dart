import 'package:flutter/material.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import '../domain/rules_category.dart';
import '../domain/rules_entities.dart';
import 'widgets/interactive_rule_text.dart';

class EntityDetailScreen extends StatelessWidget {
  final RuleEntity entity;

  const EntityDetailScreen({
    super.key,
    required this.entity,
  });

  String _formatKind(String kind) {
    return RuleCategoryType.fromKind(kind).title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entity.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant, color: AppColors.secondaryAmber),
            tooltip: 'Вернуться к столу',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.settings.name == '/table' || route.isFirst);
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            border: Border(top: BorderSide(color: AppColors.darkCardBorder)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Назад'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryAmber,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.table_restaurant, size: 16),
                label: const Text('К столу', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(context).popUntil((r) => r.settings.name == '/table' || r.isFirst),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primaryGold.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            _formatKind(entity.kind),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Набор: ${entity.setId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entity.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (entity.aliases.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Также известен как: ${entity.aliases.join(", ")}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rule sections
            const Text(
              'Способности и правила',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...entity.ruleSections.map((section) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (section.heading != null &&
                          section.heading!.trim().isNotEmpty) ...[
                        Text(
                          section.heading!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryAmber,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      InteractiveRuleText(
                        text: section.text,
                        fillWidth: true,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Epic section (Accent Card)
            if (entity.epic != null && entity.epic!.ruleSections.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AppColors.epicPurple,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Эпические правила (Ур. 10–20)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.epicPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                color: AppColors.epicCardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: AppColors.epicPurple,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...entity.epic!.ruleSections.map((epicSec) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (epicSec.heading != null) ...[
                                Text(
                                  epicSec.heading!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.epicPurple,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              InteractiveRuleText(
                                text: epicSec.text,
                                fillWidth: true,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

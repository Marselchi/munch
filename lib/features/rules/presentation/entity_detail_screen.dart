import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../domain/rules_entities.dart';

class EntityDetailScreen extends StatelessWidget {
  final RuleEntity entity;

  const EntityDetailScreen({
    super.key,
    required this.entity,
  });

  String _formatKind(String kind) {
    return switch (kind.toLowerCase()) {
      'class' => 'Класс',
      'race' => 'Раса',
      _ => kind.toUpperCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entity.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 24,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 4),
                      ],
                      Text(
                        section.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...entity.epic!.ruleSections.map((epicSec) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(height: 4),
                            ],
                            Text(
                              epicSec.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
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

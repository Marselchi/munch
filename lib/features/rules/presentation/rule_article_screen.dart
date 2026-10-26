import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import '../domain/rules_entities.dart';
import 'entity_detail_screen.dart';
import 'widgets/interactive_rule_text.dart';

class RuleArticleScreen extends StatelessWidget {
  final String title;
  final String content;
  final String badge;
  final RuleEntity? linkedEntity;

  const RuleArticleScreen({
    super.key,
    required this.title,
    required this.content,
    required this.badge,
    this.linkedEntity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant, color: AppColors.secondaryAmber),
            tooltip: 'Вернуться к столу',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Скопировать текст правила',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$title\n\n$content'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Текст правила скопирован в буфер обмена'),
                  duration: Duration(seconds: 2),
                ),
              );
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
                icon: const Icon(Icons.table_restaurant, size: 16),
                label: const Text('К столу'),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
            // Badge & Title card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262932),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF434856)),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Linked entity button if rule is part of a card
            if (linkedEntity != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.style, color: AppColors.textPrimary),
                  title: Text(
                    linkedEntity!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Перейти к полной карте (${linkedEntity!.kind})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EntityDetailScreen(entity: linkedEntity!),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Content card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InteractiveRuleText(
                  text: content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                  fillWidth: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

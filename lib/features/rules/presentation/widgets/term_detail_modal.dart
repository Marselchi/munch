import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/rules_entities.dart';
import '../../domain/rules_glossary.dart';
import '../entity_detail_screen.dart';
import '../rule_article_screen.dart';

class TermDetailModal extends StatelessWidget {
  final RuleTerm term;
  final List<RulesBundle> bundles;

  const TermDetailModal({
    super.key,
    required this.term,
    this.bundles = const [],
  });

  static Future<void> show({
    required BuildContext context,
    required RuleTerm term,
    List<RulesBundle> bundles = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: TermDetailModal(term: term, bundles: bundles),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Try to find linked entity
    RuleEntity? matchedEntity;
    if (term.entityId != null) {
      matchedEntity = bundles
          .expand((b) => b.entities)
          .where((e) => e.id == term.entityId)
          .firstOrNull;
    }

    // 2. Try to find linked rule block
    RuleBlock? matchedBlock;
    if (term.ruleBlockId != null) {
      matchedBlock = bundles
          .expand((b) => b.ruleBlocks)
          .where((b) => b.id == term.ruleBlockId)
          .firstOrNull;
    }

    final hasValidLink = matchedEntity != null || matchedBlock != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header drag handle
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

          // Origin pack and term title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryGold.withOpacity(0.4)),
                      ),
                      child: Text(
                        term.originPack,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      term.term,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (term.englishTerm != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        term.englishTerm!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Definition card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkCardBorder),
            ),
            child: Text(
              term.definition,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Only display the navigation button if an actual valid link exists
          if (hasValidLink) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  matchedEntity != null ? Icons.style : Icons.menu_book,
                  size: 18,
                ),
                label: Text(
                  matchedEntity != null
                      ? 'Перейти к карте: ${matchedEntity.title}'
                      : 'Перейти к правилу: ${matchedBlock!.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close sheet first
                  if (matchedEntity != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EntityDetailScreen(entity: matchedEntity!),
                      ),
                    );
                  } else if (matchedBlock != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RuleArticleScreen(
                          title: matchedBlock!.title,
                          content: matchedBlock!.text,
                          badge: term.originPack,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

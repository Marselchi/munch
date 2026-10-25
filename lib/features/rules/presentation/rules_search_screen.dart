import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/empty_state.dart';
import '../application/rules_controller.dart';
import '../application/search_index.dart';
import '../application/search_service.dart';
import '../domain/rules_entities.dart';
import 'entity_detail_screen.dart';
import 'rule_article_screen.dart';
import 'rules_settings_screen.dart';
import 'widgets/entity_result_card.dart';
import 'widgets/text_snippet_row.dart';

class RulesSearchScreen extends ConsumerStatefulWidget {
  const RulesSearchScreen({super.key});

  @override
  ConsumerState<RulesSearchScreen> createState() => _RulesSearchScreenState();
}

class _RulesSearchScreenState extends ConsumerState<RulesSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(duration: AppConstants.searchDebounce);

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debouncer.run(() {
      ref.read(rulesProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rulesState = ref.watch(rulesProvider);
    final results = rulesState.searchResults;
    final isQueryEmpty = rulesState.activeQuery.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник правил'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Пакеты правил',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RulesSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по классам, расам, терминам…',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(rulesProvider.notifier).search('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          // "Did you mean" chip
          if (results.didYouMeanSuggestion != null && !isQueryEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'Возможно, вы искали: ',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  ActionChip(
                    label: Text(
                      results.didYouMeanSuggestion!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                      ),
                    ),
                    backgroundColor: AppColors.darkCard,
                    side: const BorderSide(color: AppColors.primaryGold),
                    onPressed: () {
                      _searchController.text = results.didYouMeanSuggestion!;
                      ref
                          .read(rulesProvider.notifier)
                          .search(results.didYouMeanSuggestion!);
                    },
                  ),
                ],
              ),
            ),
          ],
          // Content
          Expanded(
            child: rulesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : isQueryEmpty
                    ? _buildBrowseView(rulesState)
                    : _buildSearchResults(results, rulesState),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseView(RulesState state) {
    final allRuleBlocks = state.bundles.expand((b) => b.ruleBlocks).toList();
    final allEntities = state.bundles.expand((b) => b.entities).toList();
    final classes = allEntities.where((e) => e.kind.toLowerCase() == 'class').toList();
    final races = allEntities.where((e) => e.kind.toLowerCase() == 'race').toList();
    final others = allEntities
        .where((e) => e.kind.toLowerCase() != 'class' && e.kind.toLowerCase() != 'race')
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (allRuleBlocks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 8),
                Text(
                  'Основные правила игры',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allRuleBlocks.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(color: AppColors.darkCardBorder, height: 1),
              itemBuilder: (context, idx) {
                final block = allRuleBlocks[idx];
                return ListTile(
                  title: Text(
                    block.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    block.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    _openRuleArticle(
                      title: block.title,
                      content: block.text,
                      badge: block.setId.contains('2_0') ? 'Манчкин 2.0' : 'Общие правила',
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (classes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Классы',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.accentBlue,
              ),
            ),
          ),
          ...classes.map(
            (entity) => EntityResultCard(
              entity: entity,
              onTap: () => _openDetail(entity),
            ),
          ),
        ],
        if (races.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Расы',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
          ),
          ...races.map(
            (entity) => EntityResultCard(
              entity: entity,
              onTap: () => _openDetail(entity),
            ),
          ),
        ],
        if (others.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Особые способности и карты',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...others.map(
            (entity) => EntityResultCard(
              entity: entity,
              onTap: () => _openDetail(entity),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResults(SearchResultGroup results, RulesState state) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте изменить поисковый запрос или проверить опечатки.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (results.entityResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'Классы и Расы',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGold,
              ),
            ),
          ),
          ...results.entityResults.map((r) => EntityResultCard(
                entity: r.entity,
                onTap: () => _openDetail(r.entity),
              )),
          const SizedBox(height: 12),
        ],
        if (results.textResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'В тексте правил',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryAmber,
              ),
            ),
          ),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.textResults.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(color: AppColors.darkCardBorder, height: 1),
              itemBuilder: (context, idx) {
                final textResult = results.textResults[idx];
                return TextSnippetRow(
                  result: textResult,
                  onTap: () {
                    RuleEntity? linkedEntity;
                    if (textResult.record.ownerEntityId != null) {
                      final matched = state.bundles
                          .expand((b) => b.entities)
                          .where((e) => e.id == textResult.record.ownerEntityId)
                          .toList();
                      if (matched.isNotEmpty) {
                        linkedEntity = matched.first;
                      }
                    }
                    _openRuleArticle(
                      title: textResult.record.title,
                      content: textResult.record.rawText,
                      badge: switch (textResult.record.source) {
                        TextSourceKind.generalBlock => 'Общие правила',
                        TextSourceKind.epicRule => 'Эпические правила',
                        TextSourceKind.entityRule => 'Способность карты',
                        _ => 'Правила',
                      },
                      linkedEntity: linkedEntity,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _openRuleArticle({
    required String title,
    required String content,
    required String badge,
    RuleEntity? linkedEntity,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RuleArticleScreen(
          title: title,
          content: content,
          badge: badge,
          linkedEntity: linkedEntity,
        ),
      ),
    );
  }

  void _openDetail(RuleEntity entity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityDetailScreen(entity: entity),
      ),
    );
  }
}

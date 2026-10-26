import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:munchkin_companion/core/constants/app_constants.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import 'package:munchkin_companion/core/utils/debouncer.dart';
import 'package:munchkin_companion/core/widgets/empty_state.dart';
import '../application/rules_controller.dart';
import '../application/search_index.dart';
import '../application/search_service.dart';
import '../domain/rules_category.dart';
import '../domain/rules_entities.dart';
import 'entity_detail_screen.dart';
import 'rule_article_screen.dart';
import 'rules_settings_screen.dart';
import 'widgets/entity_result_card.dart';
import 'widgets/text_snippet_row.dart';

sealed class _BrowseItem {}

class _RuleBlockHeaderItem extends _BrowseItem {}

class _RuleBlockItem extends _BrowseItem {
  final RuleBlock block;
  _RuleBlockItem(this.block);
}

class _CategoryHeaderItem extends _BrowseItem {
  final RuleCategoryType category;
  final Color color;
  _CategoryHeaderItem(this.category, this.color);
}

class _EntityItem extends _BrowseItem {
  final RuleEntity entity;
  _EntityItem(this.entity);
}

class RulesSearchScreen extends ConsumerStatefulWidget {
  const RulesSearchScreen({super.key});

  @override
  ConsumerState<RulesSearchScreen> createState() => _RulesSearchScreenState();
}

class _RulesSearchScreenState extends ConsumerState<RulesSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(duration: AppConstants.searchDebounce);
  final ScrollController _scrollController = ScrollController();

  static const int _initialBrowsePageSize = 15;
  static const int _browsePageIncrement = 15;
  static const int _initialSearchEntities = 4;
  static const int _initialSearchTexts = 6;
  static const int _searchPageIncrement = 6;

  int _browseLimit = _initialBrowsePageSize;
  int _searchEntityLimit = _initialSearchEntities;
  int _searchTextLimit = _initialSearchTexts;

  @override
  void initState() {
    super.initState();
    _searchController.text = '';
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(rulesProvider.notifier).search('');
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Load next batch when within 300px of the bottom
    if (maxScroll - currentScroll <= 300) {
      final isQueryEmpty = _searchController.text.trim().isEmpty ||
          ref.read(rulesProvider).activeQuery.trim().isEmpty;

      if (isQueryEmpty) {
        setState(() {
          _browseLimit += _browsePageIncrement;
        });
      } else {
        setState(() {
          _searchEntityLimit += _searchPageIncrement;
          _searchTextLimit += _searchPageIncrement;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debouncer.run(() {
      // Reset search page limits on new query so only what fits on screen renders initially
      setState(() {
        _searchEntityLimit = _initialSearchEntities;
        _searchTextLimit = _initialSearchTexts;
      });
      ref.read(rulesProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rulesState = ref.watch(rulesProvider);
    final results = rulesState.searchResults;
    final isQueryEmpty =
        _searchController.text.trim().isEmpty || rulesState.activeQuery.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник правил'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant, color: AppColors.secondaryAmber),
            tooltip: 'Вернуться к столу',
            onPressed: () {
              ref.read(rulesProvider.notifier).search('');
              Navigator.of(context).popUntil((route) => route.settings.name == '/table' || route.isFirst);
            },
          ),
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
                          setState(() {
                            _browseLimit = _initialBrowsePageSize;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          // "Did you mean" suggestion chip
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
                      _onSearchChanged(results.didYouMeanSuggestion!);
                    },
                  ),
                ],
              ),
            ),
          ],
          // Content with virtualized scroll pagination
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

  /// Builds gradual browse view with on-scroll pagination
  Widget _buildBrowseView(RulesState state) {
    final allRuleBlocks = state.bundles.expand((b) => b.ruleBlocks).toList();
    final allEntities = state.bundles.expand((b) => b.entities).toList();
    final categorized = CategorizedEntities.fromEntities(allEntities);

    Color getCategoryColor(RuleCategoryType cat) {
      return switch (cat) {
        RuleCategoryType.classes => AppColors.accentBlue,
        RuleCategoryType.races => AppColors.accentGreen,
        RuleCategoryType.mojos => const Color(0xFF66BB6A),
        RuleCategoryType.powers => const Color(0xFFAB47BC),
        RuleCategoryType.styles => const Color(0xFFFF7043),
        RuleCategoryType.training => const Color(0xFF26A69A),
        RuleCategoryType.accents => const Color(0xFF42A5F5),
        RuleCategoryType.steeds => const Color(0xFFFFA726),
        RuleCategoryType.hirelings => const Color(0xFF8D6E63),
        RuleCategoryType.dungeons => const Color(0xFFEC407A),
        RuleCategoryType.enhancers => const Color(0xFFFFD54F),
        RuleCategoryType.seals => const Color(0xFFEF5350),
        RuleCategoryType.madness => const Color(0xFF9C27B0),
        _ => AppColors.primaryGold,
      };
    }

    // Build flat list of all browse elements
    final allItems = <_BrowseItem>[];

    if (allRuleBlocks.isNotEmpty) {
      allItems.add(_RuleBlockHeaderItem());
      for (final b in allRuleBlocks) {
        allItems.add(_RuleBlockItem(b));
      }
    }

    for (final cat in categorized.activeCategories) {
      allItems.add(_CategoryHeaderItem(cat, getCategoryColor(cat)));
      for (final e in categorized.get(cat)) {
        allItems.add(_EntityItem(e));
      }
    }

    final totalCount = allItems.length;
    final visibleCount = math.min(_browseLimit, totalCount);
    final hasMore = visibleCount < totalCount;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: visibleCount + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleCount) {
          // Bottom loading indicator when scrolling
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final item = allItems[index];
        return switch (item) {
          _RuleBlockHeaderItem() => const Padding(
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
          _RuleBlockItem(:final block) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
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
              ),
            ),
          _CategoryHeaderItem(:final category, :final color) => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(
                category.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          _EntityItem(:final entity) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: EntityResultCard(
                entity: entity,
                onTap: () => _openDetail(entity),
              ),
            ),
        };
      },
    );
  }

  /// Builds search results limited to viewport size to prevent keystroke lag
  Widget _buildSearchResults(SearchResultGroup results, RulesState state) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте изменить поисковый запрос или проверить опечатки.',
      );
    }

    final visibleEntities = results.entityResults.take(_searchEntityLimit).toList();
    final visibleTexts = results.textResults.take(_searchTextLimit).toList();
    final hasMore = (visibleEntities.length < results.entityResults.length) ||
        (visibleTexts.length < results.textResults.length);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (visibleEntities.isNotEmpty) ...[
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
          for (final r in visibleEntities)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: EntityResultCard(
                entity: r.entity,
                onTap: () => _openDetail(r.entity),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (visibleTexts.isNotEmpty) ...[
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
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                for (var i = 0; i < visibleTexts.length; i++) ...[
                  if (i > 0) const Divider(color: AppColors.darkCardBorder, height: 1),
                  TextSnippetRow(
                    result: visibleTexts[i],
                    onTap: () {
                      RuleEntity? linkedEntity;
                      if (visibleTexts[i].record.source != TextSourceKind.generalBlock &&
                          visibleTexts[i].record.ownerEntityId != null) {
                        final matched = state.bundles
                            .expand((b) => b.entities)
                            .where((e) => e.id == visibleTexts[i].record.ownerEntityId)
                            .toList();
                        if (matched.isNotEmpty) {
                          linkedEntity = matched.first;
                        }
                      }
                      _openRuleArticle(
                        title: visibleTexts[i].record.title,
                        content: visibleTexts[i].record.rawText,
                        badge: switch (visibleTexts[i].record.source) {
                          TextSourceKind.generalBlock => 'Общие правила',
                          TextSourceKind.epicRule => 'Эпические правила',
                          TextSourceKind.entityRule => 'Способность карты',
                          _ => 'Правила',
                        },
                        linkedEntity: linkedEntity,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
        if (hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:munchkin_companion/core/constants/app_constants.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import 'package:munchkin_companion/core/utils/debouncer.dart';
import 'package:munchkin_companion/core/widgets/empty_state.dart';
import '../application/rules_controller.dart';
import '../domain/rules_category.dart';
import '../domain/rules_entities.dart';
import 'entity_detail_screen.dart';
import 'rule_article_screen.dart';
import 'rules_settings_screen.dart';
import 'widgets/entity_result_card.dart';

class RulesSearchScreen extends ConsumerStatefulWidget {
  const RulesSearchScreen({super.key});

  @override
  ConsumerState<RulesSearchScreen> createState() => _RulesSearchScreenState();
}

class _RulesSearchScreenState extends ConsumerState<RulesSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(duration: AppConstants.searchDebounce);
  late final TabController _tabController;

  // Sub-filter for Expansion rules tab
  String _expansionFilter = 'all';

  // Sub-filter for Entities tab
  String _entityCategoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(rulesProvider.notifier).search('');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debouncer.run(() {
      ref.read(rulesProvider.notifier).search(query);
      if (mounted) setState(() {});
    });
  }

  static String getSetBadge(String setId) {
    return switch (setId.toLowerCase()) {
      'core' => 'Базовый Манчкин',
      'exp2' => 'Манчкин 2: Дикий топор',
      'exp3' => 'Манчкин 3: Клирические ошибки',
      'exp4' => 'Манчкин 4: Тяга к коняге',
      'exp5' => 'Манчкин 5: Следопуты',
      'exp6' => 'Манчкин 6: Безбашенные подземелья',
      'exp7' => 'Манчкин 7: Двуручный чит',
      'exp8' => 'Манчкин 8: В хвост и в гриву',
      'exp9' => 'Манчкин 9: Пранк юрского периода',
      'exp10' => 'Манчкин 10: Искривление времени',
      'm2e' => 'Манчкин 2.0',
      'pathfinder' => 'Манчкин Pathfinder',
      'apocalypse' => 'Манчкин Апокалипсис',
      'cthulhu' => 'Манчкин Ктулху',
      'zombies' => 'Манчкин Зомби',
      'booty' => 'Пиратский Манчкин',
      'super' => 'Супер Манчкин',
      'star' => 'Звёздный Манчкин',
      'good_bad' => 'Хороший, плохой, Манчкин',
      'bites' => 'Вампирский Манчкин',
      'fu' => 'Манчкин Фу',
      _ => 'Дополнение',
    };
  }

  static Color getSetColor(String setId) {
    return switch (setId.toLowerCase()) {
      'pathfinder' => AppColors.accentFaction,
      'apocalypse' => AppColors.accentCrimson,
      'cthulhu' => const Color(0xFF9C27B0),
      'zombies' => const Color(0xFF4CAF50),
      'booty' => const Color(0xFF29B6F6),
      'super' => const Color(0xFFFFB300),
      'star' => const Color(0xFF7E57C2),
      'good_bad' => const Color(0xFF8D6E63),
      'fu' => const Color(0xFFFF7043),
      'bites' => const Color(0xFFB71C1C),
      'exp6' => const Color(0xFFEC407A),
      'exp4' => const Color(0xFFFFA726),
      'exp7' => const Color(0xFF26A69A),
      'core' => AppColors.secondaryAmber,
      'm2e' => const Color(0xFF42A5F5),
      _ => AppColors.primaryGold,
    };
  }

  bool _isSetupOrActivationBlock(RuleBlock block) {
    final id = block.id.toLowerCase();
    return id.contains('activation') ||
        id.contains('guide') ||
        id.contains('mixing') ||
        id.contains('dungeons') ||
        id.contains('seals') ||
        id.contains('steeds') ||
        id.contains('hirelings') ||
        id.contains('cultist') ||
        id.contains('portals');
  }

  bool _isCoreBlock(RuleBlock block) {
    if (_isSetupOrActivationBlock(block)) return false;
    return block.setId == 'core' || block.setId == 'm2e';
  }

  bool _isExpansionBlock(RuleBlock block) {
    if (_isSetupOrActivationBlock(block)) return true;
    return block.setId != 'core' && block.setId != 'm2e';
  }

  List<RuleBlock> _filterExpansionBlocks(List<RuleBlock> allBlocks, String query) {
    final expBlocks = allBlocks.where(_isExpansionBlock).toList();
    final q = query.trim().toLowerCase();

    return expBlocks.where((b) {
      // 1. Sub-filter
      if (_expansionFilter == 'setup') {
        if (!_isSetupOrActivationBlock(b)) return false;
      } else if (_expansionFilter == 'pathfinder') {
        if (b.setId != 'pathfinder') return false;
      } else if (_expansionFilter == 'classic') {
        if (!b.setId.startsWith('exp')) return false;
      } else if (_expansionFilter == 'spinoffs') {
        if (b.setId.startsWith('exp') || b.setId == 'core' || b.setId == 'm2e') return false;
      }

      // 2. Search query
      if (q.isEmpty) return true;
      if (b.title.toLowerCase().contains(q)) return true;
      if (b.text.toLowerCase().contains(q)) return true;
      if (getSetBadge(b.setId).toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  List<RuleEntity> _filterEntities(List<RuleEntity> allEntities, String query) {
    final q = query.trim().toLowerCase();

    return allEntities.where((e) {
      // 1. Category filter
      if (_entityCategoryFilter != 'all') {
        if (e.kind.toLowerCase() != _entityCategoryFilter) return false;
      }

      // 2. Search query
      if (q.isEmpty) return true;
      if (e.title.toLowerCase().contains(q)) return true;
      if (e.aliases.any((a) => a.toLowerCase().contains(q))) return true;
      if (getSetBadge(e.setId).toLowerCase().contains(q)) return true;
      for (final s in e.ruleSections) {
        if (s.heading != null && s.heading!.toLowerCase().contains(q)) return true;
        if (s.text.toLowerCase().contains(q)) return true;
      }
      if (e.epic != null) {
        for (final s in e.epic!.ruleSections) {
          if (s.heading != null && s.heading!.toLowerCase().contains(q)) return true;
          if (s.text.toLowerCase().contains(q)) return true;
        }
      }
      return false;
    }).toList();
  }

  List<RuleBlock> _filterCoreBlocks(List<RuleBlock> allBlocks, String query) {
    final coreBlocks = allBlocks.where(_isCoreBlock).toList();
    final q = query.trim().toLowerCase();

    return coreBlocks.where((b) {
      if (q.isEmpty) return true;
      if (b.title.toLowerCase().contains(q)) return true;
      if (b.text.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rulesState = ref.watch(rulesProvider);
    final allRuleBlocks = rulesState.bundles.expand((b) => b.ruleBlocks).toList();
    final allEntities = rulesState.bundles.expand((b) => b.entities).toList();
    final query = _searchController.text.trim();

    final filteredExpBlocks = _filterExpansionBlocks(allRuleBlocks, query);
    final filteredEntities = _filterEntities(allEntities, query);
    final filteredCoreBlocks = _filterCoreBlocks(allRuleBlocks, query);

    final expCount = query.isEmpty ? 0 : filteredExpBlocks.length;
    final entCount = query.isEmpty ? 0 : filteredEntities.length;
    final coreCount = query.isEmpty ? 0 : filteredCoreBlocks.length;

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
          // Elegant Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по правилам, дополнениям, картам…',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // "Did you mean" typo chip
          if (rulesState.searchResults.didYouMeanSuggestion != null && query.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  const Text(
                    'Возможно, вы искали: ',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  ActionChip(
                    label: Text(
                      rulesState.searchResults.didYouMeanSuggestion!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                      ),
                    ),
                    backgroundColor: AppColors.darkCard,
                    side: const BorderSide(color: AppColors.primaryGold),
                    onPressed: () {
                      _searchController.text = rulesState.searchResults.didYouMeanSuggestion!;
                      _onSearchChanged(rulesState.searchResults.didYouMeanSuggestion!);
                    },
                  ),
                ],
              ),
            ),
          ],

          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              border: Border(bottom: BorderSide(color: AppColors.darkCardBorder, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.auto_stories_outlined, size: 20),
                  text: query.isEmpty ? 'Дополнения' : 'Допы ($expCount)',
                ),
                Tab(
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  text: query.isEmpty ? 'Классы и расы' : 'Карты ($entCount)',
                ),
                Tab(
                  icon: const Icon(Icons.menu_book_outlined, size: 20),
                  text: query.isEmpty ? 'Базовые правила' : 'База ($coreCount)',
                ),
              ],
            ),
          ),

          // TabBar View Content
          Expanded(
            child: rulesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Rules of expansions & setup
                      _buildExpansionsTab(filteredExpBlocks, query, entCount, coreCount),

                      // Tab 2: Entities & classes
                      _buildEntitiesTab(filteredEntities, query, expCount, coreCount),

                      // Tab 3: Core rules
                      _buildCoreRulesTab(filteredCoreBlocks, query, expCount, entCount),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionsTab(
    List<RuleBlock> blocks,
    String query,
    int otherEntitiesCount,
    int otherCoreCount,
  ) {
    final subFilters = [
      ('all', 'Все дополнения'),
      ('setup', '⚡ Старт и активация'),
      ('pathfinder', '🛡️ Pathfinder'),
      ('classic', '🏰 Манчкин 2–10'),
      ('spinoffs', '🎲 Спин-оффы'),
    ];

    return Column(
      children: [
        // Sub-filter chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: subFilters.map((f) {
              final isSelected = _expansionFilter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryGold,
                  backgroundColor: AppColors.darkCard,
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryGold : AppColors.darkCardBorder,
                  ),
                  onSelected: (val) {
                    setState(() => _expansionFilter = f.$1);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // List or empty state
        Expanded(
          child: blocks.isEmpty
              ? _buildCrossTabEmptyState(
                  currentTabName: 'в правилах дополнений',
                  query: query,
                  altTabIdx: otherEntitiesCount > 0 ? 1 : (otherCoreCount > 0 ? 2 : -1),
                  altTabName: otherEntitiesCount > 0
                      ? '«Классы и расы» ($otherEntitiesCount)'
                      : (otherCoreCount > 0 ? '«Базовые правила» ($otherCoreCount)' : null),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    final setBadge = getSetBadge(block.setId);
                    final setColor = getSetColor(block.setId);
                    final isSetup = _isSetupOrActivationBlock(block);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          _openRuleArticle(
                            title: block.title,
                            content: block.text,
                            badge: setBadge,
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: setColor.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: setColor.withOpacity(0.45)),
                                    ),
                                    child: Text(
                                      setBadge,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: setColor,
                                      ),
                                    ),
                                  ),
                                  if (isSetup) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryAmber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.secondaryAmber.withOpacity(0.5)),
                                      ),
                                      child: const Text(
                                        '⚡ СТАРТ И МЕХАНИКА',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondaryAmber,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                block.title,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                block.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEntitiesTab(
    List<RuleEntity> entities,
    String query,
    int otherExpCount,
    int otherCoreCount,
  ) {
    final catFilters = [
      ('all', 'Все'),
      ('class', 'Классы'),
      ('race', 'Расы'),
      ('faction', 'Фракции (Pathfinder)'),
      ('mojo', 'Моджо'),
      ('power', 'Силы'),
      ('style', 'Стили'),
      ('accent', 'Акценты'),
      ('steed', 'Скакуны'),
      ('hireling', 'Наёмники'),
      ('madness', 'Безумие'),
    ];

    return Column(
      children: [
        // Category chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: catFilters.map((f) {
              final isSelected = _entityCategoryFilter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryGold,
                  backgroundColor: AppColors.darkCard,
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryGold : AppColors.darkCardBorder,
                  ),
                  onSelected: (val) {
                    setState(() => _entityCategoryFilter = f.$1);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // List or empty state
        Expanded(
          child: entities.isEmpty
              ? _buildCrossTabEmptyState(
                  currentTabName: 'в классах и особенностях',
                  query: query,
                  altTabIdx: otherExpCount > 0 ? 0 : (otherCoreCount > 0 ? 2 : -1),
                  altTabName: otherExpCount > 0
                      ? '«Правила дополнений» ($otherExpCount)'
                      : (otherCoreCount > 0 ? '«Базовые правила» ($otherCoreCount)' : null),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  itemCount: entities.length,
                  itemBuilder: (context, index) {
                    final entity = entities[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EntityResultCard(
                        entity: entity,
                        onTap: () => _openDetail(entity),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCoreRulesTab(
    List<RuleBlock> blocks,
    String query,
    int otherExpCount,
    int otherEntCount,
  ) {
    return Column(
      children: [
        Expanded(
          child: blocks.isEmpty
              ? _buildCrossTabEmptyState(
                  currentTabName: 'в базовых правилах',
                  query: query,
                  altTabIdx: otherExpCount > 0 ? 0 : (otherEntCount > 0 ? 1 : -1),
                  altTabName: otherExpCount > 0
                      ? '«Правила дополнений» ($otherExpCount)'
                      : (otherEntCount > 0 ? '«Классы и расы» ($otherEntCount)' : null),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    final isM2e = block.setId == 'm2e';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          _openRuleArticle(
                            title: block.title,
                            content: block.text,
                            badge: isM2e ? 'Манчкин 2.0' : 'Базовые правила',
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isM2e ? const Color(0xFF42A5F5) : AppColors.secondaryAmber)
                                          .withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (isM2e ? const Color(0xFF42A5F5) : AppColors.secondaryAmber)
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      isM2e ? 'Манчкин 2.0' : 'Базовые правила',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isM2e ? const Color(0xFF42A5F5) : AppColors.secondaryAmber,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                block.title,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                block.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCrossTabEmptyState({
    required String currentTabName,
    required String query,
    required int altTabIdx,
    String? altTabName,
  }) {
    if (query.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Раздел пуст',
        subtitle: 'В этой категории пока нет записей.',
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Ничего не найдено $currentTabName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Попробуйте изменить запрос или поискать в других вкладках.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (altTabIdx >= 0 && altTabName != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text('Смотреть во вкладке $altTabName'),
                onPressed: () {
                  _tabController.animateTo(altTabIdx);
                },
              ),
            ],
          ],
        ),
      ),
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

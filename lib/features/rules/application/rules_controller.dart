import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/importer.dart';
import '../data/pack_registry.dart';
import '../domain/rules_entities.dart';
import 'search_index.dart';
import 'search_service.dart';

class RulesState {
  final List<RulesBundle> bundles;
  final SearchIndex index;
  final SearchService service;
  final String activeQuery;
  final SearchResultGroup searchResults;
  final bool isLoading;

  const RulesState({
    required this.bundles,
    required this.index,
    required this.service,
    this.activeQuery = '',
    this.searchResults = const SearchResultGroup(),
    this.isLoading = false,
  });

  RulesState copyWith({
    List<RulesBundle>? bundles,
    SearchIndex? index,
    SearchService? service,
    String? activeQuery,
    SearchResultGroup? searchResults,
    bool? isLoading,
  }) {
    return RulesState(
      bundles: bundles ?? this.bundles,
      index: index ?? this.index,
      service: service ?? this.service,
      activeQuery: activeQuery ?? this.activeQuery,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RulesNotifier extends Notifier<RulesState> {
  @override
  RulesState build() {
    // Initial loading
    Future.microtask(() => loadRules());
    return RulesState(
      bundles: const [],
      index: SearchIndex.build(const []),
      service: SearchService(index: SearchIndex.build(const [])),
      isLoading: true,
    );
  }

  Future<void> loadRules() async {
    state = state.copyWith(isLoading: true);
    final bundles = await PackRegistry.loadAllBundles();
    final index = SearchIndex.build(bundles);
    final service = SearchService(index: index);

    final results = state.activeQuery.isNotEmpty
        ? service.search(state.activeQuery)
        : const SearchResultGroup();

    state = state.copyWith(
      bundles: bundles,
      index: index,
      service: service,
      searchResults: results,
      isLoading: false,
    );
  }

  void search(String query) {
    if (query.trim().isEmpty) {
      state = state.copyWith(
        activeQuery: '',
        searchResults: const SearchResultGroup(),
      );
      return;
    }

    final results = state.service.search(query);
    state = state.copyWith(
      activeQuery: query,
      searchResults: results,
    );
  }

  Future<void> importPack(String jsonString) async {
    await RulesImporter.importPackJson(jsonString);
    await loadRules();
  }

  Future<void> removePack(String contentId) async {
    await PackRegistry.removeImportedPack(contentId);
    await loadRules();
  }
}

final rulesProvider = NotifierProvider<RulesNotifier, RulesState>(
  RulesNotifier.new,
);

/// List of all classes and races available across installed rule packs
/// (used by trait selection sheets in the game).
final allRuleEntitiesProvider = Provider<List<RuleEntity>>((ref) {
  final bundles = ref.watch(rulesProvider.select((s) => s.bundles));
  final entities = <RuleEntity>[];
  for (final b in bundles) {
    entities.addAll(b.entities);
  }
  return entities;
});

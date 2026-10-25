import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/core/utils/edit_distance.dart';
import 'package:munchkin_companion/features/rules/application/search_index.dart';
import 'package:munchkin_companion/features/rules/application/search_service.dart';
import 'package:munchkin_companion/features/rules/data/bundle_validator.dart';
import 'package:munchkin_companion/features/rules/domain/rules_entities.dart';

void main() {
  group('EditDistance (Damerau-Levenshtein) Tests', () {
    test('Calculates exact match as distance 0', () {
      expect(EditDistance.damerauLevenshtein('orc', 'orc'), 0);
      expect(EditDistance.damerauLevenshtein('эльф', 'эльф'), 0);
    });

    test('Handles adjacent transposition correctly as distance 1', () {
      // 'ro' vs 'or'
      expect(EditDistance.damerauLevenshtein('orc', 'roc'), 1);
      // 'элфь' vs 'эльф'
      expect(EditDistance.damerauLevenshtein('элфь', 'эльф'), 1);
    });

    test('Handles insertion and deletion as distance 1', () {
      expect(EditDistance.damerauLevenshtein('orc', 'orcs'), 1);
      expect(EditDistance.damerauLevenshtein('cleric', 'cleri'), 1);
    });

    test('Handles substitution as distance 1', () {
      expect(EditDistance.damerauLevenshtein('cat', 'bat'), 1);
    });

    test('Respects maxDistance early exit threshold', () {
      // Distance is 4, maxDistance is 1 -> returns maxDistance + 1 = 2
      final dist = EditDistance.damerauLevenshtein('warrior', 'mage', 1);
      expect(dist, greaterThan(1));
    });
  });

  group('BundleValidator Tests', () {
    test('Accepts valid bundle', () {
      const bundle = RulesBundle(
        schemaVersion: 1,
        contentId: 'test_pack',
        contentVersion: '1.0.0',
        entities: [
          RuleEntity(
            id: 'e1',
            kind: 'class',
            title: 'Воин',
            setId: 'core',
          ),
        ],
      );

      expect(() => BundleValidator.validate(bundle), returnsNormally);
    });

    test('Rejects future schemaVersion', () {
      const bundle = RulesBundle(
        schemaVersion: 99,
        contentId: 'test_pack',
        contentVersion: '1.0.0',
        entities: [
          RuleEntity(id: 'e1', kind: 'class', title: 'Воин', setId: 'core'),
        ],
      );

      expect(() => BundleValidator.validate(bundle), throwsException);
    });

    test('Rejects empty bundle', () {
      const bundle = RulesBundle(
        schemaVersion: 1,
        contentId: 'test_pack',
        contentVersion: '1.0.0',
        entities: [],
        ruleBlocks: [],
      );

      expect(() => BundleValidator.validate(bundle), throwsException);
    });
  });

  group('SearchService Ranking Golden Tests', () {
    late SearchService searchService;

    setUp(() {
      const bundle = RulesBundle(
        schemaVersion: 1,
        contentId: 'core_test',
        contentVersion: '1.0.0',
        entities: [
          RuleEntity(
            id: 'warrior',
            kind: 'class',
            title: 'Воин',
            aliases: ['боец', 'воины', 'warrior'],
            setId: 'core',
            ruleSections: [
              RuleSection(
                heading: 'Буйство',
                text: 'Сбрось карты в бою для бонуса силы.',
              ),
            ],
            epic: EpicProperties(
              ruleSections: [
                RuleSection(
                  heading: 'Эпическое буйство',
                  text: 'Каждая сброшенная карта дает +2 к силе.',
                ),
              ],
            ),
          ),
          RuleEntity(
            id: 'orc',
            kind: 'race',
            title: 'Орк',
            aliases: ['орки', 'orc'],
            setId: 'core',
            ruleSections: [
              RuleSection(
                heading: 'Проклятия',
                text: 'Сбрось уровень вместо проклятия.',
              ),
            ],
          ),
          RuleEntity(
            id: 'wizard',
            kind: 'class',
            title: 'Волшебник',
            aliases: ['маг', 'маги', 'wizard'],
            setId: 'core',
            ruleSections: [
              RuleSection(
                heading: 'Усмирение',
                text: 'Сбрось карты, чтобы усмирить монстра.',
              ),
            ],
          ),
        ],
        ruleBlocks: [
          RuleBlock(
            id: 'combat',
            title: 'Правила боя',
            setId: 'core',
            text: 'В бою побеждает тот, чья боевая сила выше силы монстра. Воин побеждает при ничьей.',
            relatedEntityIds: ['warrior'],
          ),
        ],
      );

      final index = SearchIndex.build([bundle]);
      searchService = SearchService(index: index);
    });

    test('Exact entity title query returns Tier 1 score 1000', () {
      final results = searchService.search('Орк');
      expect(results.entityResults.isNotEmpty, isTrue);
      expect(results.entityResults.first.entity.id, 'orc');
      expect(results.entityResults.first.score, 1000);
    });

    test('Prefix entity title query returns Tier 1 score 850', () {
      final results = searchService.search('Вои');
      expect(results.entityResults.isNotEmpty, isTrue);
      expect(results.entityResults.first.entity.id, 'warrior');
      expect(results.entityResults.first.score, 850);
    });

    test('Exact alias match returns Tier 1 score 900', () {
      final results = searchService.search('маг');
      expect(results.entityResults.isNotEmpty, isTrue);
      expect(results.entityResults.first.entity.id, 'wizard');
      expect(results.entityResults.first.score, 900);
    });

    test('Text mention in rule block returns Tier 3 occurrences', () {
      final results = searchService.search('боевая сила');
      expect(results.textResults.isNotEmpty, isTrue);
      expect(results.textResults.first.record.title, 'Правила боя');
    });

    test('Fuzzy query generates suggestion', () {
      // Query "вршебник" is 1-2 edit distance away from "Волшебник"
      final results = searchService.search('волшебнк');
      expect(results.didYouMeanSuggestion, isNotNull);
      expect(results.didYouMeanSuggestion, 'Волшебник');
    });
  });
}

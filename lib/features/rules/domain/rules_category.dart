/// Category definitions and helpers to expand "other" into concrete, specific categories.
library;

import 'rules_entities.dart';

enum RuleCategoryType {
  classes('class', 'Классы', 'Классовые карты и специализации'),
  races('race', 'Расы', 'Биологические виды и расовые особенности'),
  mojos('mojo', 'Моджо', 'Зомби-модификаторы и вариации'),
  powers('power', 'Силы', 'Сверхсилы, вампирские и супер-способности'),
  styles('style', 'Стили', 'Боевые искусства и восточные стили'),
  training('training', 'Подготовка', 'Шпионские навыки и подготовка'),
  accents('accent', 'Акценты', 'Морские и пиратские национальные акценты'),
  steeds('steed', 'Скакуны и Корабли', 'Верховые животные, скакуны и звездные суда'),
  hirelings('hireling', 'Наёмники и Спутники', 'Помощники, напарники и миньоны'),
  dungeons('dungeon', 'Подземелья и Порталы', 'Комнаты, порталы и смена подземелий'),
  enhancers('enhancer', 'Усилители', 'Модификаторы рас, классов, шмоток и монстров'),
  seals('seal', 'Печати и Катастрофы', 'События апокалипсиса и бедствия'),
  madness('madness', 'Безумие', 'Психозы и рассудок из Манчкин Ктулху'),
  items('item', 'Шмотки и Снаряжение', 'Оружие, броня, головняки и обувка'),
  general('general', 'Особые правила', 'Прочие карты и свойства');

  final String id;
  final String title;
  final String description;

  const RuleCategoryType(this.id, this.title, this.description);

  static RuleCategoryType fromKind(String? kind) {
    if (kind == null) return RuleCategoryType.general;
    final k = kind.toLowerCase().trim();
    switch (k) {
      case 'class':
        return RuleCategoryType.classes;
      case 'race':
        return RuleCategoryType.races;
      case 'mojo':
        return RuleCategoryType.mojos;
      case 'power':
        return RuleCategoryType.powers;
      case 'style':
        return RuleCategoryType.styles;
      case 'training':
        return RuleCategoryType.training;
      case 'accent':
        return RuleCategoryType.accents;
      case 'steed':
      case 'ship':
      case 'vehicle':
      case 'mount':
        return RuleCategoryType.steeds;
      case 'hireling':
      case 'sidekick':
      case 'companion':
      case 'minion':
        return RuleCategoryType.hirelings;
      case 'dungeon':
      case 'portal':
        return RuleCategoryType.dungeons;
      case 'enhancer':
      case 'modifier':
        return RuleCategoryType.enhancers;
      case 'seal':
      case 'disaster':
        return RuleCategoryType.seals;
      case 'madness':
        return RuleCategoryType.madness;
      case 'item':
      case 'gear':
        return RuleCategoryType.items;
      default:
        return RuleCategoryType.general;
    }
  }
}

class CategorizedEntities {
  final Map<RuleCategoryType, List<RuleEntity>> categories;

  CategorizedEntities(this.categories);

  factory CategorizedEntities.fromEntities(List<RuleEntity> entities) {
    final map = <RuleCategoryType, List<RuleEntity>>{};
    for (final entity in entities) {
      final cat = RuleCategoryType.fromKind(entity.kind);
      map.putIfAbsent(cat, () => []).add(entity);
    }
    return CategorizedEntities(map);
  }

  List<RuleEntity> get(RuleCategoryType cat) => categories[cat] ?? const [];

  List<RuleCategoryType> get activeCategories =>
      categories.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList();
}

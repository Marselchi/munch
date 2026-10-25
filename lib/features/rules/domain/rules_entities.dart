/// Domain models for Munchkin rules, sets, entities (classes, races), and general rule blocks.
/// Pure Dart (no Flutter imports).
library;

class RuleSet {
  final String id;
  final String title;
  final String kind; // 'core' | 'expansion' | 'analogue'

  const RuleSet({
    required this.id,
    required this.title,
    this.kind = 'core',
  });

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'kind': kind};

  factory RuleSet.fromJson(Map<String, dynamic> json) => RuleSet(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: json['kind'] as String? ?? 'core',
      );
}

class RuleSection {
  final String? heading;
  final String text;

  const RuleSection({this.heading, required this.text});

  Map<String, dynamic> toJson() => {
        if (heading != null) 'heading': heading,
        'text': text,
      };

  factory RuleSection.fromJson(Map<String, dynamic> json) => RuleSection(
        heading: json['heading'] as String?,
        text: json['text'] as String? ?? '',
      );
}

class EpicProperties {
  final List<RuleSection> ruleSections;

  const EpicProperties({required this.ruleSections});

  Map<String, dynamic> toJson() => {
        'ruleSections': ruleSections.map((s) => s.toJson()).toList(),
      };

  factory EpicProperties.fromJson(Map<String, dynamic> json) => EpicProperties(
        ruleSections: (json['ruleSections'] as List<dynamic>?)
                ?.map((s) => RuleSection.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class RuleEntity {
  final String id;
  final String kind; // 'class' | 'race' | 'origin' | etc.
  final String title;
  final List<String> aliases;
  final String setId;
  final List<RuleSection> ruleSections;
  final EpicProperties? epic;

  const RuleEntity({
    required this.id,
    required this.kind,
    required this.title,
    this.aliases = const [],
    required this.setId,
    this.ruleSections = const [],
    this.epic,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'aliases': aliases,
        'setId': setId,
        'ruleSections': ruleSections.map((s) => s.toJson()).toList(),
        if (epic != null) 'epic': epic!.toJson(),
      };

  factory RuleEntity.fromJson(Map<String, dynamic> json) => RuleEntity(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? 'entity',
        title: json['title'] as String,
        aliases: (json['aliases'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        setId: json['setId'] as String? ?? 'core',
        ruleSections: (json['ruleSections'] as List<dynamic>?)
                ?.map((s) => RuleSection.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        epic: json['epic'] != null
            ? EpicProperties.fromJson(json['epic'] as Map<String, dynamic>)
            : null,
      );
}

class RuleBlock {
  final String id;
  final String title;
  final String setId;
  final String text;
  final List<String> relatedEntityIds;

  const RuleBlock({
    required this.id,
    required this.title,
    required this.setId,
    required this.text,
    this.relatedEntityIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'setId': setId,
        'text': text,
        'relatedEntityIds': relatedEntityIds,
      };

  factory RuleBlock.fromJson(Map<String, dynamic> json) => RuleBlock(
        id: json['id'] as String,
        title: json['title'] as String,
        setId: json['setId'] as String? ?? 'core',
        text: json['text'] as String? ?? '',
        relatedEntityIds: (json['relatedEntityIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class RulesBundle {
  final int schemaVersion;
  final String contentId;
  final String contentVersion;
  final String locale;
  final List<RuleSet> sets;
  final List<RuleEntity> entities;
  final List<RuleBlock> ruleBlocks;

  const RulesBundle({
    this.schemaVersion = 1,
    required this.contentId,
    required this.contentVersion,
    this.locale = 'ru',
    this.sets = const [],
    this.entities = const [],
    this.ruleBlocks = const [],
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'contentId': contentId,
        'contentVersion': contentVersion,
        'locale': locale,
        'sets': sets.map((s) => s.toJson()).toList(),
        'entities': entities.map((e) => e.toJson()).toList(),
        'ruleBlocks': ruleBlocks.map((b) => b.toJson()).toList(),
      };

  factory RulesBundle.fromJson(Map<String, dynamic> json) => RulesBundle(
        schemaVersion: json['schemaVersion'] as int? ?? 1,
        contentId: json['contentId'] as String,
        contentVersion: json['contentVersion'] as String? ?? '1.0.0',
        locale: json['locale'] as String? ?? 'ru',
        sets: (json['sets'] as List<dynamic>?)
                ?.map((s) => RuleSet.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        entities: (json['entities'] as List<dynamic>?)
                ?.map((e) => RuleEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        ruleBlocks: (json['ruleBlocks'] as List<dynamic>?)
                ?.map((b) => RuleBlock.fromJson(b as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

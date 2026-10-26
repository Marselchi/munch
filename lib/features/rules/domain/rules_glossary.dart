/// Data model for Munchkin rules glossary and highlighted terms.
library;

class RuleTerm {
  final String id;
  final String term;
  final String? englishTerm;
  final List<String> aliases;
  final String definition;
  final String? ruleBlockId;
  final String? entityId;
  final String category;
  final String originPack;

  const RuleTerm({
    required this.id,
    required this.term,
    this.englishTerm,
    this.aliases = const [],
    required this.definition,
    this.ruleBlockId,
    this.entityId,
    this.category = 'core',
    required this.originPack,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'term': term,
        if (englishTerm != null) 'englishTerm': englishTerm,
        'aliases': aliases,
        'definition': definition,
        if (ruleBlockId != null) 'ruleBlockId': ruleBlockId,
        if (entityId != null) 'entityId': entityId,
        'category': category,
        'originPack': originPack,
      };

  factory RuleTerm.fromJson(Map<String, dynamic> json) => RuleTerm(
        id: json['id'] as String,
        term: json['term'] as String,
        englishTerm: json['englishTerm'] as String?,
        aliases: (json['aliases'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        definition: json['definition'] as String? ?? '',
        ruleBlockId: json['ruleBlockId'] as String?,
        entityId: json['entityId'] as String?,
        category: json['category'] as String? ?? 'core',
        originPack: json['originPack'] as String? ?? 'Классический Манчкин',
      );
}

class TermMatchSpan {
  final int start;
  final int end;
  final String matchedText;
  final RuleTerm term;

  const TermMatchSpan({
    required this.start,
    required this.end,
    required this.matchedText,
    required this.term,
  });
}

class StaticSpan {
  final int start;
  final int end;
  final String termId;

  const StaticSpan({
    required this.start,
    required this.end,
    required this.termId,
  });
}

import '../../../core/utils/normalize.dart';
import '../domain/rules_entities.dart';

enum TextSourceKind {
  entityRule,
  epicRule,
  generalBlock,
}

class EntityRecord {
  final RuleEntity entity;
  final String normTitle;
  final List<String> normAliases;
  final Set<String> allTokens;

  EntityRecord({
    required this.entity,
    required this.normTitle,
    required this.normAliases,
    required this.allTokens,
  });

  factory EntityRecord.fromEntity(RuleEntity entity) {
    final normTitle = StringNormalizer.normalize(entity.title);
    final normAliases = entity.aliases
        .map((a) => StringNormalizer.normalize(a))
        .where((a) => a.isNotEmpty)
        .toList(growable: false);

    final tokens = <String>{};
    tokens.addAll(StringNormalizer.tokenize(entity.title));
    for (final alias in entity.aliases) {
      tokens.addAll(StringNormalizer.tokenize(alias));
    }

    return EntityRecord(
      entity: entity,
      normTitle: normTitle,
      normAliases: normAliases,
      allTokens: tokens,
    );
  }
}

class TextRecord {
  final String recordId;
  final String? ownerEntityId;
  final TextSourceKind source;
  final String title;
  final String rawText;
  final String normText;
  final List<String> tokens;

  TextRecord({
    required this.recordId,
    this.ownerEntityId,
    required this.source,
    required this.title,
    required this.rawText,
    required this.normText,
    required this.tokens,
  });
}

class IndexPosting {
  final int recordIndex;
  final List<int> positions; // Character offsets in normText

  const IndexPosting({required this.recordIndex, required this.positions});
}

/// Inverted search index built across entity titles, aliases, rule sections,
/// epic properties, and general rule blocks.
/// Pure Dart (no Flutter imports).
class SearchIndex {
  final List<EntityRecord> entityRecords;
  final List<TextRecord> textRecords;
  final Map<String, List<IndexPosting>> invertedIndex;
  final List<(String term, EntityRecord record)> vocabulary;

  SearchIndex({
    required this.entityRecords,
    required this.textRecords,
    required this.invertedIndex,
    required this.vocabulary,
  });

  factory SearchIndex.build(List<RulesBundle> bundles) {
    final entityRecords = <EntityRecord>[];
    final textRecords = <TextRecord>[];
    final invertedIndex = <String, List<IndexPosting>>{};
    final vocab = <(String, EntityRecord)>[];

    for (final bundle in bundles) {
      // Index Entities
      for (final entity in bundle.entities) {
        final entityRec = EntityRecord.fromEntity(entity);
        entityRecords.add(entityRec);

        // Add to vocabulary for fuzzy matching
        vocab.add((entityRec.normTitle, entityRec));
        for (final alias in entityRec.normAliases) {
          vocab.add((alias, entityRec));
        }

        // Entity rule sections
        for (var i = 0; i < entity.ruleSections.length; i++) {
          final section = entity.ruleSections[i];
          final raw = '${section.heading ?? ""}: ${section.text}';
          final norm = StringNormalizer.normalize(raw);
          final tokens = StringNormalizer.tokenize(raw);

          final rec = TextRecord(
            recordId: '${entity.id}.section.$i',
            ownerEntityId: entity.id,
            source: TextSourceKind.entityRule,
            title: '${entity.title}${section.heading != null ? " — ${section.heading}" : ""}',
            rawText: raw,
            normText: norm,
            tokens: tokens,
          );
          textRecords.add(rec);
        }

        // Epic properties
        if (entity.epic != null) {
          for (var i = 0; i < entity.epic!.ruleSections.length; i++) {
            final section = entity.epic!.ruleSections[i];
            final raw = 'Эпик: ${section.heading ?? ""}: ${section.text}';
            final norm = StringNormalizer.normalize(raw);
            final tokens = StringNormalizer.tokenize(raw);

            final rec = TextRecord(
              recordId: '${entity.id}.epic.$i',
              ownerEntityId: entity.id,
              source: TextSourceKind.epicRule,
              title: '${entity.title} (Эпические правила)',
              rawText: raw,
              normText: norm,
              tokens: tokens,
            );
            textRecords.add(rec);
          }
        }
      }

      // Index General Rule Blocks
      for (final block in bundle.ruleBlocks) {
        final raw = '${block.title}. ${block.text}';
        final norm = StringNormalizer.normalize(raw);
        final tokens = StringNormalizer.tokenize(raw);

        final rec = TextRecord(
          recordId: block.id,
          ownerEntityId: block.relatedEntityIds.isNotEmpty ? block.relatedEntityIds.first : null,
          source: TextSourceKind.generalBlock,
          title: block.title,
          rawText: raw,
          normText: norm,
          tokens: tokens,
        );
        textRecords.add(rec);
      }
    }

    // Build inverted index for textRecords
    for (var idx = 0; idx < textRecords.length; idx++) {
      final rec = textRecords[idx];
      for (final token in rec.tokens) {
        final postings = invertedIndex.putIfAbsent(token, () => []);
        if (postings.isEmpty || postings.last.recordIndex != idx) {
          postings.add(IndexPosting(recordIndex: idx, positions: [0]));
        }
      }
    }

    return SearchIndex(
      entityRecords: entityRecords,
      textRecords: textRecords,
      invertedIndex: invertedIndex,
      vocabulary: vocab,
    );
  }
}

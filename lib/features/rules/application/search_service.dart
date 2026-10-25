import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/edit_distance.dart';
import '../../../core/utils/normalize.dart';
import '../domain/rules_entities.dart';
import 'search_index.dart';

class EntitySearchResult {
  final RuleEntity entity;
  final int score;
  final String matchedOn; // e.g. title or alias

  const EntitySearchResult({
    required this.entity,
    required this.score,
    required this.matchedOn,
  });
}

class TextSnippetHighlight {
  final int start;
  final int end;

  const TextSnippetHighlight({required this.start, required this.end});
}

class TextSearchResult {
  final TextRecord record;
  final String snippet;
  final List<TextSnippetHighlight> highlights;
  final int score;

  const TextSearchResult({
    required this.record,
    required this.snippet,
    required this.highlights,
    required this.score,
  });
}

class SearchResultGroup {
  final List<EntitySearchResult> entityResults;
  final List<TextSearchResult> textResults;
  final String? didYouMeanSuggestion;

  const SearchResultGroup({
    this.entityResults = const [],
    this.textResults = const [],
    this.didYouMeanSuggestion,
  });

  bool get isEmpty => entityResults.isEmpty && textResults.isEmpty;
}

/// Pure Dart search service implementing tiered ranking and snippet extraction.
class SearchService {
  final SearchIndex index;

  SearchService({required this.index});

  SearchResultGroup search(String rawQuery) {
    final queryNorm = StringNormalizer.normalize(rawQuery);
    if (queryNorm.isEmpty) {
      return const SearchResultGroup();
    }

    final queryTokens = StringNormalizer.tokenize(queryNorm);
    if (queryTokens.isEmpty) {
      return const SearchResultGroup();
    }

    // 1. Rank Entities (Tiers 1 & 2)
    final entityScoreMap = <String, (RuleEntity, int, String)>{};
    String? fuzzySuggestion;
    var bestFuzzyDist = 999;

    for (final entityRec in index.entityRecords) {
      int score = 0;
      String matchedOn = entityRec.entity.title;

      // Tier 1: Exact and Prefix Title Matches
      if (entityRec.normTitle == queryNorm) {
        score = math.max(score, 1000);
      } else if (entityRec.normTitle.startsWith(queryNorm)) {
        score = math.max(score, 850);
      }

      // Tier 1: Exact and Prefix Alias Matches
      for (final alias in entityRec.normAliases) {
        if (alias == queryNorm) {
          score = math.max(score, 900);
          matchedOn = alias;
        } else if (alias.startsWith(queryNorm)) {
          score = math.max(score, 800);
          matchedOn = alias;
        }
      }

      // Tier 2: Fuzzy Matches on Title and Aliases
      final maxAllowedDist = EditDistance.maxAllowedDistance(queryNorm.length);
      if (score == 0 && maxAllowedDist > 0) {
        // Check title
        final distTitle = EditDistance.damerauLevenshtein(queryNorm, entityRec.normTitle, maxAllowedDist);
        if (distTitle <= maxAllowedDist) {
          final fuzzyScore = 799 - (40 * distTitle);
          if (fuzzyScore > score) {
            score = fuzzyScore;
            matchedOn = entityRec.entity.title;
            if (distTitle < bestFuzzyDist) {
              bestFuzzyDist = distTitle;
              fuzzySuggestion = entityRec.entity.title;
            }
          }
        }

        // Check aliases
        for (final alias in entityRec.normAliases) {
          final distAlias = EditDistance.damerauLevenshtein(queryNorm, alias, maxAllowedDist);
          if (distAlias <= maxAllowedDist) {
            final fuzzyScore = 799 - (40 * distAlias);
            if (fuzzyScore > score) {
              score = fuzzyScore;
              matchedOn = alias;
              if (distAlias < bestFuzzyDist) {
                bestFuzzyDist = distAlias;
                fuzzySuggestion = entityRec.entity.title;
              }
            }
          }
        }
      }

      // Multi-word token match bonus
      if (queryTokens.length > 1) {
        var allTokensFound = true;
        for (final qt in queryTokens) {
          if (!entityRec.allTokens.any((t) => t.contains(qt))) {
            allTokensFound = false;
            break;
          }
        }
        if (allTokensFound && score < 700) {
          score = 750;
        }
      }

      if (score > 0) {
        entityScoreMap[entityRec.entity.id] = (entityRec.entity, score, matchedOn);
      }
    }

    final entityResults = entityScoreMap.values
        .map((entry) => EntitySearchResult(
              entity: entry.$1,
              score: entry.$2,
              matchedOn: entry.$3,
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final topEntities = entityResults.take(AppConstants.maxEntitySearchResults).toList();

    // 2. Rank Text Occurrences (Tier 3)
    final textScoreMap = <int, int>{}; // recordIndex -> score

    for (final qt in queryTokens) {
      // Find matching postings (prefix or substring in inverted index)
      for (final entry in index.invertedIndex.entries) {
        if (entry.key.contains(qt)) {
          for (final posting in entry.value) {
            final rec = index.textRecords[posting.recordIndex];
            final tf = rec.tokens.where((t) => t.contains(qt)).length;

            int baseScore = switch (rec.source) {
              TextSourceKind.entityRule => 150 + (10 * math.min(tf, 5)),
              TextSourceKind.epicRule => 130 + (10 * math.min(tf, 5)),
              TextSourceKind.generalBlock => 100 + (10 * math.min(tf, 5)),
            };

            // Bonus if block title contains the term
            if (rec.title.toLowerCase().contains(qt)) {
              baseScore += 50;
            }

            textScoreMap[posting.recordIndex] =
                (textScoreMap[posting.recordIndex] ?? 0) + baseScore;
          }
        }
      }
    }

    final textResults = <TextSearchResult>[];
    for (final entry in textScoreMap.entries) {
      final rec = index.textRecords[entry.key];
      final (snippet, highlights) = _buildSnippet(rec.rawText, queryTokens);

      textResults.add(TextSearchResult(
        record: rec,
        snippet: snippet,
        highlights: highlights,
        score: entry.value,
      ));
    }

    textResults.sort((a, b) => b.score.compareTo(a.score));
    final topTextResults = textResults.take(AppConstants.maxTextSearchResults).toList();

    // "Did you mean" suggestion if no strong exact matches exist
    String? suggestion;
    if (topEntities.isEmpty || topEntities.first.score < 800) {
      suggestion = fuzzySuggestion;
    }

    return SearchResultGroup(
      entityResults: topEntities,
      textResults: topTextResults,
      didYouMeanSuggestion: suggestion,
    );
  }

  /// Builds a snippet with ~40 chars window around first occurrence.
  (String, List<TextSnippetHighlight>) _buildSnippet(
    String rawText,
    List<String> queryTokens,
  ) {
    final lower = rawText.toLowerCase();
    int matchStart = -1;
    int matchEnd = -1;

    for (final token in queryTokens) {
      final idx = lower.indexOf(token);
      if (idx != -1) {
        matchStart = idx;
        matchEnd = idx + token.length;
        break;
      }
    }

    if (matchStart == -1) {
      final snippet = rawText.length > 90 ? '${rawText.substring(0, 90)}…' : rawText;
      return (snippet, const []);
    }

    const window = 40;
    final snippetStart = math.max(0, matchStart - window);
    final snippetEnd = math.min(rawText.length, matchEnd + window);

    final prefix = snippetStart > 0 ? '…' : '';
    final suffix = snippetEnd < rawText.length ? '…' : '';
    final extracted = rawText.substring(snippetStart, snippetEnd);
    final snippet = '$prefix$extracted$suffix';

    final offsetInSnippet = prefix.length + (matchStart - snippetStart);
    final highlight = TextSnippetHighlight(
      start: offsetInSnippet,
      end: offsetInSnippet + (matchEnd - matchStart),
    );

    return (snippet, [highlight]);
  }
}

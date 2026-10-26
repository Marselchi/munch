import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/static_glossary_spans.g.dart';
import '../domain/rules_glossary.dart';
import 'glossary_data.dart';

class TextSpanItem {
  final String text;
  final RuleTerm? matchedTerm;

  const TextSpanItem.text(this.text) : matchedTerm = null;
  const TextSpanItem.term(this.text, this.matchedTerm);

  bool get isTerm => matchedTerm != null;
}

class GlossaryService {
  final Map<String, RuleTerm> _termsById = {};
  final Map<String, RuleTerm> _aliasMap = {};
  List<String> _sortedAliases = [];

  GlossaryService({List<RuleTerm> initialTerms = const []}) {
    registerTerms(initialTerms);
  }

  void registerTerm(RuleTerm term) {
    _termsById[term.id] = term;
    final primary = term.term.trim().toLowerCase();
    _aliasMap[primary] = term;

    for (final a in term.aliases) {
      final norm = a.trim().toLowerCase();
      if (norm.isNotEmpty) {
        _aliasMap[norm] = term;
      }
    }

    _sortAliases();
  }

  void registerTerms(Iterable<RuleTerm> terms) {
    for (final t in terms) {
      _termsById[t.id] = t;
      final primary = t.term.trim().toLowerCase();
      _aliasMap[primary] = t;
      for (final a in t.aliases) {
        final norm = a.trim().toLowerCase();
        if (norm.isNotEmpty) {
          _aliasMap[norm] = t;
        }
      }
    }
    _sortAliases();
  }

  void _sortAliases() {
    // Sort longer phrases first so that "Усилитель шмоток" matches before "Шмотка"
    _sortedAliases = _aliasMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  RuleTerm? getTermById(String id) => _termsById[id];

  static const Map<String, String> _stemToTermId = {
    'уровн': 'term_level',
    'класс': 'term_class',
    'шмотк': 'term_item',
    'монстр': 'term_monster',
    'проклят': 'term_curse',
    'смыв': 'term_runaway',
    'непотребств': 'term_bad_stuff',
    'наемник': 'term_hireling',
    'наёмник': 'term_hireling',
    'скакун': 'term_steed',
    'подземел': 'term_dungeon',
    'портал': 'term_portal',
    'печат': 'term_seal',
    'сивучат': 'term_seal',
    'катастроф': 'term_disaster',
    'моджо': 'term_mojo',
    'безуми': 'term_madness',
    'акцент': 'term_accent',
    'корабл': 'term_ship',
    'стил': 'term_style',
  };

  RuleTerm? findTermByWord(String word) {
    final norm = word.trim().toLowerCase();
    if (_aliasMap.containsKey(norm)) {
      return _aliasMap[norm];
    }
    for (final entry in _stemToTermId.entries) {
      if (norm.startsWith(entry.key)) {
        return _termsById[entry.value];
      }
    }
    return null;
  }

  List<RuleTerm> get allTerms => _termsById.values.toList();

  /// Tokenizes [rawText] into plain text spans and matched [RuleTerm] spans.
  /// First checks the precomputed static glossary index (O(1) lookup, 0 runtime parsing).
  /// Falls back to dynamic parsing only if text was not indexed at compile time.
  List<TextSpanItem> parseText(String rawText) {
    if (rawText.isEmpty) {
      return [const TextSpanItem.text('')];
    }

    // 1. Static precomputed spans (zero CPU cost, deterministic on all devices)
    final staticSpans = StaticGlossarySpans.spansByText[rawText];
    if (staticSpans != null) {
      return _buildSpansFromStatic(rawText, staticSpans);
    }

    // 2. Dynamic parsing fallback
    return _dynamicParseText(rawText);
  }

  List<TextSpanItem> _buildSpansFromStatic(
      String rawText, List<StaticSpan> staticSpans) {
    if (staticSpans.isEmpty) {
      return [TextSpanItem.text(rawText)];
    }

    final result = <TextSpanItem>[];
    int current = 0;

    for (final span in staticSpans) {
      if (span.start > current) {
        result.add(TextSpanItem.text(rawText.substring(current, span.start)));
      }
      final term = _termsById[span.termId];
      final matchedText = rawText.substring(span.start, span.end);
      if (term != null) {
        result.add(TextSpanItem.term(matchedText, term));
      } else {
        result.add(TextSpanItem.text(matchedText));
      }
      current = span.end;
    }

    if (current < rawText.length) {
      result.add(TextSpanItem.text(rawText.substring(current)));
    }

    return result;
  }

  List<TextSpanItem> _dynamicParseText(String rawText) {
    if (_sortedAliases.isEmpty) {
      return [TextSpanItem.text(rawText)];
    }

    final lower = rawText.toLowerCase();
    final matches = <TermMatchSpan>[];

    // Search for all alias occurrences
    for (final alias in _sortedAliases) {
      int searchStart = 0;
      while (searchStart < lower.length) {
        final found = lower.indexOf(alias, searchStart);
        if (found == -1) break;

        final foundEnd = found + alias.length;

        // Verify word boundaries
        final isStartBoundary = (found == 0) || !_isWordChar(lower[found - 1]);
        final isEndBoundary =
            (foundEnd >= lower.length) || !_isWordChar(lower[foundEnd]);

        if (isStartBoundary && isEndBoundary) {
          // Check for collision with already matched longer spans
          final collides = matches.any((m) =>
              (found >= m.start && found < m.end) ||
              (foundEnd > m.start && foundEnd <= m.end));

          if (!collides) {
            matches.add(TermMatchSpan(
              start: found,
              end: foundEnd,
              matchedText: rawText.substring(found, foundEnd),
              term: _aliasMap[alias]!,
            ));
          }
        }

        searchStart = found + 1;
      }
    }

    if (matches.isEmpty) {
      return [TextSpanItem.text(rawText)];
    }

    // Sort matches by start position
    matches.sort((a, b) => a.start.compareTo(b.start));

    final result = <TextSpanItem>[];
    int current = 0;

    for (final match in matches) {
      if (match.start > current) {
        result.add(TextSpanItem.text(rawText.substring(current, match.start)));
      }
      result.add(TextSpanItem.term(match.matchedText, match.term));
      current = match.end;
    }

    if (current < rawText.length) {
      result.add(TextSpanItem.text(rawText.substring(current)));
    }

    return result;
  }

  static bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    // 0-9, a-z, A-Z, Russian Cyrillic (0x0400 to 0x04FF), and underscore/hyphen
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        (code >= 0x0400 && code <= 0x04FF);
  }
}

final glossaryServiceProvider = Provider<GlossaryService>((ref) {
  return GlossaryService(initialTerms: GlossaryData.allTerms);
});

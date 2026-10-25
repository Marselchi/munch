/// Utilities for string normalization, diacritic stripping, and tokenization.
abstract final class StringNormalizer {
  static final RegExp _punctuationRegex = RegExp(r'[^\p{L}\p{N}\s]+', unicode: true);
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  /// Normalizes a string for search and comparison:
  /// - converts to lowercase
  /// - folds common Russian diacritics (ё -> е, й is kept or handled)
  /// - folds accented Latin characters
  /// - strips non-alphanumeric punctuation
  /// - collapses multiple whitespace into single space
  static String normalize(String input) {
    if (input.isEmpty) return '';
    var text = input.toLowerCase();

    // Russian diacritic folding
    text = text.replaceAll('ё', 'е');

    // Basic Latin diacritic folding
    text = text
        .replaceAll(RegExp(r'[àáâãäåā]'), 'a')
        .replaceAll(RegExp(r'[èéêëē]'), 'e')
        .replaceAll(RegExp(r'[ìíîïī]'), 'i')
        .replaceAll(RegExp(r'[òóôõöō]'), 'o')
        .replaceAll(RegExp(r'[ùúûüū]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');

    // Remove punctuation
    text = text.replaceAll(_punctuationRegex, ' ');

    // Collapse whitespace
    return text.replaceAll(_multiSpaceRegex, ' ').trim();
  }

  /// Tokenizes normalized text into words with minimum length filter.
  static List<String> tokenize(String input, {int minLength = 1}) {
    final norm = normalize(input);
    if (norm.isEmpty) return const [];
    return norm
        .split(' ')
        .where((token) => token.length >= minLength)
        .toList(growable: false);
  }
}

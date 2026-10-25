import 'dart:math' as math;

/// Fast, banded Damerau-Levenshtein distance with early-exit.
/// Computes distance supporting insertions, deletions, substitutions, and adjacent transpositions.
abstract final class EditDistance {
  /// Returns the maximum allowed edit distance for a query of the given length:
  /// - len <= 3: 0 (exact/prefix only)
  /// - len <= 5: 1
  /// - len <= 8: 2
  /// - otherwise: 3
  static int maxAllowedDistance(int queryLength) {
    if (queryLength <= 3) return 0;
    if (queryLength <= 5) return 1;
    if (queryLength <= 8) return 2;
    return 3;
  }

  /// Calculates the Damerau-Levenshtein distance between [s1] and [s2].
  /// If [maxDistance] is provided and the distance is guaranteed to exceed it,
  /// returns [maxDistance] + 1 early.
  static int damerauLevenshtein(String s1, String s2, [int? maxDistance]) {
    if (s1 == s2) return 0;
    final len1 = s1.length;
    final len2 = s2.length;

    if (len1 == 0) return (maxDistance != null && len2 > maxDistance) ? maxDistance + 1 : len2;
    if (len2 == 0) return (maxDistance != null && len1 > maxDistance) ? maxDistance + 1 : len1;

    // Length difference lower bound
    final diff = (len1 - len2).abs();
    if (maxDistance != null && diff > maxDistance) {
      return maxDistance + 1;
    }

    // 2D matrix for full Damerau-Levenshtein calculation
    // d[i, j] represents distance between s1[0..i-1] and s2[0..j-1]
    final d = List.generate(
      len1 + 1,
      (_) => List<int>.filled(len2 + 1, 0),
      growable: false,
    );

    for (var i = 0; i <= len1; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= len1; i++) {
      var rowMin = d[i][0];
      final char1 = s1.codeUnitAt(i - 1);

      for (var j = 1; j <= len2; j++) {
        final char2 = s2.codeUnitAt(j - 1);
        final cost = (char1 == char2) ? 0 : 1;

        var dist = math.min(
          d[i - 1][j] + 1, // deletion
          math.min(
            d[i][j - 1] + 1, // insertion
            d[i - 1][j - 1] + cost, // substitution
          ),
        );

        // Transposition of adjacent characters
        if (i > 1 &&
            j > 1 &&
            char1 == s2.codeUnitAt(j - 2) &&
            s1.codeUnitAt(i - 2) == char2) {
          dist = math.min(dist, d[i - 2][j - 2] + 1);
        }

        d[i][j] = dist;
        if (dist < rowMin) rowMin = dist;
      }

      // Early exit if the minimum value in this row already exceeds maxDistance
      if (maxDistance != null && rowMin > maxDistance) {
        return maxDistance + 1;
      }
    }

    return d[len1][len2];
  }
}

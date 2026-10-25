import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/search_service.dart';

class TextSnippetRow extends StatelessWidget {
  final TextSearchResult result;
  final VoidCallback? onTap;

  const TextSnippetRow({
    super.key,
    required this.result,
    this.onTap,
  });

  List<TextSpan> _buildHighlightedSpans(
    String snippet,
    List<TextSnippetHighlight> highlights,
  ) {
    if (highlights.isEmpty) {
      return [TextSpan(text: snippet)];
    }

    final spans = <TextSpan>[];
    int current = 0;

    final sorted = List<TextSnippetHighlight>.from(highlights)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final h in sorted) {
      final start = h.start.clamp(0, snippet.length);
      final end = h.end.clamp(0, snippet.length);

      if (start > current) {
        spans.add(TextSpan(text: snippet.substring(current, start)));
      }

      if (end > start) {
        spans.add(TextSpan(
          text: snippet.substring(start, end),
          style: const TextStyle(
            color: AppColors.primaryGold,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x33FFB74D),
          ),
        ));
      }
      current = end;
    }

    if (current < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(current)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final spans = _buildHighlightedSpans(result.snippet, result.highlights);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.menu_book,
                  size: 16,
                  color: AppColors.secondaryAmber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.record.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                children: spans,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

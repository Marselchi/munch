import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/glossary_service.dart';
import '../../application/rules_controller.dart';
import '../../domain/rules_glossary.dart';
import 'term_detail_modal.dart';

class InteractiveRuleText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final bool fillWidth;

  const InteractiveRuleText({
    super.key,
    required this.text,
    this.style,
    this.fillWidth = true,
  });

  @override
  ConsumerState<InteractiveRuleText> createState() => _InteractiveRuleTextState();
}

class _InteractiveRuleTextState extends ConsumerState<InteractiveRuleText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _onTermTapped(BuildContext context, RuleTerm term) {
    final bundles = ref.read(rulesProvider).bundles;
    TermDetailModal.show(
      context: context,
      term: term,
      bundles: bundles,
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final glossaryService = ref.watch(glossaryServiceProvider);
    final spans = glossaryService.parseText(widget.text);

    final defaultStyle = widget.style ??
        const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textPrimary,
        );

    final textSpans = <InlineSpan>[];

    for (final item in spans) {
      if (item.isTerm && item.matchedTerm != null) {
        final term = item.matchedTerm!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _onTermTapped(context, term);
        _recognizers.add(recognizer);

        textSpans.add(
          TextSpan(
            text: item.text,
            style: defaultStyle.copyWith(
              color: const Color(0xFFFFD54F),
              fontWeight: FontWeight.bold,
              backgroundColor: const Color(0x33FFB300),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFFFFB300),
              decorationThickness: 1.8,
              decorationStyle: TextDecorationStyle.solid,
            ),
            recognizer: recognizer,
          ),
        );
      } else {
        textSpans.add(
          TextSpan(
            text: item.text,
            style: defaultStyle,
          ),
        );
      }
    }

    final richText = SelectableText.rich(
      TextSpan(children: textSpans),
    );

    if (widget.fillWidth) {
      return SizedBox(
        width: double.infinity,
        child: richText,
      );
    }

    return richText;
  }
}

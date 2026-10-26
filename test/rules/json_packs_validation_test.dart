import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/features/rules/data/bundle_validator.dart';
import 'package:munchkin_companion/features/rules/domain/rules_entities.dart';

void main() {
  group('Bundled rules packs JSON validation', () {
    final packPaths = [
      'assets/rules/v1/munchkin_core.json',
      'assets/rules/v1/munchkin_expansions.json',
      'assets/rules/v1/munchkin_spinoffs.json',
      'assets/rules/v1/munchkin_2_0.json',
    ];

    for (final path in packPaths) {
      test('validates $path against RulesBundle schema', () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist on disk');

        final content = file.readAsStringSync();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;

        final bundle = RulesBundle.fromJson(jsonMap);
        expect(() => BundleValidator.validate(bundle), returnsNormally);
        expect(bundle.contentId.isNotEmpty, isTrue);
        expect(bundle.sets.isNotEmpty, isTrue);
      });
    }
  });
}

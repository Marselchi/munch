import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/rules_entities.dart';
import 'bundle_validator.dart';

abstract final class BundleLoader {
  static const String bundledCorePath = 'assets/rules/v1/munchkin_core.json';
  static const String bundledExpansionsPath = 'assets/rules/v1/munchkin_expansions.json';
  static const String bundledSpinoffsPath = 'assets/rules/v1/munchkin_spinoffs.json';
  static const String bundledMunchkin2Path = 'assets/rules/v1/munchkin_2_0.json';

  static const List<String> allBundledPaths = [
    bundledCorePath,
    bundledExpansionsPath,
    bundledSpinoffsPath,
    bundledMunchkin2Path,
  ];

  /// Loads and validates a single pack by asset path.
  static Future<RulesBundle> loadPack(String assetPath) async {
    final rawJson = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final bundle = RulesBundle.fromJson(decoded);
    BundleValidator.validate(bundle);
    return bundle;
  }

  /// Loads and validates the default bundled core rules pack.
  static Future<RulesBundle> loadBundledCore() => loadPack(bundledCorePath);

  /// Loads and validates all bundled packs.
  static Future<List<RulesBundle>> loadAllBundled() async {
    final list = <RulesBundle>[];
    for (final path in allBundledPaths) {
      try {
        final bundle = await loadPack(path);
        list.add(bundle);
      } catch (_) {}
    }
    return list;
  }
}

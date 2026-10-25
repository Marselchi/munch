import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/rules_entities.dart';
import 'bundle_loader.dart';
import 'bundle_validator.dart';

class InstalledPackInfo {
  final String contentId;
  final String contentVersion;
  final String title;
  final int entityCount;
  final int ruleBlockCount;
  final bool isBundled;
  final String? filePath;

  const InstalledPackInfo({
    required this.contentId,
    required this.contentVersion,
    required this.title,
    required this.entityCount,
    required this.ruleBlockCount,
    required this.isBundled,
    this.filePath,
  });
}

class PackRegistry {
  static const String packsFolder = 'rules_packs';

  static Future<Directory> _getPacksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$packsFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all installed rules bundles (bundled + user-imported).
  static Future<List<RulesBundle>> loadAllBundles() async {
    final bundles = <RulesBundle>[];

    // 1. Bundled packs
    try {
      final bundledList = await BundleLoader.loadAllBundled();
      bundles.addAll(bundledList);
    } catch (_) {}

    // 2. User-imported packs from storage
    try {
      final dir = await _getPacksDir();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final bundle = RulesBundle.fromJson(decoded);
          BundleValidator.validate(bundle);

          // Replace existing with same contentId if user imported updated version
          bundles.removeWhere((b) => b.contentId == bundle.contentId);
          bundles.add(bundle);
        } catch (_) {
          // Skip invalid packs gracefully
        }
      }
    } catch (_) {}

    return bundles;
  }

  /// Returns metadata for all installed packs.
  static Future<List<InstalledPackInfo>> getInstalledPacksList() async {
    final list = <InstalledPackInfo>[];

    // Bundled packs
    try {
      final bundledList = await BundleLoader.loadAllBundled();
      for (final bundle in bundledList) {
        list.add(InstalledPackInfo(
          contentId: bundle.contentId,
          contentVersion: bundle.contentVersion,
          title: bundle.sets.isNotEmpty ? bundle.sets.first.title : bundle.contentId,
          entityCount: bundle.entities.length,
          ruleBlockCount: bundle.ruleBlocks.length,
          isBundled: true,
        ));
      }
    } catch (_) {}

    // Imported packs
    try {
      final dir = await _getPacksDir();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final bundle = RulesBundle.fromJson(decoded);
          list.add(InstalledPackInfo(
            contentId: bundle.contentId,
            contentVersion: bundle.contentVersion,
            title: bundle.sets.isNotEmpty ? bundle.sets.first.title : bundle.contentId,
            entityCount: bundle.entities.length,
            ruleBlockCount: bundle.ruleBlocks.length,
            isBundled: false,
            filePath: file.path,
          ));
        } catch (_) {}
      }
    } catch (_) {}

    return list;
  }

  /// Removes an imported pack by contentId.
  static Future<bool> removeImportedPack(String contentId) async {
    final dir = await _getPacksDir();
    final file = File('${dir.path}/$contentId.json');
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}

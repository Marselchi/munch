import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:munchkin_companion/core/errors/app_exception.dart';
import '../domain/rules_entities.dart';
import 'bundle_validator.dart';
import 'pack_registry.dart';

abstract final class RulesImporter {
  /// Validates and imports a rules pack JSON string.
  /// Overwrites any existing pack with the same contentId.
  static Future<RulesBundle> importPackJson(String jsonString) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const RulesPackException('Некорректный формат файла JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const RulesPackException('Корень JSON должен быть объектом.');
    }

    final bundle = RulesBundle.fromJson(decoded);
    BundleValidator.validate(bundle);

    // Save to storage
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${PackRegistry.packsFolder}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final targetFile = File('${dir.path}/${bundle.contentId}.json');
    await targetFile.writeAsString(jsonString);

    return bundle;
  }
}

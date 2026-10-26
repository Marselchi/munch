import 'package:munchkin_companion/core/errors/app_exception.dart';
import '../domain/rules_entities.dart';

abstract final class BundleValidator {
  static const int currentSchemaVersion = 1;

  /// Validates a decoded [RulesBundle].
  /// Throws [RulesPackException] if validation fails.
  static void validate(RulesBundle bundle) {
    if (bundle.schemaVersion > currentSchemaVersion) {
      throw RulesPackException(
        'Неподдерживаемая версия схемы пакета: v${bundle.schemaVersion}. '
        'Приложение поддерживает версии до v$currentSchemaVersion.',
      );
    }

    if (bundle.contentId.trim().isEmpty) {
      throw const RulesPackException('Пакет правил должен содержать идентификатор contentId.');
    }

    if (bundle.entities.isEmpty && bundle.ruleBlocks.isEmpty) {
      throw const RulesPackException('Пакет правил пуст (нет ни сущностей, ни блоков правил).');
    }

    final entityIds = <String>{};
    for (final entity in bundle.entities) {
      if (entity.id.trim().isEmpty) {
        throw const RulesPackException('Обнаружена сущность с пустым id.');
      }
      if (entity.title.trim().isEmpty) {
        throw RulesPackException('Сущность "${entity.id}" не имеет названия (title).');
      }
      if (!entityIds.add(entity.id)) {
        throw RulesPackException('Дублирующийся идентификатор сущности: "${entity.id}".');
      }
    }
  }
}

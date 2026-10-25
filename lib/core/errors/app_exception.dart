/// Base class for all application and sync domain exceptions.
library;
sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

final class ProtocolMismatchException extends AppException {
  final int clientVersion;
  final int hostVersion;

  const ProtocolMismatchException({
    required this.clientVersion,
    required this.hostVersion,
    String? message,
  }) : super(
          message ??
              'Версия протокола не совпадает (Клиент: v$clientVersion, Хост: v$hostVersion). '
              'Пожалуйста, используйте одинаковую версию приложения.',
          'PROTOCOL_MISMATCH',
        );
}

final class SessionEndedException extends AppException {
  const SessionEndedException([String? message])
      : super(message ?? 'Игровая сессия была завершена ведущим.', 'SESSION_ENDED');
}

final class NameTakenException extends AppException {
  const NameTakenException([String? message])
      : super(message ?? 'Имя игрока уже занято.', 'NAME_TAKEN');
}

final class ApprovalRequiredException extends AppException {
  const ApprovalRequiredException([String? message])
      : super(
          message ?? 'Ожидание подтверждения входа от ведущего стола.',
          'APPROVAL_REQUIRED',
        );
}

final class ConnectionException extends AppException {
  const ConnectionException(super.message, [super.code = 'CONNECTION_ERROR']);
}

final class ValidationException extends AppException {
  const ValidationException(super.message, [super.code = 'VALIDATION_ERROR']);
}

final class RulesPackException extends AppException {
  const RulesPackException(super.message, [super.code = 'RULES_PACK_ERROR']);
}

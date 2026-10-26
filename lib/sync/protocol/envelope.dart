import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

/// Top-level protocol envelope for all WebSocket messages.
class Envelope {
  final int v;
  final String type;
  final String id;
  final int ts;
  final String sid;
  final int epoch;
  final Map<String, dynamic> data;

  const Envelope({
    this.v = AppConstants.protocolVersion,
    required this.type,
    required this.id,
    required this.ts,
    required this.sid,
    this.epoch = 0,
    this.data = const {},
  });

  factory Envelope.create({
    required String type,
    required String sessionId,
    int epoch = 0,
    Map<String, dynamic> data = const {},
  }) {
    return Envelope(
      v: AppConstants.protocolVersion,
      type: type,
      id: const Uuid().v4(),
      ts: DateTime.now().millisecondsSinceEpoch,
      sid: sessionId,
      epoch: epoch,
      data: data,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': v,
        'type': type,
        'id': id,
        'ts': ts,
        'sid': sid,
        'epoch': epoch,
        'data': data,
      };

  String encode() => jsonEncode(toJson());

  factory Envelope.fromJson(Map<String, dynamic> json) {
    return Envelope(
      v: json['v'] as int? ?? 1,
      type: json['type'] as String,
      id: json['id'] as String,
      ts: json['ts'] as int,
      sid: json['sid'] as String? ?? '',
      epoch: json['epoch'] as int? ?? 0,
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  factory Envelope.decode(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return Envelope.fromJson(decoded);
  }
}

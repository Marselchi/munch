import 'models.dart';

// --- Client -> Host Messages ---

class JoinRequest {
  final String name;
  final int appVersion;

  const JoinRequest({required this.name, required this.appVersion});

  Map<String, dynamic> toJson() => {'name': name, 'appVersion': appVersion};

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
        name: json['name'] as String,
        appVersion: json['appVersion'] as int? ?? 1,
      );
}

class RejoinRequest {
  final String playerId;
  final String token;
  final int lastSeq;

  const RejoinRequest({
    required this.playerId,
    required this.token,
    required this.lastSeq,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'token': token,
        'lastSeq': lastSeq,
      };

  factory RejoinRequest.fromJson(Map<String, dynamic> json) => RejoinRequest(
        playerId: json['playerId'] as String,
        token: json['token'] as String,
        lastSeq: json['lastSeq'] as int? ?? 0,
      );
}

class LevelRequest {
  final String reqId;
  final int? delta;
  final int? setValue;
  final LevelReason reason;

  const LevelRequest({
    required this.reqId,
    this.delta,
    this.setValue,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'reqId': reqId,
        if (delta != null) 'delta': delta,
        if (setValue != null) 'setValue': setValue,
        'reason': reason.toJson(),
      };

  factory LevelRequest.fromJson(Map<String, dynamic> json) => LevelRequest(
        reqId: json['reqId'] as String,
        delta: json['delta'] as int?,
        setValue: json['setValue'] as int?,
        reason: LevelReason.fromJson(json['reason'] as Map<String, dynamic>),
      );
}

class GearUpdate {
  final int gearPower;

  const GearUpdate({required this.gearPower});

  Map<String, dynamic> toJson() => {'gearPower': gearPower};

  factory GearUpdate.fromJson(Map<String, dynamic> json) =>
      GearUpdate(gearPower: json['gearPower'] as int);
}

class TraitsUpdate {
  final List<String> traitIds;

  const TraitsUpdate({required this.traitIds});

  Map<String, dynamic> toJson() => {'traitIds': traitIds};

  factory TraitsUpdate.fromJson(Map<String, dynamic> json) => TraitsUpdate(
        traitIds: (json['traitIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

// --- Host -> Client Messages ---

class JoinAccept {
  final String playerId;
  final String token;
  final SessionSnapshot snapshot;

  const JoinAccept({
    required this.playerId,
    required this.token,
    required this.snapshot,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'token': token,
        'snapshot': snapshot.toJson(),
      };

  factory JoinAccept.fromJson(Map<String, dynamic> json) => JoinAccept(
        playerId: json['playerId'] as String,
        token: json['token'] as String,
        snapshot: SessionSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
      );
}

class JoinReject {
  final String code;
  final String message;

  const JoinReject({required this.code, required this.message});

  Map<String, dynamic> toJson() => {'code': code, 'message': message};

  factory JoinReject.fromJson(Map<String, dynamic> json) => JoinReject(
        code: json['code'] as String,
        message: json['message'] as String,
      );
}

class SyncSnapshotMsg {
  final SessionSnapshot snapshot;

  const SyncSnapshotMsg({required this.snapshot});

  Map<String, dynamic> toJson() => snapshot.toJson();

  factory SyncSnapshotMsg.fromJson(Map<String, dynamic> json) =>
      SyncSnapshotMsg(snapshot: SessionSnapshot.fromJson(json));
}

class SyncDeltaMsg {
  final List<SyncEvent> events;

  const SyncDeltaMsg({required this.events});

  Map<String, dynamic> toJson() => {
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory SyncDeltaMsg.fromJson(Map<String, dynamic> json) => SyncDeltaMsg(
        events: (json['events'] as List<dynamic>)
            .map((e) => SyncEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LevelRequestAck {
  final String reqId;

  const LevelRequestAck({required this.reqId});

  Map<String, dynamic> toJson() => {'reqId': reqId};

  factory LevelRequestAck.fromJson(Map<String, dynamic> json) =>
      LevelRequestAck(reqId: json['reqId'] as String);
}

class LevelRequestDenied {
  final String reqId;
  final String? message;

  const LevelRequestDenied({required this.reqId, this.message});

  Map<String, dynamic> toJson() => {
        'reqId': reqId,
        if (message != null) 'message': message,
      };

  factory LevelRequestDenied.fromJson(Map<String, dynamic> json) =>
      LevelRequestDenied(
        reqId: json['reqId'] as String,
        message: json['message'] as String?,
      );
}

/// Message types catalog
abstract final class MessageType {
  // Client -> Host
  static const String joinRequest = 'join.request';
  static const String rejoinRequest = 'rejoin.request';
  static const String levelRequest = 'level.request';
  static const String gearUpdate = 'gear.update';
  static const String traitsUpdate = 'traits.update';
  static const String heartbeatPing = 'heartbeat.ping';
  static const String leaveNotify = 'leave.notify';

  // Host -> Client
  static const String joinAccept = 'join.accept';
  static const String joinReject = 'join.reject';
  static const String syncSnapshot = 'sync.snapshot';
  static const String syncDelta = 'sync.delta';
  static const String levelApplied = 'level.applied';
  static const String levelUndone = 'level.undone';
  static const String levelRequestAck = 'level.request.ack';
  static const String levelRequestDenied = 'level.request.denied';
  static const String playerJoined = 'player.joined';
  static const String playerLeft = 'player.left';
  static const String playerUpdated = 'player.updated';
  static const String sessionUpdated = 'session.updated';
  static const String sessionEnded = 'session.ended';
  static const String heartbeatPong = 'heartbeat.pong';
}

/// Error codes for JoinReject
abstract final class RejectCode {
  static const String protocolMismatch = 'PROTOCOL_MISMATCH';
  static const String sessionEnded = 'SESSION_ENDED';
  static const String nameTaken = 'NAME_TAKEN';
  static const String approvalRequired = 'APPROVAL_REQUIRED';
  static const String invalidToken = 'INVALID_TOKEN';
  static const String unknown = 'UNKNOWN_ERROR';
}

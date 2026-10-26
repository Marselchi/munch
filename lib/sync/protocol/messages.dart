import 'models.dart';

// --- Client -> Host Messages ---

class JoinRequest {
  final String name;
  final int appVersion;
  final List<String> listenIps;
  final int? listenPort;

  const JoinRequest({
    required this.name,
    required this.appVersion,
    this.listenIps = const [],
    this.listenPort,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'appVersion': appVersion,
        if (listenIps.isNotEmpty) 'listenIps': listenIps,
        if (listenPort != null) 'listenPort': listenPort,
      };

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
        name: json['name'] as String,
        appVersion: json['appVersion'] as int? ?? 1,
        listenIps: (json['listenIps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        listenPort: json['listenPort'] as int?,
      );
}

class RosterUpdateMsg {
  final List<RosterEntry> roster;

  const RosterUpdateMsg({required this.roster});

  Map<String, dynamic> toJson() => {
        'roster': roster.map((r) => r.toJson()).toList(),
      };

  factory RosterUpdateMsg.fromJson(Map<String, dynamic> json) =>
      RosterUpdateMsg(
        roster: (json['roster'] as List<dynamic>?)
                ?.map((e) => RosterEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class HostTransferMsg {
  final int nextEpoch;
  final String targetPlayerId;
  final List<Seat> seats;

  const HostTransferMsg({
    required this.nextEpoch,
    required this.targetPlayerId,
    required this.seats,
  });

  Map<String, dynamic> toJson() => {
        'nextEpoch': nextEpoch,
        'targetPlayerId': targetPlayerId,
        'seats': seats.map((s) => s.toJson()).toList(),
      };

  factory HostTransferMsg.fromJson(Map<String, dynamic> json) =>
      HostTransferMsg(
        nextEpoch: json['nextEpoch'] as int? ?? 1,
        targetPlayerId: json['targetPlayerId'] as String,
        seats: (json['seats'] as List<dynamic>?)
                ?.map((s) => Seat.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class SyncPushRequest {
  final int hostSeq;

  const SyncPushRequest({required this.hostSeq});

  Map<String, dynamic> toJson() => {'hostSeq': hostSeq};

  factory SyncPushRequest.fromJson(Map<String, dynamic> json) =>
      SyncPushRequest(hostSeq: json['hostSeq'] as int? ?? 0);
}

class SyncPushMsg {
  final List<SyncEvent> events;

  const SyncPushMsg({required this.events});

  Map<String, dynamic> toJson() => {
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory SyncPushMsg.fromJson(Map<String, dynamic> json) => SyncPushMsg(
        events: (json['events'] as List<dynamic>?)
                ?.map((e) => SyncEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
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

class ClaimableSeat {
  final String playerId;
  final String name;
  final int level;
  final int gearPower;
  final bool isLocal;

  const ClaimableSeat({
    required this.playerId,
    required this.name,
    required this.level,
    required this.gearPower,
    this.isLocal = false,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'level': level,
        'gearPower': gearPower,
        'isLocal': isLocal,
      };

  factory ClaimableSeat.fromJson(Map<String, dynamic> json) => ClaimableSeat(
        playerId: json['playerId'] as String,
        name: json['name'] as String,
        level: json['level'] as int? ?? 1,
        gearPower: json['gearPower'] as int? ?? 0,
        isLocal: json['isLocal'] as bool? ?? false,
      );
}

class SeatsListResponse {
  final List<ClaimableSeat> seats;

  const SeatsListResponse({required this.seats});

  Map<String, dynamic> toJson() => {
        'seats': seats.map((s) => s.toJson()).toList(),
      };

  factory SeatsListResponse.fromJson(Map<String, dynamic> json) =>
      SeatsListResponse(
        seats: (json['seats'] as List<dynamic>?)
                ?.map((e) => ClaimableSeat.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class SeatClaimRequest {
  final String playerId;
  final String? newName;
  final List<String> listenIps;
  final int? listenPort;

  const SeatClaimRequest({
    required this.playerId,
    this.newName,
    this.listenIps = const [],
    this.listenPort,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        if (newName != null) 'newName': newName,
        if (listenIps.isNotEmpty) 'listenIps': listenIps,
        if (listenPort != null) 'listenPort': listenPort,
      };

  factory SeatClaimRequest.fromJson(Map<String, dynamic> json) =>
      SeatClaimRequest(
        playerId: json['playerId'] as String,
        newName: json['newName'] as String?,
        listenIps: (json['listenIps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        listenPort: json['listenPort'] as int?,
      );
}

class JoinReject {
  final String code;
  final String message;
  final List<ClaimableSeat> claimableSeats;

  const JoinReject({
    required this.code,
    required this.message,
    this.claimableSeats = const [],
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (claimableSeats.isNotEmpty)
          'claimableSeats': claimableSeats.map((s) => s.toJson()).toList(),
      };

  factory JoinReject.fromJson(Map<String, dynamic> json) => JoinReject(
        code: json['code'] as String,
        message: json['message'] as String,
        claimableSeats: (json['claimableSeats'] as List<dynamic>?)
                ?.map((e) => ClaimableSeat.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
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
  static const String seatsListRequest = 'seats.list.request';
  static const String seatClaimRequest = 'seat.claim.request';
  static const String levelRequest = 'level.request';
  static const String gearUpdate = 'gear.update';
  static const String traitsUpdate = 'traits.update';
  static const String heartbeatPing = 'heartbeat.ping';
  static const String leaveNotify = 'leave.notify';
  static const String syncPush = 'sync.push';

  // Host -> Client
  static const String joinAccept = 'join.accept';
  static const String joinReject = 'join.reject';
  static const String seatsListResponse = 'seats.list.response';
  static const String syncSnapshot = 'sync.snapshot';
  static const String syncDelta = 'sync.delta';
  static const String syncPushRequest = 'sync.push.request';
  static const String levelApplied = 'level.applied';
  static const String levelUndone = 'level.undone';
  static const String levelRequestAck = 'level.request.ack';
  static const String levelRequestDenied = 'level.request.denied';
  static const String playerJoined = 'player.joined';
  static const String playerLeft = 'player.left';
  static const String playerUpdated = 'player.updated';
  static const String sessionUpdated = 'session.updated';
  static const String sessionEnded = 'session.ended';
  static const String hostChanged = 'host.changed';
  static const String hostTransfer = 'host.transfer';
  static const String rosterUpdate = 'roster.update';
  static const String seatClaimed = 'seat.claimed';
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

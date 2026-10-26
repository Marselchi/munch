import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/features/host_session/presentation/widgets/pending_requests_card.dart';
import 'package:munchkin_companion/sync/node/host_role.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';

void main() {
  testWidgets('PendingRequestsCard renders request without timeout or countdown',
      (tester) async {
    final req = PendingLevelRequest(
      reqId: 'req-1',
      playerId: 'p-1',
      delta: 1,
      reason: const LevelReason.monsterKill(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingRequestsCard(
            requests: [req],
            getPlayerName: (id) => 'Манчкин Вася',
            onApprove: (_) {},
            onDeny: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Манчкин Вася'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    // Reason is displayed
    expect(find.text(req.reason.localizedTitle), findsOneWidget);
    // No remaining seconds or timer countdown
    expect(find.textContaining('осталось'), findsNothing);
    expect(find.textContaining('59 с'), findsNothing);
    expect(find.textContaining('59с'), findsNothing);
  });
}

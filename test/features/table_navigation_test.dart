import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/features/home/presentation/home_screen.dart';
import 'package:munchkin_companion/features/host_session/application/host_session_controller.dart';
import 'package:munchkin_companion/features/rules/domain/rules_entities.dart';
import 'package:munchkin_companion/features/rules/presentation/entity_detail_screen.dart';
import 'package:munchkin_companion/features/rules/presentation/widgets/rules_nav_actions.dart';
import 'package:munchkin_companion/sync/server/host_session_engine.dart';
import 'package:munchkin_companion/sync/server/ws_server.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import 'package:munchkin_companion/features/host_session/presentation/widgets/host_player_card.dart';

class MockHostSessionNotifier extends HostSessionNotifier {
  final HostSessionState? initialState;
  MockHostSessionNotifier(this.initialState);

  @override
  HostSessionState? build() => initialState;
}

void main() {
  group('Table Navigation Tests', () {
    testWidgets('RulesNavActions "Вернуться к столу" stops at /table route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home Root')),
            '/table': (_) => Builder(
                  builder: (ctx) => Scaffold(
                    body: Column(
                      children: [
                        const Text('Game Table Screen'),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => const Scaffold(
                                  appBar: PreferredSize(
                                    preferredSize: Size.fromHeight(56),
                                    child: RulesNavActions(),
                                  ),
                                  body: Text('Rules Page'),
                                ),
                              ),
                            );
                          },
                          child: const Text('Open Rules'),
                        ),
                      ],
                    ),
                  ),
                ),
          },
        ),
      );

      // Navigate to /table
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/table');
      await tester.pumpAndSettle();

      expect(find.text('Game Table Screen'), findsOneWidget);

      // Tap Open Rules
      await tester.tap(find.text('Open Rules'));
      await tester.pumpAndSettle();

      expect(find.text('Rules Page'), findsOneWidget);

      // Tap "Вернуться к столу"
      await tester.tap(find.byTooltip('Вернуться к столу'));
      await tester.pumpAndSettle();

      // Verify we returned to the Game Table, NOT the home root!
      expect(find.text('Game Table Screen'), findsOneWidget);
      expect(find.text('Home Root'), findsNothing);
    });

    testWidgets('EntityDetailScreen "К столу" stops at /table route', (tester) async {
      const mockEntity = RuleEntity(
        id: 'test_warrior',
        kind: 'class',
        title: 'Воин',
        setId: 'munchkin_core',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('Initial Root')),
        ),
      );

      // Push Table with name /table
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/table'),
          builder: (_) => Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const EntityDetailScreen(entity: mockEntity),
                    ),
                  );
                },
                child: const Text('Open Entity Detail'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Entity Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Воин'), findsAtLeastNWidgets(1));

      // Tap bottom bar button "К столу"
      await tester.tap(find.widgetWithText(ElevatedButton, 'К столу'));
      await tester.pumpAndSettle();

      expect(find.text('Open Entity Detail'), findsOneWidget);
      expect(find.text('Initial Root'), findsNothing);
    });

    testWidgets('HomeScreen displays active table banner when host session is active in-memory', (tester) async {
      final engine = HostSessionEngine(hostPlayerName: 'TestHost');
      final server = HostWebSocketServer(onClientConnected: (_) {});

      final mockState = HostSessionState(
        engine: engine,
        server: server,
        hostIps: ['127.0.0.1'],
        port: 8787,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostSessionProvider.overrideWith(() => MockHostSessionNotifier(mockState)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Активный стол (Ведущий)'), findsOneWidget);
      expect(find.text('Вернуться за стол'), findsOneWidget);
      expect(find.text('Завершить стол'), findsOneWidget);
      engine.dispose();
    });
    testWidgets('HostPlayerCard displays transfer host and kick options in player menu', (tester) async {
      bool transferCalled = false;
      bool kickCalled = false;

      const player = Player(id: 'p2', name: 'Вася', level: 2, gearPower: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostPlayerCard(
              player: player,
              isHostPlayer: false,
              maxLevel: 10,
              onApplyLevelChange: ({delta, setValue, required reason}) {},
              onUpdateGear: (_) {},
              onTransferHost: () => transferCalled = true,
              onKickPlayer: () => kickCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open more options menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Expect options: transfer and kick
      expect(find.text('Сделать "Вася" ведущим стола'), findsOneWidget);
      expect(find.text('Исключить игрока "Вася"'), findsOneWidget);

      // Tap transfer
      await tester.tap(find.text('Сделать "Вася" ведущим стола'));
      await tester.pumpAndSettle();

      expect(transferCalled, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/core/widgets/traits_picker_sheet.dart';
import 'package:munchkin_companion/features/player_session/presentation/widgets/trait_tooltip_chip.dart';
import 'package:munchkin_companion/features/rules/application/rules_controller.dart';
import 'package:munchkin_companion/features/rules/domain/rules_entities.dart';

void main() {
  testWidgets('TraitTooltipChip shows info icon and epic icon, and modal does not overflow', (tester) async {
    const warrior = RuleEntity(
      id: 'core.class.warrior',
      kind: 'class',
      title: 'Воин (Warrior)',
      aliases: ['воин', 'warrior'],
      setId: 'core',
      ruleSections: [
        RuleSection(
          heading: 'Буйство (Berserking)',
          text: 'В бою ты можешь сбросить до 3 карт. Каждая карта дает +1 к боевой силе.',
        ),
        RuleSection(
          heading: 'Победа при ничьей',
          text: 'Если твоя боевая сила равна силе монстра, победа остается за тобой.',
        ),
      ],
      epic: EpicProperties(
        ruleSections: [
          RuleSection(
            heading: 'Эпический воин (Epic Warrior)',
            text: 'Шмотки в 2 руки занимают у тебя всего одну руку. Ты можешь нести две Большие шмотки одновременно.',
          ),
        ],
      ),
    );

    // Set a compact screen size to test overflow resilience
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allRuleEntitiesProvider.overrideWithValue([warrior]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TraitTooltipChip(traitName: 'Воин (Warrior)'),
            ),
          ),
        ),
      ),
    );

    // 1. Verify (!) info icon is present
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    // 2. Verify Epic auto_awesome icon is present alongside
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    // 3. Tap chip to open bottom sheet
    await tester.tap(find.byType(TraitTooltipChip));
    await tester.pumpAndSettle();

    // 4. Verify bottom sheet contents
    expect(find.text('Воин (Warrior)'), findsNWidgets(2)); // chip and modal title
    expect(find.text('Буйство (Berserking)'), findsOneWidget);
    expect(find.text('Эпические правила (Ур. 10–22)'), findsOneWidget);
    expect(find.text('Эпический воин (Epic Warrior)'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
    expect(find.text('К описанию'), findsOneWidget);

    // 5. Verify NO overflow exception occurred
    expect(tester.takeException(), isNull);
  });

  testWidgets('TraitsPickerSheet strictly includes traits and excludes steeds/dungeons/hirelings', (tester) async {
    final entities = [
      const RuleEntity(
        id: 'core.class.warrior',
        kind: 'class',
        title: 'Воин',
        aliases: [],
        setId: 'core',
        ruleSections: [],
      ),
      const RuleEntity(
        id: 'core.race.elf',
        kind: 'race',
        title: 'Эльф',
        aliases: [],
        setId: 'core',
        ruleSections: [],
      ),
      const RuleEntity(
        id: 'exp8.enhancer.elder',
        kind: 'enhancer',
        title: 'Старший',
        aliases: [],
        setId: 'exp8',
        ruleSections: [],
      ),
      const RuleEntity(
        id: 'exp4.steed.chicken',
        kind: 'steed',
        title: 'Цыплёнок',
        aliases: [],
        setId: 'exp4',
        ruleSections: [],
      ),
      const RuleEntity(
        id: 'exp4.hireling.elf',
        kind: 'hireling',
        title: 'Эльф-наёмничек',
        aliases: [],
        setId: 'exp4',
        ruleSections: [],
      ),
      const RuleEntity(
        id: 'fake.dungeon',
        kind: 'dungeon',
        title: 'Подземелье Ужаса',
        aliases: [],
        setId: 'fake',
        ruleSections: [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TraitsPickerSheet(
            playerName: 'Тестер',
            allEntities: entities,
            initialSelected: const [],
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should contain character traits (Class: Воин, Race: Эльф, Enhancer: Старший)
    expect(find.text('Воин'), findsOneWidget);
    expect(find.text('Эльф'), findsOneWidget);
    expect(find.text('Старший'), findsOneWidget);

    // Should NOT contain Steeds, Hirelings, or Dungeons
    expect(find.text('Цыплёнок'), findsNothing);
    expect(find.text('Эльф-наёмничек'), findsNothing);
    expect(find.text('Подземелье Ужаса'), findsNothing);
  });

  testWidgets('TraitsPickerSheet renders many active traits in horizontal scroll without overflow', (tester) async {
    final entities = [
      const RuleEntity(
        id: 'core.class.warrior',
        kind: 'class',
        title: 'Воин',
        aliases: [],
        setId: 'core',
        ruleSections: [],
      ),
    ];

    final manySelected = [
      'Воин',
      'Эльф',
      'Дварф',
      'Хафлинг',
      'Старший',
      'Элитный',
      'Легендарный',
      'Волшебник',
      'Клирик',
      'Вор',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TraitsPickerSheet(
            playerName: 'Тестер',
            allEntities: entities,
            initialSelected: manySelected,
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify no exception / overflow occurred
    expect(tester.takeException(), isNull);

    // Verify horizontal ListView exists for selected traits
    final listViews = tester.widgetList<ListView>(find.byType(ListView));
    final hasHorizontal = listViews.any((lv) => lv.scrollDirection == Axis.horizontal);
    expect(hasHorizontal, isTrue);
  });
}

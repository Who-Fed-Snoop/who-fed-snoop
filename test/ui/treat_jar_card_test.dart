import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/core/app_theme.dart';
import 'package:who_fed_snoop/ui/features/treats/views/treat_jar_card.dart';

void main() {
  group('TreatJarCard & CustomTreatSheet', () {
    testWidgets(
      '1-tap preset chips log treats, over-limit Chonk Alert stays non-blocking, and drawer deletes treats',
      (WidgetTester tester) async {
        final loggedPresets = <TreatPreset>[];
        final deletedIds = <String>[];
        var settingsTapped = false;

        final initialTreats = <TreatEvent>[
          TreatEvent(
            id: 't_1',
            preset: TreatPreset.peanutButterKong,
            label: 'PB Kong',
            emoji: '🥜',
            quantity: 2,
            caloriesPerUnit: 120,
            logicalDate: '2026-11-08',
            givenByUid: 'uid_ashley',
            givenByName: 'Ashley',
            givenAt: DateTime(2026, 11, 8, 14, 15),
            note: 'Frozen kong',
          ),
          TreatEvent(
            id: 't_2',
            preset: TreatPreset.dentalChew,
            label: 'Dental Chew',
            emoji: '🪥',
            quantity: 3,
            caloriesPerUnit: 85,
            logicalDate: '2026-11-08',
            givenByUid: 'uid_keni',
            givenByName: 'Keni',
            givenAt: DateTime(2026, 11, 8, 16, 30),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TreatJarCard(
                  petName: 'Snoop',
                  todayTreats: initialTreats,
                  dailyTreatLimit: 4,
                  currentMemberUid: 'uid_keni',
                  onLogPreset: loggedPresets.add,
                  onLogCustomTreat: ({
                    required label,
                    required quantity,
                    required caloriesPerUnit,
                    note,
                  }) async {},
                  onDeleteTreat: deletedIds.add,
                  onOpenSettings: () => settingsTapped = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 2 + 3 = 5 treats > 4 limit -> Chonk Alert soft warning shown!
        expect(find.byKey(TreatJarCard.overLimitBannerKey), findsOneWidget);
        expect(find.textContaining('CHONK ALERT!'), findsOneWidget);
        expect(find.textContaining('+1 over the 4-treat daily goal'), findsOneWidget);

        // Tapping allowance pill opens settings callback
        await tester.tap(find.byKey(TreatJarCard.allowancePillKey));
        await tester.pump();
        expect(settingsTapped, isTrue);

        // Even while over limit, 1-tap preset chips remain enabled & log truthfully
        await tester.tap(
          find.byKey(TreatJarCard.presetChipKey(TreatPreset.trainingTreat)),
        );
        await tester.tap(
          find.byKey(TreatJarCard.presetChipKey(TreatPreset.crunchyBiscuit)),
        );
        expect(
          loggedPresets,
          equals(<TreatPreset>[
            TreatPreset.trainingTreat,
            TreatPreset.crunchyBiscuit,
          ]),
        );

        // Collapsed drawer shows latest treat (Dental Chew at 4:30 PM)
        expect(find.textContaining('Latest: 🪥 Dental Chew'), findsOneWidget);

        // Expand drawer and delete partner's treat ('t_1')
        await tester.tap(find.byKey(TreatJarCard.drawerToggleKey));
        await tester.pumpAndSettle();

        expect(find.textContaining('Frozen kong'), findsOneWidget);
        await tester.tap(find.byKey(TreatJarCard.deleteTreatButtonKey('t_1')));
        await tester.pump();
        expect(deletedIds, equals(<String>['t_1']));
      },
    );

    testWidgets(
      'CustomTreatSheet validates inputs and guards against double-tap submission',
      (WidgetTester tester) async {
        final submitCompleter = Completer<void>();
        var submitCount = 0;
        String? submittedLabel;
        int? submittedQty;
        int? submittedCalories;
        String? submittedNote;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TreatJarCard(
                petName: 'Snoop',
                todayTreats: const <TreatEvent>[],
                dailyTreatLimit: 4,
                currentMemberUid: 'uid_keni',
                onLogPreset: (_) {},
                onLogCustomTreat: ({
                  required label,
                  required quantity,
                  required caloriesPerUnit,
                  note,
                }) {
                  submitCount += 1;
                  submittedLabel = label;
                  submittedQty = quantity;
                  submittedCalories = caloriesPerUnit;
                  submittedNote = note;
                  return submitCompleter.future;
                },
                onDeleteTreat: (_) {},
              ),
            ),
          ),
        );

        // Open CustomTreatSheet
        await tester.tap(find.byKey(TreatJarCard.customTreatButtonKey));
        await tester.pumpAndSettle();
        expect(find.byType(CustomTreatSheet), findsOneWidget);

        // Submitting empty label shows validation message without calling onSubmit
        final submitFinder = find.byKey(CustomTreatSheet.submitButtonKey);
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pump();
        expect(find.textContaining('Enter a treat name'), findsOneWidget);
        expect(submitCount, equals(0));

        // Fill custom label, increment qty to 3x, set 55 kcal, add note
        await tester.enterText(
          find.byKey(CustomTreatSheet.labelFieldKey),
          'Cheese Cube',
        );
        await tester.tap(find.byKey(CustomTreatSheet.incrementQtyKey));
        await tester.tap(find.byKey(CustomTreatSheet.incrementQtyKey));
        await tester.enterText(
          find.byKey(CustomTreatSheet.caloriesFieldKey),
          '55',
        );
        await tester.enterText(
          find.byKey(CustomTreatSheet.noteFieldKey),
          'Loose-leash walk reward',
        );
        await tester.pump();

        // Rapid double-tap while async save is in flight
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pump();
        await tester.tap(submitFinder, warnIfMissed: false);
        await tester.pump();

        expect(submitCount, equals(1));
        expect(submittedLabel, equals('Cheese Cube'));
        expect(submittedQty, equals(3));
        expect(submittedCalories, equals(55));
        expect(submittedNote, equals('Loose-leash walk reward'));

        // Complete future -> sheet pops cleanly once with zero navigator errors
        submitCompleter.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CustomTreatSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive layout check: TreatJarCard renders zero RenderFlex overflows across 360x800 and 412x915 viewports',
      (WidgetTester tester) async {
        const sizes = <Size>[Size(360, 800), Size(412, 915)];

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final sampleTreats = <TreatEvent>[
          TreatEvent(
            id: 'tr_a',
            preset: TreatPreset.peanutButterKong,
            label: 'Extra Large Peanut Butter Kong',
            emoji: '🥜',
            quantity: 3,
            caloriesPerUnit: 120,
            logicalDate: '2026-11-08',
            givenByUid: 'uid_ashley',
            givenByName: 'Ashley',
            givenAt: DateTime(2026, 11, 8, 15, 0),
            note: 'Kept Snoop busy during Zoom meeting',
          ),
          TreatEvent(
            id: 'tr_b',
            preset: TreatPreset.dentalChew,
            label: 'Dental Chew',
            emoji: '🪥',
            quantity: 2,
            caloriesPerUnit: 85,
            logicalDate: '2026-11-08',
            givenByUid: 'uid_keni',
            givenByName: 'Keni',
            givenAt: DateTime(2026, 11, 8, 19, 10),
          ),
        ];

        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey<String>('treat_jar_${size.width}x${size.height}'),
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    TreatJarCard(
                      petName: 'Snoop',
                      todayTreats: sampleTreats,
                      dailyTreatLimit: 4,
                      currentMemberUid: 'uid_keni',
                      isCompact: size.height < 680,
                      onLogPreset: (_) {},
                      onLogCustomTreat: ({
                        required label,
                        required quantity,
                        required caloriesPerUnit,
                        note,
                      }) async {},
                      onDeleteTreat: (_) {},
                      onOpenSettings: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Expand Today's Treats drawer at this viewport width
          await tester.tap(find.byKey(TreatJarCard.drawerToggleKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}

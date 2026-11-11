import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/core/app_theme.dart';
import 'package:who_fed_snoop/ui/features/settings/views/household_settings_sheet.dart';
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
  });

  group('HouseholdSettingsSheet', () {
    testWidgets(
      'supports adding/editing/toggling windows, logged-today notice, validation, and double-tap save guard',
      (WidgetTester tester) async {
        final saveCompleter = Completer<bool>();
        var saveCalls = 0;
        MealSchedule? savedSchedule;
        int? savedTreatLimit;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () {
                      showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => HouseholdSettingsSheet(
                          petName: 'Snoop',
                          initialSchedule: const MealSchedule(),
                          initialDailyTreatLimit: 4,
                          todayLoggedWindowIds: const <String>{'breakfast'},
                          onSave: (schedule, treatLimit) {
                            saveCalls += 1;
                            savedSchedule = schedule;
                            savedTreatLimit = treatLimit;
                            return saveCompleter.future;
                          },
                        ),
                      );
                    },
                    child: const Text('Open Settings'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();
        expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsOneWidget);
        expect(find.byKey(HouseholdSettingsSheet.cyclePreviewKey), findsOneWidget);
        expect(find.text('FED TODAY'), findsOneWidget);

        // Disabling BOTH Breakfast & Dinner triggers logged-today notice AND validation error
        final initialBreakfastToggle =
            find.byKey(HouseholdSettingsSheet.windowToggleKey('breakfast'));
        await tester.ensureVisible(initialBreakfastToggle);
        await tester.tap(initialBreakfastToggle);
        await tester.pump();
        expect(
          find.byKey(HouseholdSettingsSheet.loggedTodayNoticeKey),
          findsOneWidget,
        );

        final initialDinnerToggle =
            find.byKey(HouseholdSettingsSheet.windowToggleKey('dinner'));
        await tester.ensureVisible(initialDinnerToggle);
        await tester.tap(initialDinnerToggle);
        await tester.pump();
        expect(
          find.byKey(HouseholdSettingsSheet.validationErrorKey),
          findsOneWidget,
        );

        // Save is blocked while invalid
        final saveBtn = find.byKey(HouseholdSettingsSheet.saveButtonKey);
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pump();
        expect(saveCalls, equals(0));

        // Re-enable Breakfast & Dinner, add Lunch preset + 1 Custom Window
        final breakfastSwitch =
            find.byKey(HouseholdSettingsSheet.windowToggleKey('breakfast'));
        await tester.ensureVisible(breakfastSwitch);
        await tester.tap(breakfastSwitch);
        await tester.pump();

        final dinnerSwitch =
            find.byKey(HouseholdSettingsSheet.windowToggleKey('dinner'));
        await tester.ensureVisible(dinnerSwitch);
        await tester.tap(dinnerSwitch);
        await tester.pump();

        final addLunchChip = find.byKey(
          HouseholdSettingsSheet.presetAddChipKey(MealPeriod.lunch),
        );
        await tester.ensureVisible(addLunchChip);
        await tester.tap(addLunchChip);
        await tester.pump();

        final addCustomChip =
            find.byKey(HouseholdSettingsSheet.addCustomWindowButtonKey);
        await tester.ensureVisible(addCustomChip);
        await tester.tap(addCustomChip);
        await tester.pump();

        // Customize Lunch label via edit dialog
        final editLunchBtn =
            find.byKey(HouseholdSettingsSheet.windowEditButtonKey('lunch'));
        await tester.ensureVisible(editLunchBtn);
        await tester.tap(editLunchBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(HouseholdSettingsSheet.editDialogLabelFieldKey),
          'Midday Kibble',
        );
        await tester.tap(
          find.byKey(HouseholdSettingsSheet.editDialogApplyButtonKey),
        );
        await tester.pumpAndSettle();
        expect(find.text('Midday Kibble'), findsOneWidget);

        // Open 1-tap showTimePicker for Breakfast and confirm cleanly
        final breakfastTimeBtn =
            find.byKey(HouseholdSettingsSheet.windowTimeButtonKey('breakfast'));
        await tester.ensureVisible(breakfastTimeBtn);
        await tester.tap(breakfastTimeBtn);
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Increment daily treat limit from 4 -> 5
        final incTreatBtn =
            find.byKey(HouseholdSettingsSheet.treatLimitIncrementKey);
        await tester.ensureVisible(incTreatBtn);
        await tester.tap(incTreatBtn);
        await tester.pump();
        expect(find.text('5 / day'), findsOneWidget);

        // Rapid double-tap Save -> fires once, pops once when complete
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pump();
        await tester.tap(saveBtn, warnIfMissed: false);
        await tester.pump();

        expect(saveCalls, equals(1));
        expect(savedTreatLimit, equals(5));
        expect(savedSchedule?.allWindows.length, equals(4));

        saveCompleter.complete(true);
        await tester.pumpAndSettle();
        expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'Responsive layout check: zero RenderFlex overflows across 360x800 and 412x915 viewports',
    (WidgetTester tester) async {
      const sizes = <Size>[Size(360, 800), Size(412, 915)];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sixWindowSchedule = MealSchedule.fromWindows(const <MealWindowConfig>[
        MealWindowConfig(
          id: 'breakfast',
          period: MealPeriod.breakfast,
          label: 'Early Breakfast',
          emoji: '🥣',
          startHour: 6,
        ),
        MealWindowConfig(
          id: 'second_breakfast',
          period: MealPeriod.custom,
          label: 'Second Breakfast',
          emoji: '🦴',
          startHour: 9,
          startMinute: 30,
        ),
        MealWindowConfig(
          id: 'lunch',
          period: MealPeriod.lunch,
          label: 'Midday Bowl',
          emoji: '🍲',
          startHour: 12,
          startMinute: 30,
        ),
        MealWindowConfig(
          id: 'afternoon_snack',
          period: MealPeriod.custom,
          label: 'Afternoon Kibble',
          emoji: '🐾',
          startHour: 15,
          startMinute: 30,
        ),
        MealWindowConfig(
          id: 'dinner',
          period: MealPeriod.dinner,
          label: 'Evening Dinner',
          emoji: '🍖',
          startHour: 18,
          startMinute: 30,
        ),
        MealWindowConfig(
          id: 'lateSnack',
          period: MealPeriod.lateSnack,
          label: 'Bedtime Snack',
          emoji: '🌙',
          startHour: 21,
          startMinute: 30,
          enabled: false,
        ),
      ]);

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

        // Render 6-window HouseholdSettingsSheet with logged-today notice at this viewport width
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<String>('settings_${size.width}x${size.height}'),
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: HouseholdSettingsSheet(
                  petName: 'Snoop',
                  initialSchedule: sixWindowSchedule,
                  initialDailyTreatLimit: 4,
                  todayLoggedWindowIds: const <String>{
                    'breakfast',
                    'lateSnack',
                  },
                  onSave: (_, __) async => true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/ui/core/app_theme.dart';
import 'package:who_fed_snoop/ui/features/settings/views/household_settings_sheet.dart';

void main() {
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

        final initialDinnerToggle = find.byKey(HouseholdSettingsSheet.windowToggleKey('dinner'));
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
        final breakfastSwitch = find.byKey(HouseholdSettingsSheet.windowToggleKey('breakfast'));
        await tester.ensureVisible(breakfastSwitch);
        await tester.tap(breakfastSwitch);
        await tester.pump();

        final dinnerSwitch = find.byKey(HouseholdSettingsSheet.windowToggleKey('dinner'));
        await tester.ensureVisible(dinnerSwitch);
        await tester.tap(dinnerSwitch);
        await tester.pump();

        final addLunchChip = find.byKey(
          HouseholdSettingsSheet.presetAddChipKey(MealPeriod.lunch),
        );
        await tester.ensureVisible(addLunchChip);
        await tester.tap(addLunchChip);
        await tester.pump();

        final addCustomChip = find.byKey(HouseholdSettingsSheet.addCustomWindowButtonKey);
        await tester.ensureVisible(addCustomChip);
        await tester.tap(addCustomChip);
        await tester.pump();

        // Customize Lunch label via edit dialog
        final editLunchBtn = find.byKey(HouseholdSettingsSheet.windowEditButtonKey('lunch'));
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
        final incTreatBtn = find.byKey(HouseholdSettingsSheet.treatLimitIncrementKey);
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

    testWidgets(
      'Responsive layout check: 6-window HouseholdSettingsSheet renders zero RenderFlex overflows across 360x800 and 412x915 viewports',
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

        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

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

    testWidgets(
      'HouseholdSettingsSheet displays exact thrown error inline and locks controls while saving',
      (WidgetTester tester) async {
        final saveCompleter = Completer<bool>();
        var shouldThrow = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HouseholdSettingsSheet(
                petName: 'Snoop',
                initialSchedule: const MealSchedule(),
                initialDailyTreatLimit: 4,
                onSave: (_, __) async {
                  if (shouldThrow) {
                    throw StateError('[cloud_firestore/permission-denied] denied');
                  }
                  return saveCompleter.future;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(HouseholdSettingsSheet.saveButtonKey);
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Sheet stays open and shows formatted permission-denied error inline
        expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsOneWidget);
        expect(find.byKey(HouseholdSettingsSheet.validationErrorKey), findsOneWidget);
        expect(find.textContaining('Permission denied'), findsOneWidget);

        // Retry with pending future -> controls locked by AbsorbPointer during save
        shouldThrow = false;
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pump();
        expect(find.text('Saving Schedule...'), findsOneWidget);

        final incBtn = find.byKey(HouseholdSettingsSheet.treatLimitIncrementKey);
        await tester.ensureVisible(incBtn);
        await tester.tap(incBtn, warnIfMissed: false);
        await tester.pump();
        expect(find.text('4 / day'), findsOneWidget);

        saveCompleter.complete(true);
        await tester.pumpAndSettle();
      },
    );
  });
}

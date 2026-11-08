import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/domain/models/deep_link_route.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';

void main() {
  group('ActiveMealWindow', () {
    test('returns Breakfast window between 4:00 AM and 1:59 PM', () {
      final morning = DateTime(2026, 11, 8, 8, 15);
      final window = ActiveMealWindow.forTime(morning);

      expect(window.period, equals(MealPeriod.breakfast));
      expect(window.windowDate, equals('2026-11-08'));
      expect(window.deterministicId, equals('2026-11-08_breakfast'));
      expect(window.nextTransitionTime, equals(DateTime(2026, 11, 8, 14, 0)));
    });

    test('transitions automatically to Dinner at 2:00 PM (14:00)', () {
      final afternoon = DateTime(2026, 11, 8, 14, 0);
      final window = ActiveMealWindow.forTime(afternoon);

      expect(window.period, equals(MealPeriod.dinner));
      expect(window.windowDate, equals('2026-11-08'));
      expect(window.deterministicId, equals('2026-11-08_dinner'));
      expect(window.nextTransitionTime, equals(DateTime(2026, 11, 9, 4, 0)));
    });

    test('keeps previous evening Dinner window active between midnight and 3:59 AM', () {
      final lateNight = DateTime(2026, 11, 9, 1, 30);
      final window = ActiveMealWindow.forTime(lateNight);

      expect(window.period, equals(MealPeriod.dinner));
      expect(window.windowDate, equals('2026-11-08'));
      expect(window.deterministicId, equals('2026-11-08_dinner'));
      expect(window.nextTransitionTime, equals(DateTime(2026, 11, 9, 4, 0)));
    });
  });

  group('WhofedsnoopDeepLink (whofedsnoop.com)', () {
    test('parses partner invite link /join/SNOOP4', () {
      final uri = Uri.parse('https://whofedsnoop.com/join/snoop4');
      final parsed = WhofedsnoopDeepLink.tryParse(uri);

      expect(parsed, isNotNull);
      expect(parsed!.kind, equals(DeepLinkKind.joinHousehold));
      expect(parsed.targetId, equals('SNOOP4'));
    });

    test('parses NFC food-bin sticker link /tap/household_snoop_01', () {
      final uri = Uri.parse('https://www.whofedsnoop.com/tap/household_snoop_01');
      final parsed = WhofedsnoopDeepLink.tryParse(uri);

      expect(parsed, isNotNull);
      expect(parsed!.kind, equals(DeepLinkKind.nfcTapToFeed));
      expect(parsed.targetId, equals('household_snoop_01'));
    });

    test('parses dog sitter web pass /s/sitter_xyz', () {
      final uri = Uri.parse('https://whofedsnoop.com/s/sitter_xyz');
      final parsed = WhofedsnoopDeepLink.tryParse(uri);

      expect(parsed, isNotNull);
      expect(parsed!.kind, equals(DeepLinkKind.sitterGuestPass));
      expect(parsed.targetId, equals('sitter_xyz'));
    });
  });
}


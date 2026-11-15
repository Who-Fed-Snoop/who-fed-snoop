import 'package:flutter/material.dart';

import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';

/// Formats `minutesOfDay` (`0..1439`) into a 12-hour clock label like `8:00 AM`.
String formatMinutesOfDay(int minutesOfDay) {
  final normalized = ((minutesOfDay % 1440) + 1440) % 1440;
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minuteStr = minute.toString().padLeft(2, '0');
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour12:$minuteStr $suffix';
}

/// Live 24-hour cycle and midnight wrap-around summary card for enabled meal windows.
class CyclePreviewCard extends StatelessWidget {
  const CyclePreviewCard({super.key, required this.enabledWindows});

  final List<MealWindowConfig> enabledWindows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.snoopCoatBlack,
        borderColor: AppTheme.snoopCollarGold,
        borderRadius: 18,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '🔄 LIVE 24-HOUR CYCLE PREVIEW',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppTheme.snoopCollarGold,
            ),
          ),
          const SizedBox(height: 6),
          if (enabledWindows.isEmpty)
            const Text(
              '⚠️ Enable at least 1 meal window to activate schedule.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
          else ...<Widget>[
            for (var i = 0; i < enabledWindows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  _describeWindowSpan(i),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              enabledWindows.first.startMinutesOfDay > 0
                  ? '🌙 Before ${formatMinutesOfDay(enabledWindows.first.startMinutesOfDay)}, '
                      'late-night checks & treats wrap to the previous evening\'s '
                      '${enabledWindows.last.label} date.'
                  : '🌙 Day rolls over right at 12:00 AM.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _describeWindowSpan(int index) {
    final current = enabledWindows[index];
    final next = enabledWindows[(index + 1) % enabledWindows.length];
    final startStr = formatMinutesOfDay(current.startMinutesOfDay);
    if (enabledWindows.length == 1) {
      return '${current.emoji} ${current.label}: $startStr – $startStr (24h)';
    }
    final endMinute = (next.startMinutesOfDay - 1 + 1440) % 1440;
    final endStr = formatMinutesOfDay(endMinute);
    final wraps = index == enabledWindows.length - 1 && next.startMinutesOfDay > 0;
    final wrapTag = wraps ? ' (next morning)' : '';
    return '${current.emoji} ${current.label}: $startStr – $endStr$wrapTag';
  }
}

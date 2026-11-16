import 'package:flutter/material.dart';

import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
import 'cycle_preview_card.dart';

/// Section rendering the 1–6 meal window config cards and preset/custom add chips.
class MealWindowsSection extends StatelessWidget {
  const MealWindowsSection({
    super.key,
    required this.windows,
    required this.todayLoggedWindowIds,
    required this.onToggleWindow,
    required this.onPickWindowTime,
    required this.onEditWindowMetadata,
    required this.onDeleteWindow,
    required this.onAddPresetWindow,
    required this.onAddCustomWindow,
  });

  final List<MealWindowConfig> windows;
  final Set<String> todayLoggedWindowIds;
  final void Function(String id, bool enabled) onToggleWindow;
  final ValueChanged<MealWindowConfig> onPickWindowTime;
  final ValueChanged<MealWindowConfig> onEditWindowMetadata;
  final ValueChanged<String> onDeleteWindow;
  final ValueChanged<MealPeriod> onAddPresetWindow;
  final VoidCallback onAddCustomWindow;

  static const Key addCustomWindowButtonKey = ValueKey<String>(
    'schedule_add_custom_window',
  );

  static ValueKey<String> presetAddChipKey(MealPeriod period) =>
      ValueKey<String>('schedule_add_preset_${period.name}');

  static const List<MealPeriod> _standardPresets = <MealPeriod>[
    MealPeriod.breakfast,
    MealPeriod.lunch,
    MealPeriod.dinner,
    MealPeriod.lateSnack,
  ];

  @override
  Widget build(BuildContext context) {
    final existingIds = windows.map((w) => w.id).toSet();
    final missingPresets = _standardPresets.where((p) => !existingIds.contains(p.name)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Expanded(
              child: Text(
                'MEAL WINDOWS (1–6 DAILY SLOTS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: AppTheme.inkDark,
                ),
              ),
            ),
            Text(
              '${windows.length}/${MealSchedule.maxWindowCount}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final window in windows)
          WindowConfigCard(
            config: window,
            isLoggedToday: todayLoggedWindowIds.contains(window.id),
            canDelete: windows.length > 1,
            onToggle: (val) => onToggleWindow(window.id, val),
            onPickTime: () => onPickWindowTime(window),
            onEditMetadata: () => onEditWindowMetadata(window),
            onDelete: () => onDeleteWindow(window.id),
          ),
        if (windows.length < MealSchedule.maxWindowCount) ...<Widget>[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final preset in missingPresets)
                ActionChip(
                  key: presetAddChipKey(preset),
                  avatar: Text(
                    preset.emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  label: Text('+ ${preset.label}'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: () => onAddPresetWindow(preset),
                ),
              ActionChip(
                key: addCustomWindowButtonKey,
                avatar: const Icon(
                  Icons.add_alarm,
                  size: 16,
                  color: AppTheme.inkDark,
                ),
                label: const Text('+ Custom Window'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: AppTheme.snoopCollarGold.withValues(
                  alpha: 0.35,
                ),
                onPressed: onAddCustomWindow,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Configuration card for a single [MealWindowConfig] slot (toggle, start time, edit, delete).
class WindowConfigCard extends StatelessWidget {
  const WindowConfigCard({
    super.key,
    required this.config,
    required this.isLoggedToday,
    required this.canDelete,
    required this.onToggle,
    required this.onPickTime,
    required this.onEditMetadata,
    required this.onDelete,
  });

  final MealWindowConfig config;
  final bool isLoggedToday;
  final bool canDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final VoidCallback onEditMetadata;
  final VoidCallback onDelete;

  static ValueKey<String> toggleKey(String id) => ValueKey<String>('window_toggle_$id');

  static ValueKey<String> timeButtonKey(String id) => ValueKey<String>('window_time_$id');

  static ValueKey<String> editButtonKey(String id) => ValueKey<String>('window_edit_$id');

  static ValueKey<String> deleteButtonKey(String id) => ValueKey<String>('window_delete_$id');

  @override
  Widget build(BuildContext context) {
    final timeLabel = formatMinutesOfDay(config.startMinutesOfDay);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.comicCardDecoration(
        color: config.enabled ? AppTheme.creamCard : AppTheme.pageBackground,
        borderColor: AppTheme.inkDark,
        borderRadius: 16,
        borderWidth: 1.9,
        shadowOffset: config.enabled ? 2.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(config.emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      config.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: config.enabled ? AppTheme.inkDark : AppTheme.inkMuted,
                      ),
                    ),
                    if (isLoggedToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: AppTheme.comicPillDecoration(
                          color: AppTheme.fedSurface,
                          borderWidth: 1.3,
                        ),
                        child: const Text(
                          'FED TODAY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.inkDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                key: toggleKey(config.id),
                value: config.enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              OutlinedButton.icon(
                key: timeButtonKey(config.id),
                onPressed: onPickTime,
                style: OutlinedButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.padded,
                  minimumSize: const Size(48, 44),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.schedule, size: 15),
                label: Text(
                  'Starts $timeLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    key: editButtonKey(config.id),
                    onPressed: onEditMetadata,
                    tooltip: 'Rename window or change emoji',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  if (canDelete)
                    IconButton(
                      key: deleteButtonKey(config.id),
                      onPressed: onDelete,
                      tooltip: 'Remove window',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

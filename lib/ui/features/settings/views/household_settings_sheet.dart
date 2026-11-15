import 'package:flutter/material.dart';

import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';

/// Callback signature invoked when saving schedule & daily treat goal changes.
/// Returns `true` when persisted cleanly, or `false` to keep the sheet open.
typedef OnSaveHouseholdSettings = Future<bool> Function(
  MealSchedule schedule,
  int dailyTreatLimit,
);

/// Standalone Neo-Brutalist Material 3 bottom sheet for configuring a household's
/// daily [MealSchedule] (1..6 windows, custom labels/emojis, minute-level times)
/// and daily treat allowance (`1..20`).
class HouseholdSettingsSheet extends StatefulWidget {
  const HouseholdSettingsSheet({
    super.key,
    required this.petName,
    required this.initialSchedule,
    required this.initialDailyTreatLimit,
    this.todayLoggedWindowIds = const <String>{},
    required this.onSave,
  });

  final String petName;
  final MealSchedule initialSchedule;
  final int initialDailyTreatLimit;
  final Set<String> todayLoggedWindowIds;
  final OnSaveHouseholdSettings onSave;

  static const Key sheetKey = ValueKey<String>('household_settings_sheet');
  static const Key cyclePreviewKey = ValueKey<String>('schedule_cycle_preview');
  static const Key loggedTodayNoticeKey = ValueKey<String>('schedule_logged_today_notice');
  static const Key validationErrorKey = ValueKey<String>('schedule_validation_error');
  static const Key addCustomWindowButtonKey = ValueKey<String>('schedule_add_custom_window');
  static const Key treatLimitDecrementKey = ValueKey<String>('settings_treat_limit_dec');
  static const Key treatLimitIncrementKey = ValueKey<String>('settings_treat_limit_inc');
  static const Key treatLimitValueKey = ValueKey<String>('settings_treat_limit_value');
  static const Key saveButtonKey = ValueKey<String>('settings_save_button');
  static const Key editDialogLabelFieldKey = ValueKey<String>('window_edit_label_field');
  static const Key editDialogEmojiFieldKey = ValueKey<String>('window_edit_emoji_field');
  static const Key editDialogApplyButtonKey = ValueKey<String>('window_edit_apply_button');

  static ValueKey<String> windowToggleKey(String id) => ValueKey<String>('window_toggle_$id');

  static ValueKey<String> windowTimeButtonKey(String id) => ValueKey<String>('window_time_$id');

  static ValueKey<String> windowEditButtonKey(String id) => ValueKey<String>('window_edit_$id');

  static ValueKey<String> windowDeleteButtonKey(String id) => ValueKey<String>('window_delete_$id');

  static ValueKey<String> presetAddChipKey(MealPeriod period) =>
      ValueKey<String>('schedule_add_preset_${period.name}');

  static const List<MealPeriod> _standardPresets = <MealPeriod>[
    MealPeriod.breakfast,
    MealPeriod.lunch,
    MealPeriod.dinner,
    MealPeriod.lateSnack,
  ];

  static const List<String> _emojiChoices = <String>[
    '🥣',
    '🍲',
    '🍖',
    '🌙',
    '🐾',
    '🦴',
    '🥩',
    '🐟',
  ];

  @override
  State<HouseholdSettingsSheet> createState() => _HouseholdSettingsSheetState();
}

class _HouseholdSettingsSheetState extends State<HouseholdSettingsSheet> {
  late List<MealWindowConfig> _windows;
  late int _dailyTreatLimit;
  int _customCounter = 1;
  bool _isSaving = false;
  bool _didPop = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _windows = List<MealWindowConfig>.of(widget.initialSchedule.allWindows);
    _dailyTreatLimit = widget.initialDailyTreatLimit.clamp(1, 20);
  }

  MealSchedule get _draftSchedule => MealSchedule.fromWindows(_windows);

  String? get _liveValidationError => _draftSchedule.validate();

  Set<String> get _disabledOrRemovedLoggedTodayIds {
    final activeIds = <String>{
      for (final w in _windows)
        if (w.enabled) w.id,
    };
    return widget.todayLoggedWindowIds.difference(activeIds);
  }

  void _sortWindows() {
    _windows.sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));
  }

  /// Picks a free start time (`>= 15` minutes from existing windows) near [preferredMinutes].
  ({int hour, int minute}) _pickAvailableStartTime(int preferredMinutes) {
    var candidate = preferredMinutes % 1440;
    for (var step = 0; step < 48; step++) {
      final collides = _windows.any((w) {
        final directDiff = (w.startMinutesOfDay - candidate).abs();
        final wrapDiff = 1440 - directDiff;
        return directDiff < MealSchedule.minWindowGapMinutes ||
            wrapDiff < MealSchedule.minWindowGapMinutes;
      });
      if (!collides) {
        return (hour: candidate ~/ 60, minute: candidate % 60);
      }
      candidate = (candidate + 30) % 1440;
    }
    return (hour: preferredMinutes ~/ 60, minute: preferredMinutes % 60);
  }

  void _addPresetWindow(MealPeriod period) {
    if (_windows.length >= MealSchedule.maxWindowCount) return;
    final slot = _pickAvailableStartTime(
      period.defaultHour * 60 + period.defaultMinute,
    );
    setState(() {
      _submitError = null;
      _windows.add(
        MealWindowConfig.fromPreset(
          period,
          startHour: slot.hour,
          startMinute: slot.minute,
        ),
      );
      _sortWindows();
    });
  }

  void _addCustomWindow() {
    if (_windows.length >= MealSchedule.maxWindowCount) return;
    final existingIds = _windows.map((w) => w.id).toSet();
    while (existingIds.contains('custom_$_customCounter')) {
      _customCounter += 1;
    }
    final customNumber = _customCounter;
    final id = 'custom_$customNumber';
    _customCounter += 1;
    final slot = _pickAvailableStartTime(16 * 60); // Prefer 4:00 PM slot

    setState(() {
      _submitError = null;
      _windows.add(
        MealWindowConfig(
          id: id,
          period: MealPeriod.custom,
          label: 'Snack $customNumber',
          emoji: '🐾',
          startHour: slot.hour,
          startMinute: slot.minute,
        ),
      );
      _sortWindows();
    });
  }

  Future<void> _pickWindowTime(MealWindowConfig config) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: config.startHour,
        minute: config.startMinute,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _submitError = null;
      final index = _windows.indexWhere((w) => w.id == config.id);
      if (index != -1) {
        _windows[index] = _windows[index].copyWith(
          startHour: picked.hour,
          startMinute: picked.minute,
        );
        _sortWindows();
      }
    });
  }

  Future<void> _editWindowMetadata(MealWindowConfig config) async {
    final updated = await showDialog<({String label, String emoji})>(
      context: context,
      builder: (_) => _EditWindowMetadataDialog(
        initialLabel: config.label,
        initialEmoji: config.emoji,
      ),
    );

    if (updated == null || !mounted) return;
    setState(() {
      _submitError = null;
      final index = _windows.indexWhere((w) => w.id == config.id);
      if (index != -1) {
        _windows[index] = _windows[index].copyWith(
          label: updated.label,
          emoji: updated.emoji,
        );
      }
    });
  }

  void _toggleWindowEnabled(String id, bool enabled) {
    setState(() {
      _submitError = null;
      final index = _windows.indexWhere((w) => w.id == id);
      if (index != -1) {
        _windows[index] = _windows[index].copyWith(enabled: enabled);
      }
    });
  }

  void _deleteWindow(String id) {
    setState(() {
      _submitError = null;
      _windows.removeWhere((w) => w.id == id);
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving || _didPop) return;

    final schedule = _draftSchedule;
    final validationError = schedule.validate();
    if (validationError != null) {
      setState(() => _submitError = validationError);
      return;
    }

    setState(() {
      _isSaving = true;
      _submitError = null;
    });

    try {
      final success = await widget.onSave(schedule, _dailyTreatLimit);
      if (!mounted) return;
      if (success && !_didPop) {
        _didPop = true;
        Navigator.of(context).pop(true);
      } else if (!success) {
        setState(() {
          _isSaving = false;
          _submitError = 'Unable to save settings. Please check and try again.';
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _submitError = e.toString();
        });
      }
    }
  }

  static String _formatMinutes(int minutesOfDay) {
    final normalized = ((minutesOfDay % 1440) + 1440) % 1440;
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:$minuteStr $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final existingIds = _windows.map((w) => w.id).toSet();
    final missingPresets = HouseholdSettingsSheet._standardPresets
        .where((p) => !existingIds.contains(p.name))
        .toList();

    final enabledSorted = _windows.where((w) => w.enabled).toList()
      ..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));

    final validationMsg = _submitError ?? _liveValidationError;
    final affectedLoggedToday = _disabledOrRemovedLoggedTodayIds;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      child: Container(
        key: HouseholdSettingsSheet.sheetKey,
        decoration: const BoxDecoration(
          color: AppTheme.pageBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppTheme.inkDark, width: 3),
            left: BorderSide(color: AppTheme.inkDark, width: 3),
            right: BorderSide(color: AppTheme.inkDark, width: 3),
          ),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: viewInsetsBottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 52,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.snoopCurlHighlight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.comicCardDecoration(
                  color: AppTheme.creamCard,
                  borderRadius: 20,
                  shadowOffset: 3,
                ),
                child: Row(
                  children: <Widget>[
                    const SnoopMiniAvatar(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "⏰ ${widget.petName}'s Meal Schedule & Treats",
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.inkDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Syncs instantly across the whole pack',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Live 24h Cycle & Midnight Wrap-Around Preview
              _CyclePreviewCard(
                key: HouseholdSettingsSheet.cyclePreviewKey,
                enabledWindows: enabledSorted,
                formatMinutes: _formatMinutes,
              ),

              if (affectedLoggedToday.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  key: HouseholdSettingsSheet.loggedTodayNoticeKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: AppTheme.comicCardDecoration(
                    color: AppTheme.hungrySurface,
                    borderRadius: 14,
                    borderWidth: 1.8,
                    shadowOffset: 2,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('📌 ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          'Already logged today — disabling or removing this '
                          'window updates the active schedule while keeping '
                          "today's meal log safe in Belly Log history.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.inkDark,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
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
                    '${_windows.length}/${MealSchedule.maxWindowCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Window Config List
              for (final window in _windows)
                _WindowConfigCard(
                  config: window,
                  timeLabel: _formatMinutes(window.startMinutesOfDay),
                  isLoggedToday: widget.todayLoggedWindowIds.contains(window.id),
                  canDelete: _windows.length > 1,
                  onToggle: (val) => _toggleWindowEnabled(window.id, val),
                  onPickTime: () => _pickWindowTime(window),
                  onEditMetadata: () => _editWindowMetadata(window),
                  onDelete: () => _deleteWindow(window.id),
                ),

              // Add Preset / Custom Window Chips (up to 6 total)
              if (_windows.length < MealSchedule.maxWindowCount) ...<Widget>[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final preset in missingPresets)
                      ActionChip(
                        key: HouseholdSettingsSheet.presetAddChipKey(preset),
                        avatar: Text(
                          preset.emoji,
                          style: const TextStyle(fontSize: 13),
                        ),
                        label: Text('+ ${preset.label}'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _addPresetWindow(preset),
                      ),
                    ActionChip(
                      key: HouseholdSettingsSheet.addCustomWindowButtonKey,
                      avatar: const Icon(
                        Icons.add_alarm,
                        size: 16,
                        color: AppTheme.inkDark,
                      ),
                      label: const Text('+ Custom Window'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppTheme.snoopCollarGold.withValues(alpha: 0.35),
                      onPressed: _addCustomWindow,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Daily Treat Allowance Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.comicCardDecoration(
                  color: AppTheme.creamCard,
                  borderRadius: 18,
                  borderWidth: 2,
                  shadowOffset: 3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        const Text(
                          '🦴 Daily Treat Allowance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.inkDark,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              key: HouseholdSettingsSheet.treatLimitDecrementKey,
                              onPressed: _dailyTreatLimit > 1
                                  ? () => setState(() => _dailyTreatLimit -= 1)
                                  : null,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Container(
                              key: HouseholdSettingsSheet.treatLimitValueKey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: AppTheme.comicPillDecoration(
                                color: AppTheme.snoopCollarGold,
                                borderWidth: 1.6,
                              ),
                              child: Text(
                                '$_dailyTreatLimit / day',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.inkDark,
                                ),
                              ),
                            ),
                            IconButton(
                              key: HouseholdSettingsSheet.treatLimitIncrementKey,
                              onPressed: _dailyTreatLimit < 20
                                  ? () => setState(() => _dailyTreatLimit += 1)
                                  : null,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shows a gentle "Chonk Alert!" badge on the Treat Jar if '
                      '${widget.petName} gets more than $_dailyTreatLimit treats '
                      'in one logical day.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),

              if (validationMsg != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: HouseholdSettingsSheet.validationErrorKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: AppTheme.comicCardDecoration(
                    color: AppTheme.snoopTonguePink.withValues(alpha: 0.22),
                    borderRadius: 14,
                    borderWidth: 1.8,
                    shadowOffset: 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AppTheme.inkDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          validationMsg,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.inkDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              FilledButton.icon(
                key: HouseholdSettingsSheet.saveButtonKey,
                onPressed: _isSaving ? null : _handleSave,
                icon: const Icon(Icons.check_circle_outline, size: 19),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.fedPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.inkDark, width: 2),
                  ),
                ),
                label: Text(
                  _isSaving ? 'Saving Schedule...' : 'Save Schedule & Treat Goal',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyclePreviewCard extends StatelessWidget {
  const _CyclePreviewCard({
    super.key,
    required this.enabledWindows,
    required this.formatMinutes,
  });

  final List<MealWindowConfig> enabledWindows;
  final String Function(int minutesOfDay) formatMinutes;

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
                  ? '🌙 Before ${formatMinutes(enabledWindows.first.startMinutesOfDay)}, '
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
    final startStr = formatMinutes(current.startMinutesOfDay);
    if (enabledWindows.length == 1) {
      return '${current.emoji} ${current.label}: $startStr – $startStr (24h)';
    }
    final endMinute = (next.startMinutesOfDay - 1 + 1440) % 1440;
    final endStr = formatMinutes(endMinute);
    final wraps = index == enabledWindows.length - 1 && next.startMinutesOfDay > 0;
    final wrapTag = wraps ? ' (next morning)' : '';
    return '${current.emoji} ${current.label}: $startStr – $endStr$wrapTag';
  }
}

class _WindowConfigCard extends StatelessWidget {
  const _WindowConfigCard({
    required this.config,
    required this.timeLabel,
    required this.isLoggedToday,
    required this.canDelete,
    required this.onToggle,
    required this.onPickTime,
    required this.onEditMetadata,
    required this.onDelete,
  });

  final MealWindowConfig config;
  final String timeLabel;
  final bool isLoggedToday;
  final bool canDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final VoidCallback onEditMetadata;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                key: HouseholdSettingsSheet.windowToggleKey(config.id),
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
                key: HouseholdSettingsSheet.windowTimeButtonKey(config.id),
                onPressed: onPickTime,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
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
                    key: HouseholdSettingsSheet.windowEditButtonKey(config.id),
                    onPressed: onEditMetadata,
                    tooltip: 'Rename window or change emoji',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  if (canDelete)
                    IconButton(
                      key: HouseholdSettingsSheet.windowDeleteButtonKey(
                        config.id,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Remove window',
                      visualDensity: VisualDensity.compact,
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

class _EditWindowMetadataDialog extends StatefulWidget {
  const _EditWindowMetadataDialog({
    required this.initialLabel,
    required this.initialEmoji,
  });

  final String initialLabel;
  final String initialEmoji;

  @override
  State<_EditWindowMetadataDialog> createState() => _EditWindowMetadataDialogState();
}

class _EditWindowMetadataDialogState extends State<_EditWindowMetadataDialog> {
  late final TextEditingController _labelController =
      TextEditingController(text: widget.initialLabel);
  late final TextEditingController _emojiController =
      TextEditingController(text: widget.initialEmoji);
  String? _dialogError;

  @override
  void dispose() {
    _labelController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _apply() {
    final cleanLabel = _labelController.text.trim();
    final cleanEmoji = _emojiController.text.trim();
    if (cleanLabel.isEmpty || cleanLabel.length > 24) {
      setState(() => _dialogError = 'Label must be 1..24 characters.');
      return;
    }
    if (cleanEmoji.isEmpty || cleanEmoji.length > 8) {
      setState(() => _dialogError = 'Emoji must be 1..8 characters.');
      return;
    }
    Navigator.of(context).pop((label: cleanLabel, emoji: cleanEmoji));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppTheme.inkDark, width: 2.5),
      ),
      title: const Text(
        '✏️ Customize Meal Window',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: AppTheme.inkDark,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final emoji in HouseholdSettingsSheet._emojiChoices)
                  InkWell(
                    onTap: () => setState(() {
                      _emojiController.text = emoji;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _emojiController.text.trim() == emoji
                            ? AppTheme.snoopCollarGold
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.inkDark,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: HouseholdSettingsSheet.editDialogEmojiFieldKey,
              controller: _emojiController,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Emoji (1..8 chars)',
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: HouseholdSettingsSheet.editDialogLabelFieldKey,
              controller: _labelController,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Window Name (1..24 chars)',
                hintText: 'e.g. Second Breakfast',
                counterText: '',
                isDense: true,
              ),
            ),
            if (_dialogError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _dialogError!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.hungryPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.inkMuted,
            ),
          ),
        ),
        FilledButton(
          key: HouseholdSettingsSheet.editDialogApplyButtonKey,
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

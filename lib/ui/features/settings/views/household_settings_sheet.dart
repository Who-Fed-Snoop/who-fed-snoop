import 'package:flutter/material.dart';

import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
import '../../feeder/view_models/feeder_view_model.dart';
import '../widgets/cycle_preview_card.dart';
import '../widgets/edit_window_metadata_dialog.dart';
import '../widgets/settings_cards.dart';
import '../widgets/window_config_card.dart';

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
  static const Key loggedTodayNoticeKey = ValueKey<String>(
    'schedule_logged_today_notice',
  );
  static const Key validationErrorKey = ValueKey<String>(
    'schedule_validation_error',
  );
  static const Key addCustomWindowButtonKey = MealWindowsSection.addCustomWindowButtonKey;
  static const Key treatLimitDecrementKey = DailyTreatAllowanceCard.decrementKey;
  static const Key treatLimitIncrementKey = DailyTreatAllowanceCard.incrementKey;
  static const Key treatLimitValueKey = DailyTreatAllowanceCard.valueKey;
  static const Key saveButtonKey = ValueKey<String>('settings_save_button');
  static const Key editDialogLabelFieldKey = EditWindowMetadataDialog.labelFieldKey;
  static const Key editDialogEmojiFieldKey = EditWindowMetadataDialog.emojiFieldKey;
  static const Key editDialogApplyButtonKey = EditWindowMetadataDialog.applyButtonKey;

  static ValueKey<String> windowToggleKey(String id) => WindowConfigCard.toggleKey(id);

  static ValueKey<String> windowTimeButtonKey(String id) => WindowConfigCard.timeButtonKey(id);

  static ValueKey<String> windowEditButtonKey(String id) => WindowConfigCard.editButtonKey(id);

  static ValueKey<String> windowDeleteButtonKey(String id) => WindowConfigCard.deleteButtonKey(id);

  static ValueKey<String> presetAddChipKey(MealPeriod period) =>
      MealWindowsSection.presetAddChipKey(period);

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
      if (!collides) return (hour: candidate ~/ 60, minute: candidate % 60);
      candidate = (candidate + 30) % 1440;
    }
    return (hour: preferredMinutes ~/ 60, minute: preferredMinutes % 60);
  }

  void _addWindow(MealWindowConfig window) {
    if (_windows.length >= MealSchedule.maxWindowCount) return;
    setState(() {
      _submitError = null;
      _windows.add(window);
      _sortWindows();
    });
  }

  void _updateWindow(
    String id,
    MealWindowConfig Function(MealWindowConfig current) transform, {
    bool sort = false,
  }) {
    setState(() {
      _submitError = null;
      final index = _windows.indexWhere((w) => w.id == id);
      if (index != -1) {
        _windows[index] = transform(_windows[index]);
        if (sort) _sortWindows();
      }
    });
  }

  void _addPresetWindow(MealPeriod period) {
    final slot = _pickAvailableStartTime(
      period.defaultHour * 60 + period.defaultMinute,
    );
    _addWindow(
      MealWindowConfig.fromPreset(
        period,
        startHour: slot.hour,
        startMinute: slot.minute,
      ),
    );
  }

  void _addCustomWindow() {
    final existingIds = _windows.map((w) => w.id).toSet();
    while (existingIds.contains('custom_$_customCounter')) {
      _customCounter += 1;
    }
    final customNumber = _customCounter++;
    final slot = _pickAvailableStartTime(16 * 60); // Prefer 4:00 PM slot
    _addWindow(
      MealWindowConfig(
        id: 'custom_$customNumber',
        period: MealPeriod.custom,
        label: 'Snack $customNumber',
        emoji: '🐾',
        startHour: slot.hour,
        startMinute: slot.minute,
      ),
    );
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
    _updateWindow(
      config.id,
      (w) => w.copyWith(startHour: picked.hour, startMinute: picked.minute),
      sort: true,
    );
  }

  Future<void> _editWindowMetadata(MealWindowConfig config) async {
    final updated = await showDialog<({String label, String emoji})>(
      context: context,
      builder: (_) => EditWindowMetadataDialog(
        initialLabel: config.label,
        initialEmoji: config.emoji,
      ),
    );
    if (updated == null || !mounted) return;
    _updateWindow(
      config.id,
      (w) => w.copyWith(label: updated.label, emoji: updated.emoji),
    );
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
          _submitError = FeederViewModel.formatErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final enabledSorted = _windows.where((w) => w.enabled).toList()
      ..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));
    final validationMsg = _submitError ?? _draftSchedule.validate();

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
              SettingsHeaderCard(petName: widget.petName),
              const SizedBox(height: 14),
              CyclePreviewCard(
                key: HouseholdSettingsSheet.cyclePreviewKey,
                enabledWindows: enabledSorted,
              ),
              if (_disabledOrRemovedLoggedTodayIds.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                const SettingsNoticeBanner(
                  key: HouseholdSettingsSheet.loggedTodayNoticeKey,
                  backgroundColor: AppTheme.hungrySurface,
                  leading: Text('📌 ', style: TextStyle(fontSize: 14)),
                  message: 'Already logged today — disabling or removing this '
                      'window updates the active schedule while keeping '
                      "today's meal log safe in Belly Log history.",
                ),
              ],
              const SizedBox(height: 14),
              AbsorbPointer(
                absorbing: _isSaving,
                child: Opacity(
                  opacity: _isSaving ? 0.65 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      MealWindowsSection(
                        windows: _windows,
                        todayLoggedWindowIds: widget.todayLoggedWindowIds,
                        onToggleWindow: (id, enabled) =>
                            _updateWindow(id, (w) => w.copyWith(enabled: enabled)),
                        onPickWindowTime: _pickWindowTime,
                        onEditWindowMetadata: _editWindowMetadata,
                        onDeleteWindow: _deleteWindow,
                        onAddPresetWindow: _addPresetWindow,
                        onAddCustomWindow: _addCustomWindow,
                      ),
                      const SizedBox(height: 16),
                      DailyTreatAllowanceCard(
                        petName: widget.petName,
                        dailyTreatLimit: _dailyTreatLimit,
                        onChanged: (value) => setState(() => _dailyTreatLimit = value),
                      ),
                    ],
                  ),
                ),
              ),
              if (validationMsg != null) ...<Widget>[
                const SizedBox(height: 12),
                SettingsNoticeBanner(
                  key: HouseholdSettingsSheet.validationErrorKey,
                  backgroundColor: AppTheme.snoopTonguePink.withValues(
                    alpha: 0.22,
                  ),
                  leading: const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppTheme.inkDark,
                  ),
                  message: validationMsg,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: HouseholdSettingsSheet.saveButtonKey,
                onPressed: _isSaving ? null : _handleSave,
                icon: Icon(
                  _isSaving ? Icons.hourglass_top : Icons.check_circle_outline,
                  size: 19,
                ),
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

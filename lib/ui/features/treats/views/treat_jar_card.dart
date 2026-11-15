import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/treat_event.dart';
import '../../../core/app_theme.dart';

/// Callback signature for logging a custom treat with explicit label, count, calories, and note.
typedef OnLogCustomTreat = Future<void> Function({
  required String label,
  required int quantity,
  required int caloriesPerUnit,
  String? note,
});

/// Standalone Neo-Brutalist Material 3 card for Snoop's daily Treat Jar:
/// - Live daily treat count & calorie badge + soft over-limit warning ("Chonk Alert!")
/// - 1-tap quick preset chips + custom treat bottom sheet
/// - Expandable "Today's Treats" drawer with per-item delete action
class TreatJarCard extends StatefulWidget {
  const TreatJarCard({
    super.key,
    required this.petName,
    required this.todayTreats,
    required this.dailyTreatLimit,
    required this.currentMemberUid,
    this.isCompact = false,
    required this.onLogPreset,
    required this.onLogCustomTreat,
    required this.onDeleteTreat,
    this.onOpenSettings,
  });

  final String petName;
  final List<TreatEvent> todayTreats;
  final int dailyTreatLimit;
  final String currentMemberUid;
  final bool isCompact;
  final ValueChanged<TreatPreset> onLogPreset;
  final OnLogCustomTreat onLogCustomTreat;
  final ValueChanged<String> onDeleteTreat;
  final VoidCallback? onOpenSettings;

  static const Key cardKey = ValueKey<String>('treat_jar_card');
  static const Key allowancePillKey = ValueKey<String>('treat_allowance_pill');
  static const Key overLimitBannerKey = ValueKey<String>('treat_over_limit_banner');
  static const Key customTreatButtonKey = ValueKey<String>('treat_custom_button');
  static const Key drawerToggleKey = ValueKey<String>('treat_drawer_toggle');

  static ValueKey<String> presetChipKey(TreatPreset preset) =>
      ValueKey<String>('treat_preset_${preset.id}');

  static ValueKey<String> deleteTreatButtonKey(String treatId) =>
      ValueKey<String>('treat_delete_$treatId');

  static const List<TreatPreset> _quickPresets = <TreatPreset>[
    TreatPreset.trainingTreat,
    TreatPreset.dentalChew,
    TreatPreset.peanutButterKong,
    TreatPreset.crunchyBiscuit,
  ];

  @override
  State<TreatJarCard> createState() => _TreatJarCardState();
}

class _TreatJarCardState extends State<TreatJarCard> {
  bool _isDrawerExpanded = false;

  int get _totalTreatCount => widget.todayTreats.fold<int>(
        0,
        (total, treat) => total + treat.quantity,
      );

  int get _totalCalories => widget.todayTreats.fold<int>(
        0,
        (total, treat) => total + treat.totalCalories,
      );

  Future<void> _openCustomTreatSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomTreatSheet(
        petName: widget.petName,
        onSubmit: widget.onLogCustomTreat,
      ),
    );
  }

  static String _shortPresetLabel(TreatPreset preset) {
    switch (preset) {
      case TreatPreset.trainingTreat:
        return 'Training';
      case TreatPreset.dentalChew:
        return 'Dental Chew';
      case TreatPreset.peanutButterKong:
        return 'PB Kong';
      case TreatPreset.crunchyBiscuit:
        return 'Biscuit';
      case TreatPreset.custom:
        return 'Custom';
    }
  }

  static String _formatClockTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final sortedTreats = List<TreatEvent>.of(widget.todayTreats)
      ..sort((a, b) => b.givenAt.compareTo(a.givenAt));
    final count = _totalTreatCount;
    final calories = _totalCalories;
    final limit = widget.dailyTreatLimit;
    final isOverLimit = count > limit;
    final overBy = count - limit;

    final pillBgColor = isOverLimit
        ? AppTheme.snoopTonguePink.withValues(alpha: 0.30)
        : (count > 0 ? AppTheme.fedSurface : AppTheme.snoopCollarGold.withValues(alpha: 0.32));

    final pillText = isOverLimit
        ? '⚠️ $count / $limit TREATS • CHONK ALERT!'
        : '$count / $limit TREATS • $calories KCAL';

    return Container(
      key: TreatJarCard.cardKey,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 14 : 16,
        vertical: widget.isCompact ? 10 : 14,
      ),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderColor: AppTheme.inkDark,
        borderRadius: 22,
        borderWidth: 2.2,
        shadowOffset: 3.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header + Daily Allowance Pill
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                "🦴 ${widget.petName.toUpperCase()}'S TREAT JAR",
                style: TextStyle(
                  fontSize: widget.isCompact ? 13 : 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: AppTheme.inkDark,
                ),
              ),
              InkWell(
                key: TreatJarCard.allowancePillKey,
                onTap: widget.onOpenSettings,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: AppTheme.comicPillDecoration(
                    color: pillBgColor,
                    borderColor: AppTheme.inkDark,
                    borderWidth: 1.7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          pillText,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.inkDark,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (widget.onOpenSettings != null) ...<Widget>[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.tune,
                          size: 13,
                          color: AppTheme.inkDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Soft Over-Limit Warning Banner (never blocks truthful logging)
          if (isOverLimit) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: TreatJarCard.overLimitBannerKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.comicCardDecoration(
                color: AppTheme.snoopTonguePink.withValues(alpha: 0.16),
                borderColor: AppTheme.inkDark,
                borderRadius: 14,
                borderWidth: 1.8,
                shadowOffset: 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('🐾 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      'Easy on the snacks! ${widget.petName} is +$overBy over the '
                      '$limit-treat daily goal ($calories kcal today).',
                      style: const TextStyle(
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

          SizedBox(height: widget.isCompact ? 8 : 10),

          // 1-Tap Preset Chips + Custom Button
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final preset in TreatJarCard._quickPresets)
                _QuickTreatChip(
                  key: TreatJarCard.presetChipKey(preset),
                  emoji: preset.emoji,
                  label: _shortPresetLabel(preset),
                  calories: preset.defaultCalories,
                  backgroundColor: AppTheme.hungrySurface,
                  onTap: () => widget.onLogPreset(preset),
                ),
              _QuickTreatChip(
                key: TreatJarCard.customTreatButtonKey,
                emoji: '✨',
                label: '+ Custom',
                backgroundColor: AppTheme.snoopCollarGold.withValues(alpha: 0.35),
                onTap: _openCustomTreatSheet,
              ),
            ],
          ),

          SizedBox(height: widget.isCompact ? 8 : 10),

          // Expandable Today's Treats Drawer
          InkWell(
            key: TreatJarCard.drawerToggleKey,
            onTap: () => setState(() => _isDrawerExpanded = !_isDrawerExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.pageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.inkDark, width: 1.6),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      sortedTreats.isEmpty
                          ? 'No treats logged yet today (${(limit - count).clamp(0, limit)} left in daily goal)'
                          : (_isDrawerExpanded
                              ? "Hide Today's Treats (${sortedTreats.length})"
                              : _buildCollapsedSummary(sortedTreats)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.inkDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isDrawerExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.inkDark,
                  ),
                ],
              ),
            ),
          ),

          if (_isDrawerExpanded) ...<Widget>[
            const SizedBox(height: 8),
            if (sortedTreats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Tap any preset above when Snoop earns a snack!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkMuted,
                  ),
                ),
              )
            else
              for (final treat in sortedTreats)
                _TodayTreatRow(
                  treat: treat,
                  timeString: _formatClockTime(treat.givenAt),
                  onDelete: () => widget.onDeleteTreat(treat.id),
                ),
          ],
        ],
      ),
    );
  }

  String _buildCollapsedSummary(List<TreatEvent> sortedTreats) {
    final latest = sortedTreats.first;
    final qtySuffix = latest.quantity > 1 ? ' (x${latest.quantity})' : '';
    final timeStr = _formatClockTime(latest.givenAt);
    return 'Latest: ${latest.emoji} ${latest.label}$qtySuffix by '
        '${latest.givenByName} at $timeStr • View (${sortedTreats.length})';
  }
}

class _QuickTreatChip extends StatelessWidget {
  const _QuickTreatChip({
    super.key,
    required this.emoji,
    required this.label,
    this.calories,
    required this.backgroundColor,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final int? calories;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: AppTheme.comicPillDecoration(
            color: backgroundColor,
            borderColor: AppTheme.inkDark,
            borderWidth: 1.8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.inkDark,
                ),
              ),
              if (calories != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  '${calories}c',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTreatRow extends StatelessWidget {
  const _TodayTreatRow({
    required this.treat,
    required this.timeString,
    required this.onDelete,
  });

  final TreatEvent treat;
  final String timeString;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final qtyText = treat.quantity > 1 ? ' x${treat.quantity}' : '';
    final notePart = (treat.note != null && treat.note!.isNotEmpty) ? ' • "${treat.note}"' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.inkDark, width: 1.6),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.hungrySurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.inkDark, width: 1.5),
            ),
            child: Text(treat.emoji, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${treat.label}$qtyText • ${treat.totalCalories} kcal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.inkDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Given by ${treat.givenByName} at $timeString$notePart',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: TreatJarCard.deleteTreatButtonKey(treat.id),
            onPressed: onDelete,
            tooltip: 'Delete treat',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              size: 19,
              color: AppTheme.inkDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet for logging a custom treat with label, portion count (`1..10`),
/// estimated calories (`0..2000`), and optional note (`0..140` chars).
class CustomTreatSheet extends StatefulWidget {
  const CustomTreatSheet({
    super.key,
    required this.petName,
    required this.onSubmit,
  });

  final String petName;
  final OnLogCustomTreat onSubmit;

  static const Key labelFieldKey = ValueKey<String>('custom_treat_label_field');
  static const Key caloriesFieldKey = ValueKey<String>('custom_treat_calories_field');
  static const Key noteFieldKey = ValueKey<String>('custom_treat_note_field');
  static const Key decrementQtyKey = ValueKey<String>('custom_treat_qty_dec');
  static const Key incrementQtyKey = ValueKey<String>('custom_treat_qty_inc');
  static const Key submitButtonKey = ValueKey<String>('custom_treat_submit_button');

  @override
  State<CustomTreatSheet> createState() => _CustomTreatSheetState();
}

class _CustomTreatSheetState extends State<CustomTreatSheet> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController(text: '30');
  final TextEditingController _noteController = TextEditingController();

  int _quantity = 1;
  bool _isSubmitting = false;
  bool _didPop = false;
  String? _localError;

  @override
  void dispose() {
    _labelController.dispose();
    _caloriesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _didPop) return;

    final label = _labelController.text.trim();
    if (label.isEmpty || label.length > 40) {
      setState(() {
        _localError = 'Enter a treat name (1..40 characters).';
      });
      return;
    }

    final rawCalories = _caloriesController.text.trim();
    final parsedCalories = rawCalories.isEmpty ? 30 : int.tryParse(rawCalories);
    if (parsedCalories == null || parsedCalories < 0 || parsedCalories > 2000) {
      setState(() {
        _localError = 'Calories per treat must be between 0 and 2000.';
      });
      return;
    }

    final note = _noteController.text.trim();
    if (note.length > 140) {
      setState(() {
        _localError = 'Note must be at most 140 characters.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      await widget.onSubmit(
        label: label,
        quantity: _quantity,
        caloriesPerUnit: parsedCalories,
        note: note.isEmpty ? null : note,
      );
      if (mounted && !_didPop) {
        _didPop = true;
        Navigator.of(context).pop();
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _localError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
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
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.snoopCurlHighlight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '✨ Log Custom Treat for ${widget.petName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.inkDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track special snacks, chews, or training rewards without touching meal status.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: CustomTreatSheet.labelFieldKey,
              controller: _labelController,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Treat Name',
                hintText: 'e.g. Cheese Cube or Apple Slice',
                prefixIcon: Icon(Icons.cookie_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),

            // Portion Stepper + Calories Row (Wrap-safe for narrow screens)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: AppTheme.comicCardDecoration(
                color: AppTheme.creamCard,
                borderRadius: 16,
                borderWidth: 2,
                shadowOffset: 2,
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Portion:',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: AppTheme.inkDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: CustomTreatSheet.decrementQtyKey,
                        onPressed: _quantity > 1 ? () => setState(() => _quantity -= 1) : null,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${_quantity}x',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.inkDark,
                        ),
                      ),
                      IconButton(
                        key: CustomTreatSheet.incrementQtyKey,
                        onPressed: _quantity < 10 ? () => setState(() => _quantity += 1) : null,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 132,
                    child: TextField(
                      key: CustomTreatSheet.caloriesFieldKey,
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        labelText: 'kcal / unit',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: CustomTreatSheet.noteFieldKey,
              controller: _noteController,
              maxLength: 140,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Optional Note',
                hintText: 'e.g. Good recall at the park!',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
                counterText: '',
              ),
            ),
            if (_localError != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: AppTheme.comicCardDecoration(
                  color: AppTheme.snoopTonguePink.withValues(alpha: 0.2),
                  borderRadius: 12,
                  borderWidth: 1.6,
                  shadowOffset: 2,
                ),
                child: Text(
                  _localError!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.inkDark,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: CustomTreatSheet.submitButtonKey,
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: const Icon(Icons.pets, size: 18),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.hungryPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.inkDark, width: 2),
                ),
              ),
              label: Text(
                _isSubmitting ? 'Logging Treat...' : 'Log Custom Treat',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../domain/models/treat_event.dart';
import '../../../core/app_theme.dart';

/// 1-tap Neo-Brutalist pill chip for logging a quick treat preset or opening the custom sheet.
class QuickTreatChip extends StatelessWidget {
  const QuickTreatChip({
    super.key,
    required this.emoji,
    required this.label,
    this.calories,
    required this.backgroundColor,
    this.isLoading = false,
    this.enabled = true,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final int? calories;
  final Color backgroundColor;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInteractive = enabled && !isLoading;
    final chipOpacity = isLoading ? 0.85 : (enabled ? 1.0 : 0.55);

    return Opacity(
      opacity: chipOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            child: Center(
              widthFactor: 1.0,
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: AppTheme.comicPillDecoration(
                  color: isLoading
                      ? AppTheme.snoopCollarGold.withValues(alpha: 0.45)
                      : backgroundColor,
                  borderColor: AppTheme.inkDark,
                  borderWidth: 1.8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(isLoading ? '⏳' : emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      isLoading ? 'Logging...' : label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    if (!isLoading && calories != null) ...<Widget>[
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
          ),
        ),
      ),
    );
  }
}

/// Row displaying a single logged [TreatEvent] inside the "Today's Treats" drawer.
class TodayTreatRow extends StatelessWidget {
  const TodayTreatRow({
    super.key,
    required this.treat,
    required this.timeString,
    this.isDeleting = false,
    required this.onDelete,
  });

  final TreatEvent treat;
  final String timeString;
  final bool isDeleting;
  final VoidCallback onDelete;

  static ValueKey<String> deleteButtonKey(String treatId) =>
      ValueKey<String>('treat_delete_$treatId');

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
            key: deleteButtonKey(treat.id),
            onPressed: isDeleting ? null : onDelete,
            tooltip: isDeleting ? 'Deleting treat...' : 'Delete treat',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isDeleting ? Icons.hourglass_top : Icons.delete_outline,
              size: 19,
              color: isDeleting ? AppTheme.inkMuted : AppTheme.inkDark,
            ),
          ),
        ],
      ),
    );
  }
}

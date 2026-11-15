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

/// Row displaying a single logged [TreatEvent] inside the "Today's Treats" drawer.
class TodayTreatRow extends StatelessWidget {
  const TodayTreatRow({
    super.key,
    required this.treat,
    required this.timeString,
    required this.onDelete,
  });

  final TreatEvent treat;
  final String timeString;
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

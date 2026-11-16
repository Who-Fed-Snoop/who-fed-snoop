import 'package:flutter/material.dart';

import '../../../../data/services/widget_sync_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';

/// Live preview of the Android Home Screen Widget synced via [WidgetSyncService].
class HomeWidgetPreviewCard extends StatelessWidget {
  const HomeWidgetPreviewCard({
    super.key,
    required this.snapshot,
    required this.isLoggingMeal,
    required this.onTapFeed,
  });

  final HomeWidgetSnapshot? snapshot;
  final bool isLoggingMeal;
  final VoidCallback onTapFeed;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    if (current == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.snoopCoatBlack,
        borderColor: AppTheme.snoopCollarGold,
        borderRadius: 20,
        borderWidth: 2.5,
        shadowOffset: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.widgets_outlined,
                color: AppTheme.snoopCollarGold,
                size: 15,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'SNOOP-CAM • ANDROID HOME WIDGET PREVIEW',
                  style: TextStyle(
                    color: AppTheme.snoopCollarGold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.snoopCurlHighlight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE SYNC',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              SnoopMiniAvatar(size: 34, isHappy: current.isFed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      current.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      current.subheadline,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!current.isFed)
                FilledButton.icon(
                  onPressed: isLoggingMeal ? null : onTapFeed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.snoopCollarGold,
                    foregroundColor: AppTheme.inkDark,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    minimumSize: const Size(64, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                  icon: Icon(
                    isLoggingMeal ? Icons.hourglass_top : Icons.pets,
                    size: 14,
                  ),
                  label: Text(
                    isLoggingMeal ? 'Logging...' : 'Feed',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

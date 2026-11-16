import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Dialog for customizing a meal window's display label (`1..24` chars) and emoji (`1..8` chars).
class EditWindowMetadataDialog extends StatefulWidget {
  const EditWindowMetadataDialog({
    super.key,
    required this.initialLabel,
    required this.initialEmoji,
  });

  final String initialLabel;
  final String initialEmoji;

  static const Key labelFieldKey = ValueKey<String>('window_edit_label_field');
  static const Key emojiFieldKey = ValueKey<String>('window_edit_emoji_field');
  static const Key applyButtonKey = ValueKey<String>(
    'window_edit_apply_button',
  );

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
  State<EditWindowMetadataDialog> createState() => _EditWindowMetadataDialogState();
}

class _EditWindowMetadataDialogState extends State<EditWindowMetadataDialog> {
  late final TextEditingController _labelController = TextEditingController(
    text: widget.initialLabel,
  );
  late final TextEditingController _emojiController = TextEditingController(
    text: widget.initialEmoji,
  );
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
                for (final emoji in EditWindowMetadataDialog._emojiChoices)
                  InkWell(
                    onTap: () => setState(() {
                      _emojiController.text = emoji;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _emojiController.text.trim() == emoji
                            ? AppTheme.snoopCollarGold
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.inkDark, width: 1.5),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: EditWindowMetadataDialog.emojiFieldKey,
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
              key: EditWindowMetadataDialog.labelFieldKey,
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
          key: EditWindowMetadataDialog.applyButtonKey,
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

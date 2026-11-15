import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';

/// Callback signature for logging a custom treat with explicit label, count, calories, and note.
typedef OnLogCustomTreat = Future<void> Function({
  required String label,
  required int quantity,
  required int caloriesPerUnit,
  String? note,
});

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
  static const Key caloriesFieldKey = ValueKey<String>(
    'custom_treat_calories_field',
  );
  static const Key noteFieldKey = ValueKey<String>('custom_treat_note_field');
  static const Key decrementQtyKey = ValueKey<String>('custom_treat_qty_dec');
  static const Key incrementQtyKey = ValueKey<String>('custom_treat_qty_inc');
  static const Key submitButtonKey = ValueKey<String>(
    'custom_treat_submit_button',
  );

  @override
  State<CustomTreatSheet> createState() => _CustomTreatSheetState();
}

class _CustomTreatSheetState extends State<CustomTreatSheet> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController(
    text: '30',
  );
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

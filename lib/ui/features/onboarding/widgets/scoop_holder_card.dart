import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../core/app_theme.dart';
import '../../feeder/view_models/feeder_view_model.dart';

/// Pack HQ card allowing the user to bind this phone's Scoop Holder persona
/// (Keni, Ashley, or a custom/sitter name) and simulate a partner tap in demo mode.
class ScoopHolderCard extends StatelessWidget {
  const ScoopHolderCard({
    super.key,
    required this.viewModel,
    required this.enabled,
    required this.onSelectMember,
    required this.onCustomName,
  });

  final FeederViewModel viewModel;
  final bool enabled;
  final Future<void> Function({required String uid, required String name}) onSelectMember;
  final VoidCallback onCustomName;

  static const Key cardKey = ValueKey<String>('pack_hq_scoop_holder_card');
  static const Key keniChipKey = ValueKey<String>('pack_hq_keni_chip');
  static const Key ashleyChipKey = ValueKey<String>('pack_hq_ashley_chip');
  static const Key customChipKey = ValueKey<String>(
    'active_custom_persona_chip',
  );
  static const Key customButtonKey = ValueKey<String>(
    'pack_hq_custom_persona_button',
  );
  static const Key simulatePartnerButtonKey = ValueKey<String>(
    'simulate_partner_button',
  );

  @override
  Widget build(BuildContext context) {
    final normalizedName = viewModel.currentMemberName.trim().toLowerCase();
    final isKeni = normalizedName == 'keni';
    final isAshley = normalizedName == 'ashley';
    final isCustomOrSitter = !isKeni && !isAshley;
    final partnerName = isKeni ? 'Ashley' : 'Keni';

    return Container(
      key: cardKey,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 20,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                '🥣 Scoop Holder (This Phone)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.inkDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: AppTheme.comicPillDecoration(
                  color: AppTheme.fedSurface,
                  borderWidth: 1.5,
                ),
                child: Text(
                  'Bound: ${viewModel.currentMemberName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.inkDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Remembered across restarts, Home Widget taps & NFC scans.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ChoiceChip(
                key: keniChipKey,
                label: const Text('Keni'),
                selected: isKeni,
                visualDensity: VisualDensity.compact,
                onSelected: enabled
                    ? (_) => onSelectMember(
                          uid: InMemoryHouseholdRepository.keniUid,
                          name: 'Keni',
                        )
                    : null,
              ),
              ChoiceChip(
                key: ashleyChipKey,
                label: const Text('Ashley'),
                selected: isAshley,
                visualDensity: VisualDensity.compact,
                onSelected: enabled
                    ? (_) => onSelectMember(
                          uid: InMemoryHouseholdRepository.ashleyUid,
                          name: 'Ashley',
                        )
                    : null,
              ),
              if (isCustomOrSitter)
                ChoiceChip(
                  key: customChipKey,
                  label: Text(
                    viewModel.isSitterMode ? '🐾 Dog Sitter' : viewModel.currentMemberName,
                  ),
                  selected: true,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {},
                ),
              ActionChip(
                key: customButtonKey,
                avatar: const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppTheme.inkDark,
                ),
                label: const Text('Custom'),
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? onCustomName : null,
              ),
            ],
          ),
          if (viewModel.canSimulatePartner) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: simulatePartnerButtonKey,
                onPressed: viewModel.isLoggingMeal ? null : viewModel.simulatePartnerFeed,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppTheme.inkDark, width: 1.8),
                  foregroundColor: AppTheme.inkDark,
                  backgroundColor: AppTheme.snoopCollarGold.withValues(
                    alpha: 0.25,
                  ),
                ),
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: Text(
                  'Simulate $partnerName Tap',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog prompting for a custom Scoop Holder display name (1–50 characters).
class CustomScoopHolderDialog extends StatefulWidget {
  const CustomScoopHolderDialog({
    super.key,
    required this.initialName,
    this.maxMemberNameLength = 50,
  });

  final String initialName;
  final int maxMemberNameLength;

  static const Key fieldKey = ValueKey<String>('pack_hq_custom_persona_field');
  static const Key saveKey = ValueKey<String>('pack_hq_custom_persona_save');

  @override
  State<CustomScoopHolderDialog> createState() => _CustomScoopHolderDialogState();
}

class _CustomScoopHolderDialogState extends State<CustomScoopHolderDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'Enter 1–50 characters.');
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Container(
          decoration: AppTheme.comicCardDecoration(
            color: AppTheme.pageBackground,
            borderRadius: 22,
            borderWidth: 2.5,
            shadowOffset: 4,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Custom Scoop Holder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.inkDark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: CustomScoopHolderDialog.fieldKey,
                  controller: _controller,
                  maxLength: widget.maxMemberNameLength,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'e.g. Mom, Sam',
                    counterText: '',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppTheme.snoopCoatBlack,
                    ),
                  ),
                ),
                if (_errorText != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: AppTheme.hungryPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: CustomScoopHolderDialog.saveKey,
                      onPressed: _submit,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

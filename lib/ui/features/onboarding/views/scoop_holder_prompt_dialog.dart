import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../../feeder/view_models/feeder_view_model.dart';

/// One-time prompt displayed on unbound devices so Keni, Ashley, or another
/// pack member can bind this phone to their Scoop Holder name.
class ScoopHolderPromptDialog extends StatefulWidget {
  const ScoopHolderPromptDialog({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key dialogKey = ValueKey<String>('scoop_holder_prompt_dialog');
  static const Key keniButtonKey = ValueKey<String>('scoop_holder_prompt_keni');
  static const Key ashleyButtonKey = ValueKey<String>(
    'scoop_holder_prompt_ashley',
  );
  static const Key customNameFieldKey = ValueKey<String>(
    'scoop_holder_prompt_custom_field',
  );
  static const Key customSubmitButtonKey = ValueKey<String>(
    'scoop_holder_prompt_custom_submit',
  );
  static const Key errorTextKey = ValueKey<String>('scoop_holder_prompt_error');

  @override
  State<ScoopHolderPromptDialog> createState() => _ScoopHolderPromptDialogState();
}

class _ScoopHolderPromptDialogState extends State<ScoopHolderPromptDialog> {
  final TextEditingController _customNameController = TextEditingController();
  bool _isSaving = false;
  bool _didBind = false;
  String? _validationError;

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _selectScoopHolder({
    required String uid,
    required String name,
  }) async {
    if (_isSaving || _didBind) return;
    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      await widget.viewModel.bindScoopHolder(uid: uid, name: name);
      if (mounted && !_didBind) {
        _didBind = true;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted && !_didBind) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _submitCustomName() async {
    final trimmed = _customNameController.text.trim();
    if (trimmed.isEmpty) {
      setState(
        () => _validationError = 'Please enter your name (1–50 characters).',
      );
      return;
    }

    final lower = trimmed.toLowerCase();
    final uid = lower == 'keni'
        ? InMemoryHouseholdRepository.keniUid
        : lower == 'ashley'
            ? InMemoryHouseholdRepository.ashleyUid
            : 'uid_${lower.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    await _selectScoopHolder(uid: uid, name: trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactHeight = screenSize.height < 680;
    final petName = widget.viewModel.household?.petName ?? 'Snoop';

    return PopScope(
      canPop: _didBind,
      child: Dialog(
        key: ScoopHolderPromptDialog.dialogKey,
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: isCompactHeight ? 12 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: screenSize.height * 0.88,
          ),
          child: Container(
            decoration: AppTheme.comicCardDecoration(
              color: AppTheme.pageBackground,
              borderColor: AppTheme.inkDark,
              borderRadius: 24,
              borderWidth: 3,
              shadowOffset: 5,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isCompactHeight ? 16 : 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SnoopMiniAvatar(
                        size: isCompactHeight ? 34 : 40,
                        isHappy: true,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Who holds this phone?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.inkDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompactHeight ? 6 : 10),
                  Text(
                    'Pick once so every 1-tap feed, Home Widget tap, and NFC '
                    'scan logs under your name for $petName.',
                    style: TextStyle(
                      fontSize: isCompactHeight ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.inkMuted,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: isCompactHeight ? 12 : 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton(
                          key: ScoopHolderPromptDialog.keniButtonKey,
                          onPressed: _isSaving
                              ? null
                              : () => _selectScoopHolder(
                                    uid: InMemoryHouseholdRepository.keniUid,
                                    name: 'Keni',
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.snoopCollarGold,
                            foregroundColor: AppTheme.inkDark,
                            padding: EdgeInsets.symmetric(
                              vertical: isCompactHeight ? 12 : 15,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppTheme.inkDark,
                                width: 2.2,
                              ),
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🥣 Keni',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: ScoopHolderPromptDialog.ashleyButtonKey,
                          onPressed: _isSaving
                              ? null
                              : () => _selectScoopHolder(
                                    uid: InMemoryHouseholdRepository.ashleyUid,
                                    name: 'Ashley',
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.fedPrimary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isCompactHeight ? 12 : 15,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppTheme.inkDark,
                                width: 2.2,
                              ),
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🐾 Ashley',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompactHeight ? 10 : 14),
                  const Text(
                    'Or someone else?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: ScoopHolderPromptDialog.customNameFieldKey,
                          controller: _customNameController,
                          enabled: !_isSaving,
                          maxLength: 50,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitCustomName(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: ScoopHolderPromptDialog.customSubmitButtonKey,
                        onPressed: _isSaving ? null : _submitCustomName,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.hungryPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: AppTheme.inkDark,
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  if (_validationError != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _validationError!,
                      key: ScoopHolderPromptDialog.errorTextKey,
                      style: const TextStyle(
                        color: AppTheme.hungryPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'You can switch anytime in Pack HQ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

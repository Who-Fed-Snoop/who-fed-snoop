import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';

/// Header card displayed at the top of Pack HQ showing pet name and household join code.
class PackHqHeaderCard extends StatelessWidget {
  const PackHqHeaderCard({
    super.key,
    required this.petName,
    required this.joinCode,
  });

  final String petName;
  final String joinCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 20,
        shadowOffset: 3,
      ),
      child: Row(
        children: <Widget>[
          const SnoopMiniAvatar(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        "🐾 $petName's Pack HQ",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: AppTheme.comicPillDecoration(
                        color: AppTheme.snoopCollarGold,
                        borderWidth: 1.5,
                      ),
                      child: Text(
                        'CODE: $joinCode',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.snoopCoatBlack,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Manage the humans responsible for all 90 lbs of floof',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Join-household / create-new-household form card inside Pack HQ.
class PackHqSetupFormCard extends StatelessWidget {
  const PackHqSetupFormCard({
    super.key,
    required this.isJoinMode,
    required this.isSubmitting,
    required this.localError,
    required this.nameController,
    required this.codeController,
    required this.petNameController,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final bool isJoinMode;
  final bool isSubmitting;
  final String? localError;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController petNameController;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;

  static const Key nameFieldKey = ValueKey<String>('onboarding_name_field');
  static const Key codeFieldKey = ValueKey<String>('onboarding_code_field');
  static const Key petNameFieldKey = ValueKey<String>(
    'onboarding_pet_name_field',
  );
  static const Key submitButtonKey = ValueKey<String>(
    'onboarding_submit_button',
  );
  static const Key errorBannerKey = ValueKey<String>('onboarding_error_banner');

  /// Maximum member display name length matching `firestore.rules` (`1..50`).
  static const int maxMemberNameLength = 50;

  /// Maximum pet display name length matching `firestore.rules` (`1..40`).
  static const int maxPetNameLength = 40;

  /// Standard household join code length (`6` uppercase alphanumeric chars).
  static const int joinCodeLength = 6;

  /// Validates the Pack HQ join/create form fields and returns a user-facing error or null.
  static String? validate({
    required bool isJoinMode,
    required String trimmedName,
    required String trimmedCode,
    required String trimmedPet,
  }) {
    if (trimmedName.isEmpty) {
      return 'Please enter your name (1–50 characters).';
    }
    if (trimmedName.length > maxMemberNameLength) {
      return 'Member name must be 50 characters or fewer.';
    }
    if (isJoinMode) {
      if (trimmedCode.isEmpty) {
        return 'Please enter a 6-character household code.';
      }
      return null;
    }
    if (trimmedPet.isEmpty) {
      return "Please enter your dog's name (1–40 characters).";
    }
    if (trimmedPet.length > maxPetNameLength) {
      return 'Pet name must be 40 characters or fewer.';
    }
    return null;
  }

  InputDecoration _comicInputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      counterText: '',
      prefixIcon: Icon(prefixIcon, color: AppTheme.snoopCoatBlack),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: AppTheme.inkMuted,
        fontWeight: FontWeight.w700,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.inkDark, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.hungryPrimary, width: 2.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.inkDark, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 22,
        shadowOffset: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.vpn_key_outlined, size: 18),
                label: Text(
                  'Join Code',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.pets, size: 18),
                label: Text(
                  'New Pet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            selected: <bool>{isJoinMode},
            onSelectionChanged: isSubmitting ? null : (selection) => onModeChanged(selection.first),
          ),
          const SizedBox(height: 14),
          TextField(
            key: nameFieldKey,
            controller: nameController,
            enabled: !isSubmitting,
            maxLength: maxMemberNameLength,
            style: const TextStyle(fontWeight: FontWeight.w700),
            decoration: _comicInputDecoration(
              labelText: 'Your Name (e.g. Keni or Ashley)',
              prefixIcon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 12),
          if (isJoinMode)
            TextField(
              key: codeFieldKey,
              controller: codeController,
              enabled: !isSubmitting,
              maxLength: joinCodeLength,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              decoration: _comicInputDecoration(
                labelText: '6-Character Household Code',
                hintText: 'SNOOP4',
                prefixIcon: Icons.tag,
              ),
            )
          else
            TextField(
              key: petNameFieldKey,
              controller: petNameController,
              enabled: !isSubmitting,
              maxLength: maxPetNameLength,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: _comicInputDecoration(
                labelText: "Dog's Name",
                hintText: 'Snoop',
                prefixIcon: Icons.pets_outlined,
              ),
            ),
          if (localError != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              key: errorBannerKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.comicCardDecoration(
                color: AppTheme.snoopTonguePink.withValues(alpha: 0.18),
                borderRadius: 12,
                borderWidth: 1.5,
                shadowOffset: 2,
              ),
              child: Text(
                localError!,
                style: const TextStyle(
                  color: AppTheme.inkDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            key: submitButtonKey,
            onPressed: isSubmitting ? null : onSubmit,
            icon: Icon(
              isJoinMode ? Icons.group_add_outlined : Icons.add_home_outlined,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.hungryPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.inkDark, width: 2),
              ),
            ),
            label: Text(
              isSubmitting
                  ? (isJoinMode ? 'Joining...' : 'Creating...')
                  : (isJoinMode ? 'Join Household' : 'Create Household'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/deep_link_route.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../../feeder/view_models/feeder_view_model.dart';
import '../../settings/views/household_settings_sheet.dart';

/// Modal bottom sheet allowing Keni or Ashley to configure meal schedules & treat goals,
/// create/join a household, or copy their Partner Invite Link, NFC Food-Bin Sticker URL,
/// and Dog Sitter Web Pass.
class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key sheetKey = ValueKey<String>('onboarding_sheet');
  static const Key scheduleSettingsCardKey = ValueKey<String>(
    'onboarding_schedule_settings_card',
  );
  static const Key openScheduleSettingsButtonKey = ValueKey<String>(
    'onboarding_open_schedule_settings_button',
  );
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

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  bool _isJoinMode = true;
  bool _isSubmitting = false;
  bool _didPop = false;
  bool _isOpeningSettings = false;
  String? _localError;

  late final TextEditingController _nameController;
  late final TextEditingController _petNameController;
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    final initialMember = widget.viewModel.currentMemberName.trim();
    final initialPet = widget.viewModel.household?.petName.trim() ?? '';
    final initialCode = widget.viewModel.household?.joinCode.trim() ?? '';

    _nameController = TextEditingController(
      text: _truncate(
        initialMember.isEmpty ? 'Keni' : initialMember,
        OnboardingSheet.maxMemberNameLength,
      ),
    );
    _petNameController = TextEditingController(
      text: _truncate(
        initialPet.isEmpty ? 'Snoop' : initialPet,
        OnboardingSheet.maxPetNameLength,
      ),
    );
    _codeController = TextEditingController(
      text: _truncate(
        initialCode.isEmpty ? 'SNOOP4' : initialCode,
        OnboardingSheet.joinCodeLength,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _petNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  static String _cleanErrorMessage(Object error) {
    final raw = error.toString().trim();
    const badStatePrefix = 'Bad state: ';
    if (raw.startsWith(badStatePrefix)) {
      return raw.substring(badStatePrefix.length).trim();
    }
    const argPrefix = 'Invalid argument(s): ';
    if (raw.startsWith(argPrefix)) {
      return raw.substring(argPrefix.length).trim();
    }
    return raw;
  }

  static String _formatScheduleSummary(MealSchedule schedule) {
    final windows = schedule.enabledWindows;
    if (windows.isEmpty) {
      return '🥣 Breakfast • 🍖 Dinner';
    }
    return windows.map((w) => '${w.emoji} ${w.label}').join(' • ');
  }

  Future<void> _openScheduleSettings(
    BuildContext context,
    String petName,
  ) async {
    if (_isOpeningSettings || _isSubmitting || _didPop) return;
    _isOpeningSettings = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HouseholdSettingsSheet(
          petName: petName,
          initialSchedule: widget.viewModel.schedule,
          initialDailyTreatLimit: widget.viewModel.dailyTreatLimit,
          todayLoggedWindowIds: widget.viewModel.todayLoggedWindowIds,
          onSave: (schedule, dailyTreatLimit) {
            return widget.viewModel.updateHouseholdSettings(
              schedule: schedule,
              dailyTreatLimit: dailyTreatLimit,
            );
          },
        ),
      );
    } finally {
      _isOpeningSettings = false;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _didPop) return;

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(
        () => _localError = 'Please enter your name (1–50 characters).',
      );
      return;
    }
    if (trimmedName.length > OnboardingSheet.maxMemberNameLength) {
      setState(
        () => _localError = 'Member name must be 50 characters or fewer.',
      );
      return;
    }

    final trimmedCode = _codeController.text.trim().toUpperCase();
    final trimmedPet = _petNameController.text.trim();

    if (_isJoinMode) {
      if (trimmedCode.isEmpty) {
        setState(
          () => _localError = 'Please enter a 6-character household code.',
        );
        return;
      }
    } else {
      if (trimmedPet.isEmpty) {
        setState(
          () => _localError = "Please enter your dog's name (1–40 characters).",
        );
        return;
      }
      if (trimmedPet.length > OnboardingSheet.maxPetNameLength) {
        setState(
          () => _localError = 'Pet name must be 40 characters or fewer.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      if (_isJoinMode) {
        await widget.viewModel.joinHousehold(
          joinCode: trimmedCode,
          memberName: trimmedName,
        );
      } else {
        await widget.viewModel.createNewHousehold(
          memberName: trimmedName,
          petName: trimmedPet,
        );
      }
      if (mounted && !_didPop) {
        _didPop = true;
        Navigator.of(context).pop();
      }
    } on Object catch (e) {
      if (mounted && !_didPop) {
        setState(() => _localError = _cleanErrorMessage(e));
      }
    } finally {
      if (mounted && !_didPop) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _copyLink(String label, Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied $label: $uri')),
      );
    }
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
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final household = widget.viewModel.household;
        final rawPetName = household?.petName.trim() ?? '';
        final petName = rawPetName.isEmpty ? 'Snoop' : rawPetName;
        final joinCode = household?.joinCode ?? 'SNOOP4';
        final householdId = household?.id ?? 'household_snoop_01';

        final scheduleSummary = _formatScheduleSummary(
          widget.viewModel.schedule,
        );
        final dailyTreatLimit = widget.viewModel.dailyTreatLimit;

        final joinUri = WhofedsnoopDeepLink.buildJoinUri(joinCode);
        final nfcTapUri = WhofedsnoopDeepLink.buildNfcTapUri(householdId);
        final sitterUri = WhofedsnoopDeepLink.buildSitterPassUri(joinCode);

        final screenHeight = MediaQuery.sizeOf(context).height;

        return Container(
          key: OnboardingSheet.sheetKey,
          constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
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
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Playful top drag handle
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
                const SizedBox(height: 16),

                // Header with SnoopMiniAvatar + title + goofy subtitle
                Container(
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
                ),
                const SizedBox(height: 14),

                // Meal Windows & Treat Goal Neo-Brutalist Summary Card
                _ScheduleAndTreatGoalCard(
                  cardKey: OnboardingSheet.scheduleSettingsCardKey,
                  buttonKey: OnboardingSheet.openScheduleSettingsButtonKey,
                  scheduleSummary: scheduleSummary,
                  dailyTreatLimit: dailyTreatLimit,
                  enabled: !_isSubmitting,
                  onConfigure: () => _openScheduleSettings(context, petName),
                ),
                const SizedBox(height: 16),

                // Mode switcher + Form container
                Container(
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
                        selected: <bool>{_isJoinMode},
                        onSelectionChanged: _isSubmitting
                            ? null
                            : (selection) {
                                setState(() {
                                  _isJoinMode = selection.first;
                                  _localError = null;
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: OnboardingSheet.nameFieldKey,
                        controller: _nameController,
                        enabled: !_isSubmitting,
                        maxLength: OnboardingSheet.maxMemberNameLength,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        decoration: _comicInputDecoration(
                          labelText: 'Your Name (e.g. Keni or Ashley)',
                          prefixIcon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isJoinMode)
                        TextField(
                          key: OnboardingSheet.codeFieldKey,
                          controller: _codeController,
                          enabled: !_isSubmitting,
                          maxLength: OnboardingSheet.joinCodeLength,
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
                          key: OnboardingSheet.petNameFieldKey,
                          controller: _petNameController,
                          enabled: !_isSubmitting,
                          maxLength: OnboardingSheet.maxPetNameLength,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          decoration: _comicInputDecoration(
                            labelText: "Dog's Name",
                            hintText: 'Snoop',
                            prefixIcon: Icons.pets_outlined,
                          ),
                        ),
                      if (_localError != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          key: OnboardingSheet.errorBannerKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: AppTheme.comicCardDecoration(
                            color: AppTheme.snoopTonguePink.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: 12,
                            borderWidth: 1.5,
                            shadowOffset: 2,
                          ),
                          child: Text(
                            _localError!,
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
                        key: OnboardingSheet.submitButtonKey,
                        onPressed: _isSubmitting ? null : _submit,
                        icon: Icon(
                          _isJoinMode ? Icons.group_add_outlined : Icons.add_home_outlined,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.hungryPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: AppTheme.inkDark,
                              width: 2,
                            ),
                          ),
                        ),
                        label: Text(
                          _isSubmitting
                              ? (_isJoinMode ? 'Joining...' : 'Creating...')
                              : (_isJoinMode ? 'Join Household' : 'Create Household'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Smart Links Section Header
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: AppTheme.comicPillDecoration(
                        color: AppTheme.snoopCollarGold,
                        borderWidth: 1.8,
                      ),
                      child: const Text(
                        'TAP TO COPY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppTheme.snoopCoatBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'whofedsnoop.com Smart Links (Tap to Copy)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 1. Partner Invite Link Card
                _SmartPassCard(
                  icon: Icons.person_add_alt_1_outlined,
                  badgeLabel: 'PACK INVITE',
                  badgeColor: AppTheme.hungrySurface,
                  accentColor: AppTheme.hungryPrimary,
                  title: 'Partner Invite Link',
                  subtitle: joinUri.toString(),
                  onTap: () => _copyLink('Partner Invite Link', joinUri),
                ),
                const SizedBox(height: 10),

                // 2. NFC Food-Bin Sticker URL Card
                _SmartPassCard(
                  icon: Icons.nfc,
                  badgeLabel: 'KIBBLE BIN',
                  badgeColor: AppTheme.fedSurface,
                  accentColor: AppTheme.fedPrimary,
                  title: 'NFC Food-Bin Sticker URL',
                  subtitle: nfcTapUri.toString(),
                  onTap: () => _copyLink('NFC Tag URL', nfcTapUri),
                ),
                const SizedBox(height: 10),

                // 3. Dog Sitter Web Pass Card
                _SmartPassCard(
                  icon: Icons.badge_outlined,
                  badgeLabel: 'VIP SITTER',
                  badgeColor: AppTheme.snoopSkyAccent.withValues(alpha: 0.2),
                  accentColor: AppTheme.snoopCoatBlack,
                  title: 'Dog Sitter Web Pass',
                  subtitle: sitterUri.toString(),
                  onTap: () => _copyLink('Dog Sitter Web Pass', sitterUri),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleAndTreatGoalCard extends StatelessWidget {
  const _ScheduleAndTreatGoalCard({
    required this.cardKey,
    required this.buttonKey,
    required this.scheduleSummary,
    required this.dailyTreatLimit,
    required this.enabled,
    required this.onConfigure,
  });

  final Key cardKey;
  final Key buttonKey;
  final String scheduleSummary;
  final int dailyTreatLimit;
  final bool enabled;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: cardKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onConfigure : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.comicCardDecoration(
            color: AppTheme.creamCard,
            borderRadius: 20,
            borderWidth: 2,
            shadowOffset: 3,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '⚙️ Meal Windows & Treat Goal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scheduleSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: AppTheme.comicPillDecoration(
                        color: AppTheme.hungrySurface,
                        borderWidth: 1.5,
                      ),
                      child: Text(
                        '🦴 $dailyTreatLimit treats/day',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: buttonKey,
                onPressed: enabled ? onConfigure : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.snoopCollarGold,
                  foregroundColor: AppTheme.snoopCoatBlack,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppTheme.inkDark, width: 1.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12.5,
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

class _SmartPassCard extends StatelessWidget {
  const _SmartPassCard({
    required this.icon,
    required this.badgeLabel,
    required this.badgeColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String badgeLabel;
  final Color badgeColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.comicCardDecoration(
            color: AppTheme.creamCard,
            borderRadius: 18,
            borderWidth: 2,
            shadowOffset: 3,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.inkDark, width: 2),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppTheme.inkDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: AppTheme.comicPillDecoration(
                            color: badgeColor,
                            borderWidth: 1.4,
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.inkDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.snoopCollarGold.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.inkDark, width: 1.5),
                ),
                child: const Icon(
                  Icons.copy,
                  size: 16,
                  color: AppTheme.snoopCoatBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

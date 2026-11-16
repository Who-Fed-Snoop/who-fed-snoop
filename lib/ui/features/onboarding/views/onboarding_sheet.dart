import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/repositories/household_state_policy.dart';
import '../../../../domain/models/deep_link_route.dart';
import '../../../core/app_theme.dart';
import '../../feeder/view_models/feeder_view_model.dart';
import '../../settings/views/household_settings_sheet.dart';
import '../widgets/pack_hq_header_and_form.dart';
import '../widgets/pack_hq_info_cards.dart';
import '../widgets/scoop_holder_card.dart';

export '../widgets/pack_hq_header_and_form.dart' show PackHqHeaderCard, PackHqSetupFormCard;
export '../widgets/pack_hq_info_cards.dart'
    show PackHqSmartLinksSection, ScheduleAndTreatGoalCard, SmartPassCard;
export '../widgets/scoop_holder_card.dart' show CustomScoopHolderDialog, ScoopHolderCard;

/// Modal bottom sheet allowing Keni or Ashley to configure meal schedules & treat goals,
/// switch the device Scoop Holder, create/join a household, or copy Smart Links.
class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key sheetKey = ValueKey<String>('onboarding_sheet');
  static const Key scoopHolderCardKey = ScoopHolderCard.cardKey;
  static const Key keniPersonaChipKey = ScoopHolderCard.keniChipKey;
  static const Key ashleyPersonaChipKey = ScoopHolderCard.ashleyChipKey;
  static const Key customPersonaChipKey = ScoopHolderCard.customChipKey;
  static const Key customPersonaButtonKey = ScoopHolderCard.customButtonKey;
  static const Key customPersonaDialogFieldKey = CustomScoopHolderDialog.fieldKey;
  static const Key customPersonaDialogSaveKey = CustomScoopHolderDialog.saveKey;
  static const Key simulatePartnerButtonKey = ScoopHolderCard.simulatePartnerButtonKey;
  static const Key scheduleSettingsCardKey = ScheduleAndTreatGoalCard.defaultCardKey;
  static const Key openScheduleSettingsButtonKey = ScheduleAndTreatGoalCard.defaultButtonKey;
  static const Key nameFieldKey = PackHqSetupFormCard.nameFieldKey;
  static const Key codeFieldKey = PackHqSetupFormCard.codeFieldKey;
  static const Key petNameFieldKey = PackHqSetupFormCard.petNameFieldKey;
  static const Key submitButtonKey = PackHqSetupFormCard.submitButtonKey;
  static const Key errorBannerKey = PackHqSetupFormCard.errorBannerKey;

  /// Maximum member display name length matching `firestore.rules` (`1..50`).
  static const int maxMemberNameLength = PackHqSetupFormCard.maxMemberNameLength;

  /// Maximum pet display name length matching `firestore.rules` (`1..40`).
  static const int maxPetNameLength = PackHqSetupFormCard.maxPetNameLength;

  /// Standard household join code length (`6` uppercase alphanumeric chars).
  static const int joinCodeLength = PackHqSetupFormCard.joinCodeLength;

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
    final vm = widget.viewModel;
    _nameController = TextEditingController(
      text: HouseholdStatePolicy.sanitizeName(
        vm.currentMemberName,
        fallback: 'Keni',
        maxLength: OnboardingSheet.maxMemberNameLength,
      ),
    );
    _petNameController = TextEditingController(
      text: HouseholdStatePolicy.sanitizeName(
        vm.household?.petName ?? '',
        fallback: 'Snoop',
        maxLength: OnboardingSheet.maxPetNameLength,
      ),
    );
    _codeController = TextEditingController(
      text: HouseholdStatePolicy.sanitizeName(
        vm.household?.joinCode ?? '',
        fallback: 'SNOOP4',
        maxLength: OnboardingSheet.joinCodeLength,
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

  static String _cleanErrorMessage(Object error) {
    final raw = error.toString().trim();
    for (final prefix in const <String>[
      'Bad state: ',
      'Invalid argument(s): ',
    ]) {
      if (raw.startsWith(prefix)) {
        return raw.substring(prefix.length).trim();
      }
    }
    return raw;
  }

  Future<void> _selectScoopHolder({
    required String uid,
    required String name,
  }) async {
    if (_isSubmitting || _didPop) return;
    await widget.viewModel.switchActiveMember(uid: uid, name: name);
    if (!mounted) return;
    _nameController.text = HouseholdStatePolicy.sanitizeName(
      widget.viewModel.currentMemberName,
      fallback: 'Member',
      maxLength: OnboardingSheet.maxMemberNameLength,
    );
  }

  Future<void> _openCustomScoopHolderDialog() async {
    if (_isSubmitting || _didPop) return;
    final current = widget.viewModel.currentMemberName.trim();
    final initialText = (current == 'Keni' || current == 'Ashley') ? '' : current;

    final chosenName = await showDialog<String>(
      context: context,
      builder: (_) => CustomScoopHolderDialog(
        initialName: initialText,
        maxMemberNameLength: OnboardingSheet.maxMemberNameLength,
      ),
    );

    if (chosenName == null || !mounted) return;
    final uid = HouseholdStatePolicy.resolveInMemoryUidForName(chosenName);
    await _selectScoopHolder(uid: uid, name: chosenName);
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
          onSave: (schedule, dailyTreatLimit) => widget.viewModel.updateHouseholdSettings(
            schedule: schedule,
            dailyTreatLimit: dailyTreatLimit,
          ),
        ),
      );
    } finally {
      _isOpeningSettings = false;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _didPop) return;

    final trimmedName = _nameController.text.trim();
    final trimmedCode = _codeController.text.trim().toUpperCase();
    final trimmedPet = _petNameController.text.trim();
    final validationError = PackHqSetupFormCard.validate(
      isJoinMode: _isJoinMode,
      trimmedName: trimmedName,
      trimmedCode: trimmedCode,
      trimmedPet: trimmedPet,
    );
    if (validationError != null) {
      setState(() => _localError = validationError);
      return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Copied $label: $uri')));
    }
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

        return Container(
          key: OnboardingSheet.sheetKey,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
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
                PackHqHeaderCard(petName: petName, joinCode: joinCode),
                const SizedBox(height: 14),
                ScoopHolderCard(
                  viewModel: widget.viewModel,
                  enabled: !_isSubmitting,
                  onSelectMember: _selectScoopHolder,
                  onCustomName: _openCustomScoopHolderDialog,
                ),
                const SizedBox(height: 14),
                ScheduleAndTreatGoalCard(
                  cardKey: OnboardingSheet.scheduleSettingsCardKey,
                  buttonKey: OnboardingSheet.openScheduleSettingsButtonKey,
                  schedule: widget.viewModel.schedule,
                  dailyTreatLimit: widget.viewModel.dailyTreatLimit,
                  enabled: !_isSubmitting,
                  onConfigure: () => _openScheduleSettings(context, petName),
                ),
                const SizedBox(height: 16),
                PackHqSetupFormCard(
                  isJoinMode: _isJoinMode,
                  isSubmitting: _isSubmitting,
                  localError: _localError,
                  nameController: _nameController,
                  codeController: _codeController,
                  petNameController: _petNameController,
                  onModeChanged: (isJoin) => setState(() {
                    _isJoinMode = isJoin;
                    _localError = null;
                  }),
                  onSubmit: _submit,
                ),
                const SizedBox(height: 20),
                PackHqSmartLinksSection(
                  joinUri: WhofedsnoopDeepLink.buildJoinUri(joinCode),
                  nfcTapUri: WhofedsnoopDeepLink.buildNfcTapUri(householdId),
                  sitterUri: WhofedsnoopDeepLink.buildSitterPassUri(joinCode),
                  onCopyLink: _copyLink,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/deep_link_route.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../../feeder/view_models/feeder_view_model.dart';

/// Modal bottom sheet allowing Keni or Ashley to create/join a household,
/// or copy their Partner Invite Link, NFC Food-Bin Sticker URL, and Dog Sitter Web Pass.
class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  bool _isJoinMode = true;
  final TextEditingController _nameController = TextEditingController(
    text: 'Ashley',
  );
  final TextEditingController _petNameController = TextEditingController(
    text: 'Snoop',
  );
  final TextEditingController _codeController = TextEditingController(
    text: 'SNOOP4',
  );
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _petNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    try {
      if (_isJoinMode) {
        await widget.viewModel.joinHousehold(
          joinCode: _codeController.text,
          memberName: _nameController.text,
        );
      } else {
        await widget.viewModel.createNewHousehold(
          memberName: _nameController.text,
          petName: _petNameController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (e) {
      setState(() => _localError = e.toString());
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
    final household = widget.viewModel.household;
    final joinCode = household?.joinCode ?? 'SNOOP4';
    final householdId = household?.id ?? 'household_snoop_01';

    final joinUri = WhofedsnoopDeepLink.buildJoinUri(joinCode);
    final nfcTapUri = WhofedsnoopDeepLink.buildNfcTapUri(householdId);
    final sitterUri = WhofedsnoopDeepLink.buildSitterPassUri(joinCode);

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
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                            const Flexible(
                              child: Text(
                                "🐾 Snoop's Pack HQ",
                                style: TextStyle(
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
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isJoinMode = selection.first;
                        _localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: _comicInputDecoration(
                      labelText: 'Your Name (e.g. Keni or Ashley)',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isJoinMode)
                    TextField(
                      controller: _codeController,
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
                      controller: _petNameController,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: AppTheme.comicCardDecoration(
                        color: AppTheme.snoopTonguePink.withValues(alpha: 0.18),
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
                    onPressed: _submit,
                    icon: Icon(
                      _isJoinMode
                          ? Icons.group_add_outlined
                          : Icons.add_home_outlined,
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
                      _isJoinMode ? 'Join Household' : 'Create Household',
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

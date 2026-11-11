import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/deep_link_route.dart';
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

  @override
  Widget build(BuildContext context) {
    final household = widget.viewModel.household;
    final joinCode = household?.joinCode ?? 'SNOOP4';
    final householdId = household?.id ?? 'household_snoop_01';

    final joinUri = WhofedsnoopDeepLink.buildJoinUri(joinCode);
    final nfcTapUri = WhofedsnoopDeepLink.buildNfcTapUri(householdId);
    final sitterUri = WhofedsnoopDeepLink.buildSitterPassUri(joinCode);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  '🐾 Household & Links',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Join Code'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('New Pet'),
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
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name (e.g. Keni or Ashley)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_isJoinMode)
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '6-Character Household Code',
                  hintText: 'SNOOP4',
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextField(
                controller: _petNameController,
                decoration: const InputDecoration(
                  labelText: "Dog's Name",
                  hintText: 'Snoop',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_localError != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _localError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isJoinMode ? 'Join Household' : 'Create Household',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 32),
            const Text(
              'whofedsnoop.com Smart Links (Tap to Copy)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Partner Invite Link'),
              subtitle: Text(joinUri.toString()),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: () => _copyLink('Partner Invite Link', joinUri),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.nfc),
              title: const Text('NFC Food-Bin Sticker URL'),
              subtitle: Text(nfcTapUri.toString()),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: () => _copyLink('NFC Tag URL', nfcTapUri),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Dog Sitter Web Pass'),
              subtitle: Text(sitterUri.toString()),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: () => _copyLink('Dog Sitter Web Pass', sitterUri),
            ),
          ],
        ),
      ),
    );
  }
}

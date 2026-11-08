import 'package:flutter/material.dart';

import '../../feeder/view_models/feeder_view_model.dart';

/// Modal bottom sheet allowing Keni or Ashley to create a household or join
/// via the 6-character Household Join Code (`SNOOP4`).
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                '🐾 Household Setup',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: true, label: Text('Join Code')),
                  ButtonSegment<bool>(value: false, label: Text('New Pet')),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isJoinMode ? 'Join Household' : 'Create Household',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}


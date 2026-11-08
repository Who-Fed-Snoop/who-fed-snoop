import 'package:flutter/material.dart';

import 'data/repositories/household_repository.dart';
import 'data/services/widget_sync_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/feeder/view_models/feeder_view_model.dart';
import 'ui/features/feeder/views/feeder_view.dart';

void main() {
  final repository = InMemoryHouseholdRepository();
  final widgetSyncService = WidgetSyncService();
  final viewModel = FeederViewModel(
    repository: repository,
    widgetSyncService: widgetSyncService,
  );

  runApp(WhoFedSnoopApp(viewModel: viewModel));
}

class WhoFedSnoopApp extends StatelessWidget {
  const WhoFedSnoopApp({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Who Fed Snoop?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FeederView(viewModel: viewModel),
    );
  }
}


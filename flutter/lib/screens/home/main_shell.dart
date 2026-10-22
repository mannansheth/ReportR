import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/network/api_client.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../services/prediction_service.dart';
import '../analytics/analytics_screen.dart';
import 'camera_home_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = AppConstants.defaultTabIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(l10n, _currentIndex))),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MapScreen(
            isActive: _currentIndex == 0,
            session: widget.controller.session,
            authToken: widget.controller.authToken,
          ),
          ReportsScreen(
            session: widget.controller.session,
            authToken: widget.controller.authToken,
            isActive: _currentIndex == 1,
          ),
          CameraHomeScreen(
            isActive: _currentIndex == 2,
            predictionService: PredictionService(
              ApiClient(authToken: widget.controller.authToken),
            ),
            sessionName: widget.controller.session?.name,
            session: widget.controller.session,
            authToken: widget.controller.authToken,
            preferences: widget.controller.preferencesService,
          ),
          AnalyticsScreen(
            session: widget.controller.session,
            authToken: widget.controller.authToken,
            isActive: _currentIndex == 3,
          ),
          ProfileScreen(
            controller: widget.controller,
            isActive: _currentIndex == 4,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  String _titleForIndex(AppLocalizations l10n, int index) {
    return switch (index) {
      0 => l10n.navMap,
      1 => l10n.navReports,
      2 => l10n.navHome,
      3 => l10n.navAnalytics,
      4 => l10n.navProfile,
      _ => l10n.navHome,
    };
  }
}

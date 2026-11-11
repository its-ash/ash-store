import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'config.dart';
import 'store_controller.dart';
import 'widgets.dart';

/// Settings tab: store info, then updates for Ash Store itself and developer
/// info (the last two groups, as in every app).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: UiAppBar(title: 'Settings', backgroundColor: context.colors.surface),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: UiSpace.lg),
        children: [
          UiListGroup(
            header: 'Store',
            children: [
              UiListTile(
                'Refresh app list',
                icon: Icons.refresh_rounded,
                trailing: store.loading ? const UiSpinner() : null,
                onTap: store.loading ? null : () => store.refresh(force: true),
              ),
              UiListTile('Website', icon: Icons.public_rounded, chevron: true, onTap: () => openUrl(StoreConfig.website)),
              UiListTile(
                'Open-source licences',
                icon: Icons.description_rounded,
                chevron: true,
                onTap: () => showLicensePage(context: context, applicationName: 'Ash Store'),
              ),
            ],
          ),
          const SizedBox(height: UiSpace.lg),
          const UiUpdateSection(storeId: 'ash-store'),
          const SizedBox(height: UiSpace.lg),
          const UiDeveloperSection(),
        ],
      ),
    );
  }
}

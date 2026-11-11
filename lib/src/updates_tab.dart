import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'models.dart';
import 'widgets.dart';

/// Updates tab, "Manage apps" style: pending updates with Update all, then
/// the apps already installed.
class UpdatesTab extends StatelessWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.lg, UiSpace.page, UiSpace.sm),
            child: Semantics(header: true, child: Text('Manage apps', style: context.text.headlineSmall)),
          ),
          Expanded(
            child: CatalogGate(
              builder: (context, store, apps) {
                final updates = [for (final a in apps) if (store.stateOf(a) == AppState.updateAvailable) a];
                final installed = [for (final a in apps) if (store.stateOf(a) == AppState.installed) a];
                final busy = updates.any((a) => store.isDownloading(a) || store.isInstalling(a));
                return UiRefresh(
                  onRefresh: () => store.refresh(force: true),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: UiSpace.xxl),
                    children: [
                      const StoreNotices(),
                      if (updates.isEmpty && installed.isEmpty)
                        const SizedBox(
                          height: 360,
                          child: UiEmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Everything is up to date',
                            message: 'Apps you install from Ash Store show up here.',
                          ),
                        ),
                      if (updates.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.xs, UiSpace.page, UiSpace.xs),
                          child: Row(children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text('Updates available (${updates.length})', style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const UiGap(UiSpace.sm),
                            UiButton('Update all', size: UiSize.sm, onPressed: busy ? null : () => updateAll(context)),
                          ]),
                        ),
                        for (final a in updates)
                          AppRowTile(a, subtitle: 'v${store.installed[a.package]?.name ?? '?'} → v${a.release!.version}'),
                        const SizedBox(height: UiSpace.lg),
                      ] else if (installed.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(UiSpace.page, UiSpace.xs, UiSpace.page, UiSpace.md),
                          child: UiAlert('All your apps are up to date.', status: UiStatus.success),
                        ),
                      if (installed.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.xs, UiSpace.page, UiSpace.xs),
                          child: Semantics(header: true, child: Text('Installed (${installed.length})', style: context.text.titleMedium)),
                        ),
                        for (final a in installed) AppRowTile(a, subtitle: 'v${store.installed[a.package]?.name ?? ''} · ${UiFormat.relativeTime(a.release?.publishedAt ?? DateTime.now())}'),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

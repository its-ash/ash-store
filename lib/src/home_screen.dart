import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'app_screen.dart';
import 'config.dart';
import 'models.dart';
import 'packages.dart';
import 'store_controller.dart';
import 'widgets.dart';

enum _Filter { all, installed, updates }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final catalog = store.catalog;

    return Scaffold(
      appBar: UiAppBar(
        title: 'Ash Store',
        actions: [
          UiIconButton(
            Icons.refresh_rounded,
            tooltip: 'Refresh',
            loading: store.loading,
            onPressed: () => store.refresh(force: true),
          ),
          UiIconButton(Icons.public_rounded, tooltip: 'Website', onPressed: () => openUrl(StoreConfig.website)),
        ],
      ),
      body: catalog == null
          ? store.error != null
              ? UiErrorState(message: store.error, onRetry: () => store.refresh(force: true))
              : const UiSkeletonList(count: 6)
          : UiRefresh(onRefresh: () => store.refresh(force: true), child: _list(context, store, catalog.error)),
    );
  }

  Widget _list(BuildContext context, StoreController store, String? staleError) {
    final self = store.apps.where((a) => a.isSelf).firstOrNull;
    final updates = store.updates;
    final q = _query.toLowerCase();
    final apps = store.apps.where((a) {
      if (a.isSelf) return false;
      final state = store.stateOf(a);
      if (_filter == _Filter.installed && state != AppState.installed && state != AppState.updateAvailable) return false;
      if (_filter == _Filter.updates && state != AppState.updateAvailable) return false;
      if (q.isEmpty) return true;
      return '${a.name} ${a.manifest.tagline} ${a.manifest.category}'.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.xxl),
      children: [
        if (staleError != null) ...[
          UiAlert('Showing saved list. $staleError', status: UiStatus.warning),
          const UiGap(UiSpace.md),
        ],
        if (!store.canInstall) ...[
          UiAlert(
            'Android needs your OK before Ash Store can install apps. You only do this once.',
            title: 'Allow installs',
            status: UiStatus.info,
            action: Align(
              alignment: Alignment.centerLeft,
              child: UiButton('Open settings', size: UiSize.sm, variant: UiButtonVariant.soft, onPressed: Packages.openInstallSettings),
            ),
          ),
          const UiGap(UiSpace.md),
        ],
        if (self != null && store.stateOf(self) == AppState.updateAvailable) ...[
          UiAlert(
            'Ash Store ${self.release!.version} is ready.',
            title: 'Store update',
            status: UiStatus.accent,
            action: Align(alignment: Alignment.centerLeft, child: InstallButton(self)),
          ),
          const UiGap(UiSpace.md),
        ],
        UiSearchField(hint: 'Search apps', onChanged: (v) => setState(() => _query = v)),
        const UiGap(UiSpace.md),
        UiChoiceChips<_Filter>(
          value: _filter,
          onChanged: (v) => setState(() => _filter = v),
          options: [
            const UiChoice(_Filter.all, 'All'),
            const UiChoice(_Filter.installed, 'Installed'),
            UiChoice(_Filter.updates, updates.isEmpty ? 'Updates' : 'Updates (${updates.length})'),
          ],
        ),
        const UiGap(UiSpace.lg),
        if (apps.isEmpty)
          UiEmptyState(
            compact: true,
            icon: Icons.apps_rounded,
            title: switch (_filter) {
              _Filter.updates => 'Everything is up to date',
              _Filter.installed => 'No store apps installed yet',
              _Filter.all => q.isEmpty ? 'No apps listed yet' : 'No apps match "$_query"',
            },
          )
        else
          for (final app in apps) ...[
            _AppRow(app),
            const UiGap(UiSpace.sm),
          ],
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow(this.app);
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final release = app.release;
    return UiCard(
      padding: const EdgeInsets.all(UiSpace.md),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AppScreen(app))),
      child: Row(
        children: [
          AppIcon(app),
          const UiGap(UiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(app.name, style: context.text.titleMedium, overflow: TextOverflow.ellipsis)),
                  const UiGap(UiSpace.xs),
                  AppStatePill(app),
                ]),
                if (app.manifest.tagline.isNotEmpty)
                  Text(app.manifest.tagline, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const UiGap(UiSpace.xxs),
                Text(
                  [
                    app.manifest.category,
                    if (release != null) 'v${release.version}',
                    if (release?.apkSize != null) UiFormat.bytes(release!.apkSize!),
                  ].join(' · '),
                  style: context.text.labelSmall?.copyWith(color: context.colors.textSubtle),
                ),
              ],
            ),
          ),
          const UiGap(UiSpace.sm),
          InstallButton(app),
        ],
      ),
    );
  }
}

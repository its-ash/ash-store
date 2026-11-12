import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'browse.dart';
import 'category_screen.dart';
import 'models.dart';
import 'store_controller.dart';
import 'widgets.dart';

/// Apps tab: search bar, "For you / Top charts / Categories" tabs. For you lists
/// every app in one list; browsing by category lives in the Categories tab.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key, required this.onSearch, required this.onSettings});

  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _SearchBar(onSearch: widget.onSearch, onSettings: widget.onSettings),
          UiTabs(
            tabs: const ['For you', 'Top charts', 'Categories'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: CatalogGate(
              builder: (context, store, apps) => UiRefresh(
                onRefresh: () => store.refresh(force: true),
                child: AnimatedSwitcher(
                  duration: context.motion(UiMotion.normal),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      0 => _ForYou(apps),
                      1 => _TopCharts(apps),
                      _ => _Categories(apps),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded search pill with the store avatar (opens settings) on the right.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onSearch, required this.onSettings});
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(UiSpace.lg, UiSpace.sm, UiSpace.lg, UiSpace.md),
      child: Material(
        color: c.surfaceMuted,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSearch,
          child: Semantics(
            button: true,
            label: 'Search apps',
            excludeSemantics: true,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const UiGap(UiSpace.lg),
                  Icon(Icons.search_rounded, color: c.textMuted),
                  const UiGap(UiSpace.md),
                  Expanded(child: Text('Search apps', style: context.text.bodyLarge?.copyWith(color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Semantics(
                    button: true,
                    label: 'Settings',
                    child: InkResponse(
                      onTap: onSettings,
                      radius: 26,
                      child: Padding(
                        padding: const EdgeInsets.all(UiSpace.sm + 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // Pixel-art logo: nearest-neighbour scaling keeps the cells crisp.
                          child: Image.asset('assets/icon/logo-1024.png', width: 32, height: 32, filterQuality: FilterQuality.none),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForYou extends StatelessWidget {
  const _ForYou(this.apps);
  final List<StoreApp> apps;

  @override
  Widget build(BuildContext context) {
    final recent = recentlyUpdated(apps);
    final all = allByName(apps);
    return ListView(
      padding: const EdgeInsets.only(top: UiSpace.sm, bottom: UiSpace.xxl),
      children: [
        const StoreNotices(),
        if (apps.isEmpty)
          const SizedBox(height: 360, child: UiEmptyState(icon: Icons.apps_rounded, title: 'No apps listed yet', message: 'Pull down to refresh.'))
        else ...[
          if (recent.isNotEmpty) _FeaturedCard(recent.first),
          const SizedBox(height: UiSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: UiSectionHeader('All apps', subtitle: '${all.length} apps'),
          ),
          for (final a in all) AppRowTile(a),
        ],
      ],
    );
  }
}

/// Big card for the newest app, tinted with the accent.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard(this.app);
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tagline = app.manifest.tagline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
      child: Material(
        color: c.accentSoft,
        borderRadius: UiRadius.all(UiRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openApp(context, app),
          child: Semantics(
            container: true,
            label: 'Featured. ${app.name}. $tagline',
            child: Padding(
              padding: const EdgeInsets.all(UiSpace.lg),
              child: Row(
                children: [
                  AppIcon(app, size: 76),
                  const UiGap(UiSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEW & UPDATED', style: context.text.labelSmall?.copyWith(color: c.onAccentSoft, letterSpacing: 0.8)),
                        const UiGap(UiSpace.xs),
                        Text(app.name, style: context.text.titleLarge?.copyWith(color: c.onAccentSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (tagline.isNotEmpty)
                          Text(tagline, style: context.text.bodySmall?.copyWith(color: c.onAccentSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const UiGap(UiSpace.sm),
                        InstallButton(app),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCharts extends StatelessWidget {
  const _TopCharts(this.apps);
  final List<StoreApp> apps;

  @override
  Widget build(BuildContext context) {
    final ranked = topCharts(apps);
    return ListView(
      padding: const EdgeInsets.only(bottom: UiSpace.xxl),
      children: [
        const StoreNotices(),
        if (ranked.isEmpty)
          const SizedBox(height: 360, child: UiEmptyState(icon: Icons.leaderboard_outlined, title: 'No apps listed yet', message: 'Pull down to refresh.'))
        else
          for (var i = 0; i < ranked.length; i++) AppRowTile(ranked[i], rank: i + 1),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories(this.apps);
  final List<StoreApp> apps;

  @override
  Widget build(BuildContext context) {
    final categories = byCategory(apps);
    return ListView(
      padding: const EdgeInsets.only(top: UiSpace.sm, bottom: UiSpace.xxl),
      children: [
        if (categories.isEmpty)
          const SizedBox(height: 360, child: UiEmptyState(icon: Icons.category_outlined, title: 'No categories yet', message: 'Pull down to refresh.'))
        else
          UiListGroup(
            children: [
              for (final e in categories.entries)
                UiListTile(
                  e.key,
                  icon: categoryIcon(e.key),
                  value: '${e.value.length}',
                  chevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CategoryScreen(e.key))),
                ),
            ],
          ),
      ],
    );
  }
}

/// Count of apps that have an update, for the nav badge.
int updateCount(StoreController store) => store.updates.where((a) => !a.isSelf).length;

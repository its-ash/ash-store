import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'browse.dart';
import 'models.dart';
import 'packages.dart';
import 'store_controller.dart';
import 'widgets.dart';

/// Details of one app, laid out like a store page: header, stats, install
/// button, screenshots, about, what's new, links and similar apps.
class AppScreen extends StatelessWidget {
  const AppScreen(this.initial, {super.key});
  final StoreApp initial;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Use the freshest copy after a refresh.
    final app = store.apps.where((a) => a.id == initial.id).firstOrNull ?? initial;
    final release = app.release;
    final have = store.installed[app.package];
    final m = app.manifest;
    final c = context.colors;
    final shots = app.screenshotUrls;
    final similar = similarTo(app, browsable(store.apps));

    return Scaffold(
      backgroundColor: c.surface,
      appBar: UiAppBar(title: '', backgroundColor: c.surface),
      body: ListView(
        padding: const EdgeInsets.only(bottom: UiSpace.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppIcon(app, size: 88),
              const UiGap(UiSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text(app.name, style: context.text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const UiGap(UiSpace.xs),
                  Text('Ash Store', style: context.text.labelLarge?.copyWith(color: c.accent)),
                  const UiGap(UiSpace.xxs),
                  Text(m.category, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: UiSpace.lg),
          _Stats(app),
          const SizedBox(height: UiSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: _Actions(app, installed: have != null),
          ),
          if (shots.isNotEmpty) ...[
            const SizedBox(height: UiSpace.xl),
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
                itemCount: shots.length,
                separatorBuilder: (_, _) => const SizedBox(width: UiSpace.sm),
                itemBuilder: (_, i) => Semantics(
                  image: true,
                  label: 'Screenshot ${i + 1} of ${shots.length}',
                  child: UiImage(shots[i], width: 158, height: 280, radius: UiRadius.md),
                ),
              ),
            ),
          ],
          const SizedBox(height: UiSpace.xl),
          _AboutRow(app),
          if (release != null && release.notes.isNotEmpty) ...[
            const SizedBox(height: UiSpace.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text("What's new", style: context.text.titleMedium)),
                const UiGap(UiSpace.xxs),
                Text('v${release.version} · ${UiFormat.relativeTime(release.publishedAt)}', style: context.text.bodySmall),
                const UiGap(UiSpace.sm),
                UiExpandableText(release.notes, maxLines: 6, style: context.text.bodyMedium),
              ]),
            ),
          ],
          const SizedBox(height: UiSpace.xl),
          UiListGroup(
            header: 'App info',
            children: [
              UiListTile('Latest version', value: release == null ? 'No release' : 'v${release.version}'),
              UiListTile('Installed', value: have == null ? 'Not installed' : 'v${have.name}'),
              UiListTile('Package', value: app.package),
              UiListTile('Website', icon: Icons.public_rounded, chevron: true, onTap: () => openUrl(app.homepage)),
              UiListTile('Source on GitHub', icon: Icons.code_rounded, chevron: true, onTap: () => openUrl(app.htmlUrl)),
              if (release != null && release.htmlUrl.isNotEmpty)
                UiListTile('All releases', icon: Icons.history_rounded, chevron: true, onTap: () => openUrl('${app.htmlUrl}/releases')),
            ],
          ),
          const SizedBox(height: UiSpace.xl),
          AppCarousel(title: 'Similar apps', apps: similar),
        ],
      ),
    );
  }
}

/// Version · size · category · updated, separated by hairlines. Scrolls
/// sideways on narrow screens instead of overflowing.
class _Stats extends StatelessWidget {
  const _Stats(this.app);
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final r = app.release;
    final cells = [
      (r == null ? '—' : 'v${r.version}', 'Version'),
      (r?.apkSize == null ? '—' : UiFormat.bytes(r!.apkSize!), 'Size'),
      (app.manifest.category, 'Category'),
      (r == null ? '—' : UiFormat.relativeTime(r.publishedAt), 'Updated'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const VerticalDivider(width: UiSpace.xl, thickness: 1),
              Semantics(
                container: true,
                label: '${cells[i].$2}: ${cells[i].$1}',
                excludeSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 64, maxWidth: 140),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(cells[i].$1, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: UiSpace.xxs),
                    Text(cells[i].$2, style: context.text.bodySmall),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width primary action. Installed apps get Uninstall + Open/Update.
class _Actions extends StatelessWidget {
  const _Actions(this.app, {required this.installed});
  final StoreApp app;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final progress = store.downloads[app.id];
    final main = InstallButton(app, expand: true, size: UiSize.md);
    return Column(children: [
      if (installed && !app.isSelf)
        Row(children: [
          Expanded(
            child: UiButton(
              'Uninstall',
              size: UiSize.md,
              expand: true,
              variant: UiButtonVariant.outline,
              onPressed: () => Packages.uninstall(app.package),
            ),
          ),
          const UiGap(UiSpace.md),
          Expanded(child: main),
        ])
      else
        SizedBox(width: double.infinity, child: main),
      if (store.isDownloading(app)) ...[
        const SizedBox(height: UiSpace.md),
        UiProgressBar(progress, label: 'Downloading ${app.name}'),
      ],
    ]);
  }
}

/// "About this app ->" row with the tagline; opens the full description.
class _AboutRow extends StatelessWidget {
  const _AboutRow(this.app);
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final m = app.manifest;
    final text = m.description.isNotEmpty ? m.description : m.tagline;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        button: true,
        label: 'About this app',
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page, vertical: UiSpace.sm),
            child: Row(children: [
              Expanded(child: Text('About this app', style: context.text.titleMedium)),
              Icon(Icons.arrow_forward_rounded, size: 20, color: context.colors.textMuted),
            ]),
          ),
        ),
      ),
      if (text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
          child: Text(text, style: context.text.bodyMedium, maxLines: 4, overflow: TextOverflow.ellipsis),
        ),
    ]);
  }

  void _open(BuildContext context) {
    final m = app.manifest;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(UiSpace.page, 0, UiSpace.page, UiSpace.xxl),
          children: [
            Text('About this app', style: ctx.text.titleLarge),
            const SizedBox(height: UiSpace.md),
            if (m.tagline.isNotEmpty) Text(m.tagline, style: ctx.text.titleSmall),
            if (m.tagline.isNotEmpty) const SizedBox(height: UiSpace.sm),
            Text(m.description.isEmpty ? 'No description yet.' : m.description, style: ctx.text.bodyMedium),
            const SizedBox(height: UiSpace.lg),
            Text('${m.category} · ${app.package}', style: ctx.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

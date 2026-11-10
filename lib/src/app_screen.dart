import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'models.dart';
import 'packages.dart';
import 'store_controller.dart';
import 'widgets.dart';

/// Details of one app: install/update, versions, release notes and links.
class AppScreen extends StatelessWidget {
  const AppScreen(this.app, {super.key});
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final release = app.release;
    final have = store.installed[app.package];
    final m = app.manifest;

    return UiScaffold(
      appBar: UiAppBar(title: app.name),
      scrollable: true,
      maxWidth: 720,
      body: UiColumn(
        gap: UiSpace.lg,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            AppIcon(app, size: 72),
            const UiGap(UiSpace.lg),
            Expanded(
              child: UiColumn(gap: UiSpace.xs, children: [
                Text(app.name, style: context.text.headlineSmall),
                if (m.tagline.isNotEmpty) Text(m.tagline, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
                AppStatePill(app),
              ]),
            ),
          ]),
          UiRow(children: [
            Expanded(child: InstallButton(app, expand: true, size: UiSize.md)),
            if (have != null && !app.isSelf)
              UiIconButton(
                Icons.delete_outline_rounded,
                tooltip: 'Uninstall',
                variant: UiButtonVariant.outline,
                onPressed: () => Packages.uninstall(app.package),
              ),
          ]),
          if (m.description.isNotEmpty) Text(m.description, style: context.text.bodyMedium),
          UiListGroup(
            inset: true,
            children: [
              UiListTile('Latest version', value: release == null ? 'No release' : 'v${release.version}'),
              UiListTile('Installed', value: have == null ? 'Not installed' : 'v${have.name}'),
              if (release?.apkSize != null) UiListTile('Download size', value: UiFormat.bytes(release!.apkSize!)),
              if (release != null) UiListTile('Released', value: UiFormat.relativeTime(release.publishedAt)),
              UiListTile('Category', value: m.category),
              UiListTile('Package', value: app.package),
            ],
          ),
          if (release != null && release.notes.isNotEmpty)
            UiSection(
              title: "What's new in v${release.version}",
              child: UiExpandableText(release.notes, maxLines: 6, style: context.text.bodyMedium),
            ),
          UiListGroup(
            inset: true,
            children: [
              UiListTile('Website', icon: Icons.public_rounded, chevron: true, onTap: () => openUrl(app.homepage)),
              UiListTile('Source on GitHub', icon: Icons.code_rounded, chevron: true, onTap: () => openUrl(app.htmlUrl)),
              if (release != null && release.htmlUrl.isNotEmpty)
                UiListTile('All releases', icon: Icons.history_rounded, chevron: true, onTap: () => openUrl('${app.htmlUrl}/releases')),
            ],
          ),
        ],
      ),
    );
  }
}

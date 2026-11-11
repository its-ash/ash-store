import 'package:flutter/material.dart';
import 'package:theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_screen.dart';
import 'browse.dart';
import 'models.dart';
import 'packages.dart';
import 'store_controller.dart';

/// Rounded-square (squircle) app icon from the repo, with the name's
/// initials as fallback.
class AppIcon extends StatelessWidget {
  const AppIcon(this.app, {super.key, this.size = 52});

  final StoreApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = UiAvatar(name: app.name, diameter: size, shape: UiAvatarShape.rounded);
    final url = app.iconUrl;
    return Semantics(
      image: true,
      label: '${app.name} icon',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: url == null ? fallback : UiImage(url, width: size, height: size, radius: size * 0.2, errorWidget: fallback),
      ),
    );
  }
}

/// Install / Update / Open button with download progress.
class InstallButton extends StatelessWidget {
  const InstallButton(this.app, {super.key, this.expand = false, this.size = UiSize.sm, this.outlined = false});

  final StoreApp app;
  final bool expand;
  final UiSize size;

  /// Play-style outlined button for list rows (Install / Update).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.isDownloading(app)) {
      final p = store.downloads[app.id];
      final label = p == null ? 'Downloading' : '${(p * 100).round()}%';
      return UiButton(label, size: size, expand: expand, variant: UiButtonVariant.soft, loading: p == null, onPressed: null);
    }
    if (store.isInstalling(app)) {
      return UiButton('Installing', size: size, expand: expand, variant: UiButtonVariant.soft, loading: true, onPressed: null);
    }
    final variant = outlined ? UiButtonVariant.outline : UiButtonVariant.primary;
    final status = outlined ? UiStatus.accent : null;
    return switch (store.stateOf(app)) {
      AppState.notInstalled => UiButton('Install', size: size, expand: expand, variant: variant, status: status, onPressed: () => runInstall(context, app)),
      AppState.updateAvailable => UiButton('Update', size: size, expand: expand, variant: variant, status: status, onPressed: () => runInstall(context, app)),
      AppState.installed => UiButton('Open', size: size, expand: expand, variant: UiButtonVariant.secondary, onPressed: app.isSelf ? null : () => Packages.launch(app.package)),
      AppState.unavailable => UiButton('No release', size: size, expand: expand, variant: UiButtonVariant.outline, onPressed: null),
    };
  }
}

/// Downloads and installs [app], explaining the "Install unknown apps"
/// permission when Android has not granted it yet.
Future<InstallResult> runInstall(BuildContext context, StoreApp app) async {
  final store = StoreScope.of(context);
  final result = await store.install(app);
  if (!context.mounted) return result;
  switch (result) {
    case InstallResult.started:
      break;
    case InstallResult.needsPermission:
      final ok = await UiDialog.confirm(
        context,
        title: 'Allow Ash Store to install apps',
        message: 'Ash Store installs apps itself, so Android needs your OK once: '
            'turn on "Allow from this source" for Ash Store, then come back. '
            '${app.name} will install right after. The first install of each app '
            'shows one Android confirmation; later updates install silently on Android 12 and newer.',
        confirmLabel: 'Open settings',
        cancelLabel: 'Not now',
        icon: Icons.verified_user_outlined,
      );
      if (ok) {
        await Packages.openInstallSettings();
      } else {
        store.cancelPending();
      }
    case InstallResult.unavailable:
      context.showToast('${app.name} has no APK in its latest release yet.', status: UiStatus.warning);
    case InstallResult.failed:
      context.showToast(
        'Download or install failed. If an older copy was signed with a different key, uninstall it first.',
        title: 'Could not install ${app.name}',
        status: UiStatus.danger,
      );
  }
  return result;
}

/// Updates every app with a new version, one after the other.
Future<void> updateAll(BuildContext context) async {
  final store = StoreScope.of(context);
  for (final app in store.updates) {
    if (!context.mounted) return;
    final result = await runInstall(context, app);
    if (result != InstallResult.started) return;
  }
}

Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void openApp(BuildContext context, StoreApp app) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AppScreen(app)));

/// Row of a ranked / plain vertical list: [rank], icon, name, line, button.
class AppRowTile extends StatelessWidget {
  const AppRowTile(this.app, {super.key, this.rank, this.subtitle});

  final StoreApp app;
  final int? rank;

  /// Replaces the "category · size" line.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final line = subtitle ?? categorySizeLine(app);
    return Semantics(
      container: true,
      label: '${app.name}. $line',
      child: InkWell(
        onTap: () => openApp(context, app),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.page, vertical: UiSpace.sm + 2),
          child: Row(
            children: [
              if (rank != null) ...[
                SizedBox(
                  width: 22,
                  child: Text('$rank', textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(color: context.colors.textMuted)),
                ),
                const UiGap(UiSpace.sm),
              ],
              AppIcon(app, size: 56),
              const UiGap(UiSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const UiGap(UiSpace.xxs),
                    Text(line, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const UiGap(UiSpace.sm),
              InstallButton(app, outlined: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square card of a horizontal carousel: icon, name, category · size.
class AppCard extends StatelessWidget {
  const AppCard(this.app, {super.key});
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: '${app.name}. ${categorySizeLine(app)}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: UiRadius.all(UiRadius.md),
        onTap: () => openApp(context, app),
        child: SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(app, size: 84),
              const UiGap(UiSpace.sm),
              Text(app.name, style: context.text.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              const UiGap(UiSpace.xxs),
              Text(categorySizeLine(app), style: context.text.labelSmall?.copyWith(color: context.colors.textSubtle), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled horizontal row of [AppCard]s. Its height follows its content.
class AppCarousel extends StatelessWidget {
  const AppCarousel({super.key, required this.title, required this.apps, this.onMore});

  final String title;
  final List<StoreApp> apps;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: InkWell(
            onTap: onMore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.page, vertical: UiSpace.sm),
              child: Row(children: [
                Expanded(child: Text(title, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (onMore != null) Icon(Icons.arrow_forward_rounded, size: 20, color: context.colors.textMuted),
              ]),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in apps) ...[AppCard(a), const UiGap(UiSpace.md)],
            ],
          ),
        ),
        const UiGap(UiSpace.lg),
      ],
    );
  }
}

/// Notices at the top of a list: stale data, install permission, store update.
class StoreNotices extends StatelessWidget {
  const StoreNotices({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final self = store.apps.where((a) => a.isSelf).firstOrNull;
    final stale = store.catalog?.error;
    final children = <Widget>[
      if (stale != null) UiAlert('Showing saved list. $stale', status: UiStatus.warning),
      if (!store.canInstall)
        UiAlert(
          'Ash Store installs apps itself, so Android needs your OK once. After that, updates install without a prompt on Android 12+.',
          title: 'Allow installs',
          status: UiStatus.info,
          action: Align(
            alignment: Alignment.centerLeft,
            child: UiButton('Open settings', size: UiSize.sm, variant: UiButtonVariant.soft, onPressed: Packages.openInstallSettings),
          ),
        ),
      if (self != null && store.stateOf(self) == AppState.updateAvailable)
        UiAlert(
          'Ash Store ${self.release!.version} is ready.',
          title: 'Store update',
          status: UiStatus.accent,
          action: Align(alignment: Alignment.centerLeft, child: InstallButton(self)),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.md),
      child: Column(children: [
        for (final c in children) ...[c, if (c != children.last) const UiGap(UiSpace.sm)],
      ]),
    );
  }
}

/// Shows a skeleton or an error until the catalog is there, then [builder]
/// with the apps to list (the store itself excluded).
class CatalogGate extends StatelessWidget {
  const CatalogGate({super.key, required this.builder});
  final Widget Function(BuildContext context, StoreController store, List<StoreApp> apps) builder;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.catalog == null) {
      if (store.error != null) {
        return UiErrorState(message: store.error, onRetry: () => store.refresh(force: true));
      }
      return const StoreSkeleton();
    }
    return builder(context, store, browsable(store.apps));
  }
}

/// Loading placeholder shaped like the home screen.
class StoreSkeleton extends StatelessWidget {
  const StoreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row() => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
          child: Row(children: [
            for (var i = 0; i < 4; i++) ...[
              const SizedBox(
                width: 100,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  UiSkeleton.box(width: 84, height: 84, radius: 17),
                  UiGap(UiSpace.sm),
                  UiSkeleton(width: 80),
                  UiGap(UiSpace.xs),
                  UiSkeleton(width: 56, height: 10),
                ]),
              ),
              const UiGap(UiSpace.md),
            ],
          ]),
        );
    return Semantics(
      label: 'Loading apps',
      child: UiShimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: UiSpace.sm),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: UiSpace.page),
              child: UiSkeleton.box(height: 150, radius: 18),
            ),
            const SizedBox(height: UiSpace.xl),
            row(),
            const SizedBox(height: UiSpace.xl),
            row(),
          ],
        ),
      ),
    );
  }
}

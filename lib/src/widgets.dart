import 'package:flutter/material.dart';
import 'package:theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'packages.dart';
import 'store_controller.dart';

/// Square app icon from the repo, with the name's initials as fallback.
class AppIcon extends StatelessWidget {
  const AppIcon(this.app, {super.key, this.size = 52});

  final StoreApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = UiAvatar(name: app.name, diameter: size, shape: UiAvatarShape.rounded);
    final url = app.iconUrl;
    if (url == null) return fallback;
    return SizedBox.square(
      dimension: size,
      child: UiImage(url, width: size, height: size, radius: size * 0.24, errorWidget: fallback),
    );
  }
}

/// Install / Update / Open button with download progress.
class InstallButton extends StatelessWidget {
  const InstallButton(this.app, {super.key, this.expand = false, this.size = UiSize.sm});

  final StoreApp app;
  final bool expand;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.isDownloading(app)) {
      final p = store.downloads[app.id];
      final label = p == null ? 'Downloading' : '${(p * 100).round()}%';
      return UiButton(label, size: size, expand: expand, variant: UiButtonVariant.soft, loading: p == null, onPressed: null);
    }
    return switch (store.stateOf(app)) {
      AppState.notInstalled => UiButton('Install', size: size, expand: expand, onPressed: () => runInstall(context, app)),
      AppState.updateAvailable => UiButton('Update', size: size, expand: expand, icon: Icons.system_update_alt_rounded, onPressed: () => runInstall(context, app)),
      AppState.installed => UiButton('Open', size: size, expand: expand, variant: UiButtonVariant.secondary, onPressed: app.isSelf ? null : () => Packages.launch(app.package)),
      AppState.unavailable => UiButton('No release', size: size, expand: expand, variant: UiButtonVariant.outline, onPressed: null),
    };
  }
}

/// Small pill showing the app's state on this device.
class AppStatePill extends StatelessWidget {
  const AppStatePill(this.app, {super.key});
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return switch (store.stateOf(app)) {
      AppState.updateAvailable => const UiStatusPill('Update', status: UiStatus.warning, dot: true),
      AppState.installed => const UiStatusPill('Installed', status: UiStatus.success, dot: true),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Downloads and installs [app], explaining the "Install unknown apps"
/// permission when Android has not granted it yet.
Future<void> runInstall(BuildContext context, StoreApp app) async {
  final store = StoreScope.of(context);
  final result = await store.install(app);
  if (!context.mounted) return;
  switch (result) {
    case InstallResult.started:
      break;
    case InstallResult.needsPermission:
      final ok = await UiDialog.confirm(
        context,
        title: 'Allow Ash Store to install apps',
        message: 'Android asks before an app can install other apps. '
            'Turn on "Allow from this source" for Ash Store, then come back. '
            '${app.name} will install right after.',
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
}

Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

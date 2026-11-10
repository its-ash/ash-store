import 'package:flutter/services.dart';

import 'models.dart';

/// Android package manager calls, implemented in `MainActivity.kt`.
class Packages {
  Packages._();

  static const _channel = MethodChannel('com.itsash.store/packages');

  static Future<InstalledVersion?> installed(String package) async {
    final m = await _channel.invokeMapMethod<String, Object?>('installedVersion', {'package': package});
    if (m == null) return null;
    return InstalledVersion(m['versionName'] as String? ?? '', (m['versionCode'] as num?)?.toInt() ?? 0);
  }

  /// Whether "Install unknown apps" is allowed for the store.
  static Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  static Future<void> openInstallSettings() => _channel.invokeMethod('openInstallSettings');

  /// Opens the system installer for an APK in `<cache>/apks/`.
  static Future<bool> install(String path) async =>
      await _channel.invokeMethod<bool>('install', {'path': path}) ?? false;

  static Future<bool> launch(String package) async =>
      await _channel.invokeMethod<bool>('launch', {'package': package}) ?? false;

  static Future<void> uninstall(String package) => _channel.invokeMethod('uninstall', {'package': package});
}

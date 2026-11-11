import 'dart:async';

import 'package:flutter/services.dart';

import 'models.dart';

/// Result of a PackageInstaller session, reported by Android after `install`.
class InstallOutcome {
  const InstallOutcome({required this.package, required this.success, this.message = ''});

  final String package;
  final bool success;
  final String message;
}

/// What the store needs from Android. [MethodChannelPackages] is the real one;
/// tests plug in a fake through [Packages.bridge].
abstract class PackageBridge {
  Future<InstalledVersion?> installed(String package);
  Future<bool> canInstall();
  Future<void> openInstallSettings();

  /// Streams the APK at [path] into a PackageInstaller session and commits it.
  /// Returns false if it could not be started. The final result arrives on [results].
  Future<bool> install(String path, String package);
  Future<bool> launch(String package);
  Future<void> uninstall(String package);

  /// Install outcomes (success or failure) pushed from the platform.
  Stream<InstallOutcome> get results;
}

/// Android implementation, backed by `MainActivity.kt`.
class MethodChannelPackages implements PackageBridge {
  MethodChannelPackages() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'installResult') return;
      final m = Map<String, Object?>.from(call.arguments as Map);
      _results.add(InstallOutcome(
        package: m['package'] as String? ?? '',
        success: m['success'] as bool? ?? false,
        message: m['message'] as String? ?? '',
      ));
    });
  }

  static const _channel = MethodChannel('com.itsash.store/packages');
  final _results = StreamController<InstallOutcome>.broadcast();

  @override
  Stream<InstallOutcome> get results => _results.stream;

  @override
  Future<InstalledVersion?> installed(String package) async {
    final m = await _channel.invokeMapMethod<String, Object?>('installedVersion', {'package': package});
    if (m == null) return null;
    return InstalledVersion(m['versionName'] as String? ?? '', (m['versionCode'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallSettings() => _channel.invokeMethod('openInstallSettings');

  @override
  Future<bool> install(String path, String package) async =>
      await _channel.invokeMethod<bool>('install', {'path': path, 'package': package}) ?? false;

  @override
  Future<bool> launch(String package) async =>
      await _channel.invokeMethod<bool>('launch', {'package': package}) ?? false;

  @override
  Future<void> uninstall(String package) => _channel.invokeMethod('uninstall', {'package': package});
}

/// Static entry point used by the app. Swap [bridge] in tests.
class Packages {
  Packages._();

  static PackageBridge? _bridge;

  static PackageBridge get bridge => _bridge ??= MethodChannelPackages();
  static set bridge(PackageBridge value) => _bridge = value;

  static Future<InstalledVersion?> installed(String package) => bridge.installed(package);

  /// Whether "Install unknown apps" is allowed for the store.
  static Future<bool> canInstall() => bridge.canInstall();

  static Future<void> openInstallSettings() => bridge.openInstallSettings();

  /// Installs an APK from `<cache>/apks/` through a PackageInstaller session.
  static Future<bool> install(String path, String package) => bridge.install(path, package);

  static Future<bool> launch(String package) => bridge.launch(package);

  static Future<void> uninstall(String package) => bridge.uninstall(package);

  static Stream<InstallOutcome> get results => bridge.results;
}

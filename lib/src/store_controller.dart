import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'models.dart';
import 'packages.dart';

enum InstallResult { started, needsPermission, unavailable, failed }

/// App-wide state: the catalog, installed versions, the install permission
/// and running downloads.
class StoreController extends ChangeNotifier with WidgetsBindingObserver {
  StoreController({CatalogService? service, http.Client? client})
      : _service = service ?? CatalogService(),
        _client = client ?? http.Client();

  final CatalogService _service;
  final http.Client _client;

  Catalog? catalog;
  bool loading = false;

  /// Set when there is no catalog at all to show.
  String? error;

  /// Installed version per package id. Missing or null means not installed.
  final Map<String, InstalledVersion?> installed = {};

  /// Whether Android lets the store install apps ("Install unknown apps").
  bool canInstall = true;

  /// Download progress per app id: 0..1, or null while the size is unknown.
  final Map<String, double?> downloads = {};

  /// App ids whose PackageInstaller session is running (until Android reports back).
  final Set<String> installing = {};

  final _outcomes = StreamController<(StoreApp, InstallOutcome)>.broadcast();
  StreamSubscription<InstallOutcome>? _resultSub;

  /// Finished installs (success or failure), so the UI can show a message.
  Stream<(StoreApp, InstallOutcome)> get outcomes => _outcomes.stream;

  /// App to install once the user grants the install permission.
  StoreApp? _pending;

  List<StoreApp> get apps => catalog?.apps ?? const [];

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    listenForResults();
    final cached = await _service.cached();
    if (cached != null) {
      catalog = cached;
      notifyListeners();
      await refreshInstalled();
    }
    await refresh();
  }

  /// Starts listening to install results from Android. Called by [init].
  void listenForResults() {
    _resultSub ??= Packages.results.listen(_onResult);
  }

  Future<void> _onResult(InstallOutcome o) async {
    final app = apps.where((a) => a.package == o.package).firstOrNull;
    if (app != null) installing.remove(app.id);
    notifyListeners();
    await refreshInstalled();
    if (app != null && !_outcomes.isClosed) _outcomes.add((app, o));
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _outcomes.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    refreshInstalled().then((_) {
      final app = _pending;
      if (app != null && canInstall) {
        _pending = null;
        install(app);
      }
    });
  }

  Future<void> refresh({bool force = false}) async {
    loading = true;
    notifyListeners();
    try {
      catalog = await _service.load(force: force);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
    await refreshInstalled();
  }

  Future<void> refreshInstalled() async {
    try {
      canInstall = await Packages.canInstall();
      for (final app in apps) {
        installed[app.package] = await Packages.installed(app.package);
      }
    } catch (_) {
      // Not on Android (tests, desktop): treat everything as not installed.
    }
    notifyListeners();
  }

  AppState stateOf(StoreApp app) {
    final have = installed[app.package];
    final release = app.release;
    if (have == null) return app.downloadable ? AppState.notInstalled : AppState.unavailable;
    if (release != null && app.downloadable && compareVersions(release.version, have.name) > 0) {
      return AppState.updateAvailable;
    }
    return AppState.installed;
  }

  List<StoreApp> get updates => [for (final a in apps) if (stateOf(a) == AppState.updateAvailable) a];

  bool isDownloading(StoreApp app) => downloads.containsKey(app.id);

  bool isInstalling(StoreApp app) => installing.contains(app.id);

  /// Downloads the latest APK and installs it with a PackageInstaller session
  /// (no dialog for updates on Android 12+, one confirm for a first install).
  /// The final result arrives later through [outcomes]. Returns
  /// [InstallResult.needsPermission] when "Install unknown apps" is off; the
  /// install then continues by itself once the user turns it on.
  Future<InstallResult> install(StoreApp app) async {
    final release = app.release;
    if (release?.apkUrl == null) return InstallResult.unavailable;
    if (isDownloading(app) || isInstalling(app)) return InstallResult.started;
    try {
      canInstall = await Packages.canInstall();
    } catch (_) {}
    if (!canInstall) {
      _pending = app;
      notifyListeners();
      return InstallResult.needsPermission;
    }
    try {
      final file = await _download(app, release!);
      installing.add(app.id);
      notifyListeners();
      if (await Packages.install(file.path, app.package)) return InstallResult.started;
      installing.remove(app.id);
      notifyListeners();
      return InstallResult.failed;
    } catch (_) {
      installing.remove(app.id);
      notifyListeners();
      return InstallResult.failed;
    }
  }

  void cancelPending() => _pending = null;

  Future<File> _download(StoreApp app, StoreRelease release) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/apks');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${app.id}-${release.tag}.apk');
    if (await file.exists() && (release.apkSize == null || await file.length() == release.apkSize)) {
      return file;
    }
    // Drop APKs of older versions of this app.
    await for (final f in dir.list()) {
      if (f is File && f.uri.pathSegments.last.startsWith('${app.id}-')) await f.delete();
    }

    downloads[app.id] = null;
    notifyListeners();
    final part = File('${file.path}.part');
    try {
      final res = await _client.send(http.Request('GET', Uri.parse(release.apkUrl!)));
      if (res.statusCode != 200) throw HttpException('Download failed (${res.statusCode})');
      final total = res.contentLength ?? release.apkSize;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            final p = received / total;
            // Notify once per percent, not once per chunk.
            if ((p * 100).floor() != ((downloads[app.id] ?? -1) * 100).floor()) {
              downloads[app.id] = p;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }
      return await part.rename(file.path);
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    } finally {
      downloads.remove(app.id);
      notifyListeners();
    }
  }
}

/// Gives widgets access to the [StoreController].
class StoreScope extends InheritedNotifier<StoreController> {
  const StoreScope({super.key, required StoreController controller, required super.child})
      : super(notifier: controller);

  static StoreController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

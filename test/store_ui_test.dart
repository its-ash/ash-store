import 'dart:async';

import 'package:ash_store/main.dart';
import 'package:ash_store/src/browse.dart';
import 'package:ash_store/src/catalog.dart';
import 'package:ash_store/src/models.dart';
import 'package:ash_store/src/packages.dart';
import 'package:ash_store/src/store_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme/theme.dart';

class _NoNetwork extends CatalogService {
  @override
  Future<Catalog?> cached() async => null;
  @override
  Future<Catalog> load({bool force = false}) async => throw CatalogException('offline');
}

class FakePackages implements PackageBridge {
  final versions = <String, InstalledVersion?>{};
  final installs = <(String, String)>[];
  bool allowed = true;
  final _results = StreamController<InstallOutcome>.broadcast();

  void emit(InstallOutcome o) => _results.add(o);

  @override
  Stream<InstallOutcome> get results => _results.stream;
  @override
  Future<InstalledVersion?> installed(String package) async => versions[package];
  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<bool> install(String path, String package) async {
    installs.add((path, package));
    return true;
  }
  @override
  Future<bool> launch(String package) async => true;
  @override
  Future<void> uninstall(String package) async {}
}

StoreApp app(
  String id, {
  String category = 'Tools',
  int stars = 0,
  String? version = '1.0.0',
  int day = 1,
  String description = '',
  String tagline = 'Tagline',
  List<String> screenshots = const [],
}) =>
    StoreApp(
      repo: id,
      branch: 'main',
      htmlUrl: 'https://github.com/its-ash/$id',
      stars: stars,
      manifest: StoreManifest.fromJson({
        'id': id,
        'name': id[0].toUpperCase() + id.substring(1),
        'package': 'com.itsash.$id',
        'category': category,
        'tagline': tagline,
        'description': description,
        'screenshots': screenshots,
      }),
      release: version == null
          ? null
          : StoreRelease(
              tag: 'v$version',
              notes: 'Fixes',
              publishedAt: DateTime(2026, 1, day),
              htmlUrl: 'https://github.com/its-ash/$id/releases/v$version',
              apkUrl: 'https://x/$id.apk',
              apkSize: 2 * 1024 * 1024,
            ),
    );

final apps = [
  app('alpha', category: 'Tools', stars: 5, day: 3, description: 'Cleans things'),
  app('beta', category: 'Tools', stars: 9, day: 2),
  app('gamma', category: 'Health & Fitness', stars: 1, day: 5),
  app('delta', category: 'Utilities', day: 4),
];

StoreController controllerWith(List<StoreApp> list, {Map<String, String> installed = const {}}) {
  final c = StoreController(service: _NoNetwork());
  c.catalog = Catalog(list, DateTime.now());
  for (final e in installed.entries) {
    c.installed[e.key] = InstalledVersion(e.value, 1);
  }
  return c;
}

/// Two frames: the first finishes a transition, the second removes the old page.
Future<void> step(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> pumpStore(WidgetTester tester, StoreController c) async {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AshStoreApp(store: c));
  await step(tester);
}

void main() {
  setUpAll(() => UiTypography.useGoogleFonts = false);

  group('browse helpers', () {
    test('searchApps filters name, tagline, description', () {
      expect(searchApps(apps, 'ALPHA').map((a) => a.id), ['alpha']);
      expect(searchApps(apps, 'cleans').map((a) => a.id), ['alpha']);
      expect(searchApps(apps, 'tagline'), hasLength(4));
      expect(searchApps(apps, ''), hasLength(4));
      expect(searchApps(apps, 'zzz'), isEmpty);
    });

    test('topCharts ranks by stars, byCategory by size, similarTo skips self', () {
      expect(topCharts(apps).map((a) => a.id), ['beta', 'alpha', 'gamma', 'delta']);
      expect(byCategory(apps).keys.first, 'Tools');
      expect(recentlyUpdated(apps).first.id, 'gamma');
      expect(similarTo(apps[0], apps).map((a) => a.id).first, 'beta');
      expect(similarTo(apps[0], apps).any((a) => a.id == 'alpha'), isFalse);
    });

    test('screenshots resolve to raw URLs', () {
      final a = app('alpha', screenshots: ['shots/1.png', 'https://x/y.png']);
      expect(a.screenshotUrls, ['https://raw.githubusercontent.com/its-ash/alpha/main/shots/1.png', 'https://x/y.png']);
      expect(StoreApp.fromJson(a.toJson()).manifest.screenshots, hasLength(2));
    });
  });

  group('install results', () {
    test('success clears Installing, refreshes versions and emits an outcome', () async {
      final fake = FakePackages();
      Packages.bridge = fake;
      final c = controllerWith(apps);
      final alpha = apps[0];
      c.listenForResults();
      c.installing.add(alpha.id);
      expect(c.stateOf(alpha), AppState.notInstalled);

      fake.versions[alpha.package] = InstalledVersion('1.0.0', 1);
      final got = c.outcomes.first;
      fake.emit(InstallOutcome(package: alpha.package, success: true));
      final (a, o) = await got;
      expect(a.id, 'alpha');
      expect(o.success, isTrue);
      expect(c.isInstalling(alpha), isFalse);
      expect(c.stateOf(alpha), AppState.installed);
      c.dispose();
    });

    test('failure keeps the app not installed and reports the message', () async {
      final fake = FakePackages();
      Packages.bridge = fake;
      final c = controllerWith(apps);
      c.listenForResults();
      c.installing.add('beta');
      final got = c.outcomes.first;
      fake.emit(const InstallOutcome(package: 'com.itsash.beta', success: false, message: 'Signatures differ'));
      final (_, o) = await got;
      expect(o.message, 'Signatures differ');
      expect(c.installing, isEmpty);
      expect(c.stateOf(apps[1]), AppState.notInstalled);
      c.dispose();
    });

    test('needsPermission when installs are not allowed', () async {
      final fake = FakePackages()..allowed = false;
      Packages.bridge = fake;
      final c = controllerWith(apps);
      expect(await c.install(apps[0]), InstallResult.needsPermission);
      expect(fake.installs, isEmpty);
      c.dispose();
    });

    testWidgets('button shows Installing while a session runs', (tester) async {
      Packages.bridge = FakePackages();
      final c = controllerWith(apps);
      c.installing.add('alpha');
      await pumpStore(tester, c);
      await tester.tap(find.text('Top charts'));
      await step(tester);
      expect(find.text('Installing'), findsOneWidget);
    });
  });

  group('screens at 320 px', () {
    testWidgets('For you shows carousels, then Top charts and Categories', (tester) async {
      await pumpStore(tester, controllerWith(apps));
      expect(find.text('Search apps'), findsOneWidget);
      expect(find.text('For you'), findsOneWidget);
      expect(find.text('NEW & UPDATED'), findsOneWidget);
      expect(find.text('Tools'), findsWidgets);
      expect(find.text('Apps'), findsOneWidget); // bottom nav

      await tester.tap(find.text('Top charts'));
      await step(tester);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Install'), findsWidgets);

      await tester.tap(find.text('Categories'));
      await step(tester);
      expect(find.text('Health & Fitness'), findsOneWidget);
      await tester.tap(find.text('Health & Fitness'));
      await step(tester);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('Search filters live', (tester) async {
      await pumpStore(tester, controllerWith(apps));
      await tester.tap(find.text('Search').last);
      await step(tester);
      expect(find.text('All apps'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'gam');
      await step(tester);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      await tester.enterText(find.byType(TextField), 'nothing-here');
      await step(tester);
      expect(find.textContaining('No apps match'), findsOneWidget);
    });

    testWidgets('Updates tab lists updates with Update all and a badge', (tester) async {
      final c = controllerWith(apps, installed: {'com.itsash.alpha': '0.9.0', 'com.itsash.beta': '1.0.0'});
      await pumpStore(tester, c);
      expect(c.updates.map((a) => a.id), ['alpha']);
      expect(find.text('1'), findsOneWidget); // nav badge
      await tester.tap(find.text('Updates'));
      await step(tester);
      expect(find.text('Manage apps'), findsOneWidget);
      expect(find.text('Update all'), findsOneWidget);
      expect(find.text('v0.9.0 → v1.0.0'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget); // installed beta
    });

    testWidgets('Settings ends with updates and developer groups', (tester) async {
      await pumpStore(tester, controllerWith(apps));
      await tester.tap(find.text('Settings').last);
      await step(tester);
      expect(find.text('Refresh app list'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Ashvini Jangid'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('Ashvini Jangid'), findsOneWidget);
    });

    testWidgets('detail page shows header, stats, install and similar apps', (tester) async {
      await pumpStore(tester, controllerWith(apps));
      await tester.tap(find.text('Top charts'));
      await step(tester);
      await tester.tap(find.text('Beta').first);
      await step(tester);
      expect(find.text('Ash Store'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
      expect(find.text('About this app'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Similar apps'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Similar apps'), findsOneWidget);
    });

    testWidgets('installed app detail offers Uninstall and Open', (tester) async {
      await pumpStore(tester, controllerWith(apps, installed: {'com.itsash.beta': '1.0.0'}));
      await tester.tap(find.text('Top charts'));
      await step(tester);
      await tester.tap(find.text('Beta').first);
      await step(tester);
      expect(find.text('Uninstall'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton, offline shows an error with retry', (tester) async {
      final loading = StoreController(service: _NoNetwork());
      await pumpStore(tester, loading);
      expect(find.byType(UiSkeleton), findsWidgets);

      final failed = StoreController(service: _NoNetwork())..error = 'offline';
      await pumpStore(tester, failed);
      expect(find.text('offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('empty catalog shows an empty state', (tester) async {
      await pumpStore(tester, controllerWith([]));
      expect(find.text('No apps listed yet'), findsOneWidget);
    });
  });
}

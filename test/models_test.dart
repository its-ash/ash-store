import 'package:ash_store/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compareVersions orders numerically and ignores v and +build', () {
    expect(compareVersions('v1.0.10', '1.0.9'), greaterThan(0));
    expect(compareVersions('1.0.3', '1.0.3+7'), 0);
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('0.9.9', 'v1.0.0'), lessThan(0));
  });

  test('release prefers <id>.apk and falls back to any APK', () {
    Map<String, dynamic> asset(String name) =>
        {'name': name, 'browser_download_url': 'https://x/$name', 'size': 10};
    final json = {
      'tag_name': 'v1.2.3',
      'published_at': '2026-01-01T00:00:00Z',
      'assets': [asset('app-release.apk'), asset('linkdrop.apk'), asset('linkdrop.apk.sha256')],
    };
    final r = StoreRelease.fromGitHub(json, 'linkdrop');
    expect(r.version, '1.2.3');
    expect(r.apkName, 'linkdrop.apk');
    expect(StoreRelease.fromGitHub(json, 'other').apkName, 'app-release.apk');
    expect(StoreRelease.fromGitHub({...json, 'assets': []}, 'x').apkUrl, isNull);
  });

  test('manifest round-trips and icon resolves to raw GitHub URL', () {
    final app = StoreApp(
      repo: 'linkdrop',
      branch: 'main',
      htmlUrl: 'https://github.com/its-ash/linkdrop',
      manifest: StoreManifest.fromJson({
        'id': 'linkdrop',
        'name': 'LinkDrop',
        'package': 'com.itsash.linkdrop',
        'icon': 'assets/icon/icon.png',
      }),
    );
    expect(app.iconUrl, 'https://raw.githubusercontent.com/its-ash/linkdrop/main/assets/icon/icon.png');
    expect(StoreApp.fromJson(app.toJson()).manifest.package, 'com.itsash.linkdrop');
  });
}

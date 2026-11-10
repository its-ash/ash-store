/// Where the store looks for apps.
///
/// An app is listed when its GitHub repo (owned by [owner]) has the [topic]
/// topic, a `store.json` manifest at the root of its default branch, and a
/// latest release with an `.apk` asset. See `store-kit/STORE.md`.
class StoreConfig {
  StoreConfig._();

  static const owner = 'its-ash';
  static const topic = 'ash-store';

  /// Package id of this app, so the store can offer its own updates.
  static const selfPackage = 'com.itsash.store';

  /// How long a fetched catalog is used before it is fetched again.
  /// Unauthenticated GitHub API calls are limited to 60 an hour.
  static const cacheTtl = Duration(minutes: 15);

  static const website = 'https://store.itsash.in/';

  static Uri searchUri() => Uri.https('api.github.com', '/search/repositories', {
        'q': 'topic:$topic user:$owner fork:true',
        'per_page': '100',
      });

  static Uri latestReleaseUri(String repo) =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  static Uri manifestUri(String repo, String branch) =>
      Uri.https('raw.githubusercontent.com', '/$owner/$repo/$branch/store.json');

  static String rawUrl(String repo, String branch, String path) =>
      'https://raw.githubusercontent.com/$owner/$repo/$branch/$path';
}

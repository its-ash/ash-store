import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'models.dart';

/// The list of apps and when it was fetched.
class Catalog {
  const Catalog(this.apps, this.fetchedAt, {this.error});

  final List<StoreApp> apps;
  final DateTime fetchedAt;

  /// Set when a refresh failed and these apps came from the cache.
  final String? error;

  bool get isFresh => DateTime.now().difference(fetchedAt) < StoreConfig.cacheTtl;

  Catalog withError(String e) => Catalog(apps, fetchedAt, error: e);

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'apps': [for (final a in apps) a.toJson()],
      };

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        [for (final a in j['apps'] as List) StoreApp.fromJson((a as Map).cast())],
        DateTime.parse(j['fetchedAt'] as String),
      );
}

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Builds the catalog from GitHub: repos with the store topic, their
/// `store.json`, and their latest release. Keeps a copy on disk.
class CatalogService {
  CatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'ash-store',
  };

  Future<File> _cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/catalog.json');

  Future<Catalog?> cached() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return null;
      return Catalog.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached catalog while fresh, otherwise fetches. When the
  /// fetch fails and there is a cache, returns the cache with [Catalog.error].
  Future<Catalog> load({bool force = false}) async {
    final cache = await cached();
    if (!force && cache != null && cache.isFresh) return cache;
    try {
      final fresh = await fetch();
      await (await _cacheFile()).writeAsString(jsonEncode(fresh.toJson()));
      return fresh;
    } catch (e) {
      if (cache != null) return cache.withError(e.toString());
      rethrow;
    }
  }

  Future<Catalog> fetch() async {
    final res = await _client.get(StoreConfig.searchUri(), headers: _headers);
    _check(res);
    final items = ((jsonDecode(res.body) as Map)['items'] as List).cast<Map<String, dynamic>>();
    final apps = await Future.wait(items.where((r) => r['archived'] != true).map(_app));
    final listed = apps.whereType<StoreApp>().where((a) => a.manifest.listed).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Catalog(listed, DateTime.now());
  }

  /// Null when the repo has no valid `store.json`.
  Future<StoreApp?> _app(Map<String, dynamic> repo) async {
    final name = repo['name'] as String;
    final branch = repo['default_branch'] as String? ?? 'main';
    final StoreManifest manifest;
    try {
      final res = await _client.get(StoreConfig.manifestUri(name, branch));
      if (res.statusCode != 200) return null;
      manifest = StoreManifest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }

    StoreRelease? release;
    final rel = await _client.get(StoreConfig.latestReleaseUri(name), headers: _headers);
    if (rel.statusCode == 200) {
      release = StoreRelease.fromGitHub(jsonDecode(rel.body) as Map<String, dynamic>, manifest.id);
    } else if (rel.statusCode != 404) {
      _check(rel);
    }

    return StoreApp(
      repo: name,
      branch: branch,
      htmlUrl: repo['html_url'] as String,
      stars: repo['stargazers_count'] as int? ?? 0,
      manifest: manifest,
      release: release,
    );
  }

  void _check(http.Response res) {
    if (res.statusCode == 200) return;
    if (res.statusCode == 403 || res.statusCode == 429) {
      final reset = int.tryParse(res.headers['x-ratelimit-reset'] ?? '');
      final at = reset == null ? null : DateTime.fromMillisecondsSinceEpoch(reset * 1000);
      final wait = at == null ? '' : ' Try again after ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}.';
      throw CatalogException('GitHub rate limit reached.$wait');
    }
    throw CatalogException('GitHub returned ${res.statusCode}.');
  }
}

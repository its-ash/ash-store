import 'config.dart';

/// `store.json` at the root of an app repo. Schema: `store-kit/store.schema.json`.
class StoreManifest {
  const StoreManifest({
    required this.id,
    required this.name,
    required this.package,
    this.tagline = '',
    this.description = '',
    this.category = 'Apps',
    this.icon,
    this.homepage,
    this.listed = true,
  });

  factory StoreManifest.fromJson(Map<String, dynamic> j) => StoreManifest(
        id: j['id'] as String,
        name: j['name'] as String,
        package: j['package'] as String,
        tagline: j['tagline'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: j['category'] as String? ?? 'Apps',
        icon: j['icon'] as String?,
        homepage: j['homepage'] as String?,
        listed: j['listed'] as bool? ?? true,
      );

  /// Slug. The release APK is `<id>.apk`.
  final String id;
  final String name;

  /// Android application id, used to find the installed version.
  final String package;
  final String tagline;
  final String description;
  final String category;

  /// Repo-relative path or absolute URL of a square PNG icon.
  final String? icon;
  final String? homepage;

  /// False hides the app from the catalog (e.g. not ready yet).
  final bool listed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'package': package,
        'tagline': tagline,
        'description': description,
        'category': category,
        'icon': icon,
        'homepage': homepage,
        'listed': listed,
      };
}

/// The latest GitHub release of an app and its APK asset.
class StoreRelease {
  const StoreRelease({
    required this.tag,
    required this.notes,
    required this.publishedAt,
    required this.htmlUrl,
    this.apkName,
    this.apkUrl,
    this.apkSize,
  });

  /// Picks `<id>.apk`, then any `.apk` asset.
  factory StoreRelease.fromGitHub(Map<String, dynamic> j, String id) {
    final assets = (j['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
    final apks = assets.where((a) => (a['name'] as String).toLowerCase().endsWith('.apk')).toList();
    Map<String, dynamic>? apk;
    for (final a in apks) {
      if (a['name'] == '$id.apk') apk = a;
    }
    apk ??= apks.isEmpty ? null : apks.first;
    return StoreRelease(
      tag: j['tag_name'] as String,
      notes: (j['body'] as String? ?? '').trim(),
      publishedAt: DateTime.tryParse(j['published_at'] as String? ?? '') ?? DateTime.now(),
      htmlUrl: j['html_url'] as String? ?? '',
      apkName: apk?['name'] as String?,
      apkUrl: apk?['browser_download_url'] as String?,
      apkSize: apk?['size'] as int?,
    );
  }

  factory StoreRelease.fromJson(Map<String, dynamic> j) => StoreRelease(
        tag: j['tag'] as String,
        notes: j['notes'] as String? ?? '',
        publishedAt: DateTime.parse(j['publishedAt'] as String),
        htmlUrl: j['htmlUrl'] as String? ?? '',
        apkName: j['apkName'] as String?,
        apkUrl: j['apkUrl'] as String?,
        apkSize: j['apkSize'] as int?,
      );

  final String tag;
  final String notes;
  final DateTime publishedAt;
  final String htmlUrl;
  final String? apkName;
  final String? apkUrl;
  final int? apkSize;

  String get version => tag.startsWith('v') ? tag.substring(1) : tag;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'notes': notes,
        'publishedAt': publishedAt.toIso8601String(),
        'htmlUrl': htmlUrl,
        'apkName': apkName,
        'apkUrl': apkUrl,
        'apkSize': apkSize,
      };
}

/// One listed app: repo + manifest + latest release.
class StoreApp {
  const StoreApp({
    required this.repo,
    required this.branch,
    required this.htmlUrl,
    required this.manifest,
    this.release,
    this.stars = 0,
  });

  factory StoreApp.fromJson(Map<String, dynamic> j) => StoreApp(
        repo: j['repo'] as String,
        branch: j['branch'] as String,
        htmlUrl: j['htmlUrl'] as String,
        stars: j['stars'] as int? ?? 0,
        manifest: StoreManifest.fromJson((j['manifest'] as Map).cast()),
        release: j['release'] == null ? null : StoreRelease.fromJson((j['release'] as Map).cast()),
      );

  final String repo;
  final String branch;
  final String htmlUrl;
  final int stars;
  final StoreManifest manifest;
  final StoreRelease? release;

  String get id => manifest.id;
  String get name => manifest.name;
  String get package => manifest.package;
  bool get isSelf => package == StoreConfig.selfPackage;
  bool get downloadable => release?.apkUrl != null;

  String? get iconUrl {
    final icon = manifest.icon;
    if (icon == null || icon.isEmpty) return null;
    if (icon.startsWith('http')) return icon;
    return StoreConfig.rawUrl(repo, branch, icon);
  }

  String get homepage => manifest.homepage ?? htmlUrl;

  Map<String, dynamic> toJson() => {
        'repo': repo,
        'branch': branch,
        'htmlUrl': htmlUrl,
        'stars': stars,
        'manifest': manifest.toJson(),
        'release': release?.toJson(),
      };
}

/// Version of an app installed on this device.
class InstalledVersion {
  const InstalledVersion(this.name, this.code);
  final String name;
  final int code;
}

enum AppState { notInstalled, installed, updateAvailable, unavailable }

/// Compares dotted versions (`1.0.10` > `1.0.9`). A leading `v` and any
/// `+build` or `-suffix` are ignored.
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    s = s.split(RegExp(r'[+\- ]')).first;
    return s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3 || i < x.length || i < y.length; i++) {
    final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
    if (p != q) return p.compareTo(q);
  }
  return 0;
}

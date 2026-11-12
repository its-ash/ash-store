import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'models.dart';

/// Pure list helpers behind the store screens (browse, charts, search).

/// Apps shown to the user. The store itself is offered as an update notice.
List<StoreApp> browsable(Iterable<StoreApp> apps) => [for (final a in apps) if (!a.isSelf) a];

/// Live search over name, tagline, description and category.
List<StoreApp> searchApps(Iterable<StoreApp> apps, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return apps.toList();
  return [
    for (final a in apps)
      if ('${a.name} ${a.manifest.tagline} ${a.manifest.description} ${a.manifest.category}'.toLowerCase().contains(q)) a,
  ];
}

/// Every app, alphabetical by name (home screen list).
List<StoreApp> allByName(Iterable<StoreApp> apps) =>
    apps.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// Ranked list: most starred first, then most recently released, then name.
List<StoreApp> topCharts(Iterable<StoreApp> apps) {
  final list = apps.toList();
  list.sort((a, b) {
    final s = b.stars.compareTo(a.stars);
    if (s != 0) return s;
    final ta = a.release?.publishedAt, tb = b.release?.publishedAt;
    if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
    if ((ta == null) != (tb == null)) return ta == null ? 1 : -1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

/// Apps with a release, newest release first.
List<StoreApp> recentlyUpdated(Iterable<StoreApp> apps) {
  final list = [for (final a in apps) if (a.release != null) a];
  list.sort((a, b) => b.release!.publishedAt.compareTo(a.release!.publishedAt));
  return list;
}

/// Apps per category. Bigger categories first, then alphabetical.
Map<String, List<StoreApp>> byCategory(Iterable<StoreApp> apps) {
  final map = <String, List<StoreApp>>{};
  for (final a in apps) {
    (map[a.manifest.category] ??= []).add(a);
  }
  final keys = map.keys.toList()
    ..sort((a, b) {
      final c = map[b]!.length.compareTo(map[a]!.length);
      return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
    });
  return {for (final k in keys) k: map[k]!};
}

/// Other apps from the same category first, then the rest. Never [app] itself.
List<StoreApp> similarTo(StoreApp app, Iterable<StoreApp> apps, {int max = 12}) {
  final others = [for (final a in apps) if (a.id != app.id) a];
  final same = [for (final a in others) if (a.manifest.category == app.manifest.category) a];
  final rest = [for (final a in others) if (a.manifest.category != app.manifest.category) a];
  return [...same, ...rest].take(max).toList();
}

/// "Utilities · 4.2 MB" style line.
String categorySizeLine(StoreApp app) => [
      app.manifest.category,
      if (app.release?.apkSize != null) UiFormat.bytes(app.release!.apkSize!),
    ].join(' · ');

IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('health') || c.contains('fitness')) return Icons.favorite_outline_rounded;
  if (c.contains('life')) return Icons.spa_outlined;
  if (c.contains('product') || c.contains('office')) return Icons.work_outline_rounded;
  if (c.contains('tool')) return Icons.build_outlined;
  if (c.contains('util')) return Icons.handyman_outlined;
  if (c.contains('secur') || c.contains('privacy')) return Icons.shield_outlined;
  if (c.contains('photo') || c.contains('video') || c.contains('media')) return Icons.photo_library_outlined;
  if (c.contains('music') || c.contains('audio')) return Icons.music_note_outlined;
  if (c.contains('social') || c.contains('communic') || c.contains('message')) return Icons.chat_bubble_outline_rounded;
  if (c.contains('game')) return Icons.sports_esports_outlined;
  if (c.contains('finance') || c.contains('money')) return Icons.account_balance_wallet_outlined;
  if (c.contains('travel') || c.contains('map')) return Icons.explore_outlined;
  return Icons.apps_rounded;
}

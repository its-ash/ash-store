import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'browse.dart';
import 'widgets.dart';

/// Apps of one category as a vertical list.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen(this.category, {super.key});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: UiAppBar(title: category, backgroundColor: context.colors.surface),
      body: CatalogGate(
        builder: (context, store, apps) {
          final list = topCharts(apps.where((a) => a.manifest.category == category));
          return UiRefresh(
            onRefresh: () => store.refresh(force: true),
            child: ListView(
              padding: const EdgeInsets.only(bottom: UiSpace.xxl),
              children: [
                if (list.isEmpty)
                  SizedBox(height: 360, child: UiEmptyState(icon: categoryIcon(category), title: 'No apps in $category'))
                else
                  for (final a in list) AppRowTile(a),
              ],
            ),
          );
        },
      ),
    );
  }
}

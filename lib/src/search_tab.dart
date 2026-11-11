import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'browse.dart';
import 'widgets.dart';

/// Search tab: live filter over name, tagline and description. With an empty
/// query it lists every app.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.focusNode});
  final FocusNode focusNode;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(UiSpace.lg, UiSpace.sm, UiSpace.lg, UiSpace.md),
            child: UiSearchField(
              hint: 'Search apps',
              focusNode: widget.focusNode,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: CatalogGate(
              builder: (context, store, apps) {
                final results = searchApps(topCharts(apps), _query);
                final searching = _query.trim().isNotEmpty;
                return UiRefresh(
                  onRefresh: () => store.refresh(force: true),
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: UiSpace.xxl),
                    children: [
                      if (results.isEmpty)
                        SizedBox(
                          height: 320,
                          child: UiEmptyState(
                            icon: Icons.search_off_rounded,
                            title: searching ? 'No apps match "${_query.trim()}"' : 'No apps listed yet',
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.xs, UiSpace.page, UiSpace.xs),
                          child: Semantics(
                            header: true,
                            child: Text(searching ? 'Results' : 'All apps', style: context.text.titleMedium),
                          ),
                        ),
                        for (final a in results) AppRowTile(a),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

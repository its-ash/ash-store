import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'explore_tab.dart';
import 'models.dart';
import 'packages.dart';
import 'search_tab.dart';
import 'settings_screen.dart';
import 'store_controller.dart';
import 'updates_tab.dart';

/// Root screen: Apps, Search, Updates and Settings behind a bottom bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _apps = 0, _search = 1, _settings = 3;

  int _index = _apps;
  final _searchFocus = FocusNode();
  StreamSubscription<(StoreApp, InstallOutcome)>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= StoreScope.of(context).outcomes.listen((e) {
      if (!mounted) return;
      final (app, o) = e;
      if (o.success) {
        context.showToast('${app.name} installed.', status: UiStatus.success);
      } else if (!o.message.toLowerCase().contains('abort')) {
        context.showToast(
          o.message.isEmpty ? 'Android could not install it. If an older copy was signed with a different key, uninstall it first.' : o.message,
          title: 'Could not install ${app.name}',
          status: UiStatus.danger,
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    if (i == _search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _index == _search) _searchFocus.requestFocus();
      });
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: IndexedStack(
        index: _index,
        children: [
          ExploreTab(onSearch: () => _go(_search), onSettings: () => _go(_settings)),
          SearchTab(focusNode: _searchFocus),
          const UpdatesTab(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: UiBottomNav(
        index: _index,
        onChanged: _go,
        items: [
          const UiNavItem(Icons.apps_outlined, 'Apps', selectedIcon: Icons.apps_rounded),
          const UiNavItem(Icons.search_rounded, 'Search'),
          UiNavItem(Icons.system_update_outlined, 'Updates', selectedIcon: Icons.system_update_rounded, badge: updateCount(store)),
          const UiNavItem(Icons.settings_outlined, 'Settings', selectedIcon: Icons.settings_rounded),
        ],
      ),
    );
  }
}

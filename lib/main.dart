import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'src/home_screen.dart';
import 'src/store_controller.dart';

/// Store accent: a Play-style green. The theme lightens it in dark mode.
const storeGreen = Color(0xFF01875F);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = StoreController()..init();
  runApp(AshStoreApp(store: store));
}

class AshStoreApp extends StatelessWidget {
  const AshStoreApp({super.key, required this.store});
  final StoreController store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      controller: store,
      child: const UiApp(title: 'Ash Store', accent: storeGreen, home: HomeScreen()),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'src/home_screen.dart';
import 'src/store_controller.dart';

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
      child: const UiApp(title: 'Ash Store', home: HomeScreen()),
    );
  }
}

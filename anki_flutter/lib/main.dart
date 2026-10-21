import 'package:flutter/material.dart';

import 'screens/insights_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/search_screen.dart';
import 'services/speech.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  Speech.instance.warmUp();
  runApp(StoreScope(store: store, child: const AnkiApp()));
}

/// Makes the [AppStore] reachable from any widget and rebuilds dependents on change.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class AnkiApp extends StatelessWidget {
  const AnkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    AppColors.dark = store.darkMode;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Phone-like column on wide desktop screens.
      builder: (context, child) => ColoredBox(
        color: AppColors.dark ? const Color(0xFF0E0E10) : const Color(0xFFDCDCE2),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [
              QueueScreen(),
              LibraryScreen(),
              InsightsScreen(),
              ProfileScreen(),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(child: _NavBar(index: _tab, onTap: (i) => setState(() => _tab = i))),
                  const SizedBox(width: 10),
                  _SearchButton(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.inventory_2_rounded, 'Queue'),
    (Icons.auto_stories_rounded, 'Library'),
    (Icons.show_chart_rounded, 'Insights'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(37),
        border: Border.all(color: AppColors.dark ? Colors.white12 : Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: i == index ? (AppColors.dark ? const Color(0xFF1C1C1E) : AppColors.surface2) : null,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_items[i].$1,
                          size: 28, color: i == index ? AppColors.accentStrong : AppColors.text),
                      const SizedBox(height: 2),
                      Text(_items[i].$2,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: i == index ? AppColors.accentStrong : AppColors.text)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.dark ? Colors.white12 : Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Icon(Icons.search_rounded, size: 34, color: AppColors.text),
      ),
    );
  }
}

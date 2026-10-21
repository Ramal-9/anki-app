import 'package:flutter/material.dart';

import 'display.dart';

import 'screens/ai_practice.dart';
import 'screens/insights_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/search_screen.dart';
import 'services/speech.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/common.dart';

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
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final desktop = isDesktopLayout(store, mq.size);
        return RawScreen(
          size: mq.size,
          pixelRatio: mq.devicePixelRatio,
          child: ColoredBox(
            color: desktop ? AppColors.bg : (AppColors.dark ? const Color(0xFF0E0E10) : const Color(0xFFDCDCE2)),
            child: UiScale(
              scale: store.uiScale,
              textScale: store.textScale,
              // Phone layout on a wide window: a centred phone-width column.
              child: desktop
                  ? child!
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: store.phoneWidth),
                        child: child,
                      ),
                    ),
            ),
          ),
        );
      },
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

  static const _screens = [QueueScreen(), LibraryScreen(), InsightsScreen(), ProfileScreen()];

  void _openSearch() => Navigator.of(context).push(pageRoute(const SearchScreen()));

  @override
  Widget build(BuildContext context) {
    if (desktopOf(context)) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
            onSearch: _openSearch,
            onPractice: () => showFreePractice(context),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: IndexedStack(index: _tab, children: _screens),
              ),
            ),
          ),
        ]),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: _screens),
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
                  _SearchButton(onTap: _openSearch),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left navigation used by the desktop (Mac / wide window) layout.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onTap, required this.onSearch, required this.onPractice});
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onSearch;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: selected ? AppColors.surface2 : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(icon, size: 24, color: selected ? AppColors.accentStrong : AppColors.text),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? AppColors.accentStrong : AppColors.text)),
              ]),
            ),
          ),
        );

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SquiggleLogo(width: 46),
          const SizedBox(width: 10),
          Text(AppConfig.appName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 28),
        for (var i = 0; i < _NavBar._items.length; i++)
          item(_NavBar._items[i].$1, _NavBar._items[i].$2, i == index, () => onTap(i)),
        item(Icons.search_rounded, 'Search', false, onSearch),
        const Spacer(),
        GradientButton(
          height: 52,
          onTap: onPractice,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('AI Practice', style: TextStyle(fontSize: 16)),
          ]),
        ),
      ]),
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

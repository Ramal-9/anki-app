import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

import '../display.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_pages.dart';

const kAppIcons = [
  ('classic', 'Classic'),
  ('ocean', 'Ocean'),
  ('mint', 'Mint'),
  ('sunset', 'Sunset'),
  ('rose', 'Rose'),
  ('mono', 'Mono'),
];

String appIconUrl(String key) =>
    key == 'classic' ? 'icons/apple-touch-icon.png?v=3' : 'icons/variants/$key-180.png?v=3';

String currentAppIcon() {
  final js = globalContext.getProperty<JSObject?>('afIcon'.toJS);
  return js?.callMethod<JSString>('get'.toJS).toDart ?? 'classic';
}

/// True when running from the Home Screen / Dock rather than in a browser tab.
bool get isInstalledApp {
  final nav = globalContext.getProperty<JSObject>('navigator'.toJS);
  if (nav.getProperty<JSBoolean?>('standalone'.toJS)?.toDart ?? false) return true;
  final mq = globalContext.callMethod<JSObject>('matchMedia'.toJS, '(display-mode: standalone)'.toJS);
  return mq.getProperty<JSBoolean>('matches'.toJS).toDart;
}

/// Profile → App icon: pick the icon used when adding the app to the Home Screen or Dock.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  late String _icon = currentAppIcon();

  void _choose(String key) {
    globalContext.getProperty<JSObject?>('afIcon'.toJS)?.callMethod('set'.toJS, key.toJS);
    setState(() => _icon = key);
    toast(context, 'Icon selected. Now add the app to the Home Screen again (steps below).');
  }

  @override
  Widget build(BuildContext context) {
    final installed = isInstalledApp;
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const SubPageHeader(title: 'App icon'),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 16, runSpacing: 18, alignment: WrapAlignment.center, children: [
                for (final (key, label) in kAppIcons)
                  GestureDetector(
                    onTap: () => _choose(key),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: key == _icon ? AppColors.accent : Colors.transparent, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.network(appIconUrl(key), width: 92, height: 92, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(label,
                          style: TextStyle(
                              fontSize: 15,
                              color: key == _icon ? AppColors.accent : AppColors.textSecondary,
                              fontWeight: key == _icon ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
              ]),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('How to apply the icon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  '${installed ? 'You opened the app from the Home Screen. iPhone and Mac never change the icon of an '
                      'installed web app, so the new icon has to be set in the browser:\n\n' : ''}'
                  'Important: an app on the Home Screen keeps its own copy of your cards. Turn on Profile → Sync '
                  'first, so nothing is lost when you remove it.\n\n'
                  'iPhone:\n'
                  '1. Hold the old Anki Flow icon → Remove App → Delete from Home Screen.\n'
                  '2. Open the site in Safari, go to Profile → App icon and pick an icon.\n'
                  '3. Share → Add to Home Screen. Open it and connect Sync with your setup code.\n\n'
                  'Mac (Safari):\n'
                  '1. Remove the old app: Finder → Applications (in your home folder) → drag Anki Flow to the Bin.\n'
                  '2. In Safari choose the icon here, then File → Add to Dock.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.45),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

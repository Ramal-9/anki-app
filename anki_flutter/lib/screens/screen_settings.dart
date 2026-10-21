import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Profile → Screen & layout: shows the detected device and lets the user
/// adjust layout, UI scale, text size and phone column width.
class ScreenSettingsScreen extends StatelessWidget {
  const ScreenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final raw = RawScreen.of(context)!;
    final size = raw.size;
    final desktop = isDesktopLayout(store, size);
    final device = describeDevice(size, raw.pixelRatio);
    final orientation = size.width > size.height ? 'landscape' : 'portrait';

    void set(VoidCallback change) {
      change();
      store.touch();
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                RoundButton(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Screen', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ),

            // ------------------------------------------------ detected device
            const SectionLabel('Detected device', padding: EdgeInsets.fromLTRB(36, 20, 20, 12)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
              child: Row(children: [
                Icon(desktop ? Icons.laptop_mac_rounded : Icons.phone_iphone_rounded,
                    size: 44, color: AppColors.accent),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(device, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${size.width.round()} × ${size.height.round()} pt · ${raw.pixelRatio.toStringAsFixed(raw.pixelRatio % 1 == 0 ? 0 : 1)}× · $orientation',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('Layout in use: ${desktop ? 'Desktop (sidebar)' : 'Phone (bottom bar)'}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ]),
                ),
              ]),
            ),

            // ------------------------------------------------------- layout
            const SectionLabel('Layout', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<LayoutMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: LayoutMode.auto, icon: Icon(Icons.auto_mode_rounded), label: Text('Auto')),
                  ButtonSegment(value: LayoutMode.phone, icon: Icon(Icons.phone_iphone_rounded), label: Text('Phone')),
                  ButtonSegment(value: LayoutMode.desktop, icon: Icon(Icons.laptop_mac_rounded), label: Text('Desktop')),
                ],
                selected: {store.layoutMode},
                onSelectionChanged: (v) => set(() => store.layoutMode = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
              child: Text(
                'Auto uses the phone layout on iPhone and narrow windows, and the desktop layout with a sidebar '
                'on Mac when the window is ${kDesktopBreakpoint.round()} pt or wider.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),

            // ------------------------------------------------------- sizes
            const SectionLabel('Size', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _SliderRow(
                icon: Icons.zoom_in_rounded,
                title: 'Interface scale',
                value: store.uiScale,
                min: 0.7,
                max: 1.4,
                divisions: 14,
                label: '${(store.uiScale * 100).round()} %',
                onChanged: (v) => set(() => store.uiScale = double.parse(v.toStringAsFixed(2))),
              ),
              _SliderRow(
                icon: Icons.format_size_rounded,
                title: 'Text size',
                value: store.textScale,
                min: 0.8,
                max: 1.4,
                divisions: 12,
                label: '${(store.textScale * 100).round()} %',
                onChanged: (v) => set(() => store.textScale = double.parse(v.toStringAsFixed(2))),
              ),
              if (!desktop && size.width > 480)
                _SliderRow(
                  icon: Icons.width_normal_rounded,
                  title: 'Phone column width',
                  value: store.phoneWidth.clamp(360, 760),
                  min: 360,
                  max: 760,
                  divisions: 20,
                  label: '${store.phoneWidth.round()} pt',
                  onChanged: (v) => set(() => store.phoneWidth = v.roundToDouble()),
                ),
            ]),

            // ------------------------------------------------------ presets
            const SectionLabel('Presets', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                _preset(context, 'Automatic', Icons.auto_mode_rounded, () {
                  set(() {
                    store.layoutMode = LayoutMode.auto;
                    store.uiScale = 1.0;
                    store.textScale = 1.0;
                    store.phoneWidth = 520;
                  });
                }),
                _preset(context, 'iPhone 13', Icons.phone_iphone_rounded, () {
                  set(() {
                    store.layoutMode = LayoutMode.phone;
                    store.uiScale = size.width < 389 ? (size.width / 390).clamp(0.7, 1.0) : 1.0;
                    store.textScale = 1.0;
                    store.phoneWidth = 390;
                  });
                }),
                _preset(context, 'Mac', Icons.laptop_mac_rounded, () {
                  set(() {
                    store.layoutMode = LayoutMode.desktop;
                    store.uiScale = 1.0;
                    store.textScale = 1.0;
                  });
                }),
                _preset(context, 'Large text', Icons.text_increase_rounded, () {
                  set(() => store.textScale = 1.2);
                }),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
              child: Text(
                'Changes apply right away and are saved in this browser. If something no longer fits, tap Automatic.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preset(BuildContext context, String label, IconData icon, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.accent),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value, min, max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(children: [
        Row(children: [
          Icon(icon, color: AppColors.accent, size: 28),
          const SizedBox(width: 18),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 17)),
        ]),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ]),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'main.dart';
import 'store.dart';
import 'theme.dart';

/// How the app lays itself out. [auto] picks phone or desktop from the window size.
enum LayoutMode { auto, phone, desktop }

/// Window width (logical px) from which [LayoutMode.auto] switches to the desktop layout.
const kDesktopBreakpoint = 900.0;

/// Size of the window *before* the UI scale is applied, so device detection
/// reports the real screen (e.g. 390×844 on iPhone 13).
class RawScreen extends InheritedWidget {
  const RawScreen({super.key, required this.size, required this.pixelRatio, required super.child});
  final Size size;
  final double pixelRatio;

  static RawScreen? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RawScreen>();

  @override
  bool updateShouldNotify(RawScreen old) => old.size != size || old.pixelRatio != pixelRatio;
}

bool isDesktopLayout(AppStore store, Size rawSize) => switch (store.layoutMode) {
      LayoutMode.phone => false,
      LayoutMode.desktop => true,
      LayoutMode.auto => rawSize.width >= kDesktopBreakpoint,
    };

/// Convenience for widgets: is the desktop (sidebar) layout active?
bool desktopOf(BuildContext context) {
  final raw = RawScreen.of(context);
  return raw != null && isDesktopLayout(StoreScope.of(context), raw.size);
}

/// Human-readable guess of the device, from the platform and screen size.
String describeDevice(Size size, double dpr) {
  final w = size.shortestSide.round(), h = size.longestSide.round();
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      if (size.shortestSide >= 700) return 'iPad';
      const iphones = {
        '375x667': 'iPhone SE / 8',
        '375x812': 'iPhone X / 11 Pro / 12 mini / 13 mini',
        '390x844': 'iPhone 12 / 13 / 14',
        '393x852': 'iPhone 14 Pro / 15 / 16',
        '402x874': 'iPhone 16 Pro / 17',
        '414x896': 'iPhone 11 / XR',
        '428x926': 'iPhone 12 / 13 Pro Max / 14 Plus',
        '430x932': 'iPhone 14 Pro Max / 15 Plus / 16 Plus',
        '440x956': 'iPhone 16 Pro Max / 17 Pro Max',
      };
      return iphones['${w}x$h'] ?? 'iPhone';
    case TargetPlatform.macOS:
      return 'Mac';
    case TargetPlatform.android:
      return size.shortestSide >= 600 ? 'Android tablet' : 'Android phone';
    case TargetPlatform.windows:
      return 'Windows PC';
    case TargetPlatform.linux:
      return 'Linux PC';
    case TargetPlatform.fuchsia:
      return 'Device';
  }
}

/// Applies the user's UI scale and text size to everything below it,
/// including dialogs and bottom sheets.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.scale, required this.textScale, required this.child});
  final double scale;
  final double textScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth / scale, c.maxHeight / scale);
      final scaled = MediaQuery(
        data: mq.copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: mq.padding / scale,
          viewPadding: mq.viewPadding / scale,
          viewInsets: mq.viewInsets / scale,
        ),
        child: child,
      );
      if (scale == 1) return scaled;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: Transform.scale(scale: scale, alignment: Alignment.topLeft, child: scaled),
        ),
      );
    });
  }
}

/// Keeps pushed pages (deck, study, editor…) at a readable width on desktop.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!desktopOf(context)) return child;
    return ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: child),
      ),
    );
  }
}

Route<T> pageRoute<T>(Widget page, {bool fullscreenDialog = false}) => MaterialPageRoute<T>(
      fullscreenDialog: fullscreenDialog,
      builder: (_) => PageFrame(child: page),
    );

/// Number of grid columns that fits [width] with tiles of at least [minTile] px.
int columnsFor(double width, {double minTile = 170, int min = 2, int max = 4}) =>
    (width / minTile).floor().clamp(min, max);

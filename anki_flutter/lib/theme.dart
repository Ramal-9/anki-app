import 'package:flutter/material.dart';

/// App-wide configuration. Change the name here to rebrand the app.
class AppConfig {
  static const appName = 'Anki Flow';
  static const author = 'Ramal';
}

/// Color tokens. [AppColors.dark] is toggled from Profile → Dark mode and the
/// whole widget tree rebuilds, so every getter returns the right palette.
class AppColors {
  static bool dark = true;

  static Color get bg => dark ? const Color(0xFF1B1B1D) : const Color(0xFFF2F2F7);
  static Color get surface => dark ? const Color(0xFF2C2C2E) : Colors.white;
  static Color get surface2 => dark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
  static Color get divider => dark ? const Color(0xFF3F3F42) : const Color(0xFFDADADF);
  static Color get text => dark ? Colors.white : const Color(0xFF111114);
  static Color get textSecondary => dark ? const Color(0xFF9A9AA0) : const Color(0xFF6C6C72);
  static Color get textMuted => dark ? const Color(0xFF6E6E74) : const Color(0xFFA0A0A6);

  static const accent = Color(0xFF8A9EF0); // periwinkle used for icons/links
  static const accentStrong = Color(0xFF7B8FEA);
  static const newRed = Color(0xFFFF5A6E);
  static const learningBlue = Color(0xFF6B78F5);
  static const reviewGreen = Color(0xFF4FD1B5);
  static const goalTeal = Color(0xFF3FA58F);
  static const todayOrange = Color(0xFFF59A42);
  static const danger = Color(0xFFFF5A4E);

  /// Orange → pink → violet → teal gradient used on buttons and banners.
  static const brandGradient = LinearGradient(
    colors: [Color(0xFFF2B07A), Color(0xFFD27FD4), Color(0xFF9AA6E2), Color(0xFF63C2CF)],
    stops: [0.0, 0.45, 0.75, 1.0],
  );

  /// Softer gradient of the "In your queue" hero card.
  static const queueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB5806A), Color(0xFF8E5A92), Color(0xFF6E6C9E), Color(0xFF4B8E9C)],
    stops: [0.0, 0.42, 0.75, 1.0],
  );

  static LinearGradient get deckTile => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFF9A9A9C), Color(0xFF7C7C7E)]
            : const [Color(0xFFB9BCC6), Color(0xFF9EA1AB)],
      );
}

ThemeData buildTheme() {
  final dark = AppColors.dark;
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.bg),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accentStrong : AppColors.surface2),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    splashFactory: NoSplash.splashFactory,
  );
}

/// Section header like "STUDY BY DECK".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});
  final String text;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(
        children: [
          Text(text.toUpperCase(),
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

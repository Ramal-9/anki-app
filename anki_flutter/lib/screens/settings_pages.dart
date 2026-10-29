import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../services/notify.dart';
import '../srs.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Header used by the settings sub-pages: back button, centred title, optional action.
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({super.key, this.title, this.action});
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SizedBox(
        height: 56,
        child: Stack(alignment: Alignment.center, children: [
          if (title != null) Text(title!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Align(
            alignment: Alignment.centerLeft,
            child: RoundButton(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded)),
          ),
          if (action != null) Align(alignment: Alignment.centerRight, child: action!),
        ]),
      ),
    );
  }
}

// =============================================================== Daily goals

class DailyGoalsScreen extends StatelessWidget {
  const DailyGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const SubPageHeader(title: 'Daily goals'),
            const SizedBox(height: 28),
            DailyGoalsBody(store: store),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () {
                  store
                    ..goalTracking = true
                    ..newGoal = 15
                    ..reviewGoal = 25
                    ..touch();
                },
                child: Text('Reset to defaults', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Bottom sheet opened from the target button on the Queue screen.
Future<void> showDailyGoalsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.dark ? const Color(0xFF232325) : AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
    builder: (ctx) => Builder(builder: (ctx) {
        final store = StoreScope.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: SizedBox(
                  height: 52,
                  child: Stack(alignment: Alignment.center, children: [
                    const Text('Daily goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: RoundButton(
                        wide: true,
                        onTap: () => Navigator.pop(ctx),
                        child: const Text('Done', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
              DailyGoalsBody(store: store),
            ]),
          ),
        );
      }),
  );
}

class DailyGoalsBody extends StatelessWidget {
  const DailyGoalsBody({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          const Icon(Icons.track_changes_rounded, color: AppColors.accent, size: 30),
          const SizedBox(width: 20),
          const Expanded(child: Text('Goal tracking', style: TextStyle(fontSize: 20))),
          Switch(
            value: store.goalTracking,
            activeTrackColor: const Color(0xFF34C759),
            onChanged: (v) => store
              ..goalTracking = v
              ..touch(),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: store.goalTracking ? 1 : 0.45,
        child: IgnorePointer(
          ignoring: !store.goalTracking,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(20, 22, 18, 18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
            child: Column(children: [
              Text('YOUR DAILY TARGET',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFFF2A07E), Color(0xFFD27FD4), Color(0xFF9AA6E2), Color(0xFF63C2CF)],
                    ).createShader(r),
                    child: Text('${store.dailyGoal}',
                        style: const TextStyle(
                            fontSize: 76, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                  ),
                  const SizedBox(width: 10),
                  Text('cards / day', style: TextStyle(fontSize: 22, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              _GoalRow(
                icon: Icons.auto_awesome_outlined,
                title: 'New cards',
                subtitle: 'Brand-new cards per day',
                value: store.newGoal,
                onChanged: (v) => store
                  ..newGoal = v
                  ..touch(),
              ),
              const SizedBox(height: 14),
              _GoalRow(
                icon: Icons.sync_rounded,
                title: 'Reviews',
                subtitle: 'Due cards to clear per day',
                value: store.reviewGoal,
                onChanged: (v) => store
                  ..reviewGoal = v
                  ..touch(),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title, subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = value >= 50 ? 10 : 5;
    return Row(children: [
      Icon(icon, color: AppColors.accent, size: 28),
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20)),
          Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ]),
      ),
      const SizedBox(width: 8),
      Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.dark ? const Color(0xFF2E333D) : AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.dark ? const Color(0xFF454B58) : AppColors.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 28),
            onPressed: value <= 0 ? null : () => onChanged((value - step).clamp(0, 500)),
          ),
          SizedBox(
            width: 46,
            child: Text('$value',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: value >= 500 ? null : () => onChanged((value + step).clamp(0, 500)),
          ),
        ]),
      ),
    ]);
  }
}

// ========================================================= Spaced repetition

class SpacedRepetitionScreen extends StatelessWidget {
  const SpacedRepetitionScreen({super.key});

  static const _presets = [
    (SrsPreset.standard, Icons.balance_rounded, 'Default', 'Balanced learning with 90 % retention'),
    (SrsPreset.aggressive, Icons.local_fire_department_outlined, 'Aggressive', 'High retention (95 %), more frequent reviews'),
    (SrsPreset.relaxed, Icons.eco_outlined, 'Relaxed', 'Fewer reviews, 85 % retention target'),
    (SrsPreset.custom, Icons.tune_rounded, 'Custom', 'Set your own parameters'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.srs;

    void edit(SrsParams next) {
      store
        ..srsPreset = SrsPreset.custom
        ..customSrs = next
        ..touch();
    }

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            SubPageHeader(
              action: RoundButton(
                wide: true,
                onTap: () => store
                  ..srsPreset = SrsPreset.standard
                  ..customSrs = SrsParams.standard
                  ..touch(),
                child: const Text('Reset', style: TextStyle(fontSize: 19)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Spaced repetition', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ),
            _plainLabel('Presets'),
            Panel(children: [
              for (final (preset, icon, title, sub) in _presets)
                InkWell(
                  onTap: () {
                    if (preset == SrsPreset.custom && store.srsPreset != SrsPreset.custom) {
                      store.customSrs = store.srs; // start from the values in use
                    }
                    store
                      ..srsPreset = preset
                      ..touch();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      Icon(icon, color: AppColors.accent, size: 26),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: const TextStyle(fontSize: 20)),
                          Text(sub, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                        ]),
                      ),
                      if (store.srsPreset == preset) const Icon(Icons.check_rounded, color: AppColors.accent, size: 28),
                    ]),
                  ),
                ),
            ]),
            _plainLabel(store.srsPreset == SrsPreset.custom ? 'Your settings' : 'Preview settings'),
            Panel(children: [
              _ValueRow(
                title: 'Retention target',
                value: '${(p.retention * 100).round()} %',
                onTap: () async {
                  final v = await _pick<double>(context, 'Retention target',
                      const [0.8, 0.85, 0.88, 0.9, 0.92, 0.95, 0.97], p.retention, (v) => '${(v * 100).round()} %');
                  if (v != null) edit(SrsParams(retention: v, maxIntervalDays: p.maxIntervalDays, fuzz: p.fuzz, shortTerm: p.shortTerm));
                },
              ),
              _ValueRow(
                title: 'Max interval',
                value: '${p.maxIntervalDays} days',
                onTap: () async {
                  final v = await _pick<int>(
                      context, 'Max interval', const [30, 90, 180, 365, 730, 1825, 3650], p.maxIntervalDays, (v) => '$v days');
                  if (v != null) edit(SrsParams(retention: p.retention, maxIntervalDays: v, fuzz: p.fuzz, shortTerm: p.shortTerm));
                },
              ),
              _ValueRow(
                title: 'Fuzz',
                value: p.fuzz ? 'Enabled' : 'Disabled',
                onTap: () => edit(SrsParams(
                    retention: p.retention, maxIntervalDays: p.maxIntervalDays, fuzz: !p.fuzz, shortTerm: p.shortTerm)),
              ),
              _ValueRow(
                title: 'Short-term optimisation',
                value: p.shortTerm ? 'Enabled' : 'Disabled',
                onTap: () => edit(SrsParams(
                    retention: p.retention, maxIntervalDays: p.maxIntervalDays, fuzz: p.fuzz, shortTerm: !p.shortTerm)),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
              child: Text(
                'Retention target is how likely you are to remember a card when it comes back. Higher means more reviews. '
                'Fuzz spreads cards added together over nearby days. Short-term optimisation shows new and forgotten '
                'cards again after 1 and 10 minutes. Tap a value to change it.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static Future<T?> _pick<T>(BuildContext context, String title, List<T> options, T current, String Function(T) label) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final o in options)
            ListTile(
              title: Text(label(o), style: const TextStyle(fontSize: 18)),
              trailing: o == current ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
              onTap: () => Navigator.pop(ctx, o),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

Widget _plainLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(40, 26, 20, 10),
      child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 19, fontWeight: FontWeight.w600)),
    );

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.title, required this.value, this.onTap});
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 19))),
          Text(value, style: TextStyle(color: AppColors.textSecondary, fontSize: 19)),
        ]),
      ),
    );
  }
}

// ============================================================= Notifications

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _permission = Notify.permission;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final time = formatMinutes(store.reminderMinutes);
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const SubPageHeader(title: 'Notifications'),
            const SectionLabel('Notifications', padding: EdgeInsets.fromLTRB(40, 24, 20, 10)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
              child: Row(children: [
                const Expanded(child: Text('Enable notifications', style: TextStyle(fontSize: 19))),
                Switch(
                  value: store.notifications,
                  onChanged: (v) async {
                    store
                      ..notifications = v
                      ..touch();
                    if (v && _permission == 'default') {
                      final p = await Notify.requestPermission();
                      if (mounted) setState(() => _permission = p);
                    }
                  },
                ),
              ]),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: store.notifications ? 1 : 0.45,
              child: IgnorePointer(
                ignoring: !store.notifications,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
                  child: Row(children: [
                    const Expanded(child: Text('Reminder', style: TextStyle(fontSize: 19))),
                    GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: store.reminderMinutes ~/ 60, minute: store.reminderMinutes % 60),
                          builder: (ctx, child) =>
                              MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
                        );
                        if (t != null) {
                          store
                            ..reminderMinutes = t.hour * 60 + t.minute
                            ..touch();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(22)),
                        child: Text(time, style: const TextStyle(fontSize: 19)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            if (store.notifications) ...[
              const SizedBox(height: 20),
              Panel(children: [
                InkWell(
                  onTap: () {
                    Notify.downloadCalendarReminder(store.reminderMinutes, AppConfig.appName, Uri.base.toString());
                    toast(context, 'Open the downloaded file to add the daily reminder');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(children: [
                      const Icon(Icons.event_available_rounded, color: AppColors.accent, size: 26),
                      const SizedBox(width: 18),
                      const Expanded(child: Text('Add daily reminder to Calendar', style: TextStyle(fontSize: 18))),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ]),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    var p = _permission;
                    if (p == 'default') p = await Notify.requestPermission();
                    if (mounted) setState(() => _permission = p);
                    if (p == 'granted') {
                      await Notify.show(AppConfig.appName, 'This is how your study reminder looks.');
                    } else if (context.mounted) {
                      toast(context, 'Notifications are not allowed for this site');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(children: [
                      const Icon(Icons.notifications_active_outlined, color: AppColors.accent, size: 26),
                      const SizedBox(width: 18),
                      const Expanded(child: Text('Send a test notification', style: TextStyle(fontSize: 18))),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ]),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                child: Text(
                  _hint(_permission),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  String _hint(String permission) {
    final base = 'A web app can only remind you while it is open or in the background. '
        'For a reminder at $time every day even when the app is closed, add it to Calendar '
        '(works on iPhone and Mac).';
    return switch (permission) {
      'unsupported' => 'This browser cannot show notifications. On iPhone, first add the app to the Home Screen '
          '(Share → Add to Home Screen) and open it from there. $base',
      'denied' => 'Notifications are blocked for this site in the browser settings. $base',
      _ => base,
    };
  }

  String get time => formatMinutes(StoreScope.read(context).reminderMinutes);
}

String formatMinutes(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

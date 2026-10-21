import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'queue_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final c = _scroll.offset > 60;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SafeArea(
      bottom: false,
      child: Stack(children: [
        ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 130, top: 76),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text('Account', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ),
            _ProBanner(onTap: () => _proSheet(context)),
            const SectionLabel('Account', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _Row(
                icon: Icons.mail_outline_rounded,
                title: 'Email',
                value: store.email ?? 'Not provided',
                onTap: () async {
                  final v = await promptText(context, title: 'Email', initial: store.email ?? '', hint: 'you@example.com');
                  if (v != null) {
                    store.email = v.trim().isEmpty ? null : v.trim();
                    store.touch();
                  }
                },
              ),
              _Row(
                icon: Icons.cloud_outlined,
                title: 'Sync',
                value: 'Disabled',
                onTap: () => _backupSheet(context, store),
              ),
            ]),
            const SectionLabel('Settings', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _Row(
                icon: Icons.tune_rounded,
                title: 'Spaced repetition',
                value: store.maxIntervalDays == 36500 && store.retentionGoal == 0.9 ? 'Default' : 'Custom',
                chevron: true,
                onTap: () => _srsSheet(context, store),
              ),
              _Row(
                icon: Icons.track_changes_rounded,
                title: 'Daily goals',
                value: '${store.dailyGoal} cards/day',
                chevron: true,
                onTap: () async {
                  final v = await showDailyGoalPicker(context, store.dailyGoal);
                  if (v != null) {
                    store.dailyGoal = v;
                    store.touch();
                  }
                },
              ),
              _Row(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                value: store.notifications ? 'On' : 'Off',
                chevron: true,
                onTap: () {
                  store.notifications = !store.notifications;
                  store.touch();
                },
              ),
            ]),
            const SectionLabel('AI Practice', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _Row(
                icon: Icons.record_voice_over_outlined,
                title: 'Accent',
                value: const {'en-GB': 'UK', 'en-US': 'US', 'en-AU': 'AU'}[store.accent] ?? store.accent,
                chevron: true,
                onTap: () {
                  const order = ['en-GB', 'en-US', 'en-AU'];
                  store.accent = order[(order.indexOf(store.accent) + 1) % order.length];
                  store.touch();
                },
              ),
              _Row(
                icon: Icons.speed_rounded,
                title: 'Speech speed',
                value: '${store.speechRate.toStringAsFixed(1)}×',
                chevron: true,
                onTap: () {
                  const rates = [0.6, 0.8, 0.9, 1.0, 1.2];
                  final i = rates.indexWhere((r) => (r - store.speechRate).abs() < 0.01);
                  store.speechRate = rates[(i + 1) % rates.length];
                  store.touch();
                },
              ),
              _SwitchRow(
                icon: Icons.volume_up_outlined,
                title: 'Auto-play cards',
                value: store.autoPlayAudio,
                onChanged: (v) {
                  store.autoPlayAudio = v;
                  store.touch();
                },
              ),
              _SwitchRow(
                icon: Icons.travel_explore_rounded,
                title: 'Online phrase suggestions',
                value: store.onlineSuggestions,
                onChanged: (v) {
                  store.onlineSuggestions = v;
                  store.touch();
                },
              ),
            ]),
            const SectionLabel('Appearance', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _SwitchRow(
                icon: Icons.dark_mode_rounded,
                title: 'Dark mode',
                value: store.darkMode,
                onChanged: (v) {
                  store.darkMode = v;
                  store.touch();
                },
              ),
              _Row(
                icon: Icons.app_shortcut_outlined,
                title: 'App icon',
                trailingWidget: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                chevron: true,
                onTap: () => toast(context, 'Install the app: browser menu → "Add to Home Screen"'),
              ),
            ]),
            const SectionLabel('Feedback', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _Row(icon: Icons.star_outline_rounded, title: 'Rate us', onTap: () => toast(context, 'Thank you! ⭐')),
              _Row(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Contact us',
                onTap: () => toast(context, 'Open an issue on the GitHub repository'),
              ),
              _Row(
                icon: Icons.ios_share_rounded,
                title: 'Share with friends',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: Uri.base.toString()));
                  toast(context, 'Link copied');
                },
              ),
            ]),
            const SectionLabel('Legal', padding: EdgeInsets.fromLTRB(36, 28, 20, 12)),
            Panel(children: [
              _Row(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _legal(context, 'Terms of Service',
                    'This is a personal study app provided as is, without warranty. You are responsible for the content of your cards.'),
              ),
              _Row(
                icon: Icons.back_hand_outlined,
                title: 'Privacy Policy',
                onTap: () => _legal(context, 'Privacy Policy',
                    'All decks, cards and statistics are stored only in this browser (localStorage). '
                        'Speech recognition is performed by your browser\'s speech service. '
                        'When online suggestions are on, the word you add is sent to api.datamuse.com.'),
              ),
            ]),
            const SizedBox(height: 40),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await confirm(context, 'Sign out?',
                      'This erases all decks and progress stored in this browser. Export a backup first if needed.',
                      action: 'Sign Out');
                  if (ok) store.eraseAll();
                },
                icon: const Icon(Icons.login_rounded, color: AppColors.danger, size: 30),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.danger, fontSize: 22)),
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Made with '),
                  const TextSpan(text: '♥', style: TextStyle(color: AppColors.newRed)),
                  TextSpan(text: ' by ${AppConfig.author}.'),
                ]),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 19),
              ),
            ),
          ],
        ),
        // Collapsed header + "..." button.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 76,
            color: _collapsed ? AppColors.bg.withValues(alpha: 0.95) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(alignment: Alignment.center, children: [
              AnimatedOpacity(
                opacity: _collapsed ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Text('Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: RoundButton(
                  onTap: () => _backupSheet(context, store),
                  child: const Icon(Icons.more_horiz_rounded, size: 30),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _legal(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _proSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium_rounded, size: 56, color: AppColors.accent),
            const SizedBox(height: 12),
            Text('${AppConfig.appName} PRO', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Everything is already unlocked in this open-source build: unlimited decks, AI Practice and phrase suggestions. '
              'Use "Sync → Export backup" to keep your progress safe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            GradientButton(height: 56, onTap: () => Navigator.pop(ctx), child: const Text('Great!')),
          ]),
        ),
      ),
    );
  }

  void _srsSheet(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Spaced repetition (SM-2)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Learning steps: 1 min → 10 min. Graduating interval 1 day, easy 4 days, starting ease 250%.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Text('Retention goal: ${(store.retentionGoal * 100).round()} %'),
              Slider(
                value: store.retentionGoal,
                min: 0.7,
                max: 0.97,
                divisions: 27,
                onChanged: (v) {
                  store.retentionGoal = double.parse(v.toStringAsFixed(2));
                  store.touch();
                  set(() {});
                },
              ),
              Text('Maximum interval: ${store.maxIntervalDays >= 36500 ? '100 years' : '${store.maxIntervalDays} days'}'),
              Slider(
                value: [30, 90, 180, 365, 730, 36500].indexOf(store.maxIntervalDays).clamp(0, 5).toDouble(),
                max: 5,
                divisions: 5,
                onChanged: (v) {
                  store.maxIntervalDays = const [30, 90, 180, 365, 730, 36500][v.round()];
                  store.touch();
                  set(() {});
                },
              ),
              TextButton(
                onPressed: () {
                  store.retentionGoal = 0.9;
                  store.maxIntervalDays = 36500;
                  store.touch();
                  set(() {});
                },
                child: const Text('Reset to default'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _backupSheet(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.upload_rounded),
            title: const Text('Export backup (copy JSON)'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: store.exportJson()));
              Navigator.pop(ctx);
              toast(context, 'Backup copied to clipboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Import backup (paste JSON)'),
            onTap: () async {
              Navigator.pop(ctx);
              final raw = await promptText(context, title: 'Paste backup JSON', action: 'Import', maxLines: 6);
              if (raw == null || !context.mounted) return;
              toast(context, store.importJson(raw) ? 'Backup restored' : 'That is not a valid backup');
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Reset to demo data'),
            onTap: () async {
              Navigator.pop(ctx);
              if (await confirm(context, 'Reset?', 'Replaces everything with the demo decks.', action: 'Reset')) {
                store.resetToDemo();
              }
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 88,
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(30)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text('Try ${AppConfig.appName} PRO Free',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            const Text('Never lose your study progress',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.value, this.chevron = false, this.onTap, this.trailingWidget});
  final IconData icon;
  final String title;
  final String? value;
  final bool chevron;
  final VoidCallback? onTap;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(children: [
          Icon(icon, color: AppColors.accent, size: 30),
          const SizedBox(width: 20),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20))),
          if (value != null) Text(value!, style: TextStyle(color: AppColors.textSecondary, fontSize: 19)),
          if (trailingWidget != null) trailingWidget!,
          if (chevron) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Icon(icon, color: AppColors.accent, size: 30),
        const SizedBox(width: 20),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20))),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

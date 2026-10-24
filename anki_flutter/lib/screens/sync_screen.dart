import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../display.dart';
import '../services/sync.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_pages.dart';

const _tokenUrl = 'https://github.com/settings/tokens/new?scopes=gist&description=Anki%20Flow%20sync';

/// Profile → Sync: end-to-end encrypted sync between Mac, iPhone and any other browser.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _sync = SyncService.instance;
  final _token = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _withCode = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_refresh);
  }

  @override
  void dispose() {
    _sync.removeListener(_refresh);
    for (final c in [_token, _code, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_withCode) {
        await _sync.connectWithCode(code: _code.text, password: _password.text);
      } else {
        if (_password.text != _password2.text) throw SyncException('The two passwords are different.');
        await _sync.connect(token: _token.text, password: _password.text);
      }
      _password.clear();
      _password2.clear();
      _token.clear();
      _code.clear();
      if (mounted) toast(context, 'Sync is on');
    } on SyncException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not reach GitHub. Check the internet connection and try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const SubPageHeader(title: 'Sync'),
            const SizedBox(height: 18),
            _hero(),
            if (_sync.enabled) ..._connected() else ..._setup(),
            _security(),
          ]),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: AppColors.queueGradient, borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        const Icon(Icons.devices_rounded, color: Colors.white, size: 44),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mac ⇄ iPhone',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Decks, cards, progress and settings stay the same on all your devices. Encrypted end to end.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, height: 1.35)),
          ]),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------ connected

  List<Widget> _connected() {
    final s = _sync;
    final (icon, color, text) = switch (s.status) {
      SyncStatus.syncing => (Icons.sync_rounded, AppColors.accent, 'Syncing…'),
      SyncStatus.error => (Icons.cloud_off_rounded, AppColors.todayOrange, s.error ?? 'Sync failed'),
      _ => (Icons.cloud_done_rounded, AppColors.reviewGreen, 'Synced ${_ago(s.lastSync)}'),
    };
    return [
      const SectionLabel('Status', padding: EdgeInsets.fromLTRB(40, 26, 20, 10)),
      Panel(children: [
        _row(icon, text, color: color),
        _row(Icons.person_outline_rounded, 'GitHub account: ${s.login ?? '—'}'),
        _row(Icons.sync_rounded, 'Sync now', chevron: true, onTap: s.status == SyncStatus.syncing ? null : s.syncNow),
      ]),
      const SectionLabel('Add another device', padding: EdgeInsets.fromLTRB(40, 26, 20, 10)),
      Panel(children: [
        _row(Icons.qr_code_2_rounded, 'Copy setup code', chevron: true, onTap: _showSetupCode),
      ]),
      _note('On the iPhone open the app → Profile → Sync → "I have a setup code", paste the code (send it to '
          'yourself via AirDrop, Notes or Messages) and type the same sync password. The code is encrypted with '
          'that password, so it is useless to anyone who doesn\'t know it.'),
      const SizedBox(height: 18),
      Center(
        child: TextButton.icon(
          onPressed: () async {
            if (await confirm(context, 'Turn off sync on this device?',
                'Your cards stay on this device and in the encrypted backup. Other devices keep syncing.',
                action: 'Turn off')) {
              await s.disconnect();
            }
          },
          icon: const Icon(Icons.link_off_rounded, color: AppColors.danger),
          label: const Text('Turn off sync on this device', style: TextStyle(color: AppColors.danger, fontSize: 17)),
        ),
      ),
    ];
  }

  /// Shows the code in a dialog. Copying happens on the dialog's own button:
  /// Safari only allows clipboard writes directly inside a tap, not after the
  /// code has been encrypted asynchronously.
  Future<void> _showSetupCode() async {
    final String code;
    try {
      code = await _sync.exportSetupCode();
    } catch (e) {
      if (mounted) toast(context, 'Could not create the code: $e');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setup code'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Paste it on the other device: Profile → Sync → "I have a setup code", with the same sync password.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code)).then((_) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) toast(context, 'Setup code copied');
              }, onError: (_) {
                if (mounted) toast(context, 'Copy blocked by the browser: select the code and copy it by hand');
              });
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- setup

  List<Widget> _setup() {
    return [
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('First device')),
            ButtonSegment(value: true, label: Text('I have a setup code')),
          ],
          selected: {_withCode},
          onSelectionChanged: (v) => setState(() {
            _withCode = v.first;
            _error = null;
          }),
        ),
      ),
      if (!_withCode)
        _note('1. Create a GitHub access token with only the "gist" permission: '
            'github.com → Settings → Developer settings → Personal access tokens → Tokens (classic) → '
            'Generate new token → tick "gist". Free GitHub account is enough.\n'
            '2. Paste it below and invent a sync password (at least 8 characters). Remember it: '
            'without it nobody, including you, can read the backup.'),
      if (!_withCode)
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 6, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: _tokenUrl));
                toast(context, 'Link copied: open it in the browser');
              },
              icon: const Icon(Icons.link_rounded, color: AppColors.accent),
              label: const Text('Copy link to create the token', style: TextStyle(color: AppColors.accent)),
            ),
          ),
        ),
      if (_withCode)
        _note('On the device where sync is already on: Profile → Sync → Copy setup code. '
            'Paste it here and type the same sync password.'),
      const SizedBox(height: 10),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
        child: Column(children: [
          if (_withCode)
            _field(_code, 'Setup code (AFSYNC1…)', maxLines: 3)
          else
            _field(_token, 'GitHub token (ghp_…)', obscure: true),
          _field(_password, 'Sync password', obscure: !_showPassword, suffix: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          )),
          if (!_withCode) _field(_password2, 'Repeat sync password', obscure: !_showPassword),
        ]),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 15)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: GradientButton(
            height: 58,
            onTap: _busy ? null : _connect,
            child: _busy
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Encrypting…'),
                  ])
                : const Text('Turn on sync'),
          ),
        ),
      ),
    ];
  }

  Widget _security() => Container(
        margin: const EdgeInsets.fromLTRB(20, 26, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.lock_rounded, color: AppColors.reviewGreen),
            SizedBox(width: 10),
            Text('How it stays safe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(
            '• Everything is encrypted on your device with AES-256-GCM before it leaves it. The key is made from '
            'your sync password (PBKDF2-SHA256, 210 000 rounds) and is never uploaded.\n'
            '• GitHub only stores unreadable ciphertext in a secret gist in your own account. No other server is used.\n'
            '• The token can only touch gists: not your code, not your account.\n'
            '• Changes made on both devices are merged, nothing is overwritten. Works offline and catches up later.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.5),
          ),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
        child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.45)),
      );

  Widget _field(TextEditingController c, String label, {bool obscure = false, int maxLines = 1, Widget? suffix}) =>
      TextField(
        controller: c,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(labelText: label, suffixIcon: suffix),
      );

  Widget _row(IconData icon, String text, {Color? color, bool chevron = false, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(children: [
            Icon(icon, color: color ?? AppColors.accent, size: 26),
            const SizedBox(width: 18),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 17))),
            if (chevron) Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      );
}

String _ago(DateTime? t) {
  if (t == null) return 'not yet';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Short status for the Profile row.
String syncSummary() {
  final s = SyncService.instance;
  if (!s.enabled) return 'Off';
  return switch (s.status) {
    SyncStatus.syncing => 'Syncing…',
    SyncStatus.error => 'Offline',
    _ => 'On',
  };
}

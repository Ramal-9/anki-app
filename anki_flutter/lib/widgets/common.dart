import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Round dark button used in headers (target, +, menu, quit...).
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.child, this.onTap, this.size = 52, this.wide = false});
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: wide ? null : size,
        padding: wide ? const EdgeInsets.symmetric(horizontal: 20) : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: AppColors.dark ? Colors.white10 : Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: IconTheme(data: IconThemeData(color: AppColors.text, size: 26), child: child),
      ),
    );
  }
}

/// Full-width pill with the brand gradient ("Show answer", "Try PRO").
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.child, this.onTap, this.height = 64, this.gradient});
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.brandGradient,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          child: child,
        ),
      ),
    );
  }
}

/// Grey gradient deck tile with name, card count and due count.
class DeckTile extends StatelessWidget {
  const DeckTile({super.key, required this.name, required this.cards, required this.due, this.onTap});
  final String name;
  final int cards;
  final int due;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 108,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        decoration: BoxDecoration(
          gradient: AppColors.deckTile,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              ),
            ]),
            const Spacer(),
            Row(children: [
              Text('$cards cards',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.school_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text('$due', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// New / Learning / Review pill.
class StateTag extends StatelessWidget {
  const StateTag(this.state, {super.key});
  final CardState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      CardState.newCard => ('New', AppColors.newRed),
      CardState.learning => ('Learning', AppColors.learningBlue),
      CardState.review => ('Review', AppColors.reviewGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

/// Rounded surface container that groups list rows.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children, this.margin});
  final List<Widget> children;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 68, right: 18),
          child: Divider(height: 1, color: AppColors.divider),
        ));
      }
    }
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// Wavy gradient logo shown at the top of the Queue screen.
class SquiggleLogo extends StatelessWidget {
  const SquiggleLogo({super.key, this.width = 70});
  final double width;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * 0.42), painter: _SquigglePainter());
}

class _SquigglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.04, h * 0.25)
      ..cubicTo(w * 0.18, h * 0.35, w * 0.22, h * 0.95, w * 0.3, h * 0.8)
      ..cubicTo(w * 0.36, h * 0.65, w * 0.3, h * 0.2, w * 0.42, h * 0.3)
      ..cubicTo(w * 0.52, h * 0.4, w * 0.5, h * 0.9, w * 0.6, h * 0.75)
      ..cubicTo(w * 0.68, h * 0.6, w * 0.66, h * 0.25, w * 0.76, h * 0.38)
      ..cubicTo(w * 0.84, h * 0.48, w * 0.9, h * 0.42, w * 0.97, h * 0.4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.22
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFF2A46B), Color(0xFFE07FA0), Color(0xFFB28BE6), Color(0xFF7FC6E0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// Simple text prompt dialog. Returns null when cancelled.
Future<String?> promptText(BuildContext context,
    {required String title, String initial = '', String hint = '', String action = 'Save', int maxLines = 1}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: maxLines == 1 ? (v) => Navigator.pop(ctx, v) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(action)),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body, {String action = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: AppColors.danger))),
      ],
    ),
  );
  return r ?? false;
}

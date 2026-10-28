import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// What a notice is about: it picks the stamp on the left of the slip.
enum NoticeKind { info, arrive, away, leave, mention, error, done }

/// The table notices: a small paper slip, like a telegram strip, that
/// slides in at the top, stays a few seconds and goes. At most two at a
/// time (a third pushes the oldest out). They float above the screen, so
/// nothing below moves, and they never catch a tap.
void showNotice(BuildContext context, String text, {NoticeKind kind = NoticeKind.info}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _NoticeBoard.of(overlay).add(text, kind);
}

/// Like [showNotice], on an overlay taken before an `await` (when the
/// screen that asked may be gone by the time the answer comes).
void showNoticeIn(OverlayState overlay, String text, {NoticeKind kind = NoticeKind.info}) {
  if (!overlay.mounted) return;
  _NoticeBoard.of(overlay).add(text, kind);
}

class _NoticeBoard {
  final OverlayState overlay;
  final notices = ValueNotifier<List<_Notice>>(const []);
  late final OverlayEntry entry = OverlayEntry(builder: (_) => _NoticeStack(board: this));
  var _next = 0;

  _NoticeBoard(this.overlay) {
    overlay.insert(entry);
  }

  static _NoticeBoard? _current;

  static _NoticeBoard of(OverlayState overlay) {
    final current = _current;
    if (current != null && current.overlay == overlay && overlay.mounted) return current;
    return _current = _NoticeBoard(overlay);
  }

  void add(String text, NoticeKind kind) {
    // The same words twice in a row: once is enough.
    if (notices.value.any((n) => n.text == text)) return;
    final list = [...notices.value, _Notice(_next++, text, kind)];
    notices.value = list.length > 2 ? list.sublist(list.length - 2) : list;
  }

  void remove(_Notice notice) => notices.value = [
    for (final n in notices.value)
      if (n != notice) n,
  ];
}

class _Notice {
  final int id;
  final String text;
  final NoticeKind kind;

  _Notice(this.id, this.text, this.kind);
}

class _NoticeStack extends StatelessWidget {
  final _NoticeBoard board;

  const _NoticeStack({required this.board});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 900;
    final width = wide ? 460.0 : min(media.size.width - 32, 400.0);
    return Positioned(
      top: media.padding.top + (wide ? 92 : 58),
      left: (media.size.width - width) / 2,
      width: width,
      child: IgnorePointer(
        child: ValueListenableBuilder<List<_Notice>>(
          valueListenable: board.notices,
          builder: (context, notices, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final notice in notices.reversed)
                NoticeSlip(
                  key: ValueKey(notice.id),
                  text: notice.text,
                  kind: notice.kind,
                  wide: wide,
                  onGone: () => board.remove(notice),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slip of paper. Public so the render tool can draw it on its own.
class NoticeSlip extends StatefulWidget {
  final String text;
  final NoticeKind kind;
  final bool wide;
  final VoidCallback? onGone;

  const NoticeSlip({super.key, required this.text, this.kind = NoticeKind.info, this.wide = false, this.onGone});

  static const paper = Color(0xFFEFE4CB);
  static const ink = Color(0xFF1C140E);

  static (IconData, Color) stamp(NoticeKind kind) => switch (kind) {
    NoticeKind.info => (Icons.mail_outline, const Color(0xFF6B5532)),
    NoticeKind.arrive => (Icons.login, const Color(0xFF2F6B45)),
    NoticeKind.away => (Icons.wifi_off, const Color(0xFF8A6A1E)),
    NoticeKind.leave => (Icons.logout, const Color(0xFF9E1B1B)),
    NoticeKind.mention => (Icons.alternate_email, const Color(0xFF7A2B6B)),
    NoticeKind.error => (Icons.priority_high, const Color(0xFF9E1B1B)),
    NoticeKind.done => (Icons.check, const Color(0xFF2F6B45)),
  };

  @override
  State<NoticeSlip> createState() => _NoticeSlipState();
}

class _NoticeSlipState extends State<NoticeSlip> with SingleTickerProviderStateMixin {
  late final _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _show.forward();
    if (widget.onGone != null) {
      final stay = widget.kind == NoticeKind.error ? 5200 : 3600;
      _timer = Timer(Duration(milliseconds: stay), () {
        if (!mounted) return;
        _show.reverse().whenComplete(() {
          if (mounted) widget.onGone?.call();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = NoticeSlip.stamp(widget.kind);
    final k = widget.wide ? 1.12 : 1.0;
    final slip = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4EAD2), NoticeSlip.paper, Color(0xFFDCCBA6)],
        ),
        border: Border.all(color: const Color(0x551C140E)),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5 * k, color: color),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 8 * k),
              child: Container(
                width: 26 * k,
                height: 26 * k,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.6)),
                child: Icon(icon, size: 15 * k, color: color),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 9 * k, 14 * k, 9 * k),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['serif'],
                      color: NoticeSlip.ink,
                      fontSize: 14 * k,
                      height: 1.25,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _show,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_show.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -24),
            child: Transform.rotate(angle: -0.008, child: child),
          ),
        );
      },
      child: slip,
    );
  }
}

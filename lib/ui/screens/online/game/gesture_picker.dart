import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../l10n/app_language.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../online/reactions.dart';
import '../../../widgets/noir_modal.dart';
import '../voice/voice_dock.dart';
import 'noir_ui.dart';
import 'table_gestures.dart';

/// I testi dei gesti.
class GestureStrings {
  final bool it;

  const GestureStrings(this.it);

  static GestureStrings of(BuildContext context) => GestureStrings(AppStrings.of(context).language == AppLanguage.it);

  String title(String name) => it ? 'Un gesto per $name' : 'A gesture for $name';
  String get hint => it ? 'Lo vedono tutti al tavolo.' : 'The whole table sees it.';
  String get locked => it ? 'In bottega' : 'In the shop';
  String wait(int seconds) => it ? 'Il prossimo fra $seconds s' : 'Next one in $seconds s';
  String get report => it ? 'Segnala o blocca' : 'Report or block';
  String get settingTitle => it ? 'Gesti al tavolo' : 'Table gestures';
  String get settingHint =>
      it ? 'Spenti, nessuno può lanciarti sigari, rose o pesci.' : 'Off, nobody can throw cigars, roses or fish at you.';
}

/// Il cassetto dei gesti, aperto tenendo premuto (o col tasto destro) il
/// posto di un altro: i gesti di casa e quelli comprati si lanciano, gli
/// altri restano col lucchetto. Restituisce il gesto scelto, o null.
/// [onReport] apre le segnalazioni, come prima del cassetto.
Future<TableGesture?> showGesturePicker(
  BuildContext context, {
  required String name,
  required bool italian,
  required Set<TableGesture> owned,
  Duration wait = Duration.zero,
  VoidCallback? onReport,
  VoiceMuteAction? voice,
}) {
  final s = GestureStrings(italian);
  return showNoirSheet<TableGesture>(
    context,
    builder: (context) => NoirSheet(
      key: const Key('gestures.picker'),
      title: s.title(name),
      subtitle: wait > Duration.zero ? s.wait((wait.inMilliseconds / 1000).ceil()) : s.hint,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final gesture in TableGesture.values)
              GestureTile(
                gesture: gesture,
                label: gesture.label(italian ? AppLanguage.it : AppLanguage.en),
                open: gesture.free || owned.contains(gesture),
                lockedLabel: s.locked,
                onTap: wait > Duration.zero ? null : () => Navigator.of(context).pop(gesture),
              ),
          ],
        ),
        if (voice != null) ...[
          const SizedBox(height: 16),
          NoirModalButton(
            key: const Key('voice.muteSeat'),
            action: NoirAction(
              label: voice.label,
              icon: voice.muted ? Icons.volume_up : Icons.volume_off,
              onPressed: () {
                Navigator.of(context).pop();
                voice.toggle();
              },
            ),
          ),
        ],
        if (onReport != null) ...[
          SizedBox(height: voice != null ? 8 : 16),
          NoirModalButton(
            key: const Key('gestures.report'),
            action: NoirAction(
              label: s.report,
              icon: Icons.flag_outlined,
              style: NoirButtonStyle.quiet,
              onPressed: () {
                Navigator.of(context).pop();
                onReport();
              },
            ),
          ),
        ],
      ],
    ),
  );
}

/// Un gesto nel cassetto: si muove sotto il mouse (non col movimento ridotto).
class GestureTile extends StatefulWidget {
  final TableGesture gesture;
  final String label;
  final bool open;
  final String lockedLabel;
  final VoidCallback? onTap;

  const GestureTile({
    super.key,
    required this.gesture,
    required this.label,
    required this.open,
    required this.lockedLabel,
    this.onTap,
  });

  @override
  State<GestureTile> createState() => _GestureTileState();
}

class _GestureTileState extends State<GestureTile> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _hover = false;

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _hovered(bool on) {
    setState(() => _hover = on);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (on && !still) {
      _idle.repeat();
    } else {
      _idle.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tap = widget.open ? widget.onTap : null;
    final color = widget.gesture.legendary ? const Color(0xFFE7C33A) : Saloon.brass;
    return Semantics(
      button: true,
      enabled: tap != null,
      label: widget.label,
      child: MouseRegion(
        cursor: tap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => _hovered(true),
        onExit: (_) => _hovered(false),
        child: GestureDetector(
          key: Key('gestures.${widget.gesture.name}'),
          onTap: tap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 96,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            decoration: BoxDecoration(
              color: _hover && tap != null ? Saloon.wood : Saloon.ink.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: widget.open ? 0.8 : 0.25)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Opacity(
                    opacity: widget.open ? 1 : 0.35,
                    child: AnimatedBuilder(
                      animation: _idle,
                      builder: (context, _) => CustomPaint(painter: GestureArt(widget.gesture, t: _idle.value + 0.2)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.open ? widget.label : '🔒 ${widget.lockedLabel}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.open ? Saloon.paper : Saloon.paper.withValues(alpha: 0.5),
                    fontSize: 11,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// I gesti in vetrina, nella bottega: uno solo gira da solo (fermo col
/// movimento ridotto), più d'uno si mettono in fila.
class GestureShowcase extends StatefulWidget {
  final List<TableGesture> gestures;

  const GestureShowcase({super.key, required this.gestures});

  @override
  State<GestureShowcase> createState() => _GestureShowcaseState();
}

class _GestureShowcaseState extends State<GestureShowcase> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = widget.gestures;
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final t = _loop.value;
        if (gestures.length == 1) {
          // L'arrivo dei leggendari, poi una pausa: la scena intera, in giro.
          final land = gestures.single.legendary ? (t < 0.7 ? t / 0.7 : 0.0) : 0.0;
          return CustomPaint(painter: GestureArt(gestures.single, t: t, land: land), child: const SizedBox.expand());
        }
        return LayoutBuilder(builder: (context, box) {
          final cols = (gestures.length / 2).ceil().clamp(1, 4);
          final rows = (gestures.length / cols).ceil();
          final side = min(box.maxWidth / cols, box.maxHeight / rows);
          return Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final g in gestures)
                  SizedBox.square(dimension: side, child: CustomPaint(painter: GestureArt(g, t: t))),
              ],
            ),
          );
        });
      },
    );
  }
}

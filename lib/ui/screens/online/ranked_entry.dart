import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import 'game/noir_ui.dart';

/// La porta della stanza sul retro: lo spioncino, le targhe d'ottone, la
/// lingua del tavolo su due biglietti e il grande "CERCA PARTITA".
/// Mentre si cerca, dallo spioncino passa una luce che va e viene.
class RankedEntryView extends StatelessWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;
  final bool queued;
  final Animation<double> sweep;
  final String? cooldown;
  final bool warning;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const RankedEntryView({
    super.key,
    required this.language,
    required this.onLanguage,
    required this.queued,
    required this.sweep,
    required this.cooldown,
    required this.warning,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    final en = strings.language == AppLanguage.en;
    return Scaffold(
      backgroundColor: const Color(0xFF0C0806),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.45),
            radius: 1.15,
            colors: [Color(0xFF3A2414), Color(0xFF1A100A), Color(0xFF080504)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 16, 0),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: MaterialLocalizations.of(context).backButtonTooltip,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(width: 48, height: 48, child: CustomPaint(painter: _ChevronPainter())),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        t.rankedQueueTitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 13, letterSpacing: 4),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: min(300, box.maxHeight * 0.42),
                            child: AnimatedBuilder(
                              animation: sweep,
                              builder: (context, _) => CustomPaint(
                                size: Size.infinite,
                                painter: _DoorPainter(queued ? sweep.value : null),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _Plate(
                            child: Text(
                              en ? 'Twelve at the table · timed rounds · a rank to earn' : 'Dodici al tavolo · turni a tempo · un grado da guadagnare',
                              textAlign: TextAlign.center,
                              style: AppText.body.copyWith(color: Saloon.paper, fontSize: 13, height: 1.35),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PICCIOTTO  ›  CAPODECINA  ›  CAPOREGIME  ›  CONSIGLIERE  ›  DON',
                            textAlign: TextAlign.center,
                            style: AppText.overline.copyWith(color: Saloon.brass.withValues(alpha: 0.8), fontSize: 9.5, letterSpacing: 1.4),
                          ),
                          const SizedBox(height: 22),
                          if (queued) ...[
                            Text(t.rankedSearching, key: const Key('ranked.searching'), textAlign: TextAlign.center, style: AppText.display(20, color: Saloon.paper)),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: NoirButton(key: const Key('ranked.cancel'), kind: NoirButtonKind.brass, label: t.rankedCancel, onPressed: onCancel),
                            ),
                          ] else ...[
                            Text(
                              en ? 'LANGUAGE AT THE TABLE' : 'LINGUA DEL TAVOLO',
                              style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 10, letterSpacing: 3),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final (lang, label) in const [(AppLanguage.it, 'Italiano'), (AppLanguage.en, 'English')]) ...[
                                  if (lang == AppLanguage.en) const SizedBox(width: 12),
                                  Expanded(
                                    child: _Ticket(
                                      key: Key('ranked.lang.${lang.name}'),
                                      label: label,
                                      selected: language == lang,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        onLanguage(lang);
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 22),
                            if (cooldown != null)
                              _Plate(child: Text(cooldown!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.gold)))
                            else
                              SizedBox(
                                width: double.infinity,
                                child: NoirButton(key: const Key('ranked.start'), label: t.rankedStart.toUpperCase(), onPressed: onStart),
                              ),
                          ],
                          if (warning) ...[
                            const SizedBox(height: 14),
                            Text(t.rankedWarning, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una targa d'ottone avvitata: bordo, viti, fondo scuro.
class _Plate extends StatelessWidget {
  final Widget child;
  const _Plate({required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const _PlatePainter(),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12), child: child),
      );
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1C130C));
    canvas.drawRRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = const LinearGradient(colors: [Color(0xFFE6C27A), Color(0xFF8A6422), Color(0xFFD9B160)])
            .createShader(Offset.zero & size),
    );
    final screw = Paint()..color = const Color(0xFFB8913F);
    for (final c in [Offset(9, size.height / 2), Offset(size.width - 9, size.height / 2)]) {
      canvas.drawCircle(c, 3, screw);
      canvas.drawLine(c - const Offset(2, 2), c + const Offset(2, 2), Paint()..color = const Color(0xFF4A3412)..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => false;
}

/// Un biglietto d'ingresso con le tacche ai lati: quello scelto è d'ottone.
class _Ticket extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Ticket({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.96,
            duration: const Duration(milliseconds: 180),
            child: CustomPaint(
              painter: _TicketPainter(selected),
              child: SizedBox(
                height: 62,
                child: Center(
                  child: Text(
                    label,
                    style: AppText.display(20, color: selected ? const Color(0xFF2A1A0A) : Saloon.paper.withValues(alpha: 0.75)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _TicketPainter extends CustomPainter {
  final bool selected;
  const _TicketPainter(this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final notch = 9.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height / 2 - notch)
      ..arcToPoint(Offset(size.width, size.height / 2 + notch), radius: Radius.circular(notch), clockwise: false)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height / 2 + notch)
      ..arcToPoint(Offset(0, size.height / 2 - notch), radius: Radius.circular(notch), clockwise: false)
      ..close();
    canvas.drawShadow(path, Colors.black, selected ? 6 : 2, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? const [Color(0xFFF0D392), Color(0xFFC79A45), Color(0xFFE2BC6C)]
              : const [Color(0xFF2A1D13), Color(0xFF1A120C)],
        ).createShader(Offset.zero & size),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = selected ? const Color(0xFF6E4C18) : Saloon.brass.withValues(alpha: 0.55);
    canvas.drawPath(path, edge);
    // La linea tratteggiata della matrice.
    final dash = Paint()
      ..color = edge.color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var y = 6.0; y < size.height - 6; y += 6) {
      canvas.drawLine(Offset(size.width * 0.84, y), Offset(size.width * 0.84, y + 3), dash);
    }
  }

  @override
  bool shouldRepaint(_TicketPainter old) => old.selected != selected;
}

/// La porta di legno, con lo spioncino a griglia; da dentro, mentre si
/// cerca, una luce calda passa e torna dietro le sbarre.
class _DoorPainter extends CustomPainter {
  final double? sweep;
  const _DoorPainter(this.sweep);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = min(size.width * 0.7, h * 0.62);
    final door = Rect.fromCenter(center: Offset(size.width / 2, h / 2 + 6), width: w, height: h - 12);
    // Lo stipite di pietra e la luce che filtra sotto la porta.
    canvas.drawRect(door.inflate(10), Paint()..color = const Color(0xFF231812));
    canvas.drawRect(
      Rect.fromLTWH(door.left - 30, door.bottom, door.width + 60, 10),
      Paint()
        ..shader = RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.35), Colors.transparent])
            .createShader(Rect.fromLTWH(door.left - 30, door.bottom - 10, door.width + 60, 30)),
    );
    canvas.drawRect(
      door,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF3B2516), Color(0xFF52331D), Color(0xFF3A2414)])
            .createShader(door),
    );
    // Le assi e i pannelli.
    final groove = Paint()
      ..color = const Color(0xFF1E130B)
      ..strokeWidth = 1.4;
    for (var i = 1; i < 5; i++) {
      final x = door.left + door.width * i / 5;
      canvas.drawLine(Offset(x, door.top), Offset(x, door.bottom), groove);
    }
    final panel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF26180E);
    canvas.drawRect(Rect.fromLTRB(door.left + 14, door.center.dy + 14, door.right - 14, door.bottom - 16), panel);
    // Lo spioncino: una finestrella con la griglia d'ottone.
    final hatch = Rect.fromCenter(center: Offset(door.center.dx, door.top + door.height * 0.28), width: w * 0.42, height: w * 0.24);
    final s = sweep;
    final glow = s == null ? 0.12 : 0.35 + 0.45 * (0.5 + 0.5 * sin(s * 2 * pi));
    canvas.drawRect(hatch, Paint()..color = const Color(0xFF0A0604));
    canvas.drawRect(
      hatch,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(s == null ? 0 : sin(s * 2 * pi) * 0.8, 0),
          radius: 0.9,
          colors: [AppColors.gold.withValues(alpha: glow), Colors.transparent],
        ).createShader(hatch),
    );
    final brass = Paint()
      ..color = const Color(0xFFC9A04C)
      ..strokeWidth = 2.4;
    for (var i = 1; i < 5; i++) {
      final x = hatch.left + hatch.width * i / 5;
      canvas.drawLine(Offset(x, hatch.top), Offset(x, hatch.bottom), brass);
    }
    canvas.drawRect(hatch.inflate(3), Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0xFFB8913F));
    // Le borchie, la maniglia e la targhetta col numero.
    final stud = Paint()..color = const Color(0xFF8E6B2E);
    for (final dy in [0.06, 0.94]) {
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(Offset(door.left + door.width * (i + 0.5) / 5, door.top + door.height * dy), 2.4, stud);
      }
    }
    final knob = Offset(door.right - w * 0.13, door.center.dy + 6);
    canvas.drawCircle(knob, 6.5, Paint()..color = const Color(0xFFD8B464));
    canvas.drawCircle(knob.translate(-1.5, -1.5), 2, Paint()..color = const Color(0xFFFFF0C4));
    final plate = Rect.fromCenter(center: Offset(door.center.dx, door.top + door.height * 0.5), width: w * 0.22, height: 14);
    canvas.drawRRect(RRect.fromRectAndRadius(plate, const Radius.circular(2)), Paint()..color = const Color(0xFFB8913F));
    final number = TextPainter(
      text: const TextSpan(text: '13', style: TextStyle(color: Color(0xFF2A1A0A), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    )..layout();
    number.paint(canvas, plate.center - Offset(number.width / 2, number.height / 2));
  }

  @override
  bool shouldRepaint(_DoorPainter old) => old.sweep != sweep;
}

/// La freccia "indietro" disegnata in ottone, al posto dell'icona.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 5, c.dy - 9)
        ..lineTo(c.dx - 5, c.dy)
        ..lineTo(c.dx + 5, c.dy + 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = Saloon.brass,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => false;
}

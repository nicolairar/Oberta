import 'dart:math';

import 'package:flutter/material.dart';

import '../../../widgets/cosmetics/seat_frame.dart';
import '../../../widgets/cosmetics/styled_name.dart';

import '../../../../l10n/roles_sheet_strings.dart';
import '../../../../rules/role.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/role_style.dart';
import '../../../widgets/player_avatar.dart';
import 'noir_ui.dart';

/// Un posto al tavolo: un ritratto ad arco con la targhetta del nome.
/// Tutti i posti sono grandi uguali. Sopra, quello che serve al gioco:
/// scelto (alone d'oro), accusato (bordo rosso e nastro), quanti voti ha,
/// il pizzino con chi accusa, morto (grigio, con il garofano).
class SeatCard extends StatelessWidget {
  final String name;

  /// Il numero di posto, stabile per tutta la partita: «3 anna».
  final int? number;
  final double width;
  final bool fallen;
  final bool offline;
  final bool selected;
  final bool me;

  /// Il più accusato: bordo rosso e il nastro [accusedLabel].
  final bool accused;
  final String accusedLabel;

  /// Quanti voti ha (zero: nessun bollo).
  final int votes;

  /// Chi accusa questo giocatore, scritto sul suo pizzino.
  final String? pizzino;
  final Key? pizzinoKey;
  final Color pizzinoColor;

  /// Il timbro del linciato sta sul petto ([LynchMark]): il pizzino sale.
  final bool stamped;

  /// Una riga sotto il nome (un ruolo scoperto, «offline»).
  final String? note;
  final Color noteColor;

  /// Il ruolo, se è pubblico: la sua icona sul ritratto.
  final Role? role;

  /// Si può scegliere adesso: un filo d'ottone acceso intorno al ritratto.
  final bool selectable;

  /// Spento: non si può scegliere (resta leggibile).
  final bool dimmed;
  final VoidCallback? onTap;

  /// Tenendo premuto: il foglio del giocatore (segnalarlo, bloccarlo).
  final VoidCallback? onLongPress;

  const SeatCard({
    super.key,
    required this.name,
    this.number,
    required this.width,
    this.fallen = false,
    this.offline = false,
    this.selected = false,
    this.me = false,
    this.accused = false,
    this.accusedLabel = '',
    this.votes = 0,
    this.pizzino,
    this.pizzinoKey,
    this.pizzinoColor = Saloon.blood,
    this.stamped = false,
    this.note,
    this.noteColor = Saloon.brass,
    this.role,
    this.selectable = false,
    this.dimmed = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => _SeatHover(
        enabled: onTap != null || onLongPress != null,
        builder: (hover) => _card(context, hover && selectable),
      );

  /// [hover]: il mouse è sopra un posto che si può scegliere.
  Widget _card(BuildContext context, bool hover) {
    final tips = RolesSheetStrings.of(context);
    final height = width * 1.32;
    final arch = BorderRadius.vertical(top: Radius.circular(width / 2), bottom: Radius.circular(width * 0.12));
    final border = accused
        ? Saloon.blood
        : hover
        ? const Color(0xFFF2D58A)
        : selected || selectable
        ? Saloon.brass
        : Saloon.brassDeep;
    final glow = selected || hover
        ? [BoxShadow(color: Saloon.brass.withValues(alpha: hover && !selected ? 0.6 : 0.75), blurRadius: 18, spreadRadius: 2)]
        : accused
        ? [BoxShadow(color: Saloon.blood.withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 1)]
        : selectable
        ? [BoxShadow(color: Saloon.brass.withValues(alpha: 0.28), blurRadius: 10, spreadRadius: 0.5)]
        : const [BoxShadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 5))];
    final plateHeight = max(20.0, width * 0.27);
    // Il petto è già occupato (il nastro, la nota, il timbro): il pizzino va
    // in cima all'arco.
    final high = accused || note != null || stamped;
    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        // Il ritratto ad arco.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: plateHeight * 0.45,
          child: SeatFrame.of(
            name,
            radius: width / 2,
            thickness: SeatFrame.thicknessFor(width),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                borderRadius: arch,
                border: Border.all(
                  color: border,
                  width: selected || accused || hover
                      ? 2.8
                      : selectable
                      ? 2
                      : 1.4,
                ),
                boxShadow: glow,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: accused
                      ? const [Color(0xFF7A1018), Color(0xFF2A0508)]
                      : fallen
                      ? const [Color(0xFF2A2725), Color(0xFF121110)]
                      : const [Color(0xFF3A2A1E), Color(0xFF120C08)],
                ),
              ),
              child: ClipRRect(
                borderRadius: arch,
                child: Align(
                  alignment: const Alignment(0, -0.1),
                  child: Opacity(
                    opacity: offline ? 0.5 : 1,
                    child: PlayerAvatar(seed: name, size: width * 0.86, fallen: fallen, bare: true),
                  ),
                ),
              ),
            ),
          ),
        ),
        // La targhetta del nome.
        Positioned(
          left: -width * 0.08,
          right: -width * 0.08,
          bottom: 0,
          height: plateHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Saloon.ink,
              borderRadius: BorderRadius.circular(plateHeight / 2),
              border: Border.all(color: me ? Saloon.brass : Saloon.brassDeep, width: me ? 1.6 : 1),
              boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
            ),
            padding: EdgeInsets.symmetric(horizontal: plateHeight * 0.28),
            child: Row(
              children: [
                Expanded(
                  child: _PlateName(
                    name,
                    shrink: 0.45,
                    style: AppText.display(
                      plateHeight * 0.64,
                      color: fallen ? AppColors.textSecondary : AppColors.textPrimary,
                    ).copyWith(letterSpacing: 0.6, height: 1.05),
                  ),
                ),
                if (offline && !fallen) ...[
                  SizedBox(width: plateHeight * 0.12),
                  Tooltip(
                    message: tips.offline,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      width: plateHeight * 0.26,
                      height: plateHeight * 0.26,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6B635C)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (number != null)
          Positioned(
            left: -width * 0.08,
            top: -width * 0.04,
            child: _SeatNumber(number!, size: max(20, width * 0.32), me: me, fallen: fallen),
          ),
        if (role != null)
          Positioned(
            left: -width * 0.06,
            bottom: plateHeight * 0.9,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Saloon.ink,
                border: Border.all(color: noteColor, width: 1.2),
              ),
              child: RoleIcon(role!, size: max(18, width * 0.3)),
            ),
          ),
        if (fallen)
          Positioned(
            right: width * 0.02,
            top: height * 0.5,
            child: Tooltip(
              message: tips.dead,
              triggerMode: TooltipTriggerMode.longPress,
              child: CustomPaint(size: Size.square(width * 0.3), painter: _CarnationPainter()),
            ),
          ),
        if (votes > 0)
          Positioned(
            right: -width * 0.06,
            top: -width * 0.02,
            child: Tooltip(
              message: '$votes ${tips.votes}',
              triggerMode: TooltipTriggerMode.longPress,
              child: _WaxSeal(votes, size: max(24, width * 0.3)),
            ),
          ),
        // Il nastro dell'accusato: sul petto, appena sopra la targhetta; la
        // faccia e il nome restano scoperti.
        if (accused && accusedLabel.isNotEmpty)
          Positioned(
            left: -width * 0.06,
            right: -width * 0.06,
            bottom: plateHeight * 0.92,
            child: Center(
              child: Transform.rotate(
                angle: -0.06,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Saloon.enamel,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFFC9B0), width: 1),
                    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6)],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      accusedLabel.toUpperCase(),
                      style: AppText.display(
                        max(10, width * 0.12),
                        color: const Color(0xFFFFEBD6),
                      ).copyWith(letterSpacing: 1.2, height: 1.1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Il pizzino: sulla spalla destra, sopra la targhetta; se il petto è
        // occupato, in cima all'arco fra il numero e il bollo. Non copre mai
        // il nome né la faccia.
        if (pizzino != null)
          Positioned(
            left: high ? 0 : null,
            right: high ? 0 : -width * 0.07,
            top: high ? -width * 0.03 : null,
            bottom: high ? null : plateHeight * 0.88,
            child: Align(
              alignment: high ? Alignment.topCenter : Alignment.bottomRight,
              widthFactor: high ? null : 1,
              heightFactor: 1,
              child: Tooltip(
                message: tips.voteNote,
                triggerMode: TooltipTriggerMode.longPress,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width * (high ? 0.5 : 0.62)),
                  child: _Pizzino(key: pizzinoKey, text: pizzino!, color: pizzinoColor, size: max(9, width * 0.12)),
                ),
              ),
            ),
          ),
        if (note != null)
          Positioned(
            left: -width * 0.05,
            right: -width * 0.05,
            bottom: plateHeight * 0.95,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: Saloon.scrim(radius: 6, border: noteColor),
                child: Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: noteColor,
                    fontSize: max(9, width * 0.11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: selected ? 1.06 : (hover ? 1.04 : 1),
      child: Opacity(
        opacity: dimmed
            ? 0.45
            : fallen
            ? 0.8
            : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            // Col mouse: il tasto destro apre il foglio del giocatore.
            onSecondaryTap: onLongPress,
            hoverColor: Colors.transparent,
            customBorder: RoundedRectangleBorder(borderRadius: arch),
            splashColor: Saloon.brass.withValues(alpha: 0.2),
            child: SizedBox(width: width, height: height, child: card),
          ),
        ),
      ),
    );
  }
}

/// Sa se il mouse sta sopra il posto (sul telefono non succede mai).
class _SeatHover extends StatefulWidget {
  final bool enabled;
  final Widget Function(bool hover) builder;

  const _SeatHover({required this.enabled, required this.builder});

  @override
  State<_SeatHover> createState() => _SeatHoverState();
}

class _SeatHoverState extends State<_SeatHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: widget.builder(_hover && widget.enabled),
      );
}

/// Il nome sulla targhetta: grande; se non ci sta si stringe fino a due
/// terzi, poi si taglia con i puntini.
class _PlateName extends StatelessWidget {
  final String text;
  final TextStyle style;

  final double shrink;

  const _PlateName(this.text, {required this.style, this.shrink = 0.66});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // I bot si chiamano «bot.alfa»: sulla targhetta basta «ALFA» con
      // l'ingranaggio, così il nome si legge intero.
      final bot = text.startsWith('bot.') && text.length > 4;
      final label = (bot ? text.substring(4) : text).toUpperCase();
      final mark = bot ? style.fontSize! * 0.95 : 0.0;
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final room = box.maxWidth - mark - 2;
      final fit = painter.width <= 0 ? 1.0 : (room / painter.width).clamp(min(1.0, max(shrink, 9 / style.fontSize!)), 1.0);
      painter.dispose();
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bot) Icon(Icons.settings, size: mark * 0.85, color: Saloon.brass),
            Flexible(
              child: StyledName(
                text,
                text: label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                base: style.copyWith(fontSize: style.fontSize! * fit),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Il numero di posto: un gettone d'ottone sull'angolo del ritratto.
class _SeatNumber extends StatelessWidget {
  final int number;
  final double size;
  final bool me;
  final bool fallen;

  const _SeatNumber(this.number, {required this.size, required this.me, required this.fallen});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: fallen ? const [Color(0xFF8A817A), Color(0xFF4A443F)] : const [Color(0xFFF2D58A), Saloon.brassDeep],
      ),
      border: Border.all(color: me ? Colors.white : const Color(0xFF1A120C), width: me ? 1.6 : 1.2),
      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Text(
      '$number',
      style: AppText.display(
        size * 0.58,
        color: const Color(0xFF1A120C),
      ).copyWith(height: 1, fontWeight: FontWeight.w800, letterSpacing: 0),
    ),
  );
}

/// Il bollo di ceralacca con il numero dei voti.
class _WaxSeal extends StatelessWidget {
  final int votes;
  final double size;

  const _WaxSeal(this.votes, {required this.size});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(votes),
    tween: Tween(begin: 1.5, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Color(0xFFE0343F), Color(0xFF7A0A12)]),
        border: Border.all(color: const Color(0xFF3A0508), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text('$votes', style: AppText.display(size * 0.55, color: Colors.white).copyWith(letterSpacing: 0)),
    ),
  );
}

/// Il bigliettino di chi ha votato: «→ MARCO».
class _Pizzino extends StatelessWidget {
  final String text;
  final Color color;
  final double size;

  const _Pizzino({super.key, required this.text, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.04,
    child: Container(
      padding: const EdgeInsets.fromLTRB(3, 1, 4, 1),
      decoration: BoxDecoration(
        color: Saloon.paper,
        borderRadius: BorderRadius.circular(2),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2))],
      ),
      // Si stringe, non si taglia: «→ 11» si legge sempre intero.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(fontFamily: 'Courier', color: Saloon.paperInk, fontSize: size, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

/// Il garofano sul posto di chi non c'è più.
class _CarnationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stem = Paint()
      ..color = const Color(0xFF3F6B3A)
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.5, s * 0.45), Offset(s * 0.3, s * 0.98), stem);
    final petal = Paint()..color = const Color(0xFFC0182A);
    final center = Offset(s * 0.52, s * 0.35);
    for (var i = 0; i < 7; i++) {
      final a = 2 * pi * i / 7;
      canvas.drawCircle(center + Offset(cos(a), sin(a)) * s * 0.16, s * 0.15, petal);
    }
    canvas.drawCircle(center, s * 0.12, Paint()..color = const Color(0xFF8A0F1C));
  }

  @override
  bool shouldRepaint(_CarnationPainter old) => false;
}

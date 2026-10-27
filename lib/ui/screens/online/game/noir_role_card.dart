import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../rules/player.dart';
import '../../../../rules/role.dart';
import '../../../../sound/cue_sounds.dart';
import '../../../../sound/sound_stage.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/role_style.dart';
import '../../../widgets/role_rules.dart';
import 'noir_ui.dart';

/// La carta del ruolo, online: arriva scivolando sul panno, e si gira in
/// 3D finché il dito resta premuto (al rilascio torna coperta, così il ruolo
/// non resta mai in vista per sbaglio). Il dorso è una carta da gioco
/// rossa con la filigrana d'ottone; la faccia una locandina del ruolo.
class NoirRoleCard extends StatefulWidget {
  final Role role;
  final List<Player> teammates;

  /// Il bersaglio, se è il Cacciatore di taglie.
  final Player? bounty;

  /// Chiamata la prima volta che la carta arriva scoperta.
  final VoidCallback? onRevealed;

  const NoirRoleCard({
    super.key,
    required this.role,
    this.teammates = const [],
    this.bounty,
    this.onRevealed,
  });

  @override
  State<NoirRoleCard> createState() => _NoirRoleCardState();
}

class _NoirRoleCardState extends State<NoirRoleCard>
    with TickerProviderStateMixin {
  late final AnimationController _flip =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 520),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_notified) {
          _notified = true;
          widget.onRevealed?.call();
        }
      });
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _notified = false;

  /// Movimento ridotto: la carta è già sul panno e si scopre senza giro.
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _deal.value = 1;
    } else if (_deal.isDismissed) {
      _deal.forward();
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _deal.dispose();
    super.dispose();
  }

  void _press() {
    HapticFeedback.mediumImpact();
    SoundStage.instance.cue(Cue.flip);
    if (_still) {
      _flip.value = 1;
    } else {
      _flip.forward();
    }
  }

  void _release() => _still ? _flip.value = 0 : _flip.reverse();

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AspectRatio(
        aspectRatio: 5 / 7.4,
        child: AnimatedBuilder(
          animation: Listenable.merge([_flip, _deal]),
          builder: (context, _) {
            final deal = Curves.easeOutCubic.transform(_deal.value);
            final t = Curves.easeInOutCubic.transform(_flip.value);
            final angle = t * pi;
            final faceUp = angle > pi / 2;
            // Sollevata a metà giro: più grande, l'ombra più lontana.
            final lift = sin(t * pi);
            // Il volo comincia in dissolvenza: la carta non spunta dal nulla.
            return Opacity(
              opacity: Curves.easeOut.transform(
                (_deal.value / 0.3).clamp(0.0, 1.0),
              ),
              child: Transform.translate(
                offset: Offset(0, (1 - deal) * -260),
                child: Transform.rotate(
                  angle: (1 - deal) * -0.5,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..scaleByDouble(1 + lift * 0.06, 1 + lift * 0.06, 1, 1)
                      ..rotateY(angle),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 24 + lift * 20,
                            offset: Offset(0, 12 + lift * 18),
                          ),
                          if (faceUp)
                            BoxShadow(
                              color: widget.role.color.withValues(
                                alpha: 0.5 * (t * 2 - 1).clamp(0.0, 1.0),
                              ),
                              blurRadius: 40,
                            ),
                        ],
                      ),
                      child: faceUp
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(pi),
                              child: _Face(
                                role: widget.role,
                                teammates: widget.teammates,
                                bounty: widget.bounty,
                              ),
                            )
                          : const _Back(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: CustomPaint(
      painter: _BackPainter(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Saloon.ink,
                border: Border.all(color: Saloon.brass, width: 2),
              ),
              child: Text('O', style: AppText.display(54, color: Saloon.brass)),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: Saloon.scrim(radius: 8, border: Saloon.brass),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, color: Saloon.brass, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppStrings.of(context).pressAndHold,
                        style: AppText.overline.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF8E1620), Color(0xFF4A0910), Color(0xFF22040A)],
          stops: [0, 0.6, 1],
        ).createShader(all),
    );
    // La filigrana: rombi d'ottone.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Saloon.brass.withValues(alpha: 0.28);
    const step = 18.0;
    for (var d = -size.height; d < size.width + size.height; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), line);
      canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), line);
    }
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Saloon.brass;
    canvas.drawRRect(
      RRect.fromRectAndRadius(all.deflate(1.2), const Radius.circular(20)),
      frame,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(all.deflate(10), const Radius.circular(13)),
      frame..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BackPainter old) => false;
}

class _Face extends StatelessWidget {
  final Role role;
  final List<Player> teammates;
  final Player? bounty;

  const _Face({required this.role, required this.teammates, this.bounty});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final text = t.role(role);
    final isMafia = role.team == Team.mafia;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(role.color, Colors.white, 0.08)!,
            Color.lerp(role.color, Colors.black, 0.55)!,
            Saloon.ink,
          ],
          stops: const [0, 0.5, 1],
        ),
        border: Border.all(color: Saloon.brass, width: 2.4),
      ),
      padding: const EdgeInsets.all(9),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Saloon.brass.withValues(alpha: 0.6)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: LayoutBuilder(
          builder: (context, box) => FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color.lerp(role.color, Colors.white, 0.2)!,
                          Saloon.ink,
                        ],
                      ),
                      border: Border.all(color: Saloon.brass, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, blurRadius: 12),
                      ],
                    ),
                    child: RoleIcon(role, size: 84),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text.label.toUpperCase(),
                      style: Saloon.plate(30, color: const Color(0xFFFFF1D6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text.motto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      color: Saloon.brass,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMafia ? Saloon.enamel : const Color(0xFF16351F),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Saloon.brass),
                    ),
                    child: Text(
                      isMafia
                          ? t.youAreFamily
                          : role.team == Team.neutral
                          ? t.youAreNeutral
                          : t.youAreTown,
                      style: AppText.overline.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RoleRules(
                      role,
                      color: AppColors.textPrimary,
                      labelColor: Saloon.brass,
                      fontSize: 14,
                    ),
                  ),
                  if (bounty case final mark?) ...[
                    const SizedBox(height: 12),
                    Text(
                      t.bountyLine.replaceAll('{name}', mark.name),
                      key: const Key('role.bounty'),
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(
                        color: Saloon.brass,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (isMafia) ...[
                    const SizedBox(height: 14),
                    Text(
                      teammates.isEmpty ? t.youActAlone : t.yourAccomplices,
                      style: AppText.overline.copyWith(color: Saloon.brass),
                    ),
                    if (teammates.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        teammates.map((p) => p.name).join(' · '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

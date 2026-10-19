import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../rules/role.dart';
import '../../sound/cue_sounds.dart';
import '../../sound/meme_beat.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import 'player_avatar.dart';
import '../press.dart';

const _alarmRed = Color(0xFFE5606A);

/// La piazza di giorno: il cronometro, quanti sono ancora in piedi, il
/// tavolo di tutti e i due pulsanti, più tempo o al voto.
class DayBoard extends StatefulWidget {
  final AppStrings strings;
  final Duration duration;
  final Widget table;
  final int alive;
  final int total;
  final VoidCallback onVote;

  const DayBoard({
    super.key,
    required this.strings,
    required this.duration,
    required this.table,
    required this.alive,
    required this.total,
    required this.onVote,
  });

  @override
  State<DayBoard> createState() => _DayBoardState();
}

class _DayBoardState extends State<DayBoard> {
  static const _second = Duration(seconds: 1);

  late Duration _left = widget.duration;

  /// Tutto il tempo concesso finora, minuti aggiunti compresi: il quadrante
  /// si svuota su questo.
  late Duration _granted = widget.duration;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_second, (_) {
      if (_left == Duration.zero) return;
      setState(() => _left -= _second);
      if (_left == Duration.zero) {
        HapticFeedback.heavyImpact();
        if (beat(MemeMoment.timerEnd) == null) SoundStage.instance.cue(Cue.timeUp);
      } else if (_left <= const Duration(seconds: 10)) {
        // Gli ultimi cinque secondi: il panico.
        if (_left == const Duration(seconds: 5)) beat(MemeMoment.timerEnd);
        SoundStage.instance.cue(Cue.tick);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _oneMore() => setState(() {
    _left += const Duration(minutes: 1);
    if (_left > _granted) _granted = _left;
  });

  @override
  Widget build(BuildContext context) {
    final expired = _left == Duration.zero;
    final hurry = expired || _left <= const Duration(seconds: 10);
    final minutes = _left.inMinutes;
    final seconds = (_left.inSeconds % 60).toString().padLeft(2, '0');
    final t = widget.strings;
    final share = _granted == Duration.zero ? 0.0 : _left.inMilliseconds / _granted.inMilliseconds;
    return Column(
      children: [
        Row(
          children: [
            PocketWatch(
              share: share,
              alarm: hurry,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$minutes:$seconds',
                  style: AppText.display(30, color: hurry ? _alarmRed : AppColors.gold).copyWith(letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expired ? t.timeUp : t.floorIsOpen,
                    style: AppText.overline.copyWith(color: expired ? _alarmRed : AppColors.gold),
                  ),
                  const SizedBox(height: 8),
                  TableCensus(strings: t, alive: widget.alive, total: widget.total, centered: false),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: widget.table),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: pressed(_oneMore, Press.chips), child: Text(t.plusMinute)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(onPressed: pressed(widget.onVote, Press.confirm), child: Text(t.callTheVote)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Il cronometro della piazza: un quadrante da panciotto che si svuota.
class PocketWatch extends StatelessWidget {
  /// Quanto tempo resta, da 1 (tutto) a 0.
  final double share;

  /// Gli ultimi secondi: il quadrante si fa rosso.
  final bool alarm;
  final Widget child;
  final double size;

  const PocketWatch({super.key, required this.share, required this.alarm, required this.child, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _WatchPainter(share: share.clamp(0.0, 1.0), alarm: alarm),
        child: Padding(
          padding: EdgeInsets.all(size * 0.19),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _WatchPainter extends CustomPainter {
  final double share;
  final bool alarm;

  const _WatchPainter({required this.share, required this.alarm});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ink = alarm ? _alarmRed : AppColors.gold;
    canvas.drawCircle(center, radius - 2, Paint()..color = AppColors.background.withValues(alpha: 0.85));
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.gold.withValues(alpha: 0.45),
    );
    // Le tacche delle ore, come su un orologio da tasca.
    final tick = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final direction = Offset(sin(angle), -cos(angle));
      canvas.drawLine(center + direction * (radius - 6), center + direction * (radius - 10), tick);
    }
    final ring = Rect.fromCircle(center: center, radius: radius - 15);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ring, 0, 2 * pi, false, stroke..color = AppColors.surfaceHigh);
    if (share > 0) canvas.drawArc(ring, -pi / 2, 2 * pi * share, false, stroke..color = ink);
  }

  @override
  bool shouldRepaint(_WatchPainter old) => old.share != share || old.alarm != alarm;
}

/// Quanti sono ancora in piedi: il conto, e una fila di lumini, uno per
/// giocatore, spenti per chi non c'è più. Non dice chi: solo quanti.
class TableCensus extends StatelessWidget {
  final AppStrings strings;
  final int alive;
  final int total;
  final bool centered;

  const TableCensus({super.key, required this.strings, required this.alive, required this.total, this.centered = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          strings.aliveCount(alive, total),
          style: AppText.body.copyWith(fontSize: 13.5, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < alive ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: i < alive ? AppColors.gold : AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  boxShadow: i < alive
                      ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 4)]
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Una riga del "chi era chi": la faccia col segno del ruolo, il nome, il
/// ruolo (in rosso chi stava con la famiglia) e com'è finita.
class RevealRow extends StatelessWidget {
  final String name;
  final Role role;
  final String roleLabel;
  final String fate;
  final bool alive;
  final bool winner;

  const RevealRow({
    super.key,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.fate,
    required this.alive,
    required this.winner,
  });

  static const familyRed = Color(0xFFE5606A);

  @override
  Widget build(BuildContext context) {
    final family = role.team == Team.mafia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            border: Border(left: BorderSide(color: family ? familyRed : role.color, width: 4)),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PlayerAvatar(seed: name, size: 52, fallen: !alive),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: role.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: RoleIcon(role, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleLabel,
                      style: TextStyle(color: family ? familyRed : AppColors.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (winner) const Icon(Icons.emoji_events, size: 16, color: AppColors.gold),
                  Text(fate, style: AppText.body.copyWith(fontSize: 12.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

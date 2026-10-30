import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/local_table_strings.dart';
import '../../rules/game_setup.dart';
import '../../rules/player.dart';
import '../press.dart';
import '../theme/app_theme.dart';
import '../widgets/scene_scaffold.dart';
import '../widgets/targa.dart';
import 'online/game/noir_ui.dart' show Saloon;
import 'role_deal_screen.dart';

/// Dopo il narratore, l'ultima scelta prima delle carte: come vota la
/// piazza. Si parte sempre dal voto a voce; il voto segreto vale solo per
/// la partita in cui lo si spunta, e la prossima ricomincia a voce.
class VoteModeScreen extends StatefulWidget {
  final List<Player> players;

  /// `null`: il narratore automatico.
  final Player? narrator;

  const VoteModeScreen({super.key, required this.players, this.narrator});

  @override
  State<VoteModeScreen> createState() => _VoteModeScreenState();
}

class _VoteModeScreenState extends State<VoteModeScreen> {
  bool _secret = false;

  void _deal() {
    final setup = GameSetup.deal(
      lobby: widget.players,
      narrator: widget.narrator,
      vote: _secret ? LocalVote.secret : LocalVote.voice,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoleDealScreen(setup: setup)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final ls = LocalTableStrings(t.language);
    return SceneScaffold(
      appBar: AppBar(title: Text(ls.voteTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(ls.voteHeadline, style: AppText.display(34)),
                    const SizedBox(height: 8),
                    _OnScrim(child: Text(ls.voteIntro, style: AppText.body)),
                    const SizedBox(height: 28),
                    _BallotCheck(
                      key: const Key('vote.secret'),
                      label: ls.secretVote,
                      checked: _secret,
                      onChanged: (on) => setState(() => _secret = on),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
                      child: _OnScrim(
                        key: ValueKey(_secret ? 'vote.hint.secret' : 'vote.hint.voice'),
                        child: Text(
                          _secret ? ls.secretVoteHint : ls.voiceVoteHint,
                          style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 15, height: 1.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TargaButton(
                key: const Key('vote.next'),
                label: ls.voteNext,
                expand: true,
                feel: Press.confirm,
                onPressed: _deal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il testo si legge su una lastra scura: dietro c'è il cielo con la luna.
class _OnScrim extends StatelessWidget {
  final Widget child;

  const _OnScrim({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xF20C0907), borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

/// La casella della scheda: un quadrato d'ottone che si spunta con una
/// croce a matita, e accanto la scelta. Tutta la riga si tocca.
class _BallotCheck extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _BallotCheck({super.key, required this.label, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: pressed(() => onChanged(!checked), Press.tap),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: checked ? 0.8 : 0.35), width: checked ? 1.6 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 34,
                  child: CustomPaint(painter: _CheckBoxPainter(checked: checked)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
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

/// Il quadrato della scheda elettorale: cornice d'ottone su carta scura;
/// spuntato, una croce a matita, calcata, un po' storta come a mano.
class _CheckBoxPainter extends CustomPainter {
  final bool checked;

  const _CheckBoxPainter({required this.checked});

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.12));
    canvas.drawRRect(box, Paint()..color = const Color(0xFF15100C));
    canvas.drawRRect(
      box.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = checked ? Saloon.brass : Saloon.brassDeep,
    );
    if (!checked) return;
    final w = size.width;
    final pencil = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.12
      ..color = const Color(0xFFF2E6CC);
    canvas
      ..drawLine(Offset(w * 0.24, w * 0.22), Offset(w * 0.78, w * 0.8), pencil)
      ..drawLine(Offset(w * 0.8, w * 0.24), Offset(w * 0.22, w * 0.76), pencil);
  }

  @override
  bool shouldRepaint(_CheckBoxPainter old) => old.checked != checked;
}

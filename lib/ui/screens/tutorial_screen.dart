import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/tutorial_strings.dart';
import '../../rules/player.dart';
import '../../rules/role.dart';
import '../../settings/app_settings.dart';
import '../../tutorial/tutorial_game.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_role_card.dart';
import '../widgets/noir_modal.dart';
import '../widgets/player_grid.dart';

const _mafiaRed = Color(0xFFE5606A);
const _cleanGreen = Color(0xFF6FBF9A);

/// Il tutorial: una mano guidata contro cinque bot, sullo stesso telefono (o
/// sul PC). Il narratore accende una luce sul punto giusto dello schermo e
/// dice una frase; si può saltare in ogni momento.
class TutorialScreen extends StatefulWidget {
  final AppSettings? settings;

  const TutorialScreen({super.key, this.settings});

  static Future<void> open(BuildContext context, {AppSettings? settings}) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => TutorialScreen(settings: settings)));

  /// Al primo avvio: chiede una volta se fare la mano di prova.
  static Future<void> offer(BuildContext context, {AppSettings? settings}) async {
    final store = settings ?? AppSettings.instance;
    if (store.tutorialSeen) return;
    store.tutorialSeen = true;
    final s = TutorialStrings.of(context);
    final play = await confirmNoir(
      context,
      title: s.offerTitle,
      body: s.offerBody,
      icon: Icons.style_outlined,
      cancel: s.offerLater,
      confirm: s.offerStart,
      cancelKey: const Key('tutorial.later'),
      confirmKey: const Key('tutorial.start'),
    );
    if (play && context.mounted) await open(context, settings: store);
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _stack = GlobalKey();
  final _focus = GlobalKey();
  late TutorialStrings _s;
  late AppStrings _t;
  TutorialGame? _gameOrNull;
  TutorialGame get _game => _gameOrNull!;
  bool _revealed = false;
  Rect? _spot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = TutorialStrings.of(context);
    _t = AppStrings.of(context);
    _gameOrNull ??= TutorialGame(youName: _s.you);
  }

  void _finish() {
    (widget.settings ?? AppSettings.instance).tutorialSeen = true;
    Navigator.of(context).maybePop();
  }

  void _act(VoidCallback move) => setState(() {
    move();
    _spot = null;
  });

  /// Dove sta il pezzo da illuminare, rispetto all'intera pagina.
  void _measure() {
    if (!mounted) return;
    final target = _focus.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    Rect? spot;
    if (target != null && stack != null && target.hasSize && target.attached) {
      spot = target.localToGlobal(Offset.zero, ancestor: stack) & target.size;
    }
    if (spot != _spot) setState(() => _spot = spot);
  }

  Player get _suspect => _game.suspect;

  String get _caption {
    final g = _game;
    return switch (g.beat) {
      TutorialBeat.welcome => _s.coachWelcome,
      TutorialBeat.card => _s.coachCard,
      TutorialBeat.night => _s.coachNight(_suspect.name),
      TutorialBeat.finding => _s.coachFinding(_suspect.name),
      TutorialBeat.dawn => g.dawn!.attacks.any((a) => a.isFatal) ? _s.coachDawn : _s.coachSaved,
      TutorialBeat.talk => _s.coachTalk,
      TutorialBeat.vote => _s.coachVote(_suspect.name),
      TutorialBeat.verdict => _s.coachVerdict,
      TutorialBeat.win => _s.coachWin,
      TutorialBeat.ready => '',
    };
  }

  String get _heading {
    final g = _game;
    return switch (g.beat) {
      TutorialBeat.welcome || TutorialBeat.card => _s.title.toUpperCase(),
      TutorialBeat.night || TutorialBeat.finding => _s.night(g.round),
      _ => _s.day(g.dawn?.round ?? g.round),
    };
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final beat = _game.beat;
    if (beat == TutorialBeat.ready) return _readyPage();
    final canNext = _game.passive && (beat != TutorialBeat.card || _revealed);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A0D),
      body: SafeArea(
        child: Stack(
          key: _stack,
          fit: StackFit.expand,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_heading, textAlign: TextAlign.center, style: AppText.display(20)),
                      const SizedBox(height: 12),
                      Expanded(child: _body(beat)),
                    ],
                  ),
                ),
              ),
            ),
            if (_spot case final spot?)
              IgnorePointer(child: CustomPaint(painter: _CoachScrim(spot.inflate(8)))),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _CoachCard(
                    key: const Key('tutorial.coach'),
                    caption: _caption,
                    next: canNext ? _s.next : null,
                    onNext: () => _act(_game.next),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 8,
              child: TextButton(
                key: const Key('tutorial.skip'),
                onPressed: _finish,
                child: Text(_s.skip, style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid({List<Player>? selectable, ValueChanged<Player>? onSelect, Player? lynched, Key? key}) => PlayerGrid(
    key: key,
    players: _game.players,
    isAlive: _game.engine.isAlive,
    knowledgeOf: (player) => _game.engine.knowledgeOf(_game.you, player),
    viewer: _game.you,
    selectable: selectable,
    onSelect: onSelect,
    stamp: _t.accusedStamp,
    lynched: lynched,
    lynchedLabel: _t.language.locale.languageCode == 'it' ? 'Linciato' : 'Lynched',
  );

  Widget _panel({required Widget child, Key? key, Color border = AppColors.gold}) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border.withValues(alpha: 0.7), width: 1.4),
    ),
    child: child,
  );

  Widget _body(TutorialBeat beat) {
    final g = _game;
    switch (beat) {
      case TutorialBeat.welcome:
        return Center(
          child: Column(
            key: _focus,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('OBERTÀ', style: AppText.display(46)),
              const SizedBox(height: 8),
              Text(_s.offerBody, textAlign: TextAlign.center, style: AppText.body),
            ],
          ),
        );
      case TutorialBeat.card:
        return Center(
          child: SizedBox(
            key: _focus,
            width: 210,
            child: FlipRoleCard(role: Role.detective, onRevealed: () => setState(() => _revealed = true)),
          ),
        );
      case TutorialBeat.night:
        return _grid(key: _focus, selectable: [_suspect], onSelect: (p) => _act(() => g.investigate(p)));
      case TutorialBeat.finding:
        final finding = g.finding!;
        final mafia = finding.team == Team.mafia;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _grid()),
            const SizedBox(height: 12),
            _panel(
              key: _focus,
              border: mafia ? _mafiaRed : _cleanGreen,
              child: Column(
                children: [
                  Text(_s.investigated(finding.subject.name), style: AppText.overline),
                  const SizedBox(height: 6),
                  Text(
                    mafia ? _s.family : _t.role(Role.cittadino).label,
                    style: AppText.display(26, color: mafia ? _mafiaRed : _cleanGreen),
                  ),
                ],
              ),
            ),
          ],
        );
      case TutorialBeat.dawn:
        final dead = [for (final a in g.dawn!.attacks) if (a.isFatal) a.target];
        return Center(
          child: _panel(
            key: _focus,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_s.paper, textAlign: TextAlign.center, style: AppText.overline),
                const Divider(color: AppColors.gold),
                Text(
                  dead.isEmpty ? _s.quiet : _s.found(dead.first.name),
                  textAlign: TextAlign.center,
                  style: AppText.display(24, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(dead.isEmpty ? _s.quietSub : _s.foundSub, style: AppText.body),
              ],
            ),
          ),
        );
      case TutorialBeat.talk:
        final lines = _s.chat(g.round);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final (who, line) in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _panel(
                        border: AppColors.surfaceHigh,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$who  ',
                                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: line, style: const TextStyle(color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              key: _focus,
              onPressed: () => _act(g.speak),
              child: Text(_s.accuse(_suspect.name), textAlign: TextAlign.center),
            ),
          ],
        );
      case TutorialBeat.vote:
        return _grid(key: _focus, selectable: [_suspect], onSelect: (p) => _act(() => g.vote(p)));
      case TutorialBeat.verdict:
        final verdict = g.verdict!;
        final condemned = verdict.condemned!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _grid(lynched: condemned)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final MapEntry(key: voter, value: accused) in g.votes.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(voter.name, style: AppText.body),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.pan_tool_alt, size: 18, color: AppColors.gold),
                      ),
                      Text(accused.name, style: AppText.body.copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _panel(
              key: _focus,
              border: _mafiaRed,
              child: Column(
                children: [
                  Text(_s.condemned(condemned.name), style: AppText.overline),
                  const SizedBox(height: 6),
                  Text(_t.role(verdict.role!).label, style: AppText.display(24, color: _mafiaRed)),
                ],
              ),
            ),
          ],
        );
      case TutorialBeat.win:
        return Center(
          child: Text(
            _s.cityWins,
            key: _focus,
            textAlign: TextAlign.center,
            style: AppText.display(34, color: _cleanGreen),
          ),
        );
      case TutorialBeat.ready:
        return const SizedBox.shrink();
    }
  }

  Widget _readyPage() => Scaffold(
    backgroundColor: const Color(0xFF0B0A0D),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_police_outlined, color: AppColors.gold, size: 56),
                const SizedBox(height: 18),
                Text(_s.ready, textAlign: TextAlign.center, style: AppText.display(32)),
                const SizedBox(height: 12),
                Text(_s.readyBody, textAlign: TextAlign.center, style: AppText.body),
                const SizedBox(height: 28),
                ElevatedButton(key: const Key('tutorial.done'), onPressed: _finish, child: Text(_s.toTheTable)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Il buio intorno, un cerchio di luce sul punto giusto, il filo d'oro.
class _CoachScrim extends CustomPainter {
  final Rect spot;

  _CoachScrim(this.spot);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(spot, const Radius.circular(16));
    final dark = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(dark, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.gold.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_CoachScrim old) => old.spot != spot;
}

/// La didascalia del narratore: una frase, e «Avanti» quando non serve una mossa.
class _CoachCard extends StatelessWidget {
  final String caption;
  final String? next;
  final VoidCallback onNext;

  const _CoachCard({super.key, required this.caption, required this.next, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF0151114),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caption,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: ['serif'],
                fontStyle: FontStyle.italic,
                fontSize: 17,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: next == null
                  ? const SizedBox(height: 36)
                  : TextButton(key: const Key('tutorial.next'), onPressed: onNext, child: Text(next!)),
            ),
          ],
        ),
      ),
    );
  }
}

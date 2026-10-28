import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/tutorial_strings.dart';
import '../../online/fake_online.dart';
import '../../online/online_services.dart';
import '../../settings/app_settings.dart';
import '../../tutorial/tutorial_script.dart';
import '../../tutorial/tutorial_story.dart';
import '../../tutorial/tutorial_table.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import '../widgets/noir_modal.dart';
import 'online/online_game_screen.dart';

/// La mano di prova: lo schermo della partita online vera, con cinque bot
/// che recitano un copione. Il narratore accende solo una luce sul pezzo
/// giusto e dice una frase; il resto lo fai tu, come in partita.
class TutorialScreen extends StatefulWidget {
  final TutorialStory story;
  final AppSettings? settings;

  const TutorialScreen({super.key, this.story = TutorialStory.city, this.settings});

  /// La scelta delle tre mani.
  static Future<void> open(BuildContext context, {AppSettings? settings}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TutorialChooser(settings: settings)));

  /// Una mano precisa (dalla classificata: quella che manca).
  /// L'ultimo tavolo aperto: i test lo guardano per sapere dove toccare.
  @visibleForTesting
  static TutorialTable? lastTable;

  static Future<void> play(BuildContext context, TutorialStory story, {AppSettings? settings}) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => TutorialScreen(story: story, settings: settings),
        ),
      );

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _stack = GlobalKey();
  final _game = GlobalKey();
  late TutorialStrings _s;
  late TutorialScript _script;
  TutorialTable? _tableOrNull;
  TutorialTable get _table => _tableOrNull!;
  late OnlineServices _services;
  late Room _room;
  late Profile _me;
  Timer? _measure;
  Rect? _spot;
  bool _film = false;

  AppSettings get _settings => widget.settings ?? AppSettings.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = TutorialStrings.of(context);
    if (_tableOrNull != null) return;
    final language = AppStrings.of(context).language;
    _script = TutorialScript.of(widget.story, language);
    final table = _tableOrNull = TutorialScreen.lastTable = TutorialTable(_script, youName: _s.you, language: language);
    final fake = FakeOnline(accountId: TutorialTable.youId)..signInReady(handle: _s.you);
    _services = OnlineServices(
      auth: fake.auth,
      profiles: fake.profiles,
      friends: fake.friends,
      rooms: fake.rooms,
      game: table,
      reactions: table.reactions,
    );
    _room = Room(
      id: TutorialTable.roomId,
      code: 'OBERTA',
      hostId: TutorialTable.youId,
      language: language,
      status: RoomStatus.playing,
      maxPlayers: 6,
      bots: 5,
    );
    _me = Profile(id: TutorialTable.youId, handle: _s.you, language: language);
    table.coach.addListener(_changed);
    table.replies.addListener(_changed);
    table.finished.addListener(_finished);
    _measure = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _table.tick();
      if (mounted && _table.inFilm != _film) setState(() {});
      _locate();
    });
  }

  @override
  void dispose() {
    _measure?.cancel();
    _tableOrNull?.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _locate();
  }

  void _finished() {
    if (!_table.finished.value) return;
    _settings
      ..tutorialSeen = true
      ..markTutorialDone(widget.story.id);
    TutorialProgress.onComplete?.call(widget.story);
    if (!mounted) return;
    // Quello che la partita ha aperto sopra (il resoconto) si chiude.
    final route = ModalRoute.of(context);
    Navigator.of(context).popUntil((r) => r == route || r.isFirst);
    setState(() {});
  }

  /// Dove sta, sullo schermo della partita, il pezzo da illuminare.
  void _locate() {
    if (!mounted) return;
    final key = _table.coach.value?.spot;
    Rect? spot;
    final root = _game.currentContext as Element?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (key != null && root != null && stack != null) {
      Element? found;
      void visit(Element element) {
        if (found != null) return;
        if (element.widget.key == key) {
          found = element;
          return;
        }
        element.visitChildElements(visit);
      }

      root.visitChildElements(visit);
      final box = found?.renderObject;
      if (box is RenderBox && box.attached && box.hasSize) {
        spot = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
      }
    }
    if (spot != _spot) setState(() => _spot = spot);
  }

  /// «Salta»: via l'attesa di adesso (il film, il giornale, le righe dei
  /// bot), non la mano.
  void _skip() => _table.advance();

  /// «✕»: lasciare la mano, dopo averlo chiesto. Non conta come fatta.
  Future<void> _exit() async {
    final leave = await confirmNoir(
      context,
      title: _s.exitTitle,
      body: _s.exitBody,
      confirm: _s.exit,
      cancel: _s.stay,
      danger: true,
      key: const Key('tutorial.exit.dialog'),
      confirmKey: const Key('tutorial.exit.confirm'),
      cancelKey: const Key('tutorial.exit.cancel'),
    );
    if (!leave || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_table.finished.value) return _readyPage();
    final coach = _table.coach.value;
    final replies = _table.replies.value;
    final place = _place(MediaQuery.sizeOf(context), MediaQuery.paddingOf(context).top + 88);
    final film = _film = _table.inFilm;
    return Stack(
      key: _stack,
      fit: StackFit.expand,
      children: [
        OnlineGameScreen(
          key: _game,
          services: _services,
          room: _room,
          me: _me,
          clock: _table.clock,
          showClock: false,
          // «Salta» sta nel cartiglio, al posto dell'orologio: non copre il tavolo.
          // Accanto, una «✕» piccola per lasciare la mano.
          corner: film ? null : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: _controls()),
        ),
        // Il film copre tutto, cartiglio compreso: i comandi gli stanno sopra.
        if (film)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(24)),
              child: _controls(),
            ),
          ),
        if (_spot case final spot?) IgnorePointer(child: CustomPaint(painter: _CoachScrim(spot.inflate(6)))),
        if (coach != null || replies.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: place.top,
            bottom: place.bottom,
            // La riga non ferma le dita: si tocca il tavolo anche sotto.
            child: IgnorePointer(
              ignoring: replies.isEmpty,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _CoachCard(
                    key: const Key('tutorial.coach'),
                    color: widget.story.color,
                    caption: coach?.line,
                    replies: replies,
                    onReply: (text) => _table.sendChat(TutorialTable.roomId, _table.replyChannel, text),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// «Salta» e la «✕».
  Widget _controls() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        key: const Key('tutorial.skip'),
        onPressed: _skip,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          foregroundColor: AppColors.textSecondary,
        ),
        child: Text(_s.skip, style: const TextStyle(fontSize: 15)),
      ),
      IconButton(
        key: const Key('tutorial.exit'),
        onPressed: _exit,
        tooltip: _s.exit,
        color: AppColors.textSecondary,
        iconSize: 18,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 48),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close),
      ),
    ],
  );

  /// Dove mettere la riga: accanto alla luce, sotto se c'è posto, se no
  /// sopra; con una luce troppo grande, in alto.
  ({double? top, double? bottom}) _place(Size size, double top) {
    const room = 140.0;
    final spot = _spot;
    if (spot == null) return (top: top, bottom: null);
    if (spot.bottom + room < size.height) return (top: spot.bottom + 10, bottom: null);
    if (spot.top - room > top) return (top: null, bottom: size.height - spot.top + 10);
    return (top: top, bottom: null);
  }

  Widget _readyPage() {
    final story = widget.story;
    final missing = TutorialStory.values.where((s) => !_settings.tutorialsDone.contains(s.id)).toList();
    return Scaffold(
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
                  RoleIcon(story.role, size: 84),
                  const SizedBox(height: 18),
                  Text(
                    _s.ready,
                    textAlign: TextAlign.center,
                    style: AppText.display(32, color: story.color),
                  ),
                  const SizedBox(height: 12),
                  Text(_script.winLine, textAlign: TextAlign.center, style: AppText.body),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    key: const Key('tutorial.done'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_s.toTheTable),
                  ),
                  if (missing.isNotEmpty)
                    TextButton(
                      key: const Key('tutorial.another'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => TutorialChooser(settings: widget.settings)),
                      ),
                      child: Text(_s.nextHand),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Scegli da che parte imparare»: tre carte, una per colore.
class TutorialChooser extends StatelessWidget {
  final AppSettings? settings;

  const TutorialChooser({super.key, this.settings});

  @override
  Widget build(BuildContext context) {
    final s = TutorialStrings.of(context);
    final t = AppStrings.of(context);
    final done = (settings ?? AppSettings.instance).tutorialsDone;
    Widget card(TutorialStory story) => _StoryCard(
      key: Key('tutorial.story.${story.id}'),
      story: story,
      faction: s.faction(story),
      role: t.role(story.role).label,
      pitch: s.pitch(story),
      done: done.contains(story.id) ? s.done : null,
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TutorialScreen(story: story, settings: settings),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A0D),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final stories = TutorialStory.values;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 980 : 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.choose, textAlign: TextAlign.center, style: AppText.display(26)),
                      const SizedBox(height: 6),
                      Text(s.chooseSub, textAlign: TextAlign.center, style: AppText.body),
                      const SizedBox(height: 22),
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (i, story) in stories.indexed) ...[
                                if (i > 0) const SizedBox(width: 16),
                                Expanded(child: card(story)),
                              ],
                            ],
                          ),
                        )
                      else
                        for (final (i, story) in stories.indexed) ...[
                          if (i > 0) const SizedBox(height: 12),
                          card(story),
                        ],
                    ],
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

class _StoryCard extends StatelessWidget {
  final TutorialStory story;
  final String faction;
  final String role;
  final String pitch;
  final String? done;
  final VoidCallback onTap;

  const _StoryCard({
    super.key,
    required this.story,
    required this.faction,
    required this.role,
    required this.pitch,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = story.color;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: 0.10), AppColors.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.75), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              RoleIcon(story.role, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(faction.toUpperCase(), style: AppText.display(20, color: color)),
                        ),
                        if (done case final done?) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle, size: 18, color: color, semanticLabel: done),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: AppText.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(pitch, style: AppText.body),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il buio intorno, e un riquadro di luce sul pezzo giusto.
class _CoachScrim extends CustomPainter {
  final Rect spot;

  _CoachScrim(this.spot);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(spot, const Radius.circular(14));
    final dark = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(dark, Paint()..color = const Color(0x80000000));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.gold.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_CoachScrim old) => old.spot != spot;
}

/// La riga del narratore, piccola, con le risposte già pronte da toccare.
class _CoachCard extends StatelessWidget {
  final Color color;
  final String? caption;
  final List<String> replies;
  final ValueChanged<String> onReply;

  const _CoachCard({
    super.key,
    required this.color,
    required this.caption,
    required this.replies,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xEE151114),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (caption case final caption?)
              Text(
                caption,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['serif'],
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (i, reply) in replies.indexed)
                      ActionChip(
                        key: Key('tutorial.reply.$i'),
                        label: Text(reply, style: const TextStyle(fontSize: 12.5)),
                        onPressed: () => onReply(reply),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Il biglietto sul vicolo, al primo avvio: discreto, si tocca o si butta.
class TutorialNote extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const TutorialNote({super.key, required this.onOpen, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = TutorialStrings.of(context);
    return Transform.rotate(
      angle: -0.02,
      child: Material(
        key: const Key('tutorial.note'),
        color: const Color(0xFFF1E6CC),
        elevation: 3,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    s.hint,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['serif'],
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: Color(0xFF2A1E14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.hintGo,
                  style: const TextStyle(color: Color(0xFF8E1620), fontWeight: FontWeight.w800, fontSize: 13),
                ),
                IconButton(
                  key: const Key('tutorial.note.dismiss'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Color(0xFF5A4A3A)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../network/fake_local_session.dart';
import '../../roster/photo_camera.dart';
import '../../roster/roster.dart';
import '../../roster/roster_store.dart';
import '../../rules/player.dart';
import '../../rules/role_assignment.dart';
import '../theme/app_theme.dart';
import '../widgets/mugshot_frame.dart';
import '../widgets/noir_avatar.dart';
import '../widgets/scene_scaffold.dart';
import 'narrator_selection_screen.dart';
import 'person_screen.dart';
import '../press.dart';
import '../../sound/fx_groups.dart';
import '../../sound/screen_music.dart';
import '../../sound/sound_stage.dart';
import '../../sound/memes.dart';

// I testi della schermata, tutti qui: la traduzione li prenderà da qui.

/// Chi gioca stasera, su un telefono solo: l'elenco salvato di nomi e facce,
/// da cui si sceglie chi siede al tavolo. Chi resta fuori resta in elenco.
class LobbyScreen extends StatefulWidget {
  final FakeLocalSession session;

  /// L'elenco e la fotocamera da usare. Senza, quelli dell'app.
  final RosterStore? roster;
  final PhotoCamera? camera;

  const LobbyScreen({super.key, required this.session, this.roster, this.camera});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with ScreenMusic {
  @override
  MusicMood get screenMood => MusicMood.table;

  /// Sotto la musica del tavolo, il brusio della sala.
  @override
  FxGroup? get screenAmbience => FxGroup.bar;

  AppStrings get _t => AppStrings.of(context);

  static const _testNames = [
    'Marco',
    'Giulia',
    'Luca',
    'Sara',
    'Paolo',
    'Elena',
    'Davide',
    'Chiara',
    'Matteo',
    'Anna',
    'Simone',
    'Marta',
    'Pietro',
    'Irene',
    'Nicola',
    'Greta',
  ];

  late final RosterStore _store = widget.roster ?? RosterStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_seatTable);
    _seatTable();
    _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_seatTable);
    widget.session.dispose();
    super.dispose();
  }

  /// La stanza segue l'elenco: chi è seduto qui è seduto lì.
  void _seatTable() {
    widget.session.seat([for (final member in _store.roster.table) Player(id: member.id, name: member.name)]);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// La scorciatoia di chi sviluppa: un nome di prova, senza foto.
  void _addTestPlayer() {
    final roster = _store.roster;
    if (roster.isFull) return _say(_t.lobbyRosterFull);
    var name = _testNames.firstWhere((name) => roster.checkName(name) == null, orElse: () => '');
    for (var guest = 1; name.isEmpty; guest++) {
      if (roster.checkName('Ospite $guest') == null) name = 'Ospite $guest';
    }
    _store.add(name);
  }

  void _openPerson([RosterMember? member]) {
    if (member == null && _store.roster.isFull) return _say(_t.lobbyRosterFull);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonScreen(roster: _store, camera: widget.camera, member: member),
      ),
    );
  }

  Future<void> _toggleSeat(RosterMember member) async {
    SoundStage.instance.press(member.seated ? Press.card : Press.chips);
    // Chi si siede al tavolo, ogni tanto, ha il suo momento.
    if (!member.seated && SoundStage.instance.memeMode) {
      final meme = now(0.3, const [Meme.rizz, Meme.heeHee, Meme.applePay]);
      if (meme != null) SoundStage.instance.meme(meme);
    }
    final seated = await _store.seat(member.id, !member.seated);
    if (!seated && mounted) _say(_t.lobbyTableFullRefusal);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t.lobbyClearTitle, style: AppText.display(22, color: AppColors.textPrimary)),
        content: Text(_t.lobbyClearBody, style: AppText.body),
        actions: [
          TextButton(
            onPressed: pressed(() => Navigator.of(context).pop(false), Press.back),
            child: Text(_t.lobbyClearCancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: pressed(() => Navigator.of(context).pop(true), Press.confirm),
            child: Text(
              _t.lobbyClearConfirm,
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.clear();
  }

  void _startGame() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NarratorSelectionScreen(players: widget.session.currentPlayers)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final roster = _store.roster;
        final seated = roster.table.length;
        final missing = minRolePlayers - seated;
        return SceneScaffold(
          appBar: AppBar(
            title: Text(_t.lobbyTitle),
            actions: [
              if (kDebugMode)
                TextButton(
                  onPressed: pressed(_addTestPlayer, Press.tap),
                  child: Text(_t.lobbyDebugAdd, style: TextStyle(color: AppColors.gold)),
                ),
              if (!roster.isEmpty)
                IconButton(
                  tooltip: _t.lobbyClearTooltip,
                  onPressed: pressed(_clear, Press.tap),
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
                ),
            ],
          ),
          body: SafeArea(
            child: !_store.isLoaded
                ? const SizedBox.expand()
                : Column(
                    children: [
                      Expanded(
                        child: roster.isEmpty
                            ? const _EmptyTable()
                            : Column(
                                children: [
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        seated == 0 ? _t.lobbyTableEmpty : _t.lobbySeated(seated),
                                        style: AppText.display(28),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      missing > 0
                                          ? _t.lobbyMissing(missing)
                                          : roster.tableIsFull
                                          ? _t.lobbyTableFull
                                          : _t.lobbyReadyHint,
                                      textAlign: TextAlign.center,
                                      style: AppText.body,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _RosterGrid(roster: roster, onToggle: _toggleSeat, onEdit: _openPerson),
                                  ),
                                ],
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: Column(
                          children: [
                            _PrivacyLine(text: _t.lobbyPrivacy),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: pressed(_openPerson, Press.tap),
                                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(_t.lobbyAdd)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: pressed(missing > 0 ? null : _startGame, Press.shuffle),
                                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(_t.lobbyStart)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// La riga che dice dove restano nomi e foto.
class _PrivacyLine extends StatelessWidget {
  final String text;

  const _PrivacyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12.5, height: 1.25)),
        ),
      ],
    );
  }
}

/// L'elenco ancora vuoto: una foto segnaletica senza nome, e l'invito.
class _EmptyTable extends StatelessWidget {
  const _EmptyTable();

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(
          children: [
            Transform.rotate(
              angle: -0.07,
              child: SizedBox(
                width: 168,
                child: MugshotFrame(name: '', placeholder: t.lobbyEmptyPlaceholder),
              ),
            ),
            const SizedBox(height: 28),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t.lobbyEmptyTitle, style: AppText.display(26)),
            ),
            const SizedBox(height: 10),
            Text(t.lobbyEmptyBody, textAlign: TextAlign.center, style: AppText.body),
          ],
        ),
      ),
    );
  }
}

/// Tutte le facce dell'elenco. Le tessere si stringono quando sono tante.
class _RosterGrid extends StatelessWidget {
  final Roster roster;
  final ValueChanged<RosterMember> onToggle;
  final ValueChanged<RosterMember> onEdit;

  const _RosterGrid({required this.roster, required this.onToggle, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final members = roster.members;
    final columns = members.length > 9 ? 4 : 3;
    // In fondo le tessere sfumano: si capisce che l'elenco continua.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 1 - 22 / bounds.height, 1],
      ).createShader(bounds),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns == 3 ? 0.86 : 0.76,
              children: [
                for (final member in members)
                  _PersonTile(
                    key: ValueKey(member.id),
                    member: member,
                    onTap: () => onToggle(member),
                    onLongPress: () => onEdit(member),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
              child: Text(
                t.lobbyGestureHint,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 12.5, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una persona dell'elenco: accesa se siede al tavolo, spenta se resta fuori.
class _PersonTile extends StatelessWidget {
  final RosterMember member;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PersonTile({super.key, required this.member, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final seated = member.seated;
    final still = MediaQuery.disableAnimationsOf(context);
    // Chi arriva si posa sul tavolo, come una carta servita.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Duration.zero : const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, landed, child) => Opacity(
        opacity: landed.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * landed, child: child),
      ),
      child: Semantics(
        button: true,
        selected: seated,
        child: Material(
          color: seated ? AppColors.surfaceHigh : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: pressed(onTap),
            onLongPress: onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: seated ? AppColors.gold : AppColors.gold.withValues(alpha: 0.18),
                  width: seated ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final portrait = constraints.maxWidth * 0.74;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          Opacity(
                            opacity: seated ? 1 : 0.6,
                            child: NoirAvatar(seed: member.name, size: portrait, faded: !seated),
                          ),
                          if (seated)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: portrait * 0.32,
                                height: portrait * 0.32,
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.surfaceHigh, width: 2),
                                ),
                                child: Icon(Icons.check, size: portrait * 0.20, color: AppColors.background),
                              ),
                            )
                          else
                            Positioned(
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  t.lobbyOut,
                                  style: AppText.overline.copyWith(fontSize: 9, letterSpacing: 1.4),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: seated ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

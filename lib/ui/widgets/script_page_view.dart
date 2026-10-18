import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../narration/narrator_script.dart';
import '../../rules/role.dart';
import '../../sound/cue_sounds.dart';
import '../../sound/meme_beat.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import 'avatar_spotlight.dart';
import 'phase_shift.dart';
import 'role_reveal_card.dart';
import 'spoken_script_card.dart';

/// Una pagina del copione del narratore: chi parla, le battute, il pulsante.
class ScriptPage {
  final IconData icon;
  final String title;
  final List<ScriptLine> lines;

  /// Di chi parla la pagina: i loro ritratti prendono il posto dell'icona.
  final List<String> portraits;
  final bool portraitsFallen;

  /// Il ruolo che questa pagina svela. Resta coperto, insieme alle battute
  /// dopo la prima, finché chi legge non gira la carta.
  final Role? revealed;
  /// La pagina apre un cambio d'ora: `true` cala la notte, `false` si fa
  /// giorno, `null` niente.
  final bool? nightfall;
  final String action;
  final VoidCallback onAction;

  const ScriptPage({
    required this.icon,
    required this.title,
    required this.lines,
    this.portraits = const [],
    this.portraitsFallen = false,
    this.revealed,
    this.nightfall,
    required this.action,
    required this.onAction,
  });
}

/// Una pagina di copione. Se il testo non sta nello schermo, il pulsante
/// accompagna chi legge fino in fondo prima di lasciarlo andare avanti: le
/// istruzioni che contano stanno spesso nelle ultime righe.
class ScriptPageView extends StatefulWidget {
  final ScriptPage page;
  final String? reader;
  final AppStrings strings;

  const ScriptPageView({super.key, required this.page, required this.reader, required this.strings});

  @override
  State<ScriptPageView> createState() => _ScriptPageViewState();
}

class _ScriptPageViewState extends State<ScriptPageView> {
  final _scroll = ScrollController();
  bool _cardTurned = false;
  bool _moreBelow = false;

  /// Una volta arrivati in fondo non si torna indietro: se il pulsante
  /// cambiando etichetta spostasse il testo di qualche punto, lo stato
  /// rimbalzerebbe all'infinito tra "c'è altro" e "finito".
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _checkAfterLayout();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _update(_scroll.position);
    });
  }

  bool _update(ScrollMetrics metrics) {
    if (metrics.extentAfter <= 12) _reachedEnd = true;
    final more = !_reachedEnd;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  void _readOn() {
    final position = _scroll.position;
    _scroll.animateTo(
      min(position.maxScrollExtent, position.pixels + position.viewportDimension * 0.7),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _turnCard() {
    HapticFeedback.heavyImpact();
    final caught = widget.page.revealed?.team == Team.mafia;
    final stage = SoundStage.instance;
    // Mafioso o innocente: la carta è appena diventata pubblica.
    final meme = stage.memeMode ? beat(caught ? MemeMoment.verdictMafia : MemeMoment.verdictInnocent) : null;
    if (meme == null) stage.cue(caught ? Cue.caught : Cue.innocent);
    setState(() {
      _cardTurned = true;
      _reachedEnd = false;
    });
    _checkAfterLayout();
  }

  /// Più facce ci sono, più piccole; sotto il film del cambio d'ora un po'
  /// meno, perché lo spazio se lo prende il cielo.
  static double _portraitSize(ScriptPage page) {
    final count = page.portraits.length;
    final base = page.nightfall != null ? 96.0 : 124.0;
    if (count <= 1) return base;
    if (count == 2) return base * 0.8;
    return base * 0.62;
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final revealed = page.revealed;
    final cardCovered = revealed != null && !_cardTurned;
    // Quando legge la voce, il gobbo la segue da solo: il pulsante resta
    // quello della pagina, e toccarlo la fa tacere.
    final followsVoice = SpokenScriptCard.speaksIn(context, widget.reader) && !MediaQuery.disableAnimationsOf(context);
    final (label, onPressed) = _moreBelow && !followsVoice
        ? (widget.strings.keepReading, _readOn)
        : cardCovered
            ? (widget.strings.flipTheCard, _turnCard)
            : (page.action, page.onAction);

    return Column(
      children: [
        if (page.nightfall != null)
          PhaseShift(
            key: ValueKey(page),
            toNight: page.nightfall!,
            label: page.nightfall! ? widget.strings.nightFalls : widget.strings.dayBreaks,
          ),
        if (page.nightfall != null && page.portraits.isNotEmpty) const SizedBox(height: 12),
        if (page.nightfall != null && page.portraits.isEmpty)
          const SizedBox.shrink()
        else if (page.portraits.isEmpty && revealed == null)
          Icon(page.icon, color: AppColors.gold, size: 36)
        else
          // I ritratti di chi è in pagina; al verdetto, accanto, la carta
          // da girare: faccia e ruolo si guardano.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final name in page.portraits)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AvatarSpotlight(
                    seed: name,
                    size: _portraitSize(page),
                    fallen: page.portraitsFallen,
                  ),
                ),
              if (revealed != null) ...[
                if (page.portraits.isNotEmpty) const SizedBox(width: 18),
                RoleRevealCard(role: revealed, faceUp: !cardCovered, height: 150),
              ],
            ],
          ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(page.title, style: AppText.display(28)),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) => _update(notification.metrics),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => _update(notification.metrics),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: SpokenScriptCard(
                      reader: widget.reader,
                      lines: cardCovered ? page.lines.sublist(0, 1) : page.lines,
                      // Al cambio d'ora prima parte il tramonto (o l'alba), poi la voce.
                      leadIn: Duration(milliseconds: page.nightfall != null ? 1900 : 450),
                    ),
                  ),
                ),
              ),
              if (_moreBelow)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0014110F), AppColors.background],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
          ),
        ),
      ],
    );
  }
}


import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../../platform/achievements.dart';
import '../../../rules/role.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_reveal_card.dart';
import 'game/noir_ui.dart';
import 'progress_widgets.dart';
import '../../widgets/wide_scale.dart';
import '../../widgets/content_width.dart';
import '../../../l10n/recap_strings.dart';
import 'recap_screen.dart';

/// I risultati dell'ultima partita, a tutto schermo: chi ha vinto, la tua
/// carta, l'esperienza che riempie la barra (con lo scoppio se si sale di
/// livello), le monete che cadono nella borsa e, in classificata, il grado.
/// Restituisce true se si vuole giocare ancora (solo con [offerReplay]).
Future<bool> showMatchResults(BuildContext context, OnlineServices services, {bool offerReplay = false, DateTime? since}) async {
  final ranked = services.ranked;
  if (ranked == null) return false;
  MatchResult? result;
  try {
    result = await ranked.lastResult(since: since).timeout(const Duration(seconds: 8));
  } catch (_) {
    return false;
  }
  if (result == null || !context.mounted) return false;
  int? xpNow;
  try {
    xpNow = (await services.profiles.me()).xp;
  } catch (_) {}
  // The missions and achievements this game completed: banners on top.
  GameUnlocks unlocks = const GameUnlocks();
  try {
    unlocks = await services.progress?.unlocksFor(result.gameId) ?? unlocks;
  } catch (_) {}
  // Confirmed by the server: mirror them to Steam / Game Center / Play Games.
  unawaited(PlatformAchievements.instance.report(unlocks.achievements));
  if (!context.mounted) return false;
  final again = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => MatchResultsScreen(result: result!, xpNow: xpNow, offerReplay: offerReplay, unlocks: unlocks),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
  return again ?? false;
}

class MatchResultsScreen extends StatefulWidget {
  final MatchResult result;

  /// L'esperienza verso il prossimo livello dopo la partita (dal profilo).
  final int? xpNow;
  final bool offerReplay;

  /// Le missioni e le medaglie della partita: le loro targhe nella fascia in
  /// alto, sopra il titolo e mai su di esso.
  final GameUnlocks unlocks;

  const MatchResultsScreen({
    super.key,
    required this.result,
    this.xpNow,
    this.offerReplay = false,
    this.unlocks = const GameUnlocks(),
  });

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  bool _buzzedLevel = false;

  @override
  void initState() {
    super.initState();
    _show.addListener(_haptics);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (still) {
        _show.value = 1;
      } else {
        _show.forward();
      }
    });
  }

  void _haptics() {
    if (!_buzzedLevel && widget.result.leveledUp && _show.value >= 0.55) {
      _buzzedLevel = true;
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  Role? get _role {
    for (final role in Role.values) {
      if (role.name == widget.result.role) return role;
    }
    return null;
  }

  double _stage(double from, double to) => Curves.easeOutCubic.transform(((_show.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) =>
      DesktopCanvas.of(context) ? _desk(context) : WideScale(child: Builder(builder: _build));

  /// Chi ha vinto, a parole (null se non si dice): il risultato dice solo
  /// se hai vinto tu.
  String? _winners(AppStrings strings) {
    String m(String key) => strings.language.message('results.$key');
    final r = widget.result;
    final role = _role;
    String faction(Team team) => switch (team) {
          Team.mafia => m('familyWins'),
          Team.citizens => m('townWins'),
          Team.neutral => m('loneWolfWins'),
        };
    if (r.abandoned || role == null) return null;
    if (!r.won) return m('youLost');
    if (role.team != Team.neutral) return faction(role.team);
    return switch (role) {
      Role.cacciatore => m('bountyPaid'),
      Role.strozzino => m('loanSharkCashesIn'),
      Role.fesso => m('foolLastLaugh'),
      Role.sicario => m('hitmanStandsAlone'),
      Role.piromane => m('cityBurns'),
      _ => faction(Team.neutral),
    };
  }

  /// Da tastiera: prima della fine dello spettacolo il primo tasto lo fa
  /// vedere tutto, poi si esce.
  void _key(bool again) {
    if (_show.value < 0.88) {
      _show.value = 1;
      return;
    }
    Navigator.of(context).pop(again);
  }

  /// Su PC: a sinistra il verdetto e la carta grande, a destra quello che
  /// la partita ha fruttato e i pulsanti. INVIO gioca ancora (o torna),
  /// Esc torna indietro.
  Widget _desk(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    String m(String key) => strings.language.message('results.$key');
    final r = widget.result;
    final role = _role;
    final won = r.won && !r.abandoned;
    final accent = won ? Saloon.brass : Saloon.blood;
    final winners = _winners(strings);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _key(false),
        const SingleActivator(LogicalKeyboardKey.enter): () => _key(widget.offerReplay),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () => _key(widget.offerReplay),
      },
      child: Focus(
        autofocus: true,
        child: DeskTheme(
          child: NoirDesk(
            child: Scaffold(
              key: const Key('results.screen'),
              backgroundColor: const Color(0xFF080504),
              body: AnimatedBuilder(
                animation: _show,
                builder: (context, _) {
                  final title = _stage(0, 0.18);
                  final card = _stage(0.12, 0.32);
                  final xp = _stage(0.3, 0.6);
                  final coins = _stage(0.58, 0.85);
                  final rank = _stage(0.8, 0.95);
                  final buttons = _stage(0.88, 1);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.4, -0.25),
                        radius: 1.1,
                        colors: [
                          Color.lerp(
                              const Color(0xFF1A100A), won ? const Color(0xFF4A3014) : const Color(0xFF3A0E10), title)!,
                          const Color(0xFF080504),
                        ],
                      ),
                    ),
                    child: _underToasts(top: 16, Center(
                      child: SizedBox(
                        width: 1500,
                        height: 860,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 620,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Opacity(
                                    opacity: title,
                                    child: Column(
                                      children: [
                                        Text(t.resultsTitle.toUpperCase(), style: DeskText.overline(color: Saloon.brass)),
                                        if (r.testMatch)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(t.rankedTestMatch, style: DeskText.overline(color: AppColors.gold)),
                                          ),
                                        const SizedBox(height: 10),
                                        Transform.scale(
                                          scale: 1.4 - 0.4 * title,
                                          child: Text(
                                            (r.abandoned ? t.resultsLeft : (won ? t.resultsWon : t.resultsLost))
                                                .toUpperCase(),
                                            key: const Key('results.title'),
                                            textAlign: TextAlign.center,
                                            style: AppText.display(r.abandoned ? 52 : 84, color: accent).copyWith(
                                              letterSpacing: 6,
                                              height: 1.05,
                                              shadows: [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 36)],
                                            ),
                                          ),
                                        ),
                                        if (winners != null) ...[
                                          const SizedBox(height: 10),
                                          Text(winners,
                                              style: DeskText.overline(color: Saloon.paper)
                                                  .copyWith(fontSize: 18, letterSpacing: 4)),
                                        ],
                                        if (r.afk && !r.abandoned)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: Text(
                                              t.resultsAfk,
                                              key: const Key('results.afk'),
                                              textAlign: TextAlign.center,
                                              style: DeskText.overline(color: Saloon.blood),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (role != null) ...[
                                    const SizedBox(height: 48),
                                    Transform.translate(
                                      offset: Offset(0, 60 * (1 - card)),
                                      child: Opacity(
                                        opacity: card,
                                        child: RoleRevealCard(role: role, faceUp: card > 0.4, height: 400),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              width: 1.2,
                              margin: const EdgeInsets.symmetric(horizontal: 72, vertical: 70),
                              color: Saloon.brassDeep.withValues(alpha: 0.6 * title),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Opacity(opacity: xp > 0 ? 1 : 0, child: _xpBlock(context, xp, k: 1.6)),
                                  if (r.coinsGained > 0)
                                    Opacity(opacity: coins > 0 ? 1 : 0, child: _purse(context, coins, k: 1.6)),
                                  if (r.ratingDelta case final delta? when r.tier != null)
                                    Opacity(
                                      opacity: rank,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 36),
                                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 28),
                                        decoration: Saloon.scrim(radius: DeskSize.radius),
                                        child: Row(
                                          children: [
                                            Icon(
                                              delta >= 0 ? Icons.trending_up : Icons.trending_down,
                                              size: 40,
                                              color: delta >= 0 ? const Color(0xFF8FD18F) : Saloon.blood,
                                            ),
                                            const SizedBox(width: 22),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.tierName(r.tier!).toUpperCase(),
                                                    key: const Key('results.rank'),
                                                    style: AppText.display(DeskText.title + 4, color: Saloon.brass)
                                                        .copyWith(letterSpacing: 4),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    delta >= 0 ? t.resultsRatingUp : t.resultsRatingDown,
                                                    style: DeskText.text(
                                                      size: DeskText.lead,
                                                      color: delta >= 0 ? const Color(0xFF8FD18F) : Saloon.blood,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 56),
                                  Opacity(
                                    opacity: buttons,
                                    child: IgnorePointer(
                                      ignoring: buttons < 0.5,
                                      child: Row(
                                        children: [
                                          if (RecapShelf.last case final recap?) ...[
                                            Expanded(
                                              child: NoirButton(
                                                key: const Key('results.recap'),
                                                kind: NoirButtonKind.brass,
                                                label: RecapStrings.of(context).open,
                                                onPressed: () => showGameRecap(context, recap, me: RecapShelf.me),
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                          ],
                                          Expanded(
                                            child: NoirButton(
                                              key: const Key('results.continue'),
                                              kind: widget.offerReplay ? NoirButtonKind.brass : NoirButtonKind.enamel,
                                              label: widget.offerReplay
                                                  ? (m('back'))
                                                  : (m('backToRoom')),
                                              onPressed: () => Navigator.of(context).pop(false),
                                            ),
                                          ),
                                          if (widget.offerReplay) ...[
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: NoirButton(
                                                key: const Key('results.again'),
                                                label: m('playAgain'),
                                                onPressed: () => Navigator.of(context).pop(true),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Opacity(
                                    opacity: buttons,
                                    child: Text(
                                      widget.offerReplay
                                          ? (m('keysPlayAgainOrBack'))
                                          : (m('keysBackToRoom')),
                                      textAlign: TextAlign.center,
                                      style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Le targhe delle missioni e delle medaglie: una sola, che non riparte
  /// a ogni fotogramma dello spettacolo.
  late final Widget _toasts = ProgressToasts(unlocks: widget.unlocks);

  /// I risultati sotto la fascia delle targhe: il titolo resta sempre
  /// libero, e niente si sposta quando le targhe vanno e vengono.
  Widget _underToasts(Widget results, {double top = 0}) => widget.unlocks.isEmpty
      ? results
      : Column(
          children: [
            Padding(padding: EdgeInsets.only(top: top), child: _toasts),
            Expanded(child: results),
          ],
        );

  Widget _build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    String m(String key) => strings.language.message('results.$key');
    final r = widget.result;
    final role = _role;
    final won = r.won && !r.abandoned;
    final accent = won ? Saloon.brass : Saloon.blood;
    String faction(Team team) => switch (team) {
          Team.mafia => m('familyWins'),
          Team.citizens => m('townWins'),
          Team.neutral => m('loneWolfWins'),
        };
    // Il risultato dice solo se hai vinto tu: chi ha vinto davvero, quando
    // hai perso, non si indovina.
    final winners = r.abandoned || role == null
        ? null
        : !won
            ? (m('youLost'))
            : role.team != Team.neutral
                ? faction(role.team)
                : switch (role) {
                    Role.cacciatore => m('bountyPaid'),
                    Role.strozzino => m('loanSharkCashesIn'),
                    Role.fesso => m('foolLastLaugh'),
                    Role.sicario => m('hitmanStandsAlone'),
                    Role.piromane => m('cityBurns'),
                    _ => faction(Team.neutral),
                  };
    return Scaffold(
      key: const Key('results.screen'),
      backgroundColor: const Color(0xFF080504),
      body: AnimatedBuilder(
        animation: _show,
        builder: (context, _) {
          final title = _stage(0, 0.18);
          final card = _stage(0.12, 0.32);
          final xp = _stage(0.3, 0.6);
          final coins = _stage(0.58, 0.85);
          final rank = _stage(0.8, 0.95);
          final buttons = _stage(0.88, 1);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.2,
                colors: [Color.lerp(const Color(0xFF1A100A), won ? const Color(0xFF4A3014) : const Color(0xFF3A0E10), title)!, const Color(0xFF080504)],
              ),
            ),
            child: ContentWidth(maxWidth: 680, child: SafeArea(
              child: _underToasts(LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Opacity(
                          opacity: title,
                          child: Column(
                            children: [
                              Text(t.resultsTitle, style: AppText.overline.copyWith(color: Saloon.brass, letterSpacing: 4)),
                              if (r.testMatch) Text(t.rankedTestMatch, style: AppText.overline.copyWith(color: AppColors.gold, fontSize: 10)),
                              const SizedBox(height: 6),
                              Transform.scale(
                                scale: 1.6 - 0.6 * title,
                                child: Text(
                                  (r.abandoned ? t.resultsLeft : (won ? t.resultsWon : t.resultsLost)).toUpperCase(),
                                  key: const Key('results.title'),
                                  textAlign: TextAlign.center,
                                  style: AppText.display(r.abandoned ? 30 : 46, color: accent).copyWith(
                                    letterSpacing: 4,
                                    shadows: [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 24)],
                                  ),
                                ),
                              ),
                              if (winners != null)
                                Text(winners, style: AppText.overline.copyWith(color: Saloon.paper, fontSize: 12, letterSpacing: 3)),
                              if (r.afk && !r.abandoned)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    t.resultsAfk,
                                    key: const Key('results.afk'),
                                    textAlign: TextAlign.center,
                                    style: AppText.overline.copyWith(color: Saloon.blood, fontSize: 12, letterSpacing: 2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (role != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Transform.translate(
                              offset: Offset(0, 40 * (1 - card)),
                              child: Opacity(opacity: card, child: RoleRevealCard(role: role, faceUp: card > 0.4, height: min(190, box.maxHeight * 0.26))),
                            ),
                          ),
                        Opacity(opacity: xp > 0 ? 1 : 0, child: _xpBlock(context, xp)),
                        if (r.coinsGained > 0) Opacity(opacity: coins > 0 ? 1 : 0, child: _purse(context, coins)),
                        if (r.ratingDelta case final delta? when r.tier != null)
                          Opacity(
                            opacity: rank,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(
                                children: [
                                  Text(
                                    t.tierName(r.tier!).toUpperCase(),
                                    key: const Key('results.rank'),
                                    style: AppText.display(24, color: Saloon.brass).copyWith(letterSpacing: 3),
                                  ),
                                  Text(
                                    delta >= 0 ? t.resultsRatingUp : t.resultsRatingDown,
                                    style: AppText.body.copyWith(color: delta >= 0 ? const Color(0xFF8FD18F) : Saloon.blood),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Opacity(
                          opacity: buttons,
                          child: IgnorePointer(
                            ignoring: buttons < 0.5,
                            child: Column(
                              children: [
                                if (widget.offerReplay) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: NoirButton(
                                      key: const Key('results.again'),
                                      label: m('playAgain'),
                                      onPressed: () => Navigator.of(context).pop(true),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (RecapShelf.last case final recap?) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: NoirButton(
                                      key: const Key('results.recap'),
                                      kind: NoirButtonKind.brass,
                                      label: RecapStrings.of(context).open,
                                      onPressed: () => showGameRecap(context, recap, me: RecapShelf.me),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: NoirButton(
                                    key: const Key('results.continue'),
                                    kind: widget.offerReplay ? NoirButtonKind.brass : NoirButtonKind.enamel,
                                    label: widget.offerReplay ? (m('back')) : (m('backToRoom')),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            )),
          );
        },
      ),
    );
  }

  /// La barra dell'esperienza: si riempie col contatore; se si sale di
  /// livello arriva in fondo, scoppia e riparte dal livello nuovo.
  Widget _xpBlock(BuildContext context, double p, {double k = 1}) {
    final t = AppStrings.of(context).online;
    final r = widget.result;
    final gained = (r.xpGained * p).round();
    final after = widget.xpNow;
    double fill;
    int level;
    var burst = 0.0;
    if (r.leveledUp) {
      if (p < 0.6) {
        fill = p / 0.6;
        level = r.levelBefore;
      } else {
        burst = ((p - 0.6) / 0.4).clamp(0.0, 1.0);
        level = r.levelAfter;
        final end = after == null ? 0.0 : after / Progression.xpToNext(r.levelAfter);
        fill = end * burst;
      }
    } else {
      level = r.levelAfter;
      final need = Progression.xpToNext(level);
      final end = after == null ? 0.0 : after / need;
      final start = after == null ? 0.0 : max(0, after - r.xpGained) / need;
      fill = start + (end - start) * p;
    }
    return Column(
      children: [
        Row(
          children: [
            Text(
              AppStrings.of(context).language.message('results.level', {'level': level}),
              style: AppText.overline.copyWith(
                color: Saloon.paper,
                letterSpacing: 2 * k,
                fontSize: (AppText.overline.fontSize ?? 11) * k,
              ),
            ),
            const Spacer(),
            Text(t.resultsXp(gained), key: const Key('results.xp'), style: AppText.display(18 * k, color: Saloon.brass)),
          ],
        ),
        SizedBox(height: 6 * k),
        SizedBox(
          height: 18 * k,
          child: CustomPaint(size: Size.infinite, painter: _BarPainter(fill.clamp(0.0, 1.0), burst)),
        ),
        if (r.leveledUp && burst > 0)
          Transform.scale(
            scale: 0.6 + 0.4 * Curves.elasticOut.transform(burst),
            child: Padding(
              padding: EdgeInsets.only(top: 8 * k),
              child: Text(
                t.resultsLevelUp(r.levelAfter).toUpperCase(),
                key: const Key('results.levelUp'),
                style: AppText.display(26 * k, color: AppColors.gold).copyWith(
                  shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.8), blurRadius: 18 * (1 - burst) + 6)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Le monete cadono nella borsa e il contatore sale.
  Widget _purse(BuildContext context, double p, {double k = 1}) {
    final t = AppStrings.of(context).online;
    final coins = (widget.result.coinsGained * p).round();
    return Padding(
      padding: EdgeInsets.only(top: 16 * k),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 74 * k, height: 84 * k, child: CustomPaint(painter: _PursePainter(p))),
          SizedBox(width: 14 * k),
          Text(t.resultsCoins(coins),
              key: const Key('results.coins'), style: AppText.display(24 * k, color: AppColors.gold)),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double fill;
  final double burst;
  _BarPainter(this.fill, this.burst);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1C130C));
    if (fill > 0) {
      final f = Rect.fromLTWH(0, 0, size.width * fill, size.height);
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRect(
        f,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF8C6A26), Color(0xFFE6C27A), Color(0xFFFFF0C4)]).createShader(f),
      );
      canvas.restore();
    }
    canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = Saloon.brass);
    if (burst > 0 && burst < 1) {
      final c = Offset(size.width, size.height / 2);
      final rays = Paint()
        ..color = AppColors.gold.withValues(alpha: 1 - burst)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6;
        final d = Offset(cos(a), sin(a));
        canvas.drawLine(c + d * (8 + 30 * burst), c + d * (16 + 52 * burst), rays);
      }
      canvas.drawCircle(c, 26 * burst, Paint()..color = AppColors.gold.withValues(alpha: 0.4 * (1 - burst)));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.fill != fill || old.burst != burst;
}

/// Una borsa di cuoio con le monete che ci piovono dentro.
class _PursePainter extends CustomPainter {
  final double p;
  _PursePainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.22, h * 0.42)
      ..quadraticBezierTo(0, h * 0.62, w * 0.1, h * 0.88)
      ..quadraticBezierTo(w * 0.5, h * 1.02, w * 0.9, h * 0.88)
      ..quadraticBezierTo(w, h * 0.62, w * 0.78, h * 0.42)
      ..close();
    // Le monete che cadono, dietro la bocca della borsa.
    final coin = Paint()..color = const Color(0xFFE2BC6C);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF7A5A1E);
    for (var i = 0; i < 7; i++) {
      final local = (p * 1.6 - i * 0.12).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final x = w * (0.32 + (i * 37 % 36) / 100);
      final y = -10 + (h * 0.5) * Curves.easeIn.transform(local);
      final squash = 0.35 + 0.65 * (0.5 + 0.5 * cos(local * 9 + i));
      final rect = Rect.fromCenter(center: Offset(x, y), width: 13 * squash, height: 13);
      canvas.drawOval(rect, coin);
      canvas.drawOval(rect, rim);
    }
    canvas.drawShadow(body, Colors.black, 4, false);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8A5A30), Color(0xFF4A2A14)])
            .createShader(Offset.zero & size),
    );
    canvas.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = const Color(0xFF2A160A));
    // La bocca arricciata e il laccio.
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h * 0.42), width: w * 0.6, height: h * 0.1), Paint()..color = const Color(0xFF2A160A));
    canvas.drawLine(Offset(w * 0.3, h * 0.48), Offset(w * 0.7, h * 0.48), Paint()..color = Saloon.brass..strokeWidth = 2.2);
    canvas.drawCircle(Offset(w * 0.5, h * 0.66), 7, Paint()..color = Saloon.brass.withValues(alpha: 0.85));
    final tp = TextPainter(
      text: const TextSpan(text: '\$', style: TextStyle(color: Color(0xFF4A2A14), fontSize: 10, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.5, h * 0.66) - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PursePainter old) => old.p != p;
}

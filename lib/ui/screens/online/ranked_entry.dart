import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/online_strings.dart';
import '../../../l10n/progress_strings.dart';
import '../../../online/ranked_models.dart';
import '../../../l10n/desktop_online_strings.dart';
import '../../../l10n/desktop_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../../../tutorial/tutorial_story.dart';
import '../../theme/app_theme.dart';
import '../../theme/role_style.dart';
import 'game/noir_ui.dart';

/// La stanza sul retro: una lampada sopra il tavolo verde, il fumo, il
/// proprio grado timbrato, due carte da gioco per la lingua del tavolo e il
/// grande "Siediti al tavolo". Mentre si cerca, la lampada respira.
class RankedEntryView extends StatelessWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;
  final bool queued;
  final Animation<double> sweep;
  final String? cooldown;
  final bool warning;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  /// Opens the leaderboard (null: no link).
  final VoidCallback? onLeaderboard;

  /// Il proprio grado nella lingua scelta e quanto manca al prossimo (0..1).
  final RankTier? tier;
  final double? progress;

  /// Quanti sono in coda per lingua: si mostrano solo da [OnlineCounts.encouraging].
  final Map<AppLanguage, int> queuedCounts;

  /// Le mani di prova finite: senza tutte e tre la classificata è chiusa e
  /// al posto di «Siediti» c'è la prima mano che manca ([onTutorial]).
  final Set<TutorialStory> tutorialsDone;
  final ValueChanged<TutorialStory>? onTutorial;

  bool get _locked => !tutorialsDone.containsAll(TutorialStory.values);

  /// Invio sul PC: «Siediti», o la prima mano di prova che manca.
  void _enter() {
    if (queued || cooldown != null) return;
    if (!_locked) return onStart();
    final missing = TutorialStory.values.where((s) => !tutorialsDone.contains(s)).firstOrNull;
    if (missing != null) onTutorial?.call(missing);
  }

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
    this.tier,
    this.progress,
    this.queuedCounts = const {},
    this.onLeaderboard,
    this.tutorialsDone = const {TutorialStory.family, TutorialStory.city, TutorialStory.solo},
    this.onTutorial,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    if (DesktopCanvas.of(context)) return _desk(context, t);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0706),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.45),
                  radius: 1.1,
                  colors: [Color(0xFF2E1C10), Color(0xFF140C07), Color(0xFF070504)],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
          ),
          SafeArea(
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
                    builder: (context, box) {
                      final short = box.maxHeight < 600;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: (box.maxHeight * (short ? 0.27 : 0.34)).clamp(120.0, 300.0),
                                    width: double.infinity,
                                    child: AnimatedBuilder(
                                      animation: sweep,
                                      builder: (context, _) => CustomPaint(painter: _RoomPainter(queued ? sweep.value : null)),
                                    ),
                                  ),
                                  SizedBox(height: short ? 6 : 10),
                                  _RankBadge(tier: tier, progress: progress),
                                  if (onLeaderboard case final open?)
                                    TextButton.icon(
                                      key: const Key('ranked.leaderboard'),
                                      onPressed: open,
                                      icon: const Icon(Icons.leaderboard, color: Saloon.brass, size: 18),
                                      label: Text(
                                        ProgressStrings.of(context).leaderboard.toUpperCase(),
                                        style: AppText.overline.copyWith(color: Saloon.brass, letterSpacing: 2.4),
                                      ),
                                    ),
                                  SizedBox(height: short ? 14 : 22),
                                  if (queued) ..._searching(t) else ..._choose(t),
                                  if (warning) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      t.rankedWarning,
                                      textAlign: TextAlign.center,
                                      style: AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                  SizedBox(height: short ? 12 : 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sul PC: a sinistra la stanza con la lampada, grande come una scena; a
  /// destra il banco con il grado, le due carte e il pulsante. Frecce per
  /// la lingua, INVIO per sedersi, Esc per tornare.
  Widget _desk(BuildContext context, OnlineStrings t) {
    final d = DesktopOnlineStrings.of(context);
    void pick(AppLanguage lang) {
      if (queued || lang == language) return;
      HapticFeedback.selectionClick();
      onLanguage(lang);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0706),
      body: NoirDesk(
        child: DeskTheme(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): () {
                _enter();
              },
              const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                _enter();
              },
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () => pick(AppLanguage.it),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () => pick(AppLanguage.en),
            },
            child: DeskEscape(
              onEscape: () => queued ? onCancel() : Navigator.of(context).maybePop(),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.35, -0.3),
                          radius: 1.2,
                          colors: [Color(0xFF2E1C10), Color(0xFF140C07), Color(0xFF070504)],
                          stops: [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DeskTopBar(title: t.rankedQueueTitle),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 0, DeskSize.gutter, DeskSize.gutter),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: AnimatedBuilder(
                                  animation: sweep,
                                  builder: (context, _) => CustomPaint(
                                    size: Size.infinite,
                                    painter: _RoomPainter(queued ? sweep.value : null),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 56),
                              Container(
                                width: 700,
                                padding: const EdgeInsets.fromLTRB(48, 44, 48, 44),
                                decoration: Saloon.scrim(radius: DeskSize.radius),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _RankBadge(tier: tier, progress: progress),
                                    const SizedBox(height: 44),
                                    Text(
                                      t.rankedPickTable.toUpperCase(),
                                      style: DeskText.overline(color: Saloon.brass),
                                    ),
                                    const SizedBox(height: 24),
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (final (lang, label, sub, suit) in [
                                            (AppLanguage.it, 'Italiano', t.rankedTableIt, '♠'),
                                            (AppLanguage.en, 'English', t.rankedTableEn, '♥'),
                                          ]) ...[
                                            if (lang == AppLanguage.en) const SizedBox(width: 24),
                                            Expanded(
                                              child: _TableCard(
                                                key: Key('ranked.lang.${lang.name}'),
                                                label: label,
                                                corner: lang.name.toUpperCase(),
                                                suit: suit,
                                                sub: sub,
                                                queued: switch (queuedCounts[lang]) {
                                                  final n? when n >= OnlineCounts.encouraging => t.rankedTableQueued(n),
                                                  _ => null,
                                                },
                                                selected: language == lang,
                                                onTap: () => pick(lang),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    Text(d.rankedHow.toUpperCase(), style: DeskText.overline(color: Saloon.brass)),
                                    const SizedBox(height: 12),
                                    Text(
                                      t.rankedRules,
                                      key: const Key('ranked.rules'),
                                      style: DeskText.text(color: Saloon.paper.withValues(alpha: 0.82)).copyWith(height: 1.45),
                                    ),
                                    const Spacer(),
                                    if (queued) ...[
                                      Text(
                                        t.rankedSearching,
                                        key: const Key('ranked.searching'),
                                        textAlign: TextAlign.center,
                                        style: DeskText.display(DeskText.title, color: Saloon.paper),
                                      ),
                                      const SizedBox(height: 24),
                                      NoirButton(
                                        key: const Key('ranked.cancel'),
                                        kind: NoirButtonKind.brass,
                                        label: t.rankedCancel,
                                        onPressed: onCancel,
                                      ),
                                    ] else if (cooldown != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                        decoration: Saloon.scrim(),
                                        child: Text(
                                          cooldown!,
                                          textAlign: TextAlign.center,
                                          style: DeskText.text(size: DeskText.lead, color: AppColors.gold),
                                        ),
                                      )
                                    else if (_locked)
                                      _TutorialLock(done: tutorialsDone, onPlay: onTutorial, desk: true)
                                    else ...[
                                      NoirButton(
                                        key: const Key('ranked.start'),
                                        label: t.rankedSit.toUpperCase(),
                                        onPressed: onStart,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        DesktopStrings.of(context).enterHint,
                                        textAlign: TextAlign.center,
                                        style: DeskText.overline(color: AppColors.textSecondary),
                                      ),
                                    ],
                                    if (warning) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        t.rankedWarning,
                                        textAlign: TextAlign.center,
                                        style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  List<Widget> _searching(OnlineStrings t) => [
        Text(
          t.rankedSearching,
          key: const Key('ranked.searching'),
          textAlign: TextAlign.center,
          style: AppText.display(20, color: Saloon.paper),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: NoirButton(key: const Key('ranked.cancel'), kind: NoirButtonKind.brass, label: t.rankedCancel, onPressed: onCancel),
        ),
      ];

  List<Widget> _choose(OnlineStrings t) => [
        Text(
          t.rankedPickTable,
          style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 11, letterSpacing: 3.2),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (lang, label, sub, suit) in [
                (AppLanguage.it, 'Italiano', t.rankedTableIt, '♠'),
                (AppLanguage.en, 'English', t.rankedTableEn, '♥'),
              ]) ...[
                if (lang == AppLanguage.en) const SizedBox(width: 14),
                Expanded(
                  child: _TableCard(
                    key: Key('ranked.lang.${lang.name}'),
                    label: label,
                    corner: lang.name.toUpperCase(),
                    suit: suit,
                    sub: sub,
                    queued: switch (queuedCounts[lang]) {
                      final n? when n >= OnlineCounts.encouraging => t.rankedTableQueued(n),
                      _ => null,
                    },
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
        ),
        const SizedBox(height: 16),
        Text(
          t.rankedRules,
          key: const Key('ranked.rules'),
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: Saloon.paper.withValues(alpha: 0.78), fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (cooldown != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: Saloon.scrim(),
            child: Text(cooldown!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.gold)),
          )
        else if (_locked)
          _TutorialLock(done: tutorialsDone, onPlay: onTutorial, desk: false)
        else
          SizedBox(
            width: double.infinity,
            child: NoirButton(key: const Key('ranked.start'), label: (t.rankedSit).toUpperCase(), onPressed: onStart),
          ),
      ];
}

/// Il grado timbrato in inchiostro rosso, con la barra verso il prossimo.
/// La classificata chiusa: le tre mani di prova (rossa, oro, verde), con la
/// spunta su quelle finite, e il bottone per la prima che manca.
class _TutorialLock extends StatelessWidget {
  final Set<TutorialStory> done;
  final ValueChanged<TutorialStory>? onPlay;
  final bool desk;

  const _TutorialLock({required this.done, required this.onPlay, required this.desk});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final missing = TutorialStory.values.where((s) => !done.contains(s)).firstOrNull;
    final badge = desk ? 52.0 : 46.0;
    return Container(
      key: const Key('ranked.locked'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: desk ? 24 : 16, vertical: 14),
      decoration: Saloon.scrim(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.rankedTutorialsTitle.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppText.overline.copyWith(color: Saloon.brass, fontSize: desk ? 15 : 11, letterSpacing: 2.4),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final story in TutorialStory.values) ...[
                if (story != TutorialStory.values.first) SizedBox(width: desk ? 22 : 16),
                Semantics(
                  label: t.rankedTutorialName(story.id),
                  checked: done.contains(story),
                  child: SizedBox(
                    key: Key('ranked.tutorial.${story.id}.${done.contains(story) ? 'done' : 'todo'}'),
                    width: badge + 8,
                    height: badge + 8,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Opacity(
                            opacity: done.contains(story) ? 1 : 0.45,
                            child: Container(
                              width: badge,
                              height: badge,
                              padding: EdgeInsets.all(badge * 0.14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: story.color.withValues(alpha: 0.16),
                                border: Border.all(color: story.color, width: 2),
                              ),
                              child: RoleIcon(story.role, size: badge * 0.72),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: badge * 0.42,
                            height: badge * 0.42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done.contains(story) ? story.color : const Color(0xFF1A1210),
                              border: Border.all(color: story.color, width: 1.5),
                            ),
                            child: done.contains(story)
                                ? Icon(Icons.check_rounded, size: badge * 0.3, color: const Color(0xFF140C07))
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          Text(
            t.rankedTutorialsBody,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(fontSize: desk ? 15 : 12.5, height: 1.3, color: Saloon.paper.withValues(alpha: 0.8)),
          ),
          if (missing != null) ...[
            SizedBox(height: 12),
            NoirButton(
              key: const Key('ranked.tutorial'),
              label: t.rankedTutorialPlay(t.rankedTutorialName(missing.id)).toUpperCase(),
              onPressed: onPlay == null ? null : () => onPlay!(missing),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final RankTier? tier;
  final double? progress;
  const _RankBadge({required this.tier, required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final tier = this.tier ?? RankTier.picciotto;
    final next = tier.next;
    final p = progress ?? 0;
    final desk = DesktopCanvas.of(context);
    return Container(
      key: const Key('ranked.rank'),
      padding: desk ? const EdgeInsets.fromLTRB(28, 22, 28, 22) : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: Saloon.scrim(radius: 12, border: Saloon.brassDeep),
      child: Row(
        children: [
          Transform.rotate(
            angle: -0.07,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Saloon.blood, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                t.tierName(tier).toUpperCase(),
                style: AppText.display(desk ? 26 : 15, color: Saloon.blood).copyWith(letterSpacing: 2.2),
              ),
            ),
          ),
          SizedBox(width: desk ? 28 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.rankedYourRank, style: AppText.overline.copyWith(color: Saloon.brass, fontSize: desk ? 14 : 9.5, letterSpacing: 2.2)),
                SizedBox(height: desk ? 12 : 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: desk ? 10 : 6,
                    child: Stack(
                      children: [
                        Positioned.fill(child: Container(color: const Color(0xFF2A211B))),
                        FractionallySizedBox(
                          widthFactor: next == null ? 1 : max(0.04, p),
                          heightFactor: 1,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [Saloon.brassDeep, Saloon.brass])),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null ? t.rankedTopTier : t.rankedTowards(t.tierName(next)),
                  style: AppText.body.copyWith(fontSize: desk ? 17 : 12, height: 1.1, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una carta da gioco grande: indici negli angoli, il nome della lingua al
/// centro. Quella scelta è d'avorio con il filo d'oro, l'altra è girata a metà nell'ombra.
class _TableCard extends StatelessWidget {
  final String label;
  final String corner;
  final String suit;
  final String sub;
  final String? queued;
  final bool selected;
  final VoidCallback onTap;

  const _TableCard({
    super.key,
    required this.label,
    required this.corner,
    required this.suit,
    required this.sub,
    required this.queued,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final desk = DesktopCanvas.of(context);
    final k = desk ? 1.6 : 1.0;
    final ink = selected ? Saloon.paperInk : Saloon.paper.withValues(alpha: 0.82);
    final red = selected ? Saloon.enamel : Saloon.blood.withValues(alpha: 0.85);
    final suitColor = suit == '♥' ? red : ink;
    Widget index(bool flip) => Transform.rotate(
          angle: flip ? pi : 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(corner, style: AppText.display(13 * k, color: ink).copyWith(letterSpacing: 0.5, height: 1)),
              const SizedBox(height: 3),
              CustomPaint(size: Size(11 * k, 11 * k), painter: _SuitPainter(heart: suit == '♥', color: suitColor)),
            ],
          ),
        );
    return Semantics(
      button: true,
      selected: selected,
      label: '$label · $sub${queued == null ? '' : ' · $queued'}',
      excludeSemantics: true,
      child: DeskHover(
        onTap: onTap,
        builder: (context, hovered) => AnimatedSlide(
          offset: Offset(0, selected ? -0.03 : (hovered && desk ? -0.015 : 0)),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(minHeight: 150 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? const [Color(0xFFF6EBD2), Color(0xFFE9D9B4)]
                    : const [Color(0xFF241A13), Color(0xFF16100C)],
              ),
              border: Border.all(
                color: selected || (hovered && desk) ? Saloon.brass : Saloon.brassDeep.withValues(alpha: 0.7),
                width: selected ? 2.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: selected ? 18 : 6, offset: const Offset(0, 6)),
                if (selected) BoxShadow(color: Saloon.brass.withValues(alpha: 0.28), blurRadius: 22),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Il filo interno delle carte buone.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Saloon.brassDeep.withValues(alpha: selected ? 0.55 : 0.35)),
                      ),
                    ),
                  ),
                ),
                Positioned(left: 11, top: 10, child: index(false)),
                Positioned(right: 11, bottom: 10, child: index(true)),
                Padding(
                  padding: EdgeInsets.fromLTRB(14 * k, 34 * k, 14 * k, 34 * k),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, style: AppText.display(24 * k, color: ink).copyWith(letterSpacing: 0.6)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sub,
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(fontSize: desk ? 17 : 12, height: 1.2, fontStyle: FontStyle.italic, color: ink.withValues(alpha: 0.7)),
                      ),
                      if (queued != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: selected ? Saloon.paperInk : Saloon.ink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Saloon.online, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(queued!, style: AppText.overline.copyWith(color: Saloon.paper, fontSize: desk ? 14 : 10, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ],
                    ],
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

/// La stanza: buio, una lampada a campana, il cono di luce e il fumo, e
/// sotto il bordo del tavolo verde con qualche fiche. [breath] fa respirare
/// la luce mentre si cerca.
class _RoomPainter extends CustomPainter {
  final double? breath;
  const _RoomPainter(this.breath);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final lampY = h * 0.18;
    final tableY = h * 0.78;
    final glow = breath == null ? 1.0 : 0.82 + 0.18 * (0.5 + 0.5 * sin(breath! * 2 * pi));

    // Il calore attorno al tavolo.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, tableY), width: w * 1.2, height: h * 0.9),
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFF4A2E18).withValues(alpha: 0.55 * glow), Colors.transparent])
            .createShader(Rect.fromCenter(center: Offset(cx, tableY), width: w * 1.2, height: h * 0.9)),
    );

    // Il cono di luce.
    final spread = min(w * 0.46, 260.0);
    final cone = Path()
      ..moveTo(cx - 26, lampY + 18)
      ..lineTo(cx + 26, lampY + 18)
      ..lineTo(cx + spread, tableY)
      ..lineTo(cx - spread, tableY)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFD98A).withValues(alpha: 0.22 * glow), const Color(0xFFFFD98A).withValues(alpha: 0.04 * glow)],
        ).createShader(Rect.fromLTRB(0, lampY, w, tableY))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Il fumo: qualche nuvola larga e morbida.
    final smoke = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    final drift = (breath ?? 0) * 2 * pi;
    for (final (dx, dy, r, a) in [(-0.2, 0.55, 46.0, 0.07), (0.22, 0.4, 56.0, 0.06), (0.05, 0.7, 40.0, 0.05), (-0.3, 0.2, 34.0, 0.04)]) {
      smoke.color = const Color(0xFFE8DCC4).withValues(alpha: a);
      canvas.drawCircle(Offset(cx + w * dx + 8 * sin(drift + dy * 5), lampY + (tableY - lampY) * dy), r, smoke);
    }

    // Il tavolo: un'ellisse verde col bordo di legno, vista di sbieco.
    final tw = min(w * 1.04, 600.0);
    final table = Rect.fromCenter(center: Offset(cx, tableY), width: tw, height: min(tw * 0.22, h * 0.3));
    canvas.drawOval(table.inflate(14).shift(const Offset(0, 10)), Paint()..color = Colors.black.withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawOval(table.inflate(10), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6A3D20), Saloon.woodDark]).createShader(table.inflate(10)));
    canvas.drawOval(
      table,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 0.75,
          colors: [Color.lerp(Saloon.feltDeep, const Color(0xFF2F6B4A), glow)!, Saloon.feltDeep],
        ).createShader(table),
    );
    canvas.drawOval(table.deflate(8), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Saloon.brass.withValues(alpha: 0.25));

    // Due carte coperte e una pila di fiche sul panno.
    void card(Offset c, double angle) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.scale(1, 0.42);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 30, height: 42), const Radius.circular(3));
      canvas.drawRRect(r, Paint()..color = const Color(0xFF7A1018));
      canvas.drawRRect(r.deflate(3), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Saloon.paper.withValues(alpha: 0.7));
      canvas.restore();
    }

    card(table.center + Offset(-tw * 0.1, -2), -0.4);
    card(table.center + Offset(-tw * 0.06, 2), 0.2);
    for (var i = 0; i < 4; i++) {
      final c = table.center + Offset(tw * 0.1, -i * 3.0);
      final chip = Rect.fromCenter(center: c, width: 22, height: 8);
      canvas.drawOval(chip, Paint()..color = i.isEven ? Saloon.enamel : Saloon.paper);
      canvas.drawOval(chip, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = Colors.black.withValues(alpha: 0.5));
    }

    // Il filo e la lampada a campana, d'ottone scuro.
    canvas.drawLine(Offset(cx, 0), Offset(cx, lampY - 6), Paint()..color = const Color(0xFF3A2B1A)..strokeWidth = 1.6);
    final shade = Path()
      ..moveTo(cx - 9, lampY - 8)
      ..lineTo(cx + 9, lampY - 8)
      ..quadraticBezierTo(cx + 18, lampY + 4, cx + 34, lampY + 18)
      ..lineTo(cx - 34, lampY + 18)
      ..quadraticBezierTo(cx - 18, lampY + 4, cx - 9, lampY - 8)
      ..close();
    canvas.drawPath(shade, Paint()..shader = const LinearGradient(colors: [Color(0xFF2A3A2C), Color(0xFF51684F), Color(0xFF223024)]).createShader(Rect.fromLTRB(cx - 34, lampY - 8, cx + 34, lampY + 18)));
    canvas.drawLine(Offset(cx - 34, lampY + 18), Offset(cx + 34, lampY + 18), Paint()..color = Saloon.brass..strokeWidth = 2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, lampY + 20), width: 46, height: 8),
      Paint()
        ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.9 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

  }

  @override
  bool shouldRepaint(_RoomPainter old) => old.breath != breath;
}

/// Picche o cuori, disegnati: nessun carattere da cercare nei font.
class _SuitPainter extends CustomPainter {
  final bool heart;
  final Color color;
  const _SuitPainter({required this.heart, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = color;
    if (heart) {
      canvas.drawPath(
        Path()
          ..moveTo(w / 2, h)
          ..cubicTo(-w * 0.2, h * 0.5, w * 0.1, -h * 0.15, w / 2, h * 0.28)
          ..cubicTo(w * 0.9, -h * 0.15, w * 1.2, h * 0.5, w / 2, h)
          ..close(),
        paint,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(w / 2, 0)
          ..cubicTo(w * 1.25, h * 0.5, w * 0.8, h * 0.95, w / 2, h * 0.68)
          ..cubicTo(w * 0.2, h * 0.95, -w * 0.25, h * 0.5, w / 2, 0)
          ..close(),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w / 2, h * 0.6)
          ..lineTo(w * 0.72, h)
          ..lineTo(w * 0.28, h)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.heart != heart || old.color != color;
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

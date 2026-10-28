import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/recap_strings.dart';
import '../../../rules/game_engine.dart';
import '../../../rules/game_recap.dart';
import '../../../rules/player.dart';
import '../../../rules/role.dart';
import '../../theme/app_theme.dart';
import '../../widgets/player_avatar.dart';
import 'game/noir_ui.dart';

/// The recap of the last online game seen, so the results screen (which
/// opens after the table closes) can offer it too.
class RecapShelf {
  static GameRecap? last;
  static Player? me;
}

/// Opens "Il resoconto" over everything.
Future<void> showGameRecap(BuildContext context, GameRecap recap, {Player? me}) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => RecapScreen(recap: recap, me: me),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );

const _paper = Color(0xFFEFE4CB);
const _ink = Color(0xFF1C140E);
const _faded = Color(0xFF5E5040);
const _red = Color(0xFF9E1B1B);
const _green = Color(0xFF2F6B45);
const _ochre = Color(0xFF8A6A1E);

Color _teamColor(Team team) => switch (team) {
  Team.mafia => _red,
  Team.citizens => _green,
  Team.neutral => _ochre,
};

TextStyle _serif(double size, {Color color = _ink, FontWeight weight = FontWeight.w400, bool italic = false, double spacing = 0}) =>
    TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: spacing,
      height: 1.3,
    );

/// The end-of-game recap, as a special edition of the local paper: every
/// card face up, who won, and what everyone really did, night by night.
class RecapScreen extends StatelessWidget {
  final GameRecap recap;
  final Player? me;

  const RecapScreen({super.key, required this.recap, this.me});

  @override
  Widget build(BuildContext context) {
    final r = RecapStrings.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final k = wide ? 1.15 : 1.0;
    final cast = _Cast(recap: recap, me: me, k: k);
    final timeline = _Timeline(recap: recap, k: k);
    final close = SizedBox(
      width: wide ? 260 : double.infinity,
      child: NoirButton(
        key: const Key('recap.close'),
        label: r.close,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
    return Scaffold(
      key: const Key('recap.screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1500 : 560),
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 40 : 10, wide ? 28 : 8, wide ? 40 : 10, wide ? 24 : 10),
              child: Column(
                children: [
                  Expanded(
                    child: _Sheet(
                      child: wide
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Masthead(recap: recap, k: k),
                                const SizedBox(height: 14),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(width: 470, child: SingleChildScrollView(child: cast)),
                                      const VerticalDivider(color: _ink, width: 40, thickness: 0.8),
                                      Expanded(child: SingleChildScrollView(child: timeline)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _Masthead(recap: recap, k: k),
                                const SizedBox(height: 14),
                                cast,
                                const SizedBox(height: 18),
                                timeline,
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: wide ? 18 : 10),
                  close,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  final Widget child;

  const _Sheet({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4EAD2), _paper, Color(0xFFD9C8A2)],
      ),
      boxShadow: [BoxShadow(color: Color(0xDD000000), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 14), child: child),
  );
}

class _Rule extends StatelessWidget {
  final bool heavy;

  const _Rule({this.heavy = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Container(height: heavy ? 2.4 : 0.8, color: _ink),
  );
}

class _Masthead extends StatelessWidget {
  final GameRecap recap;
  final double k;

  const _Masthead({required this.recap, required this.k});

  @override
  Widget build(BuildContext context) {
    final r = RecapStrings.of(context);
    final color = recap.winner == null ? _ink : _teamColor(recap.winner!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(r.masthead.toUpperCase(), style: _serif(30 * k, weight: FontWeight.w700, spacing: 1.4)),
        ),
        const _Rule(heavy: true),
        Text(
          r.dateLine.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _serif(9.5 * k, spacing: 1.6),
        ),
        const _Rule(),
        const SizedBox(height: 6),
        Text(
          r.winner(recap.winner).toUpperCase(),
          key: const Key('recap.winner'),
          textAlign: TextAlign.center,
          style: _serif(24 * k, color: color, weight: FontWeight.w700, spacing: 1),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final IconData? icon;
  final double k;

  const _Heading(this.text, {this.icon, required this.k});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 16 * k, color: _ink), const SizedBox(width: 6)],
        Flexible(
          flex: 4,
          child: Text(
            text.toUpperCase(),
            maxLines: 2,
            style: _serif(13 * k, weight: FontWeight.w700, spacing: 2),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: _Rule()),
      ],
    ),
  );
}

class _Cast extends StatelessWidget {
  final GameRecap recap;
  final Player? me;
  final double k;

  const _Cast({required this.recap, required this.me, required this.k});

  @override
  Widget build(BuildContext context) {
    final r = RecapStrings.of(context);
    final t = AppStrings.of(context);
    final exits = {for (final exit in recap.exits) exit.seat};
    return Column(
      key: const Key('recap.cast'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(r.cast, k: k),
        for (final entry in recap.roles.entries)
          Container(
            key: Key('recap.player.${entry.key.id}'),
            padding: EdgeInsets.symmetric(vertical: 5 * k),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x331C140E)))),
            child: Row(
              children: [
                PlayerAvatar(seed: entry.key.name, size: 34 * k, fallen: !recap.survivors.contains(entry.key)),
                SizedBox(width: 10 * k),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key == me ? '${entry.key.name} (${r.you})' : entry.key.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _serif(14.5 * k, weight: FontWeight.w700),
                      ),
                      Text(
                        '${t.role(entry.value).label} · ${r.team(entry.value.team)} · '
                        '${exits.contains(entry.key) ? r.left : recap.survivors.contains(entry.key) ? r.survived : r.fell}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _serif(12 * k, color: _teamColor(entry.value.team), italic: true),
                      ),
                    ],
                  ),
                ),
                if (recap.won(entry.key))
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6 * k, vertical: 2 * k),
                    decoration: BoxDecoration(border: Border.all(color: _red, width: 1.6)),
                    child: Text(
                      recap.personalWins.contains(entry.key) ? r.wonAlone : r.won,
                      style: _serif(10 * k, color: _red, weight: FontWeight.w700, spacing: 1.2),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  final GameRecap recap;
  final double k;

  const _Timeline({required this.recap, required this.k});

  @override
  Widget build(BuildContext context) {
    final r = RecapStrings.of(context);
    final t = AppStrings.of(context);
    String label(Player p) => '${p.name} (${t.role(recap.roles[p]!).label})';
    final rounds = {for (final n in recap.nights) n.round, for (final d in recap.days) d.round}.toList()..sort();
    final children = <Widget>[_Heading(r.timeline, k: k)];

    Widget line(String text, {Color color = _ink, bool bold = false, IconData icon = Icons.chevron_right}) => Padding(
      padding: EdgeInsets.only(bottom: 4 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.only(top: 2 * k), child: Icon(icon, size: 13 * k, color: color)),
          SizedBox(width: 5 * k),
          Expanded(child: Text(text, style: _serif(13 * k, color: color, weight: bold ? FontWeight.w700 : FontWeight.w400))),
        ],
      ),
    );

    List<Widget> exitsAt(int round, GamePhase phase) => [
      for (final exit in recap.exits)
        if (exit.round == round && exit.phase == phase) line(r.exit(label(exit.seat)), color: _faded, icon: Icons.logout),
    ];

    for (final round in rounds) {
      final night = recap.nights.where((n) => n.round == round).firstOrNull;
      final day = recap.days.where((d) => d.round == round).firstOrNull;
      final nightLines = <Widget>[...exitsAt(round, GamePhase.night)];
      if (night != null) {
        if (night.familyVotes.isNotEmpty) {
          final byTarget = <Player, List<Player>>{};
          for (final vote in night.familyVotes) {
            if (vote.target != null) byTarget.putIfAbsent(vote.target!, () => []).add(vote.voter);
          }
          final top = byTarget.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
          nightLines.add(
            top.isEmpty
                ? line(r.familyNobody, color: _red)
                : line(r.familyAimed(top.first.key.name, [for (final p in top.first.value) p.name].join(', ')),
                    color: _red, icon: Icons.gps_fixed),
          );
        }
        for (final move in night.moves) {
          nightLines.add(line(
            '${label(move.actor)} ${r.move(move.kind, move.target.name, seen: move.seen, role: move.role == null ? null : t.role(move.role!).label, visited: move.visited)}',
          ));
        }
        for (final attack in night.dawn.attacks) {
          nightLines.add(line(
            r.attack(attack.outcome, attack.source, label(attack.target)),
            color: attack.isFatal ? _red : _green,
            bold: true,
            icon: attack.isFatal ? Icons.close : Icons.shield_outlined,
          ));
        }
        if (night.dawn.scoop case final scoop?) nightLines.add(line(r.scoopOut(scoop.subject.name, scoop.team), icon: Icons.newspaper));
        if (night.dawn.resurrected case final risen?) nightLines.add(line(r.risen(risen.name), color: _green, bold: true));
        if (nightLines.isEmpty) nightLines.add(line(r.quietNight, color: _faded));
        children
          ..add(_Heading(r.night(round), icon: Icons.nightlight_round, k: k))
          ..addAll(nightLines);
      }
      if (day != null) {
        final dayLines = <Widget>[...exitsAt(round, GamePhase.day)];
        if (day.mayor case final mayor?) dayLines.add(line(r.mayor(mayor.name), color: _green, icon: Icons.account_balance));
        if (day.votes.isNotEmpty) {
          dayLines.add(Padding(
            padding: EdgeInsets.only(bottom: 4 * k, top: 2 * k),
            child: Wrap(
              spacing: 6 * k,
              runSpacing: 4 * k,
              children: [
                for (final vote in day.votes)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6 * k, vertical: 2 * k),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0x881C140E))),
                    child: vote.target == null
                        ? Text('${vote.voter.name} ${r.abstained}', style: _serif(11.5 * k, color: _faded, italic: true))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(vote.voter.name, style: _serif(11.5 * k)),
                              Icon(Icons.arrow_right_alt, size: 14 * k, color: _red),
                              Text(vote.target!.name, style: _serif(11.5 * k, weight: FontWeight.w700)),
                            ],
                          ),
                  ),
              ],
            ),
          ));
        }
        final lynch = day.lynch;
        dayLines.add(lynch.condemned == null
            ? line(r.noCondemned, color: _faded, bold: true)
            : line(r.condemned(lynch.condemned!.name, t.role(lynch.role!).label), color: _red, bold: true, icon: Icons.gavel));
        if (lynch.personalWin) dayLines.add(line(r.foolWins(lynch.condemned!.name), color: _ochre));
        if (lynch.bountyHunter case final hunter?) dayLines.add(line(r.bounty(hunter.name), color: _ochre));
        children
          ..add(_Heading(r.day(round), icon: Icons.wb_sunny_outlined, k: k))
          ..addAll(dayLines);
      }
    }
    return Column(key: const Key('recap.timeline'), crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

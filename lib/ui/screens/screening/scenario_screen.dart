import 'dart:math';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../narration/death_story.dart';
import '../../../narration/narrator_script.dart';
import '../../../rules/game_engine.dart';
import '../../../rules/player.dart';
import '../../../rules/role.dart';
import '../../../sound/sound_stage.dart';
import '../../press.dart';
import '../../theme/app_theme.dart';
import '../../widgets/death_scene.dart';
import '../../widgets/lynch_mark.dart';
import '../../widgets/scene_scaffold.dart';
import '../online/game/chronicle_headlines.dart';
import '../online/game/front_page.dart';
import '../online/game/noir_ui.dart';
import '../online/game/seat_card.dart';
import 'night_scenarios.dart';

/// Una notte di prova, come la vedrebbero i giocatori online: i film
/// dell'alba, la prima pagina, le battute del narratore e, se la piazza ha
/// votato, il linciaggio sul posto con il verdetto.
class ScenarioScreen extends StatefulWidget {
  final NightScenario scenario;

  const ScenarioScreen({super.key, required this.scenario});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  late final ScenarioRun _run = widget.scenario.run();
  int _take = 0;

  AppStrings get _t => AppStrings.of(context);
  bool get _italian => _t.language.locale.languageCode == 'it';

  NarratorScript _script(String event) =>
      NarratorScript(pack: _t.pack, city: _t.pack.cities.first, random: Random(event.hashCode & 0x7fffffff));

  late final List<DeathStory> _stories = _script('dawn').stage(_run.dawn);

  void _films() {
    final dawn = _run.dawn;
    SoundStage.instance.prepare([
      for (final story in _stories) ...[filmFor(story).act, ?filmFor(story).save],
    ]);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: _Reel(
            count: dawn.attacks.length,
            scene: (index, next) {
              final story = _stories[index];
              final film = filmFor(story);
              final attack = dawn.attacks[index];
              return DeathScene(
                key: ValueKey('scenario-film-$index'),
                act: film.act,
                save: film.save,
                victimName: attack.isFatal ? attack.target.name : _t.someoneSaved,
                caption: story.scene.text,
                epilogue: story.epilogue?.id ?? '',
                style: skylineFor(_t.pack.cities.first.id),
                onFinished: next,
              );
            },
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenario = widget.scenario;
    final dawn = _run.dawn;
    final lynch = _run.lynch;
    final lines = _script('dawn').dawn(dawn, discussion: const Duration(minutes: 1), stories: _stories, online: true);
    final (:headline, :dead) = dawnHeadline(dawn, italian: _italian, everyoneAlive: _t.everyoneAlive);
    final city = _t.pack.cities.first.name;
    final winner = lynch?.winner ?? dawn.winner;
    return SceneScaffold(
      mood: SceneMood.night,
      appBar: AppBar(title: Text(scenario.titleIn(_italian))),
      body: SafeArea(
        child: ListView(
          key: const Key('scenario.list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(scenario.blurbIn(_italian), textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 12),
            Row(
              children: [
                if (dawn.attacks.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('scenario.films'),
                      icon: const Icon(Icons.movie_filter, size: 18),
                      label: Text(_t.screeningFilms),
                      onPressed: pressed(_films, Press.tap),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(_t.screeningReplay),
                  onPressed: () => setState(() => _take++),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 560,
              child: FrontPage(
                key: ValueKey('scenario-front-$_take'),
                masthead: _italian ? 'Il Corriere di $city' : 'The $city Courier',
                dateLine: _italian
                    ? "Anno XIX  ·  Giorno ${dawn.round}  ·  Edizione dell'alba"
                    : 'Vol. XIX  ·  Day ${dawn.round}  ·  Dawn edition',
                headline: headline,
                kicker: _t.crimePage,
                portraits: dead,
                fallen: dawn.victims.isNotEmpty,
                lines: [for (final l in lines) (text: l.text, fact: l.isFact)],
              ),
            ),
            const SizedBox(height: 16),
            Text(_t.screeningNarrator, textAlign: TextAlign.center, style: AppText.overline),
            const SizedBox(height: 6),
            for (final line in lines) _line(line),
            if (lynch != null) ..._verdict(lynch),
            if (winner != null && lynch?.bountyHunter == null) ...[
              const SizedBox(height: 12),
              for (final line in _script('end').ending(
                winner,
                assassin: _run.engine.personalWins.any((p) => _run.engine.setup.roleOf(p) == Role.sicario),
                bountyHunter: lynch?.bountyHunter,
              ))
                _line(line),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(ScriptLine line) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      line.text,
      style: AppText.body.copyWith(
        fontStyle: line.isFact ? FontStyle.normal : FontStyle.italic,
        fontWeight: line.isFact ? FontWeight.w700 : FontWeight.w400,
        color: line.isFact ? Saloon.brass : null,
      ),
    ),
  );

  List<Widget> _verdict(LynchReport report) {
    final role = report.role;
    final headline = lynchHeadline(report, italian: _italian, tag: (p) => p.name, roleLabel: (r) => _t.role(r).label);
    final mayor = _run.mayor;
    final tally = [
      for (final MapEntry(key: voter, value: target) in _run.votes.entries)
        '${voter.name} → ${target?.name ?? _t.online.abstainTag}',
    ].join('  ·  ');
    return [
      const SizedBox(height: 20),
      if (mayor != null)
        ScrimText(
          _t.pack.mayorRevealed.replaceAll('{name}', mayor.name),
          key: const Key('scenario.mayor'),
          style: AppText.body.copyWith(color: Saloon.brass, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ScrimText(
        headline,
        key: const Key('scenario.verdictHeadline'),
        style: AppText.body.copyWith(
          color: role == null ? Saloon.brass : stampColorFor(role),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (tally.isNotEmpty) ScrimText(tally, style: AppText.body.copyWith(color: Saloon.brass, fontSize: 11)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [for (final player in _run.players) _seat(player, report)],
      ),
      const SizedBox(height: 12),
      for (final line in _script('lynch').lynch(report)) _line(line),
    ];
  }

  Widget _seat(Player player, LynchReport report) {
    final engine = _run.engine;
    final shown = player == report.condemned || player == report.bountyHunter || player == _run.mayor;
    final role = shown ? engine.setup.roleOf(player) : null;
    final seat = SeatCard(
      key: ValueKey('scenario-seat-${player.id}'),
      name: player.name,
      width: 64,
      fallen: !engine.isAlive(player),
      votes: [
        for (final MapEntry(:key, :value) in _run.votes.entries)
          if (value == player) key == _run.mayor ? 2 : 1,
      ].fold(0, (a, b) => a + b),
      accusedLabel: _t.online.accusedTag,
      note: role == null ? null : _t.role(role).label,
      noteColor: role?.team == Team.mafia ? Saloon.mafia : Saloon.brass,
    );
    if (player != report.condemned) return seat;
    return LynchMark(key: ValueKey('scenario-lynch-$_take'), label: _italian ? 'Linciato' : 'Lynched', child: seat);
  }
}

/// I film dell'alba uno dopo l'altro, poi [onDone].
class _Reel extends StatefulWidget {
  final int count;
  final Widget Function(int index, VoidCallback next) scene;
  final VoidCallback onDone;

  const _Reel({required this.count, required this.scene, required this.onDone});

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> {
  int _index = 0;

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= widget.count) return widget.onDone();
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) => widget.scene(_index, _next);
}

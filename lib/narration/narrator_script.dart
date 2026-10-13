import 'dart:math';

import '../rules/game_engine.dart';
import '../rules/role.dart';
import 'death_story.dart';
import 'italian_pack.dart';
import 'narration_pack.dart';
import 'picker.dart';

/// Una battuta del copione. Quelle d'atmosfera raccontano; quelle [isFact]
/// dicono in parole semplici cosa è successo o cosa si fa adesso, e vanno
/// lette (e mostrate) in modo che nessuno al tavolo se le perda.
class ScriptLine {
  final String text;
  final bool isFact;

  const ScriptLine(this.text) : isFact = false;
  const ScriptLine.fact(this.text) : isFact = true;
}

/// Il copione del narratore: per ogni momento della partita compone le
/// battute da leggere ad alta voce, pescate ogni volta in modo diverso.
/// Lo stesso testo servirà alla voce sintetica del narratore automatico.
class NarratorScript {
  final NarrationPack pack;

  /// La città in cui è ambientata questa partita, sorteggiata all'inizio.
  final CitySetting city;
  final Picker _picker;

  NarratorScript._(this.pack, this.city, this._picker);

  factory NarratorScript({NarrationPack pack = italianPack, CitySetting? city, Random? random}) {
    final rng = random ?? Random();
    return NarratorScript._(
      pack,
      city ?? pack.cities[rng.nextInt(pack.cities.length)],
      Picker(rng),
    );
  }

  List<ScriptLine> opening() => [
        _story(_picker.pick('opening', city.openings)),
        _fact(pack.howToPlay),
      ];

  List<ScriptLine> nightFalls(int round) => [
        _story(round == 1 ? _picker.pick('night.first', pack.firstNights) : _picker.pick('night', pack.nights)),
        _fact(pack.nightInstruction),
      ];

  /// Sorteggia come è morta una vittima. Chi mette in scena il delitto e chi
  /// lo racconta devono usare la stessa storia: si compone una volta sola.
  DeathStory composeDeath() => DeathStory.compose(_picker, pack, city);

  /// [stories] sono le morti già messe in scena, una per vittima; se mancano
  /// vengono composte qui.
  List<ScriptLine> dawn(
    DawnReport report, {
    required Duration discussion,
    List<DeathStory>? stories,
  }) {
    final lines = <ScriptLine>[];

    if (report.victims.isEmpty) {
      lines.add(_fact(pack.nobodyDied));
      lines.add(_story(_picker.pick('dawn.quiet', pack.quietDawns)));
    }
    for (var i = 0; i < report.victims.length; i++) {
      final name = report.victims[i].name;
      if (i > 0) lines.add(_story(_picker.pick('dawn.again', pack.secondVictims)));
      final story = stories != null ? stories[i] : composeDeath();
      for (final paragraph in story.paragraphs) {
        lines.add(_story(paragraph, name: name));
      }
      lines.add(_fact(pack.victimFact, name: name));
    }

    final scoop = report.scoop;
    if (scoop != null) {
      final name = scoop.subject.name;
      lines.add(_story(_picker.pick('scoop', pack.scoops), name: name));
      lines.add(_fact(scoop.team == Team.mafia ? pack.scoopMafia : pack.scoopClean, name: name));
    }

    if (report.winner == null) {
      final minutes = discussion.inMinutes == 1
          ? pack.oneMinute
          : pack.manyMinutes.replaceAll('{minutes}', '${discussion.inMinutes}');
      lines.add(_fact(pack.dayInstruction.replaceAll('{minutes}', minutes)));
    }
    return lines;
  }

  List<ScriptLine> voteCall() => [
        _story(_picker.pick('vote', pack.voteCalls)),
        _fact(pack.voteInstruction),
      ];

  /// La prima battuta porta il condannato al patibolo; la seconda gira la
  /// carta, e chi impagina il copione la tiene coperta fino a quel momento.
  List<ScriptLine> lynch(LynchReport report) {
    final condemned = report.condemned;
    if (condemned == null) {
      return [_fact(pack.noLynchFact), _story(_picker.pick('lynch.none', pack.noLynch))];
    }

    final role = report.role!;
    final isMafia = role.team == Team.mafia;
    final String reaction;
    if (!isMafia) {
      reaction = _picker.pick('lynch.innocent', pack.lynchedInnocent);
    } else if (report.winner == Team.citizens) {
      reaction = _picker.pick('lynch.last', pack.lynchedLastMafioso);
    } else {
      reaction = _picker.pick('lynch.mafia', pack.lynchedMafioso);
    }
    return [
      _story(_picker.pick('lynch.scene', pack.lynchScenes), name: condemned.name),
      _fact(
        '${pack.cardTurns.replaceAll('{role}', role.label.toUpperCase())} '
        '${isMafia ? pack.wasMafia : pack.wasCitizen}',
        name: condemned.name,
      ),
      _story(reaction),
    ];
  }

  List<ScriptLine> ending(Team winner) {
    final mafiaWon = winner == Team.mafia;
    return [
      _fact(mafiaWon ? pack.mafiaWinsFact : pack.citizensWinFact),
      _story(_picker.pick('ending.${winner.name}', mafiaWon ? pack.mafiaWins : pack.citizensWin)),
    ];
  }

  /// La domanda che un giocatore legge, da solo, quando di notte tocca a lui.
  /// Il compito di copertura cambia domanda ogni notte.
  String taskPrompt(NightTask task, int round) =>
      pack.taskPrompts[task.kind] ?? pack.decoyPrompts[(round - 1) % pack.decoyPrompts.length];

  String taskHint(NightTask task) => pack.taskHints[task.kind]!;

  ScriptLine _story(String template, {String? name}) => ScriptLine(_fill(template, name));

  ScriptLine _fact(String template, {String? name}) => ScriptLine.fact(_fill(template, name));

  String _fill(String template, String? name) {
    final text = template.replaceAll('{city}', city.name);
    return name == null ? text : text.replaceAll('{name}', name);
  }
}
